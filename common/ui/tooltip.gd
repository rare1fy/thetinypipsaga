## 全局 Tooltip — 显示多行说明文字，跟随鼠标定位
## 用法：battle_scene / main 挂一个 Tooltip 节点（Control），其他模块通过 `Tooltip.show_text(...)` 调用
## 生命周期：场景退出时自动反注册

class_name Tooltip
extends PanelContainer


const MAX_WIDTH: float = 260.0
const PADDING_X: float = 12.0
const PADDING_Y: float = 12.0

static var _instance: Tooltip = null


## 显示 Tooltip（pos 是鼠标全局坐标，Tooltip 会智能避开屏幕边缘）
static func show_text(text: String, pos: Vector2) -> void:
	if _instance == null or not is_instance_valid(_instance):
		return
	_instance._show(text, pos)


## 隐藏 Tooltip
static func hide_tip() -> void:
	if _instance == null or not is_instance_valid(_instance):
		return
	_instance.visible = false


var _label: Label = null


func _ready() -> void:
	_instance = self
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_level = true  # 不受父级变换影响
	z_index = 100
	_build_ui()


func _exit_tree() -> void:
	if _instance == self:
		_instance = null


func _build_ui() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.05, 0.08, 0.96)
	style.border_color = Color("#5c80d0")
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = PADDING_X
	style.content_margin_right = PADDING_X
	style.content_margin_top = PADDING_Y
	style.content_margin_bottom = PADDING_Y
	add_theme_stylebox_override("panel", style)

	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size = Vector2(MAX_WIDTH - PADDING_X * 2, 0)
	_label.add_theme_font_size_override("font_size", 12)
	_label.add_theme_color_override("font_color", Color("#e0e4ec"))
	add_child(_label)


func _show(text: String, pos: Vector2) -> void:
	_label.text = text
	visible = true
	# 下一帧再定位（等 Label 算完 size）
	await get_tree().process_frame
	if not is_inside_tree():
		return
	var vp_size: Vector2 = get_viewport_rect().size
	var tip_size: Vector2 = size
	var offset := Vector2(12, 18)
	var target: Vector2 = pos + offset
	# 右侧越界 → 翻到左侧
	if target.x + tip_size.x > vp_size.x:
		target.x = pos.x - tip_size.x - offset.x
	# 下侧越界 → 翻到上方
	if target.y + tip_size.y > vp_size.y:
		target.y = pos.y - tip_size.y - offset.y
	# 再兜底：不允许负坐标
	target.x = maxf(0, target.x)
	target.y = maxf(0, target.y)
	global_position = target
