## 统计弹窗 — 战斗/经济统计展示
## 迁移自 React 版 StatsModal.tsx
## 数据来源：StatsTracker.stats + XpSystem

class_name StatsModal
extends VBoxContainer

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	add_theme_constant_override("separation", 6)
	_build_ui()


# ============================================================
# 构建 UI
# ============================================================

func _build_ui() -> void:
	var s: Dictionary = StatsTracker.stats
	var avg_damage: int = int(s.totalDamageDealt / maxi(1, s.battlesWon))
	
	# 标题
	var title := Label.new()
	title.text = "* 战斗统计 *"
	title.add_theme_color_override("font_color", Color("#d4a030"))
	title.add_theme_font_size_override("font_size", 12)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	
	# 当前层数
	var depth_label := Label.new()
	var current_depth: int = PlayerState.current_node
	if current_depth < 0:
		current_depth = 0
	depth_label.text = "第 %d 层" % (current_depth + 1)
	depth_label.add_theme_color_override("font_color", Color("#9aa0ac"))
	depth_label.add_theme_font_size_override("font_size", 12)
	depth_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(depth_label)
	
	# 等级信息
	if XpSystem:
		add_child(_make_section("等级"))
		add_child(_make_row("当前等级", "Lv.%d" % XpSystem.level, Color("#d4a030")))
		if XpSystem.level < XpSystem.MAX_LEVEL:
			add_child(_make_row("经验进度", "%d / %d" % [XpSystem.xp, XpSystem.xp_to_next], Color("#60c0e0")))
		else:
			add_child(_make_row("经验进度", "已满级", Color("#d4a030")))
	
	# 总伤害高亮
	var dmg_panel := PanelContainer.new()
	var dmg_style := StyleBoxFlat.new()
	dmg_style.bg_color = Color(0.88, 0.24, 0.24, 0.1)
	dmg_style.border_color = Color(0.88, 0.24, 0.24, 0.3)
	dmg_style.set_border_width_all(2)
	dmg_style.set_corner_radius_all(4)
	dmg_style.content_margin_left = 8
	dmg_style.content_margin_right = 8
	dmg_style.content_margin_top = 8
	dmg_style.content_margin_bottom = 8
	dmg_panel.add_theme_stylebox_override("panel", dmg_style)
	var dmg_vbox := VBoxContainer.new()
	dmg_vbox.add_theme_constant_override("separation", 2)
	var dmg_title := Label.new()
	dmg_title.text = "TOTAL DAMAGE"
	dmg_title.add_theme_color_override("font_color", Color("#e04040"))
	dmg_title.add_theme_font_size_override("font_size", 12)
	dmg_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dmg_vbox.add_child(dmg_title)
	var dmg_value := Label.new()
	dmg_value.text = _format_number(s.totalDamageDealt)
	dmg_value.add_theme_color_override("font_color", Color("#e04040"))
	dmg_value.add_theme_font_size_override("font_size", 12)
	dmg_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dmg_vbox.add_child(dmg_value)
	dmg_panel.add_child(dmg_vbox)
	add_child(dmg_panel)
	
	# 伤害总览
	add_child(_make_section("X 伤害总览"))
	add_child(_make_row("单次最高伤害", str(s.maxSingleHit), Color("#e04040")))
	add_child(_make_row("场均伤害", str(avg_damage), Color("#e09040")))
	
	# 出牌统计
	add_child(_make_section("[D] 出牌统计"))
	add_child(_make_row("总出牌次数", str(s.totalPlays), Color("#4080ff")))
	add_child(_make_row("总重掷次数", str(s.totalRerolls), Color("#40c040")))
	
	# 战斗统计
	add_child(_make_section("D 战斗统计"))
	add_child(_make_row("已完成战斗", str(s.battlesWon), Color("#e09040")))
	add_child(_make_row("击杀敌人", str(s.enemiesKilled), Color("#e04040")))
	add_child(_make_row("精英战胜利", str(s.elitesWon), Color("#9060d0")))
	add_child(_make_row("Boss战胜利", str(s.bossesWon), Color("#d4a030")))
	
	# 生存统计
	add_child(_make_section("H 生存统计"))
	add_child(_make_row("累计受到伤害", str(s.totalDamageTaken), Color("#e04040")))
	add_child(_make_row("累计回复量", str(s.totalHealing), Color("#40c040")))
	add_child(_make_row("累计获得护甲", str(s.totalArmorGained), Color("#4080ff")))
	
	# 经济统计
	add_child(_make_section("G 经济统计"))
	add_child(_make_row("累计获得金币", str(s.goldEarned), Color("#d4a030")))
	add_child(_make_row("累计花费金币", str(s.goldSpent), Color("#d4a030")))


# ============================================================
# UI 工具
# ============================================================

func _make_section(title: String) -> Label:
	var label := Label.new()
	label.text = title
	label.add_theme_color_override("font_color", Color("#9aa0ac"))
	label.add_theme_font_size_override("font_size", 12)
	return label


func _make_row(label_text: String, value_text: String, color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.add_theme_color_override("font_color", Color("#9aa0ac"))
	label.add_theme_font_size_override("font_size", 12)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var value := Label.new()
	value.text = value_text
	value.add_theme_color_override("font_color", color)
	value.add_theme_font_size_override("font_size", 12)
	row.add_child(value)
	return row


static func _format_number(n: int) -> String:
	var s: String = str(n)
	var result: String = ""
	var count: int = 0
	for i: int in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "," + result
		result = s[i] + result
		count += 1
	return result
