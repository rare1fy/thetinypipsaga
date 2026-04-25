## 敌人视图组件 — 对应原版 EnemyStageView.tsx 单个敌人渲染
## 职责：姓名/HP/护甲 + 距离条 + 纵深缩放 + 呼吸动画 + 状态图标
## 外部通过 setup(enemy) 绑定数据

class_name EnemyView
extends PanelContainer

signal enemy_clicked(enemy_uid: String)

# 距离条最多 3 格（对应原版 Array.from({length:3})）
const MAX_DISTANCE_DOTS := 3
const DISTANCE_DOT_SIZE := Vector2(6, 6)
const DISTANCE_COLOR_FILLED := Color("#e07830")         # --pixel-orange
const DISTANCE_COLOR_EMPTY := Color(1, 1, 1, 0.15)
const RANGED_LABEL_COLOR := Color("#30d8d0")            # --pixel-cyan-light
const MELEE_LABEL_COLOR := Color("#e07830")             # --pixel-orange-light

var _enemy: EnemyInstance = null
var _vbox: VBoxContainer = null
var _name_label: Label = null
var _combat_type_label: Label = null
var _distance_row: HBoxContainer = null
var _distance_dots: Array[ColorRect] = []
var _distance_text: Label = null
var _hp_bar: ProgressBar = null
var _hp_text: Label = null
var _armor_label: Label = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(110, 0)
	
	_vbox = VBoxContainer.new()
	_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_vbox.add_theme_constant_override("separation", 2)
	add_child(_vbox)
	
	# 顶部：姓名 + 职业标签
	var header := HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_theme_constant_override("separation", 4)
	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 12)
	header.add_child(_name_label)
	_combat_type_label = Label.new()
	_combat_type_label.add_theme_font_size_override("font_size", 9)
	header.add_child(_combat_type_label)
	_vbox.add_child(header)
	
	# 距离条
	_distance_row = HBoxContainer.new()
	_distance_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_distance_row.add_theme_constant_override("separation", 2)
	for i in MAX_DISTANCE_DOTS:
		var dot := ColorRect.new()
		dot.custom_minimum_size = DISTANCE_DOT_SIZE
		dot.color = DISTANCE_COLOR_EMPTY
		_distance_dots.append(dot)
		_distance_row.add_child(dot)
	_distance_text = Label.new()
	_distance_text.add_theme_font_size_override("font_size", 9)
	_distance_text.add_theme_color_override("font_color", DISTANCE_COLOR_FILLED)
	_distance_row.add_child(_distance_text)
	_vbox.add_child(_distance_row)
	
	# HP 条
	_hp_bar = ProgressBar.new()
	_hp_bar.custom_minimum_size = Vector2(100, 10)
	_hp_bar.show_percentage = false
	_vbox.add_child(_hp_bar)
	
	# HP 文字
	_hp_text = Label.new()
	_hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_text.add_theme_font_size_override("font_size", 10)
	_vbox.add_child(_hp_text)
	
	# 护甲（按需显示）
	_armor_label = Label.new()
	_armor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_armor_label.add_theme_font_size_override("font_size", 10)
	_armor_label.add_theme_color_override("font_color", Color("#88bbff"))
	_armor_label.visible = false
	_vbox.add_child(_armor_label)
	
	gui_input.connect(_on_gui_input)


## 外部接口：绑定敌人实例并刷新视觉
func setup(enemy: EnemyInstance) -> void:
	_enemy = enemy
	_refresh_visual()


func get_enemy_uid() -> String:
	return _enemy.uid if _enemy else ""


func _refresh_visual() -> void:
	if _enemy == null:
		return
	
	_name_label.text = _enemy.name
	
	# 战斗类型（近/远）
	var is_melee := _enemy.combat_type == GameTypes.EnemyCombatType.WARRIOR \
		or _enemy.combat_type == GameTypes.EnemyCombatType.GUARDIAN
	_combat_type_label.text = "[近]" if is_melee else "[远]"
	_combat_type_label.add_theme_color_override(
		"font_color", MELEE_LABEL_COLOR if is_melee else RANGED_LABEL_COLOR
	)
	
	# 距离条
	var dist := maxi(0, _enemy.distance)
	var show_distance := dist > 0
	_distance_row.visible = show_distance
	if show_distance:
		for i in MAX_DISTANCE_DOTS:
			_distance_dots[i].color = DISTANCE_COLOR_FILLED if i < dist else DISTANCE_COLOR_EMPTY
		_distance_text.text = "距%d" % dist
	
	# HP
	_hp_bar.max_value = _enemy.max_hp
	_hp_bar.value = maxi(0, _enemy.hp)
	_hp_text.text = "HP: %d/%d" % [maxi(0, _enemy.hp), _enemy.max_hp]
	
	# 护甲
	if _enemy.armor > 0:
		_armor_label.text = "护甲: %d" % _enemy.armor
		_armor_label.visible = true
	else:
		_armor_label.visible = false
	
	# 纵深视觉（缩放 / y 偏移 / 亮度）
	var depth: Dictionary = BattleHelpers.get_depth_visuals(dist)
	scale = Vector2(depth.depth_scale, depth.depth_scale)
	position.y = depth.depth_y
	modulate = Color(depth.depth_brightness, depth.depth_brightness, depth.depth_brightness, 1.0)
	z_index = int(depth.depth_z)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _enemy:
			enemy_clicked.emit(_enemy.uid)
