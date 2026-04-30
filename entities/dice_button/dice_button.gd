## 骰子按钮组件 — 对应原版 DiceSelectCard.tsx
## 节点结构和样式都在 dice_button.tscn 中定义
## 三层视觉：底色（元素） + 边框（选中态） + 角标（选中标记）
##
## 美术替换指引：
##   - BgRect (ColorRect)：未来可换成 TextureRect/Sprite2D 承载骰子面
##   - ValueLabel (Label)：未来可替换为点数图形
##   - ElementIcon (Label emoji)：未来换成元素 icon 资源

class_name DiceButton
extends Button

signal die_clicked(die_id: int)
## 骰子被点击后触发：Controller 结合真实选中结果决定是否弹 tooltip
signal die_tap_requested(die_id: int, center_pos: Vector2)
## 索引点击信号（Controller 通过此信号获取手牌索引）
signal dice_index_clicked(index: int)

# 骰子数据快照（引用 GameManager.hand_dice 中的 Dictionary）
var _die: Dictionary = {}

# 手牌索引（Controller 通过此字段定位骰子）
var dice_index: int = -1

var _is_candidate: bool = false

# tscn 中的节点引用
@onready var _border_rect: ColorRect = %BorderRect
@onready var _bg_rect: ColorRect = %BgRect
@onready var _value_label: Label = %ValueLabel
@onready var _element_icon: Label = %ElementIcon
@onready var _badge: Label = %Badge

# 视觉规格
const BORDER_WIDTH := 3
const SELECTED_BORDER_WIDTH := 5
const SELECTED_BORDER_COLOR := Color("#f0c040")
const UNSELECTED_BORDER_COLOR := Color(1, 1, 1, 0.15)
const CANDIDATE_BORDER_COLOR := Color("#40a0e8")

func _ready() -> void:
	pressed.connect(_on_self_pressed)
	if not _die.is_empty():
		_refresh_visual()

## 外部接口：绑定骰子数据并刷新视觉
func setup(die: Dictionary) -> void:
	_die = die
	if is_node_ready():
		_refresh_visual()

## Controller 兼容接口：初始化骰子数据和索引
func init(dice_data: Dictionary, index: int) -> void:
	dice_index = index
	setup(dice_data)

func get_die_id() -> int:
	return _die.get("id", -1)

## 设置选中状态并刷新视觉
func set_selected(selected: bool) -> void:
	_die["selected"] = selected
	if is_node_ready():
		_refresh_visual()

## 设置为候选态（可组成牌型的骰子，蓝色边框提示）
func set_candidate(is_candidate: bool) -> void:
	_is_candidate = is_candidate
	if is_node_ready():
		_refresh_visual()

func _refresh_visual() -> void:
	if _die.is_empty():
		return
	
	var value := int(_die.get("value", 1))
	var selected: bool = _die.get("selected", false)
	var rolling: bool = _die.get("rolling", false)
	var elem: String = _die.get("collapsedElement", _die.get("element", "normal"))
	
	_value_label.text = str(value) if not rolling else "?"
	
	# 元素图标
	_element_icon.text = _element_icon_text(elem)
	_element_icon.visible = elem != "normal"
	_element_icon.add_theme_color_override("font_color", _element_color(elem).lightened(0.3))
	
	# 底色：始终按元素色显示
	_bg_rect.color = _element_color(elem)
	
	# 边框：选中=金色加粗框 > 候选=蓝框 > 默认=浅灰细线
	if selected:
		_border_rect.color = SELECTED_BORDER_COLOR
		_set_border_thickness(SELECTED_BORDER_WIDTH)
	elif _is_candidate:
		_border_rect.color = CANDIDATE_BORDER_COLOR
		_set_border_thickness(BORDER_WIDTH)
	else:
		_border_rect.color = UNSELECTED_BORDER_COLOR
		_set_border_thickness(BORDER_WIDTH)
	
	# 角标
	_badge.visible = selected
	
	modulate = Color(1, 1, 1, 1)
	disabled = rolling

func _element_color(elem: String) -> Color:
	match elem:
		"fire": return Color(0.85, 0.30, 0.15, 1.0)
		"ice": return Color(0.22, 0.55, 0.85, 1.0)
		"thunder": return Color(0.85, 0.80, 0.20, 1.0)
		"poison": return Color(0.30, 0.70, 0.30, 1.0)
		"holy": return Color(0.92, 0.88, 0.55, 1.0)
		"shadow": return Color(0.40, 0.22, 0.55, 1.0)
		_: return Color(0.15, 0.15, 0.20, 1.0)

func _element_icon_text(elem: String) -> String:
	match elem:
		"fire": return "🔥"
		"ice": return "❄"
		"thunder": return "⚡"
		"poison": return "☠"
		"holy": return "✦"
		"shadow": return "◈"
		_: return ""

## 动态调整边框厚度（选中态用更粗的框）
func _set_border_thickness(thickness: int) -> void:
	if _border_rect == null:
		return
	_border_rect.offset_left = -thickness
	_border_rect.offset_top = -thickness
	_border_rect.offset_right = thickness
	_border_rect.offset_bottom = thickness

func _on_self_pressed() -> void:
	if _die.is_empty():
		return
	if _die.get("rolling", false):
		return
	var die_id: int = int(_die.get("id", -1))
	die_clicked.emit(die_id)
	if dice_index >= 0:
		dice_index_clicked.emit(dice_index)
	var center: Vector2 = global_position + size * 0.5
	die_tap_requested.emit(die_id, center)
