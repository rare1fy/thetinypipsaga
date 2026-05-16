## 死亡过渡动画 — 玩家致命一击后的演出
## 时序（总 840ms）：
##   1. (0-420ms) 屏幕抖动 2 拍
##   2. (420-720ms) 失重坠落
##   3. (720-840ms) 黑幕 fade 满 → 立刻切 GameOverScreen
##
## 用法: DeathTransition.play(parent_node, on_complete_callable)

class_name DeathTransition
extends CanvasLayer

const SHAKE_MS: float = 420.0
const FALL_MS: float = 300.0
const FADE_MS: float = 120.0
const TOTAL_MS: float = SHAKE_MS + FALL_MS + FADE_MS  # 840

var _on_complete: Callable = Callable()


static func play(parent: Node, on_complete: Callable = Callable()) -> DeathTransition:
	var instance := DeathTransition.new()
	instance._on_complete = on_complete
	parent.add_child(instance)
	return instance


func _ready() -> void:
	layer = 95
	_build_and_animate()


func _build_and_animate() -> void:
	# 黑幕（最终 fade 满）
	var black_rect := ColorRect.new()
	black_rect.color = Color(0, 0, 0, 0)
	black_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(black_rect)

	# 红色闪烁叠加层
	var red_flash := ColorRect.new()
	red_flash.color = Color(0.8, 0.1, 0.1, 0)
	red_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(red_flash)

	var tw := create_tween()

	# 阶段 1：屏幕抖动 + 红色闪烁
	tw.tween_callback(func():
		_shake_screen()
	)
	tw.parallel().tween_property(red_flash, "color:a", 0.4, 0.1)
	tw.tween_property(red_flash, "color:a", 0.0, 0.3)

	# 阶段 2：坠落感（画面下移 + 缩小）
	tw.tween_interval(SHAKE_MS / 1000.0 - 0.4)  # 等待抖动结束
	tw.tween_callback(func():
		var viewport := get_viewport()
		if viewport:
			var canvas := viewport.canvas_transform
			var fall_tw := create_tween()
			fall_tw.tween_method(func(t: float) -> void:
				var offset_y: float = t * 320.0
				viewport.canvas_transform = canvas.translated(Vector2(0, offset_y))
			, 0.0, 1.0, FALL_MS / 1000.0).set_ease(Tween.EASE_IN)
	)

	# 阶段 3：黑幕 fade
	tw.tween_interval(FALL_MS / 1000.0)
	tw.tween_property(black_rect, "color:a", 1.0, FADE_MS / 1000.0)

	# 完成回调
	tw.tween_callback(func():
		# 恢复 canvas_transform
		var viewport := get_viewport()
		if viewport:
			viewport.canvas_transform = Transform2D.IDENTITY
		if _on_complete.is_valid():
			_on_complete.call()
		queue_free()
	)


func _shake_screen() -> void:
	var viewport := get_viewport()
	if not viewport:
		return
	var original := viewport.canvas_transform
	var shake_tw := create_tween()
	var shake_count: int = 4
	var shake_duration: float = SHAKE_MS / 1000.0 / float(shake_count * 2)
	var intensity: float = 6.0

	for i: int in range(shake_count):
		var offset_x: float = intensity * (1.0 if i % 2 == 0 else -1.0)
		shake_tw.tween_callback(func() -> void:
			viewport.canvas_transform = original.translated(Vector2(offset_x, 0))
		)
		shake_tw.tween_interval(shake_duration)
		shake_tw.tween_callback(func() -> void:
			viewport.canvas_transform = original.translated(Vector2(-offset_x, 0))
		)
		shake_tw.tween_interval(shake_duration)

	shake_tw.tween_callback(func() -> void:
		viewport.canvas_transform = original
	)
