## 地图生成器 v2 — 对应原版 Slay-the-Spire 风格算法
##
## 四步流程（复刻自 dicehero2 mapGenerator.ts）：
##   1. 生成节点网格 + 每个节点带 x 坐标（同层防重叠 / 抖动）
##   2. 按最近距离连接下一层 + 40% 概率分叉 + 孤立节点补连
##   3. 按权重分配节点类型（固定层跳过，首3层禁精英/营火）
##   4. 约束修正：特殊节点不连续 / 经济节点管控 / Boss 前营火保底 / 战斗密度兜底
##
## 节点类型权重（STS 标准）：
##   enemy 45 / event 20 / elite 12 / campfire 12 / merchant 6 / treasure 5

class_name MapGenerator

# ============================================================
# 常量
# ============================================================

const TOTAL_LAYERS := 15
const MAX_RECURSION := 50

## 节点类型权重池
const STANDARD_WEIGHTS: Array[Dictionary] = [
	{"type": GameTypes.NodeType.ENEMY, "weight": 45},
	{"type": GameTypes.NodeType.EVENT, "weight": 20},
	{"type": GameTypes.NodeType.ELITE, "weight": 12},
	{"type": GameTypes.NodeType.CAMPFIRE, "weight": 12},
	{"type": GameTypes.NodeType.MERCHANT, "weight": 6},
	{"type": GameTypes.NodeType.TREASURE, "weight": 5},
]

## 章节固定层配置（与原版对齐）
const FIXED_LAYERS: Dictionary = {
	0: {"type": GameTypes.NodeType.ENEMY, "count": 1},
	1: {"type": null, "count": 3},
	2: {"type": null, "count": 5},
	3: {"type": null, "count": 3},
	4: {"type": null, "count": 4},
	5: {"type": null, "count": 5},
	6: {"type": null, "count": 4},
	7: {"type": GameTypes.NodeType.BOSS, "count": 1},
	8: {"type": null, "count": 3},
	9: {"type": null, "count": 5},
	10: {"type": null, "count": 5},
	11: {"type": null, "count": 4},
	12: {"type": null, "count": 5},
	13: {"type": null, "count": 4},
	14: {"type": GameTypes.NodeType.BOSS, "count": 1},
}

## 特殊节点 — 不能与父节点同类型连续
const SPECIAL_TYPES: Array = [
	GameTypes.NodeType.ELITE,
	GameTypes.NodeType.CAMPFIRE,
	GameTypes.NodeType.MERCHANT,
]

## 非战斗节点
const NON_COMBAT_TYPES: Array = [
	GameTypes.NodeType.CAMPFIRE,
	GameTypes.NodeType.MERCHANT,
	GameTypes.NodeType.EVENT,
	GameTypes.NodeType.TREASURE,
]


# ============================================================
# MapNode — 扩展 x 坐标用于布局
# ============================================================

class MapNode:
	extends RefCounted
	var id: String = ""
	var depth: int = 0
	var col: int = 0
	var x: float = 50.0  ## 同层横向百分比位置 [0-100]
	var type: GameTypes.NodeType = GameTypes.NodeType.ENEMY
	var connections: Array[String] = []
	var visited: bool = false
	var available: bool = false

	func _to_string() -> String:
		return "MapNode(%s, d=%d, x=%.1f, %s)" % [id, depth, x, GameTypes.NodeType.keys()[type]]


# ============================================================
# 主入口
# ============================================================

