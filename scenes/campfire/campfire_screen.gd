## 营火界面 — 休整 / 强化骰子 / 净化骰子 / 遗物升级
## 完整复刻 React 版 CampfireScreen + CampfireUpgradeView + CampfirePurifyView

extends Node2D

enum CampAction { NONE, REST, UPGRADE_DICE, PURIFY_DICE, UPGRADE_RELIC }

@onready var rest_btn: Button = %RestBtn
@onready var upgrade_dice_btn: Button = %UpgradeDiceBtn
@onready var purify_dice_btn: Button = %PurifyDiceBtn
@onready var back_btn: Button = %BackBtn
@onready var info_label: Label = %InfoLabel
@onready var relic_list: VBoxContainer = %RelicList
@onready var dice_list: VBoxContainer = %DiceList
@onready var dice_preview: VBoxContainer = %DicePreview
@onready var confirm_btn: Button = %ConfirmBtn

var _action_used: bool = false
var _current_action: CampAction = CampAction.NONE
var _selected_dice_idx: int = -1


func _ready() -> void:
	rest_btn.pressed.connect(_on_rest)
	upgrade_dice_btn.pressed.connect(_on_upgrade_dice_mode)
	purify_dice_btn.pressed.connect(_on_purify_dice_mode)
	back_btn.pressed.connect(_on_back)
	confirm_btn.pressed.connect(_on_confirm)
	GameManager.phase_changed.connect(_on_phase_changed)
	SoundPlayer.play_music("explore")
	_on_phase_changed(GameManager.phase)


func _on_phase_changed(new_phase: GameTypes.GamePhase) -> void:
	visible = new_phase == GameTypes.GamePhase.CAMPFIRE
	if visible:
		_action_used = false
		_current_action = CampAction.NONE
		_selected_dice_idx = -1
		_refresh_main_ui()


func _refresh_main_ui() -> void:
	info_label.text = "※ 营地只能选择一项行动 ※"
	
	rest_btn.disabled = _action_used or GameManager.hp >= GameManager.max_hp
	upgrade_dice_btn.disabled = _action_used
	purify_dice_btn.disabled = _action_used or PlayerState.dice_bag.size() <= 6
	
	# 隐藏子面板
	dice_list.visible = false
	dice_preview.visible = false
	confirm_btn.visible = false
	
	# 显示遗物升级列表
	_refresh_relic_list()


func _refresh_relic_list() -> void:
	for child in relic_list.get_children():
		child.queue_free()
	
	for i in GameManager.relics.size():
		var r: Dictionary = GameManager.relics[i]
		var def: RelicDef = GameData.get_relic_def(r.id)
		if not def:
			continue
		var level: int = r.get("level", 1)
		if level >= GameBalance.CAMPFIRE_CONFIG.maxRelicLevel:
			continue
		var cost := level * GameBalance.CAMPFIRE_CONFIG.upgradeCostPerLevel
		var hbox := HBoxContainer.new()
		var name_l := Label.new()
		name_l.text = "%s Lv%d→%d (%d金)" % [def.name, level, level + 1, cost]
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var upgrade_btn := Button.new()
		upgrade_btn.text = "升级"
		upgrade_btn.disabled = _action_used
		upgrade_btn.pressed.connect(_on_upgrade_relic.bind(i, cost))
		hbox.add_child(name_l)
		hbox.add_child(upgrade_btn)
		relic_list.add_child(hbox)


func _on_rest() -> void:
	if _action_used:
		return
	GameManager.heal(GameBalance.CAMPFIRE_CONFIG.restHeal)
	SoundPlayer.play_sound("heal")
	VFX.show_toast("篝火休整 +%d HP" % GameBalance.CAMPFIRE_CONFIG.restHeal, "buff")
	_action_used = true
	_leave_campfire()


func _on_upgrade_relic(index: int, cost: int) -> void:
	if _action_used:
		return
	if not GameManager.spend_gold(cost):
		SoundPlayer.play_sound("error")
		VFX.show_toast("金币不足", "damage")
		return
	GameManager.relics[index]["level"] = GameManager.relics[index].get("level", 1) + 1
	SoundPlayer.play_sound("upgrade")
	VFX.show_toast("遗物升级成功", "buff")
	_action_used = true
	_leave_campfire()


# ===== 骰子升级模式 =====

func _on_upgrade_dice_mode() -> void:
	if _action_used:
		return
	_current_action = CampAction.UPGRADE_DICE
	_selected_dice_idx = -1
	_show_dice_list(true)


func _on_purify_dice_mode() -> void:
	if _action_used:
		return
	_current_action = CampAction.PURIFY_DICE
	_selected_dice_idx = -1
	_show_dice_list(false)


func _show_dice_list(is_upgrade: bool) -> void:
	dice_list.visible = true
	dice_preview.visible = false
	confirm_btn.visible = false
	
	for child in dice_list.get_children():
		child.queue_free()
	
	info_label.text = "选择要%s的骰子" % ("强化" if is_upgrade else "净化")
	
	for i in PlayerState.dice_bag.size():
		var dice_id: String = PlayerState.dice_bag[i]
		var dice_data: Dictionary = GameData._dice_defs.get(dice_id, {})
		var dice_name: String = dice_data.get("name", dice_id)
		var dice_level: int = PlayerState.dice_levels.get(dice_id, 1)
		var dice_faces: Array[int] = dice_data.get("faces", [1, 2, 3, 4, 5, 6])
		
		# 升级模式：只显示可升级的（等级 < 最大等级）
		if is_upgrade and dice_level >= 5:
			continue
		
		var btn := Button.new()
		btn.text = "%s Lv.%d [%s]" % [dice_name, dice_level, _faces_to_str(dice_faces)]
		btn.custom_minimum_size = Vector2(280, 32)
		btn.pressed.connect(_on_dice_selected.bind(i))
		dice_list.add_child(btn)


