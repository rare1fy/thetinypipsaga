## 伤害预览面板 — 对应原版 expectedOutcome 在 UI 层的呈现
## 选中骰子变化时调用 refresh(selected_dice) 即可刷新
## 只展示信息，不修改任何游戏状态

class_name DamagePreview
extends PanelContainer

const HandTypeEffects := preload("res://data/hand_type_effects.gd")

# UI 子节点
var _hand_label: Label = null           # 当前牌型
var _damage_label: Label = null         # 预计伤害
var _armor_label: Label = null          # 护甲（仅有时显示）
var _status_label: Label = null         # 状态效果提示
var _aoe_label: Label = null            # AOE 提示（仅雷元素 / 特定牌型）

# 牌型附带护甲/状态表 — 从 HandTypeEffects 配置表读取（延迟计算，避免缓存过期）
static func get_hand_effect_table() -> Dictionary:
	return HandTypeEffects.get_display_table()

# 兼容旧引用（hand_guide.gd 等）
static var HAND_EFFECT_TABLE: Dictionary:
	get:
		return HandTypeEffects.get_display_table()


func _ready() -> void:
	_build_ui()
	_show_empty_state()
	# 默认隐藏：由 BattleController._update_damage_preview 在选中骰子后切 visible=true
	visible = false


func _build_ui() -> void:
	# 面板背景
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.09, 0.92)
	style.border_color = Color("#3c6cc8")
	style.set_border_width_all(2)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	add_theme_stylebox_override("panel", style)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	add_child(vbox)
	
	_hand_label = _make_label(16, Color("#f0c850"))
	_damage_label = _make_label(20, Color("#f07050"))
	_armor_label = _make_label(13, Color("#60a0e8"))
	_status_label = _make_label(12, Color("#c090f0"))
	_aoe_label = _make_label(12, Color("#e8e040"))
	
	vbox.add_child(_hand_label)
	vbox.add_child(_damage_label)
	vbox.add_child(_armor_label)
	vbox.add_child(_status_label)
	vbox.add_child(_aoe_label)


## 空态：骰子未选中时显示占位，面板保持可见避免布局跳动
func _show_empty_state() -> void:
	_hand_label.text = "— 未选中骰子 —"
	_hand_label.add_theme_color_override("font_color", Color("#6a6a80"))
	_damage_label.text = "预计伤害 0"
	_damage_label.add_theme_color_override("font_color", Color("#6a6a80"))
	_armor_label.visible = false
	_status_label.visible = false
	_aoe_label.visible = false


## 恢复高亮色（退出空态时调用）
func _restore_highlight_colors() -> void:
	_hand_label.add_theme_color_override("font_color", Color("#f0c850"))
	_damage_label.add_theme_color_override("font_color", Color("#f07050"))


func _make_label(font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 2)
	return l


## 外部接口：根据选中骰子刷新预览
func refresh(selected_dice: Array[Dictionary]) -> void:
	if selected_dice.is_empty():
		_show_empty_state()
		return
	
	_restore_highlight_colors()
	
	var hand_result := HandEvaluator.check_hands(selected_dice)
	
	# v0.5 预览：outcome_multiplier 连乘 + bonus_base_damage 进乘区
	var outcome_mult: float = _calc_preview_outcome_mult(hand_result.bestHand)
	var base_bonus: int = _calc_preview_bonus_damage()
	
	# 骰子 onPlay 特效预演（纯函数调用，不改游戏状态）
	var effect_preview := _preview_dice_effects(selected_dice)
	var total_bonus_damage: int = base_bonus + effect_preview.bonus_damage
	if effect_preview.bonus_mult > 0.0:
		outcome_mult *= (1.0 + effect_preview.bonus_mult)
	
	var total_damage := HandEvaluator.calculate_damage(
		selected_dice, hand_result, total_bonus_damage, outcome_mult, PlayerState.hand_type_upgrades
	)
	
	# 牌型
	_hand_label.text = hand_result.bestHand
	
	# 伤害
	_damage_label.text = "预计伤害 %d" % total_damage
	
	# 护甲与状态（按最高牌型查表）
	var raw_hands: Variant = hand_result.get("activeHands", [])
	var active_hands: Array[String] = []
	if raw_hands is Array[String]:
		active_hands = raw_hands
	elif raw_hands is Array:
		for h: String in raw_hands:
			active_hands.append(h)
	var best_effect := _get_best_effect(active_hands)
	# §6.6 第 2 级：同元素系牌型 → baseDamage 额外转护甲
	var elemental_armor: int = 0
	if _has_elemental_hand(active_hands):
		elemental_armor = HandEvaluator.calculate_base_damage(selected_dice, hand_result, PlayerState.hand_type_upgrades)
	# 叠加骰子特效带来的护甲
	var hand_armor: int = best_effect.armor + effect_preview.armor + elemental_armor
	if hand_armor > 0:
		_armor_label.text = "护甲 +%d" % hand_armor
		_armor_label.visible = true
	else:
		_armor_label.visible = false
	
	# 叠加骰子特效带来的状态/治疗/自伤描述
	var status_parts: Array[String] = []
	if best_effect.status != "":
		status_parts.append(best_effect.status)
	if effect_preview.heal > 0:
		status_parts.append("回血 %d" % effect_preview.heal)
	if effect_preview.self_damage > 0:
		status_parts.append("自伤 %d" % effect_preview.self_damage)
	if effect_preview.pierce > 0:
		status_parts.append("穿甲")
	if status_parts.is_empty():
		_status_label.visible = false
	else:
		_status_label.text = " · ".join(status_parts)
		_status_label.visible = true
	
	# AOE 标识（考虑骰子特效带来的 aoe）
	var has_aoe: bool = BattleHelpers.detect_aoe(selected_dice, hand_result) or effect_preview.aoe > 0
	if has_aoe:
		if effect_preview.aoe > 0:
			_aoe_label.text = "⚡ 群伤 +%d" % effect_preview.aoe
		else:
			_aoe_label.text = "⚡ 群伤"
	_aoe_label.visible = has_aoe


