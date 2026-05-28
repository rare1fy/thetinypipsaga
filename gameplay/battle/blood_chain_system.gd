## 血锁链系统 — v0.5 战士枢纽机制
## 职责：
## - 建立/覆盖血锁绑定
## - 玩家受伤/自伤时传递等额伤害给被锁敌人
## - 回合衰减与清零

class_name BloodChainSystem


## ============================================================
## 建立血锁（覆盖旧绑定）
## ============================================================

## 与单个目标建立血锁，持续到下个敌方回合结束
static func bind(enemy_uid: String) -> void:
	if enemy_uid.is_empty():
		return
	if enemy_uid not in PlayerState.blood_chain_targets:
		PlayerState.blood_chain_targets.append(enemy_uid)
	PlayerState.blood_chain_turns = 2  # 本回合剩余 + 下个敌方回合
	BattleLog.log_player("- 血锁链绑定 → %s" % enemy_uid)


## AOE 绑定（顺子打出时与所有命中敌人绑定）
static func bind_all(enemy_uids: Array[String]) -> void:
	PlayerState.blood_chain_targets.clear()
	for uid: String in enemy_uids:
		if not uid.is_empty():
			PlayerState.blood_chain_targets.append(uid)
	PlayerState.blood_chain_turns = 2
	BattleLog.log_player("- 血锁链 AOE 绑定 %d 个目标" % enemy_uids.size())


## ============================================================
## 传递伤害（玩家受伤/自伤时调用）
## ============================================================

## 返回应传递给被锁敌人的伤害量
## source: "enemy" = 敌人攻击, "self" = 主动自伤, "dot" = DOT
static func get_chain_damage(hp_lost: int, source: String) -> int:
	if hp_lost <= 0:
		return 0
	if PlayerState.blood_chain_targets.is_empty():
		return 0
	if PlayerState.blood_chain_turns <= 0:
		return 0
	# DOT 不触发血锁
	if source == "dot":
		return 0
	# 敌人攻击和主动自伤都触发
	return hp_lost


## 检查某个敌人是否被血锁绑定
static func is_bound(enemy_uid: String) -> bool:
	return enemy_uid in PlayerState.blood_chain_targets and PlayerState.blood_chain_turns > 0


## ============================================================
## 回合衰减
## ============================================================

static func tick_turn() -> void:
	if PlayerState.blood_chain_turns > 0:
		PlayerState.blood_chain_turns -= 1
		if PlayerState.blood_chain_turns <= 0:
			PlayerState.blood_chain_targets.clear()
			BattleLog.log_status("血锁链解除")


## ============================================================
## 清零
## ============================================================

static func reset() -> void:
	PlayerState.blood_chain_targets.clear()
	PlayerState.blood_chain_turns = 0
