## 控制系统统一入口 — v0.5_01 §1.8 + §1.9
## 职责：
## - 统一施加控制效果（嘲讽/眩晕/击退/变羊/致盲/缴械）
## - ccImmunity 梯度免控判定（§1.9）
## - 变羊 50/50 概率 + 数据替换 + snapshot 恢复
## - 致盲：攻击转向友军/自伤（非 MISS）
## - 缴械：普攻伤害强制为 1（非跳过）
## - 嘲讽：覆写意图为普攻 ×0.7

class_name ControlSystem


## ============================================================
## 控制类型枚举
## ============================================================

enum ControlType {
	TAUNT,      ## 嘲讽：覆写意图为普攻，伤害×0.7
	STUN,       ## 眩晕：完全跳过行动
	KNOCKBACK,  ## 击退：distance+2（上限2）
	POLYMORPH,  ## 变羊：50%普通羊/50%羊王，持续2回合
	BLIND,      ## 致盲：攻击转向友军（单敌人时自伤）
	DISARM,     ## 缴械：普攻伤害强制为1
}


## ============================================================
## 施加控制（统一入口）— §1.9 ccImmunity 梯度判定
## ============================================================

## 返回 true = 成功施加, false = 被免控/豁免
static func apply_control(
	target: EnemyInstance,
	control_type: ControlType,
	duration: int = -1
) -> bool:
	if target == null or target.hp <= 0:
		return false

	# §1.6 + §1.8.1：Boss/精英 100% 豁免变羊 → fizzle，不消耗 ccImmunity
	if control_type == ControlType.POLYMORPH and _is_boss_or_elite(target):
		BattleLog.log_status("⚡ %s 豁免变羊！" % target.name)
		VFX.show_toast("%s 豁免！" % target.name, "warning")
		return false  # 不 +1 ccImmunity

	# §1.8.2：已变羊目标不可重复变羊 → fizzle，但仍 +1 ccImmunity
	if control_type == ControlType.POLYMORPH and target.is_polymorphed:
		target.cc_immunity += 1
		BattleLog.log_status("⚡ %s 已变羊，无法重复施加！" % target.name)
		return false

	# §1.9.2 ccImmunity 梯度判定
	var success: bool = _roll_cc_immunity(target)

	# §1.9.2 "尝试即消耗"：无论是否生效，ccImmunity += 1
	target.cc_immunity += 1

	if not success:
		BattleLog.log_status("⚡ %s 抵抗了 %s！（免控 %d 层）" % [target.name, _type_name(control_type), target.cc_immunity])
		VFX.show_toast("%s 抵抗！" % target.name, "warning")
		return false

	# 施加控制
	var actual_duration: int = duration if duration > 0 else _default_duration(control_type)
	var cc_key: String = _type_to_key(control_type)

	match control_type:
		ControlType.KNOCKBACK:
			# §1.8.1：distance += 2，上限 2
			target.distance = mini(2, target.distance + 2)
		ControlType.POLYMORPH:
			# §1.8.2：50/50 普通羊/羊王，持续 2 回合
			_apply_polymorph(target, actual_duration)
		_:
			target.cc_turns[cc_key] = maxi(target.cc_turns.get(cc_key, 0), actual_duration)

	BattleLog.log_player("🎯 %s 被施加 %s（%d回合）" % [target.name, _type_name(control_type), actual_duration])
	return true


## ============================================================
## §1.9.2 ccImmunity 梯度掷骰
## ============================================================

static func _roll_cc_immunity(target: EnemyInstance) -> bool:
	var layers: int = target.cc_immunity
	if layers <= 0:
		return true   # 100% 生效
	elif layers == 1:
		return randf() < 0.5  # 50% 生效
	else:
		return false  # ≥2 层直接免疫


## ============================================================
## §1.8.2 变羊：50/50 概率 + 数据替换
## ============================================================

static func _apply_polymorph(target: EnemyInstance, duration: int) -> void:
	# 保存 snapshot（恢复用）
	target.pre_polymorph_snapshot = {
		"attack_dmg": target.attack_dmg,
		"hp": target.hp,
		"max_hp": target.max_hp,
	}

	# 50/50 抽签
	if randf() < 0.5:
		# 普通羊：attack=1, hp=原hp（锁死不能被治疗）
		target.attack_dmg = 1
		# hp 和 max_hp 保持不变（锁死当前值）
		BattleLog.log_status("🐑 %s 变成了普通羊！" % target.name)
		VFX.show_toast("🐑 变羊！", "debuff")
	else:
		# 羊王：attack=20, hp=6, maxHp=6
		target.attack_dmg = 20
		target.hp = mini(target.hp, 6)
		target.max_hp = 6
		BattleLog.log_status("👑🐑 %s 变成了羊王！" % target.name)
		VFX.show_toast("👑 羊王！", "damage")

	target.cc_turns["polymorph"] = duration


