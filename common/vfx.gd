## 动画引擎 — 全局静音版本（2026-04-24 刘叔要求全关，便于 bug 排查）
## ============================================================
## 【重要】本文件处于"动画禁用模式"：
## - 所有 VFX.xxx 调用保留原函数签名，但不产生任何视觉动画
## - 需要立刻到位的终态（可见性 / 位置 / 缩放 / 颜色）仍然正确设置
## - 粒子函数不再生成 ColorRect（减少节点开销）
## - 返回 Tween 的函数统一返回 null；调用方用 `if tw:` 判空接受
## ============================================================
## 【恢复动画】把 ANIMATIONS_ENABLED 改成 true 并回滚本文件即可（Git 历史）
## ============================================================

class_name VFX

const ANIMATIONS_ENABLED: bool = false

## ==========================================
## 屏幕震动
## ==========================================

static func shake(_node: Node, _intensity: float = 8.0, _duration: float = 0.3, _decay: bool = true) -> void:
	pass


static func shake_heavy(_node: Node, _intensity: float = 12.0, _duration: float = 0.5) -> void:
	pass


## ==========================================
## 淡入淡出 — 终态必须正确（否则 UI 不可见）
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
## 缩放动画 — 终态 scale=1、可见
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


## ==========================================
## 滑动动画 — 保持原位、立刻显示（不再位移）
## ==========================================

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
## 循环类脉冲/呼吸 — 返回 null；调用方需要判空
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
## 战斗特效
## ==========================================

static func hit_flash(_control: Control, _duration: float = 0.15) -> void:
	pass


static func selected_pulse(_control: Control, _color: Color = Color.YELLOW, _period: float = 1.0) -> Tween:
	return null


static func poison_pulse(_control: Control, _period: float = 1.2) -> Tween:
	return null


static func burn_edge(_control: Control, _period: float = 1.0) -> Tween:
	return null


static func heal_glow(_control: Control, _duration: float = 0.8) -> void:
	pass


## ==========================================
## 骰子动画 — dice_roll / dice_select / dice_deselect / dice_play
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
## 浮动文字增强
## ==========================================

static func damage_pop(label: Label, _duration: float = 0.3) -> void:
	if not is_instance_valid(label):
		return
	label.scale = Vector2.ONE


## ==========================================
## Boss 出场 / Warning
## ==========================================

static func boss_entrance(_node: Node, _duration: float = 0.5) -> void:
	pass


static func warning_flash(_control: Control, _count: int = 3, _period: float = 0.5) -> void:
	pass


## ==========================================
## 元素特效（骰子上的循环光晕）
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
## 粒子效果 — 全部 no-op（不生成 ColorRect）
## ==========================================

static func pixel_burst(_parent: Node, _center: Vector2, _count: int = 12, _colors: Array[Color] = [Color.RED, Color.ORANGE, Color.YELLOW], _speed: float = 80.0, _life: float = 0.5) -> void:
	pass


static func heal_burst(_parent: Node, _center: Vector2, _count: int = 8) -> void:
	pass


static func coin_burst(_parent: Node, _center: Vector2, _count: int = 6) -> void:
	pass


static func poison_drip(_parent: Node, _center: Vector2, _count: int = 4) -> void:
	pass


static func victory_burst(_parent: Node, _center: Vector2, _count: int = 15) -> void:
	pass


## ==========================================
## 环境循环 — 返回 null
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
