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

## P2 新增：召唤/复活/archetype
var summon_count: int = 0       ## 已召唤次数
var revived_once: bool = false  ## 是否已复活过（防止无限复活）
var is_summoned: bool = false   ## 是否为召唤物（召唤物不能再召唤）
var archetype: String = ""      ## 敌人子类型（pyromancer/toxicologist/healer/inquisitor 等）
var dot_amplifier: int = 0      ## Caster DOT 放大层数
var holy_wrath: int = 0         ## Priest 圣怒层数
var guard_rage: int = 0         ## Guardian 防御怒气层数
var blood_fury: int = 0         ## Warrior 血怒层数（受伤后累加，每层+25%攻击）
var vengeance_stacks: int = 0   ## Berserker 复仇层数（队友死亡时+50%/层）

## v0.5 控制状态 — 统一用 Dictionary 管理，key = 控制类型名, value = 剩余回合数
## 注意：ControlSystem 直接操作 cc_turns 字典（唯一写入入口）
## 下方属性访问器仅供外部模块只读查询使用
var cc_turns: Dictionary = {}  ## {"taunt": 2, "stun": 1, ...}
var cc_immunity: bool = false   ## 配置级免控标记

## 控制状态只读便捷访问器（写入请通过 ControlSystem.apply_control）
var cc_taunt_turns: int:
	get: return cc_turns.get("taunt", 0)
	set(v): cc_turns["taunt"] = v if v > 0 else cc_turns.erase("taunt")
var cc_stun_turns: int:
	get: return cc_turns.get("stun", 0)
	set(v): cc_turns["stun"] = v if v > 0 else cc_turns.erase("stun")
var cc_polymorph_turns: int:
	get: return cc_turns.get("polymorph", 0)
	set(v): cc_turns["polymorph"] = v if v > 0 else cc_turns.erase("polymorph")
var cc_blind_turns: int:
	get: return cc_turns.get("blind", 0)
	set(v): cc_turns["blind"] = v if v > 0 else cc_turns.erase("blind")
var cc_disarm_turns: int:
	get: return cc_turns.get("disarm", 0)
	set(v): cc_turns["disarm"] = v if v > 0 else cc_turns.erase("disarm")


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
		var result: Dictionary = { type = _action_type_str(action.type), value = val, description = action.description }
		# [v2] 携带 effects 数组 — 非空时 EnemyActionResolver 直接走 EffectEngine
		if not action.effects.is_empty():
			result["effects"] = action.effects
		return result
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