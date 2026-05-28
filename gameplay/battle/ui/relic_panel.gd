## RelicBar — 战斗内底部遗物折叠条
##
## 交互规则（对齐原版 RelicPanelView.tsx）：
##   - 默认折叠：显示一条 "^ 遗物库 - N件 -" 按钮（贴在 HandPanel 顶部）
##   - 点击按钮 → 发信号 expand_requested，由 BattleScene 负责实例化 RelicOverlay 展开
##   - 伤害结算时：外部可调 request_expand() 强制展开（用于"结算时自动弹遗物栏"）
##   - 遗物触发闪光：外部可调 flash_relic(relic_id) 让对应格子闪烁
##     （闪光效果由 Overlay 读 _flashing_relic_ids 实现）
##
## 挂载方式：作为 HandPanel/HandVBox 顶部的第一个子节点挂入
##
## EventBus.relic_gained / relic_lost 触发自动刷新计数

class_name RelicBar
extends VBoxContainer

signal expand_requested
signal collapse_requested

const COLOR_GOLD: Color = Color("#d4a030")
const COLOR_GOLD_LIGHT: Color = Color("#f0c850")
const COLOR_TEXT_DIM: Color = Color(0.5019608, 0.5647059, 0.627451, 1)

var _toggle_btn: Button
var _count_label: Label
var _is_expanded: bool = false


# ── 生命周期 ─────────────────────────────────────

func _ready() -> void:
	add_theme_constant_override("separation", 0)
	_build_layout()
	_refresh_count()
	_connect_event_bus()


func _exit_tree() -> void:
	_disconnect_event_bus()


func _connect_event_bus() -> void:
	# EventBus 里如果有 relic_gained/relic_lost 信号就连上；没有就跳过
	if EventBus.has_signal("relic_gained"):
		EventBus.connect("relic_gained", _on_relic_changed)
	if EventBus.has_signal("relic_lost"):
		EventBus.connect("relic_lost", _on_relic_changed)


func _disconnect_event_bus() -> void:
	if EventBus.has_signal("relic_gained") and EventBus.is_connected("relic_gained", _on_relic_changed):
		EventBus.disconnect("relic_gained", _on_relic_changed)
	if EventBus.has_signal("relic_lost") and EventBus.is_connected("relic_lost", _on_relic_changed):
		EventBus.disconnect("relic_lost", _on_relic_changed)


func _on_relic_changed(_v: Variant = null) -> void:
	_refresh_count()


# ── 公开 API ─────────────────────────────────────

## 外部刷新计数入口
func refresh() -> void:
	_refresh_count()


## 强制展开（用于战斗结算时自动弹出）
func request_expand() -> void:
	if not _is_expanded:
		_is_expanded = true
		_update_toggle_arrow()
		expand_requested.emit()


## 强制折叠（Overlay 关闭时反向通知）
func notify_collapsed() -> void:
	_is_expanded = false
	_update_toggle_arrow()


# ── UI 构建 ──────────────────────────────────────

func _build_layout() -> void:
	# 顶部分隔线（替代原版 border-top）
	var sep := HSeparator.new()
	sep.custom_minimum_size = Vector2(4, 4)
	sep.add_theme_color_override("separator", Color(0.31, 0.27, 0.21, 0.6))
	add_child(sep)

	# 点击按钮（整条）
	_toggle_btn = Button.new()
	_toggle_btn.flat = true
	_toggle_btn.custom_minimum_size = Vector2(4, 16)
	_toggle_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_toggle_btn.focus_mode = Control.FOCUS_NONE
	_toggle_btn.pressed.connect(_on_toggle_pressed)
	add_child(_toggle_btn)

	# 按钮内容：垂直堆叠"^ / 遗物库 / - N 件 -"
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 0)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	_toggle_btn.add_child(inner)

	var arrow := Label.new()
	arrow.text = "^"
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrow.add_theme_color_override("font_color", COLOR_GOLD)
	arrow.add_theme_font_size_override("font_size", 4)
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arrow.name = "Arrow"
	inner.add_child(arrow)

	var title := Label.new()
	title.text = "遗物库"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", COLOR_GOLD_LIGHT)
	title.add_theme_font_size_override("font_size", 4)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(title)

	_count_label = Label.new()
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	_count_label.add_theme_font_size_override("font_size", 4)
	_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(_count_label)


func _refresh_count() -> void:
	if _count_label == null:
		return
	var n: int = PlayerState.relics.size()
	_count_label.text = "- %d 件 -" % n


func _update_toggle_arrow() -> void:
	if _toggle_btn == null:
		return
	var arrow: Label = _toggle_btn.get_node_or_null("Arrow") as Label
	if arrow == null:
		# 容错：兼容内部布局被替换的情况
		var inner: Node = _toggle_btn.get_child(0)
		if inner and inner.get_child_count() > 0:
			arrow = inner.get_child(0) as Label
	if arrow:
		arrow.text = "v" if _is_expanded else "^"


# ── 交互 ─────────────────────────────────────────

func _on_toggle_pressed() -> void:
	SoundPlayer.play_sound("click")
	_is_expanded = not _is_expanded
	_update_toggle_arrow()
	if _is_expanded:
		expand_requested.emit()
	else:
		collapse_requested.emit()
