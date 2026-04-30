## 出牌桥接器
## 从 battle_controller.gd 拆出（B1 行数限制）
## 职责：出牌结算的完整流程（演出 → 攻击动画 → 伤害 → 受击 → 遗物 → 延迟刷新）
## 对应原版 useBattleCombat.tsx 的 playSelectedDice
##
## 时序契约（2026-04-30 刘叔重排）：
##   点击出牌 → 结算演出（await） → 玩家攻击动画 → 敌人受击动画+伤害飘字
class_name PlayHandlerBridge
extends Node

const DiceEffectResolver = preload("res://gameplay/battle/dice_effect_resolver.gd")
const DiceEffectApplier = preload("res://gameplay/battle/dice_effect_applier.gd")
const BattleHelpers = preload("res://gameplay/battle/battle_helpers.gd")
const EnemyMgr = preload("res://gameplay/battle/battle_enemy_manager.gd")
const ClassDefData = preload("res://data/class_def.gd")


# ============================================================
# 出牌执行（时序：演出 → 攻击 → 受击）
# ============================================================

## 执行出牌（替代 battle_controller._on_play_pressed 的业务逻辑）
## 由 BattleController 调用，必须作为 controller 子节点存在
func execute(controller: BattleController) -> void:
	if controller.selected_dice_indices.is_empty() or controller._is_resolving:
		return

	var selected_dice: Array[Dictionary] = controller._collect_selected_dice()
	var hand_result: Dictionary = HandEvaluator.check_hands(selected_dice)
	var active_hands: Array[String] = []
	active_hands.assign(hand_result.get("activeHands", []))
	var is_pure_normal: bool = active_hands.size() == 1 and active_hands[0] == "普通攻击"

	# §6.1 / §6.2 多选普攻守卫
	var class_def: ClassDef = ClassDefData.get_all().get(PlayerState.player_class) as ClassDef
	var can_multi_normal: bool = class_def != null and class_def.normal_attack_multi_select
	if is_pure_normal and selected_dice.size() > 1:
		if not can_multi_normal:
			BattleLog.log_status("⚠️ 不成牌型时只能出 1 颗骰子")
			return
		else:
			BattleLog.log_status("⚔️ 多选普通攻击：特殊骰子效果将被禁用！")

	# §6.5 第 5 级：skipOnPlay = 战士多选普攻
	var skip_on_play: bool = can_multi_normal and is_pure_normal and selected_dice.size() > 1

	controller._is_resolving = true
	controller.play_btn.disabled = true
	SoundPlayer.play_sound("player_attack")

	# ── §6.4 盗贼连击钩子 ──
	var current_combo: int = PlayerState.combo_count
	var last_hand: String = PlayerState.last_play_hand_type
	if PlayerState.player_class == "rogue":
		if current_combo == 0:
			var wr_c: WeakRef = weakref(controller)
			controller.get_tree().create_timer(0.2).timeout.connect(func() -> void:
				var c: BattleController = wr_c.get_ref() as BattleController
				if c == null or not c.is_inside_tree():
					return
				TurnManager.free_rerolls_left += 1
				var pp: Vector2 = c.hp_bar.global_position + c.hp_bar.size * 0.5
				VFX.spawn_status_text(c._float_layer, pp, "连击预备: +1免费重投")
			)
		elif current_combo == 1 and not is_pure_normal:
			var wr_c2: WeakRef = weakref(controller)
			controller.get_tree().create_timer(0.2).timeout.connect(func() -> void:
				var c: BattleController = wr_c2.get_ref() as BattleController
				if c == null or not c.is_inside_tree():
					return
				var pp: Vector2 = c.hp_bar.global_position + c.hp_bar.size * 0.5
				VFX.spawn_status_text(c._float_layer, pp, "连击! +20%伤害")
			)

	# ── 骰子 onPlay 特效结算 ──
	var dice_in_hand: Array[DiceDef] = []
	var unselected_dice: Array[DiceDef] = []
	for die_dict: Dictionary in DiceBag.hand_dice:
		var d_def: DiceDef = GameData.get_dice_def(die_dict.get("defId", ""))
		if d_def:
			dice_in_hand.append(d_def)
			if not die_dict.get("selected", false):
				unselected_dice.append(d_def)

	var dice_effect_result: DiceEffectResolver.ResolveResult = \
		DiceEffectResolver.resolve_on_play(
			DiceEffectApplier.get_dice_def_for_selected(selected_dice),
			PlayerState.hp,
			PlayerState.max_hp,
			GameManager.rerolls_this_turn,
			current_combo,
			PlayerState.armor,
			DiceEffectApplier.get_target_enemy_instance(EnemyMgr.get_target_enemy(controller.enemy_views)),
			EnemyMgr.collect_enemy_instances(controller.enemy_views),
			dice_in_hand,
			unselected_dice,
			skip_on_play
		)

	# §6.6 第 8 / 9 级修正因子
	var player_weak: bool = PlayerState.has_status(GameTypes.StatusType.WEAK)
	var target_instance: EnemyInstance = DiceEffectApplier.get_target_enemy_instance(EnemyMgr.get_target_enemy(controller.enemy_views))
	var enemy_vulnerable: bool = target_instance != null and target_instance.has_status(GameTypes.StatusType.VULNERABLE)
	var rogue_combo_bonus: bool = PlayerState.player_class == "rogue" and current_combo >= 1 and not is_pure_normal
	var this_hand_type: String = hand_result.get("bestHand", "")
	var precision_combo: bool = PlayerState.player_class == "rogue" and current_combo == 1 and last_hand != "" and last_hand == this_hand_type and not is_pure_normal

	# 计算牌型和伤害
	var bonus_mult: float = BattlePlayHandler.calc_play_bonus_mult(hand_result.bestHand) + dice_effect_result.bonus_mult
	var bonus_damage: int = BattlePlayHandler.calc_play_bonus_damage() + dice_effect_result.bonus_damage
	var total_damage: int = HandEvaluator.calculate_damage(
		selected_dice, hand_result, bonus_mult, bonus_damage,
		PlayerState.hand_type_upgrades,
		player_weak, enemy_vulnerable, rogue_combo_bonus, precision_combo
	)
	BattleLog.log_dice("[DIAG] hand=%s bonus_mult=%.2f bonus_dmg=%d total=%d combo=%d fury=%d rage=%.2f weak=%s vuln=%s rogue_combo=%s skip_op=%s" % [
		hand_result.bestHand, bonus_mult, bonus_damage, total_damage,
		current_combo, PlayerState.blood_reroll_count, PlayerState.warrior_rage_mult,
		player_weak, enemy_vulnerable, rogue_combo_bonus, skip_on_play
	])

	# 应用特效结果（护甲转伤害等 onPlay 效果，不含伤害应用）
	DiceEffectApplier.apply(dice_effect_result, controller.enemy_views, controller._refresh_status_bar, dice_in_hand, controller.hp_bar)

	# §6.6 第 3 级 — pierce 聚合
	var total_pierce: int = dice_effect_result.pierce + RelicEngine.get_on_play_pierce(PlayerState.relics)

	# ── 时序编排：演出 → 攻击 → 受击 ──
	var hand_name: String = hand_result.get("bestHand", "")
	if hand_name != "":
		BattleLog.log_dice("%s → %d 伤害" % [hand_name, total_damage])
	else:
		BattleLog.log_dice("出牌 → %d 伤害" % total_damage)

	# 阶段 1：结算演出（await 等待四阶段播完 + 收尾淡出）
	await _play_settlement(controller, hand_name, selected_dice, bonus_mult, bonus_damage, total_damage, hand_result)

	# 阶段 2：玩家攻击动画（等待动画完成再触发受击，避免同时播放）
	var battle_scene: BattleScene = controller.owner as BattleScene
	if battle_scene != null and battle_scene.player_hands != null:
		battle_scene.player_hands.play_attack()
		await battle_scene.player_hands.attack_finished

	# 阶段 3：伤害应用 + 敌人受击动画 + 飘字
	_apply_damage_and_after(
		controller, total_damage, selected_dice, hand_result, dice_effect_result,
		total_pierce, is_pure_normal
	)


