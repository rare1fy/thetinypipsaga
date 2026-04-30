## SaveManager — 存档管理单例
## 功能：
##   · Run 存档（当前局内：血量 / 骰子 / 遗物 / 地图 / 层数 / 金币等）
##   · Meta 存档（跨局持久：已通关职业 / 最高层 / 音量设置）
## 存储位置：`user://run.save` + `user://meta.save`（JSON 格式）
## 抖音适配：未来发行时 _read_file / _write_file 可改走 tt.setStorage 桥接

extends Node

# ============================================================
# 常量
# ============================================================
const RUN_SAVE_PATH := "user://run.save"
const META_SAVE_PATH := "user://meta.save"
const SAVE_VERSION := 1                          ## 存档格式版本，升级时做迁移

# ============================================================
# 信号
# ============================================================
signal run_saved
signal run_loaded
signal run_save_cleared

# ============================================================
# Public API — Run 存档
# ============================================================

## 保存当前局状态（通常在地图界面 / 事件选择后调用）
func save_run() -> bool:
	# 战斗中禁止存档（状态半步）
	if TurnManager.phase == GameTypes.GamePhase.BATTLE:
		push_warning("[SaveManager] 战斗中不可存档，跳过")
		return false
	
	var payload: Dictionary = {
		"version": SAVE_VERSION,
		"timestamp": Time.get_unix_time_from_system(),
		"player": _serialize_player(),
		"dice": _serialize_dice(),
		"run_progress": _serialize_run_progress(),
		"stats": StatsTracker.stats.duplicate(true),
	}
	
	var ok := _write_file(RUN_SAVE_PATH, payload)
	if ok:
		run_saved.emit()
	return ok


## 加载存档到各 autoload；成功返回 true
func load_run() -> bool:
	var payload := _read_file(RUN_SAVE_PATH)
	if payload.is_empty():
		return false
	
	# 版本兼容（未来升级在此加迁移逻辑）
	var version: int = payload.get("version", 0)
	if version != SAVE_VERSION:
		push_warning("[SaveManager] 存档版本不匹配 (file=%d current=%d)，已跳过" % [version, SAVE_VERSION])
		return false
	
	_deserialize_player(payload.get("player", {}))
	_deserialize_dice(payload.get("dice", {}))
	_deserialize_run_progress(payload.get("run_progress", {}))
	StatsTracker.stats = payload.get("stats", {}).duplicate(true)
	
	run_loaded.emit()
	return true


## 是否存在 run 存档
func has_run_save() -> bool:
	return FileAccess.file_exists(RUN_SAVE_PATH)


## 删除 run 存档（死亡 / 胜利 / 手动放弃调用）
func clear_run_save() -> void:
	if FileAccess.file_exists(RUN_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RUN_SAVE_PATH))
	run_save_cleared.emit()


# ============================================================
# Public API — Meta 存档（跨局持久）
# ============================================================

func save_meta(meta: Dictionary) -> bool:
	var payload: Dictionary = {
		"version": SAVE_VERSION,
		"meta": meta,
	}
	return _write_file(META_SAVE_PATH, payload)


func load_meta() -> Dictionary:
	var payload := _read_file(META_SAVE_PATH)
	return payload.get("meta", {}) if not payload.is_empty() else {}


# ============================================================
# 序列化 — 玩家状态
# ============================================================

func _serialize_player() -> Dictionary:
	return {
		"hp": PlayerState.hp,
		"max_hp": PlayerState.max_hp,
		"armor": PlayerState.armor,
		"gold": PlayerState.gold,
		"souls": PlayerState.souls,
		"player_class": PlayerState.player_class,
	}


func _deserialize_player(data: Dictionary) -> void:
	PlayerState.hp = data.get("hp", 100)
	PlayerState.max_hp = data.get("max_hp", 100)
	PlayerState.armor = data.get("armor", 0)
	PlayerState.gold = data.get("gold", 0)
	PlayerState.souls = data.get("souls", 0)
	PlayerState.player_class = data.get("player_class", "")


# ============================================================
# 序列化 — 骰子系统
# ============================================================

