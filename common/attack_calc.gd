## 伤害计算器 — 对应原版 logic/attackCalc.ts
## 纯函数，计算敌人有效攻击力

class_name AttackCalc

# 常量
const ENEMY_ATTACK_MULT := {
	"warrior": 1.3,
	"rangerHit": 0.40,
	"rangerAttackCountStep": 2,
	"slow": 0.5,
}
const STATUS_EFFECT_MULT := {
	"weak": 0.75,
	"vulnerable": 1.5,
}


## 计算敌人有效攻击力
static func get_effective_attack_dmg(enemy: EnemyInstance, player_statuses: Array[StatusEffect], attack_count: int = 0, is_slowed: bool = false) -> int:
	var val := enemy.attack_dmg
	
	# 1. combatType 乘数
	var combat_str: String = GameTypes.EnemyCombatType.keys()[enemy.combat_type].to_lower()
	if combat_str == "warrior":
		val = int(val * ENEMY_ATTACK_MULT.warrior)
	if combat_str == "ranger":
		val = maxi(1, int(val * ENEMY_ATTACK_MULT.rangerHit) + attack_count)
		if is_slowed:
			val = int(val * ENEMY_ATTACK_MULT.slow)
	
	# 2. 力量加成
	var strength := enemy.get_status_value(GameTypes.StatusType.STRENGTH)
	if strength > 0:
		val += strength
	
	# 3. 虚弱修正
	if enemy.has_status(GameTypes.StatusType.WEAK):
		val = maxi(1, int(val * STATUS_EFFECT_MULT.weak))
	
	# 4. 玩家易伤修正
	for s in player_statuses:
		if s.type == GameTypes.StatusType.VULNERABLE and s.duration > 0:
			val = int(val * STATUS_EFFECT_MULT.vulnerable)
			break
	
	return val


## 计算 Ranger 追击伤害
static func get_ranger_follow_up_dmg(enemy: EnemyInstance, attack_count: int) -> int:
	return maxi(1, int(enemy.attack_dmg * ENEMY_ATTACK_MULT.rangerHit) + attack_count + 1)
