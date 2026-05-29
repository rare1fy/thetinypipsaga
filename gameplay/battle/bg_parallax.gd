## bg_parallax.gd — 分层背景透视位移
## 职责：4 层背景（Sky/FarView/MidView/GroundBase）的待机呼吸 + 攻击推拉 + 受击反弹
## 第一人称视角：摄像机呼吸让远景动作微、近景动作大，模拟纵深感
##
## 挂载：作为 WorldLayer/SceneBG 根节点的脚本（Camera2D 在 WorldLayer 下，不改场景层级）
## 节点要求：Sky / FarView / MidView / GroundBase 四个子 Sprite2D（按命名查询）

class_name BgParallax
extends Node2D

@export_group("待机呼吸-振幅")
## 天空层 Y 轴振幅（越远越小）
@export var sky_idle_amp: float = 1.5
## 远山层 Y 轴振幅
@export var far_idle_amp: float = 3.0
## 中景层 Y 轴振幅
@export var mid_idle_amp: float = 6.0
## 地面层 Y 轴振幅（越近越大，模拟透视）
@export var ground_idle_amp: float = 10.0

@export_group("待机呼吸-节奏")
## 呼吸周期（秒，越大越慢）
@export var idle_period: float = 3.2
## 远近层相位差（弧度，让远景慢于近景，强化纵深）
@export var layer_phase_step: float = 0.4

@export_group("攻击推拉幅度")
## 地面层（近景，推拉最大）
@export var attack_push_ground: float = 18.0
## 中景层
@export var attack_push_mid: float = 10.0
## 远山层
@export var attack_push_far: float = 4.0
## 天空层（远景，推拉最小）
@export var attack_push_sky: float = 1.5

@export_group("受击反弹幅度")
## 地面层（近景，反弹最大）
@export var hurt_kick_ground: float = 14.0
## 中景层
@export var hurt_kick_mid: float = 8.0
## 远山层
@export var hurt_kick_far: float = 3.0
## 天空层
@export var hurt_kick_sky: float = 1.0

@export_group("跟随地面层")
## 跟地面一起呼吸/抖动的节点（例如 EnemyContainer）
## 解决"敌人浮空"问题：敌人站在地面上，必须跟地面同步起伏
@export var follow_ground_nodes: Array[NodePath] = []
## 跟随强度系数（1.0=完全跟随地面振幅；0.7=微弱跟随；0.0=不跟随）
@export_range(0.0, 1.5, 0.05) var follow_ground_ratio: float = 1.0

@onready var _sky: Sprite2D = get_node_or_null("Sky") as Sprite2D
@onready var _far: Sprite2D = get_node_or_null("FarView") as Sprite2D
@onready var _mid: Sprite2D = get_node_or_null("MidView") as Sprite2D
@onready var _ground: Sprite2D = get_node_or_null("GroundBase") as Sprite2D

## 每层的基准 Y 坐标（在 _ready 时快照，之后叠加动画偏移）
var _base_y_sky: float = 0.0
var _base_y_far: float = 0.0
var _base_y_mid: float = 0.0
var _base_y_ground: float = 0.0

## 跟随节点缓存 + 它们的基准 Y（快照一次，之后只叠加 delta_y）
var _follow_nodes: Array[Node2D] = []
var _follow_base_y: Array[float] = []

## 呼吸累计时间
var _idle_time: float = 0.0
## 是否暂停呼吸（攻击/受击 Tween 期间暂停，避免位置被呼吸覆盖）
var _anim_lock: bool = false


func _ready() -> void:
	# 快照初始 Y（设计师在编辑器里拖的位置）
	if _sky != null:
		_base_y_sky = _sky.position.y
	if _far != null:
		_base_y_far = _far.position.y
	if _mid != null:
		_base_y_mid = _mid.position.y
	if _ground != null:
		_base_y_ground = _ground.position.y
	if _sky == null or _far == null or _mid == null or _ground == null:
		push_warning("[BgParallax] 某一层背景节点未找到，请检查 Sky/FarView/MidView/GroundBase 命名")
	# 解析跟随节点并快照基准 Y（EnemyContainer 等）
	_follow_nodes.clear()
	_follow_base_y.clear()
	for np: NodePath in follow_ground_nodes:
		var n: Node2D = get_node_or_null(np) as Node2D
		if n != null:
			_follow_nodes.append(n)
			_follow_base_y.append(n.position.y)
		else:
			push_warning("[BgParallax] follow_ground_nodes 路径未找到: %s" % str(np))


