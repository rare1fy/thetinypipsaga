## Toast 管理器 — 对应原版 addToast(msg, type)
## 监听 GameManager.toast_requested，从屏幕底部冒出消息条
## 单例 CanvasLayer 挂在 Main 下，跨场景复用

class_name ToastManager
extends CanvasLayer

const MAX_TOAST_COUNT := 3           # 同屏最大 toast 数
const TOAST_LIFETIME := 2.2          # 单条显示总时长（秒）
const FADE_DURATION := 0.25           # 淡入/淡出时长
const TOAST_HEIGHT := 32              # 单条高度
const TOAST_GAP := 6                  # 条间距
const BOTTOM_MARGIN := 120            # 距屏幕底部偏移（避开按钮区）

# 活跃 toast 列表（顶层 Control 节点）
var _toasts: Array[Control] = []


func _ready() -> void:
	layer = 50   # 压在场景之上，但在全局 Overlay（100）之下
	GameManager.toast_requested.connect(_on_toast_requested)


func _on_toast_requested(msg: String, type: String) -> void:
	_push_toast(msg, type)


func _push_toast(msg: String, type: String) -> void:
	# 超出上限：最老的先消失
	while _toasts.size() >= MAX_TOAST_COUNT:
		var oldest: Control = _toasts.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()
	
	var toast := _build_toast_node(msg, type)
	add_child(toast)
	_toasts.append(toast)
	_layout_toasts()
	
	# 淡入 → 静止 → 淡出 → 销毁
	toast.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(toast, "modulate:a", 1.0, FADE_DURATION)
	tw.tween_interval(TOAST_LIFETIME - FADE_DURATION * 2)
	tw.tween_property(toast, "modulate:a", 0.0, FADE_DURATION)
	tw.tween_callback(func(): _on_toast_expired(toast))


func _on_toast_expired(toast: Control) -> void:
	_toasts.erase(toast)
	if is_instance_valid(toast):
		toast.queue_free()
	_layout_toasts()


## 布局所有 toast：从底向上依次堆叠
func _layout_toasts() -> void:
	var vp_size := get_viewport().get_visible_rect().size
	for i in _toasts.size():
		var t: Control = _toasts[i]
		if not is_instance_valid(t):
			continue
		# 最新的在上面（索引大的 y 更靠下）
		var stack_index := _toasts.size() - 1 - i
		var y := vp_size.y - BOTTOM_MARGIN - (TOAST_HEIGHT + TOAST_GAP) * stack_index
		var x := (vp_size.x - t.custom_minimum_size.x) * 0.5
		t.position = Vector2(x, y)


## 构造单条 toast 节点（PanelContainer + 内部 Label）
func _build_toast_node(msg: String, type: String) -> Control:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = 0
	
	# 按类型选择样式
	var style := StyleBoxFlat.new()
	style.bg_color = _bg_color_for_type(type)
	style.border_color = _border_color_for_type(type)
	style.set_border_width_all(2)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style)
	
	var label := Label.new()
	label.text = msg
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", _text_color_for_type(type))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 2)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	
	# 根据消息长度估算宽度（中文字符粗估 14px）
	var estimated_width := clampi(msg.length() * 14 + 40, 140, 320)
	panel.custom_minimum_size = Vector2(estimated_width, TOAST_HEIGHT)
	
	return panel


func _bg_color_for_type(type: String) -> Color:
	match type:
		"damage", "error":
			return Color(0.55, 0.12, 0.10, 0.92)
		"warn", "warning":
			return Color(0.55, 0.35, 0.10, 0.92)
		"buff", "success":
			return Color(0.10, 0.35, 0.18, 0.92)
		_:
			return Color(0.10, 0.10, 0.15, 0.92)


func _border_color_for_type(type: String) -> Color:
	match type:
		"damage", "error":
			return Color("#d44a2a")
		"warn", "warning":
			return Color("#e07830")
		"buff", "success":
			return Color("#38c060")
		_:
			return Color("#3c6cc8")


func _text_color_for_type(type: String) -> Color:
	match type:
		"damage", "error":
			return Color("#ffc8c0")
		"warn", "warning":
			return Color("#ffe0b0")
		"buff", "success":
			return Color("#c8ffd0")
		_:
			return Color("#d8e0e8")
