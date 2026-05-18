## 地图生成器 — 杀戮尖塔风格随机地图
## 照搬原版 dicehero2/src/utils/mapGenerator.ts + mapConstraints.ts
##
## 核心流程：
## 1. 生成节点网格（含随机 X 坐标）
## 2. 基于距离生成连接关系（最近 + 40%分叉）
## 3. 按概率权重随机分配节点类型
## 4. 约束修正（特殊节点不连续、Boss前营火、战斗密度兜底）

class_name MapGenerator

## ============================================================
## 地图节点
## ============================================================

class MapNode:
	extends RefCounted
	var id: String = ""
	var depth: int = 0
	var type: GameTypes.NodeType = GameTypes.NodeType.ENEMY
	var x: float = 50.0        ## 水平位置百分比 (0-100)
	var connections: Array[String] = []
	var visited: bool = false
	var available: bool = false

## ============================================================
## 配置常量
## ============================================================

const TOTAL_LAYERS: int = 15

## 固定层配置 — 与原版完全一致
const FIXED_LAYERS: Dictionary = {
	0: {"type": "enemy", "count": 1},
	1: {"type": null, "count": 3},
	2: {"type": null, "count": 5},
	3: {"type": null, "count": 3},
	4: {"type": null, "count": 4},
	5: {"type": null, "count": 5},
	6: {"type": null, "count": 4},
	7: {"type": "boss", "count": 1},
	8: {"type": null, "count": 3},
	9: {"type": null, "count": 5},
	10: {"type": null, "count": 5},
	11: {"type": null, "count": 4},
	12: {"type": null, "count": 5},
	13: {"type": null, "count": 4},
	14: {"type": "boss", "count": 1},
}

## Boss 所在层
const BOSS_DEPTHS: Array[int] = [7, 14]

## Boss 前一层
const PRE_BOSS_LAYERS: Array[int] = [6, 13]

## 真正固定类型的层（type != null）
const TRULY_FIXED_LAYERS: Array[int] = [0, 7, 14]

## 概率权重 — 杀戮尖塔风格
const STANDARD_WEIGHTS: Array[Dictionary] = [
	{"type": GameTypes.NodeType.ENEMY, "weight": 40},
	{"type": GameTypes.NodeType.EVENT, "weight": 17},
	{"type": GameTypes.NodeType.ELITE, "weight": 20},
	{"type": GameTypes.NodeType.CAMPFIRE, "weight": 12},
	{"type": GameTypes.NodeType.MERCHANT, "weight": 6},
	{"type": GameTypes.NodeType.TREASURE, "weight": 5},
]

## 特殊节点 — 不能与同类连续
const SPECIAL_TYPES: Array[int] = [
	GameTypes.NodeType.ELITE,
	GameTypes.NodeType.CAMPFIRE,
	GameTypes.NodeType.MERCHANT,
]

## 非战斗节点
const NON_COMBAT_TYPES: Array[int] = [
	GameTypes.NodeType.CAMPFIRE,
	GameTypes.NodeType.MERCHANT,
	GameTypes.NodeType.EVENT,
	GameTypes.NodeType.TREASURE,
]

## 经济节点
const ECONOMIC_TYPES: Array[int] = [
	GameTypes.NodeType.MERCHANT,
	GameTypes.NodeType.TREASURE,
]

## ============================================================
## 主生成函数
## ============================================================

