## 事件界面 — 随机事件选择

extends Control

@onready var event_label: RichTextLabel = %EventLabel
@onready var choice_container: VBoxContainer = %ChoiceContainer

# 简单事件池
const EVENTS: Array[Dictionary] = [
	{
		"title": "古老神殿",
		"desc": "你发现了一座古老的神殿，石壁上刻着神秘的文字……",
		"choices": [
			{"text": "祈祷(+15 HP)", "effect": "heal", "value": 15},
			{"text": "搜索(获得30金币)", "effect": "gold", "value": 30},
			{"text": "离开", "effect": "none"},
		]
	},
	{
		"title": "受伤的旅人",
		"desc": "路边躺着一位受伤的旅人，他向你求助……",
		"choices": [
			{"text": "帮助(-10 HP, 获得遗物)", "effect": "trade_hp_relic", "value": 10},
			{"text": "无视", "effect": "none"},
		]
	},
	{
		"title": "神秘商人",
		"desc": "一个神秘的商人从暗处走出，向你展示他的货物……",
		"choices": [
			{"text": "购买(花费25金, +10 HP)", "effect": "buy_heal", "value": 25},
			{"text": "拒绝", "effect": "none"},
		]
	},
]


func _ready() -> void:
	GameManager.phase_changed.connect(_on_phase_changed)


func _on_phase_changed(new_phase: GameTypes.GamePhase) -> void:
	visible = new_phase == GameTypes.GamePhase.EVENT
	if visible:
		_show_random_event()
		VFX.fade_in(event_label, 0.3)
		VFX.slide_in_from_bottom(choice_container, 20.0, 0.3, 0.2)


func _show_random_event() -> void:
	var event: Dictionary = EVENTS[randi() % EVENTS.size()]
	
	for child in choice_container.get_children():
		child.queue_free()
	
	event_label.text = "[b]%s[/b]\n\n%s" % [event.title, event.desc]
	
	for choice: Dictionary in event.choices:
		var btn := Button.new()
		btn.text = choice.text
		btn.pressed.connect(_on_choice_made.bind(choice))
		choice_container.add_child(btn)


func _on_choice_made(choice: Dictionary) -> void:
	var effect: String = choice.get("effect", "none")
	var value: int = choice.get("value", 0)
	
	match effect:
		"heal":
			GameManager.heal(value)
		"gold":
			GameManager.add_gold(value)
		"trade_hp_relic":
			GameManager.take_damage(value)
			# 随机给一个遗物
			var all_relics: Array = GameData._relic_defs.values()
			if all_relics.size() > 0:
				var def: RelicDef = all_relics[randi() % all_relics.size()]
				GameManager.relics.append({"id": def.id, "level": 1})
		"buy_heal":
			if GameManager.spend_gold(value):
				GameManager.heal(10)
	
	SoundPlayer.play_sound("event")
	GameManager.set_phase(GameTypes.GamePhase.MAP)
