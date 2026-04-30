## ModalManager — 全局弹窗管理器
##
## 职责：栈式管理 Modal，统一背景遮罩 / 标题栏 / 关闭按钮 / 淡入淡出 / ESC & 点外关闭。
## 用法：
##   ModalHub.open(content, title, options)
##     content: Control | PackedScene   # 弹窗正文
##     title: String                    # 标题栏文字（空字符串则不渲染标题栏）
##     options: Dictionary              # close_on_backdrop / close_on_esc / size / backdrop_alpha / show_close_btn
##   ModalHub.close()                   # 关最上层
##   ModalHub.close_all()
##
## 访问：通过 main.gd 挂载到 /root/Main/ModalHub，脚本里用 get_tree().root.get_node("Main/ModalHub") 取
##       或直接通过 @onready var hub := get_node("/root/Main/ModalHub")
##       更方便：使用 ModalHub.get_instance() 静态工厂（见 common/ui/modal_hub.gd）

extends CanvasLayer

# ============================================================
# 常量（面板默认尺寸 / 动画时长）
# ============================================================
const DEFAULT_PANEL_SIZE := Vector2(560, 720)
const VIEWPORT_MARGIN := 40                   # 面板距屏幕边缘最小留白
const BACKDROP_ALPHA_DEFAULT := 0.6
const FADE_IN_TIME := 0.18
const FADE_OUT_TIME := 0.14
const PANEL_POP_SCALE_START := 0.92

# ============================================================
# 信号
# ============================================================
signal modal_opened(modal_id: int)
signal modal_closed(modal_id: int)
signal all_modals_closed

# ============================================================
# 状态
# ============================================================
var _stack: Array[Dictionary] = []            # [{id, root, options}]
var _next_id: int = 1

func _ready() -> void:
	layer = 80                                  # Toast(50) < Modal(80) < Transition(100)
	# 允许捕获未消费的输入（ESC 关闭）
	process_mode = Node.PROCESS_MODE_ALWAYS


# ============================================================
# Public API
# ============================================================

## 打开一个 Modal。
## content 可以是 Control 节点或 PackedScene；其余见头部注释。
## 返回 modal_id，用于识别具体弹窗（close(id) 可指定关闭某层）。
func open(content: Variant, title: String = "", options: Dictionary = {}) -> int:
	var close_on_backdrop: bool = options.get("close_on_backdrop", true)
	var close_on_esc: bool = options.get("close_on_esc", true)
	var panel_size: Vector2 = options.get("size", DEFAULT_PANEL_SIZE)
	var backdrop_alpha: float = options.get("backdrop_alpha", BACKDROP_ALPHA_DEFAULT)
	var show_close_btn: bool = options.get("show_close_btn", true)
	
	var modal_id := _next_id
	_next_id += 1
	
	var root := _build_modal_shell(title, panel_size, backdrop_alpha, show_close_btn, modal_id)
	add_child(root)
	
	# 注入正文
	var content_host: Control = root.get_node("Panel/VBox/ContentHost") as Control
	_inject_content(content_host, content)
	
	# 淡入
	root.modulate.a = 0.0
	var panel := root.get_node("Panel") as Control
	panel.scale = Vector2(PANEL_POP_SCALE_START, PANEL_POP_SCALE_START)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(root, "modulate:a", 1.0, FADE_IN_TIME)
	tw.tween_property(panel, "scale", Vector2.ONE, FADE_IN_TIME)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	_stack.append({
		"id": modal_id,
		"root": root,
		"close_on_backdrop": close_on_backdrop,
		"close_on_esc": close_on_esc,
	})
	modal_opened.emit(modal_id)
	return modal_id


## 关闭最上层 Modal（可选传 id 指定层）
func close(modal_id: int = -1) -> void:
	if _stack.is_empty():
		return
	var target_index := _stack.size() - 1
	if modal_id != -1:
		for i in _stack.size():
			if _stack[i].id == modal_id:
				target_index = i
				break
	_close_at(target_index)


## 关闭所有 Modal
func close_all() -> void:
	while not _stack.is_empty():
		_close_at(_stack.size() - 1)


## 是否有 Modal 打开
func is_open() -> bool:
	return not _stack.is_empty()


# ============================================================
# 输入处理（ESC 关顶层）
# ============================================================

