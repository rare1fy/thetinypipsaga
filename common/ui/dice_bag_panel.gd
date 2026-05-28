## 骰子袋面板 — 战斗中查看骰子库/弃骰库
## 左侧按钮 = 骰子库（蓝色），右侧按钮 = 弃骰库（红色）
## 点击展开全屏弹窗，显示所有骰子缩略图 + 点击查看详情

class_name DiceBagPanel
extends CanvasLayer

signal closed

enum PanelMode { DRAW_PILE, DISCARD_PILE }

const RARITY_COLORS: Dictionary = {
	0: Color("8899aa"),  # COMMON
	1: Color("44bb44"),  # UNCOMMON
	2: Color("4488ee"),  # RARE
	3: Color("cc44ee"),  # EPIC
	4: Color("ffaa22"),  # LEGENDARY
}

var _mode: PanelMode = PanelMode.DRAW_PILE
var _bg: ColorRect
var _panel: PanelContainer
var _title_label: Label
var _count_label: Label
var _grid: GridContainer
var _close_btn: Button
var _tooltip_panel: PanelContainer
var _tooltip_name: Label
var _tooltip_faces: Label
var _tooltip_desc: RichTextLabel

## 预缓存 StyleBox（按稀有度）
var _card_styles: Dictionary = {}  # {rarity: StyleBoxFlat}
var _panel_style_draw: StyleBoxFlat
var _panel_style_discard: StyleBoxFlat


func _ready() -> void:
	layer = 70
	_init_styles()
	_build_ui()
	visible = false


func open(mode: PanelMode) -> void:
	_mode = mode
	visible = true
	_tooltip_panel.visible = false
	_refresh()
	# 入场动画
	_panel.modulate.a = 0.0
	_panel.scale = Vector2(0.9, 0.9)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_panel, "modulate:a", 1.0, 0.2)
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.2).set_ease(Tween.EASE_OUT)
	_bg.modulate.a = 0.0
	tw.tween_property(_bg, "modulate:a", 1.0, 0.15)


func _close() -> void:
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_panel, "modulate:a", 0.0, 0.15)
	tw.tween_property(_panel, "scale", Vector2(0.9, 0.9), 0.15)
	tw.tween_property(_bg, "modulate:a", 0.0, 0.1)
	tw.chain().tween_callback(func():
		visible = false
		closed.emit()
	)


func _init_styles() -> void:
	for rarity: int in RARITY_COLORS:
		_card_styles[rarity] = _make_card_style(rarity)
	_panel_style_draw = _make_panel_style(Color("203860"))
	_panel_style_discard = _make_panel_style(Color("602020"))


func _build_ui() -> void:
	# 全屏暗幕
	_bg = ColorRect.new()
	_bg.color = Color(0, 0, 0, 0.85)
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.gui_input.connect(_on_bg_input)
	add_child(_bg)

	# 主面板
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(172, 240)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_panel.add_child(vbox)

	# 头部
	var header := HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(header)

	_title_label = Label.new()
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.add_theme_font_size_override("font_size", 8)
	header.add_child(_title_label)

	_count_label = Label.new()
	_count_label.add_theme_font_size_override("font_size", 4)
	_count_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	header.add_child(_count_label)

	_close_btn = Button.new()
	_close_btn.text = "x"
	_close_btn.flat = true
	_close_btn.add_theme_font_size_override("font_size", 8)
	_close_btn.pressed.connect(_close)
	header.add_child(_close_btn)

	# 骰子网格（ScrollContainer 包裹）
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(160, 192)
	vbox.add_child(scroll)

	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_grid)

	# Tooltip 面板
	_tooltip_panel = PanelContainer.new()
	_tooltip_panel.visible = false
	_tooltip_panel.custom_minimum_size = Vector2(92, 40)
	var tp_style := StyleBoxFlat.new()
	tp_style.bg_color = Color(0.05, 0.04, 0.08, 0.96)
	tp_style.border_color = Color("d4a030")
	tp_style.set_border_width_all(2)
	tp_style.set_corner_radius_all(3)
	tp_style.set_content_margin_all(8)
	_tooltip_panel.add_theme_stylebox_override("panel", tp_style)
	add_child(_tooltip_panel)

	var tp_vbox := VBoxContainer.new()
	tp_vbox.add_theme_constant_override("separation", 4)
	_tooltip_panel.add_child(tp_vbox)

	_tooltip_name = Label.new()
	_tooltip_name.add_theme_font_size_override("font_size", 4)
	tp_vbox.add_child(_tooltip_name)

	_tooltip_faces = Label.new()
	_tooltip_faces.add_theme_font_size_override("font_size", 4)
	_tooltip_faces.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	tp_vbox.add_child(_tooltip_faces)

	_tooltip_desc = RichTextLabel.new()
	_tooltip_desc.bbcode_enabled = true
	_tooltip_desc.fit_content = true
	_tooltip_desc.custom_minimum_size = Vector2(80, 20)
	_tooltip_desc.add_theme_font_size_override("normal_font_size", 4)
	tp_vbox.add_child(_tooltip_desc)


