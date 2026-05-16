## RelicOverlay — 遗物库展开半屏面板
##
## 对齐原版 RelicPanelView.tsx 的 showRelicPanel 半屏弹窗：
##   - 从底部 Tween 滑入，高度约 55% 屏高
##   - 顶部标题栏 "遗物库 (N)" + 关闭按钮
##   - 6 列网格展示遗物图标；点击图标 → 弹遗物详情 modal
##   - 触发中的遗物（flashing_relic_ids）边框闪金光
##   - 点击遮罩背景也关闭
##
## 挂载方式：由 BattleScene 在 RelicBar.expand_requested 时动态实例化，挂到 %Root 下
## 关闭方式：自行 queue_free + 发出 closed 信号给 BattleScene

class_name RelicOverlay
extends Control

signal closed

const RelicGuideRef := preload("res://common/ui/relic_guide.gd")
const ModalHubRef := preload("res://common/ui/modal_hub.gd")

const COLOR_GOLD: Color = Color("#d4a030")
const COLOR_GOLD_LIGHT: Color = Color("#f0c850")
const COLOR_TEXT_DIM: Color = Color(0.5019608, 0.5647059, 0.627451, 1)
const COLOR_TEXT_BRIGHT: Color = Color(0.84, 0.87, 0.94, 1)
const COLOR_PANEL_BG: Color = Color(0.0625, 0.055, 0.078, 0.98)
const COLOR_PANEL_BORDER: Color = Color(0.231, 0.251, 0.314, 1)

const ANIM_DURATION: float = 0.28
const HEIGHT_RATIO: float = 0.55  # 占屏高 55%
const COLUMNS: int = 6
const SLOT_SIZE: Vector2 = Vector2(48, 52)

var _panel: PanelContainer
var _grid: GridContainer
var _title_label: Label
var _backdrop: ColorRect
var _flashing_ids: Array[String] = []


# ── 生命周期 ─────────────────────────────────────

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP  # 拦截点击，不让穿透到战斗场景
	_build_layout()
	_refresh()
	_play_enter_anim()


## 外部接口：设置当前正在闪光的遗物 id（通常由 resolver 在遗物触发时调用）
func set_flashing_ids(ids: Array[String]) -> void:
	_flashing_ids = ids.duplicate()
	_refresh()  # 重建格子以应用闪光样式


## 外部关闭入口（带动画）
func close_with_anim() -> void:
	_play_exit_anim()


# ── 布局 ─────────────────────────────────────────

func _build_layout() -> void:
	# 半透明遮罩（点击关闭）
	_backdrop = ColorRect.new()
	_backdrop.color = Color(0, 0, 0, 0.5)
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.gui_input.connect(_on_backdrop_input)
	add_child(_backdrop)

	# 底部滑入面板
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	var vp_size: Vector2 = get_viewport_rect().size
	var panel_height: float = vp_size.y * HEIGHT_RATIO
	_panel.custom_minimum_size = Vector2(0, panel_height)
	_panel.size = Vector2(vp_size.x, panel_height)
	_panel.position = Vector2(0, vp_size.y)  # 初始在屏外（等_play_enter_anim拉上来）
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	# 样式
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL_BG
	style.border_color = COLOR_GOLD
	style.border_width_top = 3
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 10)
	_panel.add_child(inner)

	# 顶部标题栏
	inner.add_child(_build_header())

	# 分隔线
	var sep := HSeparator.new()
	sep.add_theme_color_override("separator", COLOR_PANEL_BORDER)
	inner.add_child(sep)

	# 滚动 + 网格
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.add_child(scroll)

	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_grid)


func _build_header() -> Control:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)

	_title_label = Label.new()
	_title_label.add_theme_color_override("font_color", COLOR_GOLD)
	_title_label.add_theme_font_size_override("font_size", 14)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title_label)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.flat = true
	close_btn.custom_minimum_size = Vector2(28, 28)
	close_btn.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	close_btn.add_theme_font_size_override("font_size", 16)
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.pressed.connect(_on_close_pressed)
	header.add_child(close_btn)

	return header


# ── 数据刷新 ─────────────────────────────────────

