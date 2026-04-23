## 地图界面 — 显示地图节点和导航

extends Control

@onready var map_container: VBoxContainer = %MapContainer
@onready var chapter_label: Label = %ChapterLabel

var _map_nodes: Array = []


func _ready() -> void:
	GameManager.phase_changed.connect(_on_phase_changed)


func _on_phase_changed(new_phase: GameTypes.GamePhase) -> void:
	visible = new_phase == GameTypes.GamePhase.MAP
	if visible and _map_nodes.is_empty():
		_generate_map()


func _generate_map() -> void:
	_map_nodes = MapGenerator.generate_chapter(GameManager.chapter)
	chapter_label.text = GameBalance.CHAPTER_CONFIG.chapterNames[GameManager.chapter - 1]
	_refresh_map_ui()


func _refresh_map_ui() -> void:
	for child in map_container.get_children():
		child.queue_free()
	
	# 按层显示
	var layers: Dictionary = {}
	for node in _map_nodes:
		if not layers.has(node.depth):
			layers[node.depth] = []
		layers[node.depth].append(node)
	
	for depth in range(15):
		if not layers.has(depth):
			continue
		var hbox := HBoxContainer.new()
		hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		
		for node in layers[depth]:
			var btn := Button.new()
			btn.custom_minimum_size = Vector2(50, 30)
			btn.text = _node_type_short(node.type)
			btn.tooltip_text = "%s (深度%d)" % [GameTypes.NodeType.keys()[node.type], node.depth]
			
			# 着色
			match node.type:
				GameTypes.NodeType.ENEMY: btn.modulate = Color(1.0, 0.6, 0.6)
				GameTypes.NodeType.ELITE: btn.modulate = Color(1.0, 0.3, 0.3)
				GameTypes.NodeType.BOSS: btn.modulate = Color(1.0, 0.2, 0.2)
				GameTypes.NodeType.CAMPFIRE: btn.modulate = Color(1.0, 0.8, 0.3)
				GameTypes.NodeType.MERCHANT: btn.modulate = Color(0.3, 0.8, 1.0)
				GameTypes.NodeType.EVENT: btn.modulate = Color(0.6, 1.0, 0.6)
				GameTypes.NodeType.TREASURE: btn.modulate = Color(1.0, 1.0, 0.3)
			
			if node.visited:
				btn.disabled = true
				btn.modulate = Color(0.3, 0.3, 0.3)
			elif not node.available:
				btn.disabled = true
			
			btn.pressed.connect(_on_node_clicked.bind(node))
			hbox.add_child(btn)
		
		map_container.add_child(hbox)


func _on_node_clicked(node) -> void:
	if not node.available:
		return
	
	SoundPlayer.play_sound("click")
	MapGenerator.visit_node(_map_nodes, node.id)
	GameManager.current_node = node.depth
	
	# 解锁下一层
	MapGenerator.get_next_available(_map_nodes, node.id)
	
	# 进入对应场景
	match node.type:
		GameTypes.NodeType.ENEMY, GameTypes.NodeType.ELITE, GameTypes.NodeType.BOSS:
			GameManager.set_phase(GameTypes.GamePhase.BATTLE)
			# 生成波次数据
			_spawn_battle(node.type)
		GameTypes.NodeType.CAMPFIRE:
			GameManager.set_phase(GameTypes.GamePhase.CAMPFIRE)
		GameTypes.NodeType.MERCHANT:
			GameManager.set_phase(GameTypes.GamePhase.MERCHANT)
		GameTypes.NodeType.EVENT:
			GameManager.set_phase(GameTypes.GamePhase.EVENT)
		GameTypes.NodeType.TREASURE:
			GameManager.set_phase(GameTypes.GamePhase.TREASURE)
	
	_refresh_map_ui()


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
	
	# 通知战斗场景
	GameManager.set_phase(GameTypes.GamePhase.BATTLE)
	# 战斗场景通过信号接收波次数据


static func _node_type_short(type: GameTypes.NodeType) -> String:
	match type:
		GameTypes.NodeType.ENEMY: return "战"
		GameTypes.NodeType.ELITE: return "精"
		GameTypes.NodeType.BOSS: return "王"
		GameTypes.NodeType.CAMPFIRE: return "火"
		GameTypes.NodeType.MERCHANT: return "商"
		GameTypes.NodeType.EVENT: return "事"
		GameTypes.NodeType.TREASURE: return "宝"
		_: return "?"
