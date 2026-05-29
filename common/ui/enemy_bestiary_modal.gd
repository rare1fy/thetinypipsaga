## 敌人图鉴 — 按章节分页展示所有敌人
## 迁移自 React 版 EnemyBestiary.tsx

class_name EnemyBestiaryModal
extends VBoxContainer

# ============================================================
# 常量
# ============================================================

const COMBAT_LABELS: Dictionary = {
	"warrior": {"label": "战", "color": Color("#e04040"), "full": "近战战士"},
	"guardian": {"label": "盾", "color": Color("#4080ff"), "full": "守护者"},
	"ranger": {"label": "弓", "color": Color("#40c040"), "full": "弓箭手"},
	"caster": {"label": "术", "color": Color("#9060d0"), "full": "法师"},
	"priest": {"label": "牧", "color": Color("#d4a030"), "full": "牧师"},
}

const ARCHETYPE_DESC: Dictionary = {
	"berserker": "【狂战】你每打他一次，攻击力+40%（最多4次）。队友死亡触发复仇+50%/层",
	"striker": "【突袭】血量≤70%时爆发，攻击+50%",
	"paladin": "【圣骑】攻击+20%，不会被激怒",
	"marksman": "【神射】追击伤害随命中次数翻倍+30%",
	"trapper": "【陷阱】每次攻击附带1层剧毒",
	"hunter": "【猎手】标准弓手",
	"bulwark": "【铁壁】防御获双倍护甲，不激怒",
	"enforcer": "【执法】每防御1回合，下次攻击+60%（最多3次）",
	"pyromancer": "【焚化】80%概率灼烧，每层放大+50%",
	"toxicologist": "【毒师】80%概率剧毒，每层放大+40%",
	"cursemaster": "【咒师】100%给你毒+虚弱双诅咒",
	"healer": "【治疗】优先治疗友军→自疗→护甲→减益",
	"inquisitor": "【审判】不治疗，50%概率虚弱+易伤",
}

# ============================================================
# 状态
# ============================================================

var _current_chapter: int = 1
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
	title.text = "敌人图鉴"
	title.add_theme_color_override("font_color", Color("#e6e8f0"))
	title.add_theme_font_size_override("font_size", 12)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	
	# 章节标签栏
	_tab_container = HBoxContainer.new()
	_tab_container.add_theme_constant_override("separation", 4)
	_tab_container.alignment = BoxContainer.ALIGNMENT_CENTER
	
	var chapter_names: Array = GameBalance.CHAPTER_CONFIG.get("chapterNames", [])
	for i: int in chapter_names.size():
		var btn := Button.new()
		btn.text = String(chapter_names[i])
		btn.add_theme_font_size_override("font_size", 12)
		var ch: int = i + 1
		btn.pressed.connect(func():
			_current_chapter = ch
			_refresh_list()
			_update_tab_styles()
		)
		btn.set_meta("chapter", ch)
		_tab_container.add_child(btn)
	
	add_child(_tab_container)
	_update_tab_styles()
	
	# 内容区
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(4, 200)
	
	_content_container = VBoxContainer.new()
	_content_container.add_theme_constant_override("separation", 4)
	scroll.add_child(_content_container)
	add_child(scroll)


func _update_tab_styles() -> void:
	for child: Node in _tab_container.get_children():
		if child is Button:
			var btn := child as Button
			var ch: int = int(btn.get_meta("chapter"))
			if ch == _current_chapter:
				btn.modulate = Color.WHITE
			else:
				btn.modulate = Color(1, 1, 1, 0.5)


# ============================================================
# 刷新列表
# ============================================================

