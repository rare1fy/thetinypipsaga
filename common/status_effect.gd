## 状态效果数据类

class_name StatusEffect
extends Resource

@export var type: GameTypes.StatusType = GameTypes.StatusType.POISON
@export var value: int = 0
@export var duration: int = 0

func _to_string() -> String:
	return "StatusEffect(%s, val=%d, dur=%d)" % [GameTypes.StatusType.keys()[type], value, duration]
