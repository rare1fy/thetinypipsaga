## 遗物定义（v2 — 数据驱动）
## 只保留基础属性 + effects 数组，所有效果行为由 EffectEngine 执行
## 新增遗物 = 填基础属性 + 从 EffectType 枚举挑效果配参数，不需要动代码

class_name RelicDef
extends Resource


# ============================================================
# CD 类型枚举
# ============================================================

enum CdType {
	PERMANENT = 0,   ## 永久生效（无CD）
	PER_TRIGGER = 1, ## 每次触发条件满足即触发
	TURN_CD = 2,     ## 每N回合可触发一次
	BATTLE_CD = 3,   ## 每场战斗可触发N次
	NODE_CD = 4,     ## 每N个地图节点可触发一次
	CONSUME = 5,     ## 一次性消耗（触发后移除遗物）
}


# ============================================================
# 基础属性
# ============================================================

@export var id: String = ""
@export var name: String = ""
@export var description: String = ""
@export var icon: String = ""
@export var rarity: GameTypes.RelicRarity = GameTypes.RelicRarity.COMMON

## 职业归属（空字符串=通用，"C01"=战士，"C02"=法师，"C03"=盗贼）
@export var class_type: String = ""

## 触发时机（决定 EffectEngine 何时执行此遗物的效果）
@export var trigger: GameTypes.RelicTrigger = GameTypes.RelicTrigger.PASSIVE

## 计数型遗物（如"每杀3个敌人触发一次"）
@export var counter: int = 0
@export var max_counter: int = 0
@export var counter_label: String = ""

## CD 类型 + 冷却值
@export var cd_type: CdType = CdType.PERMANENT
@export var cooldown: int = 0  ## 含义取决于 cd_type：回合数 / 战斗次数 / 节点数

## 是否一次性（触发后消耗）— 兼容旧字段，新数据用 cd_type = CONSUME
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
