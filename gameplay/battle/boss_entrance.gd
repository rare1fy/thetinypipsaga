## Boss 入场演出 — 全屏暗幕 + WARNING横条 + Boss名号 + 闪烁
## 用法: BossEntrance.play(parent_node, boss_name, chapter, is_final)
## 演出结束后自动 queue_free

class_name BossEntrance
extends CanvasLayer

const CHAPTER_COLORS: Dictionary = {
	1: { "primary": Color("#c8403c"), "glow": Color(0.78, 0.25, 0.23, 0.6), "bg": Color(0.04, 0.01, 0.01, 0.85) },
	2: { "primary": Color("#68a0e8"), "glow": Color(0.39, 0.63, 0.94, 0.6), "bg": Color(0.01, 0.02, 0.05, 0.85) },
	3: { "primary": Color("#f0a040"), "glow": Color(0.94, 0.63, 0.25, 0.6), "bg": Color(0.05, 0.02, 0.0, 0.85) },
	4: { "primary": Color("#b068e8"), "glow": Color(0.69, 0.41, 0.91, 0.6), "bg": Color(0.02, 0.01, 0.05, 0.85) },
	5: { "primary": Color("#e8d068"), "glow": Color(0.91, 0.82, 0.41, 0.6), "bg": Color(0.03, 0.02, 0.01, 0.85) },
}

const FINAL_COLORS: Dictionary = {
	"primary": Color("#f0c040"),
	"glow": Color(0.94, 0.75, 0.25, 0.75),
	"bg": Color(0.03, 0.01, 0.05, 0.92),
}

signal entrance_finished

var _boss_name: String = ""
var _chapter: int = 1
var _is_final: bool = false


static func play(parent: Node, boss_name: String, chapter: int, is_final: bool = false) -> BossEntrance:
	var entrance := BossEntrance.new()
	entrance._boss_name = boss_name
	entrance._chapter = chapter
	entrance._is_final = is_final
	entrance.layer = 90
	parent.add_child(entrance)
	return entrance


func _ready() -> void:
	var colors: Dictionary = FINAL_COLORS if _is_final else CHAPTER_COLORS.get(_chapter, CHAPTER_COLORS[1])
	var primary: Color = colors["primary"]
	var bg: Color = colors["bg"]

	# 全屏暗幕
	var backdrop := ColorRect.new()
	backdrop.color = bg
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	# WARNING 横条
	var warning_bar := ColorRect.new()
	warning_bar.color = primary.darkened(0.3)
	warning_bar.set_anchors_preset(Control.PRESET_CENTER)
	warning_bar.custom_minimum_size = Vector2(800, 60)
	warning_bar.size = Vector2(800, 60)
	warning_bar.position = Vector2(-400, -30)
	add_child(warning_bar)

	# WARNING 文字
	var warning_label := Label.new()
	warning_label.text = "⚠ FINAL BATTLE ⚠" if _is_final else "⚠ WARNING ⚠"
	warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	warning_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	warning_label.add_theme_font_size_override("font_size", 14 if _is_final else 12)
	warning_label.add_theme_color_override("font_color", primary)
	warning_label.add_theme_color_override("font_outline_color", Color.BLACK)
	warning_label.add_theme_constant_override("outline_size", 3)
	warning_bar.add_child(warning_label)

	# Boss 名号
	var name_label := Label.new()
	name_label.text = _boss_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.set_anchors_preset(Control.PRESET_CENTER)
	name_label.custom_minimum_size = Vector2(400, 40)
	name_label.size = Vector2(400, 40)
	name_label.position = Vector2(-200, 40)
	name_label.add_theme_font_size_override("font_size", 22 if _is_final else 18)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.add_theme_color_override("font_outline_color", primary.darkened(0.2))
	name_label.add_theme_constant_override("outline_size", 4)
	add_child(name_label)

	# 动画序列
	var total_duration: float = 3.0 if _is_final else 2.2
	var tw: Tween = create_tween()

	# 整体淡入
	backdrop.modulate.a = 0.0
	warning_bar.modulate.a = 0.0
	name_label.modulate.a = 0.0
	tw.tween_property(backdrop, "modulate:a", 1.0, 0.3)

	# WARNING 横条从左滑入
	warning_bar.position.x = -800.0
	tw.tween_property(warning_bar, "position:x", -400.0, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.parallel().tween_property(warning_bar, "modulate:a", 1.0, 0.2)

	# WARNING 闪烁
	tw.tween_property(warning_label, "modulate:a", 0.3, 0.15)
	tw.tween_property(warning_label, "modulate:a", 1.0, 0.15)
	tw.tween_property(warning_label, "modulate:a", 0.3, 0.15)
	tw.tween_property(warning_label, "modulate:a", 1.0, 0.15)

	# Boss 名号淡入
	tw.tween_property(name_label, "modulate:a", 1.0, 0.3)

	# 持续展示
	tw.tween_interval(total_duration - 1.8)

	# 整体淡出
	tw.tween_property(backdrop, "modulate:a", 0.0, 0.4)
	tw.parallel().tween_property(warning_bar, "modulate:a", 0.0, 0.3)
	tw.parallel().tween_property(name_label, "modulate:a", 0.0, 0.3)

	tw.tween_callback(_on_finished)


func _on_finished() -> void:
	entrance_finished.emit()
	queue_free()
