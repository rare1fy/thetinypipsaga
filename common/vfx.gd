## 动画引擎 — 精选实现版（2026-04-24 VFX 三件套）
## ============================================================
## 本文件策略：
## 1. 关键战斗 VFX（震屏 / 受击闪烁 / 粒子 / 血条脉冲）真实实现
## 2. 装饰类 VFX（呼吸 / 循环光晕 / 淡入淡出）保持 no-op，仅设置终态
## 3. 粒子统一用 CPUParticles2D 创建（兼容 Compatibility 渲染器）
## 4. 所有函数保留原签名，调用方无需改动
## ============================================================
## 【关闭】把 ANIMATIONS_ENABLED 改成 false 即可让所有函数全部静音
## ============================================================

class_name VFX

const ANIMATIONS_ENABLED: bool = true

## ==========================================
## 屏幕震动 — 真实实现（修改节点 position 抖动再回归）
## ==========================================

static func shake(node: Node, intensity: float = 8.0, duration: float = 0.3, _decay: bool = true) -> void:
	if not ANIMATIONS_ENABLED:
		return
	if not is_instance_valid(node):
		return
	var target: CanvasItem = node as CanvasItem
	if target == null:
		return
	_do_shake(target, intensity, duration)


static func shake_heavy(node: Node, intensity: float = 12.0, duration: float = 0.5) -> void:
	shake(node, intensity, duration)


static func _do_shake(target: CanvasItem, intensity: float, duration: float) -> void:
	# Control 用 pivot_offset 偏移（不影响锚点布局）；Node2D 用 position 偏移
	var use_pivot: bool = target is Control
	var origin: Vector2
	var prop: String
	
	if use_pivot:
		var ctrl: Control = target as Control
		origin = ctrl.pivot_offset
		prop = "pivot_offset"
		ctrl.pivot_offset = ctrl.size * 0.5  # 先设到中心
		origin = ctrl.pivot_offset  # 再读更新后的值
	else:
		origin = (target as Node2D).position
		prop = "position"
	
	var tw := target.create_tween()
	var steps := int(maxf(duration / 0.04, 4.0))
	for i in range(steps):
		var decay := 1.0 - float(i) / float(steps)
		var offset := Vector2(
			randf_range(-intensity, intensity) * decay,
			randf_range(-intensity, intensity) * decay
		)
		tw.tween_property(target, prop, origin + offset, 0.04)
	tw.tween_property(target, prop, origin, 0.04)


## ==========================================
## 淡入淡出 — 终态设置（无动画）
## ==========================================

static func fade_in(control: CanvasItem, _duration: float = 0.25, _delay: float = 0.0) -> void:
	if not is_instance_valid(control):
		return
	control.modulate.a = 1.0
	control.visible = true


static func fade_out(control: CanvasItem, _duration: float = 0.25, callback: Callable = Callable()) -> void:
	if not is_instance_valid(control):
		return
	control.modulate.a = 0.0
	if callback.is_valid():
		callback.call()
	else:
		control.visible = false


static func flash_overlay(control: Control, _color: Color = Color.RED, _duration: float = 0.3) -> void:
	if not is_instance_valid(control):
		return
	control.visible = false
	control.modulate.a = 0.0


## ==========================================
## 缩放动画 — 终态 scale=1
## ==========================================

static func pop_in(control: Control, _duration: float = 0.4, _delay: float = 0.0, _overshoot: float = 1.2) -> void:
	if not is_instance_valid(control):
		return
	control.scale = Vector2.ONE
	control.modulate.a = 1.0
	control.visible = true


static func pop_out(control: Control, _duration: float = 0.25, callback: Callable = Callable()) -> void:
	if not is_instance_valid(control):
		return
	control.scale = Vector2.ZERO
	if callback.is_valid():
		callback.call()


static func spring_scale(control: Control, target: Vector2, _duration: float = 0.3, _stiffness: float = 300.0) -> void:
	if not is_instance_valid(control):
		return
	control.scale = target