static func generate_chapter(chapter: int = 1) -> Array[MapNode]:
	var nodes: Array[MapNode] = []

	# 记录 boss 层和 preBoss 层
	var boss_depths: Array[int] = []
	var pre_boss_layers: Dictionary = {}
	var truly_fixed: Dictionary = {}
	for depth in FIXED_LAYERS.keys():
		var cfg: Dictionary = FIXED_LAYERS[depth]
		if cfg.get("type") == GameTypes.NodeType.BOSS:
			boss_depths.append(depth)
			pre_boss_layers[depth - 1] = true
		if cfg.get("type") != null:
			truly_fixed[depth] = true

	# ========== Step 1: 生成节点位置 ==========
	_generate_positions(nodes, chapter, boss_depths, pre_boss_layers)

	# ========== Step 2: 生成连接 ==========
	_generate_connections(nodes)

	# ========== Step 3: 分配类型 ==========
	_assign_types(nodes, truly_fixed, pre_boss_layers, boss_depths)

	# ========== Step 4: 约束修正 ==========
	_fix_constraints(nodes, truly_fixed)
	_ensure_campfires_before_boss(nodes, boss_depths)

	# 标记起点
	for n in nodes:
		if n.depth == 0:
			n.available = true

	return nodes


# ============================================================
# Step 1: 位置生成
# ============================================================

static func _generate_positions(
	nodes: Array[MapNode],
	chapter: int,
	boss_depths: Array[int],
	pre_boss_layers: Dictionary,
) -> void:
	for depth in range(TOTAL_LAYERS):
		var cfg: Dictionary = FIXED_LAYERS.get(depth, {"type": null, "count": 3})
		var count: int = cfg.get("count", 3)
		var is_pre_boss: bool = pre_boss_layers.has(depth)
		var is_post_boss: bool = depth > 0 and boss_depths.has(depth - 1)

		var positions: Array[float] = []
		if count == 1:
			positions.append(50.0)
		elif is_pre_boss:
			# Boss 前收拢
			for i in range(count):
				var base_x := 20.0 + (i + 1.0) / (count + 1.0) * 60.0
				var jitter := (randf() - 0.5) * 8.0
				positions.append(clampf(base_x + jitter, 15.0, 85.0))
		elif is_post_boss:
			# Boss 后展开
			for i in range(count):
				var base_x := 10.0 + (i + 1.0) / (count + 1.0) * 80.0
				var jitter := (randf() - 0.5) * 15.0
				positions.append(clampf(base_x + jitter, 8.0, 92.0))
		else:
			var min_spacing := 80.0 / (count + 1.0)
			for i in range(count):
				var base_x := 5.0 + (i + 1.0) / (count + 1.0) * 90.0
				var jitter := (randf() - 0.5) * minf(20.0, min_spacing * 0.5)
				positions.append(clampf(base_x + jitter, 5.0, 95.0))

		positions.sort()

		# 同层最小间距 12%
		for i in range(1, positions.size()):
			if positions[i] - positions[i - 1] < 12.0:
				positions[i] = positions[i - 1] + 12.0
				if positions[i] > 95.0:
					positions[i] = 95.0

		for i in range(count):
			var node := MapNode.new()
			node.id = "ch%d_d%d_c%d" % [chapter, depth, i]
			node.depth = depth
			node.col = i
			node.x = positions[i]
			node.type = GameTypes.NodeType.ENEMY
			nodes.append(node)


# ============================================================
# Step 2: 连接生成（最近距离 + 40% 分叉）
# ============================================================

