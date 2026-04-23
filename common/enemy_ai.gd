## 敌人AI系统 — 对应原版 logic/enemyAI.ts
## 管理敌人回合行动逻辑

class_name EnemyAI

const GUARDIAN_CONFIG := {"shieldMult": 1.5, "defenseCycle": 2}
const ANIM_TIMING := {"enemyDeathCleanupDelay": 2200, "waveTransitionDeathBuffer": 400}


## 执行敌人回合（由 BattleScene 调用，通过回调驱动UI）
## 返回 {hp: int, gameOver: bool}
static func execute_enemy_turn(game: Node, enemies: Array[EnemyInstance], _dice: Array[Dictionary]) -> Dictionary:
	# 标记敌人回合
	game.is_enemy_turn = true
	
	# 1. 玩家中毒结算
	var poison := game.get_status_value(GameTypes.StatusType.POISON)
	if poison > 0:
		game.take_damage(poison)
		game.add_status(GameTypes.StatusType.POISON, poison - 1, 1)  # 递减
		if game.hp <= 0:
			return {"hp": 0, "gameOver": true}
	
	# 2. 敌人灼烧结算
	var all_dead_from_dot := _settle_burn(enemies)
	if all_dead_from_dot:
		return {"hp": game.hp, "gameOver": false, "waveTransition": true}
	
	# 3. 敌人中毒结算
	all_dead_from_dot = _settle_poison(enemies)
	if all_dead_from_dot:
		return {"hp": game.hp, "gameOver": false, "waveTransition": true}
	
	# 4. 每个存活敌人执行AI决策
	for e in enemies:
		if e.hp <= 0:
			continue
		
		# 冻结跳过
		if e.is_frozen():
			continue
		
		# 近战移动
		var is_melee := e.combat_type == GameTypes.EnemyCombatType.WARRIOR or e.combat_type == GameTypes.EnemyCombatType.GUARDIAN
		var is_slowed := e.is_slowed()
		
		if is_melee and e.distance > 0:
			if is_slowed:
				continue  # 减速无法移动
			e.distance = maxi(0, e.distance - 1)
			continue
		
		# Guardian: 攻防交替+嘲讽
		if e.combat_type == GameTypes.EnemyCombatType.GUARDIAN:
			if game.battle_turn % GUARDIAN_CONFIG.defenseCycle == 0:
				var shield_val := int(e.attack_dmg * GUARDIAN_CONFIG.shieldMult)
				e.armor += shield_val
				game.target_enemy_uid = e.uid
				continue
		
		# Priest: 治疗/增益/减益
		if e.combat_type == GameTypes.EnemyCombatType.PRIEST:
			_execute_priest_action(e, enemies, game)
			continue
		
		# Caster: DoT
		if e.combat_type == GameTypes.EnemyCombatType.CASTER:
			_execute_caster_action(e, game)
			continue
		
		# Warrior/Ranger: 攻击
		_execute_attack(e, game)
	
	# 5. 敌人回合结束
	game.battle_turn += 1
	game.is_enemy_turn = false
	
	# 灼烧结算
	var burn := game.get_status_value(GameTypes.StatusType.BURN)
	if burn > 0:
		game.take_damage(burn)
		# 灼烧一次性
		var new_statuses: Array[StatusEffect] = []
		for s in game.statuses:
			if s.type != GameTypes.StatusType.BURN:
				new_statuses.append(s)
		game.statuses = new_statuses
		if game.hp <= 0:
			return {"hp": 0, "gameOver": true}
	
	# 状态递减
	game.tick_statuses()
	
	return {"hp": game.hp, "gameOver": false}


## 灼烧DOT结算
static func _settle_burn(enemies: Array[EnemyInstance]) -> bool:
	var all_dead := true
	for e in enemies:
		if e.hp <= 0:
			continue
		for s in e.statuses:
			if s.type == GameTypes.StatusType.BURN and s.value > 0:
				e.hp = maxi(0, e.hp - s.value)
				s.value = 0
		if e.hp > 0:
			all_dead = false
	return all_dead and enemies.size() > 0


## 中毒DOT结算
static func _settle_poison(enemies: Array[EnemyInstance]) -> bool:
	var all_dead := true
	for e in enemies:
		if e.hp <= 0:
			continue
		for s in e.statuses:
			if s.type == GameTypes.StatusType.POISON and s.value > 0:
				e.hp = maxi(0, e.hp - s.value)
				s.duration -= 1
		# 移除过期状态
		e.statuses = e.statuses.filter(func(s): return s.duration > 0)
		if e.hp > 0:
			all_dead = false
	return all_dead and enemies.size() > 0


## 执行攻击
static func _execute_attack(e: EnemyInstance, game: Node) -> void:
	var damage := AttackCalc.get_effective_attack_dmg(e, game.statuses, e.attack_count, e.is_slowed())
	game.take_damage(damage)
	e.attack_count += 1
	
	# Ranger 追击
	if e.combat_type == GameTypes.EnemyCombatType.RANGER:
		var second_hit := AttackCalc.get_ranger_follow_up_dmg(e, e.attack_count)
		game.take_damage(second_hit)


## Priest行动
static func _execute_priest_action(e: EnemyInstance, allies: Array[EnemyInstance], game: Node) -> void:
	# 优先治疗血量最低的盟友
	var wounded_allies := allies.filter(func(a): return a.hp > 0 and a.uid != e.uid and a.hp < a.max_hp)
	wounded_allies.sort_custom(func(a, b): return a.hp < b.hp)
	
	if wounded_allies.size() > 0 and randf() < 0.5:
		var target := wounded_allies[0] as EnemyInstance
		var heal_amount := int(e.attack_dmg * 4.0)
		target.hp = mini(target.max_hp, target.hp + heal_amount)
	elif randf() < 0.35:
		# 施加虚弱
		game.add_status(GameTypes.StatusType.WEAK, 1, 3)
	else:
		# 施加易伤
		game.add_status(GameTypes.StatusType.VULNERABLE, 1, 3)


## Caster行动
static func _execute_caster_action(e: EnemyInstance, game: Node) -> void:
	if randf() < 0.4:
		# 施加中毒
		var poison_val := maxi(2, int(e.attack_dmg * 0.4))
		game.add_status(GameTypes.StatusType.POISON, poison_val, 3)
	else:
		# 施加灼烧
		var burn_val := maxi(1, int(e.attack_dmg * 0.3))
		game.add_status(GameTypes.StatusType.BURN, burn_val, 3)
