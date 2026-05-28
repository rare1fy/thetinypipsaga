## player_hands.gd — 第一人称双手视角
## 职责：玩家视觉反馈（待机呼吸/受击缩手/死亡垂手/摇骰子/攻击挥手）
## 布局（对齐概念图）：
##   - 左手（LeftHand）在屏幕左下，持骰子
##   - 右手（RightHand）在屏幕右下，持武器/剑
## 挂载位置：BattleScene → PlayerHandsLayer(CanvasLayer) → PlayerHands(根)
## 根类型：Node2D（手要做位置/旋转/缩放动画，Control 打架）

class_name PlayerHands
extends Node2D

signal attack_finished
signal roll_dice_finished

@export_group("基准位置")
## 左手基准位置（Node2D 本地坐标，相对于 PlayerHands 根）
@export var left_hand_base_pos: Vector2 = Vector2(0, 0)
## 右手基准位置
@export var right_hand_base_pos: Vector2 = Vector2(0, 0)

@export_group("受击动作")
## 受击时双手下沉距离（px）
@export var hurt_sink_distance: float = 20.0

@export_group("死亡动作")
## 死亡时双手下垂距离
@export var death_drop_distance: float = 200.0

@export_group("攻击动作")
## 攻击时右手前挥距离
@export var attack_swing_distance: float = 30.0

@export_group("待机呼吸")
## Y 轴振幅（px，越大起伏越明显）
@export var idle_breath_amp: float = 4.0
## 周期（秒，越大越慢）
@export var idle_breath_period: float = 2.6
## 左右手相位差（弧度，让呼吸不同步）
@export var idle_breath_phase_offset: float = 0.5

@onready var left_hand: Node2D = %LeftHand
@onready var right_hand: Node2D = %RightHand

var _is_dead: bool = false
## 是否正在播放"独占动画"（受击/攻击/摇骰子/死亡），此时暂停呼吸叠加
var _anim_lock: bool = false
## 呼吸累计时间
var _breath_time: float = 0.0
## 根节点基准 scale（在 _ready 时快照，攻击动画做相对缩放用）
var _base_scale: Vector2 = Vector2.ONE


func _ready() -> void:
	# 初始化到基准位置（防止美术拖拽后运行时漂移）
	left_hand.position = left_hand_base_pos
	right_hand.position = right_hand_base_pos
	_base_scale = scale  # 快照场景里拖的 scale（通常 2,2）
	# Idle 呼吸默认开启
	set_process(true)


## 每帧驱动 idle 呼吸：两手在 Y 轴做 Sin 波起伏，相位错开模拟左右呼吸
## 使用 _process 而非 Tween：和其他动画共存时只需要切 _anim_lock 开关，避免 Tween 冲突
func _process(delta: float) -> void:
	if _is_dead or _anim_lock:
		return
	_breath_time += delta
	var omega: float = TAU / idle_breath_period
	var left_offset: float = sin(_breath_time * omega) * idle_breath_amp
	var right_offset: float = sin(_breath_time * omega + idle_breath_phase_offset) * idle_breath_amp
	left_hand.position = left_hand_base_pos + Vector2(0, left_offset)
	right_hand.position = right_hand_base_pos + Vector2(0, right_offset)


## 受击反馈：双手快速下沉 + 轻微晃动 + 闪红
## 用协程 await 替代 timer.connect，节点销毁时协程自然终止
func play_hurt() -> void:
	if _is_dead:
		return
	_play_hurt_coroutine()


func _play_hurt_coroutine() -> void:
	_anim_lock = true
	_shake_hand(left_hand, left_hand_base_pos, hurt_sink_distance)
	_shake_hand(right_hand, right_hand_base_pos, hurt_sink_distance)
	_flash_red(left_hand)
	_flash_red(right_hand)
	await get_tree().create_timer(0.32).timeout
	if not is_inside_tree():
		return
	_anim_lock = false


## 摇骰子动画：两手同时左右快速晃动 + 微幅旋转，模拟摇骰筒
func play_roll_dice() -> void:
	if _is_dead:
		roll_dice_finished.emit()
		return
	_play_roll_dice_coroutine()


func _play_roll_dice_coroutine() -> void:
	_anim_lock = true
	_shake_hand_side(left_hand, left_hand_base_pos, -1.0)
	_shake_hand_side(right_hand, right_hand_base_pos, 1.0)
	await get_tree().create_timer(0.40).timeout
	if not is_inside_tree():
		return
	_anim_lock = false
	roll_dice_finished.emit()