## 每帧驱动 Idle 呼吸（仅 Y 轴）
## 各层 Sin 波独立相位，越近的层振幅越大
## 同时把地面层的 Y 偏移按 follow_ground_ratio 同步到跟随节点（敌人不再浮空）
func _process(delta: float) -> void:
	if _anim_lock:
		return
	_idle_time += delta
	var omega: float = TAU / idle_period
	var ground_delta_y: float = 0.0
	if _sky != null:
		_sky.position.y = _base_y_sky + sin(_idle_time * omega) * sky_idle_amp
	if _far != null:
		_far.position.y = _base_y_far + sin(_idle_time * omega + layer_phase_step) * far_idle_amp
	if _mid != null:
		_mid.position.y = _base_y_mid + sin(_idle_time * omega + layer_phase_step * 2.0) * mid_idle_amp
	if _ground != null:
		ground_delta_y = sin(_idle_time * omega + layer_phase_step * 3.0) * ground_idle_amp
		_ground.position.y = _base_y_ground + ground_delta_y
	# 跟随节点：只叠加 delta_y，不覆盖 x
	var applied_dy: float = ground_delta_y * follow_ground_ratio
	for i: int in _follow_nodes.size():
		var node: Node2D = _follow_nodes[i]
		if is_instance_valid(node):
			node.position.y = _follow_base_y[i] + applied_dy


## 攻击推拉：玩家出手瞬间摄像机"下压半拍"，4 层按远近推
func play_attack_push() -> void:
	_play_layered_kick(
		-attack_push_sky, -attack_push_far, attack_push_mid, attack_push_ground,
		0.12, 0.22
	)


## 受击反弹：敌人命中瞬间摄像机被打退，4 层按远近反弹
func play_hurt_kick() -> void:
	_play_layered_kick(
		hurt_kick_sky, hurt_kick_far, -hurt_kick_mid, -hurt_kick_ground,
		0.08, 0.30
	)


# ============================================================
# 内部
# ============================================================

## 四层分层位移：各层先冲到目标偏移再回弹到基准
## 注意：sky/far/mid/ground 的 Y 偏移方向不同，由调用方传入（正值=向下，负值=向上）
func _play_layered_kick(
	sky_dy: float, far_dy: float, mid_dy: float, ground_dy: float,
	push_time: float, return_time: float
) -> void:
	_anim_lock = true
	# 各层独立 create_tween 串行，不需要父 tween（否则空 Tweeners 会报错）
	_tween_layer(_sky, _base_y_sky, sky_dy, push_time, return_time)
	_tween_layer(_far, _base_y_far, far_dy, push_time, return_time)
	_tween_layer(_mid, _base_y_mid, mid_dy, push_time, return_time)
	_tween_layer(_ground, _base_y_ground, ground_dy, push_time, return_time)
	# 跟随节点（敌人等）按地面层同方向位移，乘以 follow_ground_ratio
	var follow_dy: float = ground_dy * follow_ground_ratio
	for i: int in _follow_nodes.size():
		_tween_follow_node(_follow_nodes[i], _follow_base_y[i], follow_dy, push_time, return_time)
	# 总时长后解锁（恢复呼吸）—— 用 await 而非 timer.connect，节点销毁时协程自然终止
	var total: float = push_time + return_time + 0.05
	await get_tree().create_timer(total).timeout
	if not is_inside_tree():
		return
	_anim_lock = false


## 给单层建两段动画：冲向目标 → 回到基准
func _tween_layer(layer: Sprite2D, base_y: float, dy: float, push_time: float, return_time: float) -> void:
	if layer == null:
		return
	var sub := layer.create_tween()
	sub.set_ease(Tween.EASE_OUT)
	sub.set_trans(Tween.TRANS_CUBIC)
	sub.tween_property(layer, "position:y", base_y + dy, push_time)
	sub.tween_property(layer, "position:y", base_y, return_time).set_trans(Tween.TRANS_BACK)


## 驱动跟随节点（Node2D，非 Sprite2D）同步位移
func _tween_follow_node(node: Node2D, base_y: float, dy: float, push_time: float, return_time: float) -> void:
	if not is_instance_valid(node):
		return
	var sub := node.create_tween()
	sub.set_ease(Tween.EASE_OUT)
	sub.set_trans(Tween.TRANS_CUBIC)
	sub.tween_property(node, "position:y", base_y + dy, push_time)
	sub.tween_property(node, "position:y", base_y, return_time).set_trans(Tween.TRANS_BACK)
