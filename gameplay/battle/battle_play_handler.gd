# battle_play_handler.gd — 出牌结算协调层
# 从 battle_controller.gd 拆出，专职出牌流程编排
# 核心计算方法保持纯函数（calc_* / get_best_*），apply_* 方法允许调用 VFX/音效副作用
# C1 豁免说明：伤害应用需要驱动视觉反馈（飘字+粒子+震屏），副作用集中在此层
class_name BattlePlayHandler
extends RefCounted


# ============================================================
# 出牌加成计算
# ============================================================

## 计算增幅倍率 outcome.multiplier（v0.5：全部连乘）
## 来源：遗物 bonusMult × 过充 × 血怒 × 其他
## 返回值 ≥ 1.0（无加成时为 1.0）
static func calc_outcome_multiplier(best_hand: String) -> float:
	var mult: float = 1.0
	# 遗物倍率（通过 RelicEngine 统一处理）
	var relic_result := RelicEngine.on_play(GameManager.relics, null, [], best_hand)
	if relic_result.bonus_mult > 0.0:
		mult *= (1.0 + relic_result.bonus_mult)
	# 过充系统（v0.5）
	var overcharge: float = GameBalance.get_overcharge_mult(
		DiceBag.hand_dice.size(), GameBalance.PLAYER_INITIAL.drawCount
	)
	if overcharge > 0.0:
		mult *= (1.0 + overcharge)
	# 血怒：每层 +15%，最多 5 层
	var fury_stacks: int = mini(GameManager.blood_reroll_count, GameBalance.FURY_CONFIG.maxStack)
	var fury_mult: float = fury_stacks * GameBalance.FURY_CONFIG.damagePerStack
	if fury_mult > 0.0:
		mult *= (1.0 + fury_mult)
	# 战士狂暴（v0.5：berserk_turns > 0 时 +30%）
	if PlayerState.berserk_turns > 0:
		mult *= 1.3
	return mult


## 计算额外基础伤害 baseDamage（v0.5：进乘区，不再是末尾加法项）
## 来源：遗物 onPlay.damage + 怒火燎原 + fury_bonus
static func calc_bonus_base_damage() -> int:
	var bonus: int = GameManager.rage_fire_bonus + GameManager.fury_bonus_damage
	# 遗物 ON_PLAY 伤害由 RelicEngine 统一处理（在 play_handler_bridge 中合并）
	return bonus


# ============================================================
# 伤害应用
# ============================================================

