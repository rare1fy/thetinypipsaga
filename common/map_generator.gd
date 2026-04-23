## 地图生成器 — 对应原版地图系统
## 每章15层，含固定层和随机层

class_name MapGenerator

# 地图节点
class MapNode:
	extends RefCounted
	var id: String = ""
	var depth: int = 0
	var col: int = 0           ## 同层中的列位置
	var type: GameTypes.NodeType = GameTypes.NodeType.ENEMY
	var connections: Array[String] = []  ## 连接到的下一层节点ID
	var visited: bool = false
	var available: bool = false
	
	func _to_string() -> String:
		return "MapNode(%s, depth=%d, type=%s)" % [id, depth, GameTypes.NodeType.keys()[type]]


## 章节固定层配置
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

## 节点类型权重（随机层）
const NODE_WEIGHTS: Array[Dictionary] = [
	{"type": GameTypes.NodeType.ELITE, "cumWeight": 0.10},
	{"type": GameTypes.NodeType.CAMPFIRE, "cumWeight": 0.22},
	{"type": GameTypes.NodeType.TREASURE, "cumWeight": 0.32},
	{"type": GameTypes.NodeType.MERCHANT, "cumWeight": 0.44},
	{"type": GameTypes.NodeType.MERCHANT, "cumWeight": 0.52},
	{"type": GameTypes.NodeType.EVENT, "cumWeight": 0.62},
]


## 生成一章地图
static func generate_chapter(chapter: int = 1) -> Array[MapNode]:
	var nodes: Array[MapNode] = []
	var layers: Array = []  # 每层的节点数组
	
	for depth in range(15):
		var config := FIXED_LAYERS.get(depth, {"type": null, "count": 3}) as Dictionary
		var count: int = config.get("count", 3)
		var fixed_type = config.get("type")
		var layer_nodes: Array[MapNode] = []
		
		for col in range(count):
			var node := MapNode.new()
			node.id = "ch%d_d%d_c%d" % [chapter, depth, col]
			node.depth = depth
			node.col = col
			
			if fixed_type != null:
				node.type = _str_to_node_type(fixed_type)
			else:
				node.type = _random_node_type(depth, chapter)
			
			# 第0层和Boss层标记为可用
			if depth == 0:
				node.available = true
			
			layer_nodes.append(node)
			nodes.append(node)
		
		layers.append(layer_nodes)
	
	# 生成连接（每层连接到下一层）
	for depth in range(layers.size() - 1):
		var current_layer: Array = layers[depth]
		var next_layer: Array = layers[depth + 1]
		
		for node in current_layer:
			# 每个节点至少连接1个下一层节点
			# 简化算法：按列位置就近连接
			var connected := false
			
			# 连接到下一层列位置最近的节点
			for next_node in next_layer:
				if absi(next_node.col - node.col) <= 1 or next_layer.size() == 1:
					if not node.connections.has(next_node.id):
						node.connections.append(next_node.id)
						connected = true
					if current_layer.size() <= 3:
						break  # 少节点时每个连更多
			
			# 确保至少连接1个
			if not connected and next_layer.size() > 0:
				var idx := mini(node.col, next_layer.size() - 1)
				node.connections.append(next_layer[idx].id)
	
	return nodes


## 根据ID查找节点
static func find_node(nodes: Array[MapNode], id: String) -> MapNode:
	for n in nodes:
		if n.id == id:
			return n
	return null


## 获取下一层可用节点
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


## 标记节点为已访问
static func visit_node(nodes: Array[MapNode], id: String) -> void:
	var node := find_node(nodes, id)
	if node:
		node.visited = true
		node.available = false


## 获取节点类型的敌人类型
static func get_battle_type(node_type: GameTypes.NodeType) -> String:
	match node_type:
		GameTypes.NodeType.ELITE:
			return "elite"
		GameTypes.NodeType.BOSS:
			return "boss"
		_:
			return "enemy"


static func _random_node_type(depth: int, chapter: int) -> GameTypes.NodeType:
	# 营火层保障
	if depth in [6, 13]:
		if randf() < 0.5:
			return GameTypes.NodeType.CAMPFIRE
	
	var roll := randf()
	for w in NODE_WEIGHTS:
		if roll < w.cumWeight:
			return w.type
	
	# 章节越高，精英概率越高
	if chapter >= 3 and randf() < 0.05:
		return GameTypes.NodeType.ELITE
	
	return GameTypes.NodeType.ENEMY


static func _str_to_node_type(s: String) -> GameTypes.NodeType:
	match s:
		"enemy": return GameTypes.NodeType.ENEMY
		"elite": return GameTypes.NodeType.ELITE
		"boss": return GameTypes.NodeType.BOSS
		"event": return GameTypes.NodeType.EVENT
		"campfire": return GameTypes.NodeType.CAMPFIRE
		"treasure": return GameTypes.NodeType.TREASURE
		"merchant": return GameTypes.NodeType.MERCHANT
		_: return GameTypes.NodeType.ENEMY
