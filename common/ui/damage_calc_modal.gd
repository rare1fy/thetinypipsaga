## 伤害计算详情弹窗 — 展示出牌预期结算的完整计算过程
## 显示：基础伤害 → 骰子效果 → 遗物加成 → 牌型倍率 → 最终伤害
## 用法: DamageCalcModal.show_calc(parent, calc_breakdown)

class_name DamageCalcModal
extends CanvasLayer

signal closed

## 计算步骤数据结构
## breakdown = {
##   "hand_type": "顺子",
##   "hand_level": 2,
##   "base_damage": 15,
##   "dice_effects": [{"name": "火焰骰", "value": 3}],
##   "relic_effects": [{"name": "战斗之锤", "value": 5, "type": "flat"}],
##   "hand_mult": 2.5,
##   "status_mult": 1.5,
##   "final_damage": 56,
##   "armor": 0,
##   "heal": 0,
##   "pierce": 0,
## }

var _breakdown: Dictionary = {}


static func show_calc(parent: Node, breakdown: Dictionary) -> DamageCalcModal:
	var instance := DamageCalcModal.new()
	instance._breakdown = breakdown
	parent.add_child(instance)
	return instance


func _ready() -> void:
	layer = 80
	_build_ui()


func _build_ui() -> void:
	# 背景遮罩
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.85)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			_close()
	)
	add_child(bg)

	# 主面板
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(160, 200)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.06, 0.04, 0.96)
	panel_style.border_color = Color("d4a030")
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(3)
	panel_style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(150, 190)
	panel.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	# 标题
	var title := Label.new()
	title.text = "X 伤害计算详情"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 8)
	title.add_theme_color_override("font_color", Color("d4a030"))
	vbox.add_child(title)

	_add_separator(vbox)

	# 牌型信息
	var hand_type: String = _breakdown.get("hand_type", "未知")
	var hand_level: int = _breakdown.get("hand_level", 1)
	_add_row(vbox, "牌型", "%s Lv.%d" % [hand_type, hand_level], Color("ffcc44"))

	_add_separator(vbox)

	# 基础伤害
	var base_dmg: int = _breakdown.get("base_damage", 0)
	_add_row(vbox, "骰子点数合计", str(base_dmg), Color.WHITE)

	# 骰子效果
	var dice_effects: Array = _breakdown.get("dice_effects", [])
	for eff: Dictionary in dice_effects:
		var eff_name: String = eff.get("name", "")
		var eff_value: int = eff.get("value", 0)
		_add_row(vbox, "  + %s" % eff_name, "+%d" % eff_value, Color("88ccff"))

	# 遗物效果
	var relic_effects: Array = _breakdown.get("relic_effects", [])
	if not relic_effects.is_empty():
		_add_separator(vbox)
		_add_section_title(vbox, "遗物加成")
		for eff: Dictionary in relic_effects:
			var eff_name: String = eff.get("name", "")
			var eff_value = eff.get("value", 0)
			var eff_type: String = eff.get("type", "flat")
			var display: String = "+%d" % eff_value if eff_type == "flat" else "×%.1f" % float(eff_value)
			_add_row(vbox, "  %s" % eff_name, display, Color("cc88ff"))

	_add_separator(vbox)

	# 倍率
	var hand_mult: float = _breakdown.get("hand_mult", 1.0)
	_add_row(vbox, "牌型倍率", "×%.1f" % hand_mult, Color("ffaa44"))

	var status_mult: float = _breakdown.get("status_mult", 1.0)
	if status_mult != 1.0:
		_add_row(vbox, "状态倍率(易伤)", "×%.1f" % status_mult, Color("ff6666"))

	_add_separator(vbox)

	# 最终结果
	var final_dmg: int = _breakdown.get("final_damage", 0)
	_add_row(vbox, "最终伤害", str(final_dmg), Color("ff4444"), 16)

	var armor: int = _breakdown.get("armor", 0)
	if armor > 0:
		_add_row(vbox, "获得护甲", "+%d" % armor, Color("44ccff"))

	var heal: int = _breakdown.get("heal", 0)
	if heal > 0:
		_add_row(vbox, "恢复生命", "+%d" % heal, Color("44ff44"))

	var pierce: int = _breakdown.get("pierce", 0)
	if pierce > 0:
		_add_row(vbox, "穿甲", str(pierce), Color("ffcc00"))

	# 关闭提示
	_add_separator(vbox)
	var hint := Label.new()
	hint.text = "点击任意处关闭"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 5)
	hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	vbox.add_child(hint)

	# 入场动画
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.9, 0.9)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(panel, "modulate:a", 1.0, 0.2)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.2).set_ease(Tween.EASE_OUT)


func _close() -> void:
	closed.emit()
	queue_free()


func _add_row(parent: VBoxContainer, label_text: String, value_text: String, color: Color, font_size: int = 12) -> void:
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var lbl := Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	hbox.add_child(lbl)

	var val := Label.new()
	val.text = value_text
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.add_theme_font_size_override("font_size", font_size)
	val.add_theme_color_override("font_color", color)
	hbox.add_child(val)

	parent.add_child(hbox)


func _add_separator(parent: VBoxContainer) -> void:
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	parent.add_child(sep)


func _add_section_title(parent: VBoxContainer, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 5)
	lbl.add_theme_color_override("font_color", Color("aaaaaa"))
	parent.add_child(lbl)
