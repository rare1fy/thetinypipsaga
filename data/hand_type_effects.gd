## 牌型效果配置表 — 数据驱动
## 所有牌型的附带效果统一用 EffectTypes 描述
## 新增/修改牌型效果 = 改这张表，不动代码
##
## 每个牌型条目：
##   effects: Array[Dictionary]  — 效果列表（EffectTypes.create_effect 格式）
##   is_aoe: bool                — 是否为 AOE 牌型
##   display_status: String      — UI 显示的状态文本（给 DamagePreview 用）
##   display_armor: int          — UI 显示的护甲值（给 DamagePreview 用）

class_name HandTypeEffects


# ============================================================
# 牌型效果配置
# ============================================================

static var _cache: Dictionary = {}

static func get_all() -> Dictionary:
	if not _cache.is_empty():
		return _cache
	_cache = {
		# ---- 基础牌型 ----
		"普通攻击": _entry([], false),

		"对子": _entry([], false),

		"连对": _entry([
			EffectTypes.create_effect(
				EffectTypes.EffectType.ARMOR, {value = 5},
				EffectTypes.TriggerType.ON_PLAY, EffectTypes.EffectScope.INSTANT,
				EffectTypes.StackingRule.INDEPENDENT, EffectTypes.TargetScope.SELF
			),
		], false, "", 5),

		"三连对": _entry([
			EffectTypes.create_effect(
				EffectTypes.EffectType.ARMOR, {value = 8},
				EffectTypes.TriggerType.ON_PLAY, EffectTypes.EffectScope.INSTANT,
				EffectTypes.StackingRule.INDEPENDENT, EffectTypes.TargetScope.SELF
			),
		], true, "", 8),

		"三条": _entry([
			EffectTypes.create_effect(
				EffectTypes.EffectType.APPLY_STATUS, {status = "vulnerable", value = 1, target = "enemy"},
				EffectTypes.TriggerType.ON_PLAY, EffectTypes.EffectScope.INSTANT,
				EffectTypes.StackingRule.INDEPENDENT, EffectTypes.TargetScope.MAIN
			),
], false, "易伤x1（3回合）"),

		"四条": _entry([
			EffectTypes.create_effect(
				EffectTypes.EffectType.APPLY_STATUS, {status = "vulnerable", value = 2, target = "enemy"},
				EffectTypes.TriggerType.ON_PLAY, EffectTypes.EffectScope.INSTANT,
				EffectTypes.StackingRule.INDEPENDENT, EffectTypes.TargetScope.MAIN
			),
], true, "易伤x2（3回合）"),

		"五条": _entry([], true),

		"六条": _entry([], true),

		# ---- 顺子系 ----
		"顺子": _entry([], true),

		"4顺": _entry([
			EffectTypes.create_effect(
				EffectTypes.EffectType.APPLY_STATUS, {status = "weak", value = 1, target = "enemy"},
				EffectTypes.TriggerType.ON_PLAY, EffectTypes.EffectScope.INSTANT,
				EffectTypes.StackingRule.INDEPENDENT, EffectTypes.TargetScope.MAIN
			),
		], true, "虚弱x1（1回合）"),

		"5顺": _entry([
			EffectTypes.create_effect(
				EffectTypes.EffectType.APPLY_STATUS, {status = "weak", value = 2, target = "enemy"},
				EffectTypes.TriggerType.ON_PLAY, EffectTypes.EffectScope.INSTANT,
				EffectTypes.StackingRule.INDEPENDENT, EffectTypes.TargetScope.MAIN
			),
		], true, "虚弱x2（1回合）"),

		"6顺": _entry([
			EffectTypes.create_effect(
				EffectTypes.EffectType.ARMOR, {value = 10},
				EffectTypes.TriggerType.ON_PLAY, EffectTypes.EffectScope.INSTANT,
				EffectTypes.StackingRule.INDEPENDENT, EffectTypes.TargetScope.SELF
			),
			EffectTypes.create_effect(
				EffectTypes.EffectType.APPLY_STATUS, {status = "weak", value = 3, target = "enemy"},
				EffectTypes.TriggerType.ON_PLAY, EffectTypes.EffectScope.INSTANT,
				EffectTypes.StackingRule.INDEPENDENT, EffectTypes.TargetScope.MAIN
			),
		], true, "虚弱x3（1回合）", 10),

		# ---- 葫芦系（真实伤害 + 无视嘲讽）----
		"葫芦": _entry([
			EffectTypes.create_effect(
				EffectTypes.EffectType.TRUE_DAMAGE, {},
				EffectTypes.TriggerType.ON_PLAY, EffectTypes.EffectScope.PLAY,
				EffectTypes.StackingRule.INDEPENDENT, EffectTypes.TargetScope.MAIN
			),
			EffectTypes.create_effect(
				EffectTypes.EffectType.IGNORE_TAUNT, {},
				EffectTypes.TriggerType.ON_PLAY, EffectTypes.EffectScope.PLAY,
				EffectTypes.StackingRule.INDEPENDENT, EffectTypes.TargetScope.SELF
			),
		], false, "真实伤害（无视护甲+减伤）"),

		"大葫芦": _entry([
			EffectTypes.create_effect(
				EffectTypes.EffectType.TRUE_DAMAGE, {},
				EffectTypes.TriggerType.ON_PLAY, EffectTypes.EffectScope.PLAY,
				EffectTypes.StackingRule.INDEPENDENT, EffectTypes.TargetScope.MAIN
			),
			EffectTypes.create_effect(
				EffectTypes.EffectType.IGNORE_TAUNT, {},
				EffectTypes.TriggerType.ON_PLAY, EffectTypes.EffectScope.PLAY,
				EffectTypes.StackingRule.INDEPENDENT, EffectTypes.TargetScope.SELF
			),
		], false, "真实伤害（无视护甲+减伤）"),

		# ---- 元素系（AOE + 同元素护甲转化在 apply 时处理）----
		"同元素": _entry([], false, "", 0, true),

		"元素顺": _entry([], true, "", 0, true),

		"元素葫芦": _entry([
			EffectTypes.create_effect(
				EffectTypes.EffectType.TRUE_DAMAGE, {},
				EffectTypes.TriggerType.ON_PLAY, EffectTypes.EffectScope.PLAY,
				EffectTypes.StackingRule.INDEPENDENT, EffectTypes.TargetScope.MAIN
			),
			EffectTypes.create_effect(
				EffectTypes.EffectType.IGNORE_TAUNT, {},
				EffectTypes.TriggerType.ON_PLAY, EffectTypes.EffectScope.PLAY,
				EffectTypes.StackingRule.INDEPENDENT, EffectTypes.TargetScope.SELF
			),
		], true, "真实伤害（无视护甲+减伤）", 0, true),

		"皇家元素顺": _entry([], true, "", 0, true),
	}
	return _cache


