## 盗贼骰子 onPlay 特效处理
## 被 DiceEffectResolver.resolve_on_play 调用
## 设计原则：纯函数，无副作用，只修改传入的 result
## 属性映射：所有 dice_def.xxx 严格对应 DiceDef @export 字段
class_name DiceEffectRogue
extends RefCounted


## 结算盗贼职业 onPlay 特效
static func resolve(
	dice_def: DiceDef,
	result: DiceEffectResolver.ResolveResult,
	player_hp: int,
	player_max_hp: int,
	player_rerolls: int,
	player_combo: int,
	target_enemy: EnemyInstance,
	enemies: Array[EnemyInstance],
	dice_in_hand: Array[DiceDef],
	unselected_dice: Array[DiceDef]
) -> void:
	if not dice_def:
		return

	# ── 中毒系 ──

	# poison_base: 基础中毒层数
	if dice_def.poison_base > 0:
		result.apply_statuses.append({
			"type": GameTypes.StatusType.POISON,
			"value": dice_def.poison_base,
			"duration": 3,
			"target": "enemy"
		})
		result.descriptions.append("中毒 %d/回合 3 回合" % dice_def.poison_base)

	# poison_bonus_if_poisoned: 目标已中毒时额外中毒
	if dice_def.poison_bonus_if_poisoned > 0:
		if target_enemy and StatusService.has(target_enemy.statuses, GameTypes.StatusType.POISON):
			result.apply_statuses.append({
				"type": GameTypes.StatusType.POISON,
				"value": dice_def.poison_bonus_if_poisoned,
				"duration": 2,
				"target": "enemy"
			})
			result.descriptions.append("中毒加深 +%d/回合" % dice_def.poison_bonus_if_poisoned)

	# poison_from_value: 基于骰子面值施加中毒
	if dice_def.poison_from_value:
		var poison_val := maxi(1, int(DiceEffectResolver._avg_faces(dice_def) * 0.5))
		result.apply_statuses.append({
			"type": GameTypes.StatusType.POISON,
			"value": poison_val,
			"duration": 3,
			"target": "enemy"
		})
		result.descriptions.append("基于面值中毒 %d/回合" % poison_val)

	# poison_scale_damage: 中毒层数转直接伤害
	if dice_def.poison_scale_damage > 0:
		if target_enemy:
			var poison_stacks: int = StatusService.get_value(target_enemy.statuses, GameTypes.StatusType.POISON)
			var scaled_dmg: int = poison_stacks * dice_def.poison_scale_damage
			if scaled_dmg > 0:
				result.bonus_damage += scaled_dmg
				result.descriptions.append("毒伤缩放 +%d" % scaled_dmg)

	# poison_from_poison_dice: 手牌中毒骰子数量加成
	if dice_def.poison_from_poison_dice > 0:
		var poison_dice_count: int = _count_element_in_hand(dice_in_hand, GameTypes.DiceElement.POISON)
		var bonus: int = poison_dice_count * dice_def.poison_from_poison_dice
		if bonus > 0:
			result.bonus_damage += bonus
			result.descriptions.append("毒骰加成 +%d 伤害" % bonus)

	# double_poison_on_combo: 连击时中毒翻倍
	if dice_def.double_poison_on_combo and player_combo >= 2:
		result.bonus_mult += 0.5
		result.descriptions.append("连击毒翻倍 ×+0.5")

	# poison_inverse: 毒素反转 — 将目标毒层全部转化为直接伤害
	if dice_def.poison_inverse:
		if target_enemy:
			var poison_stacks: int = StatusService.get_value(target_enemy.statuses, GameTypes.StatusType.POISON)
			if poison_stacks > 0:
				result.bonus_damage += poison_stacks
				result.descriptions.append("毒素反转 +%d 伤害" % poison_stacks)

	# detonate_poison_percent: 引爆中毒百分比伤害
	if dice_def.detonate_poison_percent > 0.0:
		if target_enemy:
			var poison_val: int = StatusService.get_value(target_enemy.statuses, GameTypes.StatusType.POISON)
			if poison_val > 0:
				var detonate_dmg: int = int(float(target_enemy.hp) * dice_def.detonate_poison_percent)
				result.bonus_damage += detonate_dmg
				result.descriptions.append("引爆中毒 %d 伤害" % detonate_dmg)

	# ── 连击系 ──

	# combo_bonus: 连击倍率加成
	if dice_def.combo_bonus > 0.0:
		var combo_mult: float = dice_def.combo_bonus * float(player_combo)
		result.bonus_mult += combo_mult
		result.descriptions.append("连击 ×+%.1f" % combo_mult)

	# combo_scale_damage: 连击缩放伤害
	if dice_def.combo_scale_damage > 0.0:
		var combo_dmg: int = int(float(player_combo) * dice_def.combo_scale_damage)
		result.bonus_damage += combo_dmg
		result.descriptions.append("连击缩放 +%d" % combo_dmg)

	# combo_detonate_poison: 连击引爆中毒
	if dice_def.combo_detonate_poison > 0.0 and player_combo >= 2:
		if target_enemy:
			var poison_val: int = StatusService.get_value(target_enemy.statuses, GameTypes.StatusType.POISON)
			var combo_det_dmg: int = int(float(poison_val) * dice_def.combo_detonate_poison)
			if combo_det_dmg > 0:
				result.bonus_damage += combo_det_dmg
				result.descriptions.append("连击引爆 +%d" % combo_det_dmg)

	# combo_heal: 连击回血
	if dice_def.combo_heal > 0 and player_combo >= 2:
		result.heal += dice_def.combo_heal
		result.descriptions.append("连击回复 %d HP" % dice_def.combo_heal)

	# combo_splash_damage: 连击时对其他敌人造成溅射伤害
	if dice_def.combo_splash_damage and player_combo >= 2 and target_enemy:
		var splash_dmg: int = int(float(target_enemy.hp) * 0.15)
		if splash_dmg > 0:
			result.aoe += splash_dmg
			result.descriptions.append("连击溅射 %d AOE" % splash_dmg)

	# combo_draw_bonus_next_turn: 连击额外抽牌
	if dice_def.combo_draw_bonus_next_turn and player_combo >= 2:
		result.descriptions.append("连击：下回合额外抽牌")

	# combo_grant_play: 连击给额外出牌
	if dice_def.combo_grant_play and player_combo >= 2:
		result.extra_plays += 1
		result.descriptions.append("连击额外出牌 +1")

	# combo_grant_extra_play: 连击给额外出牌（更高要求）
	if dice_def.combo_grant_extra_play and player_combo >= 3:
		result.extra_plays += 1
		result.descriptions.append("连击精通额外出牌 +1")

	# combo_persist_shadow: 连击持续影分身
	if dice_def.combo_persist_shadow and player_combo >= 2:
		result.bonus_damage += 3
		result.descriptions.append("连击影分身 +3 伤害")

	# grant_extra_play_on_combo: 连击给额外出牌
	if dice_def.grant_extra_play_on_combo and player_combo >= 2:
		result.extra_plays += 1
		result.descriptions.append("连击额外出牌 +1")

	# ── 出牌机制 ──

	# crit_on_second_play: 第二次出暴击（原版：comboCount >= 1 时才触发）
	if dice_def.crit_on_second_play > 0.0 and player_combo >= 1:
		result.bonus_mult += dice_def.crit_on_second_play
		result.descriptions.append("二次出牌暴击 ×+%.1f" % dice_def.crit_on_second_play)

	# bonus_damage_on_second_play: 第二次出额外伤害（原版：comboCount >= 1）
	if dice_def.bonus_damage_on_second_play > 0 and player_combo >= 1:
		result.bonus_damage += dice_def.bonus_damage_on_second_play
		result.descriptions.append("二次出牌 +%d 伤害" % dice_def.bonus_damage_on_second_play)

	# bonus_mult_on_second_play: 第二次出倍率加成（原版：comboCount >= 1）
	if dice_def.bonus_mult_on_second_play > 0.0 and player_combo >= 1:
		result.bonus_mult += dice_def.bonus_mult_on_second_play
		result.descriptions.append("二次出牌 ×+%.1f" % dice_def.bonus_mult_on_second_play)

	# mult_on_third_play: 第三次出倍率加成（原版：comboCount >= 2 时才触发）
	if dice_def.mult_on_third_play > 0.0 and player_combo >= 2:
		result.bonus_mult += dice_def.mult_on_third_play
		result.descriptions.append("三次出牌 ×+%.1f" % dice_def.mult_on_third_play)

	# grant_play_on_third: 第三次出给额外出牌
	if dice_def.grant_play_on_third:
		result.extra_plays += 1
		result.descriptions.append("三次出牌额外 +1 出牌")

	# escalate_damage: 递增伤害
	if dice_def.escalate_damage > 0.0:
		var base_dmg: int = int(DiceEffectResolver._avg_faces(dice_def) * dice_def.escalate_damage)
		result.bonus_damage += base_dmg
		result.descriptions.append("递增 +%d 伤害" % base_dmg)

	# detonate_extra_per_play: 每次出牌额外 AOE
	if dice_def.detonate_extra_per_play > 0.0:
		var extra_aoe: int = int(dice_def.detonate_extra_per_play)
		result.aoe += extra_aoe
		result.descriptions.append("额外 AOE %d" % extra_aoe)

	# detonate_all_on_last_play: 最后一次出牌引爆全部
	if dice_def.detonate_all_on_last_play:
		result.descriptions.append("末牌引爆（待 controller 追踪）")

	# ── 骰子操控 ──

	# always_bounce: 总是弹回手牌
	if dice_def.always_bounce:
		result.always_bounce = true
		result.bonus_damage += 1
		result.descriptions.append("弹回手牌")

	# bounce_and_grow: 弹回并增长
	if dice_def.bounce_and_grow:
		result.bonus_damage += 2
		result.descriptions.append("弹回增长 +2 伤害")

	# boomerang_play: 回旋镖（出牌后返回 + AOE）
	if dice_def.boomerang_play:
		result.aoe += 3
		result.descriptions.append("回旋镖 AOE 3")

	# shadow_clone_play: 影分身
	if dice_def.shadow_clone_play:
		result.bonus_damage += 2
		result.bonus_mult += 0.5
		result.descriptions.append("影分身 +2 伤害 ×+0.5")

	# grant_shadow_die: 赠予影分身骰子
	if dice_def.grant_shadow_die:
		result.temp_dice.append("shadow_clone")
		result.descriptions.append("获得影分身骰子")

	# grant_shadow_remnant: 赠予残余影分身
	if dice_def.grant_shadow_remnant:
		result.temp_dice.append("shadow_remnant")
		result.descriptions.append("获得残余影分身")

	# grant_persistent_shadow_remnant: 赠予持久影分身
	if dice_def.grant_persistent_shadow_remnant:
		result.temp_dice.append("persistent_shadow")
		result.descriptions.append("获得持久影分身")

	# phantom_from_shadow_dice: 影分身来源加成
	if dice_def.phantom_from_shadow_dice:
		var shadow_count: int = _count_shadow_dice_in_hand(dice_in_hand)
		if shadow_count > 0:
			result.bonus_damage += shadow_count * 2
			result.descriptions.append("影骰加成 +%d" % (shadow_count * 2))

	# grant_temp_die: 赠予临时骰子
	if dice_def.grant_temp_die:
		result.temp_dice.append("temp_generic")
		result.descriptions.append("获得临时骰子")

	# clone_self: 自我复制 — 出牌后复制自身到手牌
	if dice_def.clone_self:
		result.clone_self = true
		result.descriptions.append("复制自身到手牌")

	# stay_in_hand: 保留在手牌
	if dice_def.stay_in_hand:
		result.stay_in_hand = true
		result.descriptions.append("保留在手牌")

	# draw_from_bag: 从骰子袋抽牌
	if dice_def.draw_from_bag > 0:
		result.descriptions.append("抽 %d 张骰子" % dice_def.draw_from_bag)

	# grant_extra_play: 获得额外出牌次数
	if dice_def.grant_extra_play:
		result.extra_plays += 1
		result.descriptions.append("额外出牌 +1")

	# wildcard: 已在 _resolve_common 中处理

	# ── 防御 / 偷取 ──

	# steal_armor: 偷取敌人护甲
	if dice_def.steal_armor > 0.0:
		if target_enemy and target_enemy.armor > 0:
			var stolen: int = int(float(target_enemy.armor) * dice_def.steal_armor)
			if stolen > 0:
				result.armor += stolen
				result.descriptions.append("偷取 %d 护甲" % stolen)

	# transfer_debuff: 转移自身负面状态给敌人
	if dice_def.transfer_debuff:
		result.apply_statuses.append({"type": GameTypes.StatusType.POISON, "value": -1, "duration": 0, "target": "self"})
		result.apply_statuses.append({"type": GameTypes.StatusType.BURN, "value": -1, "duration": 0, "target": "self"})
		result.descriptions.append("转移负面状态给敌人")

	# ── 职业判断标记 ──

	# ignore_for_hand_type: 已在 _resolve_common 中处理

	# requires_triple: 已在 _resolve_common 中处理

	# first_play_only: 已在 _resolve_common 中处理


# ============================================================
# 内部辅助函数
# ============================================================

## 统计手牌中指定元素的骰子数量
static func _count_element_in_hand(hand: Array[DiceDef], element: int) -> int:
	var count: int = 0
	for d: DiceDef in hand:
		if d.element == element:
			count += 1
	return count


## 统计手牌中影分身骰子数量
static func _count_shadow_dice_in_hand(hand: Array[DiceDef]) -> int:
	var count: int = 0
	for d: DiceDef in hand:
		if d.shadow_clone_play or d.grant_shadow_die or d.phantom_from_shadow_dice:
			count += 1
	return count