static func _generate_connections(nodes: Array[MapNode]) -> void:
	for depth in range(TOTAL_LAYERS - 1):
		var current: Array[MapNode] = _filter_depth(nodes, depth)
		var next_layer: Array[MapNode] = _filter_depth(nodes, depth + 1)

		if next_layer.is_empty() or current.is_empty():
			continue

		if next_layer.size() == 1:
			for n in current:
				if not n.connections.has(next_layer[0].id):
					n.connections.append(next_layer[0].id)
			continue

		if current.size() == 1:
			for nxt in next_layer:
				if not current[0].connections.has(nxt.id):
					current[0].connections.append(nxt.id)
			continue

		# 入度统计
		var in_degree: Dictionary = {}
		for nxt in next_layer:
			in_degree[nxt.id] = 0

		for node in current:
			# 按 x 距离排序邻居
			var candidates: Array = []  # [RULES-B2-EXEMPT] 临时排序结构
			for nxt in next_layer:
				candidates.append({"dist": absf(node.x - nxt.x), "node": nxt})
			candidates.sort_custom(func(a, b): return a.dist < b.dist)

			# 必连最近的
			var nearest: MapNode = candidates[0].node
			if not node.connections.has(nearest.id):
				node.connections.append(nearest.id)
				in_degree[nearest.id] = in_degree.get(nearest.id, 0) + 1

			# 40% 概率连次近的（入度 <2 才允许，防止收敛太密）
			if candidates.size() > 1 and randf() < 0.4:
				var second: MapNode = candidates[1].node
				if in_degree.get(second.id, 0) < 2 and not node.connections.has(second.id):
					node.connections.append(second.id)
					in_degree[second.id] = in_degree.get(second.id, 0) + 1

		# 孤立节点补连
		for nxt in next_layer:
			if in_degree.get(nxt.id, 0) == 0:
				var closest: MapNode = current[0]
				var min_dist: float = INF
				for node in current:
					var d := absf(node.x - nxt.x)
					if d < min_dist:
						min_dist = d
						closest = node
				if not closest.connections.has(nxt.id):
					closest.connections.append(nxt.id)


# ============================================================
# Step 3: 类型分配
# ============================================================

static func _assign_types(
	nodes: Array[MapNode],
	truly_fixed: Dictionary,
	pre_boss_layers: Dictionary,
	boss_depths: Array[int],
) -> void:
	# 3a. 先设置固定层
	for n in nodes:
		var cfg: Dictionary = FIXED_LAYERS.get(n.depth, {})
		var fixed_type = cfg.get("type")
		if fixed_type != null:
			n.type = fixed_type

	# 3b. 按层分配非固定层
	for depth in range(TOTAL_LAYERS):
		if truly_fixed.has(depth):
			continue

		var layer_nodes: Array[MapNode] = _filter_depth(nodes, depth)

		# 层级排除集
		var layer_excluded: Dictionary = {}

		# 规则 A: 前 3 层不出精英和营火
		if depth <= 2:
			layer_excluded[GameTypes.NodeType.ELITE] = true
			layer_excluded[GameTypes.NodeType.CAMPFIRE] = true

		# 规则 B: Boss 前一层不出精英
		if pre_boss_layers.has(depth):
			layer_excluded[GameTypes.NodeType.ELITE] = true

		# 规则 C: Boss 后首层不出精英
		if depth > 0 and boss_depths.has(depth - 1):
			layer_excluded[GameTypes.NodeType.ELITE] = true

		# 同层已用类型（减少特殊类型重复）
		var used_in_layer: Dictionary = {}

		for node in _shuffle(layer_nodes):
			var node_excluded := layer_excluded.duplicate()

			# 规则 D: 与父节点特殊类型不连续
			var parents: Array[MapNode] = _get_parents(nodes, node)
			for p in parents:
				if SPECIAL_TYPES.has(p.type):
					node_excluded[p.type] = true

			# 规则 E: 同层分叉多样性
			for used_type in used_in_layer.keys():
				if SPECIAL_TYPES.has(used_type):
					node_excluded[used_type] = true

			var assigned := _weighted_random_type(node_excluded)
			node.type = assigned
			used_in_layer[assigned] = true


static func _weighted_random_type(excluded: Dictionary) -> GameTypes.NodeType:
	var pool: Array = []  # [RULES-B2-EXEMPT] 临时构建池
	for w in STANDARD_WEIGHTS:
		if not excluded.has(w.type):
			pool.append(w)

	if pool.is_empty():
		return GameTypes.NodeType.ENEMY

	var total: float = 0.0
	for w in pool:
		total += w.weight

	var r := randf() * total
	for w in pool:
		r -= w.weight
		if r <= 0.0:
			return w.type
	return GameTypes.NodeType.ENEMY


# ============================================================
# Step 4: 约束修正
# ============================================================

