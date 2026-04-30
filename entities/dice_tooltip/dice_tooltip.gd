## dice_tooltip.gd — 选中骰子时浮出的信息卡片
## 节点结构和样式都在 dice_tooltip.tscn 中定义
## 对应原版 PlayerHudView.tsx 中 lastTappedDieId 驱动的 portal tooltip
##
## 使用方式：
##   var tip := preload("res://entities/dice_tooltip/dice_tooltip.tscn").instantiate()
##   _float_layer.add_child(tip)
##   tip.show_for_die(die_dict, global_pos)
##   tip.hide_tip()
class_name DiceTooltip
extends Control

# ── 元素配置（同步 dice_button.gd）
const ELEM_NAMES: Dictionary = {
	"fire":    "火焰骰子",
	"ice":     "冰霜骰子",
	"thunder": "雷电骰子",
	"poison":  "剧毒骰子",
	"holy":    "神圣骰子",
	"shadow":  "暗影骰子",
}

const ELEM_DESCS: Dictionary = {
	"fire":    "造成额外灼烧伤害（持续2回合）",
	"ice":     "冻结敌人，令其跳过1回合行动",
	"thunder": "雷击造成AOE范围伤害",
	"poison":  "施加毒素持续掉血",
	"holy":    "治疗自身并净化负面状态",
	"shadow":  "暗影穿刺，无视护甲",
}

const ELEM_COLORS: Dictionary = {
	"fire":    Color("#ff8040"),
	"ice":     Color("#60c0f0"),
	"thunder": Color("#e0d040"),
	"poison":  Color("#60e060"),
	"holy":    Color("#e0d8a0"),
	"shadow":  Color("#a080d0"),
}

const CLASS_COLORS: Dictionary = {
	"warrior": Color("#ff6060"),
	"mage":    Color("#a070ff"),
	"rogue":   Color("#60d080"),
}

const TIP_WIDTH := 180.0
const TIP_OFFSET_Y := -12.0  # 骰子上方的间距

# tscn 中的节点引用
@onready var _panel: PanelContainer = %Panel
@onready var _name_label: Label = %NameLabel
@onready var _desc_label: Label = %DescLabel
@onready var _faces_label: Label = %FacesLabel
@onready var _extra_label: Label = %ExtraLabel
@onready var _arrow: Control = %Arrow

func _ready() -> void:
	_arrow.draw.connect(_draw_arrow)
	visible = false

func _draw_arrow() -> void:
	if _arrow == null:
		return
	var pts := PackedVector2Array([
		Vector2(0, 0),
		Vector2(10, 0),
		Vector2(5, 6),
	])
	_arrow.draw_colored_polygon(pts, Color(0.047, 0.039, 0.078, 0.85))

## 根据骰子 dict 和骰子在屏幕上的 global_position 弹出 tooltip
func show_for_die(die: Dictionary, dice_global_pos: Vector2, player_class: String = "", fury_bonus_damage: int = 0) -> void:
	var def_id: String = die.get("defId", "")
	var def: DiceDef = GameData.get_dice_def(def_id)
	if def == null:
		return

	var collapsed_elem: String = die.get("collapsedElement", "")
	if collapsed_elem.is_empty():
		var elem: String = die.get("element", "normal")
		if elem != "normal":
			collapsed_elem = elem

	# 决定显示名称
	var tip_name: String
	if not collapsed_elem.is_empty() and ELEM_NAMES.has(collapsed_elem):
		tip_name = ELEM_NAMES[collapsed_elem]
	else:
		tip_name = def.name if not def.name.is_empty() else def_id

	# 决定描述
	var tip_desc: String
	if not collapsed_elem.is_empty() and ELEM_DESCS.has(collapsed_elem):
		tip_desc = ELEM_DESCS[collapsed_elem]
	else:
		tip_desc = def.description

	# 决定名字颜色
	var tip_color: Color
	if not collapsed_elem.is_empty() and ELEM_COLORS.has(collapsed_elem):
		tip_color = ELEM_COLORS[collapsed_elem]
	elif CLASS_COLORS.has(player_class):
		tip_color = CLASS_COLORS[player_class]
	else:
		# id前缀推断
		if def_id.begins_with("w_"):
			tip_color = Color("#ff6060")
		elif def_id.begins_with("mage_"):
			tip_color = Color("#a070ff")
		elif def_id.begins_with("r_"):
			tip_color = Color("#60d080")
		else:
			tip_color = Color("#c8c8d0")

	# 填充文本
	_name_label.text = tip_name
	_name_label.add_theme_color_override("font_color", tip_color)

	_desc_label.text = tip_desc
	_desc_label.visible = not tip_desc.is_empty()

	# 面值
	var face_strs := PackedStringArray()
	for f: int in def.faces:
		face_strs.append(str(f))
	var faces_str := "[" + ", ".join(face_strs) + "]"
	_faces_label.text = "面值: " + faces_str

	# 血怒额外信息
	if def_id == "w_fury" and fury_bonus_damage > 0:
		_extra_label.text = "当前叠加: +%d 伤害" % fury_bonus_damage
		_extra_label.visible = true
	else:
		_extra_label.visible = false

	# 确保 panel 大小已更新
	_panel.reset_size()
	await get_tree().process_frame
	var panel_size: Vector2 = _panel.size

	# 水平居中在骰子上方，钳制不出屏幕边缘
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var tip_x: float = clampf(
		dice_global_pos.x - panel_size.x * 0.5,
		8.0,
		viewport_size.x - panel_size.x - 8.0
	)
	var tip_y: float = dice_global_pos.y - panel_size.y + TIP_OFFSET_Y

	_panel.position = Vector2(tip_x, tip_y)

	# 箭头放在 panel 底部中央
	var arrow_x: float = dice_global_pos.x - 5.0
	var arrow_y: float = dice_global_pos.y + TIP_OFFSET_Y - 2.0
	_arrow.position = Vector2(arrow_x, arrow_y)
	_arrow.queue_redraw()

	visible = true

## 隐藏 tooltip
func hide_tip() -> void:
	visible = false
