## 精英/Boss 增强逻辑 — 对齐原版 elites.ts
## 职责：
## - isElite / isBoss 纯判定函数
## - 精英/Boss 塞废骰子逻辑（碎裂骰/诅咒骰）
## - 精英/Boss 叠护甲逻辑

class_name EliteEnhancer


## ============================================================
## 配置常量（对齐原版 ELITE_CONFIG）
## ============================================================

const HP_THRESHOLD_ELITE: int = 80       ## maxHp > 此值 → 精英
const HP_THRESHOLD_BOSS: int = 200       ## maxHp > 此值 → Boss
const BOSS_CURSE_HP_RATIO: float = 0.4   ## hp/maxHp < 此值 → 诅咒骰子
const ARMOR_MULT_ELITE: float = 1.5      ## 精英护甲倍率（基于 attackDmg）
const ARMOR_MULT_BOSS: float = 2.0       ## Boss 护甲倍率
const ELITE_DICE_CYCLE: int = 3          ## 精英塞废骰周期
const BOSS_CURSE_CYCLE: int = 2          ## Boss 低HP诅咒周期
const BOSS_CRACKED_CYCLE: int = 3        ## Boss 塞碎裂骰周期
const ELITE_ARMOR_CYCLE: int = 3         ## 精英叠护甲周期
const BOSS_ARMOR_CYCLE: int = 2          ## Boss 叠护甲周期


## ============================================================
## 判定函数（优先用 config.category，fallback 到 HP 阈值）
## ============================================================

static func is_elite(e: EnemyInstance) -> bool:
	var cfg: EnemyConfig = EnemyConfig.get_config(e.config_id)
	if cfg != null:
		return cfg.category == EnemyConfig.EnemyCategory.ELITE
	return e.max_hp > HP_THRESHOLD_ELITE and e.max_hp <= HP_THRESHOLD_BOSS


static func is_boss(e: EnemyInstance) -> bool:
	var cfg: EnemyConfig = EnemyConfig.get_config(e.config_id)
	if cfg != null:
		return cfg.category == EnemyConfig.EnemyCategory.BOSS
	return e.max_hp > HP_THRESHOLD_BOSS


## ============================================================
## 塞废骰子（每回合开始对每个精英/Boss 检查）
## 返回 true 表示触发了效果
## ============================================================

static func process_elite_dice(e: EnemyInstance, battle_turn: int) -> bool:
	if battle_turn <= 0:
		return false
	var triggered: bool = false

	# 精英：每 ELITE_DICE_CYCLE 回合塞碎裂骰子
	if is_elite(e) and battle_turn % ELITE_DICE_CYCLE == 0:
		_stuff_dice(e, "cracked", "%s 塞入碎裂骰子！" % e.name)
		triggered = true

	# Boss：诅咒骰和碎裂骰独立判定（可同回合触发）
	if is_boss(e):
		var hp_ratio: float = float(e.hp) / float(e.max_hp) if e.max_hp > 0 else 1.0
		# 低HP时塞诅咒骰子
		if hp_ratio < BOSS_CURSE_HP_RATIO and battle_turn % BOSS_CURSE_CYCLE == 0:
			_stuff_dice(e, "cursed", "%s 施放诅咒！" % e.name)
			triggered = true
		# 碎裂骰子（独立判定，不与诅咒互斥）
		if battle_turn % BOSS_CRACKED_CYCLE == 0:
			_stuff_dice(e, "cracked", "%s 塞入碎裂骰子！" % e.name)
			triggered = true

	return triggered


static func _stuff_dice(e: EnemyInstance, def_id: String, toast_msg: String) -> void:
	DiceBag.owned_dice.append({"defId": def_id, "level": 1})
	DiceBag.dice_bag.append(def_id)
	VFX.show_toast(toast_msg, "damage")
	BattleLog.log_enemy("! %s" % toast_msg)
	SoundPlayer.play_sound("enemy_skill")


## ============================================================
## 叠护甲（每回合开始对每个精英/Boss 检查）
## 返回护甲增加量（0 表示未触发）
## ============================================================

static func process_elite_armor(e: EnemyInstance, battle_turn: int) -> int:
	if battle_turn <= 0:
		return 0

	# 精英叠护甲
	if is_elite(e) and battle_turn % ELITE_ARMOR_CYCLE == 0:
		var armor_val: int = int(float(e.attack_dmg) * ARMOR_MULT_ELITE)
		e.armor += armor_val
		BattleLog.log_enemy("[A] %s 凝聚了护甲（+%d）！" % [e.name, armor_val])
		SoundPlayer.play_sound("enemy_skill")
		return armor_val

	# Boss 叠护甲
	if is_boss(e) and battle_turn % BOSS_ARMOR_CYCLE == 0:
		var armor_val: int = int(float(e.attack_dmg) * ARMOR_MULT_BOSS)
		e.armor += armor_val
		BattleLog.log_enemy("[A] %s 释放了护盾（+%d 护甲）！" % [e.name, armor_val])
		SoundPlayer.play_sound("enemy_skill")
		return armor_val

	return 0