static func generate_chapter(_chapter: int = 1) -> Array[MapNode]:
	var nodes: Array[MapNode] = []

	# ── 第一步：生成所有节点（分配随机 X 坐标）──
	for depth in range(TOTAL_LAYERS):
		var config: Dictionary = FIXED_LAYERS.get(depth, {"type": null, "count": 3})
		var count: int = config.get("count", 3)
		var is_pre_boss: bool = depth in PRE_BOSS_LAYERS
		var is_post_boss: bool = depth > 0 and (depth - 1) in BOSS_DEPTHS

		var positions: Array[float] = []

		if count == 1:
			positions.append(50.0)
		elif is_pre_boss:
			# Boss前层稍收拢
			for i in range(count):
				var base_x: float = 20.0 + float(i + 1) / float(count + 1) * 60.0
				var jitter: float = (randf() - 0.5) * 8.0
				positions.append(clampf(base_x + jitter, 15.0, 85.0))
		elif is_post_boss:
			# Boss后层展开
			for i in range(count):
				var base_x: float = 10.0 + float(i + 1) / float(count + 1) * 80.0
				var jitter: float = (randf() - 0.5) * 15.0
				positions.append(clampf(base_x + jitter, 8.0, 92.0))
		else:
			var min_spacing: float = 80.0 / float(count + 1)
			for i in range(count):
				var base_x: float = 5.0 + float(i + 1) / float(count + 1) * 90.0
				var jitter: float = (randf() - 0.5) * minf(20.0, min_spacing * 0.5)
				positions.append(clampf(base_x + jitter, 5.0, 95.0))

		positions.sort()

		# 最小间距保障
		for i in range(1, positions.size()):
			if positions[i] - positions[i - 1] < 12.0:
				positions[i] = positions[i - 1] + 12.0
				if positions[i] > 95.0:
					positions[i] = 95.0

		for i in range(count):
			var node := MapNode.new()
			node.id = "node_%d_%d" % [depth, i]
			node.depth = depth
			node.x = positions[i] if i < positions.size() else 50.0
			node.type = GameTypes.NodeType.ENEMY  # 占位
			if depth == 0:
				node.available = true
			nodes.append(node)

	# ── 第二步：生成连接关系（基于距离 + 40%分叉）──
	for depth in range(TOTAL_LAYERS - 1):
		var current_layer: Array[MapNode] = _get_layer(nodes, depth)
		var next_layer: Array[MapNode] = _get_layer(nodes, depth + 1)

		if next_layer.size() == 1:
			for node in current_layer:
				node.connections.append(next_layer[0].id)
		elif current_layer.size() == 1:
			for next_node in next_layer:
				current_layer[0].connections.append(next_node.id)
		else:
			var in_degree: Dictionary = {}
			for n in next_layer:
				in_degree[n.id] = 0

			for node in current_layer:
				# 按距离排序下一层节点
				var distances: Array[Dictionary] = []
				for next_node in next_layer:
					distances.append({"dist": absf(node.x - next_node.x), "id": next_node.id})
				distances.sort_custom(func(a, b): return a.dist < b.dist)

				# 连接最近的
				node.connections.append(distances[0].id)
				in_degree[distances[0].id] = in_degree.get(distances[0].id, 0) + 1

				# 40% 概率连第二近（增加分叉）
				if distances.size() > 1 and randf() < 0.4:
					if in_degree.get(distances[1].id, 0) < 2:
						node.connections.append(distances[1].id)
						in_degree[distances[1].id] = in_degree.get(distances[1].id, 0) + 1

			# 孤立节点补连
			for next_node in next_layer:
				if in_degree.get(next_node.id, 0) == 0:
					var closest_parent: MapNode = current_layer[0]
					var min_dist: float = INF
					for p in current_layer:
						var dist: float = absf(p.x - next_node.x)
						if dist < min_dist:
							min_dist = dist
							closest_parent = p
					closest_parent.connections.append(next_node.id)

	# 去重连接
	for node in nodes:
		var unique: Array[String] = []
		for c in node.connections:
			if c not in unique:
				unique.append(c)
		node.connections = unique

	# ── 第三步：分配节点类型 ──
	# 3a. 固定层先设置
	for node in nodes:
		var config: Dictionary = FIXED_LAYERS.get(node.depth, {})
		var fixed_type = config.get("type")
		if fixed_type == "boss":
			node.type = GameTypes.NodeType.BOSS
		elif fixed_type == "enemy" and node.depth in TRULY_FIXED_LAYERS:
			node.type = GameTypes.NodeType.ENEMY

	# 3b. 按层逐个分配
	for depth in range(TOTAL_LAYERS):
		if depth in TRULY_FIXED_LAYERS:
			continue
		var layer_nodes: Array[MapNode] = _get_layer(nodes, depth)
		_shuffle_nodes(layer_nodes)

		# 构建本层排除集
		var layer_excluded: Array[int] = []
		if depth <= 2:
			layer_excluded.append(GameTypes.NodeType.ELITE)
			layer_excluded.append(GameTypes.NodeType.CAMPFIRE)
		if depth in PRE_BOSS_LAYERS:
			layer_excluded.append(GameTypes.NodeType.ELITE)
		if depth > 0 and (depth - 1) in BOSS_DEPTHS:
			layer_excluded.append(GameTypes.NodeType.ELITE)

		var used_in_layer: Array[int] = []

		for node in layer_nodes:
			var node_excluded: Array[int] = layer_excluded.duplicate()

			# 父节点约束：特殊节点不连续
			var parents: Array[MapNode] = _get_parents(nodes, node)
			for p in parents:
				if p.type in SPECIAL_TYPES:
					if p.type not in node_excluded:
						node_excluded.append(p.type)

			# 同层多样性
			for used in used_in_layer:
				if used in SPECIAL_TYPES and used not in node_excluded:
					node_excluded.append(used)

			node.type = _weighted_random_type(node_excluded)
			used_in_layer.append(node.type)

	# ── 第四步：约束修正 ──
	for depth in range(1, TOTAL_LAYERS):
		if depth in TRULY_FIXED_LAYERS:
			continue
		var layer_nodes: Array[MapNode] = _get_layer(nodes, depth)
		for node in layer_nodes:
			var parents: Array[MapNode] = _get_parents(nodes, node)
			if parents.is_empty():
				continue
			# 修正1：特殊节点不能与同类父节点连续
			if node.type in SPECIAL_TYPES:
				for p in parents:
					if p.type == node.type:
						node.type = GameTypes.NodeType.ENEMY
						break
			# 修正2：连续2层非战斗 → 强制战斗
			if node.type in NON_COMBAT_TYPES and depth >= 2:
				var has_chain: bool = false
				for parent in parents:
					if parent.type not in NON_COMBAT_TYPES:
						continue
					var grandparents: Array[MapNode] = _get_parents(nodes, parent)
					for gp in grandparents:
						if gp.type in NON_COMBAT_TYPES:
							has_chain = true
							break
					if has_chain:
						break
				if has_chain:
					node.type = GameTypes.NodeType.ENEMY

	# ── 第五步：经济节点管控 ──
	for depth in range(TOTAL_LAYERS):
		if depth in TRULY_FIXED_LAYERS:
			continue
		var layer_nodes: Array[MapNode] = _get_layer(nodes, depth)
		if depth <= 1:
			for n in layer_nodes:
				if n.type in ECONOMIC_TYPES:
					n.type = GameTypes.NodeType.ENEMY if randf() < 0.6 else GameTypes.NodeType.EVENT
			continue
		var econ_count: int = 0
		for n in layer_nodes:
			if n.type in ECONOMIC_TYPES:
				econ_count += 1
				if econ_count > 1:
					n.type = GameTypes.NodeType.ENEMY if randf() < 0.6 else GameTypes.NodeType.EVENT

	# ── 第六步：Boss前营火保障 ──
	for boss_depth in BOSS_DEPTHS:
		_ensure_campfires_before_boss(nodes, boss_depth, 2)

	return nodes

