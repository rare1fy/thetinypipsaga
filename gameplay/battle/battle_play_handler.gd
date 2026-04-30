# battle_play_handler.gd — 出牌结算协调层
# 从 battle_controller.gd 拆出，专职出牌流程编排
# 核心计算方法保持纯函数（calc_* / get_best_*），apply_* 方法允许调用 VFX/音效副作用
# C1 豁免说明：伤害应用需要驱动视觉反馈（飘字+粒子+震屏），副作用集中在此层
class_name BattlePlayHandler
extends RefCounted


# ============================================================
# 出牌加成计算
# ============================================================

## 计算牌型倍率加成（遗物 + 职业）
## 参数 best_hand: 本次出牌的牌型名
static func calc_play_bonus_mult(best_hand: String) -> float:
	var mult: float = 0.0
	# 遗物倍率
	for r: Dictionary in GameManager.relics:
		var def: RelicDef = GameData.get_relic_def(r.id)
		if def and def.multiplier > 0 and def.id == "prism_focus" and "同元素" in best_hand:
			mult += def.multiplier
	# 职业倍率：法师过充 + 战士血怒（封顶 FURY_CONFIG）
	mult += GameManager.mage_overcharge_mult
	# 血怒封顶：每层 +15%，最多 5 层 = +75%
	var fury_stacks: int = mini(GameManager.blood_reroll_count, GameBalance.FURY_CONFIG.maxStack)
	var fury_mult: float = fury_stacks * GameBalance.FURY_CONFIG.damagePerStack
	mult += fury_mult + GameManager.warrior_rage_mult
	# 盗贼同牌型精准连击 ×1.25 已移至 HandEvaluator.calculate_damage 独立乘算
	# （原版 playHandStats.ts calcComboFinisherBonus 是独立 ×1.25，不应混入 bonus_mult）
	return mult


## 计算额外伤害加成（遗物 + 职业）
static func calc_play_bonus_damage() -> int:
	var bonus: int = GameManager.rage_fire_bonus + GameManager.fury_bonus_damage
	for r: Dictionary in GameManager.relics:
		var def: RelicDef = GameData.get_relic_def(r.id)
		if def and def.trigger == GameTypes.RelicTrigger.ON_PLAY and def.damage > 0 and def.id != "life_furnace":
			bonus += def.damage
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

## 应用牌型附带效果（护甲/状态）
## §6.6 第 2 级：同元素系牌型（同元素 / 元素顺 / 元素葫芦 / 皇家元素顺）
##   → 额外获得等量于本次 baseDamage 的护甲（原版 expectedOutcomeCalc.ts 第 2 级）
## 参数 base_damage：本次出牌的 baseDamage（点数和 × 牌型倍率），用于元素系护甲转化
static func apply_hand_effects(hand_result: Dictionary, base_damage: int = 0) -> void:
	var active: Array[String] = []
	active.assign(hand_result.get("activeHands", []))
	var best_effect: Dictionary = get_best_hand_effect(active)
	if best_effect.get("armor", 0) > 0:
		PlayerState.gain_armor(best_effect.armor)
	# §6.6 第 2 级：同元素系牌型 → base_damage 转护甲
	if base_damage > 0 and _has_elemental_hand(active):
		PlayerState.gain_armor(base_damage)


## 判断是否包含同元素系牌型
static func _has_elemental_hand(active_hands: Array[String]) -> bool:
	const ELEMENTAL_HANDS: Array[String] = ["同元素", "元素顺", "元素葫芦", "皇家元素顺"]
	for h: String in active_hands:
		if h in ELEMENTAL_HANDS:
			return true
	return false


## 查 HAND_EFFECT_TABLE 获取最佳牌型效果
static func get_best_hand_effect(active_hands: Array[String]) -> Dictionary:
	var best: Dictionary = {"armor": 0, "status": ""}
	var table: Dictionary = DamagePreview.HAND_EFFECT_TABLE
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
		if d_def and (d_def.always_bounce or d_def.stay_in_hand):
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