# ============================================================
# 伤害应用 + 敌人受击动画
# ============================================================

func _apply_damage_and_after(
	controller: BattleController,
	total_damage: int,
	selected_dice: Array[Dictionary],
	hand_result: Dictionary,
	dice_effect_result: DiceEffectResolver.ResolveResult,
	total_pierce: int,
	is_pure_normal: bool
) -> void:
	# 1. 伤害应用（含受击动画 + 飘字）
	BattlePlayHandler.apply_damage_to_enemies(
		total_damage, selected_dice, hand_result, dice_effect_result,
		EnemyMgr.get_living_enemies(controller.enemy_views), EnemyMgr.get_target_enemy(controller.enemy_views),
		controller._float_layer, controller.world_layer,
		total_pierce
	)

	# 2. 重击音效（主目标高伤害时）
	if total_damage >= 20:
		SoundPlayer.play_sound("heavy_impact")

	# 3. 牌型附带效果
	var armor_before: int = PlayerState.armor
	var base_damage: int = HandEvaluator.calculate_base_damage(selected_dice, hand_result, PlayerState.hand_type_upgrades)
	BattlePlayHandler.apply_hand_effects(hand_result, base_damage)
	var armor_gained: int = PlayerState.armor - armor_before
	if armor_gained > 0:
		var player_pos: Vector2 = controller.hp_bar.global_position + controller.hp_bar.size * 0.5
		VFX.spawn_armor_text(controller._float_layer, player_pos, armor_gained)

	# 4. combo 飘字
	var combo: int = PlayerState.combo_count
	if combo > 1:
		var combo_pos: Vector2 = Vector2(
			controller.get_viewport_rect().size.x * 0.5,
			controller.get_viewport_rect().size.y * 0.35
		)
		VFX.spawn_combo_text(controller._float_layer, combo_pos, combo)
		SoundPlayer.play_sound("combo_hit")

	# 5. 触发遗物 onPlay
	RelicEngine.on_play(PlayerState.relics, controller, selected_dice.duplicate(), hand_result.get("bestHand", ""))

	# 6. 出牌状态写回
	PlayerState.last_play_hand_type = hand_result.get("bestHand", "")
	if is_pure_normal:
		PlayerState.consecutive_normal_attacks += 1
	else:
		PlayerState.consecutive_normal_attacks = 0

	var target_view: Node = EnemyMgr.get_target_enemy(controller.enemy_views)
	if target_view != null and target_view.has_method("get_enemy_instance"):
		var target_inst2: EnemyInstance = target_view.get_enemy_instance()
		if target_inst2 != null and target_inst2.uid != "":
			var prev: int = PlayerState.plays_per_enemy.get(target_inst2.uid, 0)
			PlayerState.plays_per_enemy[target_inst2.uid] = prev + 1

	# 7. 检查胜负
	if EnemyMgr.check_battle_over(controller.enemy_views, controller._on_battle_ended.bind(true)):
		return

	# 8. 标记已出骰子 + 消耗出牌次数
	BattlePlayHandler.mark_spent_and_after_play(controller.selected_dice_indices, dice_effect_result)
	controller.selected_dice_indices.clear()

	# 9. 延迟刷新 UI
	_schedule_after_play_resolve(controller)


