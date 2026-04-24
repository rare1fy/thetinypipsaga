## 结算演出播放器 — 对应原版 runSettlementAnimation
## 四阶段时间线：手牌展示 → 骰子计分 → 效果触发 → 最终伤害
## 纯演出层，不改游戏状态；调用方传入最终结果，由本类分阶段呈现

class_name SettlementPlayer
extends CanvasLayer

# 阶段时长（毫秒）
const PHASE1_HAND_DISPLAY_MS := 450      # 手牌名称飞入 + 停留
const PHASE2_DICE_STEP_MS := 140         # 每颗骰子计分间隔
const PHASE2_DICE_HOLD_MS := 160         # 全部骰子累加完后停留
const PHASE3_EFFECT_MS := 300            # 效果触发（遗物闪烁 / 狂暴倍率）
const PHASE4_FINAL_MS := 260             # 最终伤害数字放大 + 震屏

# 演出开关（调试时可关）
const ENABLED := true

# UI 子节点
var _dim: ColorRect = null              # 半透明背景
var _hand_label: Label = null           # 牌型名（Phase 1）
var _sum_label: Label = null            # 计分累加（Phase 2）
var _bonus_label: Label = null          # 倍率提示（Phase 3）
var _final_label: Label = null          # 最终伤害（Phase 4）

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
	
	_hand_label = _make_label(32, Color("#f0c850"))
	_sum_label = _make_label(26, Color("#e0e8f0"))
	_bonus_label = _make_label(22, Color("#a858e8"))
	_final_label = _make_label(40, Color("#f07050"))
	
	# 竖排居中
	for l in [_hand_label, _sum_label, _bonus_label, _final_label]:
		add_child(l)
		l.visible = false


func _make_label(font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func is_running() -> bool:
	return _running


## 主入口：按四阶段播放结算演出（全程 await）
## data = {
##   hand_name: String,          # 牌型全名（Phase 1 显示）
##   dice_values: Array[int],    # 每颗骰子点数（Phase 2 逐个累加）
##   bonus_mult: float,          # 倍率加成 0..
##   bonus_damage: int,          # 额外伤害
##   total_damage: int,          # 最终伤害（Phase 4 显示）
##   has_aoe: bool,              # 是否 AOE（Phase 4 震屏强度）
## }
func play(data: Dictionary) -> void:
	if not ENABLED:
		return
	if _running:
		return
	_running = true
	
	_dim.visible = true
	_dim.modulate.a = 0.0
	var fade_tw := create_tween()
	fade_tw.tween_property(_dim, "modulate:a", 1.0, 0.1)
	
	await _phase1_hand_display(data.get("hand_name", "普通攻击"))
	await _phase2_dice_scoring(data.get("dice_values", []))
	await _phase3_effects(data.get("bonus_mult", 0.0), data.get("bonus_damage", 0))
	await _phase4_final_damage(data.get("total_damage", 0), data.get("has_aoe", false))
	
	# 收尾：全部淡出
	var close_tw := create_tween()
	close_tw.set_parallel(true)
	for l in [_hand_label, _sum_label, _bonus_label, _final_label, _dim]:
		close_tw.tween_property(l, "modulate:a", 0.0, 0.18)
	await close_tw.finished
	
	_dim.visible = false
	for l in [_hand_label, _sum_label, _bonus_label, _final_label]:
		l.visible = false
	_running = false


## ========== Phase 1: 牌型名横向飞入 ==========
func _phase1_hand_display(hand_name: String) -> void:
	_hand_label.text = hand_name
	_hand_label.visible = true
	_hand_label.modulate.a = 0.0
	_hand_label.scale = Vector2(0.6, 0.6)
	_hand_label.pivot_offset = _hand_label.size * 0.5
	
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_hand_label, "modulate:a", 1.0, 0.15)
	tw.tween_property(_hand_label, "scale", Vector2(1.1, 1.1), 0.2)
	await tw.finished
	
	var settle := create_tween()
	settle.tween_property(_hand_label, "scale", Vector2(1.0, 1.0), 0.1)
	await settle.finished
	
	# 音效
	if has_node("/root/SoundPlayer"):
		SoundPlayer.play_sound("hand_reveal")
	
	await get_tree().create_timer(PHASE1_HAND_DISPLAY_MS / 1000.0).timeout


## ========== Phase 2: 骰子逐个累加 ==========
func _phase2_dice_scoring(dice_values: Array) -> void:
	if dice_values.is_empty():
		return
	
	_sum_label.visible = true
	_sum_label.modulate.a = 1.0
	var running_sum := 0
	for v in dice_values:
		running_sum += int(v)
		_sum_label.text = "+ %d  =  %d" % [int(v), running_sum]
		# 每次 tick 放大一下
		var pop := create_tween()
		_sum_label.pivot_offset = _sum_label.size * 0.5
		_sum_label.scale = Vector2(1.15, 1.15)
		pop.tween_property(_sum_label, "scale", Vector2(1.0, 1.0), 0.1)
		if has_node("/root/SoundPlayer"):
			SoundPlayer.play_sound("tick")
		await get_tree().create_timer(PHASE2_DICE_STEP_MS / 1000.0).timeout
	
	await get_tree().create_timer(PHASE2_DICE_HOLD_MS / 1000.0).timeout


## ========== Phase 3: 倍率/额外伤害提示 ==========
func _phase3_effects(bonus_mult: float, bonus_damage: int) -> void:
	var parts: Array[String] = []
	if bonus_mult > 0.001:
		parts.append("×%.2f 倍率" % (1.0 + bonus_mult))
	if bonus_damage > 0:
		parts.append("+%d 额外伤害" % bonus_damage)
	
	if parts.is_empty():
		return
	
	_bonus_label.text = " · ".join(parts)
	_bonus_label.visible = true
	_bonus_label.modulate.a = 0.0
	
	var tw := create_tween()
	tw.tween_property(_bonus_label, "modulate:a", 1.0, 0.15)
	await tw.finished
	
	if has_node("/root/SoundPlayer"):
		SoundPlayer.play_sound("multiplier")
	
	await get_tree().create_timer(PHASE3_EFFECT_MS / 1000.0).timeout


## ========== Phase 4: 最终伤害数字放大 + 震屏 ==========
func _phase4_final_damage(total_damage: int, has_aoe: bool) -> void:
	_final_label.text = "-%d" % total_damage
	_final_label.visible = true
	_final_label.modulate.a = 0.0
	_final_label.pivot_offset = _final_label.size * 0.5
	_final_label.scale = Vector2(0.4, 0.4)
	
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_final_label, "modulate:a", 1.0, 0.15)
	tw.tween_property(_final_label, "scale", Vector2(1.3, 1.3), 0.2)
	await tw.finished
	
	# 震屏 + 重击音
	GameManager.screen_shake_requested.emit()
	if has_node("/root/SoundPlayer"):
		SoundPlayer.play_heavy_impact(2.0 if has_aoe else 1.2)
	
	var settle := create_tween()
	settle.tween_property(_final_label, "scale", Vector2(1.0, 1.0), 0.12)
	await settle.finished
	
	await get_tree().create_timer(PHASE4_FINAL_MS / 1000.0).timeout
