## 状态效果服务 — 纯函数集合
## 负责：增/查/减 status effect
## 契约：所有方法均原地修改入参 statuses 数组，不返回新副本。

class_name StatusService
extends RefCounted


## 新增或叠加一个状态
## 规则：
##   - VULNERABLE（易伤）：层数累加，无上限，不走 duration 衰减
##   - ARCANE_DISRUPTION（法脉紊乱）：层数累加，无上限，不走 duration 衰减，不可净化
##   - 其他状态：同类取更高 value/duration（覆盖式）
## 直接修改入参 statuses，调用方无需写回
static func add(
	statuses: Array[StatusEffect],
	type: GameTypes.StatusType,
	value: int,
	duration: int
) -> void:
	# 层数累加型状态：易伤 / 法脉紊乱
	if type == GameTypes.StatusType.VULNERABLE or type == GameTypes.StatusType.ARCANE_DISRUPTION:
		for s in statuses:
			if s.type == type:
				s.value += value
				s.duration = 999  # 不走 duration 衰减，走层数衰减
				return
		var new_status := StatusEffect.new()
		new_status.type = type
		new_status.value = value
		new_status.duration = 999
		statuses.append(new_status)
		return
	# 其他状态：覆盖式（取大值）
	for s in statuses:
		if s.type == type:
			s.value = maxi(s.value, value)
			s.duration = maxi(s.duration, duration)
			return
	var new_status := StatusEffect.new()
	new_status.type = type
	new_status.value = value
	new_status.duration = duration
	statuses.append(new_status)


## 判断是否持有某状态（duration > 0）
static func has(statuses: Array[StatusEffect], type: GameTypes.StatusType) -> bool:
	return statuses.any(func(s): return s.type == type and s.duration > 0)


## 取某状态的 value（不存在返回 0）
static func get_value(statuses: Array[StatusEffect], type: GameTypes.StatusType) -> int:
	for s in statuses:
		if s.type == type:
			return s.value
	return 0


## 所有状态 duration -1，清理到期项（不含易伤/法脉紊乱，走层数衰减）
## 直接修改入参 statuses
static func tick(statuses: Array[StatusEffect]) -> void:
	var to_remove: Array[int] = []
	for i in statuses.size():
		# 易伤 / 法脉紊乱不走 duration 衰减
		if statuses[i].type == GameTypes.StatusType.VULNERABLE \
			or statuses[i].type == GameTypes.StatusType.ARCANE_DISRUPTION:
			continue
		statuses[i].duration -= 1
		if statuses[i].duration <= 0:
			to_remove.append(i)
	for i in range(to_remove.size() - 1, -1, -1):
		statuses.remove_at(to_remove[i])


## 易伤层数衰减：每敌方回合结束 -1 层，归 0 时移除
## 直接修改入参 statuses
static func tick_vulnerable(statuses: Array[StatusEffect]) -> void:
	var to_remove: Array[int] = []
	for i in statuses.size():
		if statuses[i].type == GameTypes.StatusType.VULNERABLE:
			statuses[i].value -= GameBalance.VULNERABLE_CONFIG.decay_per_enemy_turn
			if statuses[i].value <= 0:
				to_remove.append(i)
	for i in range(to_remove.size() - 1, -1, -1):
		statuses.remove_at(to_remove[i])


## 法脉紊乱：出牌时完全重置（归零移除）
## 直接修改入参 statuses
static func clear_arcane_disruption(statuses: Array[StatusEffect]) -> void:
	for i in range(statuses.size() - 1, -1, -1):
		if statuses[i].type == GameTypes.StatusType.ARCANE_DISRUPTION:
			statuses.remove_at(i)


## 法脉紊乱：降低指定层数（星界共鸣符文骰持有效果）
## 返回实际降低的层数（用于日志/飘字）
static func reduce_arcane_disruption(statuses: Array[StatusEffect], amount: int) -> int:
	for s: StatusEffect in statuses:
		if s.type == GameTypes.StatusType.ARCANE_DISRUPTION:
			var actual: int = mini(s.value, amount)
			s.value -= actual
			if s.value <= 0:
				statuses.erase(s)
			return actual
	return 0


## 法脉紊乱：消耗全部层数并返回消耗的层数（星界共鸣打出效果）
static func consume_arcane_disruption(statuses: Array[StatusEffect]) -> int:
	for i in range(statuses.size() - 1, -1, -1):
		if statuses[i].type == GameTypes.StatusType.ARCANE_DISRUPTION:
			var consumed: int = statuses[i].value
			statuses.remove_at(i)
			return consumed
	return 0