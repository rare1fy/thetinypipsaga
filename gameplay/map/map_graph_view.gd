## map_graph_view.gd — 地图节点图视图
##
## 渲染职责：
##   - 接收 Array[MapGenerator.MapNode]，按 x/depth 绝对坐标布局
##   - _draw() 手绘贝塞尔路径连线（不用 Line2D，方便一次重绘）
##   - 每个节点一个按钮，贴对应类型的 UI 图标（res://assets/art/generated/icons/）
##   - 信号 node_clicked(MapGenerator.MapNode)
##
## 设计语言：复刻原版 useMapLayout.ts
##   - 虚拟画布宽 720，高 = 层数 × LAYER_HEIGHT
##   - 节点直径 NODE_SIZE
##   - 访问/可选/禁用三态颜色区分
##
## 编辑器友好：
##   - LAYER_HEIGHT / NODE_SIZE / 线宽 / 颜色都是 @export
##   - 美术后续换 PNG 图标只改 ICON_PATHS 映射

extends Control
class_name MapGraphView

signal node_clicked(map_node: MapGenerator.MapNode)

# ============================================================
# 外观参数（Inspector 可调）
# ============================================================

@export_group("布局")
@export var layer_height: float = 140.0     ## 每层间距
@export var node_size: Vector2 = Vector2(54, 54)
@export var canvas_margin_top: float = 80.0   ## 底部（第 0 层）空白
@export var canvas_margin_bottom: float = 60.0  ## 顶部（最终 Boss 层）空白

@export_group("路径绘制")
@export var path_color_default: Color = Color("#3a3228")
@export var path_color_visited: Color = Color("#5a6e7e")
@export var path_color_available: Color = Color("#c8a040")
@export var path_width: float = 3.0
@export var path_dash_count: int = 8  ## 每段路径绘制为几个点（模拟像素虚线）

@export_group("节点")
@export var node_color_available: Color = Color("#f0c850")
@export var node_color_visited: Color = Color("#5a6e7e")
@export var node_color_locked: Color = Color("#2a2420")
@export var node_border_color: Color = Color("#0a0908")

# ============================================================
# 类型图标映射
# ============================================================

const ICON_PATHS := {
	GameTypes.NodeType.ENEMY: "res://assets/art/generated/icons/sword.png",
	GameTypes.NodeType.ELITE: "res://assets/art/generated/icons/skull_crown.png",
	GameTypes.NodeType.BOSS: "res://assets/art/generated/icons/crown.png",
	GameTypes.NodeType.CAMPFIRE: "res://assets/art/generated/icons/campfire.png",
	GameTypes.NodeType.MERCHANT: "res://assets/art/generated/icons/merchant.png",
	GameTypes.NodeType.EVENT: "res://assets/art/generated/icons/event.png",
	GameTypes.NodeType.TREASURE: "res://assets/art/generated/icons/treasure.png",
}

const FALLBACK_LABELS := {
	GameTypes.NodeType.ENEMY: "战",
	GameTypes.NodeType.ELITE: "精",
	GameTypes.NodeType.BOSS: "王",
	GameTypes.NodeType.CAMPFIRE: "火",
	GameTypes.NodeType.MERCHANT: "商",
	GameTypes.NodeType.EVENT: "事",
	GameTypes.NodeType.TREASURE: "宝",
}

# ============================================================
# 状态
# ============================================================

var _map_nodes: Array[MapGenerator.MapNode] = []
var _button_by_id: Dictionary = {}  ## id -> Button
var _max_depth: int = 0  ## 动态计算的最大 depth（_rebuild 时更新）


# ============================================================
# 公开 API
# ============================================================

func set_map_nodes(nodes: Array[MapGenerator.MapNode]) -> void:
	_map_nodes = nodes
	_rebuild()


## 刷新节点状态（颜色等），不重建按钮
func refresh_states() -> void:
	for map_node in _map_nodes:
		var btn: Button = _button_by_id.get(map_node.id)
		if btn:
			_apply_node_state(btn, map_node)
	queue_redraw()


# ============================================================
# 渲染
# ============================================================

func _ready() -> void:
	clip_contents = false


