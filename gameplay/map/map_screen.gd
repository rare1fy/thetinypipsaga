## 地图界面 — 显示地图节点和导航

extends Node2D
@onready var map_container: VBoxContainer = %MapContainer
@onready var chapter_label: Label = %ChapterLabel

var _map_nodes: Array = []


func _ready() -> void:
	GameManager.phase_changed.connect(_on_phase_changed)
	# Godot 版 main.gd 采用"每次切场景 free + instantiate"模式，
	# 进入时当前 phase 就已经是 MAP，phase_changed 不会再触发 → 必须手动兜底生成。
	if GameManager.phase == GameTypes.GamePhase.MAP and _map_nodes.is_empty():
		_generate_map()


func _on_phase_changed(new_phase: GameTypes.GamePhase) -> void:
	# 保留此信号回调以兼容"未来不走 free/instantiate"的切换方式；
	# 当前 main.gd 走销毁重建，此处实际不会触发。
	if new_phase == GameTypes.GamePhase.MAP and _map_nodes.is_empty():
		_generate_map()


func _generate_map() -> void:
	_map_nodes = MapGenerator.generate_chapter(GameManager.chapter)
	chapter_label.text = GameBalance.CHAPTER_CONFIG.chapterNames[GameManager.chapter - 1]
	_refresh_map_ui()


func _refresh_map_ui() -> void:
	for child in map_container.get_children():
		child.queue_free()
	
	# 按层显示（自下而上：depth 最大的在最上方，玩家从屏幕底部向上推进）
	var layers: Dictionary = {}
	for node in _map_nodes:
		if not layers.has(node.depth):
			layers[node.depth] = []
		layers[node.depth].append(node)
	
	for depth in range(14, -1, -1):
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
			# 先生成波次数据写入 GameManager.pending_wave，内部再切 BATTLE phase
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
	
	# 先写入 GameManager 再切 phase，保证 BattleScene 实例化时能读到波次
	GameManager.pending_wave = wave_ids
	if wave_ids.is_empty():
		push_warning("[MAP] wave_ids 为空，EnemyConfig 可能没返回数据，章节 %d 类型 %s" % [GameManager.chapter, battle_type])
	GameManager.set_phase(GameTypes.GamePhase.BATTLE)


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