# ============================================================
# 查询接口
# ============================================================

## 获取指定牌型的效果列表
static func get_effects(hand_name: String) -> Array[Dictionary]:
	var table: Dictionary = get_all()
	var entry: Dictionary = table.get(hand_name, {})
	return entry.get("effects", []) as Array[Dictionary]


## 判断牌型是否为 AOE
static func is_aoe_hand(hand_name: String) -> bool:
	var table: Dictionary = get_all()
	var entry: Dictionary = table.get(hand_name, {})
	return entry.get("is_aoe", false)


## 判断激活的牌型列表中是否有 AOE
static func has_aoe_in_active(active_hands: Array[String]) -> bool:
	var table: Dictionary = get_all()
	for h: String in active_hands:
		var entry: Dictionary = table.get(h, {})
		if entry.get("is_aoe", false):
			return true
	return false


## 判断是否包含同元素系牌型（§6.6 第 2 级：baseDamage 转护甲）
static func has_elemental_hand(active_hands: Array[String]) -> bool:
	var table: Dictionary = get_all()
	for h: String in active_hands:
		var entry: Dictionary = table.get(h, {})
		if entry.get("is_elemental", false):
			return true
	return false


## 判断牌型是否标记为真实伤害
static func has_true_damage(hand_name: String) -> bool:
	var effs: Array[Dictionary] = get_effects(hand_name)
	for eff: Dictionary in effs:
		if eff.get("type", -1) == EffectTypes.EffectType.TRUE_DAMAGE:
			return true
	return false


## 判断牌型是否标记为无视嘲讽
static func has_ignore_taunt(hand_name: String) -> bool:
	var effs: Array[Dictionary] = get_effects(hand_name)
	for eff: Dictionary in effs:
		if eff.get("type", -1) == EffectTypes.EffectType.IGNORE_TAUNT:
			return true
	return false


## 获取 UI 显示用的效果表（兼容旧 HAND_EFFECT_TABLE 格式）
static func get_display_table() -> Dictionary:
	var table: Dictionary = get_all()
	var result: Dictionary = {}
	for hand_name: String in table:
		var entry: Dictionary = table[hand_name]
		result[hand_name] = {
			"armor": entry.get("display_armor", 0),
			"status": entry.get("display_status", ""),
		}
	return result


# ============================================================
# 内部辅助
# ============================================================

## 构建一条牌型配置条目
static func _entry(
	effects: Array[Dictionary] = [],
	is_aoe: bool = false,
	display_status: String = "",
	display_armor: int = 0,
	is_elemental: bool = false,
) -> Dictionary:
	return {
		"effects": effects,
		"is_aoe": is_aoe,
		"is_elemental": is_elemental,
		"display_status": display_status,
		"display_armor": display_armor,
	}