## 对敌人施加伤害（AOE / 单体）
## ui_root: 粒子挂载父节点（飘字层）
## shake_target: 震屏目标（WorldLayer，UI 不受影响）
## target_pierce: §6.6 第 3 级 — 仅对主目标生效的护甲穿透（骰子 + onPlay 遗物聚合）
static func apply_damage_to_enemies(
	total_damage: int,
	selected_dice: Array[Dictionary],
	hand_result: Dictionary,
	effect_result: DiceEffectResolver.ResolveResult,
	living_enemies: Array[Node],
	target_enemy: Node,
	ui_root: Node,
	shake_target: Node,
	target_pierce: int = 0
) -> void:
	var has_hand_aoe: bool = BattleHelpers.detect_aoe(selected_dice, hand_result)
	var has_effect_aoe: bool = effect_result != null and effect_result.aoe > 0

	if has_hand_aoe or has_effect_aoe:
		SoundPlayer.play_sound("player_aoe")
		# 牌型 AOE：主目标吃满伤害，其余敌人各吃 aoe_damage 固定额外伤害
		# （原版 postPlayEffects.ts: aoeDamage 是每个敌人额外受伤，不是主伤害平分）
		if has_hand_aoe:
			# 主目标吃满 total_damage + pierce
			if target_enemy:
				if target_enemy.has_method("take_damage"):
					target_enemy.take_damage(total_damage, target_pierce)
				if target_enemy.has_method("play_hurt"):
					target_enemy.play_hurt()
				var pos: Vector2 = _get_view_center(target_enemy)
				VFX.spawn_element_hit(ui_root, pos, "lightning", 12)
				VFX.spawn_damage_text(ui_root, pos, total_damage, total_damage >= 20)
			# 其余敌人吃 AOE 固伤（原版 aoeDamage = 主伤害的 30%）
			var aoe_fixed: int = maxi(1, int(total_damage * 0.3))
			for view: Node in living_enemies:
				if view == target_enemy:
					continue
				if view.has_method("take_damage"):
					view.take_damage(aoe_fixed)
				if view.has_method("play_hurt"):
					view.play_hurt()
				var pos: Vector2 = _get_view_center(view)
				VFX.spawn_element_hit(ui_root, pos, "lightning", 6)
				VFX.spawn_damage_text(ui_root, pos, aoe_fixed, false)
		# 骰子特效 AOE：附加固定伤害给所有非目标敌人（fire 粒子）
		if has_effect_aoe and effect_result != null:
			_apply_effect_aoe_damage(living_enemies, target_enemy, effect_result.aoe, ui_root)
		VFX.shake(shake_target, 6.0, 0.2)
	elif target_enemy:
		SoundPlayer.play_sound("hit")
		# 单体攻击
		var is_crit: bool = total_damage >= 20  # 高伤害判定为暴击飘字
		if target_enemy.has_method("take_damage"):
			target_enemy.take_damage(total_damage, target_pierce)
		if target_enemy.has_method("play_hurt"):
			target_enemy.play_hurt()
		var pos: Vector2 = _get_view_center(target_enemy)
		var element: String = dominant_element(selected_dice)
		VFX.spawn_element_hit(ui_root, pos, element, 10)
		VFX.spawn_damage_text(ui_root, pos, total_damage, is_crit)
		VFX.shake(shake_target, 3.0, 0.15)


## AOE 伤害+飘字辅助：对所有敌人造成同等伤害并生成元素粒子+飘字
static func _apply_aoe_damage_with_vfx(
	enemies: Array[Node], damage: int, element: String, ui_root: Node
) -> void:
	for view: Node in enemies:
		if view.has_method("take_damage"):
			view.take_damage(damage)
		if view.has_method("play_hurt"):
			view.play_hurt()
		var pos: Vector2 = _get_view_center(view)
		VFX.spawn_element_hit(ui_root, pos, element, 10)
		VFX.spawn_damage_text(ui_root, pos, damage, false)


## 骰子特效 AOE：非目标敌人各吃 aoe 固伤，目标敌人已在牌型 AOE 或单体中吃满
static func _apply_effect_aoe_damage(
	enemies: Array[Node], target_enemy: Node, aoe_damage: int, ui_root: Node
) -> void:
	for view: Node in enemies:
		if view == target_enemy:
			continue  # 目标敌人已在主攻击中受伤，不再重复
		if view.has_method("take_damage"):
			view.take_damage(aoe_damage)
		if view.has_method("play_hurt"):
			view.play_hurt()
		var pos: Vector2 = _get_view_center(view)
		VFX.spawn_element_hit(ui_root, pos, "fire", 8)
		VFX.spawn_damage_text(ui_root, pos, aoe_damage, false)


## 安全获取敌人视图中心坐标
static func _get_view_center(view: Node) -> Vector2:
	if view.has_method("get_global_center"):
		return view.get_global_center()
	return Vector2.ZERO


# ============================================================
# 牌型附带效果
# ============================================================