## ============================================================
## 辅助函数
## ============================================================

static func _get_layer(nodes: Array[MapNode], depth: int) -> Array[MapNode]:
	var result: Array[MapNode] = []
	for n in nodes:
		if n.depth == depth:
			result.append(n)
	return result


static func _get_parents(nodes: Array[MapNode], child: MapNode) -> Array[MapNode]:
	var result: Array[MapNode] = []
	for n in nodes:
		if n.depth == child.depth - 1 and child.id in n.connections:
			result.append(n)
	return result


static func _shuffle_nodes(arr: Array[MapNode]) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j: int = randi() % (i + 1)
		var tmp: MapNode = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


static func _weighted_random_type(excluded: Array[int]) -> GameTypes.NodeType:
	var filtered: Array[Dictionary] = []
	for w in STANDARD_WEIGHTS:
		if w.type not in excluded:
			filtered.append(w)
	if filtered.is_empty():
		return GameTypes.NodeType.ENEMY
	var total_weight: float = 0.0
	for w in filtered:
		total_weight += w.weight
	var r: float = randf() * total_weight
	for w in filtered:
		r -= w.weight
		if r <= 0:
			return w.type
	return GameTypes.NodeType.ENEMY


static func _ensure_campfires_before_boss(nodes: Array[MapNode], boss_depth: int, min_count: int) -> void:
	var pre_boss_depth: int = boss_depth - 1
	var pre_boss_2_depth: int = boss_depth - 2

	var candidates: Array[MapNode] = []
	for n in nodes:
		if n.depth == pre_boss_depth or n.depth == pre_boss_2_depth:
			candidates.append(n)

	var existing_count: int = 0
	var campfire_xs: Array[float] = []
	for n in candidates:
		if n.type == GameTypes.NodeType.CAMPFIRE:
			existing_count += 1
			campfire_xs.append(n.x)

	var needed: int = min_count - existing_count
	if needed <= 0:
		return

	# 收集可替换节点（优先 pre_boss_depth 层）
	var replaceable: Array[MapNode] = []
	for n in candidates:
		if n.type != GameTypes.NodeType.CAMPFIRE and n.type != GameTypes.NodeType.BOSS:
			replaceable.append(n)

	# 按距离已有营火最远排序
	replaceable.sort_custom(func(a, b):
		var a_min: float = INF
		var b_min: float = INF
		for cx in campfire_xs:
			a_min = minf(a_min, absf(a.x - cx))
			b_min = minf(b_min, absf(b.x - cx))
		return a_min > b_min  # 距离远的优先
	)

	for candidate in replaceable:
		if needed <= 0:
			break
		# 尽量分散
		var too_close: bool = false
		for cx in campfire_xs:
			if absf(candidate.x - cx) < 15.0:
				too_close = true
				break
		if too_close and replaceable.size() > needed:
			continue
		candidate.type = GameTypes.NodeType.CAMPFIRE
		campfire_xs.append(candidate.x)
		needed -= 1

	# 强制补足
	if needed > 0:
		for candidate in replaceable:
			if needed <= 0:
				break
			if candidate.type == GameTypes.NodeType.CAMPFIRE:
				continue
			candidate.type = GameTypes.NodeType.CAMPFIRE
			needed -= 1


## ============================================================
## 公共 API（供 map_screen 调用）
## ============================================================

static func find_node(nodes: Array[MapNode], id: String) -> MapNode:
	for n in nodes:
		if n.id == id:
			return n
	return null


static func get_next_available(nodes: Array[MapNode], current_id: String) -> Array[MapNode]:
	var current := find_node(nodes, current_id)
	if not current:
		return []
	var result: Array[MapNode] = []
	for conn_id in current.connections:
		var n := find_node(nodes, conn_id)
		if n:
			n.available = true
			result.append(n)
	return result


static func visit_node(nodes: Array[MapNode], id: String) -> void:
	var node := find_node(nodes, id)
	if node:
		node.visited = true
		node.available = false


static func get_battle_type(node_type: GameTypes.NodeType) -> String:
	match node_type:
		GameTypes.NodeType.ELITE:
			return "elite"
		GameTypes.NodeType.BOSS:
			return "boss"
		_:
			return "enemy"