func _refresh_list() -> void:
	for child: Node in _content_container.get_children():
		child.queue_free()
	
	var all_enemies: Array[Dictionary] = _get_all_enemies()
	var chapter_enemies: Array[Dictionary] = []
	for e: Dictionary in all_enemies:
		if int(e.get("chapter", 0)) == _current_chapter:
			chapter_enemies.append(e)
	
	# 按类别分组
	_add_category_section(chapter_enemies, "normal", "— 普通敌人 —", Color("#9aa0ac"))
	_add_category_section(chapter_enemies, "elite", "— 精英敌人 —", Color("#e09040"))
	_add_category_section(chapter_enemies, "boss", "— BOSS —", Color("#9060d0"))
	
	if chapter_enemies.is_empty():
		var hint := Label.new()
		hint.text = "该章节暂无敌人数据"
		hint.add_theme_color_override("font_color", Color("#9aa0ac"))
		hint.add_theme_font_size_override("font_size", 12)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_content_container.add_child(hint)


func _add_category_section(enemies: Array[Dictionary], category: String, title: String, color: Color) -> void:
	var filtered: Array[Dictionary] = []
	for e: Dictionary in enemies:
		if String(e.get("category", "")) == category:
			filtered.append(e)
	
	if filtered.is_empty():
		return
	
	var section_label := Label.new()
	section_label.text = title
	section_label.add_theme_color_override("font_color", color)
	section_label.add_theme_font_size_override("font_size", 12)
	section_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content_container.add_child(section_label)
	
	for e: Dictionary in filtered:
		_content_container.add_child(_build_enemy_row(e))


func _build_enemy_row(enemy: Dictionary) -> Button:
	var enemy_name: String = String(enemy.get("name", "?"))
	var combat_type: String = String(enemy.get("combatType", "warrior"))
	var base_hp: int = int(enemy.get("baseHp", 0))
	var base_dmg: int = int(enemy.get("baseDmg", 0))
	var category: String = String(enemy.get("category", "normal"))
	var archetype: String = String(enemy.get("archetype", ""))
	
	var ct: Dictionary = COMBAT_LABELS.get(combat_type, {"label": "?", "color": Color.WHITE})
	var cat_label: String = "普通"
	if category == "elite":
		cat_label = "精英"
	elif category == "boss":
		var boss_rank: String = String(enemy.get("bossRank", "mid"))
		cat_label = "终BOSS" if boss_rank == "final" else "中BOSS"
	
	var btn := Button.new()
	btn.text = "[%s] %s  %s  HP:%d ATK:%d" % [String(ct.label), enemy_name, cat_label, base_hp, base_dmg]
	btn.add_theme_color_override("font_color", ct.color as Color)
	btn.add_theme_font_size_override("font_size", 12)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.pressed.connect(func():
		_show_enemy_detail(enemy)
	)
	return btn


# ============================================================
# 敌人详情
# ============================================================

const ModalHubRef := preload("res://common/ui/modal_hub.gd")

