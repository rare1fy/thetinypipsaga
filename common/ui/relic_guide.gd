## RelicGuide — 遗物图鉴（Modal 内容）
##
## 展示所有已注册遗物：图标 / 名称 / 稀有度 / 效果描述
## 按稀有度分组：传说 → 稀有 → 精良 → 普通（稀有度高的排在前，引导玩家关注）
##
## 数据源：GameData._relic_defs（Dictionary[id → RelicDef]）
## 配色源：PixelTheme.RARITY_COMMON/UNCOMMON/RARE/LEGENDARY
##
## 调用方式：
##   const RelicGuideRef := preload("res://common/ui/relic_guide.gd")
##   ModalHubRef.open(RelicGuideRef.new(), "遗物图鉴", {"size": Vector2(560, 780)})

extends VBoxContainer

const ModalHubRef := preload("res://common/ui/modal_hub.gd")

# ============================================================
# 常量：稀有度展示顺序（传说最上，普通最下）
# ============================================================
const RARITY_ORDER: Array[int] = [
	GameTypes.RelicRarity.LEGENDARY,
	GameTypes.RelicRarity.RARE,
	GameTypes.RelicRarity.UNCOMMON,
	GameTypes.RelicRarity.COMMON,
]

# 稀有度 → 中文标签
const RARITY_LABEL: Dictionary = {
	GameTypes.RelicRarity.COMMON: "普通",
	GameTypes.RelicRarity.UNCOMMON: "精良",
	GameTypes.RelicRarity.RARE: "稀有",
	GameTypes.RelicRarity.LEGENDARY: "传说",
}

# 稀有度 → 颜色
const RARITY_COLOR: Dictionary = {
	GameTypes.RelicRarity.COMMON: Color("#38c060"),
	GameTypes.RelicRarity.UNCOMMON: Color("#3c6cc8"),
	GameTypes.RelicRarity.RARE: Color("#a855f7"),
	GameTypes.RelicRarity.LEGENDARY: Color("#f97316"),
}

# 稀有度 → emoji 前缀（无素材时的视觉层级）
const RARITY_EMOJI: Dictionary = {
	GameTypes.RelicRarity.COMMON: "⚪",
	GameTypes.RelicRarity.UNCOMMON: "🔵",
	GameTypes.RelicRarity.RARE: "🟣",
	GameTypes.RelicRarity.LEGENDARY: "🟠",
}

# 触发时机 → 中文标签
const TRIGGER_LABEL: Dictionary = {
	GameTypes.RelicTrigger.ON_PLAY: "出牌时",
	GameTypes.RelicTrigger.ON_KILL: "击杀时",
	GameTypes.RelicTrigger.ON_REROLL: "重投时",
	GameTypes.RelicTrigger.ON_TURN_START: "回合开始",
	GameTypes.RelicTrigger.ON_TURN_END: "回合结束",
	GameTypes.RelicTrigger.ON_BATTLE_START: "战斗开始",
	GameTypes.RelicTrigger.ON_BATTLE_END: "战斗结束",
	GameTypes.RelicTrigger.ON_DAMAGE_TAKEN: "受击时",
	GameTypes.RelicTrigger.ON_FATAL: "致命时",
	GameTypes.RelicTrigger.ON_FLOOR_CLEAR: "清场时",
	GameTypes.RelicTrigger.ON_MOVE: "移动时",
	GameTypes.RelicTrigger.PASSIVE: "被动",
}


# ============================================================
# 生命周期
# ============================================================
func _ready() -> void:
	add_theme_constant_override("separation", 16)
	_build_content()


# ============================================================
# 构建
# ============================================================
func _build_content() -> void:
	# 顶部说明 + 总数
	var all_relics: Array[RelicDef] = []
	all_relics.assign(GameData._relic_defs.values())
	var intro := Label.new()
	intro.text = "共收录 %d 件遗物\n按稀有度分组，传说在上" % all_relics.size()
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro.add_theme_color_override("font_color", Color("#9aa0ac"))
	intro.add_theme_font_size_override("font_size", 12)
	add_child(intro)
	
	# 空数据兜底（GameData 未初始化或数据加载失败）
	if all_relics.is_empty():
		var empty_label := Label.new()
		empty_label.text = "（暂无遗物数据）"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		empty_label.add_theme_color_override("font_color", Color("#5a6070"))
		add_child(empty_label)
		return
	
	# 按稀有度分组
	var grouped: Dictionary = _group_by_rarity(all_relics)
	
	# 可滚动主体
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 14)
	scroll.add_child(list)
	
	# 按顺序输出每个稀有度组
	for rarity: int in RARITY_ORDER:
		var defs: Array[RelicDef] = []
		defs.assign(grouped.get(rarity, []))
		if defs.is_empty():
			continue
		list.add_child(_build_group_header(rarity, defs.size()))
		for def: RelicDef in defs:
			list.add_child(_build_relic_entry(def))


func _group_by_rarity(all_relics: Array[RelicDef]) -> Dictionary:
	var result: Dictionary = {}
	for def: RelicDef in all_relics:
		var key: int = def.rarity
		if not result.has(key):
			result[key] = []
		result[key].append(def)
	return result


func _build_group_header(rarity: int, count: int) -> Control:
	var color: Color = RARITY_COLOR.get(rarity, Color.WHITE)
	var label_text: String = RARITY_LABEL.get(rarity, "未知")
	
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	
	var dot := ColorRect.new()
	dot.color = color
	dot.custom_minimum_size = Vector2(4, 20)
	header.add_child(dot)
	
	var label := Label.new()
	label.text = "%s（%d）" % [label_text, count]
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", color)
	header.add_child(label)
	
	return header


func _build_relic_entry(def: RelicDef) -> Control:
	var color: Color = RARITY_COLOR.get(def.rarity, Color.WHITE)
	var emoji: String = RARITY_EMOJI.get(def.rarity, "⚪")
	
	var row := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#242838")
	style.border_color = color.darkened(0.5)
	style.set_border_width_all(1)
	style.border_width_left = 3  # 左侧粗边标稀有度
	style.set_corner_radius_all(4)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	row.add_theme_stylebox_override("panel", style)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	row.add_child(vbox)
	
	# 第一行：emoji + 名称 + 触发时机
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	
	var emoji_label := Label.new()
	emoji_label.text = emoji
	emoji_label.add_theme_font_size_override("font_size", 14)
	top.add_child(emoji_label)
	
	var name_label := Label.new()
	name_label.text = def.name
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", color)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_label)
	
	var trigger_label := Label.new()
	trigger_label.text = TRIGGER_LABEL.get(def.trigger, "")
	trigger_label.add_theme_font_size_override("font_size", 11)
	trigger_label.add_theme_color_override("font_color", Color("#7a8090"))
	top.add_child(trigger_label)
	
	vbox.add_child(top)
	
	# 第二行：描述
	if def.description != "":
		var desc_label := Label.new()
		desc_label.text = def.description
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.add_theme_font_size_override("font_size", 12)
		desc_label.add_theme_color_override("font_color", Color("#c8d0e0"))
		vbox.add_child(desc_label)
	
	return row
