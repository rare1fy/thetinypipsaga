## 战后遗物选择界面 — 三选一

extends Node2D

@onready var relic_container: HBoxContainer = %RelicContainer
@onready var desc_label: RichTextLabel = %DescLabel
@onready var skip_btn: Button = %SkipBtn

var _choices: Array[Dictionary] = []
var _selected_idx: int = -1


func _ready() -> void:
	GameManager.phase_changed.connect(_on_phase_changed)
	skip_btn.pressed.connect(_on_skip)
	_on_phase_changed(GameManager.phase)


func _on_phase_changed(new_phase: GameTypes.GamePhase) -> void:
	visible = new_phase == GameTypes.GamePhase.SKILL_SELECT
	if visible:
		_generate_choices()
		_render_choices()
		VFX.fade_in(desc_label, 0.3)
		VFX.slide_in_from_bottom(relic_container, 20.0, 0.3, 0.1)


func _generate_choices() -> void:
	_choices.clear()
	_selected_idx = -1
	
	# 生成3个不同稀有度的遗物选项
	var rarities: Array[int] = [GameTypes.RelicRarity.COMMON, GameTypes.RelicRarity.UNCOMMON, GameTypes.RelicRarity.RARE]
	var hp_costs: Dictionary = {
		GameTypes.RelicRarity.COMMON: 5,
		GameTypes.RelicRarity.UNCOMMON: 10,
		GameTypes.RelicRarity.RARE: 15,
	}
	
	for rarity in rarities:
		var available: Array[RelicDef] = _get_relics_by_rarity(rarity)
		if available.is_empty():
			continue
		var chosen: RelicDef = available[randi() % available.size()]
		_choices.append({
			"relic_def": chosen,
			"rarity": rarity,
			"hp_cost": hp_costs.get(rarity, 5),
		})


func _get_relics_by_rarity(rarity: GameTypes.RelicRarity) -> Array[RelicDef]:
	var result: Array[RelicDef] = []
	var owned_ids: Array[String] = []
	for r: Dictionary in GameManager.relics:
		owned_ids.append(r.get("id", ""))
	
	var all_relics: Array[RelicDef] = []
	all_relics.assign(GameData._relic_defs.values())
	for relic: RelicDef in all_relics:
		if relic.rarity == rarity and not relic.id in owned_ids:
			result.append(relic)
	return result


func _render_choices() -> void:
	# 清除旧按钮
	for child in relic_container.get_children():
		child.queue_free()
	
	if _choices.is_empty():
		desc_label.text = "没有可选的遗物。"
		return
	
	desc_label.text = "[b]选择一件起始遗物[/b]\n不同稀有度需要付出不同的生命代价。\n\n"
	
	for i: int in _choices.size():
		var choice: Dictionary = _choices[i]
		var relic: RelicDef = choice.relic_def
		var rarity_label: String = _rarity_text(choice.rarity)
		
		var btn := Button.new()
		btn.text = "%s\n%s\n-%d HP" % [relic.name, rarity_label, choice.hp_cost]
		btn.tooltip_text = relic.description
		btn.custom_minimum_size = Vector2(160, 100)
		btn.pressed.connect(_on_relic_selected.bind(i))
		relic_container.add_child(btn)


func _rarity_text(rarity: String) -> String:
	match rarity:
		"common":
			return "[普通]"
		"uncommon":
			return "[稀有]"
		"rare":
			return "[史诗]"
		_:
			return "[???]"


func _on_relic_selected(idx: int) -> void:
	if idx < 0 or idx >= _choices.size():
		return
	
	var choice: Dictionary = _choices[idx]
	var relic: RelicDef = choice.relic_def
	var hp_cost: int = choice.hp_cost
	
	# 扣除HP代价
	GameManager.take_damage(hp_cost)
	
	# 添加遗物
	GameManager.relics.append({"id": relic.id, "level": 1})
	
	VFX.show_toast("获得遗物: %s (-%d HP)" % [relic.name, hp_cost], "buff")
	SoundPlayer.play_sound("relic_pickup")
	
	# 进入地图
	GameManager.set_phase(GameTypes.GamePhase.MAP)


func _on_skip() -> void:
	VFX.show_toast("跳过了遗物选择", "damage")
	GameManager.set_phase(GameTypes.GamePhase.MAP)