func _faces_to_str(faces: Array[int]) -> String:
	var parts: Array[String] = []
	for f in faces:
		parts.append(str(f))
	return ",".join(parts)


func _on_dice_selected(idx: int) -> void:
	_selected_dice_idx = idx
	_show_dice_preview()


func _show_dice_preview() -> void:
	if _selected_dice_idx < 0 or _selected_dice_idx >= PlayerState.dice_bag.size():
		return
	
	dice_preview.visible = true
	confirm_btn.visible = true
	
	for child in dice_preview.get_children():
		child.queue_free()
	
	var dice_id: String = PlayerState.dice_bag[_selected_dice_idx]
	var dice_data: Dictionary = GameData._dice_defs.get(dice_id, {})
	var dice_name: String = dice_data.get("name", dice_id)
	var dice_level: int = PlayerState.dice_levels.get(dice_id, 1)
	var faces: Array[int] = dice_data.get("faces", [1, 2, 3, 4, 5, 6])
	
	if _current_action == CampAction.UPGRADE_DICE:
		var cost: int = dice_level * GameBalance.CAMPFIRE_CONFIG.upgradeCostPerLevel
		var next_level: int = dice_level + 1
		var next_faces: Array[int] = _get_upgraded_faces(faces, next_level)
		
		info_label.text = "强化预览: %s Lv.%d → Lv.%d (费用: %d金)" % [dice_name, dice_level, next_level, cost]
		
		var current_label := Label.new()
		current_label.text = "当前: [%s]" % _faces_to_str(faces)
		dice_preview.add_child(current_label)
		
		var next_label := Label.new()
		next_label.text = "升级: [%s]" % _faces_to_str(next_faces)
		dice_preview.add_child(next_label)
		
		confirm_btn.text = "确认升级 (%d金)" % cost
		confirm_btn.disabled = GameManager.gold < cost
	
	elif _current_action == CampAction.PURIFY_DICE:
		info_label.text = "净化确认: 将永久移除 %s" % dice_name
		confirm_btn.text = "确认净化"
		confirm_btn.disabled = PlayerState.dice_bag.size() <= 6
		
		var warn_label := Label.new()
		warn_label.text = "※ 此操作不可撤回 ※"
		dice_preview.add_child(warn_label)


func _get_upgraded_faces(base_faces: Array[int], level: int) -> Array[int]:
	# 升级逻辑：每级面值+1（参考 React 版 getUpgradedFaces）
	var result: Array[int] = []
	for f in base_faces:
		result.append(f + (level - 1))
	return result


func _on_confirm() -> void:
	if _selected_dice_idx < 0 or _selected_dice_idx >= PlayerState.dice_bag.size():
		return
	
	match _current_action:
		CampAction.UPGRADE_DICE:
			_do_upgrade_dice()
		CampAction.PURIFY_DICE:
			_do_purify_dice()


func _do_upgrade_dice() -> void:
	var dice_id: String = PlayerState.dice_bag[_selected_dice_idx]
	var dice_level: int = PlayerState.dice_levels.get(dice_id, 1)
	var cost: int = dice_level * GameBalance.CAMPFIRE_CONFIG.upgradeCostPerLevel
	
	if not GameManager.spend_gold(cost):
		SoundPlayer.play_sound("error")
		VFX.show_toast("金币不足", "damage")
		return
	
	PlayerState.dice_levels[dice_id] = dice_level + 1
	SoundPlayer.play_sound("upgrade")
	VFX.show_toast("%s 升级到 Lv.%d!" % [GameData._dice_defs.get(dice_id, {}).get("name", dice_id), dice_level + 1], "buff")
	_action_used = true
	_leave_campfire()


func _do_purify_dice() -> void:
	if PlayerState.dice_bag.size() <= 6:
		SoundPlayer.play_sound("error")
		VFX.show_toast("骰子库已达最少数量", "damage")
		return
	
	var dice_id: String = PlayerState.dice_bag[_selected_dice_idx]
	var dice_name: String = GameData._dice_defs.get(dice_id, {}).get("name", dice_id)
	PlayerState.dice_bag.remove_at(_selected_dice_idx)
	PlayerState.dice_levels.erase(dice_id)
	SoundPlayer.play_sound("enemy_skill")
	VFX.show_toast("%s 已永久移除" % dice_name, "damage")
	_action_used = true
	_leave_campfire()


func _on_back() -> void:
	if _current_action != CampAction.NONE:
		_current_action = CampAction.NONE
		_selected_dice_idx = -1
		_refresh_main_ui()
		return
	GameManager.set_phase(GameTypes.GamePhase.MAP)


func _leave_campfire() -> void:
	# 营火只能执行一项行动，执行后自动返回地图
	GameManager.set_phase(GameTypes.GamePhase.MAP)
