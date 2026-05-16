## 魂晶商店 — 跨局 Meta 进度系统
## 消耗魂晶购买常驻遗物，购买后每次开局自动携带
## 对齐原版 SoulShop.tsx

class_name SoulShop
extends Control

signal closed

const PURPLE := Color("#9060d0")
const PURPLE_DIM := Color("#6040a0")
const PURPLE_BG := Color("#1a0e2e")
const GREEN_OWNED := Color("#40a060")
const RED_CANT := Color("#a04040")

## 商店商品定义：{relic_id, cost}
const SHOP_ITEMS: Array[Dictionary] = [
	{"relic_id": "grindstone", "cost": 500},
	{"relic_id": "iron_skin_relic", "cost": 400},
	{"relic_id": "fate_coin", "cost": 650},
	{"relic_id": "greedy_hand", "cost": 800},
	{"relic_id": "crimson_grail", "cost": 700},
	{"relic_id": "schrodinger_bag", "cost": 750},
	{"relic_id": "treasure_sense_relic", "cost": 550},
	{"relic_id": "warm_ember_relic", "cost": 450},
	{"relic_id": "symmetry_seeker", "cost": 600},
	{"relic_id": "iron_banner", "cost": 500},
]

var _meta: Dictionary = {}
var _scroll: ScrollContainer
var _list: VBoxContainer
var _balance_label: Label
var _stats_label: Label
var _flash_label: Label
var _flash_tw: Tween


func _ready() -> void:
	_meta = _load_meta()
	_build_ui()
	_refresh()


# ============================================================
# Meta 存储
# ============================================================

func _load_meta() -> Dictionary:
	var raw: Dictionary = SaveManager.load_meta()
	return {
		"souls": raw.get("permanent_souls", 0),
		"unlocked": raw.get("unlocked_start_relics", []),
		"total_runs": raw.get("total_runs", 0),
		"total_wins": raw.get("total_wins", 0),
		"highest_overkill": raw.get("highest_overkill", 0),
	}


func _save_meta() -> void:
	var raw: Dictionary = SaveManager.load_meta()
	raw["permanent_souls"] = _meta["souls"]
	raw["unlocked_start_relics"] = _meta["unlocked"]
	SaveManager.save_meta(raw)


# ============================================================
# UI 构建
# ============================================================

