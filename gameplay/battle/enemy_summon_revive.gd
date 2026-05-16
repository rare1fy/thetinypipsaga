## 敌人召唤/复活机制 — 对齐原版 enemySummonRevive.ts
## 纯逻辑模块，不执行 UI 副作用（由调用方负责动画/音效）
##
## 召唤：每回合开始检查所有存活敌人的 SummonRule，满足条件 push 新敌人
## 复活：敌人 hp<=0 时检查 ReviveRule，满足条件回血或分裂

class_name EnemySummonRevive


## ============================================================
## 召唤
## ============================================================

class SummonResult:
	var new_minions: Array[EnemyInstance] = []
	var log: String = ""
	var summoner_uid: String = ""


## 检查并执行单个敌人的召唤
## 返回 SummonResult（new_minions 为空表示未触发）
static func try_summon(
	enemy: EnemyInstance,
	battle_turn: int,
	current_wave_size: int
) -> SummonResult:
	var result := SummonResult.new()
	result.summoner_uid = enemy.uid

	# 召唤物自身不能再召唤（防递归雪崩）
	if enemy.is_summoned:
		return result

	var config := EnemyConfig.get_config(enemy.config_id)
	if not config or config.summons == null:
		return result

	var rule: EnemyConfig.EnemySummon = config.summons
	var interval: int = maxi(1, rule.interval)
	var count: int = maxi(1, rule.count)
	var max_total: int = rule.max_total if rule.max_total > 0 else 4
	var wave_cap: int = rule.wave_cap if rule.wave_cap > 0 else 4

	# 频率检查
	if battle_turn < 1:
		return result
	if battle_turn % interval != 0:
		return result

	# 上限检查
	if enemy.summon_count >= max_total:
		return result
	if current_wave_size >= wave_cap:
		return result

	# HP 阈值检查（低于阈值才召唤）
	if rule.hp_threshold > 0.0 and enemy.max_hp > 0:
		if float(enemy.hp) / float(enemy.max_hp) > rule.hp_threshold:
			return result

	# 查找 minion 配置
	var minion_config := EnemyConfig.get_config(rule.minion_id)
	if not minion_config:
		return result

	# 计算实际召唤数量
	var slots_left: int = mini(count, mini(max_total - enemy.summon_count, wave_cap - current_wave_size))
	if slots_left <= 0:
		return result

	# 生成召唤物
	for i: int in slots_left:
		var minion := EnemyInstance.from_config(minion_config)
		minion.is_summoned = true
		result.new_minions.append(minion)

	# 更新召唤者计数
	enemy.summon_count += slots_left
	result.log = "%s 召唤了 %d 只 %s！" % [enemy.name, slots_left, minion_config.name]
	return result


## ============================================================
## 复活/分裂
## ============================================================

class ReviveResult:
	var revived_self: EnemyInstance = null  ## 直接复活后的本体（与 splits 互斥）
	var splits: Array[EnemyInstance] = []   ## 分裂出的多只敌人
	var log: String = ""


## 检查并执行死亡敌人的复活/分裂
## 返回 ReviveResult（revived_self 和 splits 都为空表示不复活）
static func try_revive(enemy: EnemyInstance) -> ReviveResult:
	var result := ReviveResult.new()

	# 已复活过的不再复活
	if enemy.revived_once:
		return result

	var config := EnemyConfig.get_config(enemy.config_id)
	if not config or config.revive == null:
		return result

	var rule: EnemyConfig.EnemyRevive = config.revive

	# 分裂模式
	if rule.split_into > 0:
		var split_config: EnemyConfig
		if rule.split_minion_id != "":
			split_config = EnemyConfig.get_config(rule.split_minion_id)
		else:
			split_config = config
		if not split_config:
			return result

		var each_hp: int = maxi(1, int(float(enemy.max_hp) * rule.revive_hp_ratio / float(rule.split_into)))
		for i: int in rule.split_into:
			var m := EnemyInstance.from_config(split_config)
			m.hp = each_hp
			m.max_hp = each_hp
			m.attack_dmg = maxi(1, int(enemy.attack_dmg * 0.7))
			m.revived_once = true
			m.is_summoned = true
			result.splits.append(m)

		result.log = "%s 在死亡的瞬间分裂成了 %d 只！" % [enemy.name, rule.split_into]
		return result

	# 直接复活模式
	var new_hp: int = maxi(1, int(float(enemy.max_hp) * rule.revive_hp_ratio))
	enemy.hp = new_hp
	enemy.armor = 0
	enemy.statuses.clear()
	enemy.revived_once = true
	result.revived_self = enemy
	result.log = "%s 拒绝死亡，重新站起（%d HP）！" % [enemy.name, new_hp]
	return result
