## 状态效果服务 — 纯函数集合
## 负责：增/查/减 status effect
## 契约：所有方法均原地修改入参 statuses 数组，不返回新副本。

class_name StatusService
extends RefCounted


## 新增或叠加一个状态（同类取更高 value/duration）
## 直接修改入参 statuses，调用方无需写回
static func add(
	statuses: Array[StatusEffect],
	type: GameTypes.StatusType,
	value: int,
	duration: int
) -> void:
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


## 所有状态 duration -1，清理到期项
## 直接修改入参 statuses
static func tick(statuses: Array[StatusEffect]) -> void:
	var to_remove: Array[int] = []
	for i in statuses.size():
		statuses[i].duration -= 1
		if statuses[i].duration <= 0:
			to_remove.append(i)
	for i in range(to_remove.size() - 1, -1, -1):
		statuses.remove_at(to_remove[i])
