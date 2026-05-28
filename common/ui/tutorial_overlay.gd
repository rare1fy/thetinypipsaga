## 新手引导 — 分步教程覆盖层
## 迁移自 React 版 TutorialOverlay.tsx

class_name TutorialOverlay
extends VBoxContainer

const ModalHubRef := preload("res://common/ui/modal_hub.gd")

# ============================================================
# 教程步骤
# ============================================================

const TUTORIAL_STEPS: Array[Dictionary] = [
	{
		"id": "welcome",
		"title": "* 欢迎来到六面史诗 *",
		"icon": "★",
		"content": "在这片被永夜笼罩的大陆上，你将用骰子组合牌型，击败沿途的敌人，穿越5个大关，拯救世界。",
	},
	{
		"id": "map",
		"title": "* 地图探索 *",
		"icon": "📖",
		"content": "每个大关有一张随机生成的地图。节点类型包括：\n[战] — 击败敌人获取金币\n[精] — 强敌，奖励丰厚\n[BOSS] — 关卡守关者\n[商] — 购买遗物和骰子\n[火] — 回复生命或升级牌型\n[事] — 随机遭遇\n[箱] — 免费获取奖励",
	},
	{
		"id": "dice",
		"title": "* 骰子与元素 *",
		"icon": "[D]",
		"content": "战斗时自动从骰子库抽取手牌。骰子分多种类型：\n• 普通骰子 — 标准1-6\n• 灌铅骰子 — 只出4/5/6\n• 元素骰子 — 随机附带火/冰/雷/毒/圣元素\n• 锋刃/倍增/分裂等 — 各有特殊效果\n击败Boss和战斗后可获取新骰子扩充骰子库。",
	},
	{
		"id": "hands",
		"title": "* 牌型系统 *",
		"icon": "🃏",
"content": "选中骰子组合成牌型，牌型决定基础伤害和倍率：\n• 普通攻击 — 任意骰子\n• 对子/连对/三连对 — 相同点数配对\n• 三条/四条/五条/六条 — 更多相同点数\n• 顺子/4顺/5顺/6顺 — 连续点数\n• 葫芦/大葫芦 — 三条+对子组合\n牌型等级可在篝火升级，提升倍率。",
	},
	{
		"id": "play",
		"title": "* 出牌与重Roll *",
		"icon": "▶",
		"content": "选中想要打出的骰子 → 点击「出牌」攻击敌人。\n每回合有固定出牌次数，用完后轮到敌人行动。\n\n想换骰子？选中不要的骰子 → 点「重Roll」重新投掷。\n首次重Roll免费，之后消耗HP（代价逐渐递增）。",
	},
	{
		"id": "relics",
		"title": "* 遗物系统 *",
		"icon": "⚡",
		"content": "遗物是你的被动能力，打出特定牌型时自动触发。\n击败精英和Boss后可获得遗物，商店也能购买。\n\n战斗中，伤害预览卡片下方会显示当前牌型激活了哪些遗物。\n点「遗物库」按钮可查看你的全部遗物。",
	},
	{
		"id": "combat",
		"title": "* 战斗要点 *",
		"icon": "⚔",
		"content": "• 注意敌人头顶的意图图标（攻击/防御/施法）\n• 护甲在敌人攻击前抵挡伤害，每回合刷新\n• 元素效果：火破甲、冰冻结、雷AOE、毒持续、圣回血\n• Boss战分多波，每波击败后自动进入下一波\n• 击败Boss获得额外手牌上限+1",
	},
	{
		"id": "economy",
		"title": "* 经济与构筑 *",
		"icon": "💰",
		"content": "• 金币 — 在商店购买遗物和骰子\n• 骰子构筑 — 每场战斗后可选取新骰子\n• 同种骰子重复获取可升级（最高Lv.3）\n• 合理搭配骰子+遗物，打造你的专属流派！",
	},
	{
		"id": "ready",
		"title": "* 准备出发 *",
		"icon": "🔥",
		"content": "穿越幽暗森林、冰封山脉、熔岩深渊、暗影要塞，直到永恒之巅。\n\n每一关都有独特的敌人和Boss等待着你。\n骰运亨通，勇士！",
	},
]

