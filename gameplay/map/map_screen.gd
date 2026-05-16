## 地图界面 v2 — 复刻原版 Slay-the-Spire 式节点图
##
## 变化：
##   - 使用 MapGraphView 替换旧 VBox 直堆
##   - 节点按 x 坐标布局，路径画贝塞尔连线
##   - 顶部条显示金币 / 章节名 / HP
extends Node2D

@onready var _graph: MapGraphView = %MapGraphView
@onready var _chapter_label: Label = %ChapterLabel
@onready var _gold_label: Label = %GoldLabel
@onready var _hp_label: Label = %HpLabel
@onready var _scroll: ScrollContainer = _graph.get_parent() as ScrollContainer

var _map_nodes: Array[MapGenerator.MapNode] = []


func _ready() -> void:
	GameManager.phase_changed.connect(_on_phase_changed)
	GameManager.gold_changed.connect(_on_gold_changed)
	GameManager.hp_changed.connect(_on_hp_changed)
	SoundPlayer.play_music("explore")

	_graph.node_clicked.connect(_on_node_clicked)

	# 兜底：Godot 版 main.gd 采用"切场景 free+instantiate"模式
	if GameManager.phase == GameTypes.GamePhase.MAP:
		if GameManager.map_nodes.is_empty():
			_generate_map()
		else:
			_map_nodes = GameManager.map_nodes
			_refresh_header()
			_graph.set_map_nodes(_map_nodes)
		SaveManager.save_run()
		# 延迟一帧后自动滚动到当前可用节点
		await get_tree().process_frame
		_scroll_to_current_node()

	_refresh_header()


func _on_phase_changed(new_phase: GameTypes.GamePhase) -> void:
	if new_phase == GameTypes.GamePhase.MAP and _map_nodes.is_empty():
		_generate_map()


func _on_gold_changed(_amount: int) -> void:
	_refresh_header()


func _on_hp_changed(_hp: int, _max: int) -> void:
	_refresh_header()


func _generate_map() -> void:
	_map_nodes = MapGenerator.generate_chapter(GameManager.chapter)
	GameManager.map_nodes = _map_nodes
	_refresh_header()
	_graph.set_map_nodes(_map_nodes)
	# 延迟一帧后自动滚动到当前可用节点
	await get_tree().process_frame
	_scroll_to_current_node()


func _refresh_header() -> void:
	var chapter_idx: int = clampi(GameManager.chapter - 1, 0, GameBalance.CHAPTER_CONFIG.chapterNames.size() - 1)
	_chapter_label.text = GameBalance.CHAPTER_CONFIG.chapterNames[chapter_idx]
	_gold_label.text = "金币: %d" % GameManager.gold
	_hp_label.text = "HP %d/%d" % [GameManager.hp, GameManager.max_hp]