func _build_ui() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP

	# 标题栏
	var header := HBoxContainer.new()
	header.set_anchors_preset(PRESET_TOP_WIDE)
	header.offset_bottom = 48
	add_child(header)

	var title := Label.new()
	title.text = "💎 魂晶商店"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", PURPLE)
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	header.add_child(title)

	_balance_label = Label.new()
	_balance_label.add_theme_font_size_override("font_size", 14)
	_balance_label.add_theme_color_override("font_color", PURPLE)
	header.add_child(_balance_label)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.flat = true
	close_btn.add_theme_font_size_override("font_size", 18)
	close_btn.pressed.connect(func(): closed.emit())
	header.add_child(close_btn)

	# 说明
	var desc := Label.new()
	desc.text = "消耗魂晶购买常驻遗物，购买后每次开局自动携带。\n魂晶通过溢出伤害获取，营火可撤离保存。"
	desc.add_theme_font_size_override("font_size", 10)
	desc.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.position = Vector2(0, 52)
	desc.size = Vector2(400, 40)
	add_child(desc)

	# Flash 消息
	_flash_label = Label.new()
	_flash_label.add_theme_font_size_override("font_size", 13)
	_flash_label.add_theme_color_override("font_color", PURPLE)
	_flash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_flash_label.position = Vector2(0, 92)
	_flash_label.size = Vector2(400, 24)
	_flash_label.modulate.a = 0.0
	add_child(_flash_label)

	# 商品列表
	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(0, 118)
	_scroll.size = Vector2(400, 340)
	add_child(_scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	_scroll.add_child(_list)

	# 底部统计
	_stats_label = Label.new()
	_stats_label.add_theme_font_size_override("font_size", 9)
	_stats_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
	_stats_label.position = Vector2(0, 464)
	_stats_label.size = Vector2(400, 20)
	add_child(_stats_label)


# ============================================================
# 刷新列表
# ============================================================

func _refresh() -> void:
	_balance_label.text = "💎 %d" % _meta["souls"]

	var unlocked_arr: Array = _meta.get("unlocked", [])
	_stats_label.text = "总局数: %d  |  最高溢出: %d  |  已解锁: %d/%d" % [
		_meta.get("total_runs", 0),
		_meta.get("highest_overkill", 0),
		unlocked_arr.size(),
		SHOP_ITEMS.size(),
	]

	# 清空旧条目
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.free()

	# 生成商品条目
	for item: Dictionary in SHOP_ITEMS:
		var relic_id: String = item["relic_id"]
		var cost: int = item["cost"]
		var relic_def: RelicDef = GameData.get_relic_def(relic_id)
		if relic_def == null:
			continue

		var owned: bool = relic_id in unlocked_arr
		var can_afford: bool = _meta["souls"] >= cost

		var row := _make_item_row(relic_def, cost, owned, can_afford)
		if not owned:
			row.gui_input.connect(_on_item_input.bind(item))
		_list.add_child(row)


func _make_item_row(relic: RelicDef, cost: int, owned: bool, can_afford: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PURPLE_BG if not owned else Color("#0a1a0e")
	style.border_color = GREEN_OWNED if owned else (PURPLE_DIM if can_afford else Color(0.3, 0.3, 0.35))
	style.border_width_bottom = 2; style.border_width_top = 2
	style.border_width_left = 2; style.border_width_right = 2
	style.corner_radius_top_left = 2; style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2; style.corner_radius_bottom_right = 2
	style.content_margin_left = 10; style.content_margin_right = 10
	style.content_margin_top = 8; style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)
	if owned:
		panel.modulate.a = 0.6

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	panel.add_child(hbox)

	# 遗物名称+描述
	var info := VBoxContainer.new()
	info.size_flags_horizontal = SIZE_EXPAND_FILL
	hbox.add_child(info)

	var name_row := HBoxContainer.new()
	info.add_child(name_row)

	var name_label := Label.new()
	name_label.text = relic.name
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", GREEN_OWNED if owned else Color.WHITE)
	name_row.add_child(name_label)

	if owned:
		var tag := Label.new()
		tag.text = " 已解锁"
		tag.add_theme_font_size_override("font_size", 9)
		tag.add_theme_color_override("font_color", GREEN_OWNED)
		name_row.add_child(tag)

	var desc_label := Label.new()
	desc_label.text = relic.description
	desc_label.add_theme_font_size_override("font_size", 10)
	desc_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(desc_label)

	# 价格
	if not owned:
		var price := Label.new()
		price.text = "💎 %d" % cost
		price.add_theme_font_size_override("font_size", 12)
		price.add_theme_color_override("font_color", PURPLE if can_afford else RED_CANT)
		hbox.add_child(price)

	return panel


# ============================================================
# 购买逻辑
# ============================================================

func _on_item_input(event: InputEvent, item: Dictionary) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return

	var relic_id: String = item["relic_id"]
	var cost: int = item["cost"]
	var unlocked_arr: Array = _meta.get("unlocked", [])

	if relic_id in unlocked_arr:
		_show_flash("已拥有此遗物！", Color.YELLOW)
		return

	if _meta["souls"] < cost:
		_show_flash("❌ 魂晶不足！", RED_CANT)
		return

	# 购买成功
	_meta["souls"] -= cost
	unlocked_arr.append(relic_id)
	_meta["unlocked"] = unlocked_arr
	_save_meta()

	var relic_def: RelicDef = GameData.get_relic_def(relic_id)
	var relic_name: String = relic_def.name if relic_def else relic_id
	_show_flash("✦ 获得 %s！" % relic_name, PURPLE)
	SoundPlayer.play_sound("reward")

	_refresh()


func _show_flash(msg: String, color: Color) -> void:
	_flash_label.text = msg
	_flash_label.add_theme_color_override("font_color", color)
	if _flash_tw and _flash_tw.is_valid():
		_flash_tw.kill()
	_flash_tw = create_tween()
	_flash_tw.tween_property(_flash_label, "modulate:a", 1.0, 0.15)
	_flash_tw.tween_interval(1.5)
	_flash_tw.tween_property(_flash_label, "modulate:a", 0.0, 0.3)
