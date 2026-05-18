## 地图界面 — 杀戮尖塔风格随机排布地图
## 照搬原版 dicehero2 的 MapScreen + useMapLayout 逻辑

extends Control

@onready var chapter_label: Label = %ChapterLabel
@onready var scroll_container: ScrollContainer = %ScrollContainer
@onready var map_canvas: Control = %MapCanvas

## 布局常量
const LAYER_HEIGHT: float = 140.0   ## 每层间距（像素）
const CANVAS_WIDTH: float = 352.0   ## 画布宽度（= viewport 宽度）
const NODE_SIZE: Vector2 = Vector2(28, 28)
const MARGIN_TOP: float = 60.0
const MARGIN_BOTTOM: float = 40.0

## 节点图标映射
const NODE_ICONS: Dictionary = {
	GameTypes.NodeType.ENEMY: "⚔",
	GameTypes.NodeType.ELITE: "💀",
	GameTypes.NodeType.BOSS: "👑",
	GameTypes.NodeType.CAMPFIRE: "🔥",
	GameTypes.NodeType.MERCHANT: "🛒",
	GameTypes.NodeType.EVENT: "❓",
	GameTypes.NodeType.TREASURE: "💎",
}

## 节点颜色映射
const NODE_COLORS: Dictionary = {
	GameTypes.NodeType.ENEMY: Color(0.85, 0.35, 0.35),
	GameTypes.NodeType.ELITE: Color(1.0, 0.2, 0.5),
	GameTypes.NodeType.BOSS: Color(1.0, 0.15, 0.15),
	GameTypes.NodeType.CAMPFIRE: Color(1.0, 0.75, 0.2),
	GameTypes.NodeType.MERCHANT: Color(0.3, 0.8, 1.0),
	GameTypes.NodeType.EVENT: Color(0.5, 1.0, 0.5),
	GameTypes.NodeType.TREASURE: Color(1.0, 1.0, 0.3),
}

var _map_nodes: Array = []
var _node_positions: Dictionary = {}  ## id -> Vector2 (canvas坐标)
var _node_buttons: Dictionary = {}    ## id -> Button
var _navigating: bool = false


func _ready() -> void:
	GameManager.phase_changed.connect(_on_phase_changed)


func _on_phase_changed(new_phase: GameTypes.GamePhase) -> void:
	visible = new_phase == GameTypes.GamePhase.MAP
	if visible:
		if _map_nodes.is_empty():
			_generate_map()
		else:
			_refresh_map_ui()
		_navigating = false


func _generate_map() -> void:
	_map_nodes = MapGenerator.generate_chapter(GameManager.chapter)
	var chapter_names: Array = ["飓风城外围", "碎牙堡荒原", "暗渊城", "月影城与灰谷", "龙眠圣殿"]
	var ch_idx: int = clampi(GameManager.chapter - 1, 0, chapter_names.size() - 1)
	chapter_label.text = "第%d章 · %s" % [GameManager.chapter, chapter_names[ch_idx]]
	_calculate_positions()
	_refresh_map_ui()
	# 立即定位到当前可用节点
	_scroll_to_current()


func _calculate_positions() -> void:
	_node_positions.clear()
	var max_depth: int = 0
	for node in _map_nodes:
		if node.depth > max_depth:
			max_depth = node.depth

	# 画布高度 = 层数 × 层高 + 上下边距
	var canvas_height: float = float(max_depth + 1) * LAYER_HEIGHT + MARGIN_TOP + MARGIN_BOTTOM
	map_canvas.custom_minimum_size = Vector2(CANVAS_WIDTH, canvas_height)

	# 计算每个节点的画布坐标
	# 注意：地图从下往上显示（depth=0 在底部，depth=max 在顶部）
	for node in _map_nodes:
		var y: float = canvas_height - MARGIN_BOTTOM - float(node.depth) * LAYER_HEIGHT
		var x: float = node.x / 100.0 * (CANVAS_WIDTH - 40.0) + 20.0
		_node_positions[node.id] = Vector2(x, y)


