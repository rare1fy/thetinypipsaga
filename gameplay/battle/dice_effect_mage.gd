## 法师骰子 onPlay 特效处理
## 被 DiceEffectResolver.resolve_on_play 调用
## 设计原则：纯函数，无副作用，只修改传入的 result
## 注意：reverse_value / override_value / copy_highest_value / devour_die /
##   swap_with_unselected / random_target / first_play_only / requires_triple /
##   ignore_for_hand_type / heal_or_max_hp / heal_per_cleanse / purify_all /
##   remove_burn / max_hp_bonus 已在 _resolve_common 中处理，此处不重复
class_name DiceEffectMage
extends RefCounted


## 结算法师职业 onPlay 特效
static func resolve(
	dice_def: DiceDef,
	result: DiceEffectResolver.ResolveResult,
	player_hp: int,
	player_max_hp: int,
	player_rerolls: int,
	player_combo: int,
	target_enemy: EnemyInstance,
	enemies: Array[EnemyInstance],
	dice_in_hand: Array[DiceDef] = []
) -> void:
	if not dice_def:
		return

	# ── 元素系 ──

	# 多元素倍率
	if dice_def.mult_per_element > 0.0:
		result.bonus_mult += dice_def.mult_per_element
		result.descriptions.append("元素倍率 ×+%.1f" % dice_def.mult_per_element)

	# 每元素额外伤害
	if dice_def.bonus_damage_per_element > 0:
		var element_count: int = _count_distinct_elements_in_hand()
		var bonus: int = element_count * dice_def.bonus_damage_per_element
		if bonus > 0:
			result.bonus_damage += bonus
			result.descriptions.append("元素加成 +%d 伤害" % bonus)

	# 统一元素
	if dice_def.unify_element:
		result.unify_element = true
		result.descriptions.append("统一元素")

	# 锁定元素
	if dice_def.lock_element:
		result.descriptions.append("锁定元素")

	# 多元素爆破
	if dice_def.multi_element_blast:
		result.apply_statuses.append({"type": GameTypes.StatusType.BURN, "value": 2, "duration": 2, "target": "enemy"})
		result.apply_statuses.append({"type": GameTypes.StatusType.POISON, "value": 2, "duration": 2, "target": "enemy"})
		result.apply_statuses.append({"type": GameTypes.StatusType.FREEZE, "value": 2, "duration": 2, "target": "enemy"})
		result.descriptions.append("触发灼烧+中毒+冰冻")

	# 双元素
	if dice_def.dual_element:
		result.descriptions.append("双元素骰子")

	# 复制多数元素
	if dice_def.copy_majority_element:
		result.copy_majority_element = true
		result.descriptions.append("复制多数元素")

	# ── 状态交互 ──

	# 灼烧回响：目标已灼烧则额外伤害
	if dice_def.burn_echo:
		if target_enemy and StatusService.has(target_enemy.statuses, GameTypes.StatusType.BURN):
			result.bonus_damage += 5
			result.descriptions.append("灼烧回响 +5 伤害")

	# 冰霜回响：目标已冰冻则百分比伤害
	if dice_def.frost_echo_damage > 0.0:
		if target_enemy and StatusService.has(target_enemy.statuses, GameTypes.StatusType.FREEZE):
			var frost_dmg := int(float(target_enemy.max_hp) * dice_def.frost_echo_damage)
			result.bonus_damage += frost_dmg
			result.descriptions.append("冰霜回响 %d 伤害" % frost_dmg)

	# 冰冻加成：目标已冰冻则额外伤害
	if dice_def.freeze_bonus > 0:
		if target_enemy and StatusService.has(target_enemy.statuses, GameTypes.StatusType.FREEZE):
			result.bonus_damage += dice_def.freeze_bonus
			result.descriptions.append("冰冻加成 +%d 伤害" % dice_def.freeze_bonus)

	# 伤害护盾
	if dice_def.damage_shield:
		result.armor += 3
		result.descriptions.append("伤害护盾 +3 护甲")

	# 护甲转伤害
	if dice_def.armor_to_damage:
		result.armor_to_damage = true
		result.descriptions.append("护甲转伤害")

	# ── 蓄力 / 保持 ──

	# 蓄力机制（原版 mageCalc.ts L56-62）
	# 满足 requiresCharge 层数后：bonusMult 全额 + 超出层数 × bonusMultPerExtraCharge
	if dice_def.requires_charge > 0 and dice_def.bonus_mult > 0.0:
		var charge_count: int = 0
		if GameManager and GameManager.has_method("get_charge_count"):
			charge_count = GameManager.get_charge_count(dice_def.id)
		if charge_count >= dice_def.requires_charge:
			var extra_layers: int = maxi(0, charge_count - dice_def.requires_charge)
			var extra_mult: float = dice_def.bonus_mult_per_extra_charge * float(extra_layers) if dice_def.bonus_mult_per_extra_charge > 0.0 else 0.0
			var total_charge_mult: float = dice_def.bonus_mult + extra_mult
			result.bonus_mult += total_charge_mult
			result.descriptions.append("蓄力释放 ×+%.1f" % total_charge_mult)

	# 每回合保留加成（onPlay 中计算已保留回合数）
	if dice_def.bonus_per_turn_kept > 0:
		var kept_turns: int = 1
		if dice_def.has_method("get_kept_turns"):
			kept_turns = dice_def.get_kept_turns()
		var kept_bonus: int = mini(kept_turns * dice_def.bonus_per_turn_kept, dice_def.keep_bonus_cap)
		result.bonus_damage += kept_bonus
		result.descriptions.append("保留加成 +%d 伤害" % kept_bonus)

	# 保留时提升最低骰子面值
	if dice_def.boost_lowest_on_keep > 0:
		result.bonus_damage += dice_def.boost_lowest_on_keep
		result.descriptions.append("提升最低 +%d" % dice_def.boost_lowest_on_keep)

	# 净化回血：每净化一个负面状态回血
	if dice_def.heal_per_cleanse > 0:
		var debuff_count: int = 0
		if GameManager and GameManager.has_method("get_debuff_count"):
			debuff_count = GameManager.get_debuff_count()
		if debuff_count > 0:
			result.heal += dice_def.heal_per_cleanse * debuff_count
			result.descriptions.append("净化回血 %d" % (dice_def.heal_per_cleanse * debuff_count))

	# ── AOE / 连锁 ──

	# 连锁闪电
	if dice_def.chain_bolt:
		result.aoe += 3
		result.descriptions.append("连锁闪电 3 AOE")

	# 溅射随机敌人
	if dice_def.splash_to_random:
		result.aoe += 2
		result.descriptions.append("溅射随机敌人 2")

	# ── 手牌操控 ──

	# 基于手牌数获得护甲
	if dice_def.armor_from_hand_size > 0.0:
		var hand_size: int = dice_in_hand.size()
		var hand_armor := int(float(hand_size) * dice_def.armor_from_hand_size)
		if hand_armor > 0:
			result.armor += hand_armor
			result.descriptions.append("基于手牌数获得 %d 护甲" % hand_armor)


## 统计手牌中不同元素数量
static func _count_distinct_elements_in_hand() -> int:
	var elements: Array[int] = []
	# 简化：假设最多 5 种元素
	if GameManager and GameManager.has_method("get_hand_elements"):
		elements = GameManager.get_hand_elements()
	return maxi(1, elements.size())