# ============================================================
# 结算演出
# ============================================================

func _play_settlement(
	controller: BattleController,
	hand_name: String,
	selected_dice: Array[Dictionary],
	bonus_mult: float,
	bonus_damage: int,
	total_damage: int,
	hand_result: Dictionary
) -> void:
	var settlement: SettlementPlayer = controller.get_node_or_null("%SettlementPlayer")
	if settlement == null:
		settlement = SettlementPlayer.new()
		settlement.name = "SettlementPlayer"
		controller.add_child(settlement)
	var dice_values: Array[int] = []
	for d: Dictionary in selected_dice:
		dice_values.append(d.get("value", 0))
	var has_aoe: bool = BattleHelpers.detect_aoe(selected_dice, hand_result)
	# await 等待结算演出四阶段全部播完 + 收尾淡出
	await settlement.play({
		"hand_name": hand_name,
		"dice_values": dice_values,
		"bonus_mult": bonus_mult,
		"bonus_damage": bonus_damage,
		"total_damage": total_damage,
		"has_aoe": has_aoe,
	})


# ============================================================
# 出牌结算后延迟刷新
# ============================================================

func _schedule_after_play_resolve(controller: BattleController) -> void:
	var wr: WeakRef = weakref(controller)
	get_tree().create_timer(0.5).timeout.connect(func() -> void:
		var c: BattleController = wr.get_ref() as BattleController
		if c != null and c.is_inside_tree():
			_on_after_play_resolve(c)
	)


func _on_after_play_resolve(controller: BattleController) -> void:
	if not controller.is_inside_tree():
		return
	EnemyMgr.refresh_enemy_views(controller.enemy_views)
	controller._refresh_status_bar()
	controller._is_resolving = false
	if GameManager.plays_left <= 0 or DiceBag.hand_dice.is_empty():
		controller._check_auto_end_turn()
	else:
		controller._refresh_hand_display()
		controller._update_play_button_state()
		var dp: DamagePreview = controller._get_damage_preview()
		if dp:
			dp.refresh([])