func _refresh() -> void:
	if _grid == null:
		return
	for child: Node in _grid.get_children():
		child.queue_free()

	var relics: Array[Dictionary] = PlayerState.relics
	if _title_label != null:
		_title_label.text = "遗物库 (%d)" % relics.size()

	if relics.is_empty():
		var empty := Label.new()
		empty.text = "暂无遗物"
		empty.add_theme_color_override("font_color", COLOR_TEXT_DIM)
		empty.add_theme_font_size_override("font_size", 11)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# 填 COLUMNS 列让它居中占位
		var holder := CenterContainer.new()
		holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		holder.add_child(empty)
		_grid.add_child(holder)
		return

	for r: Dictionary in relics:
		var def: RelicDef = GameData.get_relic_def(r.get("id", ""))
		if def == null:
			continue
		_grid.add_child(_build_slot(def, r))


# ── 格子构建 ─────────────────────────────────────

func _build_slot(def: RelicDef, instance: Dictionary) -> Control:
	var box := PanelContainer.new()
	box.custom_minimum_size = SLOT_SIZE
	box.mouse_filter = Control.MOUSE_FILTER_STOP

	var is_flashing: bool = _flashing_ids.has(def.id)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.102, 0.118, 0.165, 1)
	style.border_color = COLOR_GOLD if is_flashing else COLOR_PANEL_BORDER
	style.set_border_width_all(2 if is_flashing else 1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 2
	style.content_margin_right = 2
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	box.add_theme_stylebox_override("panel", style)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(col)

	# 图标（稀有度 emoji 占位，后续美术可替换 TextureRect）
	var icon := Label.new()
	icon.text = _rarity_emoji(def.rarity)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 18)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(icon)

	# 名字（截断到 4 字符，对齐原版）
	var name_label := Label.new()
	var short_name: String = def.name
	if short_name.length() > 4:
		short_name = short_name.substr(0, 4)
	name_label.text = short_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	name_label.add_theme_font_size_override("font_size", 8)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(name_label)

	# 计数（如有）
	var counter: int = int(instance.get("counter", 0))
	if counter > 0:
		var badge := Label.new()
		badge.text = "%d%s" % [counter, instance.get("counterLabel", "")]
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.add_theme_color_override("font_color", Color("#f9a066"))
		badge.add_theme_font_size_override("font_size", 8)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(badge)

	# 点击 → 打开遗物详情
	box.gui_input.connect(_on_slot_input.bind(def))
	return box


func _rarity_emoji(rarity: int) -> String:
	match rarity:
		GameTypes.RelicRarity.COMMON:
			return "⚪"
		GameTypes.RelicRarity.UNCOMMON:
			return "🔵"
		GameTypes.RelicRarity.RARE:
			return "🟣"
		GameTypes.RelicRarity.LEGENDARY:
			return "🟠"
	return "⚪"


# ── 交互 ─────────────────────────────────────────

func _on_slot_input(event: InputEvent, def: RelicDef) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		SoundPlayer.play_sound("click")
		# 复用现有遗物图鉴 modal（focus 到该遗物）
		ModalHubRef.open(
			RelicGuideRef.new(),
			"遗物：%s" % def.name,
			{"size": Vector2(560, 780), "close_on_backdrop": true}
		)


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_close_pressed()


func _on_close_pressed() -> void:
	SoundPlayer.play_sound("click")
	close_with_anim()


# ── 动画 ─────────────────────────────────────────

func _play_enter_anim() -> void:
	if _panel == null or _backdrop == null:
		return
	var vp_size: Vector2 = get_viewport_rect().size
	var target_y: float = vp_size.y - _panel.size.y
	# 背景淡入
	_backdrop.modulate.a = 0.0
	var bd_tw: Tween = create_tween()
	bd_tw.tween_property(_backdrop, "modulate:a", 1.0, ANIM_DURATION)
	# 面板滑入
	var panel_tw: Tween = create_tween()
	panel_tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	panel_tw.tween_property(_panel, "position:y", target_y, ANIM_DURATION)


func _play_exit_anim() -> void:
	if _panel == null or _backdrop == null:
		closed.emit()
		queue_free()
		return
	var vp_size: Vector2 = get_viewport_rect().size
	# 背景淡出
	var bd_tw: Tween = create_tween()
	bd_tw.tween_property(_backdrop, "modulate:a", 0.0, ANIM_DURATION * 0.7)
	# 面板下滑
	var panel_tw: Tween = create_tween()
	panel_tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	panel_tw.tween_property(_panel, "position:y", vp_size.y, ANIM_DURATION)
	await panel_tw.finished
	if not is_inside_tree():
		return
	closed.emit()
	queue_free()
