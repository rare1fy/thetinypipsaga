## 骰子奖励选择界面

extends Control

@onready var dice_container: VBoxContainer = %DiceContainer
@onready var skip_btn: Button = %SkipBtn


func _ready() -> void:
	skip_btn.pressed.connect(_on_skip)
	GameManager.phase_changed.connect(_on_phase_changed)


func _on_phase_changed(new_phase: GameTypes.GamePhase) -> void:
	visible = new_phase == GameTypes.GamePhase.DICE_REWARD
	if visible:
		_generate_choices()
		VFX.slide_in_from_bottom(dice_container, 20.0, 0.3, 0.1)
		VFX.pop_in(skip_btn, 0.3, 0.3)


func _generate_choices() -> void:
	for child in dice_container.get_children():
		child.queue_free()
	
	var pool := GameData.get_dice_reward_pool("enemy", GameManager.player_class)
	var choices := GameData.pick_random_dice(pool, 3)
	
	for def in choices:
		var btn := Button.new()
		btn.text = "%s — %s" % [def.name, def.description]
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.pressed.connect(_on_pick.bind(def))
		dice_container.add_child(btn)


func _on_pick(def: DiceDef) -> void:
	GameManager.owned_dice.append({"defId": def.id, "level": 1})
	SoundPlayer.play_sound("dice_acquire")
	GameManager.set_phase(GameTypes.GamePhase.MAP)


func _on_skip() -> void:
	GameManager.set_phase(GameTypes.GamePhase.MAP)
