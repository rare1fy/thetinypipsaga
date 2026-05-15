## 敌人 Trait 系统 — 对齐原版 enemyTraits.ts
## 五职业 + 子类型（archetype）的递增 trait 维护
##
## bloodFury: Warrior 受伤后 +25%/层 攻击（berserker +40%/层），封顶 4 层
## guardRage: Guardian 防御后 +60%/层 攻击（bulwark 不爆发），封顶 3 层
## dotAmplifier: Caster DOT ×1.4/层（pyromancer ×1.5/层），封顶 4 层
## holyWrath: Priest 每 2 回合 +1，影响 debuff 持续和护甲祝福加成，封顶 4 层
##
## BOSS 走自身 phase[hpThreshold] 阶段递进，不叠 trait

class_name EnemyTraits

## ============================================================
## 常量
## ============================================================

const BLOOD_FURY_CAP: int = 4
const BLOOD_FURY_PER_STACK: float = 0.25
const GUARD_RAGE_CAP: int = 3
const GUARD_RAGE_PER_STACK: float = 0.6
const DOT_AMPLIFIER_CAP: int = 4
const DOT_AMPLIFIER_PER_STACK: float = 0.4
const HOLY_WRATH_CAP: int = 4
const VENGEANCE_PER_STACK: float = 0.5


## BOSS 不叠 trait（走自身阶段递进）
static func should_apply_trait(e: EnemyInstance) -> bool:
	return not e.config_id.begins_with("boss_")


## ============================================================
## Trait 累加
## ============================================================

## Warrior 受伤后累计 bloodFury（berserker +40%/层，paladin 不叠）
static func apply_blood_fury_on_hurt(e: EnemyInstance) -> void:
	if not should_apply_trait(e):
		return
	if e.combat_type != GameTypes.EnemyCombatType.WARRIOR:
		return
	if e.archetype == "paladin":
		return
	if e.blood_fury >= BLOOD_FURY_CAP:
		return
	e.blood_fury += 1


## Berserker 复仇：队友死亡时 +1 层（每层 +50% 攻击）
static func apply_vengeance_on_ally_death(e: EnemyInstance) -> void:
	if not should_apply_trait(e):
		return
	if e.combat_type != GameTypes.EnemyCombatType.WARRIOR:
		return
	if e.archetype != "berserker":
		return
	e.vengeance_stacks += 1


## Guardian 防御后累计 guardRage（bulwark 不爆发）
static func apply_guard_rage_on_defend(e: EnemyInstance) -> void:
	if not should_apply_trait(e):
		return
	if e.combat_type != GameTypes.EnemyCombatType.GUARDIAN:
		return
	if e.archetype == "bulwark":
		return
	if e.guard_rage >= GUARD_RAGE_CAP:
		return
	e.guard_rage += 1


## Guardian 攻击后清空 guardRage
static func consume_guard_rage_on_attack(e: EnemyInstance) -> void:
	e.guard_rage = 0


## Caster DOT 放大累加
static func bump_dot_amplifier(e: EnemyInstance) -> void:
	if not should_apply_trait(e):
		return
	if e.combat_type != GameTypes.EnemyCombatType.CASTER:
		return
	if e.archetype == "cursemaster":
		return
	if e.dot_amplifier >= DOT_AMPLIFIER_CAP:
		return
	e.dot_amplifier += 1


## Priest 圣怒：每 2 回合 +1
static func bump_holy_wrath_per_turn(e: EnemyInstance, battle_turn: int) -> void:
	if not should_apply_trait(e):
		return
	if e.combat_type != GameTypes.EnemyCombatType.PRIEST:
		return
	if battle_turn == 0 or battle_turn % 2 != 0:
		return
	if e.holy_wrath >= HOLY_WRATH_CAP:
		return
	e.holy_wrath += 1


## ============================================================
## 攻击力修正（被 AttackCalc 调用）
## ============================================================

## trait 与 archetype 联合的攻击力修正乘数
static func attack_trait_multiplier(e: EnemyInstance) -> float:
	var mul: float = 1.0

	# guardRage：每层 +60%
	if e.combat_type == GameTypes.EnemyCombatType.GUARDIAN and e.guard_rage > 0:
		mul *= 1.0 + GUARD_RAGE_PER_STACK * float(e.guard_rage)

	# bloodFury：每层 +25%（berserker +40%/层）
	if e.combat_type == GameTypes.EnemyCombatType.WARRIOR and e.blood_fury > 0:
		var per_stack: float = 0.40 if e.archetype == "berserker" else BLOOD_FURY_PER_STACK
		mul *= 1.0 + per_stack * float(e.blood_fury)

	# berserker vengeance：每层 +50%
	if e.combat_type == GameTypes.EnemyCombatType.WARRIOR and e.vengeance_stacks > 0:
		mul *= 1.0 + VENGEANCE_PER_STACK * float(e.vengeance_stacks)

	# archetype 静态修正
	if e.combat_type == GameTypes.EnemyCombatType.WARRIOR:
		if e.archetype == "paladin":
			mul *= 1.2

	if e.combat_type == GameTypes.EnemyCombatType.RANGER:
		if e.archetype == "marksman":
			mul *= 1.3

	return mul


## Caster DOT 加成倍率
static func get_dot_multiplier(e: EnemyInstance) -> float:
	if not should_apply_trait(e):
		return 1.0
	if e.combat_type != GameTypes.EnemyCombatType.CASTER:
		return 1.0
	var mul: float = 1.0
	if e.dot_amplifier > 0:
		var per_stack: float = 0.5 if e.archetype == "pyromancer" else DOT_AMPLIFIER_PER_STACK
		mul *= 1.0 + per_stack * float(e.dot_amplifier)
	return mul


## Guardian bulwark 防御获双倍护甲
static func archetype_armor_boost(e: EnemyInstance) -> float:
	if e.combat_type == GameTypes.EnemyCombatType.GUARDIAN and e.archetype == "bulwark":
		return 2.0
	return 1.0