## 变羊恢复：期满后恢复原数据
static func restore_polymorph(target: EnemyInstance) -> void:
	if target.pre_polymorph_snapshot.is_empty():
		return
	var snap: Dictionary = target.pre_polymorph_snapshot
	target.attack_dmg = snap.get("attack_dmg", target.attack_dmg)
	# hp 恢复：取当前 hp 和原 hp 的较小值（变羊期间受伤的 hp 保留）
	var original_hp: int = snap.get("hp", target.hp)
	var original_max_hp: int = snap.get("max_hp", target.max_hp)
	target.max_hp = original_max_hp
	target.hp = mini(target.hp, original_max_hp)
	target.pre_polymorph_snapshot = {}
	BattleLog.log_status("✨ %s 恢复了原形！" % target.name)


## ============================================================
## 查询：敌人是否被控制（跳过行动）
## §1.8.2：眩晕跳过行动；变羊不跳过（变羊后仍行动，用羊的数据）
## ============================================================

static func should_skip_action(e: EnemyInstance) -> bool:
	return e.cc_turns.get("stun", 0) > 0


## 查询：嘲讽中（覆写意图为普攻×0.7）
static func is_taunted(e: EnemyInstance) -> bool:
	return e.cc_turns.get("taunt", 0) > 0


## 查询：致盲中（攻击转向友军/自伤）
static func is_blinded(e: EnemyInstance) -> bool:
	return e.cc_turns.get("blind", 0) > 0


## 查询：缴械中（普攻伤害强制为1）
static func is_disarmed(e: EnemyInstance) -> bool:
	return e.cc_turns.get("disarm", 0) > 0


## 查询：变羊中
static func is_polymorphed(e: EnemyInstance) -> bool:
	return e.cc_turns.get("polymorph", 0) > 0


## ============================================================
## §1.8.1 嘲讽伤害修正：×0.7（向下取整，最低1）
## ============================================================

static func get_taunt_damage(base_damage: int) -> int:
	return maxi(1, int(float(base_damage) * 0.7))


## ============================================================
## §1.8.1 致盲：获取攻击重定向目标
## 多敌人：攻击随机另一个存活敌人
## 单敌人：攻击自己（自伤）
## ============================================================

static func get_blind_target(blinded_enemy: EnemyInstance) -> EnemyInstance:
	var living: Array[EnemyInstance] = []
	for e in GameManager.current_enemies:
		if e is EnemyInstance and e.hp > 0 and e.uid != blinded_enemy.uid:
			living.append(e)
	if living.size() > 0:
		return living[randi() % living.size()]
	# 单敌人：返回自身（自伤）
	return blinded_enemy


## ============================================================
## 回合衰减 — §1.9.3 + §1.8.2 变羊恢复
## 敌方回合开始：ccImmunity -= 1
## 敌方回合结束：控制状态回合数 -= 1，变羊期满恢复
## ============================================================

## §1.9.3：每个敌人回合开始时 ccImmunity -= 1
static func tick_cc_immunity(enemies: Array[EnemyInstance]) -> void:
	for e: EnemyInstance in enemies:
		if e.hp <= 0:
			continue
		e.cc_immunity = maxi(0, e.cc_immunity - 1)


## 控制状态回合衰减（每敌方回合结束调用）
static func tick_all(enemies: Array[EnemyInstance]) -> void:
	for e: EnemyInstance in enemies:
		if e.hp <= 0:
			continue
		var keys: Array = e.cc_turns.keys()
		for key: String in keys:
			e.cc_turns[key] -= 1
			if e.cc_turns[key] <= 0:
				e.cc_turns.erase(key)
				# 变羊期满恢复原数据
				if key == "polymorph":
					restore_polymorph(e)


## ============================================================
## 内部辅助
## ============================================================

static func _is_boss_or_elite(target: EnemyInstance) -> bool:
	# Boss/精英判定：max_hp > 200 或配置标记
	return target.max_hp > 200


static func _default_duration(ct: ControlType) -> int:
	match ct:
		ControlType.TAUNT: return 1
		ControlType.STUN: return 1
		ControlType.KNOCKBACK: return 1  # 击退是一次性位移，不持续
		ControlType.POLYMORPH: return 2  # §1.8.1：持续 2 个敌人回合
		ControlType.BLIND: return 1
		ControlType.DISARM: return 1
		_: return 1


static func _type_name(ct: ControlType) -> String:
	match ct:
		ControlType.TAUNT: return "嘲讽"
		ControlType.STUN: return "眩晕"
		ControlType.KNOCKBACK: return "击退"
		ControlType.POLYMORPH: return "变羊"
		ControlType.BLIND: return "致盲"
		ControlType.DISARM: return "缴械"
		_: return "未知"


static func _type_to_key(ct: ControlType) -> String:
	match ct:
		ControlType.TAUNT: return "taunt"
		ControlType.STUN: return "stun"
		ControlType.KNOCKBACK: return "knockback"
		ControlType.POLYMORPH: return "polymorph"
		ControlType.BLIND: return "blind"
		ControlType.DISARM: return "disarm"
		_: return "unknown"
