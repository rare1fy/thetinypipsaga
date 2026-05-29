## 骰子图鉴 — 按职业分类展示所有骰子
## 迁移自 React 版 DiceGuideModal.tsx + DiceGuideList.tsx

class_name DiceGuideModal
extends VBoxContainer

# ============================================================
# 分类定义
# ============================================================

const CATEGORIES: Array[Dictionary] = [
	{"id": "all", "label": "全部", "color": Color("#b0b8c8")},
	{"id": "universal", "label": "通用", "color": Color("#b0b8c8")},
	{"id": "warrior", "label": "战士", "color": Color("#e04040")},
	{"id": "mage", "label": "法师", "color": Color("#9060d0")},
	{"id": "rogue", "label": "盗贼", "color": Color("#40c040")},
]

const RARITY_ORDER: Array[int] = [
	GameTypes.DiceRarity.COMMON,
	GameTypes.DiceRarity.UNCOMMON,
	GameTypes.DiceRarity.RARE,
	GameTypes.DiceRarity.LEGENDARY,
	GameTypes.DiceRarity.CURSE,
]

# ============================================================
# 状态
# ============================================================

var _active_category: String = "all"
var _content_container: VBoxContainer
var _tab_container: HBoxContainer

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	add_theme_constant_override("separation", 8)
	_build_ui()
	_refresh_list()


# ============================================================
# 构建 UI
# ============================================================

func _build_ui() -> void:
	# 标题
	var title := Label.new()
	title.text = "* 骰子图鉴 *"
	title.add_theme_color_override("font_color", Color("#e6e8f0"))
	title.add_theme_font_size_override("font_size", 12)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	
	# 分类标签栏
	_tab_container = HBoxContainer.new()
	_tab_container.add_theme_constant_override("separation", 4)
	_tab_container.alignment = BoxContainer.ALIGNMENT_CENTER
	for cat: Dictionary in CATEGORIES:
		var btn := Button.new()
		btn.text = String(cat.label)
		btn.add_theme_font_size_override("font_size", 12)
		var cat_id: String = String(cat.id)
		btn.pressed.connect(func():
			_active_category = cat_id
			_refresh_list()
			_update_tab_styles()
		)
		btn.set_meta("cat_id", cat_id)
		_tab_container.add_child(btn)
	add_child(_tab_container)
	_update_tab_styles()
	
	# 内容区（滚动）
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(4, 200)
	
	_content_container = VBoxContainer.new()
	_content_container.add_theme_constant_override("separation", 6)
	scroll.add_child(_content_container)
	add_child(scroll)


func _update_tab_styles() -> void:
	for child: Node in _tab_container.get_children():
		if child is Button:
			var btn := child as Button
			var cat_id: String = String(btn.get_meta("cat_id"))
			if cat_id == _active_category:
				btn.modulate = Color.WHITE
			else:
				btn.modulate = Color(1, 1, 1, 0.5)


# ============================================================
# 刷新列表
# ============================================================

