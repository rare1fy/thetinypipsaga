## 战斗日志（数据层 + 可选 UI）
##
## 职责：
##   1. 静态 API 收集战斗日志（`BattleLog.log_write(text, color)`）
##   2. 数据保存在 `_lines: Array[Dictionary]`，即使 UI 隐藏/不存在也照常收集
##   3. UI 显示作为可选能力，通过 `visible = false` 隐藏（节点仍挂在场景里做数据收集）
##   4. 外部（例如 SettingsPanel）可通过静态 `get_snapshot()` 读取日志数据快照
##
## 用法：
##   在战斗场景挂一个 BattleLog 节点，自动注册为 _instance
##   现在战斗内默认 visible = false（日志下沉到设置面板查看）
##
## 关闭时自动反注册，不泄漏

class_name BattleLog
extends PanelContainer


const MAX_LINES: int = 200            ## 最多保留条数，超出删最旧的
const LINE_FONT_SIZE: int = 12
const PANEL_WIDTH: float = 240.0

## 预设颜色
const COLOR_PLAYER: Color = Color("#f0c850")
const COLOR_ENEMY: Color = Color("#f07050")
const COLOR_DICE: Color = Color("#60e0a0")
const COLOR_STATUS: Color = Color("#c090f0")
const COLOR_RELIC: Color = Color("#e8c040")
const COLOR_NEUTRAL: Color = Color("#b0b8c8")

static var _instance: BattleLog = null


# ── 静态 API（数据层） ──────────────────────────────

## 写一行日志（battle_controller / resolver / applier 调用）
## 注意方法名不能叫 log — 会和 GDScript 内置 log(float) 冲突
static func log_write(text: String, color: Color = COLOR_NEUTRAL) -> void:
	if _instance == null or not is_instance_valid(_instance):
		return
	_instance._append(text, color)


static func log_player(text: String) -> void:
	log_write(text, COLOR_PLAYER)


static func log_enemy(text: String) -> void:
	log_write(text, COLOR_ENEMY)


static func log_dice(text: String) -> void:
	log_write(text, COLOR_DICE)


static func log_status(text: String) -> void:
	log_write(text, COLOR_STATUS)


static func log_relic(text: String) -> void:
	log_write(text, COLOR_RELIC)


## 清空日志
static func clear() -> void:
	if _instance == null or not is_instance_valid(_instance):
		return
	_instance._clear()


## 获取当前日志快照（SettingsPanel 渲染用）
## 返回：Array[{ "text": String, "color": Color }]
static func get_snapshot() -> Array[Dictionary]:
	if _instance == null or not is_instance_valid(_instance):
		return []
	var out: Array[Dictionary] = []
	out.assign(_instance._lines)
	return out


## 是否存在活动的日志收集器（SettingsPanel 判定是否显示"查看战斗日志"按钮用）
static func has_instance() -> bool:
	return _instance != null and is_instance_valid(_instance)


# ── 实例状态 ────────────────────────────────────────

var _lines: Array[Dictionary] = []   # [{text, color}, ...]
var _scroll: ScrollContainer = null
var _vbox: VBoxContainer = null
var _toggle_btn: Button = null
var _collapsed: bool = false


# ── 生命周期 ────────────────────────────────────────

func _ready() -> void:
	_instance = self
	_build_ui()


func _exit_tree() -> void:
	if _instance == self:
		_instance = null


# ── UI 构建（隐藏时也要构建：否则 visible 切换后无法展示） ──

func _build_ui() -> void:
	# 面板背景
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.05, 0.08, 0.85)
	style.border_color = Color("#3c4c6c")
	style.set_border_width_all(1)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	add_theme_stylebox_override("panel", style)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 4)
	add_child(outer)

	# 顶部 Header（标题 + 折叠按钮）
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 4)
	outer.add_child(header)

	var title := Label.new()
	title.text = "战斗日志"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color("#c8d0e8"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	_toggle_btn = Button.new()
	_toggle_btn.text = "—"
	_toggle_btn.flat = true
	_toggle_btn.custom_minimum_size = Vector2(20, 20)
	_toggle_btn.add_theme_font_size_override("font_size", 12)
	_toggle_btn.pressed.connect(_on_toggle)
	header.add_child(_toggle_btn)

	# 内容滚动区
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(PANEL_WIDTH - 20, 240)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(_scroll)

	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 2)
	_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_vbox)


func _append(text: String, color: Color) -> void:
	# 1. 数据层：存入 _lines
	_lines.append({"text": text, "color": color})
	while _lines.size() > MAX_LINES:
		_lines.pop_front()

	# 2. UI 层：visible==false 时也添加节点，保证 visible 切回时内容立即可见
	if _vbox == null:
		return
	var line := Label.new()
	line.text = text
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.add_theme_font_size_override("font_size", LINE_FONT_SIZE)
	line.add_theme_color_override("font_color", color)
	line.custom_minimum_size = Vector2(PANEL_WIDTH - 30, 0)
	_vbox.add_child(line)
	while _vbox.get_child_count() > MAX_LINES:
		_vbox.get_child(0).queue_free()
	# 可见时滚到底（隐藏时不必等 layout，节省一次帧等待）
	if not visible:
		return
	await get_tree().process_frame
	if is_instance_valid(_scroll):
		_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)


func _clear() -> void:
	_lines.clear()
	if _vbox == null:
		return
	for child: Node in _vbox.get_children():
		child.queue_free()


func _on_toggle() -> void:
	_collapsed = not _collapsed
	if _scroll != null:
		_scroll.visible = not _collapsed
	if _toggle_btn != null:
		_toggle_btn.text = "+" if _collapsed else "—"
