## 事件界面 — 随机事件选择

extends Node2D
@onready var event_label: RichTextLabel = %EventLabel
@onready var choice_container: VBoxContainer = %ChoiceContainer

# 事件图标映射
const ICON_MAP: Dictionary = {
	"skull": "💀",
	"star": "⭐",
	"flame": "🔥",
	"heart": "❤️",
	"shopBag": "🛍️",
	"refresh": "🔄",
	"question": "❓",
}


func _ready() -> void:
	GameManager.phase_changed.connect(_on_phase_changed)
	SoundPlayer.play_music("explore")
	_on_phase_changed(GameManager.phase)


func _on_phase_changed(new_phase: GameTypes.GamePhase) -> void:
	visible = new_phase == GameTypes.GamePhase.EVENT
	if visible:
		_show_random_event()
		VFX.fade_in(event_label, 0.3)
		VFX.slide_in_from_bottom(choice_container, 20.0, 0.3, 0.2)


func _show_random_event() -> void:
	# 从事件池中随机选择一个事件
	var pool: Array[Dictionary] = EventData.EVENTS_POOL
	var event: Dictionary = pool[randi() % pool.size()]
	
	# 清除旧选项按钮
	for child in choice_container.get_children():
		child.queue_free()
	
	# 显示事件标题和描述
	var icon: String = ICON_MAP.get(event.get("icon_id", "question"), "❓")
	event_label.text = "%s [b]%s[/b]\n\n%s" % [icon, event.title, event.desc]
	
	# 生成选项按钮
	for choice: Dictionary in event.options:
		var btn := Button.new()
		var label: String = choice.label
		# 替换牌型占位符
		if event.get("needs_random_hand_type", false):
			var hand_type: String = _get_random_hand_type()
			label = label.replace("{handType}", hand_type).replace("{hand_type}", hand_type)
		btn.text = label
		btn.tooltip_text = choice.get("sub", "")
		btn.pressed.connect(_on_choice_made.bind(choice, event))
		choice_container.add_child(btn)


func _get_random_hand_type() -> String:
	# 获取玩家当前拥有的随机非基础骰子名，作为文案占位替换
	var hand_types: Array[String] = []
	for dice_id: String in PlayerState.dice_bag:
		var dice_def: DiceDef = GameData.get_dice_def(dice_id)
		if dice_def and dice_def.rarity != GameTypes.DiceRarity.COMMON:
			hand_types.append(dice_def.name)
	if hand_types.is_empty():
		hand_types = ["攻击牌", "防御牌", "魔法牌"]
	return hand_types[randi() % hand_types.size()]