static func slide_in_from_bottom(control: Control, _distance: float = 30.0, _duration: float = 0.3, _delay: float = 0.0) -> void:
	if not is_instance_valid(control):
		return
	control.modulate.a = 1.0
	control.visible = true


static func slide_in_from_top(control: Control, _distance: float = 30.0, _duration: float = 0.3, _delay: float = 0.0) -> void:
	if not is_instance_valid(control):
		return
	control.modulate.a = 1.0
	control.visible = true


static func slide_in_from_left(control: Control, _distance: float = 30.0, _duration: float = 0.3, _delay: float = 0.0) -> void:
	if not is_instance_valid(control):
		return
	control.modulate.a = 1.0
	control.visible = true


## ==========================================
## 循环类脉冲/呼吸 — 暂保持 null（v0.1 不做）
## ==========================================

static func breathe(_control: Control, _amplitude: float = 3.0, _period: float = 2.0) -> Tween:
	return null


static func breathe_warrior(_control: Control, _amplitude: float = 5.0, _period: float = 1.8) -> Tween:
	return null


static func breathe_caster(_control: Control, _amplitude: float = 2.0, _period: float = 2.5) -> Tween:
	return null


static func breathe_guardian(_control: Control, _period: float = 2.2) -> Tween:
	return null


## ==========================================
## 战斗特效 — 受击闪烁真实实现
## ==========================================

static func hit_flash(control: Control, duration: float = 0.15) -> void:
	if not ANIMATIONS_ENABLED:
		return
	if not is_instance_valid(control):
		return
	var original_mod := control.modulate
	var tw := control.create_tween()
	tw.tween_property(control, "modulate", Color(2.0, 2.0, 2.0, original_mod.a), duration * 0.4)
	tw.tween_property(control, "modulate", original_mod, duration * 0.6)


static func selected_pulse(_control: Control, _color: Color = Color.YELLOW, _period: float = 1.0) -> Tween:
	return null


static func poison_pulse(_control: Control, _period: float = 1.2) -> Tween:
	return null


static func burn_edge(_control: Control, _period: float = 1.0) -> Tween:
	return null


static func heal_glow(control: Control, duration: float = 0.8) -> void:
	if not ANIMATIONS_ENABLED:
		return
	if not is_instance_valid(control):
		return
	var original_mod := control.modulate
	var tw := control.create_tween()
	tw.tween_property(control, "modulate", Color(0.6, 1.8, 0.6, original_mod.a), duration * 0.3)
	tw.tween_property(control, "modulate", original_mod, duration * 0.7)


## ==========================================
## 骰子动画 — 保持 no-op
## ==========================================

static func dice_roll(_control: Control, _duration: float = 0.15) -> Tween:
	return null


static func dice_play(control: Control, _duration: float = 0.4, callback: Callable = Callable()) -> void:
	if not is_instance_valid(control):
		return
	control.modulate.a = 0.0
	if callback.is_valid():
		callback.call()


static func dice_select(_control: Control, _duration: float = 0.12) -> void:
	pass


static func dice_deselect(control: Control, target_y: float, _duration: float = 0.08) -> void:
	if not is_instance_valid(control):
		return
	control.position.y = target_y
	control.scale = Vector2.ONE


## ==========================================
## 浮动文字 — 多样式飘字真实实现
## type: "damage" / "crit" / "heal" / "armor" / "combo" / "status"
## ==========================================

## 伤害飘字（红色，向上飘升淡出）
static func damage_pop(label: Label, duration: float = 0.8) -> void:
	_floating_pop(label, duration, Color("#f07050"), Vector2(1.3, 1.3), Vector2(0, -50))


## 暴击飘字（橙红，更大缩放+更长停留）
static func crit_pop(label: Label, duration: float = 1.0) -> void:
	_floating_pop(label, duration, Color("#ff4020"), Vector2(1.8, 1.8), Vector2(0, -60))


## 治疗飘字（绿色，温和上飘）
static func heal_pop(label: Label, duration: float = 0.7) -> void:
	_floating_pop(label, duration, Color("#50e880"), Vector2(1.1, 1.1), Vector2(0, -35))