func _refresh_list() -> void:
	for child: Node in _content_container.get_children():
		child.queue_free()
	
	var all_dice: Dictionary = GameData.get_all_dice()
	var categories_to_show: Array[String] = []
	
	if _active_category == "all":
		categories_to_show = ["universal", "warrior", "mage", "rogue"]
	else:
		categories_to_show = [_active_category]
	
	# 已拥有的骰子 ID
	var owned_ids: Dictionary = {}
	for od: Dictionary in DiceBag.owned_dice:
		owned_ids[String(od.get("defId", ""))] = true
	
	for cat_id: String in categories_to_show:
		var cat_info: Dictionary = {}
		for c: Dictionary in CATEGORIES:
			if String(c.id) == cat_id:
				cat_info = c
				break
		
		# 筛选该分类的骰子
		var dice_in_cat: Array[DiceDef] = []
		for dice_id: String in all_dice:
			var def: DiceDef = all_dice[dice_id]
			if _get_category_for_dice(def) == cat_id:
				dice_in_cat.append(def)
		
		if dice_in_cat.is_empty():
			continue
		
		# 分类标题
		var cat_label := Label.new()
		cat_label.text = "— %s —" % String(cat_info.get("label", cat_id))
		cat_label.add_theme_color_override("font_color", cat_info.get("color", Color.WHITE) as Color)
		cat_label.add_theme_font_size_override("font_size", 12)
		cat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_content_container.add_child(cat_label)
		
		# 按稀有度分组
		for rarity: int in RARITY_ORDER:
			var dice_in_rarity: Array[DiceDef] = []
			for def: DiceDef in dice_in_cat:
				if def.rarity == rarity:
					dice_in_rarity.append(def)
			
			if dice_in_rarity.is_empty():
				continue
			
			# 稀有度标签
			var rarity_label := Label.new()
			rarity_label.text = _rarity_label(rarity)
			rarity_label.add_theme_color_override("font_color", _rarity_color(rarity))
			rarity_label.add_theme_font_size_override("font_size", 12)
			_content_container.add_child(rarity_label)
			
			# 骰子条目
			for def: DiceDef in dice_in_rarity:
				var is_owned: bool = owned_ids.has(def.id)
				_content_container.add_child(_build_dice_row(def, is_owned))


func _build_dice_row(def: DiceDef, is_owned: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	
	# 名称
	var name_label := Label.new()
	name_label.text = def.name
	name_label.add_theme_color_override("font_color", Color("#e6e8f0") if is_owned else Color("#666666"))
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	
	# 面值
	var faces_label := Label.new()
	faces_label.text = "[%s]" % ",".join(def.faces.map(func(f: int): return str(f)))
	faces_label.add_theme_color_override("font_color", Color("#9aa0ac"))
	faces_label.add_theme_font_size_override("font_size", 12)
	row.add_child(faces_label)
	
	# 拥有标记
	if is_owned:
		var owned_label := Label.new()
		owned_label.text = "v"
		owned_label.add_theme_color_override("font_color", Color("#40c040"))
		owned_label.add_theme_font_size_override("font_size", 12)
		row.add_child(owned_label)
	
	# 效果描述（tooltip 风格）
	if not def.effects.is_empty():
		var desc_label := Label.new()
		desc_label.text = def.get_display_description()
		desc_label.add_theme_color_override("font_color", Color("#8090a0"))
		desc_label.add_theme_font_size_override("font_size", 12)
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(desc_label)
	
	return row


# ============================================================
# 分类判断
# ============================================================

static func _get_category_for_dice(def: DiceDef) -> String:
	var dice_id: String = def.id
	if dice_id.begins_with("warrior_") or dice_id.begins_with("war_"):
		return "warrior"
	elif dice_id.begins_with("mage_") or dice_id.begins_with("mag_"):
		return "mage"
	elif dice_id.begins_with("rogue_") or dice_id.begins_with("rog_"):
		return "rogue"
	else:
		return "universal"


static func _rarity_label(rarity: int) -> String:
	match rarity:
		GameTypes.DiceRarity.COMMON: return "普通"
		GameTypes.DiceRarity.UNCOMMON: return "稀有"
		GameTypes.DiceRarity.RARE: return "史诗"
		GameTypes.DiceRarity.LEGENDARY: return "传说"
		GameTypes.DiceRarity.CURSE: return "诅咒"
		_: return "?"


static func _rarity_color(rarity: int) -> Color:
	match rarity:
		GameTypes.DiceRarity.COMMON: return Color("#9aa0ac")
		GameTypes.DiceRarity.UNCOMMON: return Color("#40c040")
		GameTypes.DiceRarity.RARE: return Color("#4080ff")
		GameTypes.DiceRarity.LEGENDARY: return Color("#d4a030")
		GameTypes.DiceRarity.CURSE: return Color("#e04040")
		_: return Color("#888888")
