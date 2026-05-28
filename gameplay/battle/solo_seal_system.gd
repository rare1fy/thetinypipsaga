## 单挑系统 — v0.5 战士枢纽机制
## 职责：
## - 建立/覆盖单挑关系
## - 判定 AOE 牌型是否被屏蔽
## - 双方伤害 ×1.4
## - 其他敌人攻击屏蔽
## - 回合衰减与清零

class_name SoloSealSystem

const SOLO_DAMAGE_MULT: float = 1.4


## ============================================================
## 建立单挑（覆盖旧单挑）
## ============================================================

static func activate(enemy_uid: String) -> void:
	PlayerState.solo_seal_target = enemy_uid
	PlayerState.solo_seal_turns = 2  # 本回合剩余 + 下个敌方回合
	BattleLog.log_player("X 单挑！→ %s" % enemy_uid)


## ============================================================
## 查询
## ============================================================

static func is_active() -> bool:
	return not PlayerState.solo_seal_target.is_empty() and PlayerState.solo_seal_turns > 0


static func get_target_uid() -> String:
	return PlayerState.solo_seal_target if is_active() else ""


## 判断某个敌人是否是单挑目标
static func is_solo_target(enemy_uid: String) -> bool:
	return is_active() and PlayerState.solo_seal_target == enemy_uid


## ============================================================
## 伤害修正
## ============================================================

## 玩家对单挑目标的伤害倍率
static func get_player_damage_mult(target_uid: String) -> float:
	if is_solo_target(target_uid):
		return SOLO_DAMAGE_MULT
	return 1.0


## 敌人对玩家的伤害倍率（非单挑目标攻击归零）
static func get_enemy_damage_mult(attacker_uid: String) -> float:
	if not is_active():
		return 1.0
	if attacker_uid == PlayerState.solo_seal_target:
		return SOLO_DAMAGE_MULT  # 单挑目标伤害 ×1.4
	return 0.0  # 其他敌人攻击无效


## ============================================================
## AOE 牌型屏蔽判定
## ============================================================

## AOE 牌型（顺子系）在单挑期间退化为单体 ×1.4
## 骰子自带 AOE（旋风斩等）不被屏蔽
static func should_suppress_hand_aoe() -> bool:
	return is_active()


## ============================================================
## 单挑目标死亡 → 立即结束
## ============================================================

static func on_target_death(enemy_uid: String) -> void:
	if is_solo_target(enemy_uid):
		PlayerState.solo_seal_target = ""
		PlayerState.solo_seal_turns = 0
		BattleLog.log_status("单挑目标死亡，单挑结束")


## ============================================================
## 回合衰减
## ============================================================

static func tick_turn() -> void:
	if PlayerState.solo_seal_turns > 0:
		PlayerState.solo_seal_turns -= 1
		if PlayerState.solo_seal_turns <= 0:
			PlayerState.solo_seal_target = ""
			BattleLog.log_status("单挑结束")


## ============================================================
## 清零
## ============================================================

static func reset() -> void:
	PlayerState.solo_seal_target = ""
	PlayerState.solo_seal_turns = 0