## 护甲飘字（蓝色，短距上飘）
static func armor_pop(label: Label, duration: float = 0.6) -> void:
	_floating_pop(label, duration, Color("#60a0f0"), Vector2(1.0, 1.0), Vector2(0, -30))


## Combo 连击飘字（金色，弹性缩放+横向抖动）
static func combo_pop(label: Label, hit_count: int, duration: float = 0.9) -> void:
	if not ANIMATIONS_ENABLED:
		return
	if not is_instance_valid(label):
		return
	var start_pos := label.position
	label.modulate.a = 1.0
	# combo 数字越大，缩放和抖动越强
	var intensity := mini(hit_count, 5)
	var scale_target := Vector2(1.0 + 0.15 * intensity, 1.0 + 0.15 * intensity)
	label.scale = scale_target * 1.3
	label.add_theme_color_override("font_color", Color("#f0c850"))
	var tw := label.create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "position", start_pos + Vector2(randf_range(-8, 8), -55), duration * 0.6)
	tw.tween_property(label, "scale", scale_target, duration * 0.3)
	tw.chain().tween_property(label, "modulate:a", 0.0, duration * 0.4)


## 状态飘字（紫色，短距上飘）
static func status_pop(label: Label, duration: float = 0.6) -> void:
	_floating_pop(label, duration, Color("#c080f0"), Vector2(1.0, 1.0), Vector2(0, -30))


## 飘字通用实现（类型特化函数的底层）
static func _floating_pop(label: Label, duration: float, color: Color, start_scale: Vector2, drift: Vector2) -> void:
	if not ANIMATIONS_ENABLED:
		return
	if not is_instance_valid(label):
		return
	var start_pos := label.position
	label.modulate.a = 1.0
	label.scale = start_scale
	label.add_theme_color_override("font_color", color)
	var tw := label.create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "position", start_pos + drift, duration)
	tw.tween_property(label, "scale", Vector2(1.0, 1.0), duration * 0.3)
	tw.chain().tween_property(label, "modulate:a", 0.0, duration * 0.4)


## ==========================================
## 飘字工厂 — 在指定父节点上创建飘字 Label 并自动播放动画后销毁
## ==========================================

## 在 target 位置创建伤害飘字
static func spawn_damage_text(parent: Node, pos: Vector2, damage: int, is_crit: bool = false) -> void:
	if not ANIMATIONS_ENABLED:
		return
	if damage <= 0:
		return  # 0 伤害不生成飘字
	var label := _create_floating_label(parent, pos, str(damage), 22 if is_crit else 18)
	if is_crit:
		crit_pop(label)
	else:
		damage_pop(label)


## 在 target 位置创建治疗飘字
static func spawn_heal_text(parent: Node, pos: Vector2, amount: int) -> void:
	if not ANIMATIONS_ENABLED:
		return
	if amount <= 0:
		return
	var label := _create_floating_label(parent, pos, "+%d" % amount, 16)
	heal_pop(label)


## 在 target 位置创建护甲飘字
static func spawn_armor_text(parent: Node, pos: Vector2, amount: int) -> void:
	if not ANIMATIONS_ENABLED:
		return
	if amount <= 0:
		return
	var label := _create_floating_label(parent, pos, "🛡+%d" % amount, 14)
	armor_pop(label)


## 在 target 位置创建 combo 飘字
static func spawn_combo_text(parent: Node, pos: Vector2, hit_count: int) -> void:
	if not ANIMATIONS_ENABLED:
		return
	if hit_count <= 0:
		return
	var label := _create_floating_label(parent, pos, "COMBO x%d!" % hit_count, 20)
	combo_pop(label, hit_count)


## 在 target 位置创建状态/提示文本飘字（通用文本飘字，CH6 盗贼连击钩子等使用）
static func spawn_status_text(parent: Node, pos: Vector2, text: String, font_size: int = 16) -> void:
	if not ANIMATIONS_ENABLED:
		return
	if text.is_empty():
		return
	var label := _create_floating_label(parent, pos, text, font_size)
	heal_pop(label)


