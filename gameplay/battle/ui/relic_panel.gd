## RelicPanel — 战斗中的遗物状态栏
##
## 以小图标横向列表展示玩家当前持有的所有遗物
## 鼠标悬停任一图标 → 调用 Tooltip.show_text() 展示详情
## EventBus.relic_gained / relic_lost 触发自动刷新
##
## 挂载方式：battle_scene 的 _spawn_relic_panel() 动态创建
## 定位：左上角，position(8, 48)

extends PanelContainer

const ModalHubRef := preload("res://common/ui/modal_hub.gd")

# 稀有度 → 颜色（与 relic_guide 对齐）
const RARITY_COLOR: Dictionary = {
	GameTypes.RelicRarity.COMMON: Color("#38c060"),
	GameTypes.RelicRarity.UNCOMMON: Color("#3c6cc8"),
	GameTypes.RelicRarity.RARE: Color("#a855f7"),
	GameTypes.RelicRarity.LEGENDARY: Color("#f97316"),
}

# 稀有度 → emoji
const RARITY_EMOJI: Dictionary = {
	GameTypes.RelicRarity.COMMON: "⚪",
	GameTypes.RelicRarity.UNCOMMON: "🔵",
	GameTypes.RelicRarity.RARE: "🟣",
	GameTypes.RelicRarity.LEGENDARY: "🟠",
}

# 触发时机 → 中文
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

const ICON_SIZE: int = 32
const MAX_PER_ROW: int = 8

var _grid: GridContainer
var _title_label: Label


# ── 生命周期 ─────────────────────────────────────

func _ready() -> void:
	custom_minimum_size = Vector2(0, 0)
	_apply_style()
	_build_layout()
	_refresh()


# ── 公开刷新入口（外部遗物触发后可调用） ──

func refresh() -> void:
	_refresh()


func _apply_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.13, 0.88)
	style.border_color = Color("#3a4050")
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	add_theme_stylebox_override("panel", style)


func _build_layout() -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	add_child(vbox)
	
	_title_label = Label.new()
	_title_label.text = "遗物"
	_title_label.add_theme_font_size_override("font_size", 11)
	_title_label.add_theme_color_override("font_color", Color("#9aa0ac"))
	vbox.add_child(_title_label)
	
	_grid = GridContainer.new()
	_grid.columns = MAX_PER_ROW
	_grid.add_theme_constant_override("h_separation", 4)
	_grid.add_theme_constant_override("v_separation", 4)
	vbox.add_child(_grid)


# ── 刷新 ─────────────────────────────────────────

func _refresh() -> void:
	if _grid == null:
		return
	for child: Node in _grid.get_children():
		child.queue_free()
	
	var relics: Array[Dictionary] = PlayerState.relics
	if relics.is_empty():
		_title_label.text = "遗物（暂无）"
		return
	_title_label.text = "遗物 x%d" % relics.size()
	
	for r: Dictionary in relics:
		var def: RelicDef = GameData.get_relic_def(r.get("id", ""))
		if def == null:
			continue
		_grid.add_child(_build_icon(def, r))


# ── 图标构建 ─────────────────────────────────────

func _build_icon(def: RelicDef, instance: Dictionary) -> Control:
	var color: Color = RARITY_COLOR.get(def.rarity, Color.WHITE)
	var emoji: String = RARITY_EMOJI.get(def.rarity, "⚪")
	
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#1a1e2a")
	style.border_color = color
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	box.add_theme_stylebox_override("panel", style)
	
	var label := Label.new()
	label.text = emoji
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(label)
	
	# 右上角计数角标（如有）
	var counter: int = int(instance.get("counter", 0))
	if counter > 0:
		var badge := Label.new()
		badge.text = "%d" % counter
		badge.add_theme_font_size_override("font_size", 9)
		badge.add_theme_color_override("font_color", Color("#ffe066"))
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		badge.offset_left = -12
		badge.offset_top = -12
		badge.offset_right = -2
		badge.offset_bottom = -2
		box.add_child(badge)
	
	# Tooltip 挂载（闭包捕获 def + instance）
	box.mouse_entered.connect(_on_icon_hover.bind(def, instance, box))
	box.mouse_exited.connect(_on_icon_exit)
	box.gui_input.connect(_on_icon_input)
	return box


func _on_icon_hover(def: RelicDef, instance: Dictionary, node: Control) -> void:
	var text: String = _build_tooltip_text(def, instance)
	# 锚定到图标右下角，避免遮挡自身
	var pos: Vector2 = node.global_position + Vector2(node.size.x + 8, 0)
	Tooltip.show_text(text, pos)


func _on_icon_exit() -> void:
	Tooltip.hide_tip()


func _on_icon_input(event: InputEvent) -> void:
	# 点击打开完整遗物图鉴
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_open_full_guide()


func _open_full_guide() -> void:
	const RelicGuideRef := preload("res://common/ui/relic_guide.gd")
	ModalHubRef.open(RelicGuideRef.new(), "遗物图鉴", {"size": Vector2(560, 780)})


# ── Tooltip 文本构建 ─────────────────────────────

static func _build_tooltip_text(def: RelicDef, instance: Dictionary) -> String:
	var rarity_label: String = ["普通", "精良", "稀有", "传说"][def.rarity] if def.rarity < 4 else "?"
	var trigger_label: String = TRIGGER_LABEL.get(def.trigger, "")
	var lines: Array[String] = []
	lines.append("【%s】· %s" % [def.name, rarity_label])
	if trigger_label != "":
		lines.append("触发：%s" % trigger_label)
	# 计数/层数
	var level: int = int(instance.get("level", 1))
	var counter: int = int(instance.get("counter", 0))
	if level > 1:
		lines.append("层数：%d" % level)
	if counter > 0:
		var lbl: String = def.counter_label if def.counter_label != "" else "计数"
		if def.max_counter > 0:
			lines.append("%s：%d / %d" % [lbl, counter, def.max_counter])
		else:
			lines.append("%s：%d" % [lbl, counter])
	if def.description != "":
		lines.append("")
		lines.append(def.description)
	lines.append("")
	lines.append("〔左键 · 打开完整图鉴〕")
	return "\n".join(lines)