static func _fix_constraints(nodes: Array[MapNode], truly_fixed: Dictionary) -> void:
	for depth in range(1, TOTAL_LAYERS):
		if truly_fixed.has(depth):
			continue
		var layer_nodes: Array[MapNode] = _filter_depth(nodes, depth)
		for node in layer_nodes:
			var parents: Array[MapNode] = _get_parents(nodes, node)
			if parents.is_empty():
				continue

			# 修正1: 特殊节点不与同类父连续
			if SPECIAL_TYPES.has(node.type):
				for p in parents:
					if p.type == node.type:
						node.type = GameTypes.NodeType.ENEMY
						break

			# 修正2: 连续 3 层非战斗 → 改战斗
			if NON_COMBAT_TYPES.has(node.type) and depth >= 2:
				var has_chain := false
				for parent in parents:
					if not NON_COMBAT_TYPES.has(parent.type):
						continue
					var grandparents: Array[MapNode] = _get_parents(nodes, parent)
					for gp in grandparents:
						if NON_COMBAT_TYPES.has(gp.type):
							has_chain = true
							break
					if has_chain:
						break
				if has_chain:
					node.type = GameTypes.NodeType.ENEMY


## Boss 前保证至少 2 个营火（分布在不同 x 位置）
static func _ensure_campfires_before_boss(
	nodes: Array[MapNode], boss_depths: Array[int]
) -> void:
	const MIN_CAMPFIRES := 2
	for boss_depth in boss_depths:
		var pre_boss := boss_depth - 1
		var pre_boss_2 := boss_depth - 2
		if pre_boss < 0:
			continue

		var candidates: Array[MapNode] = []
		for n in nodes:
			if n.depth == pre_boss or n.depth == pre_boss_2:
				candidates.append(n)

		var existing: Array[MapNode] = []
		for n in candidates:
			if n.type == GameTypes.NodeType.CAMPFIRE:
				existing.append(n)

		var needed: int = MIN_CAMPFIRES - existing.size()
		if needed <= 0:
			continue

		var xs: Array[float] = []
		for n in existing:
			xs.append(n.x)

		# 按与已有营火 x 距离排序（远的优先，保证分散）
		var replaceable: Array[MapNode] = []
		for n in candidates:
			if n.type != GameTypes.NodeType.CAMPFIRE and n.type != GameTypes.NodeType.BOSS:
				replaceable.append(n)
		replaceable.sort_custom(func(a, b):
			var da := INF if xs.is_empty() else _min_dist(a.x, xs)
			var db := INF if xs.is_empty() else _min_dist(b.x, xs)
			return da > db
		)

		for cand in replaceable:
			if needed <= 0:
				break
			cand.type = GameTypes.NodeType.CAMPFIRE
			xs.append(cand.x)
			needed -= 1


# ============================================================
# 辅助函数
# ============================================================

static func _filter_depth(nodes: Array[MapNode], depth: int) -> Array[MapNode]:
	var result: Array[MapNode] = []
	for n in nodes:
		if n.depth == depth:
			result.append(n)
	return result


static func _get_parents(nodes: Array[MapNode], node: MapNode) -> Array[MapNode]:
	var result: Array[MapNode] = []
	for n in nodes:
		if n.depth == node.depth - 1 and n.connections.has(node.id):
			result.append(n)
	return result


static func _min_dist(x: float, xs: Array[float]) -> float:
	var md: float = INF
	for cx in xs:
		var d := absf(x - cx)
		if d < md:
			md = d
	return md


static func _shuffle(arr: Array[MapNode]) -> Array[MapNode]:
	var result: Array[MapNode] = arr.duplicate()
	for i in range(result.size() - 1, 0, -1):
		var j := randi() % (i + 1)
		var tmp := result[i]
		result[i] = result[j]
		result[j] = tmp
	return result


# ============================================================
# 公开接口（保持与旧版 API 兼容）
# ============================================================

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
		GameTypes.NodeType.ELITE: return "elite"
		GameTypes.NodeType.BOSS: return "boss"
		_: return "enemy"