## 创建飘字 Label 节点（设置基础样式，定位到指定位置）
## pos 为全局/屏幕坐标。通过设置 label.global_position 直接定位。
## 居中逻辑：依赖 Label 自身测量后的实际宽度，消除硬编码偏移
static func _create_floating_label(parent: Node, pos: Vector2, text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)
	parent.add_child(label)
	# 强制测量后用实际尺寸居中，避免硬编码偏移造成偏右
	label.reset_size()
	var offset: Vector2 = Vector2(label.size.x * 0.5, 0)
	label.global_position = pos - offset
	label.z_index = 100
	# [FIX-Lambda] 动画结束后自动销毁 — 用 WeakRef 包裹避免 "Lambda capture was freed"
	var label_wr: WeakRef = weakref(label)
	label.get_tree().create_timer(1.5).timeout.connect(func() -> void:
		var lbl: Label = label_wr.get_ref() as Label
		if is_instance_valid(lbl):
			lbl.queue_free()
	)
	return label


## ==========================================
## Boss 出场 / Warning — no-op
## ==========================================

static func boss_entrance(_node: Node, _duration: float = 0.5) -> void:
	pass


static func warning_flash(_control: Control, _count: int = 3, _period: float = 0.5) -> void:
	pass


## ==========================================
## 元素特效 — no-op（循环光晕暂不做）
## ==========================================

static func fire_glow(_control: Control, _period: float = 1.5) -> Tween:
	return null


static func ice_sparkle(_control: Control, _period: float = 2.0) -> Tween:
	return null


static func thunder_flash(_control: Control) -> void:
	pass


static func shadow_pulse(_control: Control, _period: float = 1.8) -> Tween:
	return null


static func holy_pulse(_control: Control, _period: float = 2.0) -> Tween:
	return null


## ==========================================
## 粒子效果 — CPUParticles2D 真实实现
## ==========================================

static func pixel_burst(parent: Node, center: Vector2, count: int = 12, colors: Array[Color] = [Color.RED, Color.ORANGE, Color.YELLOW], speed: float = 80.0, life: float = 0.5) -> void:
	if not ANIMATIONS_ENABLED:
		return
	if not is_instance_valid(parent):
		return
	_spawn_particles(parent, center, count, colors, speed, life, 0.0)


static func heal_burst(parent: Node, center: Vector2, count: int = 8) -> void:
	if not ANIMATIONS_ENABLED:
		return
	var colors: Array[Color] = [Color(0.4, 1.0, 0.5), Color(0.6, 1.0, 0.8), Color.WHITE]
	_spawn_particles(parent, center, count, colors, 60.0, 0.7, -60.0)


static func coin_burst(parent: Node, center: Vector2, count: int = 6) -> void:
	if not ANIMATIONS_ENABLED:
		return
	var colors: Array[Color] = [Color(1.0, 0.85, 0.2), Color(1.0, 0.9, 0.4)]
	_spawn_particles(parent, center, count, colors, 90.0, 0.6, 40.0)


static func poison_drip(parent: Node, center: Vector2, count: int = 4) -> void:
	if not ANIMATIONS_ENABLED:
		return
	var colors: Array[Color] = [Color(0.5, 1.0, 0.3), Color(0.4, 0.8, 0.2)]
	_spawn_particles(parent, center, count, colors, 30.0, 0.8, 80.0)


static func victory_burst(parent: Node, center: Vector2, count: int = 15) -> void:
	if not ANIMATIONS_ENABLED:
		return
	var colors: Array[Color] = [Color(1.0, 0.9, 0.3), Color(1.0, 0.6, 0.2), Color(0.9, 0.3, 0.3), Color.WHITE]
	_spawn_particles(parent, center, count, colors, 120.0, 0.9, -40.0)


## 五元素击中粒子（P1 新增）
## element: "fire" / "ice" / "thunder" / "poison" / "holy" / "physical"
static func spawn_element_hit(parent: Node, center: Vector2, element: String, count: int = 10) -> void:
	if not ANIMATIONS_ENABLED:
		return
	var colors := _element_palette(element)
	var speed := 90.0 if element == "thunder" else 70.0
	_spawn_particles(parent, center, count, colors, speed, 0.55, 0.0)