## 攻击反馈 — 5 拍分镜（蓄力→顿帧→急挥→冲击定格→回收）
## 核心帅点：Hit-Stop（打击瞬间全局 time_scale 凝滞）+ 旋转挥砍 + 根节点震屏 + 剑气残像
func play_attack() -> void:
	print_rich("[color=cyan][PlayerHands] play_attack: _is_dead=%s[/color]" % _is_dead)
	if _is_dead:
		attack_finished.emit()
		return
	_play_attack_coroutine()


func _play_attack_coroutine() -> void:
	_anim_lock = true
	# 相对缩放系数（基于场景里拖的 _base_scale，避免硬编码 2.0）
	var scale_charge: Vector2 = _base_scale * 1.03   # 蓄力微胀
	var scale_strike: Vector2 = _base_scale * 0.98   # 急挥急缩
	var scale_normal: Vector2 = _base_scale          # 回收归位

	# --- 拍 ① 蓄力 0.14s：右手反向抬高后拉 + 左手内收下压，全身轻微放大 ---
	var charge_left := left_hand_base_pos + Vector2(-6, 10)
	var charge_right := right_hand_base_pos + Vector2(-28, -attack_swing_distance * 0.75)
	var charge_rot_right := deg_to_rad(-25.0)  # 向后上拧
	var tw_charge := create_tween().set_parallel(true)
	tw_charge.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO)
	tw_charge.tween_property(left_hand, "position", charge_left, 0.14)
	tw_charge.tween_property(right_hand, "position", charge_right, 0.14)
	tw_charge.tween_property(right_hand, "rotation", charge_rot_right, 0.14)
	tw_charge.tween_property(self, "scale", scale_charge, 0.14)
	await tw_charge.finished
	if not is_inside_tree():
		_anim_lock = false
		return

	# --- 拍 ② 顿帧 0.05s：蓄力巅峰停住，营造"即将爆发"的紧张感 ---
	await get_tree().create_timer(0.05).timeout
	if not is_inside_tree():
		_anim_lock = false
		return

	# --- 拍 ③ 急挥 0.08s：右手向前下方劈砍 + 大幅旋转 + 剑气残像 ---
	var strike_right := right_hand_base_pos + Vector2(18, -attack_swing_distance * 0.2)
	var strike_rot_right := deg_to_rad(45.0)  # 向前下方砍
	_spawn_slash_trail()  # 派生剑气残像
	var tw_strike := create_tween().set_parallel(true)
	tw_strike.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	tw_strike.tween_property(right_hand, "position", strike_right, 0.08)
	tw_strike.tween_property(right_hand, "rotation", strike_rot_right, 0.08)
	tw_strike.tween_property(left_hand, "position",
		left_hand_base_pos + Vector2(4, 16), 0.08)  # 左手稳住向后让
	tw_strike.tween_property(self, "scale", scale_strike, 0.08)
	await tw_strike.finished
	if not is_inside_tree():
		_anim_lock = false
		return

	# --- 拍 ④ Hit-Stop 0.08s：全局凝滞，这是"帅"的灵魂 ---
	# 保存原 time_scale，避免被外部代码覆盖后无法恢复
	var prev_time_scale: float = Engine.time_scale
	Engine.time_scale = 0.12
	# create_timer(wait_time, process_always, process_in_physics, ignore_time_scale)
	# ignore_time_scale=true：timer 按真实时间走，不受 time_scale 影响
	await get_tree().create_timer(0.08, true, false, true).timeout
	Engine.time_scale = prev_time_scale  # 无论节点是否存活都恢复，防死锁
	if not is_inside_tree():
		_anim_lock = false
		return
	attack_finished.emit()  # 伤害结算在冲击定格时触发，视觉最帅

	# --- 拍 ⑤ 回收 0.22s：右手带旋转回归，整体缓慢归位 ---
	var tw_recover := create_tween().set_parallel(true)
	tw_recover.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw_recover.tween_property(right_hand, "position", right_hand_base_pos, 0.22)
	tw_recover.tween_property(right_hand, "rotation", 0.0, 0.22)
	tw_recover.tween_property(left_hand, "position", left_hand_base_pos, 0.22)
	tw_recover.tween_property(self, "scale", scale_normal, 0.22)
	await tw_recover.finished
	if not is_inside_tree():
		return
	_anim_lock = false


