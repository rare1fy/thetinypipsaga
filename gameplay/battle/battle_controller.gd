## 战斗控制器 — 从 battle_scene.gd 剥离的纯逻辑层
## 职责：出牌 / 重投 / 敌方回合 / 伤害结算 / 胜负判定
## 不直接操作 UI，通过 signal 通知 scene 层刷新

class_name BattleController
extends Node

signal ui_refresh_requested
signal dice_ui_refresh_requested
signal enemies_ui_refresh_requested
signal hand_label_updated(text: String)
signal damage_preview_refreshed(dice: Array)
signal damage_preview_hidden
signal floating_text_requested(text: String, color: Color, target: String)
signal settlement_started(data: Dictionary)
signal battle_victory
signal game_over_triggered

## 出牌锁：结算演出期间禁止二次出牌
var playing_hand: bool = false

## 当前选中的骰子
var selected_dice: Array[Dictionary] = []

## 本回合重投计数
var reroll_count: int = 0

## 敌人列表（引用，与 scene 共享）
var enemies: Array[EnemyInstance] = []

## 战斗是否激活
var battle_active: bool = false


## ========== 战斗生命周期 ==========

func start_battle(wave_data: Array) -> void:
	battle_active = true
	GameManager.battle_turn = 0
	GameManager.hp_lost_this_battle = 0
	enemies = []

	for config_id in wave_data:
		var config := EnemyConfig.get_config(config_id)
		if config:
			var scaling := GameBalance.get_depth_scaling(maxi(0, GameManager.current_node))
			var chapter_scale: Dictionary = GameBalance.CHAPTER_CONFIG.chapterScaling[mini(GameManager.chapter - 1, 4)]
			var e := EnemyInstance.from_config(config,
				scaling.hpMult * chapter_scale.hpMult,
				scaling.dmgMult * chapter_scale.dmgMult)
			enemies.append(e)

	enemies_ui_refresh_requested.emit()
	start_new_turn()


func start_new_turn() -> void:
	GameManager.start_turn()
	reroll_count = 0
	ui_refresh_requested.emit()

	GameManager.execute_draw_phase()
	RelicEngine.on_battle_start(GameManager.relics, GameManager)
	SoundPlayer.play_sound("roll")


## ========== 出牌逻辑 ==========

func play_hand() -> void:
	if selected_dice.is_empty():
		return
	if GameManager.plays_left <= 0:
		return
	if GameManager.is_enemy_turn:
		return
	if playing_hand:
		return

	playing_hand = true
	SoundPlayer.play_sound("player_attack")

	var hand_result := HandEvaluator.check_hands(selected_dice)
	var bonus_mult := RelicEngine.get_bonus_mult(GameManager.relics, hand_result.bestHand)
	bonus_mult += GameManager.mage_overcharge_mult
	bonus_mult += GameManager.warrior_rage_mult

	# 盗贼连击加成
	if GameManager.player_class == "rogue" and GameManager.combo_count >= 1:
		bonus_mult += 0.2
		if GameManager.last_play_hand_type == hand_result.bestHand and hand_result.bestHand != "普通攻击":
			bonus_mult += 0.25

	var bonus_damage := RelicEngine.get_bonus_damage(GameManager.relics, GameManager)
	bonus_damage += GameManager.fury_bonus_damage
	var total_damage := HandEvaluator.calculate_damage(selected_dice, hand_result, bonus_mult, bonus_damage)

	var target := BattleHelpers.pick_target(enemies, GameManager.target_enemy_uid)
	if not target:
		playing_hand = false
		return

	var dice_values: Array = []
	for d in selected_dice:
		dice_values.append(int(d.value))
	var has_aoe := BattleHelpers.detect_aoe(selected_dice, hand_result)

	damage_preview_hidden.emit()

	# 通知 scene 层播放结算演出，await 完成后继续
	settlement_started.emit({
		"hand_name": hand_result.bestHand,
		"dice_values": dice_values,
		"bonus_mult": bonus_mult,
		"bonus_damage": bonus_damage,
		"total_damage": total_damage,
		"has_aoe": has_aoe,
	})


## 出牌结算 — 由 scene 层 await 演出后调用
func finalize_play(hand_result: Dictionary, target: EnemyInstance, total_damage: int) -> void:
	# 清除临时加成
	GameManager.rage_fire_bonus = 0
	GameManager.fury_bonus_damage = 0

	attack_enemy(target, total_damage, hand_result)

	var played_defs: Array[String] = []
	for d in selected_dice:
		d.spent = true
		played_defs.append(d.defId)
	GameManager.discard_hand_dice(played_defs)
	selected_dice.clear()

	_process_dice_on_play_effects()

	GameManager.last_play_hand_type = hand_result.bestHand
	GameManager.after_play()

	if GameManager.player_class == "rogue" and GameManager.combo_count >= 1:
		_grant_shadow_remnant()

	enemies_ui_refresh_requested.emit()
	_check_enemy_deaths()
	ui_refresh_requested.emit()

	if enemies.all(func(e): return e.hp <= 0):
		on_battle_victory()

	playing_hand = false


## ========== 重投逻辑 ==========