static func _element_palette(element: String) -> Array[Color]:
	match element:
		"fire":
			return [Color(1.0, 0.5, 0.15), Color(1.0, 0.85, 0.25), Color(0.95, 0.3, 0.1)]
		"ice":
			return [Color(0.55, 0.85, 1.0), Color(0.8, 0.95, 1.0), Color.WHITE]
		"thunder":
			return [Color(1.0, 1.0, 0.5), Color(0.7, 0.7, 1.0), Color.WHITE]
		"poison":
			return [Color(0.5, 1.0, 0.35), Color(0.35, 0.8, 0.2)]
		"holy":
			return [Color(1.0, 0.95, 0.6), Color.WHITE, Color(1.0, 1.0, 0.8)]
		_:
			return [Color(1.0, 0.8, 0.3), Color.WHITE, Color(1.0, 0.6, 0.3)]


static func _spawn_particles(parent: Node, center: Vector2, count: int, colors: Array[Color], speed: float, life: float, gravity_y: float) -> void:
	if colors.is_empty():
		return
	var p := CPUParticles2D.new()
	p.position = center
	p.emitting = false
	p.one_shot = true
	p.amount = count
	p.lifetime = life
	p.explosiveness = 0.85
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.6
	p.initial_velocity_max = speed
	p.gravity = Vector2(0, gravity_y)
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.0
	p.color = colors[0]
	parent.add_child(p)
	p.emitting = true
	# [FIX-Lambda] 粒子结束后自销毁 — 用 WeakRef 包裹避免 "Lambda capture was freed"
	var cleanup_time: float = life + 0.3
	var p_wr: WeakRef = weakref(p)
	p.get_tree().create_timer(cleanup_time).timeout.connect(func() -> void:
		var particle: CPUParticles2D = p_wr.get_ref() as CPUParticles2D
		if is_instance_valid(particle):
			particle.queue_free()
	)


## ==========================================
## 血条脉冲（P1 新增，命名 hp_pulse）
## 适用：ProgressBar / TextureProgressBar / Control 受击时 modulate 闪红
## ==========================================

static func hp_pulse(bar: Control, is_damage: bool = true) -> void:
	if not ANIMATIONS_ENABLED:
		return
	if not is_instance_valid(bar):
		return
	var original := bar.modulate
	var flash_color := Color(1.8, 0.6, 0.6, original.a) if is_damage else Color(0.6, 1.6, 0.8, original.a)
	var tw := bar.create_tween()
	tw.tween_property(bar, "modulate", flash_color, 0.08)
	tw.tween_property(bar, "modulate", original, 0.25)


## ==========================================
## 环境循环 — no-op
## ==========================================

static func star_twinkle(_control: Control, _period: float = 3.0) -> Tween:
	return null


static func firefly_float(_control: Control, _period: float = 4.0, _amplitude: float = 8.0) -> Tween:
	return null


## ==========================================
## 工具函数
## ==========================================

static func stop_all(_node: Node) -> void:
	pass


static func safe_remove(control: Control, _duration: float = 0.2) -> void:
	if not is_instance_valid(control):
		return
	control.queue_free()


## ==========================================
## Toast 提示 — 转发到 GameManager.toast_requested 信号
## ToastManager 单例监听后会从屏幕底部冒出消息条
## type: "info" / "buff" / "damage" / "warn" / "error" / "success"
## ==========================================
static func show_toast(text: String, toast_type: String = "info") -> void:
	if Engine.has_singleton("GameManager"):
		Engine.get_singleton("GameManager").toast_requested.emit(text, toast_type)
	else:
		# Autoload 用 get_tree 拿
		var tree := Engine.get_main_loop() as SceneTree
		if tree and tree.root.has_node("GameManager"):
			var gm := tree.root.get_node("GameManager")
			if gm.has_signal("toast_requested"):
				gm.toast_requested.emit(text, toast_type)
				return
		print("[Toast][%s] %s" % [toast_type, text])