## 派生右手剑气残像：克隆一个半透明副本，自行淡出销毁
## 不引用 self，timer 销毁也不炸
func _spawn_slash_trail() -> void:
	if not is_instance_valid(right_hand):
		return
	var trail := Sprite2D.new()
	# RightHand 本身就是 Sprite2D，直接取其 texture
	var src_sprite: Sprite2D = right_hand as Sprite2D
	if src_sprite != null and src_sprite.texture != null:
		trail.texture = src_sprite.texture
		trail.scale = src_sprite.scale
	trail.global_position = right_hand.global_position
	trail.rotation = right_hand.rotation
	trail.modulate = Color(1.2, 1.4, 2.0, 0.55)  # 冷白蓝剑气
	trail.z_index = -1
	right_hand.get_parent().add_child(trail)
	# 自淡出销毁，独立生命周期
	var fade := trail.create_tween()
	fade.tween_property(trail, "modulate:a", 0.0, 0.25)
	fade.parallel().tween_property(trail, "scale", trail.scale * 1.4, 0.25)
	fade.tween_callback(trail.queue_free)


## 死亡反馈：双手缓慢垂下 + 变灰
func play_death() -> void:
	if _is_dead:
		return
	_is_dead = true
	_anim_lock = true
	set_process(false) # 停呼吸
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


## 获取骰子锚点（骰子抛掷动画起点 / 终点）
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
	_anim_lock = false
	_breath_time = 0.0
	left_hand.position = left_hand_base_pos
	right_hand.position = right_hand_base_pos
	left_hand.rotation = 0.0
	right_hand.rotation = 0.0
	left_hand.modulate = Color.WHITE
	right_hand.modulate = Color.WHITE
	scale = _base_scale  # 兜底：攻击协程被打断时 scale 可能停在非基准值
	set_process(true)


# ============================================================
# 内部动画辅助
# ============================================================

## 释放动画锁：恢复 Idle 呼吸
func _release_anim_lock() -> void:
	_anim_lock = false


## 下沉+左右抖动（受击用）
func _shake_hand(hand: Node2D, base_pos: Vector2, sink: float) -> void:
	var tween := hand.create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	# 下沉
	tween.tween_property(hand, "position", base_pos + Vector2(0, sink), 0.08)
	# 左右抖
	tween.tween_property(hand, "position", base_pos + Vector2(-6, sink * 0.5), 0.06)
	tween.tween_property(hand, "position", base_pos + Vector2(6, sink * 0.3), 0.06)
	# 弹回
	tween.tween_property(hand, "position", base_pos, 0.12).set_trans(Tween.TRANS_BACK)


## 横向快速晃动（摇骰子用）：x 方向先远后近抖 3 次，带微幅旋转
## direction: -1.0 = 向左偏 / 1.0 = 向右偏（左右手方向不同）
func _shake_hand_side(hand: Node2D, base_pos: Vector2, direction: float) -> void:
	var amp: float = 8.0
	var rot_amp: float = deg_to_rad(6.0) * direction
	# 位置轨道
	var pos_tw := hand.create_tween()
	pos_tw.set_ease(Tween.EASE_IN_OUT)
	pos_tw.set_trans(Tween.TRANS_SINE)
	pos_tw.tween_property(hand, "position", base_pos + Vector2(amp * direction, -4), 0.08)
	pos_tw.tween_property(hand, "position", base_pos + Vector2(-amp * direction, 2), 0.08)
	pos_tw.tween_property(hand, "position", base_pos + Vector2(amp * direction * 0.6, -2), 0.08)
	pos_tw.tween_property(hand, "position", base_pos + Vector2(-amp * direction * 0.3, 1), 0.08)
	pos_tw.tween_property(hand, "position", base_pos, 0.08).set_trans(Tween.TRANS_BACK)
	# 旋转轨道（并行）
	var rot_tw := hand.create_tween()
	rot_tw.set_ease(Tween.EASE_IN_OUT)
	rot_tw.set_trans(Tween.TRANS_SINE)
	rot_tw.tween_property(hand, "rotation", rot_amp, 0.08)
	rot_tw.tween_property(hand, "rotation", -rot_amp, 0.08)
	rot_tw.tween_property(hand, "rotation", rot_amp * 0.5, 0.08)
	rot_tw.tween_property(hand, "rotation", 0.0, 0.16)


func _flash_red(hand: Node2D) -> void:
	var tween := hand.create_tween()
	tween.tween_property(hand, "modulate", Color(1.5, 0.5, 0.5, 1), 0.08)
	tween.tween_property(hand, "modulate", Color.WHITE, 0.25)