func _refresh_map_ui() -> void:
	# 清除旧内容
	for child in map_canvas.get_children():
		child.queue_free()
	_node_buttons.clear()

	# 先画连线（用 Line2D）
	_draw_connections()

	# 再画节点
	for node in _map_nodes:
		var pos: Vector2 = _node_positions.get(node.id, Vector2.ZERO)
		var btn := Button.new()
		btn.custom_minimum_size = NODE_SIZE
		btn.size = NODE_SIZE
		btn.position = pos - NODE_SIZE * 0.5
		btn.text = NODE_ICONS.get(node.type, "?")
		btn.add_theme_font_size_override("font_size", 12)

		# 样式
		var color: Color = NODE_COLORS.get(node.type, Color.WHITE)
		if node.visited:
			btn.modulate = Color(0.3, 0.3, 0.3, 0.6)
			btn.disabled = true
		elif node.available:
			btn.modulate = color
			# 可用节点脉冲动画
			var tween := create_tween()
			tween.set_loops()
			tween.tween_property(btn, "modulate:a", 0.6, 0.8).set_trans(Tween.TRANS_SINE)
			tween.tween_property(btn, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_SINE)
		else:
			btn.modulate = Color(0.4, 0.4, 0.4, 0.5)
			btn.disabled = true

		btn.pressed.connect(_on_node_clicked.bind(node))
		map_canvas.add_child(btn)
		_node_buttons[node.id] = btn


func _draw_connections() -> void:
	for node in _map_nodes:
		if node.connections.is_empty():
			continue
		var from_pos: Vector2 = _node_positions.get(node.id, Vector2.ZERO)
		for conn_id in node.connections:
			var to_pos: Vector2 = _node_positions.get(conn_id, Vector2.ZERO)
			if to_pos == Vector2.ZERO:
				continue
			var line := Line2D.new()
			line.add_point(from_pos)
			line.add_point(to_pos)
			line.width = 1.5

			# 连线颜色：已走过的路径亮，未走过的暗
			var from_node := MapGenerator.find_node(_map_nodes, node.id)
			var to_node := MapGenerator.find_node(_map_nodes, conn_id)
			if from_node and from_node.visited:
				line.default_color = Color(0.6, 0.6, 0.6, 0.7)
			elif to_node and to_node.available:
				line.default_color = Color(0.8, 0.8, 0.5, 0.5)
			else:
				line.default_color = Color(0.3, 0.3, 0.3, 0.3)

			map_canvas.add_child(line)


func _on_node_clicked(node) -> void:
	if _navigating:
		return
	if not node.available:
		return
	_navigating = true

	SoundPlayer.play_sound("click")
	MapGenerator.visit_node(_map_nodes, node.id)
	GameManager.current_node = node.depth

	# 解锁下一层
	MapGenerator.get_next_available(_map_nodes, node.id)

	# 进入对应场景
	match node.type:
		GameTypes.NodeType.ENEMY, GameTypes.NodeType.ELITE, GameTypes.NodeType.BOSS:
			_spawn_battle(node.type)
		GameTypes.NodeType.CAMPFIRE:
			GameManager.set_phase(GameTypes.GamePhase.CAMPFIRE)
		GameTypes.NodeType.MERCHANT:
			GameManager.set_phase(GameTypes.GamePhase.MERCHANT)
		GameTypes.NodeType.EVENT:
			GameManager.set_phase(GameTypes.GamePhase.EVENT)
		GameTypes.NodeType.TREASURE:
			GameManager.set_phase(GameTypes.GamePhase.TREASURE)


func _spawn_battle(node_type: GameTypes.NodeType) -> void:
	var battle_type := MapGenerator.get_battle_type(node_type)
	var wave_ids: Array[String] = []

	match battle_type:
		"enemy":
			var normals := EnemyConfig.get_normals_for_chapter(GameManager.chapter)
			if normals.size() > 0:
				var picked := normals[randi() % normals.size()]
				wave_ids.append(picked.id)
		"elite":
			var elites := EnemyConfig.get_elites_for_chapter(GameManager.chapter)
			if elites.size() > 0:
				wave_ids.append(elites[randi() % elites.size()].id)
		"boss":
			var bosses := EnemyConfig.get_bosses_for_chapter(GameManager.chapter)
			if bosses.size() > 0:
				wave_ids.append(bosses[randi() % bosses.size()].id)

	GameManager.set_phase(GameTypes.GamePhase.BATTLE)


func _scroll_to_current() -> void:
	# 找到当前可用节点中最低的（depth 最小），直接定位
	var target_y: float = 0.0
	for node in _map_nodes:
		if node.available:
			var pos: Vector2 = _node_positions.get(node.id, Vector2.ZERO)
			target_y = maxf(target_y, pos.y)

	# 滚动到目标位置（居中显示）
	var viewport_h: float = scroll_container.size.y
	var scroll_target: float = target_y - viewport_h * 0.5
	scroll_target = clampf(scroll_target, 0.0, map_canvas.custom_minimum_size.y - viewport_h)
	scroll_container.scroll_vertical = int(scroll_target)
