## Boss 嘲讽预告横幅 — 地图上经过 Boss 前一层时弹出
## 用法: BossTauntBanner.show_taunt(parent_node, boss_name, taunt_line, chapter)
## 效果：屏幕顶部滑入一条暗色横幅，显示 Boss 名 + 嘲讽台词，2秒后滑出

class_name BossTauntBanner
extends CanvasLayer

const CHAPTER_ACCENT: Dictionary = {
	1: Color("c8403c"),
	2: Color("68a0e8"),
	3: Color("f0a040"),
	4: Color("b068e8"),
	5: Color("e8d068"),
}

## Boss 嘲讽台词库（按章节，每章 Boss 各有几句随机台词）
const TAUNT_LINES: Dictionary = {
	1: [
		"又一只迷途的羔羊……",
		"你的骰子在颤抖吗？",
		"这里将是你的坟墓。",
		"我已等候多时。",
	],
	2: [
		"荒原的风会吹散你的骨灰。",
		"兽族不需要怜悯。",
		"碎牙堡从不接纳弱者。",
	],
	3: [
		"死亡只是开始……",
		"加入我们吧，永生的代价并不高。",
		"你的灵魂闻起来很美味。",
	],
	4: [
		"月光之下，无处遁形。",
		"精灵的箭比你的骰子更快。",
		"灰谷的迷雾会吞噬一切。",
	],
	5: [
		"凡人，你不配踏入此地。",
		"龙焰将净化一切不洁。",
		"跪下，或化为灰烬。",
	],
}

var _boss_name: String = ""
var _taunt_line: String = ""
var _chapter: int = 1


static func show_taunt(parent: Node, boss_name: String, chapter: int, custom_line: String = "") -> BossTauntBanner:
	var instance := BossTauntBanner.new()
	instance._boss_name = boss_name
	instance._chapter = chapter
	if custom_line != "":
		instance._taunt_line = custom_line
	else:
		var lines: Array = TAUNT_LINES.get(chapter, TAUNT_LINES[1])
		instance._taunt_line = lines[randi() % lines.size()]
	parent.add_child(instance)
	return instance


## 检查当前地图状态是否应该触发 Boss 嘲讽（进入 Boss 前一层时触发）
static func should_show_taunt(current_depth: int, _chapter: int) -> bool:
	var boss_layer: int = MapGenerator.TOTAL_LAYERS - 1
	var mid_boss_layer: int = 7  # balance.json: map.mid_boss_layer
	# Boss 前一层触发
	return current_depth == boss_layer - 1 or current_depth == mid_boss_layer - 1


func _ready() -> void:
	layer = 80
	_build_and_animate()


func _build_and_animate() -> void:
	var accent: Color = CHAPTER_ACCENT.get(_chapter, Color("c8403c"))

	# 横幅容器（从顶部滑入）
	var banner := PanelContainer.new()
	banner.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	banner.offset_top = -80
	banner.offset_bottom = 0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.03, 0.08, 0.92)
	style.border_color = accent
	style.border_width_bottom = 2
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	banner.add_theme_stylebox_override("panel", style)
	add_child(banner)

	# 内容
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)
	banner.add_child(vbox)

	# Boss 名
	var name_label := Label.new()
	name_label.text = "👑 %s" % _boss_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", accent)
	vbox.add_child(name_label)

	# 嘲讽台词
	var line_label := Label.new()
	line_label.text = "「%s」" % _taunt_line
	line_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line_label.add_theme_font_size_override("font_size", 11)
	line_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 0.9))
	vbox.add_child(line_label)

	# 动画：滑入 → 停留 → 滑出
	var tw := create_tween()
	tw.tween_property(banner, "offset_top", 0.0, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.parallel().tween_property(banner, "offset_bottom", 80.0, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(2.5)
	tw.tween_property(banner, "offset_top", -80.0, 0.3).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tw.parallel().tween_property(banner, "offset_bottom", 0.0, 0.3).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tw.tween_callback(queue_free)
