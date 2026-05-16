## 敌人行动效果桥接器（v3 — 纯数据驱动）
## 职责：从敌人 action 中提取 effects 数组，构建执行上下文
## 所有 action 已迁移到 _action_fx() 格式，不再需要 description 字符串匹配

class_name EnemyEffectBridge
extends RefCounted

const EffectEngine = preload("res://gameplay/battle/effect_engine.gd")


## 将敌人行动转换为 effects 数组
## action: 来自 EnemyInstance.get_action() 的字典
## e: 执行行动的敌人实例
## 返回: 可直接传给 EffectEngine.execute() 的效果列表
static func action_to_effects(action: Dictionary, e: EnemyInstance) -> Array[Dictionary]:
	if action.has("effects") and action["effects"] is Array and not action["effects"].is_empty():
		return action["effects"]

	# 兜底：无 effects 的 action 按基础攻击处理（理论上不应触发）
	push_warning("EnemyEffectBridge: action 缺少 effects 数组，走兜底攻击: %s" % str(action))
	var dmg: int = action.get("value", e.attack_dmg)
	return [
		EffectTypes.create_effect(EffectTypes.EffectType.BONUS_DAMAGE,
			{"value": dmg},
			EffectTypes.TriggerType.ON_PLAY, EffectTypes.EffectScope.INSTANT),
	]


## 构建敌人行动的执行上下文
static func build_enemy_context(e: EnemyInstance) -> EffectEngine.ExecuteContext:
	var ctx := EffectEngine.ExecuteContext.new()
	ctx.source = EffectTypes.EffectSource.ENEMY_SKILL
	ctx.source_id = e.config_id
	ctx.player_hp = PlayerState.hp
	ctx.player_max_hp = PlayerState.max_hp
	ctx.player_armor = PlayerState.armor
	ctx.dice_points_total = e.attack_dmg
	return ctx