func _on_choice_made(choice: Dictionary, event: Dictionary) -> void:
	var action: Dictionary = choice.get("action", {"type": "noop"})
	var action_type: String = action.get("type", "noop")
	
	match action_type:
		"startBattle":
			# 事件触发战斗：仿 map_screen._spawn_battle 的 enemy 分支逻辑
			var normals := EnemyConfig.get_normals_for_chapter(GameManager.chapter)
			var wave_ids: Array[String] = []
			if normals.size() > 0:
				wave_ids.append(normals[randi() % normals.size()].id)
			if wave_ids.is_empty():
				# 兜底：无敌人可用，退回地图并提示，避免卡死
				push_warning("[Event] 本章无普通敌人，startBattle 降级为跳过")
				VFX.show_toast("战斗未触发（敌人池为空）", "damage")
				SoundPlayer.play_sound("event")
				GameManager.set_phase(GameTypes.GamePhase.MAP)
				return
			GameManager.pending_wave = wave_ids
			SoundPlayer.play_sound("event")
			GameManager.set_phase(GameTypes.GamePhase.BATTLE)
			return  # 切场景前别再执行下面的 set_phase(MAP)
		"modifyHp":
			var value: int = action.get("value", 0)
			if value > 0:
				GameManager.heal(value)
			else:
				GameManager.take_damage(-value)
		"modifySouls":
			var value: int = action.get("value", 0)
			if value > 0:
				GameManager.add_gold(value)
			else:
				GameManager.spend_gold(-value)
		"modifyMaxHp":
			var value: int = action.get("value", 0)
			GameManager.modify_max_hp(value)
		"upgradeHandType":
			var hp_cost: int = -action.get("value", 0)
			if hp_cost > 0:
				GameManager.take_damage(hp_cost)
			GameManager.upgrade_hand_type()
		"grantRelic":
			var all_relics: Array[RelicDef] = []
			all_relics.assign(GameData._relic_defs.values())
			if all_relics.size() > 0:
				var def: RelicDef = all_relics[randi() % all_relics.size()]
				GameManager.relics.append({"id": def.id, "level": 1})
				VFX.show_toast("获得遗物: %s" % def.name, "buff")
		"removeDice":
			# 移除一颗非基础骰子
			var non_basic_dice: Array[String] = []
			for dice_id: String in PlayerState.dice_bag:
				var dice_def: DiceDef = GameData.get_dice_def(dice_id)
				if dice_def and dice_def.rarity != GameTypes.DiceRarity.COMMON:
					non_basic_dice.append(dice_id)
			if non_basic_dice.size() > 0:
				var to_remove: String = non_basic_dice[randi() % non_basic_dice.size()]
				PlayerState.dice_bag.erase(to_remove)
				VFX.show_toast("骰子已熔炼: %s" % to_remove, "damage")
		"randomOutcome":
			var _outcomes: Array[Dictionary] = []
			_outcomes.assign(action.get("outcomes", []))
			_execute_random_outcome(_outcomes)
		"noop":
			pass
	
	# 显示 toast 提示
	if action.get("toast"):
		var toast_type: String = action.get("toast_type", "damage")
		VFX.show_toast(action.toast, toast_type)
	
	# 记录日志
	if action.get("log"):
		print("[Event] %s" % action.log)
	
	SoundPlayer.play_sound("event")
	GameManager.set_phase(GameTypes.GamePhase.MAP)


func _execute_random_outcome(outcomes: Array[Dictionary]) -> void:
	if outcomes.is_empty():
		return
	# 按权重选择一个结果
	var total_weight: float = 0.0
	for outcome: Dictionary in outcomes:
		total_weight += outcome.get("weight", 1.0)
	
	var roll: float = randf() * total_weight
	var cumulative: float = 0.0
	for outcome: Dictionary in outcomes:
		cumulative += outcome.get("weight", 1.0)
		if roll <= cumulative:
			# 执行该结果的所有 action
			for sub_action: Dictionary in outcome.get("actions", []):
				_execute_single_action(sub_action)
			# 显示结果 toast
			if outcome.get("toast"):
				VFX.show_toast(outcome.toast, outcome.get("toast_type", "damage"))
			# 记录结果日志
			if outcome.get("log"):
				print("[Event] %s" % outcome.log)
			break


func _execute_single_action(action: Dictionary) -> void:
	var action_type: String = action.get("type", "noop")
	match action_type:
		"modifyHp":
			var value: int = action.get("value", 0)
			if value > 0:
				GameManager.heal(value)
			else:
				GameManager.take_damage(-value)
		"modifySouls":
			var value: int = action.get("value", 0)
			if value > 0:
				GameManager.add_gold(value)
			else:
				GameManager.spend_gold(-value)
		"modifyMaxHp":
			GameManager.modify_max_hp(action.get("value", 0))
		"upgradeHandType":
			GameManager.upgrade_hand_type()
		"grantRelic":
			var all_relics: Array[RelicDef] = []
			all_relics.assign(GameData._relic_defs.values())
			if all_relics.size() > 0:
				var def: RelicDef = all_relics[randi() % all_relics.size()]
				GameManager.relics.append({"id": def.id, "level": 1})
		"removeDice":
			var non_basic_dice: Array[String] = []
			for dice_id: String in PlayerState.dice_bag:
				var dice_def: DiceDef = GameData.get_dice_def(dice_id)
				if dice_def and dice_def.rarity != GameTypes.DiceRarity.COMMON:
					non_basic_dice.append(dice_id)
			if non_basic_dice.size() > 0:
				var to_remove: String = non_basic_dice[randi() % non_basic_dice.size()]
				PlayerState.dice_bag.erase(to_remove)
		"noop":
			pass
