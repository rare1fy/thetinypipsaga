## 骰子定义资源（v2 — 数据驱动）
## 只保留基础属性 + effects 数组，所有效果行为由 EffectEngine 执行
## 新增骰子 = 填基础属性 + 从 EffectType 枚举挑效果配参数，不需要动代码

class_name DiceDef
extends Resource


# ============================================================
# 基础属性（~15个字段，不可再精简）
# ============================================================

@export var id: String = ""
@export var name: String = ""
@export var element: GameTypes.DiceElement = GameTypes.DiceElement.NORMAL
@export var faces: Array[int] = [1, 2, 3, 4, 5, 6]
@export var description: String = ""
@export var rarity: GameTypes.DiceRarity = GameTypes.DiceRarity.COMMON

## 骰子分类标记
@export var is_elemental: bool = false
@export var is_cursed: bool = false
@export var is_cracked: bool = false
@export var is_rune: bool = false
@export var ignore_for_hand_type: bool = false  ## 符文骰不参与牌型判定
@export var copy_majority_element: bool = false  ## 共鸣骰：复制手牌中最多的元素
@export var dual_element: bool = false           ## 棱镜骰：双元素坍缩

## 职业归属（用于UI分类和职业限制）
@export var class_type: String = ""  # "warrior" / "mage" / "rogue" / ""

## 升级相关
@export var level: int = 1
@export var max_level: int = 3


# ============================================================
# 效果数组（核心：所有行为由此描述）
# ============================================================

## 骰子携带的全部效果列表
## 每个元素是一个 Dictionary，格式遵循 EffectTypes.create_effect() 的输出
## 示例：
##   [
##     {type: BONUS_DAMAGE_SCALED, trigger: ON_PLAY, scope: PLAY, params: {source:"points", ratio:0.5}},
##     {type: CONTROL, trigger: ON_PLAY, scope: INSTANT, params: {control:"stun", duration:1, target:"main"}},
##   ]
@export var effects: Array[Dictionary] = []


# ============================================================
# 辅助方法
# ============================================================

## 判断是否有指定触发时机的效果
func has_effects_for_trigger(trigger: EffectTypes.TriggerType) -> bool:
	for effect: Dictionary in effects:
		if effect.get("trigger", -1) == trigger:
			return true
	return false


## 获取指定触发时机的效果列表
func get_effects_for_trigger(trigger: EffectTypes.TriggerType) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for effect: Dictionary in effects:
		if effect.get("trigger", -1) == trigger:
			result.append(effect)
	return result


## 判断是否有 onPlay 效果（兼容旧接口）
func has_on_play() -> bool:
	return has_effects_for_trigger(EffectTypes.TriggerType.ON_PLAY)


## 获取骰子点数总和
func get_points_total() -> int:
	var total: int = 0
	for face: int in faces:
		total += face
	return total


## 获取骰子平均点数
func get_points_avg() -> float:
	if faces.is_empty():
		return 0.0
	return float(get_points_total()) / float(faces.size())


## 获取用于 UI 显示的描述文本
## 优先从 effects[] 自动生成，fallback 到旧 description 字段
func get_display_description() -> String:
	if not effects.is_empty():
		var lines: Array[String] = EffectTypes.describe_effects(effects)
		if not lines.is_empty():
			return " / ".join(lines)
	return description


## 校验所有效果的参数完整性（开发期调用）
func validate_all_effects() -> bool:
	var all_valid: bool = true
	for effect: Dictionary in effects:
		if not EffectTypes.validate_params(effect):
			push_error("[DiceDef:%s] 效果校验失败" % id)
			all_valid = false
	return all_valid
