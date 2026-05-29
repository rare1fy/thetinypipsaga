## 结算演出播放器 — 对应原版 runSettlementAnimation
## 五阶段时间线：
##   Phase 1: 牌型名飞入
##   Phase 2: 选中的骰子逐颗从左到右弹入 + 每颗累加点数（X 递增）
##   Phase 2.5: 倍率提示（×M 从小到大弹出）
##   Phase 3: 遗物加成闪烁 + 飘字（bonus_damage / bonus_mult）
##   Phase 4: 最终伤害大字爆炸 + 震屏
## 纯演出层，不改游戏状态；调用方传入最终结果，由本类分阶段呈现

class_name SettlementPlayer
extends CanvasLayer

@export_group("阶段时长-毫秒")
## 牌型名显示时长
@export var phase1_hand_display_ms: int = 400
## 每颗骰子出现间隔（原版 280ms，越大越慢）
@export var phase2_dice_step_ms: int = 260
## 骰子全部出完后停顿
@export var phase2_dice_hold_ms: int = 150
## 倍率弹出
@export var phase25_mult_ms: int = 400
## 遗物加成闪烁
@export var phase3_effect_ms: int = 350
## 最终伤害停留
@export var phase4_final_ms: int = 380

@export_group("调试")
## 演出开关（关闭后跳过所有演出直接结算）
@export var enabled: bool = true

# UI 子节点
var _dim: ColorRect = null                # 半透明背景
var _panel: VBoxContainer = null          # 垂直主面板（居中）
var _hand_label: Label = null             # 牌型名（Phase 1）
var _dice_row: HBoxContainer = null       # 骰子横向行（Phase 2）
var _base_label: Label = null             # 基础值累加（Phase 2 底部）
var _mult_label: Label = null             # 倍率（Phase 2.5）
var _bonus_label: Label = null            # 遗物加成（Phase 3）
var _final_label: Label = null            # 最终伤害（Phase 4）

var _running: bool = false


func _ready() -> void:
	layer = 80
	_build_ui()


func _build_ui() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.35)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.visible = false
	add_child(_dim)

	# 垂直主面板（各行不重叠）
	_panel = VBoxContainer.new()
	_panel.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.add_theme_constant_override("separation", 14)
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	add_child(_panel)

	_hand_label = _make_label(30, Color("#f0c850"))
	_panel.add_child(_hand_label)

	_dice_row = HBoxContainer.new()
	_dice_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_dice_row.add_theme_constant_override("separation", 8)
	_dice_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_dice_row)

	_base_label = _make_label(24, Color("#e0e8f0"))
	_panel.add_child(_base_label)

	_mult_label = _make_label(28, Color("#ffb04a"))
	_panel.add_child(_mult_label)

	_bonus_label = _make_label(20, Color("#a858e8"))
	_panel.add_child(_bonus_label)

	_final_label = _make_label(44, Color("#f07050"))
	_panel.add_child(_final_label)

	for l: Label in [_hand_label, _base_label, _mult_label, _bonus_label, _final_label]:
		l.visible = false
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.size_flags_horizontal = Control.SIZE_SHRINK_CENTER


