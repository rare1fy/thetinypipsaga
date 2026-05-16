## Boss 入场演出 — 全屏暗幕 + 像素警告横条 + Boss名号 + 闪烁
## 用法: BossEntrance.play(parent_node, boss_name, chapter, is_final)

class_name BossEntrance
extends CanvasLayer

const CHAPTER_COLORS: Dictionary = {
	1: Color("c8403c"),  # 幽暗森林
	2: Color("68a0e8"),  # 冰封山脉
	3: Color("f0a040"),  # 熔岩深渊
	4: Color("b068e8"),  # 暗影要塞
	5: Color("e8d068"),  # 永恒之巅
}

const CHAPTER_SUBTITLES: Dictionary = {
	1: "幽暗森林之主",
	2: "冰封山脉之王",
	3: "熔岩深渊守卫",
	4: "暗影要塞领主",
	5: "永恒之巅主宰",
}

var _boss_name: String = ""
var _chapter: int = 1
var _is_final: bool = false
var _on_complete: Callable = Callable()


static func play(parent: Node, boss_name: String, chapter: int, is_final: bool = false, on_complete: Callable = Callable()) -> BossEntrance:
	var instance := BossEntrance.new()
	instance._boss_name = boss_name
	instance._chapter = chapter
	instance._is_final = is_final
	instance._on_complete = on_complete
	parent.add_child(instance)
	return instance


func _ready() -> void:
	layer = 90
	_build_ui()
	_animate()


func _build_ui() -> void:
	var accent: Color = CHAPTER_COLORS.get(_chapter, Color("c8403c"))
	if _is_final:
		accent = Color("f0c040")

	# 全屏暗幕
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.01, 0.03, 0.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# 警告横条
	var warning_bar := ColorRect.new()
	warning_bar.color = Color(accent, 0.8)
	warning_bar.custom_minimum_size = Vector2(0, 4)
	warning_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	warning_bar.offset_top = 200
	warning_bar.offset_bottom = 204
	add_child(warning_bar)

	var warning_bar2 := ColorRect.new()
	warning_bar2.color = Color(accent, 0.8)
	warning_bar2.custom_minimum_size = Vector2(0, 4)
	warning_bar2.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	warning_bar2.offset_top = 360
	warning_bar2.offset_bottom = 364
	add_child(warning_bar2)

	# 中央容器
	var center := VBoxContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.grow_vertical = Control.GROW_DIRECTION_BOTH
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 8)
	add_child(center)

	# WARNING 标签
	if _is_final:
		var final_label := Label.new()
		final_label.text = "⚡ FINAL BATTLE ⚡"
		final_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		final_label.add_theme_font_size_override("font_size", 14)
		final_label.add_theme_color_override("font_color", Color("c060ff"))
		center.add_child(final_label)

	var warning_label := Label.new()
	warning_label.text = "⚠ WARNING ⚠"
	warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning_label.add_theme_font_size_override("font_size", 12)
	warning_label.add_theme_color_override("font_color", accent)
	center.add_child(warning_label)

	# Boss 名号
	var name_label := Label.new()
	name_label.text = _boss_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 28)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	center.add_child(name_label)

	# 副标题
	var subtitle: String = CHAPTER_SUBTITLES.get(_chapter, "深渊之主") if not _is_final else "终焉主宰"
	var sub_label := Label.new()
	sub_label.text = subtitle
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_label.add_theme_font_size_override("font_size", 13)
	sub_label.add_theme_color_override("font_color", Color(accent, 0.8))
	center.add_child(sub_label)

	# 存储引用
	set_meta("bg", bg)
	set_meta("center", center)
	set_meta("warning_label", warning_label)


func _animate() -> void:
	var bg: ColorRect = get_meta("bg")
	var center: VBoxContainer = get_meta("center")
	var warning_label: Label = get_meta("warning_label")

	var duration: float = 1.2 if not _is_final else 1.8

	# 暗幕淡入
	var tw := create_tween()
	tw.tween_property(bg, "color:a", 0.85, 0.3)

	# 中央内容入场
	center.modulate.a = 0.0
	center.position.y += 20
	tw.parallel().tween_property(center, "modulate:a", 1.0, 0.4).set_delay(0.2)
	tw.parallel().tween_property(center, "position:y", center.position.y - 20, 0.4).set_delay(0.2).set_ease(Tween.EASE_OUT)

	# WARNING 闪烁
	tw.tween_callback(func():
		var flash_tw := create_tween()
		flash_tw.set_loops(3)
		flash_tw.tween_property(warning_label, "modulate:a", 0.3, 0.15)
		flash_tw.tween_property(warning_label, "modulate:a", 1.0, 0.15)
	).set_delay(0.5)

	# 持续展示后退出
	tw.tween_interval(duration)
	tw.tween_property(bg, "color:a", 0.0, 0.3)
	tw.parallel().tween_property(center, "modulate:a", 0.0, 0.2)
	tw.tween_callback(func():
		if _on_complete.is_valid():
			_on_complete.call()
		queue_free()
	)