func reroll_selected() -> void:
	const BLOOD_COST := 3

	if GameManager.is_enemy_turn or GameManager.plays_left <= 0 or playing_hand:
		return

	var to_reroll: Array[Dictionary] = []
	for d in GameManager.hand_dice:
		if d.selected and not d.spent:
			to_reroll.append(d)
	if to_reroll.is_empty():
		GameManager.toast_requested.emit("请先选中要重投的骰子", "info")
		return

	# 消费免费次数 / 卖血
	if GameManager.free_rerolls_left > 0:
		GameManager.free_rerolls_left -= 1
	elif GameManager.can_blood_reroll and GameManager.hp > BLOOD_COST:
		GameManager.blood_reroll_count += 1
		GameManager.take_damage(BLOOD_COST)
		SoundPlayer.play_sound("hit")
	else:
		if GameManager.can_blood_reroll:
			GameManager.toast_requested.emit("血量不足！卖血重投需要 %d HP" % BLOOD_COST, "damage")
		else:
			GameManager.toast_requested.emit("免费重投次数已用完", "info")
		return

	reroll_count += 1
	GameManager.stats.totalRerolls += 1
	SoundPlayer.play_sound("reroll")

	# 牌库循环：替换选中的骰子
	var replace_ids: Array[int] = []
	var defs_to_discard: Array[String] = []
	for d in to_reroll:
		replace_ids.append(d.id)
		if not d.get("isTemp", false) or d.defId == "temp_rogue":
			defs_to_discard.append(d.defId)

	GameManager.discard_hand_dice(defs_to_discard)

	var draw_result: Dictionary = GameManager.draw_from_bag(defs_to_discard.size())
	var fresh_dice: Array = draw_result.drawn

	var fresh_idx := 0
	for i in GameManager.hand_dice.size():
		var d: Dictionary = GameManager.hand_dice[i]
		if not replace_ids.has(d.id):
			continue
		if d.get("isTemp", false) and d.defId != "temp_rogue":
			d.value = GameManager.reroll_die(d)
			d.selected = false
			d.rolling = false
			continue
		if fresh_idx < fresh_dice.size():
			var fresh: Dictionary = fresh_dice[fresh_idx]
			fresh_idx += 1
			fresh["id"] = d.id
			fresh["selected"] = false
			fresh["rolling"] = false
			GameManager.hand_dice[i] = fresh

	selected_dice.clear()
	hand_label_updated.emit("")
	damage_preview_refreshed.emit([])
	dice_ui_refresh_requested.emit()
	ui_refresh_requested.emit()


## ========== 敌方回合 ==========

func execute_enemy_turn() -> void:
	GameManager.is_enemy_turn = true
	ui_refresh_requested.emit()

	var result := EnemyAI.execute_enemy_turn(GameManager, enemies, GameManager.hand_dice)

	if result.get("gameOver", false):
		game_over_triggered.emit()
		return

	enemies_ui_refresh_requested.emit()
	start_new_turn()


## ========== 结束回合 ==========

func end_player_turn() -> void:
	if GameManager.is_enemy_turn or playing_hand:
		return

	SoundPlayer.play_sound("turn_end")
	execute_enemy_turn()


## ========== 骰子选中 ==========

func toggle_die_selection(die_id: int) -> void:
	if GameManager.is_enemy_turn or playing_hand:
		return
	if GameManager.plays_left <= 0:
		GameManager.toast_requested.emit("出牌次数已耗尽", "info")
		return

	var die: Dictionary = {}
	for d in GameManager.hand_dice:
		if int(d.get("id", -1)) == die_id:
			die = d
			break
	if die.is_empty() or die.spent:
		return

	die.selected = not die.selected

	if die.selected:
		selected_dice.append(die)
	else:
		selected_dice.erase(die)

	if selected_dice.size() > 0:
		var hand := HandEvaluator.check_hands(selected_dice)
		hand_label_updated.emit(hand.bestHand)
	else:
		hand_label_updated.emit("")

	damage_preview_refreshed.emit(selected_dice)
	dice_ui_refresh_requested.emit()
	ui_refresh_requested.emit()


## ========== 敌人选中（嘲讽目标） ==========

func set_target_enemy(enemy_uid: String) -> void:
	GameManager.target_enemy_uid = enemy_uid
	enemies_ui_refresh_requested.emit()


## ========== 内部方法 ==========

func attack_enemy(enemy: EnemyInstance, damage: int, _hand_result: Dictionary) -> void:
	var absorbed := mini(enemy.armor, damage)
	enemy.armor -= absorbed
	var hp_damage := damage - absorbed
	enemy.hp = maxi(0, enemy.hp - hp_damage)

	BattleHelpers.apply_element_effects(enemy, selected_dice, enemies)
	GameManager.record_damage(damage, true)

	floating_text_requested.emit("-%d" % damage, Color.RED, "enemy")
	SoundPlayer.play_sound("hit")


func _check_enemy_deaths() -> void:
	BattleHelpers.settle_enemy_deaths(enemies)


func _grant_shadow_remnant() -> void:
	GameManager.hand_dice.append(BattleHelpers.make_shadow_remnant())


func _process_dice_on_play_effects() -> void:
	GameManager.hand_dice.append_array(BattleHelpers.compute_dice_on_play_extras(selected_dice))


func on_battle_victory() -> void:
	battle_active = false
	GameManager.stats.battlesWon += 1
	SoundPlayer.play_sound("victory")
	battle_victory.emit()
	GameManager.set_phase(GameTypes.GamePhase.LOOT)
