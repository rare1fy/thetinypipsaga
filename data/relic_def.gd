## 遗物定义（v2 — 数据驱动）
## 只保留基础属性 + effects 数组，所有效果行为由 EffectEngine 执行
## 新增遗物 = 填基础属性 + 从 EffectType 枚举挑效果配参数，不需要动代码

class_name RelicDef
extends Resource


# ============================================================
# 基础属性
# ============================================================

@export var id: String = ""
@export var name: String = ""
@export var description: String = ""
@export var icon: String = ""
@export var rarity: GameTypes.RelicRarity = GameTypes.RelicRarity.COMMON

## 触发时机（决定 EffectEngine 何时执行此遗物的效果）
@export var trigger: GameTypes.RelicTrigger = GameTypes.RelicTrigger.PASSIVE

## 计数型遗物（如"每杀3个敌人触发一次"）
@export var counter: int = 0
@export var max_counter: int = 0
@export var counter_label: String = ""

## 冷却（如"每N回合触发一次"）
@export var cooldown: int = 0

## 是否一次性（触发后消耗）
@export var consumable: bool = false


# ============================================================
# 效果数组（核心：所有行为由此描述）
# ============================================================

## 遗物携带的全部效果列表
## 格式遵循 EffectTypes.create_effect() 的输出
## 示例：
##   [
##     {type: MODIFY_DRAW_COUNT, trigger: ON_BATTLE_START, scope: BATTLE, params: {delta: 1}},
##     {type: ARMOR_PER_TURN, trigger: ON_TURN_START, scope: BATTLE, params: {value: 3}},
##   ]
@export var effects: Array[Dictionary] = []


# ============================================================
# 辅助方法
# ============================================================

## 判断是否有指定触发时机的效果
func has_effects_for_trigger(trigger_type: EffectTypes.TriggerType) -> bool:
	for effect: Dictionary in effects:
		if effect.get("trigger", -1) == trigger_type:
			return true
	return false


## 获取指定触发时机的效果列表
func get_effects_for_trigger(trigger_type: EffectTypes.TriggerType) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for effect: Dictionary in effects:
		if effect.get("trigger", -1) == trigger_type:
			result.append(effect)
	return result


## 校验所有效果的参数完整性（开发期调用）
func validate_all_effects() -> bool:
	var all_valid: bool = true
	for effect: Dictionary in effects:
		if not EffectTypes.validate_params(effect):
			push_error("[RelicDef:%s] 效果校验失败" % id)
			all_valid = false
	return all_valid