func _on_bg_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_close()


func _refresh() -> void:
	var dice_list: Array[String] = []
	if _mode == PanelMode.DRAW_PILE:
		dice_list.assign(DiceBag.dice_bag)
		_title_label.text = "[D] 骰子库"
		_count_label.text = "共 %d 颗" % dice_list.size()
		_panel.add_theme_stylebox_override("panel", _panel_style_draw)
	else:
		dice_list.assign(DiceBag.discard_pile)
		_title_label.text = "[R] 弃骰库"
		_count_label.text = "共 %d 颗" % dice_list.size()
		_panel.add_theme_stylebox_override("panel", _panel_style_discard)

	# 清空网格（即时删除避免闪烁）
	var old_children: Array[Node] = _grid.get_children()
	for child: Node in old_children:
		_grid.remove_child(child)
		child.free()

	if dice_list.is_empty():
		var empty_label := Label.new()
		empty_label.text = "空" if _mode == PanelMode.DISCARD_PILE else "骰子库已空，弃骰库将洗回"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		_grid.add_child(empty_label)
		return

	# 按稀有度分组排序
	var sorted_list: Array[String] = dice_list.duplicate()
	sorted_list.sort_custom(func(a: String, b: String) -> bool:
		var da: DiceDef = GameData.get_dice_def(a)
		var db: DiceDef = GameData.get_dice_def(b)
		if not da or not db:
			return a < b
		if da.rarity != db.rarity:
			return da.rarity > db.rarity
		return da.name < db.name
	)

	for dice_id: String in sorted_list:
		var def: DiceDef = GameData.get_dice_def(dice_id)
		if not def:
			continue
		var card := _make_dice_card(def)
		_grid.add_child(card)


func _make_dice_card(def: DiceDef) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(36, 40)
	var style: StyleBoxFlat = _card_styles.get(def.rarity, _card_styles.get(0))
	card.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 2)
	card.add_child(vbox)

	# 骰子名
	var name_label := Label.new()
	name_label.text = def.name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 4)
	name_label.add_theme_color_override("font_color", RARITY_COLORS.get(def.rarity, Color.WHITE))
	vbox.add_child(name_label)

	# 面值
	var faces_label := Label.new()
	faces_label.text = str(def.faces)
	faces_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	faces_label.add_theme_font_size_override("font_size", 4)
	faces_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	vbox.add_child(faces_label)

	# 点击事件
	card.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			_show_tooltip(def, card)
	)

	return card


func _show_tooltip(def: DiceDef, anchor: Control) -> void:
	_tooltip_panel.visible = true
	_tooltip_name.text = def.name
	_tooltip_name.add_theme_color_override("font_color", RARITY_COLORS.get(def.rarity, Color.WHITE))
	_tooltip_faces.text = "面值: %s" % str(def.faces)
	_tooltip_desc.text = def.get_display_description()

	# 定位到锚点上方
	await get_tree().process_frame  # 等待 tooltip 尺寸计算完成
	var anchor_rect: Rect2 = anchor.get_global_rect()
	_tooltip_panel.global_position = Vector2(
		anchor_rect.position.x + anchor_rect.size.x / 2.0 - _tooltip_panel.size.x / 2.0,
		anchor_rect.position.y - _tooltip_panel.size.y - 8
	)


func _make_panel_style(bg_color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(bg_color, 0.95)
	sb.border_color = Color(bg_color, 0.6).lightened(0.3)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(12)
	return sb


func _make_card_style(rarity: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	var base_color: Color = RARITY_COLORS.get(rarity, Color(0.4, 0.4, 0.4))
	sb.bg_color = Color(base_color, 0.15)
	sb.border_color = Color(base_color, 0.4)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	sb.set_content_margin_all(4)
	return sb