## 自动滚动到当前可用节点（最低的 available 节点居中显示）
func _scroll_to_current_node() -> void:
	if _scroll == null or _map_nodes.is_empty():
		return
	# 找到第一个 available 节点
	var target_node: MapGenerator.MapNode = null
	for n: MapGenerator.MapNode in _map_nodes:
		if n.available:
			if target_node == null or n.depth < target_node.depth:
				target_node = n
	if target_node == null:
		return
	# 计算节点在 MapGraphView 中的 y 坐标
	var node_y: float = _graph._node_screen_pos(target_node).y
	# 滚动使节点居中
	var scroll_target: float = node_y - _scroll.size.y * 0.5
	scroll_target = clampf(scroll_target, 0.0, _graph.custom_minimum_size.y - _scroll.size.y)
	# 平滑滚动
	var tw: Tween = create_tween()
	tw.tween_property(_scroll, "scroll_vertical", int(scroll_target), 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


func _on_node_clicked(map_node: MapGenerator.MapNode) -> void:
	if not map_node.available:
		return

	SoundPlayer.play_sound("click")
	MapGenerator.visit_node(_map_nodes, map_node.id)
	GameManager.current_node = map_node.depth

	# 解锁下一层
	MapGenerator.get_next_available(_map_nodes, map_node.id)

	_graph.refresh_states()

	# 路由到对应场景
	match map_node.type:
		GameTypes.NodeType.ENEMY, GameTypes.NodeType.ELITE, GameTypes.NodeType.BOSS:
			_spawn_battle(map_node.type)
		GameTypes.NodeType.CAMPFIRE:
			GameManager.set_phase(GameTypes.GamePhase.CAMPFIRE)
		GameTypes.NodeType.MERCHANT:
			GameManager.set_phase(GameTypes.GamePhase.MERCHANT)
		GameTypes.NodeType.EVENT:
			GameManager.set_phase(GameTypes.GamePhase.EVENT)
		GameTypes.NodeType.TREASURE:
			GameManager.set_phase(GameTypes.GamePhase.TREASURE)
		_:
			push_warning("[MAP] 未识别的 NodeType=%s，fallback 到 EVENT" % str(map_node.type))
			GameManager.set_phase(GameTypes.GamePhase.EVENT)


func _spawn_battle(node_type: GameTypes.NodeType) -> void:
	var battle_type: String = MapGenerator.get_battle_type(node_type)
	var depth: int = GameManager.current_node
	var chapter: int = GameManager.chapter
	var wave_ids: Array[String] = []

	match battle_type:
		"enemy":
			wave_ids = _roll_normal_wave(chapter, depth)
		"elite":
			wave_ids = _roll_elite_wave(chapter, depth)
		"boss":
			wave_ids = _roll_boss_wave(chapter)

	GameManager.pending_wave = wave_ids
	if wave_ids.is_empty():
		push_warning(
			"[MAP] wave_ids 为空，EnemyConfig 未返回数据，章节 %d 类型 %s"
			% [chapter, battle_type]
		)
	GameManager.set_phase(GameTypes.GamePhase.BATTLE)


## 普通战：按深度随机 1~3 个敌人（对齐原版 enemies.ts 概率曲线，但上限卡 3，
## 因为当前 BattleScene 的透视槽位只有 中/左/右 3 个，超过会重叠堆到"右"）
##   depth 0 → 固定 1 个
##   depth 1 → 40% 1 个 / 60% 2 个
##   depth 2-4 → 50% 2 / 50% 3
##   depth 5-9 → 70% 3 / 30% 2
##   depth ≥10 → 固定 3（原版是 3~4，等透视系统扩 4 槽位后恢复）
static func _roll_normal_wave(chapter: int, depth: int) -> Array[String]:
	var pool: Array[EnemyConfig] = EnemyConfig.get_normals_for_chapter(chapter)
	if pool.is_empty():
		return []
	var count: int = _roll_normal_count(depth)
	var result: Array[String] = []
	for i: int in count:
		result.append(pool[randi() % pool.size()].id)
	return result


static func _roll_normal_count(depth: int) -> int:
	if depth <= 0:
		return 1
	if depth == 1:
		return 1 if randf() < 0.4 else 2
	if depth <= 4:
		return 2 if randf() < 0.5 else 3
	return 2 if randf() < 0.3 else 3


## 精英战：1 个精英 + 1 个陪跑小兵（对齐原版 line 144）
static func _roll_elite_wave(chapter: int, _depth: int) -> Array[String]:
	var elites: Array[EnemyConfig] = EnemyConfig.get_elites_for_chapter(chapter)
	if elites.is_empty():
		return []
	var result: Array[String] = [elites[randi() % elites.size()].id]
	var normals: Array[EnemyConfig] = EnemyConfig.get_normals_for_chapter(chapter)
	if not normals.is_empty():
		result.append(normals[randi() % normals.size()].id)
	return result


## Boss 战：单体
static func _roll_boss_wave(chapter: int) -> Array[String]:
	var bosses: Array[EnemyConfig] = EnemyConfig.get_bosses_for_chapter(chapter)
	if bosses.is_empty():
		return []
	return [bosses[randi() % bosses.size()].id]