## 应用牌型附带效果（护甲/状态/真伤标记等）
## 通过 HandTypeEffects 配置表获取效果列表，走 EffectEngine 执行
## 参数 base_damage：本次出牌的 baseDamage，用于元素系护甲转化
## 返回 ExecuteResult，调用方可读取 true_damage / ignore_taunt 标记
static func apply_hand_effects(hand_result: Dictionary, base_damage: int = 0) -> EffectEngine.ExecuteResult:
	var active: Array[String] = []
	active.assign(hand_result.get("activeHands", []))
	var result := EffectEngine.ExecuteResult.new()

	# 收集所有激活牌型的效果
	var all_effects: Array[Dictionary] = []
	for h: String in active:
		var effs: Array[Dictionary] = HandTypeEffects.get_effects(h)
		all_effects.append_array(effs)

	# 通过 EffectEngine 执行（护甲/状态/真伤/无视嘲讽等）
	if not all_effects.is_empty():
		var ctx := EffectEngine.ExecuteContext.new()
		ctx.player_hp = PlayerState.hp
		ctx.player_max_hp = PlayerState.max_hp
		ctx.source = EffectTypes.EffectSource.HAND_TYPE
		result = EffectEngine.execute(all_effects, ctx)
		# 应用护甲
		if result.armor > 0:
			PlayerState.gain_armor(result.armor)
		# 状态效果暂存，由 PlayHandlerBridge 消费
		if not result.apply_statuses.is_empty():
			for status: Dictionary in result.apply_statuses:
				PlayerState.pending_hand_statuses.append(status)

	# §6.6 第 2 级：同元素系牌型 → base_damage 转护甲
	if base_damage > 0 and HandTypeEffects.has_elemental_hand(active):
		PlayerState.gain_armor(base_damage)

	return result


## 查 HandTypeEffects 获取最佳牌型效果（UI 显示用）
static func get_best_hand_effect(active_hands: Array[String]) -> Dictionary:
	var best: Dictionary = {"armor": 0, "status": ""}
	var table: Dictionary = HandTypeEffects.get_display_table()
	for h: String in active_hands:
		var eff: Dictionary = table.get(h, {})
		if eff.is_empty():
			continue
		if eff.get("armor", 0) > best.get("armor", 0):
			best = eff
	return best


# ============================================================
# 骰子出牌后处置（即刻销毁 → 入弃骰库）
# ============================================================

## 处置已出骰子：除 always_bounce / stay_in_hand 外，全部从 hand_dice 移除并入弃骰库。
## 同时记入 DiceBag.dice_played_this_turn（供嘲讽反噬等"谁打过"判定使用）。
## 注意：必须按索引降序删，否则索引错位。
static func mark_spent_and_after_play(indices: Array[int], _effect_result: DiceEffectResolver.ResolveResult = null) -> void:
	var sorted_indices: Array[int] = indices.duplicate()
	sorted_indices.sort()
	sorted_indices.reverse()
	for idx: int in sorted_indices:
		if idx < 0 or idx >= DiceBag.hand_dice.size():
			continue
		var die_dict: Dictionary = DiceBag.hand_dice[idx]
		var dice_id: String = die_dict.get("defId", "")
		# 本回合打出记录（含 bounce/stay，供 tauntAll 反噬等判定）
		if dice_id != "":
			DiceBag.dice_played_this_turn.append(dice_id)
		var d_def: DiceDef = GameData.get_dice_def(dice_id) if dice_id else null
		var should_stay: bool = false
		if d_def:
			for eff: Dictionary in d_def.effects:
				var eff_type: int = eff.get("type", -1)
				if eff_type == EffectTypes.EffectType.BOUNCE or eff_type == EffectTypes.EffectType.PRESERVE_DIE:
					should_stay = true
					break
		if should_stay:
			# 弹回/保留的骰子留在手牌，仅重置选中状态
			die_dict["selected"] = false
		else:
			# 默认：从手牌移除 + defId 回弃骰库
			if dice_id != "":
				DiceBag.discard_pile.append(dice_id)
			DiceBag.hand_dice.remove_at(idx)
	# 消耗出牌次数（after_play 处理法师蓄力重置等）
	GameManager.after_play()


# ============================================================
# 辅助方法
# ============================================================

## 获取选中骰子中的主导元素
static func dominant_element(dice: Array[Dictionary]) -> String:
	var counts: Dictionary = {}
	for d: Dictionary in dice:
		var elem: String = d.get("element", "neutral")
		counts[elem] = counts.get(elem, 0) + 1
	var best: String = "neutral"
	var best_count: int = 0
	for elem: String in counts:
		if counts[elem] > best_count:
			best = elem
			best_count = counts[elem]
	return best
