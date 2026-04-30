## 像素渲染器 — 将像素矩阵数据绘制到 Godot 控件上
## 对应原版 PixelSprite.tsx + PixelIcons.tsx 的 box-shadow 绘制体系
## 在 Godot 中用 ColorRect 网格替代 box-shadow

class_name PixelRenderer

## 在父容器中绘制像素网格，返回创建的节点数量
static func draw_pixels(parent: Control, pixels: Array, pixel_size: int = 4) -> int:  # [RULES-B2-EXEMPT] 嵌套 Array 无法 typed
	var count := 0
	for row in pixels.size():
		var row_data: Array = pixels[row]
		for col in row_data.size():
			var color_str: String = str(row_data[col])
			if color_str == "" or color_str.is_empty():
				continue
			var cr := ColorRect.new()
			cr.color = Color.from_string(color_str, Color.TRANSPARENT)
			cr.position = Vector2(col * pixel_size, row * pixel_size)
			cr.size = Vector2(pixel_size, pixel_size)
			cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			parent.add_child(cr)
			count += 1
	return count


## 清除父容器中的所有像素子节点
static func clear_pixels(parent: Control) -> void:
	for child in parent.get_children():
		if child is ColorRect:
			child.queue_free()


## 创建一个带像素精灵的容器
static func create_sprite_container(sprite_data: Dictionary, pixel_size: int = 4) -> Control:
	var container := Control.new()
	var w: int = sprite_data.get("width", 8)
	var h: int = sprite_data.get("height", 8)
	container.custom_minimum_size = Vector2(w * pixel_size, h * pixel_size)
	container.size = Vector2(w * pixel_size, h * pixel_size)
	draw_pixels(container, sprite_data.get("pixels", []), pixel_size)
	return container


## 在已有容器上绘制精灵（先清空再绘制）
static func render_sprite(container: Control, sprite_data: Dictionary, pixel_size: int = 4) -> void:
	clear_pixels(container)
	var w: int = sprite_data.get("width", 8)
	var h: int = sprite_data.get("height", 8)
	container.custom_minimum_size = Vector2(w * pixel_size, h * pixel_size)
	draw_pixels(container, sprite_data.get("pixels", []), pixel_size)