const TUTORIAL_SAVE_KEY: String = "tutorial_completed"

# ============================================================
# 状态
# ============================================================

var _current_step: int = 0
var _content_label: Label
var _title_label: Label
var _icon_label: Label
var _progress_bar: ProgressBar
var _step_counter: Label
var _prev_btn: Button
var _next_btn: Button

signal tutorial_completed

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	add_theme_constant_override("separation", 12)
	_build_ui()
	_update_step()


# ============================================================
# 构建 UI
# ============================================================

func _build_ui() -> void:
	# 进度条
	_progress_bar = ProgressBar.new()
	_progress_bar.min_value = 0
	_progress_bar.max_value = TUTORIAL_STEPS.size()
	_progress_bar.value = 1
	_progress_bar.custom_minimum_size = Vector2(0, 8)
	_progress_bar.show_percentage = false
	add_child(_progress_bar)
	
	# 步骤计数
	_step_counter = Label.new()
	_step_counter.add_theme_color_override("font_color", Color("#9aa0ac"))
	_step_counter.add_theme_font_size_override("font_size", 10)
	_step_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_step_counter)
	
	# 图标
	_icon_label = Label.new()
	_icon_label.add_theme_font_size_override("font_size", 32)
	_icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_icon_label)
	
	# 标题
	_title_label = Label.new()
	_title_label.add_theme_color_override("font_color", Color("#d4a030"))
	_title_label.add_theme_font_size_override("font_size", 16)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_title_label)
	
	# 内容
	_content_label = Label.new()
	_content_label.add_theme_color_override("font_color", Color("#b0b8c8"))
	_content_label.add_theme_font_size_override("font_size", 12)
	_content_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_content_label)
	
	# 导航按钮
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	
	_prev_btn = Button.new()
	_prev_btn.text = "◀ 上一步"
	_prev_btn.pressed.connect(_on_prev)
	btn_row.add_child(_prev_btn)
	
	_next_btn = Button.new()
	_next_btn.text = "下一步 ▶"
	_next_btn.pressed.connect(_on_next)
	btn_row.add_child(_next_btn)
	
	add_child(btn_row)
	
	# 跳过按钮
	var skip_btn := Button.new()
	skip_btn.text = "跳过教程"
	skip_btn.add_theme_color_override("font_color", Color("#9aa0ac"))
	skip_btn.add_theme_font_size_override("font_size", 10)
	skip_btn.pressed.connect(_on_skip)
	add_child(skip_btn)


# ============================================================
# 步骤导航
# ============================================================

func _update_step() -> void:
	var step: Dictionary = TUTORIAL_STEPS[_current_step]
	_title_label.text = String(step.title)
	_content_label.text = String(step.content)
	_icon_label.text = String(step.icon)
	_progress_bar.value = _current_step + 1
	_step_counter.text = "[%d/%d]" % [_current_step + 1, TUTORIAL_STEPS.size()]
	
	_prev_btn.visible = _current_step > 0
	_next_btn.text = "开始游戏！" if _current_step == TUTORIAL_STEPS.size() - 1 else "下一步 ▶"


func _on_prev() -> void:
	if _current_step > 0:
		_current_step -= 1
		_update_step()


func _on_next() -> void:
	if _current_step < TUTORIAL_STEPS.size() - 1:
		_current_step += 1
		_update_step()
	else:
		_complete_tutorial()


func _on_skip() -> void:
	_complete_tutorial()


func _complete_tutorial() -> void:
	# 标记教程已完成
	var meta: Dictionary = SaveManager.load_meta()
	meta[TUTORIAL_SAVE_KEY] = true
	SaveManager.save_meta(meta)
	
	tutorial_completed.emit()
	ModalHubRef.close_all()


# ============================================================
# 静态工具
# ============================================================

static func is_tutorial_completed() -> bool:
	var meta: Dictionary = SaveManager.load_meta()
	return bool(meta.get(TUTORIAL_SAVE_KEY, false))


static func reset_tutorial() -> void:
	var meta: Dictionary = SaveManager.load_meta()
	meta.erase(TUTORIAL_SAVE_KEY)
	SaveManager.save_meta(meta)