func _make_label(font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func is_running() -> bool:
	return _running


## 主入口：按五阶段播放结算演出（全程 await）
## data = {
##   hand_name: String,          # 牌型全名（Phase 1 显示）
##   dice_values: Array[int],    # 每颗骰子点数（Phase 2 逐个累加）
##   bonus_mult: float,          # 倍率加成 0..（额外 mult，非基础牌型 mult）
##   bonus_damage: int,          # 额外伤害
##   total_damage: int,          # 最终伤害（Phase 4 显示）
##   has_aoe: bool,              # 是否 AOE（Phase 4 震屏强度）
## }
func play(data: Dictionary) -> void:
	print_rich("[color=green][SettlementPlayer] play() 入口: enabled=%s _running=%s[/color]" % [enabled, _running])
	if not enabled:
		return
	if _running:
		push_warning("[SettlementPlayer] play() called while _running=true, skipping")
		return
	_running = true

	_dim.visible = true
	_panel.visible = true
	_dim.modulate.a = 0.0
	var fade_tw := create_tween()
	fade_tw.tween_property(_dim, "modulate:a", 1.0, 0.1)

	# Phase 1
	await _phase1_hand_display(data.get("hand_name", "普通攻击"))
	# Phase 2
	var dice_values: Array[int] = _coerce_int_array(data.get("dice_values", []))
	await _phase2_dice_scoring(dice_values)
	# Phase 2.5 倍率
	await _phase25_multiplier(data.get("outcome_mult", 1.0))
	# Phase 3 遗物加成
	await _phase3_effects(data.get("bonus_base_damage", 0))
	# Phase 4 最终伤害
	await _phase4_final_damage(data.get("total_damage", 0), data.get("has_aoe", false))

	# 收尾淡出
	print_rich("[color=green][SettlementPlayer] 收尾淡出[/color]")
	var close_tw := create_tween()
	close_tw.set_parallel(true)
	close_tw.tween_property(_dim, "modulate:a", 0.0, 0.18)
	close_tw.tween_property(_panel, "modulate:a", 0.0, 0.18)
	await _safe_await_tween(close_tw, 0.5)

	_cleanup_after_play()
	print_rich("[color=green][SettlementPlayer] play() 完成, _running=false[/color]")


func _cleanup_after_play() -> void:
	_dim.visible = false
	_panel.visible = false
	_panel.modulate.a = 1.0
	for l: Label in [_hand_label, _base_label, _mult_label, _bonus_label, _final_label]:
		l.visible = false
		l.modulate.a = 1.0
	for c: Node in _dice_row.get_children():
		c.queue_free()
	_running = false


func _coerce_int_array(raw: Variant) -> Array[int]:
	var out: Array[int] = []
	if raw is Array[int]:
		return raw
	if raw is Array:
		for v: int in raw:
			out.append(v)
	return out


# ========== Phase 1: 牌型名放大飞入 ==========
func _phase1_hand_display(hand_name: String) -> void:
	_hand_label.text = hand_name
	_hand_label.visible = true
	_hand_label.modulate.a = 0.0
	_hand_label.pivot_offset = _hand_label.size * 0.5
	_hand_label.scale = Vector2(0.6, 0.6)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_hand_label, "modulate:a", 1.0, 0.15)
	tw.tween_property(_hand_label, "scale", Vector2(1.1, 1.1), 0.2)
	await _safe_await_tween(tw, 0.5)

	var settle := create_tween()
	settle.tween_property(_hand_label, "scale", Vector2(1.0, 1.0), 0.1)
	await _safe_await_tween(settle, 0.3)

	if has_node("/root/SoundPlayer"):
		SoundPlayer.play_sound("hand_reveal")

	await get_tree().create_timer(phase1_hand_display_ms / 1000.0).timeout


# ========== Phase 2: 骰子逐颗弹入 + X 累加 ==========
func _phase2_dice_scoring(dice_values: Array[int]) -> void:
	if dice_values.is_empty():
		return

	# 清空旧骰子
	for c: Node in _dice_row.get_children():
		c.queue_free()

	_base_label.visible = true
	_base_label.modulate.a = 1.0
	_base_label.text = ""

	var running_sum := 0
	for i: int in dice_values.size():
		var v: int = dice_values[i]
		# 创建单颗骰子面板
		var die_box: PanelContainer = _make_die_box(v)
		_dice_row.add_child(die_box)
		# 弹入动画：放大 + 淡入
		die_box.modulate.a = 0.0
		die_box.pivot_offset = Vector2(22, 22)
		die_box.scale = Vector2(0.5, 0.5)
		var pop := create_tween()
		pop.set_parallel(true)
		pop.tween_property(die_box, "modulate:a", 1.0, 0.12)
		pop.tween_property(die_box, "scale", Vector2(1.15, 1.15), 0.14)

		# 累加 X
		running_sum += v
		_base_label.text = "X = %d" % running_sum
		# X 每次 tick 脉冲
		_base_label.pivot_offset = _base_label.size * 0.5
		_base_label.scale = Vector2(1.18, 1.18)
		var shrink := create_tween()
		shrink.tween_property(_base_label, "scale", Vector2(1.0, 1.0), 0.12)

		if has_node("/root/SoundPlayer"):
			SoundPlayer.play_sound("tick")

		await get_tree().create_timer(phase2_dice_step_ms / 1000.0).timeout
		# 骰子回到正常大小
		var final := create_tween()
		final.tween_property(die_box, "scale", Vector2(1.0, 1.0), 0.08)

	await get_tree().create_timer(phase2_dice_hold_ms / 1000.0).timeout


