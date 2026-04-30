## 战斗日志面板 — 右侧滚动条，记录关键战斗事件
## 用法：在战斗场景中挂一个 BattleLog 节点（Control），它会自动把自己注册成 _instance
##       其他模块通过 `BattleLog.log_write(text, color)` 静态 API 写日志
## 关闭时自动反注册，不泄漏

class_name BattleLog
extends PanelContainer


const MAX_LINES: int = 80             ## 最多保留条数，超出删最旧的
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


## 静态 API：写一行日志（battle_controller / resolver / applier 调用）
## 注意方法名不能叫 log — 会和 GDScript 内置 log(float) 冲突
static func log_write(text: String, color: Color = COLOR_NEUTRAL) -> void:
	if _instance == null or not is_instance_valid(_instance):
		return
	_instance._append(text, color)


## 玩家操作类
static func log_player(text: String) -> void:
	log_write(text, COLOR_PLAYER)


## 敌人行动类
static func log_enemy(text: String) -> void:
	log_write(text, COLOR_ENEMY)


## 骰子/牌型类
static func log_dice(text: String) -> void:
	log_write(text, COLOR_DICE)


## 状态效果类
static func log_status(text: String) -> void:
	log_write(text, COLOR_STATUS)


## 遗物触发类
static func log_relic(text: String) -> void:
	log_write(text, COLOR_RELIC)


## 清空日志（用于每场战斗开始）
static func clear() -> void:
	if _instance == null or not is_instance_valid(_instance):
		return
	_instance._clear()


var _scroll: ScrollContainer = null
var _vbox: VBoxContainer = null
var _toggle_btn: Button = null
var _collapsed: bool = false


func _ready() -> void:
	_instance = self
	_build_ui()


func _exit_tree() -> void:
	if _instance == self:
		_instance = null


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
	var line := Label.new()
	line.text = text
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.add_theme_font_size_override("font_size", LINE_FONT_SIZE)
	line.add_theme_color_override("font_color", color)
	line.custom_minimum_size = Vector2(PANEL_WIDTH - 30, 0)
	_vbox.add_child(line)
	# 超量移除最旧的
	while _vbox.get_child_count() > MAX_LINES:
		_vbox.get_child(0).queue_free()
	# 滚到底（延迟到下一帧，等待布局刷新）
	await get_tree().process_frame
	if is_instance_valid(_scroll):
		_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)


func _clear() -> void:
	for child: Node in _vbox.get_children():
		child.queue_free()


func _on_toggle() -> void:
	_collapsed = not _collapsed
	_scroll.visible = not _collapsed
	_toggle_btn.text = "+" if _collapsed else "—"