## 预演骰子 onPlay 特效（纯函数调用，不改任何状态）
## 返回 DiceEffectResolver.ResolveResult
func _preview_dice_effects(selected_dice: Array[Dictionary]) -> DiceEffectResolver.ResolveResult:
	# 构造手牌 + 未选骰子定义
	var dice_in_hand: Array[DiceDef] = []
	var unselected_dice: Array[DiceDef] = []
	for die_dict: Dictionary in DiceBag.hand_dice:
		var d_def: DiceDef = GameData.get_dice_def(die_dict.get("defId", ""))
		if d_def:
			dice_in_hand.append(d_def)
			if not die_dict.get("selected", false):
				unselected_dice.append(d_def)
	
	return DiceEffectResolver.resolve_on_play(
		DiceEffectApplier.get_dice_def_for_selected(selected_dice),
		PlayerState.hp,
		PlayerState.max_hp,
		GameManager.rerolls_this_turn,
		PlayerState.combo_count,
		PlayerState.armor,
		null,  # target_enemy：预览不需要实际目标，单体 bonus 默认按 null 处理
		[],     # enemies：预览不考虑战场敌人数量相关效果（如 mult_per_enemy）
		dice_in_hand,
		unselected_dice
	)


## ====== 纯计算辅助（不改任何状态）======

## v0.5 预览增幅倍率（连乘）
func _calc_preview_outcome_mult(best_hand: String) -> float:
	var mult: float = 1.0
	# 遗物倍率（通过 RelicEngine 统一处理）
	var relic_result := RelicEngine.on_play(GameManager.relics, null, [], best_hand)
	if relic_result.bonus_mult > 0.0:
		mult *= (1.0 + relic_result.bonus_mult)
	# 过充
	var overcharge: float = GameBalance.get_overcharge_mult(
		DiceBag.hand_dice.size(), GameBalance.PLAYER_INITIAL.drawCount
	)
	if overcharge > 0.0:
		mult *= (1.0 + overcharge)
	# 血怒
	var fury_stacks: int = mini(GameManager.blood_reroll_count, GameBalance.FURY_CONFIG.maxStack)
	var fury_mult: float = fury_stacks * GameBalance.FURY_CONFIG.damagePerStack
	if fury_mult > 0.0:
		mult *= (1.0 + fury_mult)
	# 战士狂暴
	if GameManager.warrior_rage_mult > 0.0:
		mult *= (1.0 + GameManager.warrior_rage_mult)
	return mult


## 额外伤害：怒火燎原累积 + 其他 bonus（不包含会变更 counter 的遗物）
func _calc_preview_bonus_damage() -> int:
	var bonus := GameManager.rage_fire_bonus + GameManager.fury_bonus_damage
	for r: Dictionary in GameManager.relics:
		var def: RelicDef = GameData.get_relic_def(r.get("id", ""))
		if not def or def.trigger != GameTypes.RelicTrigger.ON_PLAY or def.id == "life_furnace":
			continue
		# 从 effects 数组提取 BONUS_DAMAGE 值
		for eff: Dictionary in def.effects:
			if eff.get("type", -1) == EffectTypes.EffectType.BONUS_DAMAGE:
				bonus += eff.get("params", {}).get("value", 0)
	return bonus


func _get_best_effect(active_hands: Array[String]) -> Dictionary:
	var best := {"armor": 0, "status": ""}
	for h: String in active_hands:
		var eff: Dictionary = HAND_EFFECT_TABLE.get(h, {})
		if eff.is_empty():
			continue
		if eff.get("armor", 0) > best.armor:
			best.armor = eff.armor
		if eff.get("status", "") != "" and best.status == "":
			best.status = eff.status
	return best


## §6.6 第 2 级判定：是否含同元素系牌型
func _has_elemental_hand(active_hands: Array[String]) -> bool:
	return HandTypeEffects.has_elemental_hand(active_hands)