func _unhandled_input(event: InputEvent) -> void:
	if _stack.is_empty():
		return
	if event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		var top: Dictionary = _stack[-1]
		if top.close_on_esc:
			close()
			get_viewport().set_input_as_handled()


# ============================================================
# 内部 — 构建 Modal 壳
# ============================================================

func _build_modal_shell(title: String, panel_size: Vector2, backdrop_alpha: float, show_close_btn: bool, modal_id: int) -> Control:
	var root := Control.new()
	root.name = "Modal_%d" % modal_id
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP   # 阻止输入穿透到下层
	
	# 背景遮罩
	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = Color(0.0, 0.0, 0.0, backdrop_alpha)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.gui_input.connect(_on_backdrop_input.bind(modal_id))
	root.add_child(backdrop)
	
	# 面板
	var panel := PanelContainer.new()
	panel.name = "Panel"
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#1a1d2a")
	style.border_color = Color("#4a5578")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", style)
	# 居中定位
	var vp_size := get_viewport().get_visible_rect().size
	var clamped_size := Vector2(
		min(panel_size.x, vp_size.x - VIEWPORT_MARGIN * 2),
		min(panel_size.y, vp_size.y - VIEWPORT_MARGIN * 2)
	)
	panel.custom_minimum_size = clamped_size
	panel.size = clamped_size
	panel.position = (vp_size - clamped_size) * 0.5
	panel.pivot_offset = clamped_size * 0.5
	root.add_child(panel)
	
	# 面板内部：VBox = [标题栏] + [内容宿主]
	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 10)
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(vbox)
	
	if title != "" or show_close_btn:
		vbox.add_child(_build_title_bar(title, show_close_btn, modal_id))
	
	var content_host := Control.new()
	content_host.name = "ContentHost"
	content_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_host.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(content_host)
	
	return root


func _build_title_bar(title: String, show_close_btn: bool, modal_id: int) -> Control:
	var bar := HBoxContainer.new()
	bar.name = "TitleBar"
	bar.add_theme_constant_override("separation", 8)
	
	var title_label := Label.new()
	title_label.text = title
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color("#e6e8f0"))
	bar.add_child(title_label)
	
	if show_close_btn:
		var close_btn := Button.new()
		close_btn.text = "×"
		close_btn.custom_minimum_size = Vector2(32, 32)
		close_btn.add_theme_font_size_override("font_size", 20)
		close_btn.pressed.connect(func(): close(modal_id))
		bar.add_child(close_btn)
	
	return bar


func _inject_content(host: Control, content: Variant) -> void:
	if content is PackedScene:
		var inst: Node = (content as PackedScene).instantiate()
		host.add_child(inst)
		if inst is Control:
			(inst as Control).set_anchors_preset(Control.PRESET_FULL_RECT)
	elif content is Control:
		host.add_child(content as Control)
		(content as Control).set_anchors_preset(Control.PRESET_FULL_RECT)
	elif content is Node:
		host.add_child(content as Node)
	else:
		push_warning("[ModalHub] Unsupported content type: %s" % typeof(content))


# ============================================================
# 内部 — 关闭逻辑
# ============================================================

func _close_at(index: int) -> void:
	if index < 0 or index >= _stack.size():
		return
	var entry: Dictionary = _stack[index]
	var modal_id: int = entry.id
	var root: Control = entry.root
	_stack.remove_at(index)
	
	if is_instance_valid(root):
		var panel := root.get_node_or_null("Panel") as Control
		var tw := create_tween().set_parallel(true)
		tw.tween_property(root, "modulate:a", 0.0, FADE_OUT_TIME)
		if panel:
			tw.tween_property(panel, "scale", Vector2(PANEL_POP_SCALE_START, PANEL_POP_SCALE_START), FADE_OUT_TIME)
		tw.chain().tween_callback(func(): 
			if is_instance_valid(root):
				root.queue_free()
		)
	
	modal_closed.emit(modal_id)
	if _stack.is_empty():
		all_modals_closed.emit()


func _on_backdrop_input(event: InputEvent, modal_id: int) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	# 只有最顶层响应点外关闭
	if _stack.is_empty() or _stack[-1].id != modal_id:
		return
	if _stack[-1].close_on_backdrop:
		close(modal_id)
