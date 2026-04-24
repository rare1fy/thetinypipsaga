## 骰子按钮组件 — 对应原版 DiceSelectCard.tsx
## 三层视觉：底色（元素） + 边框（选中态） + 角标（选中标记）
## 外部通过 setup(die) 配置，点击通过 die_clicked(die_id) 信号上报

class_name DiceButton
extends Button

signal die_clicked(die_id: int)

# 骰子数据快照（引用 GameManager.hand_dice 中的 Dictionary）
var _die: Dictionary = {}

# 视觉子节点（代码创建，避免场景文件依赖）
var _bg_rect: ColorRect = null          # 底色（元素色）
var _border_rect: ColorRect = null      # 边框（选中时金色，未选中时透明）
var _value_label: Label = null          # 点数
var _badge: Label = null                # 右上角选中角标 ◆

# 常量：视觉规格
const DICE_SIZE := Vector2(52, 52)
const BORDER_WIDTH := 3
const SELECTED_BORDER_COLOR := Color("#d4a030")   # PixelTheme.PIXEL_GOLD
const SELECTED_BG_TINT := Color(0.84, 0.63, 0.19, 0.25)   # 金色半透明叠加
const UNSELECTED_BORDER_COLOR := Color(1, 1, 1, 0.12)
const BADGE_COLOR := Color("#d4a030")
const SPENT_ALPHA := 0.35


func _ready() -> void:
	custom_minimum_size = DICE_SIZE
	size = DICE_SIZE
	focus_mode = Control.FOCUS_NONE
	flat = true
	clip_contents = false
	
	# 1. 边框层（最底，绘制一圈外轮廓）
	_border_rect = ColorRect.new()
	_border_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_border_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_border_rect.offset_left = -BORDER_WIDTH
	_border_rect.offset_top = -BORDER_WIDTH
	_border_rect.offset_right = BORDER_WIDTH
	_border_rect.offset_bottom = BORDER_WIDTH
	_border_rect.color = UNSELECTED_BORDER_COLOR
	add_child(_border_rect)
	move_child(_border_rect, 0)
	
	# 2. 底色层（元素色）
	_bg_rect = ColorRect.new()
	_bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_rect.color = Color(0.1, 0.1, 0.12)
	add_child(_bg_rect)
	
	# 3. 点数文字
	_value_label = Label.new()
	_value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_value_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_value_label.add_theme_font_size_override("font_size", 22)
	_value_label.add_theme_color_override("font_color", Color.WHITE)
	_value_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_value_label.add_theme_constant_override("outline_size", 3)
	add_child(_value_label)
	
	# 4. 右上角角标（选中时显示 ◆）
	_badge = Label.new()
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge.text = "◆"
	_badge.add_theme_font_size_override("font_size", 14)
	_badge.add_theme_color_override("font_color", BADGE_COLOR)
	_badge.add_theme_color_override("font_outline_color", Color.BLACK)
	_badge.add_theme_constant_override("outline_size", 2)
	_badge.position = Vector2(DICE_SIZE.x - 14, -6)
	_badge.visible = false
	add_child(_badge)
	
	pressed.connect(_on_self_pressed)


## 外部接口：绑定骰子数据并刷新视觉
func setup(die: Dictionary) -> void:
	_die = die
	_refresh_visual()


func get_die_id() -> int:
	return _die.get("id", -1)


func _refresh_visual() -> void:
	if _die.is_empty():
		return
	
	var value := int(_die.get("value", 1))
	var selected: bool = _die.get("selected", false)
	var spent: bool = _die.get("spent", false)
	var rolling: bool = _die.get("rolling", false)
	var elem: String = _die.get("collapsedElement", _die.get("element", "normal"))
	
	_value_label.text = str(value) if not rolling else "?"
	
	# 底色：按元素 + 选中时叠金色
	var base_color := _element_color(elem)
	if selected:
		# 金色半透明覆盖到元素色之上，保持元素色能辨识
		base_color = base_color.lerp(SELECTED_BG_TINT, 0.6)
	_bg_rect.color = base_color
	
	# 边框：选中时金色粗边，未选中时浅灰
	_border_rect.color = SELECTED_BORDER_COLOR if selected else UNSELECTED_BORDER_COLOR
	
	# 角标
	_badge.visible = selected
	
	# 已使用：半透明 + 禁用点击
	modulate.a = SPENT_ALPHA if spent else 1.0
	disabled = spent or rolling


func _element_color(elem: String) -> Color:
	match elem:
		"fire": return Color(0.85, 0.30, 0.15, 1.0)
		"ice": return Color(0.22, 0.55, 0.85, 1.0)
		"thunder": return Color(0.85, 0.80, 0.20, 1.0)
		"poison": return Color(0.30, 0.70, 0.30, 1.0)
		"holy": return Color(0.92, 0.88, 0.55, 1.0)
		"shadow": return Color(0.40, 0.22, 0.55, 1.0)
		_: return Color(0.15, 0.15, 0.20, 1.0)


func _on_self_pressed() -> void:
	if _die.is_empty():
		return
	if _die.get("spent", false) or _die.get("rolling", false):
		return
	die_clicked.emit(int(_die.get("id", -1)))