## 生成单颗骰子的 PanelContainer（42×42，含点数 Label）
func _make_die_box(value: int) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(12, 12)
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.96, 0.96, 0.88, 1.0)
	sb.border_color = Color(0.25, 0.20, 0.15, 1.0)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	pc.add_theme_stylebox_override("panel", sb)
	var lbl := Label.new()
	lbl.text = str(value)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.15, 0.12, 0.10, 1.0))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(lbl)
	return pc


# ========== Phase 2.5: 倍率弹出 ==========
func _phase25_multiplier(outcome_mult: float) -> void:
	# v0.5: outcome_mult 基准为 1.0，无额外加成时跳过
	if outcome_mult <= 1.001:
		return
	_mult_label.text = "×%.2f" % outcome_mult
	_mult_label.visible = true
	_mult_label.modulate.a = 0.0
	_mult_label.pivot_offset = _mult_label.size * 0.5
	_mult_label.scale = Vector2(0.4, 0.4)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_mult_label, "modulate:a", 1.0, 0.12)
	tw.tween_property(_mult_label, "scale", Vector2(1.2, 1.2), 0.15)
	await _safe_await_tween(tw, 0.4)

	if has_node("/root/SoundPlayer"):
		SoundPlayer.play_sound("multiplier")

	var settle := create_tween()
	settle.tween_property(_mult_label, "scale", Vector2(1.0, 1.0), 0.1)
	await _safe_await_tween(settle, 0.3)

	await get_tree().create_timer(phase25_mult_ms / 1000.0).timeout


# ========== Phase 3: 额外基础伤害（进乘区） ==========
func _phase3_effects(bonus_base_damage: int) -> void:
	if bonus_base_damage <= 0:
		return
	_bonus_label.text = "基础伤害 +%d" % bonus_base_damage
	_bonus_label.visible = true
	_bonus_label.modulate.a = 0.0
	_bonus_label.pivot_offset = _bonus_label.size * 0.5
	_bonus_label.scale = Vector2(0.7, 0.7)

	# 闪烁 3 次
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_bonus_label, "modulate:a", 1.0, 0.1)
	tw.tween_property(_bonus_label, "scale", Vector2(1.1, 1.1), 0.12)
	await _safe_await_tween(tw, 0.3)

	if has_node("/root/SoundPlayer"):
		SoundPlayer.play_sound("relic_activate")

	var flash := create_tween()
	flash.set_loops(2)
	flash.tween_property(_bonus_label, "modulate", Color(1.8, 1.2, 2.0, 1), 0.10)
	flash.tween_property(_bonus_label, "modulate", Color(1, 1, 1, 1), 0.10)
	await _safe_await_tween(flash, 0.8)

	await get_tree().create_timer(phase3_effect_ms / 1000.0).timeout


# ========== Phase 4: 最终伤害数字放大 + 震屏 ==========
func _phase4_final_damage(total_damage: int, has_aoe: bool) -> void:
	_final_label.text = "-%d" % total_damage
	_final_label.visible = true
	_final_label.modulate.a = 0.0
	_final_label.pivot_offset = _final_label.size * 0.5
	_final_label.scale = Vector2(0.4, 0.4)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_final_label, "modulate:a", 1.0, 0.15)
	tw.tween_property(_final_label, "scale", Vector2(1.35, 1.35), 0.18)
	await _safe_await_tween(tw, 0.5)

	# 震屏 + 重击音
	GameManager.screen_shake_requested.emit()
	if has_node("/root/SoundPlayer"):
		SoundPlayer.play_heavy_impact(2.0 if has_aoe else 1.2)

	var settle := create_tween()
	settle.tween_property(_final_label, "scale", Vector2(1.0, 1.0), 0.12)
	await _safe_await_tween(settle, 0.3)

	await get_tree().create_timer(phase4_final_ms / 1000.0).timeout


## 安全 await tween：只 await 一次 tween.finished（Tween 信号自动在 tween 销毁时触发）
## 不再用 while 每帧轮询，避免回调堆积
func _safe_await_tween(tw: Tween, _timeout_sec: float) -> void:
	if tw == null or not tw.is_valid():
		return
	await tw.finished
