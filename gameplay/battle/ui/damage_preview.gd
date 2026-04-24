## 伤害预览面板 — 对应原版 expectedOutcome 在 UI 层的呈现
## 选中骰子变化时调用 refresh(selected_dice) 即可刷新
## 只展示信息，不修改任何游戏状态

class_name DamagePreview
extends PanelContainer

# UI 子节点
var _hand_label: Label = null           # 当前牌型
var _damage_label: Label = null         # 预计伤害
var _armor_label: Label = null          # 护甲（仅有时显示）
var _status_label: Label = null         # 状态效果提示
var _aoe_label: Label = null            # AOE 提示（仅雷元素 / 特定牌型）

# 牌型附带护甲/状态表（对齐 handTypes.ts）
const HAND_EFFECT_TABLE: Dictionary = {
	"对子": {"armor": 0, "status": ""},
	"连对": {"armor": 5, "status": ""},
	"三连对": {"armor": 8, "status": ""},
	"三条": {"armor": 0, "status": "易伤x1（2回合）"},
	"4顺": {"armor": 0, "status": "虚弱x1（2回合）"},
	"葫芦": {"armor": 15, "status": ""},
	"5顺": {"armor": 0, "status": "虚弱x2（2回合）"},
	"四条": {"armor": 0, "status": "易伤x2（2回合）"},
	"6顺": {"armor": 10, "status": "虚弱x3（2回合）"},
}


func _ready() -> void:
	_build_ui()
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
		visible = false
		return
	
	visible = true
	
	var hand_result := HandEvaluator.check_hands(selected_dice)
	
	# 预览专用纯计算（无副作用，不改遗物 counter）
	var bonus_mult := _calc_preview_mult(hand_result.bestHand)
	var bonus_damage := _calc_preview_bonus_damage()
	var total_damage := HandEvaluator.calculate_damage(selected_dice, hand_result, bonus_mult, bonus_damage)
	
	# 牌型
	_hand_label.text = hand_result.bestHand
	
	# 伤害
	_damage_label.text = "预计伤害 %d" % total_damage
	
	# 护甲与状态（按最高牌型查表）
	var best_effect := _get_best_effect(hand_result.activeHands)
	if best_effect.armor > 0:
		_armor_label.text = "护甲 +%d" % best_effect.armor
		_armor_label.visible = true
	else:
		_armor_label.visible = false
	
	if best_effect.status != "":
		_status_label.text = "状态：%s" % best_effect.status
		_status_label.visible = true
	else:
		_status_label.visible = false
	
	# AOE 标识（通过 BattleHelpers 统一判定，避免双份代码）
	var has_aoe := BattleHelpers.detect_aoe(selected_dice, hand_result)
	_aoe_label.text = "⚡ 群伤"
	_aoe_label.visible = has_aoe


## ====== 纯计算辅助（不改任何状态）======

## 只计算"玩家看得见"的倍率：遗物倍率 + 狂暴 + 过充
## 不重复计算 RelicEngine.get_bonus_damage（它会修改 life_furnace counter）
func _calc_preview_mult(best_hand: String) -> float:
	var relic_mult := 0.0
	for r in GameManager.relics:
		var def: RelicDef = GameData.get_relic_def(r.id)
		if def.multiplier > 0 and def.id == "prism_focus" and "同元素" in best_hand:
			relic_mult += def.multiplier
	return relic_mult + GameManager.mage_overcharge_mult + GameManager.warrior_rage_mult


## 额外伤害：怒火燎原累积 + 其他 bonus（不包含会变更 counter 的遗物）
func _calc_preview_bonus_damage() -> int:
	var bonus := GameManager.rage_fire_bonus + GameManager.fury_bonus_damage
	for r in GameManager.relics:
		var def: RelicDef = GameData.get_relic_def(r.id)
		if def.trigger == GameTypes.RelicTrigger.ON_PLAY and def.damage > 0 and def.id != "life_furnace":
			bonus += def.damage
	return bonus


func _get_best_effect(active_hands: Array) -> Dictionary:
	var best := {"armor": 0, "status": ""}
	for h in active_hands:
		var eff: Dictionary = HAND_EFFECT_TABLE.get(h, {})
		if eff.is_empty():
			continue
		if eff.get("armor", 0) > best.armor:
			best.armor = eff.armor
		if eff.get("status", "") != "" and best.status == "":
			best.status = eff.status
	return best
