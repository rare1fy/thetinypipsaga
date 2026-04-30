## player_hands.gd — 第一人称双手视角
## 职责：玩家视觉反馈（受击缩手/死亡垂手/攻击挥手）
## 布局（对齐概念图）：
##   - 左手（LeftHand）在屏幕左下，未来持骰子
##   - 右手（RightHand）在屏幕右下，持武器/剑
## 挂载位置：BattleScene → PlayerHandsLayer(CanvasLayer) → PlayerHands(根)
## 根类型：Node2D（手要做位置/旋转/缩放动画，Control 打架）

class_name PlayerHands
extends Node2D

signal attack_finished

## 左手基准位置（Node2D 本地坐标，相对于 PlayerHands 根）
## 美术资源替换后只需要调整这里即可
@export var left_hand_base_pos: Vector2 = Vector2(0, 0)
@export var right_hand_base_pos: Vector2 = Vector2(0, 0)

## 受击时双手下沉距离（px）
@export var hurt_sink_distance: float = 20.0
## 死亡时双手下垂距离
@export var death_drop_distance: float = 200.0
## 攻击时右手前挥距离
@export var attack_swing_distance: float = 30.0

@onready var left_hand: Node2D = %LeftHand
@onready var right_hand: Node2D = %RightHand

var _is_dead: bool = false


func _ready() -> void:
	# 初始化到基准位置（防止美术拖拽后运行时漂移）
	left_hand.position = left_hand_base_pos
	right_hand.position = right_hand_base_pos


## 受击反馈：双手快速下沉 + 轻微晃动 + 闪红
func play_hurt() -> void:
	if _is_dead:
		return
	_shake_hand(left_hand, left_hand_base_pos, hurt_sink_distance)
	_shake_hand(right_hand, right_hand_base_pos, hurt_sink_distance)
	_flash_red(left_hand)
	_flash_red(right_hand)


## 攻击反馈：右手挥武器 + 左手扔骰子
## 对齐概念图：左手拿骰子 / 右手持剑
func play_attack() -> void:
	if _is_dead:
		attack_finished.emit()
		return
	# 右手（持武器）大幅前挥
	var right_tween := create_tween()
	right_tween.set_ease(Tween.EASE_OUT)
	right_tween.set_trans(Tween.TRANS_CUBIC)
	var right_swing := right_hand_base_pos + Vector2(-10, -attack_swing_distance)
	right_tween.tween_property(right_hand, "position", right_swing, 0.12)
	right_tween.tween_property(right_hand, "position", right_hand_base_pos, 0.18).set_trans(Tween.TRANS_BACK)
	# 左手（拿骰子）向前上"抛"一下
	var left_tween := create_tween()
	left_tween.set_ease(Tween.EASE_OUT)
	left_tween.set_trans(Tween.TRANS_CUBIC)
	var left_toss := left_hand_base_pos + Vector2(10, -attack_swing_distance * 0.8)
	left_tween.tween_property(left_hand, "position", left_toss, 0.1)
	left_tween.tween_property(left_hand, "position", left_hand_base_pos, 0.2).set_trans(Tween.TRANS_BACK)
	# 动画约 0.30s；用 SceneTree timer 确保 signal 在指定时间后发射（不依赖任何节点生命周期）
	get_tree().create_timer(0.30).timeout.connect(func() -> void:
		if is_instance_valid(self):
			attack_finished.emit()
	)


## 死亡反馈：双手缓慢垂下 + 变灰
func play_death() -> void:
	if _is_dead:
		return
	_is_dead = true
	var tween := create_tween().set_parallel(true)
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_QUAD)
	# 双手下垂
	tween.tween_property(left_hand, "position",
		left_hand_base_pos + Vector2(0, death_drop_distance), 1.2)
	tween.tween_property(right_hand, "position",
		right_hand_base_pos + Vector2(0, death_drop_distance), 1.2)
	# 双手变灰
	tween.tween_property(left_hand, "modulate", Color(0.4, 0.4, 0.4, 0.8), 1.2)
	tween.tween_property(right_hand, "modulate", Color(0.4, 0.4, 0.4, 0.8), 1.2)


## 获取骰子锚点（未来骰子抛掷动画起点 / 终点）
## side: "left" = 左手（拿骰子）, "right" = 右手（持武器）
func get_dice_anchor(side: String = "left") -> Vector2:
	var hand: Node2D = left_hand if side == "left" else right_hand
	if hand == null:
		return global_position
	# 先查找手内子节点 DiceAnchor（Marker2D）
	var anchor: Node2D = hand.get_node_or_null("DiceAnchor")
	if anchor != null:
		return anchor.global_position
	return hand.global_position


## 重置到初始状态（波次切换 / 关卡切换时调用）
func reset_state() -> void:
	_is_dead = false
	left_hand.position = left_hand_base_pos
	right_hand.position = right_hand_base_pos
	left_hand.modulate = Color.WHITE
	right_hand.modulate = Color.WHITE


# ============================================================
# 内部动画辅助
# ============================================================

func _shake_hand(hand: Node2D, base_pos: Vector2, sink: float) -> void:
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	# 下沉
	tween.tween_property(hand, "position", base_pos + Vector2(0, sink), 0.08)
	# 左右抖
	tween.tween_property(hand, "position", base_pos + Vector2(-6, sink * 0.5), 0.06)
	tween.tween_property(hand, "position", base_pos + Vector2(6, sink * 0.3), 0.06)
	# 弹回
	tween.tween_property(hand, "position", base_pos, 0.12).set_trans(Tween.TRANS_BACK)


func _flash_red(hand: Node2D) -> void:
	var tween := create_tween()
	tween.tween_property(hand, "modulate", Color(1.5, 0.5, 0.5, 1), 0.08)
	tween.tween_property(hand, "modulate", Color.WHITE, 0.25)