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

@onready var _bg: ColorRect = %Background
@onready var _panel: PanelContainer = %Panel
@onready var _title_label: Label = %TitleLabel
@onready var _count_label: Label = %CountLabel
@onready var _grid: GridContainer = %DiceGrid
@onready var _close_btn: Button = %CloseBtn
@onready var _tooltip_panel: PanelContainer = %TooltipPanel
@onready var _tooltip_name: Label = %TooltipName
@onready var _tooltip_faces: Label = %TooltipFaces
@onready var _tooltip_desc: RichTextLabel = %TooltipDesc


func _ready() -> void:
	_close_btn.pressed.connect(_close)
	_bg.gui_input.connect(_on_bg_input)
	_tooltip_panel.visible = false
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


func _on_bg_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_close()


func _refresh() -> void:
	var dice_list: Array[String] = []
	if _mode == PanelMode.DRAW_PILE:
		dice_list.assign(DiceBag.dice_bag)
		_title_label.text = "🎲 骰子库"
		_count_label.text = "共 %d 颗" % dice_list.size()
		_panel.add_theme_stylebox_override("panel", _make_panel_style(Color("203860")))
	else:
		dice_list.assign(DiceBag.discard_pile)
		_title_label.text = "♻ 弃骰库"
		_count_label.text = "共 %d 颗" % dice_list.size()
		_panel.add_theme_stylebox_override("panel", _make_panel_style(Color("602020")))

	# 清空网格
	for child: Node in _grid.get_children():
		child.queue_free()

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
		return da.display_name < db.display_name
	)

	for dice_id: String in sorted_list:
		var def: DiceDef = GameData.get_dice_def(dice_id)
		if not def:
			continue
		var card := _make_dice_card(def)
		_grid.add_child(card)


func _make_dice_card(def: DiceDef) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(72, 80)
	card.add_theme_stylebox_override("panel", _make_card_style(def.rarity))

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 2)
	card.add_child(vbox)

	# 骰子名
	var name_label := Label.new()
	name_label.text = def.display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.add_theme_color_override("font_color", RARITY_COLORS.get(def.rarity, Color.WHITE))
	vbox.add_child(name_label)

	# 面值
	var faces_label := Label.new()
	faces_label.text = str(def.faces)
	faces_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	faces_label.add_theme_font_size_override("font_size", 9)
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
	_tooltip_name.text = def.display_name
	_tooltip_name.add_theme_color_override("font_color", RARITY_COLORS.get(def.rarity, Color.WHITE))
	_tooltip_faces.text = "面值: %s" % str(def.faces)
	_tooltip_desc.text = def.get_display_description()

	# 定位到锚点上方
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
