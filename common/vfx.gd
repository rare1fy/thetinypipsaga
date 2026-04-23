## 动画引擎 — 原版 framer-motion + CSS @keyframes 的 Godot Tween 等效方案
## 对应原版: motion/react (44组件) + index.css (120+ @keyframes) + ParticleEffects.tsx
## 统一封装所有 UI 动画、战斗特效、屏幕震动、粒子效果
## 使用方式: VFX.shake(node) / VFX.pulse(node) / VFX.fade_in(control) 等

class_name VFX

## ==========================================
## 屏幕震动（对应原版 screenShake / pixel-screen-shake）
## ==========================================

## 水平震动 — 用于受击/暴击/重击
static func shake(node: Node, intensity: float = 8.0, duration: float = 0.3, decay: bool = true) -> void:
	var tween := node.create_tween()
	var steps := 6
	for i in steps:
		var progress := float(i) / steps
		var amp := intensity * (1.0 - progress * 0.7) if decay else intensity
		var dir := 1.0 if i % 2 == 0 else -1.0
		tween.tween_property(node, "position:x", node.position.x + amp * dir, duration / steps)
	tween.tween_property(node, "position:x", node.position.x, duration / steps)


## 全向震动 — Boss出场/大伤害
static func shake_heavy(node: Node, intensity: float = 12.0, duration: float = 0.5) -> void:
	var tween := node.create_tween()
	var offsets := [Vector2(-3, 4), Vector2(4, -3), Vector2(-2, 2), Vector2(3, -1), Vector2(0, 0)]
	for offset in offsets:
		var scaled := offset * (intensity / 10.0)
		tween.tween_property(node, "position", node.position + scaled, duration / offsets.size())
	tween.tween_property(node, "position", node.position, duration / offsets.size())


## ==========================================
## 淡入淡出（对应原版 AnimatePresence + fade_out/fade_in 信号）
## ==========================================

## 淡入
static func fade_in(control: Control, duration: float = 0.25, delay: float = 0.0) -> void:
	control.modulate.a = 0.0
	control.visible = true
	var tween := control.create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_property(control, "modulate:a", 1.0, duration)


## 淡出
static func fade_out(control: Control, duration: float = 0.25, callback: Callable = Callable()) -> void:
	var tween := control.create_tween()
	tween.tween_property(control, "modulate:a", 0.0, duration)
	if callback.is_valid():
		tween.tween_callback(callback)
	else:
		tween.tween_callback(func(): control.visible = false)


## 闪烁淡入淡出（战斗闪光覆盖层）
static func flash_overlay(control: Control, color: Color = Color.RED, duration: float = 0.3) -> void:
	control.modulate = Color(color.r, color.g, color.b, 0.0)
	control.visible = true
	var tween := control.create_tween()
	# 0→0.12→0.05→0.08→0 (模拟原版 opacity: [0, 0.12, 0.05, 0.08, 0])
	tween.tween_property(control, "modulate:a", 0.12, duration * 0.15)
	tween.tween_property(control, "modulate:a", 0.05, duration * 0.15)
	tween.tween_property(control, "modulate:a", 0.08, duration * 0.2)
	tween.tween_property(control, "modulate:a", 0.0, duration * 0.5)
	tween.tween_callback(func(): control.visible = false)


## ==========================================
## 缩放动画（对应原版 scale: 0 → 1 / spring 弹性）
## ==========================================

