## 升级三选一弹窗
## 迁移自 React 版 LevelUpModal.tsx
## 监听 XpSystem.pending_level_ups，非空时弹出三选一

class_name LevelUpModal
extends VBoxContainer

const ModalHubRef := preload("res://common/ui/modal_hub.gd")
const XpSystemScript := preload("res://common/autoload/xp_system.gd")

# ============================================================
# 状态
# ============================================================

var _choices: Array = []
var _current_level: int = 0

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	add_theme_constant_override("separation", 12)


## 初始化并显示
func init(level: int, choices: Array) -> void:
	_current_level = level
	_choices = choices
	_build_ui()


# ============================================================
# 构建 UI
# ============================================================

func _build_ui() -> void:
	# 清空旧内容
	for child: Node in get_children():
		child.queue_free()
	
	# 标题
	var title := Label.new()
	title.text = "* LEVEL UP · Lv%d *" % _current_level
	title.add_theme_color_override("font_color", Color("#d4a030"))
	title.add_theme_font_size_override("font_size", 9)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	
	# 提示
	var hint := Label.new()
	hint.text = "选择一项永久成长"
	hint.add_theme_color_override("font_color", Color("#b0b8c8"))
	hint.add_theme_font_size_override("font_size", 6)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)
	
	# 三选一按钮
	for reward in _choices:
		add_child(_build_reward_card(reward))
	
	# 队列提示
	if XpSystem and XpSystem.pending_level_ups.size() > 1:
		var queue_hint := Label.new()
		queue_hint.text = "还有 %d 次升级待领取" % (XpSystem.pending_level_ups.size() - 1)
		queue_hint.add_theme_color_override("font_color", Color("#9aa0ac"))
		queue_hint.add_theme_font_size_override("font_size", 5)
		queue_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(queue_hint)


func _build_reward_card(reward: Variant) -> Control:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	var cat_color: Color = XpSystem.get_category_color(reward.category)
	style.bg_color = Color(0.04, 0.05, 0.06, 0.9)
	style.border_color = cat_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", style)
	
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	
	# 类别图标区
	var icon_box := PanelContainer.new()
	var icon_style := StyleBoxFlat.new()
	icon_style.bg_color = Color(0, 0, 0, 0.55)
	icon_style.border_color = cat_color.darkened(0.3)
	icon_style.set_border_width_all(2)
	icon_style.set_corner_radius_all(2)
	icon_box.add_theme_stylebox_override("panel", icon_style)
	icon_box.custom_minimum_size = Vector2(20, 20)
	var icon_label := Label.new()
	icon_label.text = _get_category_icon(reward.category)
	icon_label.add_theme_font_size_override("font_size", 10)
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_box.add_child(icon_label)
	hbox.add_child(icon_box)
	
	# 文字区
	var text_vbox := VBoxContainer.new()
	text_vbox.add_theme_constant_override("separation", 4)
	text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# 类别标签
	var cat_label := Label.new()
	cat_label.text = XpSystem.get_category_label(reward.category)
	cat_label.add_theme_color_override("font_color", cat_color)
	cat_label.add_theme_font_size_override("font_size", 5)
	text_vbox.add_child(cat_label)
	
	# 标题
	var title_lbl := Label.new()
	title_lbl.text = reward.title
	title_lbl.add_theme_color_override("font_color", cat_color.lightened(0.3))
	title_lbl.add_theme_font_size_override("font_size", 8)
	text_vbox.add_child(title_lbl)
	
	# 描述
	var desc := Label.new()
	desc.text = reward.description
	desc.add_theme_color_override("font_color", Color("#b0b8c8"))
	desc.add_theme_font_size_override("font_size", 6)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_vbox.add_child(desc)
	
	hbox.add_child(text_vbox)
	card.add_child(hbox)
	
	# 点击选择
	card.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
			_on_reward_picked(reward)
	)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	return card


# ============================================================
# 选择奖励
# ============================================================

func _on_reward_picked(reward: Variant) -> void:
	SoundPlayer.play_sound("click")
	reward.apply_fn.call()
	XpSystem.consume_level_up()
	VFX.show_toast("获得「%s」" % reward.title, "buff")
	
	# 关闭当前弹窗
	ModalHubRef.close()
	
	# 如果还有待领取的升级，延迟弹出下一个
	if XpSystem.has_pending_level_up():
		await get_tree().create_timer(0.3).timeout
		_show_next_level_up()


## 弹出下一个升级弹窗
static func _show_next_level_up() -> void:
	if not XpSystem or not XpSystem.has_pending_level_up():
		return
	var next_level: int = XpSystem.pending_level_ups[0]
	var choices: Array = XpSystem.get_level_up_choices()
	var modal := LevelUpModal.new()
	modal.init(next_level, choices)
	ModalHubRef.open(modal, "", {"size": Vector2(420, 520), "close_on_backdrop": false, "close_on_esc": false, "show_close_btn": false})


## 外部入口：检查并弹出升级弹窗
static func check_and_show() -> void:
	_show_next_level_up()


# ============================================================
# 工具
# ============================================================

static func _get_category_icon(category: int) -> String:
	# 0=SURVIVAL, 1=OFFENSE, 2=RESOURCE (matches XpSystem.RewardCategory enum)
	match category:
		0: return "H"
		1: return "X"
		2: return "G"
		_: return "?"