func _show_enemy_detail(enemy: Dictionary) -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	
	var enemy_name: String = String(enemy.get("name", "?"))
	var combat_type: String = String(enemy.get("combatType", "warrior"))
	var base_hp: int = int(enemy.get("baseHp", 0))
	var base_dmg: int = int(enemy.get("baseDmg", 0))
	var category: String = String(enemy.get("category", "normal"))
	var archetype: String = String(enemy.get("archetype", ""))
	
	# 标题
	var title := Label.new()
	title.text = enemy_name
	title.add_theme_color_override("font_color", Color("#e6e8f0"))
	title.add_theme_font_size_override("font_size", 12)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	# 基础信息
	var ct: Dictionary = COMBAT_LABELS.get(combat_type, {"full": combat_type})
	_add_detail_section(vbox, "基础信息", [
		"种类：%s" % String(ct.get("full", combat_type)),
		"生命：%d　基础攻击：%d" % [base_hp, base_dmg],
	])
	
	# 种族特性
	if archetype != "" and ARCHETYPE_DESC.has(archetype):
		_add_detail_section(vbox, "种族特性", [String(ARCHETYPE_DESC[archetype])])
	
	# 战斗行为（phases）
	var phases: Array = enemy.get("phases", [])
	if not phases.is_empty():
		var lines: Array[String] = []
		var multi_phase: bool = phases.size() > 1
		for i: int in phases.size():
			var phase: Dictionary = phases[i]
			if multi_phase:
				var threshold: float = float(phase.get("hpThreshold", 0.0))
				if threshold > 0:
					lines.append("* 阶段 %d（HP ≥ %d%%）" % [i + 1, int(threshold * 100)])
				else:
					lines.append("* 阶段 %d" % (i + 1))
			var actions: Array = phase.get("actions", [])
			var action_strs: Array[String] = []
			for a: Dictionary in actions:
				action_strs.append(_describe_action(enemy, a))
			lines.append("  →  ".join(action_strs))
			if actions.size() > 1:
				lines.append("  └ 以上 %d 步循环" % actions.size())
		_add_detail_section(vbox, "战斗行为", lines)
	
	# 召唤
	var summons: Dictionary = enemy.get("summons", {})
	if not summons.is_empty():
		var interval: int = int(summons.get("interval", 3))
		var count: int = int(summons.get("count", 1))
		var minion_id: String = String(summons.get("minionId", "?"))
		_add_detail_section(vbox, "召唤机制", [
			"每 %d 回合召唤 %d 只【%s】" % [interval, count, minion_id],
		])
	
	# 复活/分裂
	var revive: Dictionary = enemy.get("revive", {})
	if not revive.is_empty():
		var split_into: int = int(revive.get("splitInto", 0))
		var hp_ratio: float = float(revive.get("reviveHpRatio", 0.5))
		if split_into > 0:
			_add_detail_section(vbox, "分裂机制", [
				"死亡时分裂为 %d 只，每只 %d%% HP" % [split_into, int(hp_ratio * 100)],
			])
		else:
			_add_detail_section(vbox, "复活机制", [
				"死亡时复活，回血至 %d%% HP" % int(hp_ratio * 100),
			])
	
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(192, 224)
	scroll.add_child(vbox)
	
	ModalHubRef.open(scroll, enemy_name, {"size": Vector2(420, 520), "close_on_backdrop": true})


func _add_detail_section(parent: VBoxContainer, title: String, lines: Array) -> void:
	var section_title := Label.new()
	section_title.text = "— %s —" % title
	section_title.add_theme_color_override("font_color", Color("#d4a030"))
	section_title.add_theme_font_size_override("font_size", 12)
	parent.add_child(section_title)
	
	for line in lines:
		var label := Label.new()
		label.text = String(line)
		label.add_theme_color_override("font_color", Color("#b0b8c8"))
		label.add_theme_font_size_override("font_size", 12)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		parent.add_child(label)


func _describe_action(enemy: Dictionary, action: Dictionary) -> String:
	var a_type: String = String(action.get("type", ""))
	var base_value: int = int(action.get("baseValue", 0))
	var desc: String = String(action.get("description", ""))
	var combat_type: String = String(enemy.get("combatType", ""))
	
	if a_type == "防御":
		return "[守] +%d 护甲" % base_value
	elif a_type == "攻击":
		if combat_type in ["caster", "priest"]:
			return "[法] %s" % (desc if desc != "" else "蓄力")
		return "[攻] %d 伤害%s" % [base_value, "(%s)" % desc if desc != "" else ""]
	elif a_type == "技能":
		return "[技] %s ×%d" % [desc if desc != "" else "技能", base_value]
	return "%s %d" % [a_type, base_value]


# ============================================================
# 获取所有敌人配置
# ============================================================

func _get_all_enemies() -> Array[Dictionary]:
	# 从 GameData / ConfigLoader 获取所有敌人配置
	var result: Array[Dictionary] = []
	var all_enemies: Dictionary = GameData.get_all_enemies()
	for enemy_id: String in all_enemies:
		result.append(all_enemies[enemy_id])
	return result
