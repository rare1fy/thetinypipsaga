## 敌人行动效果执行器（v2 — 数据驱动）
## 职责：将敌人的 action（从 EnemyInstance.get_action() 获取）转换为 effects 数组，
##       调用 EffectEngine 执行，返回结果由 EnemyActionResolver 应用到游戏状态
## 设计：敌人配置中的 action 可以直接携带 effects 数组，也可以用 type/value/description 走兼容映射

class_name EnemyEffectBridge
extends RefCounted


## 将敌人行动转换为 effects 数组
## action: 来自 EnemyInstance.get_action() 的字典
## e: 执行行动的敌人实例
## 返回: 可直接传给 EffectEngine.execute() 的效果列表
static func action_to_effects(action: Dictionary, e: EnemyInstance) -> Array[Dictionary]:
	# 优先使用 action 中直接配置的 effects 数组（新格式）
	if action.has("effects") and action["effects"] is Array and not action["effects"].is_empty():
		return action["effects"]

	# 兼容旧格式：从 type/value/description 映射
	var action_type: String = action.get("type", "攻击")
	var action_value: int = action.get("value", e.attack_dmg)
	var action_desc: String = action.get("description", "")

	match action_type:
		"防御":
			return _map_defend(e, action_value, action_desc)
		"技能":
			return _map_skill(e, action_value, action_desc)
		_:
			return _map_attack(e, action_value)


## 构建敌人行动的执行上下文
static func build_enemy_context(e: EnemyInstance) -> EffectEngine.ExecuteContext:
	var ctx := EffectEngine.ExecuteContext.new()
	ctx.source = EffectTypes.EffectSource.ENEMY_SKILL
	ctx.source_id = e.config_id
	# 敌人攻击目标是玩家，所以 player 信息填入
	ctx.player_hp = PlayerState.hp
	ctx.player_max_hp = PlayerState.max_hp
	ctx.player_armor = PlayerState.armor
	# 敌人自身信息通过 target_enemy 传递（这里是"来源"而非"目标"）
	ctx.dice_points_total = e.attack_dmg  # 复用字段表示基础攻击力
	return ctx


# ============================================================
# 旧格式映射
# ============================================================

## 防御行动 → 护甲 + 嘲讽
static func _map_defend(e: EnemyInstance, value: int, _desc: String) -> Array[Dictionary]:
	var shield_val: int = value if value > 0 else int(float(e.attack_dmg) * 1.5)
	var effects: Array[Dictionary] = [
		EffectTypes.create_effect(EffectTypes.EffectType.ARMOR,
			{"value": shield_val},
			EffectTypes.TriggerType.ON_PLAY, EffectTypes.EffectScope.INSTANT),
	]
	# Guardian 防御时附带嘲讽
	if e.combat_type == GameTypes.EnemyCombatType.GUARDIAN:
		effects.append(EffectTypes.create_effect(EffectTypes.EffectType.CONTROL,
			{"control": "taunt", "duration": 1, "target": "self"},
			EffectTypes.TriggerType.ON_PLAY, EffectTypes.EffectScope.INSTANT))
	return effects


## 技能行动 → 根据 description 映射
static func _map_skill(e: EnemyInstance, value: int, desc: String) -> Array[Dictionary]:
	var effects: Array[Dictionary] = []

	# DOT 类
	var dot_type: String = _detect_dot(desc)
	if dot_type != "":
		var dot_val: int = maxi(1, value)
		var status_name: String = "burn" if dot_type == "burn" else "poison"
		effects.append(EffectTypes.create_effect(EffectTypes.EffectType.APPLY_STATUS,
			{"status": status_name, "value": dot_val, "target": "enemy"},
			EffectTypes.TriggerType.ON_PLAY, EffectTypes.EffectScope.INSTANT))
		return effects

	# 控制类
	var ctl_type: String = _detect_control(desc)
	if ctl_type != "":
		var ctl_params: Dictionary = {"control": ctl_type, "target": "enemy"}
		if ctl_type == "knockback":
			ctl_params["distance"] = 1
		else:
			ctl_params["duration"] = 2
		effects.append(EffectTypes.create_effect(EffectTypes.EffectType.APPLY_STATUS,
			{"status": ctl_type, "value": 1, "target": "enemy"},
			EffectTypes.TriggerType.ON_PLAY, EffectTypes.EffectScope.INSTANT))
		return effects

	# 护甲祝福类
	if _is_armor_bless(desc):
		effects.append(EffectTypes.create_effect(EffectTypes.EffectType.ARMOR,
			{"value": maxi(1, value)},
			EffectTypes.TriggerType.ON_PLAY, EffectTypes.EffectScope.INSTANT,
			EffectTypes.StackingRule.INDEPENDENT, EffectTypes.TargetScope.RANDOM_ALLY))
		return effects

	# 治疗类
	if _is_heal(desc):
		effects.append(EffectTypes.create_effect(EffectTypes.EffectType.HEAL,
			{"value": maxi(1, value)},
			EffectTypes.TriggerType.ON_PLAY, EffectTypes.EffectScope.INSTANT,
			EffectTypes.StackingRule.INDEPENDENT, EffectTypes.TargetScope.RANDOM_ALLY))
		return effects

	# 塞诅咒骰
	if _is_curse(desc):
		effects.append(EffectTypes.create_effect(EffectTypes.EffectType.INSERT_CURSE_DIE,
			{"die_id": "cursed", "count": 1},
			EffectTypes.TriggerType.ON_PLAY, EffectTypes.EffectScope.INSTANT))
		return effects

	# 未识别 → 当攻击处理
	return _map_attack(e, value)


## 攻击行动 → 基础伤害
static func _map_attack(e: EnemyInstance, value: int) -> Array[Dictionary]:
	var dmg: int = value if value > 0 else e.attack_dmg
	return [
		EffectTypes.create_effect(EffectTypes.EffectType.BONUS_DAMAGE,
			{"value": dmg},
			EffectTypes.TriggerType.ON_PLAY, EffectTypes.EffectScope.INSTANT),
	]


# ============================================================
# 描述检测辅助
# ============================================================

static func _detect_dot(desc: String) -> String:
	var lower: String = desc.to_lower()
	if lower.contains("灼烧") or lower.contains("火") or lower.contains("burn") or lower.contains("fire"):
		return "burn"
	if lower.contains("中毒") or lower.contains("毒") or lower.contains("poison"):
		return "poison"
	return ""


static func _detect_control(desc: String) -> String:
	var lower: String = desc.to_lower()
	if lower.contains("冻结") or lower.contains("freeze") or lower.contains("冰"):
		return "freeze"
	if lower.contains("虚弱") or lower.contains("weak"):
		return "weak"
	if lower.contains("易伤") or lower.contains("vulnerable") or lower.contains("脆弱"):
		return "vulnerable"
	return ""


static func _is_armor_bless(desc: String) -> bool:
	var lower: String = desc.to_lower()
	return lower.contains("护甲") or lower.contains("祝福") or lower.contains("shield") or lower.contains("armor")


static func _is_heal(desc: String) -> bool:
	var lower: String = desc.to_lower()
	return lower.contains("治疗") or lower.contains("回复") or lower.contains("heal")


static func _is_curse(desc: String) -> bool:
	var lower: String = desc.to_lower()
	return lower.contains("诅咒") or lower.contains("curse")
