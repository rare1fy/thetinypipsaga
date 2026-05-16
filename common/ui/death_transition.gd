## 死亡过渡动画 — 玩家致命一击后的演出
## 时序（总 840ms）：
##   1. (0-420ms) 屏幕抖动 2 拍 + 红色闪烁
##   2. (420-720ms) 失重坠落
##   3. (720-840ms) 黑幕 fade 满 → 立刻切 GameOverScreen
##
## 用法: DeathTransition.play(parent_node, on_complete_callable)

class_name DeathTransition
extends CanvasLayer

const SHAKE_DURATION: float = 0.42
const FALL_DURATION: float = 0.30
const FADE_DURATION: float = 0.12

var _on_complete: Callable = Callable()


static func play(parent: Node, on_complete: Callable = Callable()) -> DeathTransition:
	var instance := DeathTransition.new()
	instance._on_complete = on_complete
	parent.add_child(instance)
	return instance


func _ready() -> void:
	layer = 95
	_animate()


func _animate() -> void:
	# 黑幕
	var black_rect := ColorRect.new()
	black_rect.color = Color(0, 0, 0, 0)
	black_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(black_rect)

	# 红色闪烁叠加层
	var red_flash := ColorRect.new()
	red_flash.color = Color(0.8, 0.1, 0.1, 0)
	red_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(red_flash)

	var viewport := get_viewport()
	var original_transform: Transform2D = viewport.canvas_transform if viewport else Transform2D.IDENTITY

	# 单一 Tween 序列，避免并发竞态
	var tw := create_tween()

	# 阶段 1：红色闪烁 + 屏幕抖动（串行在同一 Tween 中）
	tw.tween_property(red_flash, "color:a", 0.5, 0.08)
	tw.tween_property(red_flash, "color:a", 0.0, 0.12)

	# 抖动：4 次交替偏移
	var shake_step: float = SHAKE_DURATION / 8.0
	var intensity: float = 6.0
	for i: int in range(4):
		var offset_x: float = intensity * (1.0 if i % 2 == 0 else -1.0)
		tw.tween_callback(func() -> void:
			if viewport:
				viewport.canvas_transform = original_transform.translated(Vector2(offset_x, 0))
		)
		tw.tween_interval(shake_step)
		tw.tween_callback(func() -> void:
			if viewport:
				viewport.canvas_transform = original_transform.translated(Vector2(-offset_x, 0))
		)
		tw.tween_interval(shake_step)

	# 抖动结束，恢复原位
	tw.tween_callback(func() -> void:
		if viewport:
			viewport.canvas_transform = original_transform
	)

	# 阶段 2：坠落（画面下移）
	tw.tween_method(func(t: float) -> void:
		if viewport:
			viewport.canvas_transform = original_transform.translated(Vector2(0, t * 320.0))
	, 0.0, 1.0, FALL_DURATION).set_ease(Tween.EASE_IN)

	# 阶段 3：黑幕 fade
	tw.tween_property(black_rect, "color:a", 1.0, FADE_DURATION)

	# 完成：恢复 canvas_transform + 回调
	tw.tween_callback(func() -> void:
		if viewport:
			viewport.canvas_transform = Transform2D.IDENTITY
		if _on_complete.is_valid():
			_on_complete.call()
		queue_free()
	)
