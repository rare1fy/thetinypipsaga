## 运行时敌人实例 — 对应原版 types/entities.ts Enemy

class_name EnemyInstance
extends RefCounted

var uid: String = ""
var config_id: String = ""
var name: String = ""
var hp: int = 0
var max_hp: int = 0
var armor: int = 0
var attack_dmg: int = 0
var combat_type: GameTypes.EnemyCombatType = GameTypes.EnemyCombatType.WARRIOR
var description: String = ""
var drop_gold: int = 0
var drop_relic: bool = false
var drop_max_plays: int = 0
var drop_dice_count: int = 0
var reroll_reward: int = 0
var statuses: Array[StatusEffect] = []
var distance: int = 2
var attack_count: int = 0
var battle_turn: int = 0  ## 用于 pattern 决策


## 从配置创建敌人实例
static func from_config(config: EnemyConfig, hp_scale: float = 1.0, dmg_scale: float = 1.0) -> EnemyInstance:
	var e := EnemyInstance.new()
	e.uid = "enemy_%d_%d" % [randi(), Time.get_ticks_msec()]
	e.config_id = config.id
	e.name = config.name
	e.hp = int(config.base_hp * hp_scale)
	e.max_hp = e.hp
	e.armor = 0
	e.attack_dmg = int(config.base_dmg * dmg_scale)
	e.combat_type = config.combat_type
	e.drop_gold = config.drop_gold
	e.drop_relic = config.drop_relic
	e.reroll_reward = config.drop_reroll_reward
	e.statuses = []
	e.distance = 2 if (config.combat_type == GameTypes.EnemyCombatType.WARRIOR or config.combat_type == GameTypes.EnemyCombatType.GUARDIAN) else 3
	return e


## 执行敌人 pattern 决策
func get_action() -> Dictionary:
	var config := EnemyConfig.get_config(config_id)
	if not config:
		return { type = "攻击", value = attack_dmg, description = "" }
	for phase in config.phases:
		# hp_threshold > 0 代表"血量低于阈值才启用该阶段"，hp 仍高于阈值则跳过
		if phase.hp_threshold > 0 and hp >= max_hp * phase.hp_threshold:
			continue
		var actions: Array = phase.actions  # [RULES-B2-EXEMPT] EnemyConfig.EnemyAction 内部类跨文件引用不稳定
		if actions.is_empty():
			continue
		var idx: int = battle_turn % actions.size()
		var action = actions[idx]
		# scalable=true 时 value 随当前 attack_dmg 缩放，false 时用配置写死的 base_value
		var val: int
		if action.scalable:
			val = int(action.base_value * _dmg_scale())
		else:
			val = action.base_value
		return { type = _action_type_str(action.type), value = val, description = action.description }
	return { type = "攻击", value = attack_dmg }


func _dmg_scale() -> float:
	return float(attack_dmg) / float(EnemyConfig.get_config(config_id).base_dmg) if EnemyConfig.get_config(config_id) else 1.0


func _action_type_str(t: int) -> String:
	match t:
		0: return "攻击"
		1: return "防御"
		2: return "技能"
		_: return "攻击"


func is_frozen() -> bool:
	return statuses.any(func(s): return s.type == GameTypes.StatusType.FREEZE and s.duration > 0)


func is_slowed() -> bool:
	return statuses.any(func(s): return s.type == GameTypes.StatusType.SLOW and s.duration > 0)


func has_status(st: GameTypes.StatusType) -> bool:
	return statuses.any(func(s): return s.type == st)


func get_status_value(st: GameTypes.StatusType) -> int:
	for s in statuses:
		if s.type == st:
			return s.value
	return 0
