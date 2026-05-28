## 伤痕系统 — v0.5 战士第三被动
## 职责：
## - 伤痕叠层（仅主动自伤来源）
## - 伤痕衰减（每敌方回合结束 -2 层）
## - 普通攻击放大器（追加基础伤害 = 当前层数 × 1，不消耗）
## - 消耗型骰子接口（浴血之刃/血神之眼按比例消耗）
## - 战斗结束清零

class_name ScarSystem


## ============================================================
## 叠层（仅主动自伤来源调用）
## ============================================================

## 主动自伤造成实际 HP 损失时调用，每损 1 HP +1 层
static func add_from_self_damage(hp_lost: int) -> void:
	if hp_lost <= 0:
		return
	if PlayerState.player_class != "warrior":
		return
	PlayerState.scar_stacks += hp_lost
	BattleLog.log_player("B 伤痕 +%d（当前 %d 层）" % [hp_lost, PlayerState.scar_stacks])


## ============================================================
## 衰减（每敌方回合结束调用）
## ============================================================

static func decay_per_enemy_turn() -> void:
	if PlayerState.scar_stacks <= 0:
		return
	var old: int = PlayerState.scar_stacks
	PlayerState.scar_stacks = maxi(0, PlayerState.scar_stacks - 2)
	if old != PlayerState.scar_stacks:
		BattleLog.log_status("伤痕衰减 -2（%d → %d）" % [old, PlayerState.scar_stacks])


## ============================================================
## 普通攻击放大器（被动持续收益，不消耗）
## ============================================================

## 返回本次普通攻击应追加的基础伤害
static func get_normal_attack_bonus() -> int:
	if PlayerState.player_class != "warrior":
		return 0
	return PlayerState.scar_stacks


## ============================================================
## 消耗型骰子接口
## ============================================================

## 消耗指定比例的伤痕层数，返回实际消耗量
## ratio: 0.5 = 50%, 0.3 = 30% 等
static func consume(ratio: float) -> int:
	if PlayerState.scar_stacks <= 0:
		return 0
	var amount: int = int(float(PlayerState.scar_stacks) * ratio)  # 向下取整
	if amount <= 0:
		return 0
	PlayerState.scar_stacks -= amount
	BattleLog.log_player("伤痕消耗 -%d（剩余 %d）" % [amount, PlayerState.scar_stacks])
	return amount


## ============================================================
## 战斗结束清零
## ============================================================

static func reset_battle() -> void:
	PlayerState.scar_stacks = 0
	PlayerState.blood_chain_targets.clear()
	PlayerState.blood_chain_turns = 0
	PlayerState.solo_seal_target = ""
	PlayerState.solo_seal_turns = 0
	PlayerState.berserk_turns = 0
	PlayerState.next_play_bonus_mult = 0.0
	PlayerState.hit_count_last_enemy_turn = 0
	PlayerState.was_hit_last_enemy_turn = false
	PlayerState.titanfist_uses = 0
