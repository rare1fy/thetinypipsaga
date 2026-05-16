## 控制系统统一入口 — v0.5_01 §1.8
## 职责：
## - 统一施加控制效果（嘲讽/眩晕/击退/变羊/致盲/缴械）
## - ccImmunity 免控判定
## - 控制效果的回合衰减
## - 控制效果对敌人行为的影响查询

class_name ControlSystem


## ============================================================
## 控制类型枚举
## ============================================================

enum ControlType {
	TAUNT,      ## 嘲讽：覆写意图为普攻，伤害×0.7
	STUN,       ## 眩晕：跳过行动
	KNOCKBACK,  ## 击退：distance+1（近战延迟1回合）
	POLYMORPH,  ## 变羊：跳过行动+攻击力归零
	BLIND,      ## 致盲：攻击有50%概率miss
	DISARM,     ## 缴械：无法使用攻击类行动
}


## ============================================================
## 施加控制（统一入口）
## ============================================================

## 返回 true = 成功施加, false = 被免控
static func apply_control(
	target: EnemyInstance,
	control_type: ControlType,
	duration: int = 1
) -> bool:
	if target == null or target.hp <= 0:
		return false

	# ccImmunity 判定：Boss 和标记免控的敌人
	if _is_cc_immune(target, control_type):
		BattleLog.log_status("⚡ %s 免疫控制！" % target.name)
		VFX.show_toast("%s 免疫！" % target.name, "warning")
		return false

	# 施加控制
	var cc_key: String = _type_to_key(control_type)
	match control_type:
		ControlType.KNOCKBACK:
			target.distance = mini(3, target.distance + 1)  # 最大距离3
		_:
			target.cc_turns[cc_key] = maxi(target.cc_turns.get(cc_key, 0), duration)

	BattleLog.log_player("🎯 %s 被施加 %s（%d回合）" % [target.name, _type_name(control_type), duration])
	return true


## ============================================================
## 免控判定
## ============================================================

static func _is_cc_immune(target: EnemyInstance, control_type: ControlType) -> bool:
	# Boss 免疫硬控（眩晕/变羊），但不免疫嘲讽/致盲/缴械/击退
	if target.max_hp > 200:  # Boss 阈值
		match control_type:
			ControlType.STUN, ControlType.POLYMORPH:
				return true
	# 配置级免控
	if target.cc_immunity:
		return true
	return false


## ============================================================
## 查询：敌人是否被控制（跳过行动）
## ============================================================

static func should_skip_action(e: EnemyInstance) -> bool:
	return e.cc_turns.get("stun", 0) > 0 or e.cc_turns.get("polymorph", 0) > 0


## 查询：嘲讽中（覆写意图为普攻×0.7）
static func is_taunted(e: EnemyInstance) -> bool:
	return e.cc_turns.get("taunt", 0) > 0


## 查询：致盲中（50% miss）
static func is_blinded(e: EnemyInstance) -> bool:
	return e.cc_turns.get("blind", 0) > 0


## 查询：缴械中（无法攻击）
static func is_disarmed(e: EnemyInstance) -> bool:
	return e.cc_turns.get("disarm", 0) > 0


## ============================================================
## 回合衰减（每敌方回合结束调用）
## ============================================================

static func tick_all(enemies: Array[EnemyInstance]) -> void:
	for e: EnemyInstance in enemies:
		if e.hp <= 0:
			continue
		var keys: Array = e.cc_turns.keys()  # 显式快照，避免遍历中修改风险
		for key: String in keys:
			e.cc_turns[key] -= 1
			if e.cc_turns[key] <= 0:
				e.cc_turns.erase(key)


## ============================================================
## 内部辅助
## ============================================================

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