## 弹出（从小到大，带弹性）
static func pop_in(control: Control, duration: float = 0.4, delay: float = 0.0, overshoot: float = 1.2) -> void:
	control.scale = Vector2.ZERO
	control.visible = true
	var tween := control.create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_property(control, "scale", Vector2.ONE * overshoot, duration * 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "scale", Vector2.ONE, duration * 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


## 缩小消失
static func pop_out(control: Control, duration: float = 0.25, callback: Callable = Callable()) -> void:
	var tween := control.create_tween()
	tween.tween_property(control, "scale", Vector2.ZERO, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	if callback.is_valid():
		tween.tween_callback(callback)


## Spring 弹性缩放（对应原版 type: 'spring', stiffness/damping）
static func spring_scale(control: Control, target: Vector2, duration: float = 0.3, stiffness: float = 300.0) -> void:
	var tween := control.create_tween()
	# Godot 没有 spring tween，用 TRANS_ELASTIC 近似
	tween.tween_property(control, "scale", target, duration).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## ==========================================
## 滑动动画（对应原版 y/x offset 动画）
## ==========================================

## 从下方滑入
static func slide_in_from_bottom(control: Control, distance: float = 30.0, duration: float = 0.3, delay: float = 0.0) -> void:
	var target_y := control.position.y
	control.position.y += distance
	control.modulate.a = 0.0
	control.visible = true
	var tween := control.create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_property(control, "position:y", target_y, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(control, "modulate:a", 1.0, duration * 0.5)


## 从上方滑入
static func slide_in_from_top(control: Control, distance: float = 30.0, duration: float = 0.3, delay: float = 0.0) -> void:
	var target_y := control.position.y
	control.position.y -= distance
	control.modulate.a = 0.0
	control.visible = true
	var tween := control.create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_property(control, "position:y", target_y, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(control, "modulate:a", 1.0, duration * 0.5)


## 从左侧滑入
static func slide_in_from_left(control: Control, distance: float = 30.0, duration: float = 0.3, delay: float = 0.0) -> void:
	var target_x := control.position.x
	control.position.x -= distance
	control.modulate.a = 0.0
	control.visible = true
	var tween := control.create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_property(control, "position:x", target_x, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(control, "modulate:a", 1.0, duration * 0.5)


## ==========================================
## 脉冲/呼吸（对应原版 pixel-breathe / enemy-breathe / pixel-pulse）
## ==========================================

## 呼吸脉冲（上下浮动）— 用于敌人待机
static func breathe(control: Control, amplitude: float = 3.0, period: float = 2.0) -> Tween:
	var tween := control.create_tween().set_loops()
	tween.tween_property(control, "position:y", control.position.y - amplitude, period * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(control, "position:y", control.position.y, period * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tween


## 战士型呼吸（幅度大+左右晃）
static func breathe_warrior(control: Control, amplitude: float = 5.0, period: float = 1.8) -> Tween:
	var base_pos := control.position
	var tween := control.create_tween().set_loops()
	tween.tween_property(control, "position", base_pos + Vector2(-2, -amplitude), period * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(control, "position", base_pos, period * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tween


## 法师型呼吸（微弱+微旋转）
static func breathe_caster(control: Control, amplitude: float = 2.0, period: float = 2.5) -> Tween:
	var base_pos := control.position
	var tween := control.create_tween().set_loops()
	tween.tween_property(control, "position", base_pos + Vector2(0, -amplitude), period * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(control, "rotation", 0.03, period * 0.5)
	tween.tween_property(control, "position", base_pos, period * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(control, "rotation", -0.03, period * 0.5)
	tween.tween_property(control, "rotation", 0.0, period * 0.25)
	return tween


## 守卫型呼吸（微缩放）
static func breathe_guardian(control: Control, period: float = 2.2) -> Tween:
	var tween := control.create_tween().set_loops()
	tween.tween_property(control, "scale", Vector2(1.03, 0.97), period * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(control, "scale", Vector2.ONE, period * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tween


## ==========================================
## 战斗特效（对应原版 enemy-hit-flash / enemy-attack-windup 等）
## ==========================================

## 受击闪白
static func hit_flash(control: Control, duration: float = 0.15) -> void:
	var orig_mod := control.modulate
	control.modulate = Color.WHITE
	var tween := control.create_tween()
	tween.tween_property(control, "modulate", orig_mod, duration)


## 选中脉冲光晕（对应原版 dice-selected-pulse）
static func selected_pulse(control: Control, color: Color = Color.YELLOW, period: float = 1.0) -> Tween:
	var tween := control.create_tween().set_loops()
	tween.tween_property(control, "modulate", Color(color.r, color.g, color.b, 1.0), period * 0.5).set_trans(Tween.TRANS_SINE)
	tween.tween_property(control, "modulate", Color(color.r, color.g, color.b, 0.7), period * 0.5).set_trans(Tween.TRANS_SINE)
	return tween


## 毒系脉冲（对应原版 pixel-poison-pulse）
static func poison_pulse(control: Control, period: float = 1.2) -> Tween:
	var tween := control.create_tween().set_loops()
	tween.tween_property(control, "modulate", Color(0.7, 0.3, 1.0), period * 0.3).set_trans(Tween.TRANS_SINE)
	tween.tween_property(control, "modulate", Color.ONE, period * 0.7).set_trans(Tween.TRANS_SINE)
	return tween


## 火系边缘（对应原版 pixel-burn-edge）
static func burn_edge(control: Control, period: float = 1.0) -> Tween:
	var tween := control.create_tween().set_loops()
	tween.tween_property(control, "modulate", Color(1.2, 0.7, 0.3), period * 0.2).set_trans(Tween.TRANS_SINE)
	tween.tween_property(control, "modulate", Color.ONE, period * 0.8).set_trans(Tween.TRANS_SINE)
	return tween


## 治疗发光（对应原版 pixel-heal-glow）
static func heal_glow(control: Control, duration: float = 0.8) -> void:
	var tween := control.create_tween()
	tween.tween_property(control, "modulate", Color(0.5, 1.2, 0.5), duration * 0.3).set_trans(Tween.TRANS_SINE)
	tween.tween_property(control, "modulate", Color.ONE, duration * 0.7).set_trans(Tween.TRANS_SINE)


## ==========================================
## 骰子动画（对应原版 PlayerHudView 中的骰子动画）
## ==========================================

## 骰子滚动（旋转+弹跳循环）
static func dice_roll(control: Control, duration: float = 0.15) -> Tween:
	var tween := control.create_tween().set_loops()
	# 旋转
	tween.tween_property(control, "rotation", deg_to_rad(90), duration).set_trans(Tween.TRANS_LINEAR)
	tween.parallel().tween_property(control, "scale", Vector2(1.15, 1.15), duration).set_trans(Tween.TRANS_SINE)
	tween.tween_property(control, "rotation", deg_to_rad(180), duration).set_trans(Tween.TRANS_LINEAR)
	tween.parallel().tween_property(control, "scale", Vector2.ONE, duration).set_trans(Tween.TRANS_SINE)
	return tween


## 骰子出牌飞出（对应原版 playing: y: -180, opacity: 0, scale: 2, rotate: 720）
static func dice_play(control: Control, duration: float = 0.4, callback: Callable = Callable()) -> void:
	var tween := control.create_tween()
	tween.tween_property(control, "position:y", control.position.y - 180, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(control, "modulate:a", 0.0, duration)
	tween.parallel().tween_property(control, "scale", Vector2(2.0, 2.0), duration).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(control, "rotation", deg_to_rad(720), duration).set_trans(Tween.TRANS_LINEAR)
	if callback.is_valid():
		tween.tween_callback(callback)


## 骰子选中上移
static func dice_select(control: Control, duration: float = 0.12) -> void:
	var tween := control.create_tween()
	tween.tween_property(control, "position:y", control.position.y - 18, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(control, "scale", Vector2(1.12, 1.12), duration).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## 骰子取消选中
static func dice_deselect(control: Control, target_y: float, duration: float = 0.08) -> void:
	var tween := control.create_tween()
	tween.tween_property(control, "position:y", target_y, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(control, "scale", Vector2.ONE, duration).set_trans(Tween.TRANS_SINE)


## ==========================================
## 浮动文字增强（对应原版 pixel-damage-pop）
## ==========================================

## 伤害弹出 — 先放大再缩回
static func damage_pop(label: Label, duration: float = 0.3) -> void:
	label.scale = Vector2(1.5, 1.5)
	var tween := label.create_tween()
	tween.tween_property(label, "scale", Vector2(0.9, 0.9), duration * 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2.ONE, duration * 0.6).set_trans(Tween.TRANS_SINE)


## ==========================================
## Boss 出场特效（对应原版 BossEntrance.tsx）
## ==========================================

## Boss出场震动+脉冲
static func boss_entrance(node: Node, duration: float = 0.5) -> void:
	shake_heavy(node, 10.0, duration)


## WARNING 闪烁（对应原版 opacity: [1, 0.3, 1, 0.3, 1]）
static func warning_flash(control: Control, count: int = 3, period: float = 0.5) -> void:
	var tween := control.create_tween()
	for i in count:
		tween.tween_property(control, "modulate:a", 0.3, period * 0.25)
		tween.tween_property(control, "modulate:a", 1.0, period * 0.25)


## ==========================================
## 元素特效（对应原版 dice-element-* CSS动画）
## ==========================================

## 火焰发光
static func fire_glow(control: Control, period: float = 1.5) -> Tween:
	var tween := control.create_tween().set_loops()
	tween.tween_property(control, "modulate", Color(1.3, 0.8, 0.3), period * 0.3).set_trans(Tween.TRANS_SINE)
	tween.tween_property(control, "modulate", Color.ONE, period * 0.7).set_trans(Tween.TRANS_SINE)
	return tween


## 冰霜闪光
static func ice_sparkle(control: Control, period: float = 2.0) -> Tween:
	var tween := control.create_tween().set_loops()
	tween.tween_property(control, "modulate", Color(0.7, 0.9, 1.3), period * 0.2).set_trans(Tween.TRANS_SINE)
	tween.tween_property(control, "modulate", Color.ONE, period * 0.8).set_trans(Tween.TRANS_SINE)
	return tween


## 雷电闪击
static func thunder_flash(control: Control) -> void:
	control.modulate = Color(1.5, 1.5, 0.5)
	var tween := control.create_tween()
	tween.tween_property(control, "modulate", Color.ONE, 0.1)


## 暗影脉动
static func shadow_pulse(control: Control, period: float = 1.8) -> Tween:
	var tween := control.create_tween().set_loops()
	tween.tween_property(control, "modulate", Color(0.5, 0.3, 0.8), period * 0.4).set_trans(Tween.TRANS_SINE)
	tween.tween_property(control, "modulate", Color.ONE, period * 0.6).set_trans(Tween.TRANS_SINE)
	return tween


## 圣光脉冲
static func holy_pulse(control: Control, period: float = 2.0) -> Tween:
	var tween := control.create_tween().set_loops()
	tween.tween_property(control, "modulate", Color(1.2, 1.2, 0.8), period * 0.3).set_trans(Tween.TRANS_SINE)
	tween.tween_property(control, "modulate", Color.ONE, period * 0.7).set_trans(Tween.TRANS_SINE)
	return tween


## ==========================================
## 粒子效果（对应原版 ParticleEffects.tsx + CSSParticles）
## ==========================================

## 像素粒子爆发 — 在指定位置生成N个方块粒子
static func pixel_burst(parent: Control, center: Vector2, count: int = 12, colors: Array[Color] = [Color.RED, Color.ORANGE, Color.YELLOW], speed: float = 80.0, life: float = 0.5) -> void:
	for i in count:
		var p := ColorRect.new()
		var color := colors[i % colors.size()]
		p.color = color
		p.size = Vector2(3, 3)
		p.position = center
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(p)
		
		var angle := TAU * i / count + randf() * 0.3
		var vel := Vector2(cos(angle), sin(angle)) * speed * (0.5 + randf() * 0.5)
		var target := center + vel * life
		
		var tween := p.create_tween()
		tween.tween_property(p, "position", target, life).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(p, "modulate:a", 0.0, life)
		tween.tween_callback(p.queue_free)


## 治疗粒子（绿色上飘）
static func heal_burst(parent: Control, center: Vector2, count: int = 8) -> void:
	var colors: Array[Color] = [Color.GREEN, Color(0.5, 1.0, 0.3), Color(0.3, 0.8, 0.3)]
	for i in count:
		var p := ColorRect.new()
		p.color = colors[i % colors.size()]
		p.size = Vector2(3, 3)
		p.position = center + Vector2(randf_range(-15, 15), randf_range(-5, 5))
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(p)
		
		var tween := p.create_tween()
		tween.tween_property(p, "position:y", p.position.y - 40, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(p, "modulate:a", 0.0, 0.8)
		tween.tween_callback(p.queue_free)


## 金币粒子（金色上飘）
static func coin_burst(parent: Control, center: Vector2, count: int = 6) -> void:
	var colors: Array[Color] = [Color(1.0, 0.85, 0.3), Color(1.0, 0.7, 0.2), Color.WHITE]
	for i in count:
		var p := ColorRect.new()
		p.color = colors[i % colors.size()]
		p.size = Vector2(2, 2)
		p.position = center + Vector2(randf_range(-10, 10), 0)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(p)
		
		var tween := p.create_tween()
		tween.tween_property(p, "position:y", p.position.y - 50, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(p, "modulate:a", 0.0, 1.0)
		tween.tween_callback(p.queue_free)


## 毒系粒子（紫色下滴）
static func poison_drip(parent: Control, center: Vector2, count: int = 4) -> void:
	for i in count:
		var p := ColorRect.new()
		p.color = Color(0.6, 0.2, 0.8)
		p.size = Vector2(2, 3)
		p.position = center + Vector2(randf_range(-12, 12), -5)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(p)
		
		var delay := i * 0.2 + randf() * 0.3
		var tween := p.create_tween()
		tween.tween_interval(delay)
		tween.tween_property(p, "position:y", p.position.y + 20, 0.6).set_trans(Tween.TRANS_SINE)
		tween.parallel().tween_property(p, "modulate:a", 0.0, 0.6)
		tween.tween_callback(p.queue_free)


## 胜利粒子（多色爆发+重力下落）
static func victory_burst(parent: Control, center: Vector2, count: int = 15) -> void:
	var colors: Array[Color] = [
		Color(1.0, 0.85, 0.3), Color.RED, Color.CYAN,
		Color(0.6, 0.2, 0.8), Color.GREEN, Color.WHITE
	]
	for i in count:
		var p := ColorRect.new()
		p.color = colors[i % colors.size()]
		var size := randi_range(3, 6)
		p.size = Vector2(size, size)
		p.position = center + Vector2(randf_range(-20, 20), randf_range(-10, 10))
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(p)
		
		var angle := -PI / 2 + randf_range(-PI * 0.7, PI * 0.7)
		var speed := randf_range(60, 120)
		var life := randf_range(0.8, 1.5)
		var vx := cos(angle) * speed
		var vy_start := sin(angle) * speed
		var target_x := p.position.x + vx * life
		var target_y := p.position.y + vy_start * life + 0.5 * 100 * life * life  # 重力
		
		var tween := p.create_tween()
		tween.tween_property(p, "position", Vector2(target_x, target_y), life).set_trans(Tween.TRANS_SINE)
		tween.parallel().tween_property(p, "modulate:a", 0.0, life).set_trans(Tween.TRANS_LINEAR)
		tween.tween_callback(p.queue_free)


## ==========================================
## 环境效果（对应原版 ForestBattle/IceBattle/ShadowBattle 等）
## ==========================================

## 星星闪烁（对应原版 star-twinkle）
static func star_twinkle(control: Control, period: float = 3.0) -> Tween:
	var tween := control.create_tween().set_loops()
	tween.tween_property(control, "modulate:a", 0.3, period * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(control, "modulate:a", 1.0, period * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tween


## 萤火虫浮动（对应原版 firefly-float）
static func firefly_float(control: Control, period: float = 4.0, amplitude: float = 8.0) -> Tween:
	var base_pos := control.position
	var tween := control.create_tween().set_loops()
	tween.tween_property(control, "position", base_pos + Vector2(randf_range(-amplitude, amplitude), -amplitude), period * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(control, "position", base_pos + Vector2(randf_range(-amplitude, amplitude), amplitude), period * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tween


## ==========================================
## 工具函数
## ==========================================

## 停止节点上所有 Tween
static func stop_all(node: Node) -> void:
	for child in node.get_children():
		if child is Tween:
			child.kill()

## 安全移除节点（先淡出再删除）
static func safe_remove(control: Control, duration: float = 0.2) -> void:
	if not is_instance_valid(control):
		return
	var tween := control.create_tween()
	tween.tween_property(control, "modulate:a", 0.0, duration)
	tween.tween_property(control, "scale", Vector2.ZERO, duration * 0.5)
	tween.tween_callback(control.queue_free)