func _serialize_dice() -> Dictionary:
	return {
		"owned_dice": DiceBag.owned_dice.duplicate(true),
		"dice_bag": DiceBag.dice_bag.duplicate(),
		"discard_pile": DiceBag.discard_pile.duplicate(),
		"dice_levels": PlayerState.dice_levels.duplicate(),
	}


func _deserialize_dice(data: Dictionary) -> void:
	var owned_raw: Array = data.get("owned_dice", [])  # [RULES-B2-EXEMPT] dict.get 返回裸 Array
	DiceBag.owned_dice.clear()
	for entry in owned_raw:
		if entry is Dictionary:
			DiceBag.owned_dice.append(entry)
	var bag_src: Array = data.get("dice_bag", [])  # [RULES-B2-EXEMPT] dict.get 返回裸 Array
	DiceBag.dice_bag.clear()
	for s in bag_src:
		DiceBag.dice_bag.append(str(s))
	var discard_src: Array = data.get("discard_pile", [])  # [RULES-B2-EXEMPT] dict.get 返回裸 Array
	DiceBag.discard_pile.clear()
	for s in discard_src:
		DiceBag.discard_pile.append(str(s))
	PlayerState.dice_levels = data.get("dice_levels", {}).duplicate()


# ============================================================
# 序列化 — 局内进度（地图 / 遗物 / 层数）
# ============================================================

func _serialize_run_progress() -> Dictionary:
	# MapNode 是 RefCounted，JSON.stringify 无法直接序列化，需手动转 dict
	var map_data: Array = []  # [RULES-B2-EXEMPT] 手动构建的序列化数组
	for node in PlayerState.map_nodes:
		if node is MapGenerator.MapNode:
			map_data.append({
				"id": node.id,
				"depth": node.depth,
				"col": node.col,
				"type": node.type,
				"connections": node.connections.duplicate(),
				"visited": node.visited,
				"available": node.available,
			})
	return {
		"chapter": PlayerState.chapter,
		"current_node": PlayerState.current_node,
		"map_nodes": map_data,
		"relics": PlayerState.relics.duplicate(true),
		"pending_wave": PlayerState.pending_wave.duplicate(),
	}


func _deserialize_run_progress(data: Dictionary) -> void:
	PlayerState.chapter = data.get("chapter", 1)
	PlayerState.current_node = data.get("current_node", -1)
	# 将 dict 数组恢复为 MapNode 实例
	var nodes_raw: Array = data.get("map_nodes", [])  # [RULES-B2-EXEMPT] dict.get 返回裸 Array
	var restored_nodes: Array[MapGenerator.MapNode] = []
	for d in nodes_raw:
		if d is Dictionary:
			var node := MapGenerator.MapNode.new()
			node.id = d.get("id", "")
			node.depth = int(d.get("depth", 0))
			node.col = int(d.get("col", 0))
			node.type = int(d.get("type", 0)) as GameTypes.NodeType
			var conns: Array = d.get("connections", [])  # [RULES-B2-EXEMPT] dict.get 返回裸 Array
			node.connections.clear()
			for c in conns:
				node.connections.append(str(c))
			node.visited = d.get("visited", false)
			node.available = d.get("available", false)
			restored_nodes.append(node)
	PlayerState.map_nodes = restored_nodes
	var relics: Array = data.get("relics", [])  # [RULES-B2-EXEMPT] dict.get 返回裸 Array
	PlayerState.relics.clear()
	for r in relics:
		if r is Dictionary:
			PlayerState.relics.append(r)
	var wave_src: Array = data.get("pending_wave", [])  # [RULES-B2-EXEMPT] dict.get 返回裸 Array
	PlayerState.pending_wave.clear()
	for s in wave_src:
		PlayerState.pending_wave.append(str(s))


# ============================================================
# 文件 I/O
# ============================================================

func _write_file(path: String, payload: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("[SaveManager] 无法写入 %s (err=%d)" % [path, FileAccess.get_open_error()])
		return false
	file.store_string(JSON.stringify(payload))
	file.close()
	return true


func _read_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	return {}