func _rebuild() -> void:
	# 清空旧按钮
	for child in get_children():
		child.queue_free()
	_button_by_id.clear()

	if _map_nodes.is_empty():
		custom_minimum_size = Vector2(720, 400)
		return

	# 计算画布高度 = 层数 × layer_height + margins
	_max_depth = 0
	for n in _map_nodes:
		if n.depth > _max_depth:
			_max_depth = n.depth
	var total_height := (_max_depth + 1) * layer_height + canvas_margin_top + canvas_margin_bottom
	custom_minimum_size = Vector2(720, total_height)

	# 建节点按钮
	for map_node in _map_nodes:
		var btn := Button.new()
		btn.custom_minimum_size = node_size
		btn.size = node_size
		btn.flat = false
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_filter = Control.MOUSE_FILTER_PASS

		# 图标优先，fallback 到文字
		var icon_path: String = ICON_PATHS.get(map_node.type, "")
		if icon_path != "" and ResourceLoader.exists(icon_path):
			var tex: Texture2D = load(icon_path)
			btn.icon = tex
			btn.expand_icon = true
		else:
			btn.text = FALLBACK_LABELS.get(map_node.type, "?")

		btn.position = _node_screen_pos(map_node) - node_size * 0.5
		_apply_node_state(btn, map_node)
		btn.pressed.connect(_on_btn_pressed.bind(map_node))

		add_child(btn)
		_button_by_id[map_node.id] = btn

	queue_redraw()


func _draw() -> void:
	if _map_nodes.is_empty():
		return

	for map_node in _map_nodes:
		var from := _node_screen_pos(map_node)
		for conn_id in map_node.connections:
			var target := _find_node(conn_id)
			if target == null:
				continue
			var to := _node_screen_pos(target)
			var color := _path_color_for(map_node, target)
			_draw_dashed_path(from, to, color)


func _draw_dashed_path(from: Vector2, to: Vector2, color: Color) -> void:
	# 中间加一点贝塞尔弯曲感：control = 中点 + 垂直扰动
	var mid: Vector2 = from.lerp(to, 0.5)
	var perpendicular: Vector2 = (to - from).normalized().rotated(PI * 0.5)
	var hash_val: float = (from.x * 131.0 + from.y * 17.0)
	var bend_sign: float = 1.0 if fmod(hash_val, 2.0) >= 1.0 else -1.0
	var control: Vector2 = mid + perpendicular * 20.0 * bend_sign

	var prev := from
	for i in range(1, path_dash_count + 1):
		var t: float = float(i) / float(path_dash_count)
		var p := _bezier(from, control, to, t)
		if i % 2 == 0:
			draw_line(prev, p, color, path_width, true)
		prev = p


static func _bezier(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return (u * u) * p0 + (2.0 * u * t) * p1 + (t * t) * p2


# ============================================================
# 坐标换算
# ============================================================

func _node_screen_pos(map_node: MapGenerator.MapNode) -> Vector2:
	var canvas_w := size.x if size.x > 0 else 720.0
	var x: float = map_node.x / 100.0 * canvas_w
	# depth 倒序（第 0 层在底部）— 用 _rebuild 时算好的动态最大 depth
	var y: float = canvas_margin_top + (_max_depth - map_node.depth) * layer_height
	return Vector2(x, y)


# ============================================================
# 状态展示
# ============================================================

func _apply_node_state(btn: Button, map_node: MapGenerator.MapNode) -> void:
	if map_node.visited:
		btn.modulate = node_color_visited
		btn.disabled = true
		_stop_node_pulse(btn)
	elif map_node.available:
		btn.modulate = node_color_available
		btn.disabled = false
		_start_node_pulse(btn)
	else:
		btn.modulate = node_color_locked
		btn.disabled = true
		_stop_node_pulse(btn)


## 可用节点脉冲动画（呼吸发光效果）
func _start_node_pulse(btn: Button) -> void:
	if btn.has_meta("pulse_tween"):
		var old_tw: Tween = btn.get_meta("pulse_tween") as Tween
		if old_tw != null and old_tw.is_valid():
			return  # 已在脉冲中
	var tw := create_tween()
	tw.set_loops()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(btn, "modulate", node_color_available * 1.3, 0.6)
	tw.tween_property(btn, "modulate", node_color_available, 0.6)
	btn.set_meta("pulse_tween", tw)


func _stop_node_pulse(btn: Button) -> void:
	if btn.has_meta("pulse_tween"):
		var tw: Tween = btn.get_meta("pulse_tween") as Tween
		if tw != null and tw.is_valid():
			tw.kill()
		btn.remove_meta("pulse_tween")


func _path_color_for(from_node: MapGenerator.MapNode, to_node: MapGenerator.MapNode) -> Color:
	if from_node.visited and to_node.visited:
		return path_color_visited
	if from_node.visited and to_node.available:
		return path_color_available
	return path_color_default


func _find_node(id: String) -> MapGenerator.MapNode:
	for n in _map_nodes:
		if n.id == id:
			return n
	return null


# ============================================================
# 交互
# ============================================================

func _on_btn_pressed(map_node: MapGenerator.MapNode) -> void:
	node_clicked.emit(map_node)
