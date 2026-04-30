## HandGuide — 牌型图鉴（Modal 内容）
##
## 展示 17 种牌型的：名称 / 基础威力 / 伤害倍率 / 附带护甲·状态 / 构成规则说明
## 数据源：
##   - HandEvaluator.HAND_MULT        （基础值 + 倍率）
##   - DamagePreview.HAND_EFFECT_TABLE（附带护甲/状态）
##   - 本文件 HAND_DESCRIPTIONS      （构成规则说明 — 图鉴专属静态数据）
##
## 调用方式（不依赖 class_name）：
##   const HandGuideRef := preload("res://common/ui/hand_guide.gd")
##   ModalHubRef.open(HandGuideRef.new(), "牌型图鉴", {"size": Vector2(560, 780)})

extends VBoxContainer

const ModalHubRef := preload("res://common/ui/modal_hub.gd")

# ============================================================
# 常量：牌型分组（决定 UI 分组呈现顺序）
# ============================================================
const GROUPS: Array[Dictionary] = [
	{"title": "🎲 基础牌型", "color": "#a8c0ff", "hands": [
		"对子", "连对", "三连对", "三条", "四条", "五条", "六条", "葫芦",
	]},
	{"title": "📏 顺子牌型", "color": "#a0e8b0", "hands": [
		"顺子", "4顺", "5顺", "6顺",
	]},
	{"title": "🔥 元素牌型", "color": "#ffb878", "hands": [
		"同元素",
	]},
	{"title": "👑 组合牌型（稀有）", "color": "#f0c850", "hands": [
		"元素顺", "元素葫芦", "皇家元素顺",
	]},
]

# ============================================================
# 常量：构成规则说明
# ============================================================
const HAND_DESCRIPTIONS: Dictionary = {
	"普通攻击": "无牌型时，按点数之和造成伤害",
	"对子": "2 颗相同点数的骰子",
	"连对": "2 组对子（4 颗骰子）",
	"三连对": "3 组对子（6 颗骰子）",
	"三条": "3 颗相同点数的骰子",
	"四条": "4 颗相同点数的骰子",
	"五条": "5 颗相同点数的骰子",
	"六条": "6 颗相同点数的骰子",
	"葫芦": "一组三条 + 一组对子，或叠加组合",
	"顺子": "3 颗点数连续的骰子",
	"4顺": "4 颗点数连续的骰子",
	"5顺": "5 颗点数连续的骰子",
	"6顺": "1~6 全顺",
	"同元素": "4 颗及以上相同元素（非 normal）",
	"元素顺": "顺子 + 同元素，威力翻倍",
	"元素葫芦": "葫芦 + 同元素，三条与对子同色",
	"皇家元素顺": "同元素的 6 顺（1~6），神话级牌型",
}


# ============================================================
# 生命周期
# ============================================================
func _ready() -> void:
	add_theme_constant_override("separation", 16)
	_build_content()


# ============================================================
# 构建
# ============================================================
func _build_content() -> void:
	# 顶部说明
	var intro := Label.new()
	intro.text = "出牌伤害 = (点数和 + 基础) × 倍率\n数值越高，牌型越强力"
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro.add_theme_color_override("font_color", Color("#9aa0ac"))
	intro.add_theme_font_size_override("font_size", 12)
	add_child(intro)
	
	# 可滚动主体
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 14)
	scroll.add_child(list)
	
	for group: Dictionary in GROUPS:
		list.add_child(_build_group_header(group.title, group.color))
		for hand_name: String in group.hands:
			list.add_child(_build_hand_entry(hand_name))


func _build_group_header(title: String, color_hex: String) -> Control:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	
	var dot := ColorRect.new()
	dot.color = Color(color_hex)
	dot.custom_minimum_size = Vector2(4, 20)
	header.add_child(dot)
	
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(color_hex))
	header.add_child(label)
	
	return header


func _build_hand_entry(hand_name: String) -> Control:
	var mult_data: Dictionary = HandEvaluator.HAND_MULT.get(hand_name, {"base": 0, "mult": 1.0})
	var base_v: int = int(mult_data.get("base", 0))
	var mult_v: float = float(mult_data.get("mult", 1.0))
	var effect: Dictionary = DamagePreview.HAND_EFFECT_TABLE.get(hand_name, {"armor": 0, "status": ""})
	var desc: String = HAND_DESCRIPTIONS.get(hand_name, "")
	
	var row := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#242838")
	style.border_color = Color("#3a4258")
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	row.add_theme_stylebox_override("panel", style)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	row.add_child(vbox)
	
	# 第一行：名称 + 基础值 + 倍率
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	
	var name_label := Label.new()
	name_label.text = hand_name
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color("#f0e8c8"))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_label)
	
	var stats_label := Label.new()
	stats_label.text = "基础 %d · ×%.1f" % [base_v, mult_v]
	stats_label.add_theme_font_size_override("font_size", 13)
	stats_label.add_theme_color_override("font_color", Color("#f07050"))
	top.add_child(stats_label)
	
	vbox.add_child(top)
	
	# 第二行：构成说明
	if desc != "":
		var desc_label := Label.new()
		desc_label.text = desc
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.add_theme_font_size_override("font_size", 12)
		desc_label.add_theme_color_override("font_color", Color("#9aa0ac"))
		vbox.add_child(desc_label)
	
	# 第三行：附带效果（仅当有护甲 or 状态时显示）
	var effect_text := _format_effect(effect)
	if effect_text != "":
		var effect_label := Label.new()
		effect_label.text = effect_text
		effect_label.add_theme_font_size_override("font_size", 12)
		effect_label.add_theme_color_override("font_color", Color("#80c0f0"))
		vbox.add_child(effect_label)
	
	return row


func _format_effect(effect: Dictionary) -> String:
	var parts: Array[String] = []
	var armor: int = int(effect.get("armor", 0))
	var status: String = str(effect.get("status", ""))
	if armor > 0:
		parts.append("🛡 护甲 +%d" % armor)
	if status != "":
		parts.append("💫 " + status)
	return "  ·  ".join(parts)
