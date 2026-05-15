## 战士骰子 onPlay 特效处理
## 被 DiceEffectResolver.resolve_on_play 调用
## 设计原则：纯函数，无副作用，只修改传入的 result
class_name DiceEffectWarrior
extends RefCounted


## 结算战士职业 onPlay 特效
static func resolve(
	dice_def: DiceDef,
	result: DiceEffectResolver.ResolveResult,
	player_hp: int,
	player_max_hp: int,
	player_rerolls: int,
	player_armor: int,
	target_enemy: EnemyInstance,
	enemies: Array[EnemyInstance],
	dice_in_hand: Array[DiceDef] = []
) -> void:
	if not dice_def:
		return

	if dice_def.armor_from_value:
		var armor_val := _calc_armor_from_value(dice_def)
		if armor_val > 0:
			result.armor += armor_val
			result.descriptions.append("基于数值获得 %d 护甲" % armor_val)

	if dice_def.armor_from_total_points:
		var armor_val := _calc_armor_from_total_points(dice_def)
		if armor_val > 0:
			result.armor += armor_val
			result.descriptions.append("基于总点数获得 %d 护甲" % armor_val)

	if dice_def.armor_from_hand_size > 0.0:
		var hand_armor := int(float(dice_in_hand.size()) * dice_def.armor_from_hand_size)
		if hand_armor > 0:
			result.armor += hand_armor
			result.descriptions.append("基于手牌数获得 %d 护甲" % hand_armor)

	if dice_def.armor_break:
		var break_result := _apply_armor_break(target_enemy)
		result.pierce += break_result.pierce
		result.bonus_damage += break_result.bonus_damage
		if break_result.pierce > 0:
			result.descriptions.append("破甲：无视 %d 护甲" % break_result.pierce)

	if dice_def.damage_from_armor > 0.0:
		var dmg_from_armor := int(float(target_enemy.armor) * dice_def.damage_from_armor) if target_enemy else 0
		if dmg_from_armor > 0:
			result.bonus_damage += dmg_from_armor
			result.descriptions.append("护甲转伤害 %d" % dmg_from_armor)

	if dice_def.armor_to_damage:
		if player_armor > 0:
			result.bonus_damage += int(float(player_armor) * 0.5)
			result.descriptions.append("护甲转伤害 %d" % int(float(player_armor) * 0.5))

	if dice_def.damage_shield:
		result.apply_statuses.append({
			"type": GameTypes.StatusType.DODGE,
			"value": 100,
			"duration": 1,
			"target": "self"
		})
		result.descriptions.append("伤害盾：100%% 闪避 1 回合")

	if dice_def.execute_threshold > 0.0:
		var exec_result := _apply_execute(dice_def, target_enemy)
		result.bonus_mult *= exec_result.bonus_mult
		if exec_result.bonus_mult > 1.0:
			result.descriptions.append("处决！×+%.1f" % exec_result.bonus_mult)
		if dice_def.execute_heal > 0 and target_enemy and _is_enemy_below_threshold(target_enemy, dice_def.execute_threshold):
			result.heal += dice_def.execute_heal
			result.descriptions.append("处决回复 %d HP" % dice_def.execute_heal)

	if dice_def.scale_with_lost_hp > 0.0:
		var scale_result := _apply_scale_with_lost_hp(dice_def, player_hp, player_max_hp)
		result.bonus_damage += scale_result.bonus_damage
		if scale_result.bonus_damage > 0:
			result.descriptions.append("复仇之刃：+%d 基础伤害" % scale_result.bonus_damage)

	if dice_def.self_berserk:
		var berserk_result := _apply_berserk(dice_def, player_hp, player_max_hp)
		result.bonus_damage += berserk_result.bonus_damage
		result.bonus_mult *= berserk_result.bonus_mult
		result.self_damage += berserk_result.self_damage
		for desc in berserk_result.descriptions:
			result.descriptions.append(desc)

	if dice_def.scale_with_self_damage:
		var dmg_taken := player_max_hp - player_hp
		result.bonus_damage += int(float(dmg_taken) * 0.3)
		result.descriptions.append("受伤加成 +%d" % int(float(dmg_taken) * 0.3))

	if dice_def.low_hp_override_value > 0 and dice_def.low_hp_threshold > 0.0:
		var hp_ratio := float(player_hp) / float(player_max_hp) if player_max_hp > 0 else 1.0
		if hp_ratio <= dice_def.low_hp_threshold:
			result.bonus_damage += dice_def.low_hp_override_value
			result.descriptions.append("低血量！伤害 +%d" % dice_def.low_hp_override_value)

	if dice_def.bonus_damage_from_points > 0.0:
		var total_faces := DiceEffectResolver._total_faces(dice_def)
		var bonus_pts := int(float(total_faces) * dice_def.bonus_damage_from_points)
		result.bonus_damage += bonus_pts
		result.descriptions.append("基于面值 +%d 伤害" % bonus_pts)

	if dice_def.bonus_damage_per_element > 0:
		result.bonus_damage += dice_def.bonus_damage_per_element
		result.descriptions.append("元素加成 +%d 伤害" % dice_def.bonus_damage_per_element)

	if dice_def.scale_with_blood_rerolls:
		result.bonus_damage += player_rerolls * 2
		result.descriptions.append("血重投 +%d 伤害" % (player_rerolls * 2))

	if dice_def.purify_all:
		# v0.5 怒吼净化：清除全部负面 + 嘲讽全体1回合 + 每清1层对随机敌人造成1点基础伤害
		var cleansed_count: int = 0
		for st in [GameTypes.StatusType.POISON, GameTypes.StatusType.BURN, GameTypes.StatusType.VULNERABLE, GameTypes.StatusType.WEAK, GameTypes.StatusType.FREEZE]:
			result.apply_statuses.append({"type": st, "value": -99, "duration": 0, "target": "self"})
			# 统计清除层数（实际层数在 applier 中结算，这里预估）
			cleansed_count += 1
		# 嘲讽全体敌人 1 回合（v0.5_01 §1.8：覆写意图为普攻，伤害×0.7）
		for e: EnemyInstance in enemies:
			if e.hp > 0:
				result.apply_statuses.append({
					"type": GameTypes.StatusType.VULNERABLE,
					"value": 1,
					"duration": 1,
					"target": "enemy",
					"target_uid": e.uid,
					"is_taunt": true
				})
		# 每清1层对随机敌人造成1点基础伤害（简化：直接加 bonus_damage）
		result.bonus_damage += cleansed_count
		result.descriptions.append("怒吼净化：清除负面 + 嘲讽全体 + %d 伤害" % cleansed_count)

	if dice_def.splinter_damage > 0.0:
		var splinter_dmg := int(float(player_max_hp) * dice_def.splinter_damage)
		result.aoe += splinter_dmg
		result.descriptions.append("分裂 %.0f%% 最大HP AOE" % (dice_def.splinter_damage * 100))

	if dice_def.scale_with_hits:
		# v0.5 怒火：最近一次敌方回合中被打次数×25%增幅倍率 + ≥3次额外施加1层易伤
		var hit_count: int = PlayerState.hit_count_last_enemy_turn
		if hit_count > 0:
			var fury_mult: float = float(hit_count) * 0.25
			result.bonus_mult *= (1.0 + fury_mult)
			result.descriptions.append("怒火：被打%d次 → +%d%% 增幅" % [hit_count, int(fury_mult * 100)])
		if hit_count >= 3:
			result.apply_statuses.append({
				"type": GameTypes.StatusType.VULNERABLE,
				"value": 1,
				"duration": 99,
				"target": "enemy"
			})
			result.descriptions.append("怒火：≥3次 → 目标+1层易伤")

	if dice_def.purify_one:
		result.apply_statuses.append({"type": GameTypes.StatusType.POISON, "value": -1, "duration": 0, "target": "self"})
		result.apply_statuses.append({"type": GameTypes.StatusType.BURN, "value": -1, "duration": 0, "target": "self"})
		result.descriptions.append("净化一个负面状态")

	if dice_def.trigger_all_elements:
		for st in [GameTypes.StatusType.BURN, GameTypes.StatusType.POISON, GameTypes.StatusType.FREEZE]:
			result.apply_statuses.append({"type": st, "value": 1, "duration": 2, "target": "enemy"})
		result.descriptions.append("触发全元素效果")

	if dice_def.heal_from_value:
		var heal_val := _calc_heal_from_value(dice_def)
		if heal_val > 0:
			result.heal += heal_val
			result.descriptions.append("基于数值回复 %d HP" % heal_val)

	if dice_def.heal_per_cleanse > 0:
		result.heal += dice_def.heal_per_cleanse
		result.descriptions.append("净化回复 %d HP" % dice_def.heal_per_cleanse)

	# v0.5 战吼：上回合被打过时 +bonus_mult_if_hit 增幅
	if dice_def.bonus_mult_if_hit > 0.0 and PlayerState.was_hit_last_enemy_turn:
		result.bonus_mult *= (1.0 + dice_def.bonus_mult_if_hit)
		result.descriptions.append("战吼：受伤后 +%d%% 增幅" % int(dice_def.bonus_mult_if_hit * 100))

	# v0.5 血锁链绑定
	if dice_def.blood_chain_bind:
		if target_enemy and target_enemy.hp > 0:
			BloodChainSystem.bind(target_enemy.uid)
			result.descriptions.append("血锁链：绑定目标")

	# v0.5 单挑
	if dice_def.solo_seal:
		if target_enemy and target_enemy.hp > 0:
			SoloSealSystem.activate(target_enemy.uid)
			result.descriptions.append("单挑！双方伤害 ×%.1f" % SoloSealSystem.SOLO_DAMAGE_MULT)

	# v0.5 消耗伤痕（浴血之刃/血神之眼）
	if dice_def.consume_scar_ratio > 0.0:
		var consumed: int = ScarSystem.consume(dice_def.consume_scar_ratio)
		if consumed > 0:
			result.bonus_damage += consumed * 2  # 每层消耗 → +2 基础伤害
			result.descriptions.append("消耗 %d 层伤痕 → +%d 伤害" % [consumed, consumed * 2])

	# v0.5 伤痕加成（每层追加基础伤害）
	if dice_def.scar_bonus_per_stack > 0.0 and PlayerState.scar_stacks > 0:
		var scar_bonus: int = int(float(PlayerState.scar_stacks) * dice_def.scar_bonus_per_stack)
		if scar_bonus > 0:
			result.bonus_damage += scar_bonus
			result.descriptions.append("伤痕加成：%d层 × %.1f = +%d" % [PlayerState.scar_stacks, dice_def.scar_bonus_per_stack, scar_bonus])

	# v0.5 生命熔炉满血增幅（上次出牌触发的 +20% 在这里消费）
	if PlayerState.next_play_bonus_mult > 0.0:
		result.bonus_mult *= (1.0 + PlayerState.next_play_bonus_mult)
		result.descriptions.append("生命熔炉余韵：+%d%%" % int(PlayerState.next_play_bonus_mult * 100))
		PlayerState.next_play_bonus_mult = 0.0

	# v0.5 伤痕被动：普通攻击追加基础伤害（不消耗）
	# 这里只在没有其他特殊效果时触发（纯普通骰子）
	if not dice_def.has_on_play() and PlayerState.player_class == "warrior":
		var scar_atk_bonus: int = ScarSystem.get_normal_attack_bonus()
		if scar_atk_bonus > 0:
			result.bonus_damage += scar_atk_bonus
			result.descriptions.append("伤痕被动：+%d 基础伤害" % scar_atk_bonus)


# ============================================================
# 内部辅助函数
# ============================================================

static func _calc_armor_from_value(dice_def: DiceDef) -> int:
	var avg := DiceEffectResolver._avg_faces(dice_def)
	return maxi(0, int(avg * 0.5))


static func _calc_armor_from_total_points(dice_def: DiceDef) -> int:
	var total := DiceEffectResolver._total_faces(dice_def)
	return maxi(0, int(total * 0.3))


static func _apply_armor_break(target_enemy: EnemyInstance) -> DiceEffectResolver.ResolveResult:
	var result := DiceEffectResolver.ResolveResult.new()
	if not target_enemy or target_enemy.armor <= 0:
		return result
	result.pierce = target_enemy.armor
	result.bonus_damage = int(target_enemy.armor * 0.5)
	return result


static func _apply_execute(dice_def: DiceDef, target_enemy: EnemyInstance) -> DiceEffectResolver.ResolveResult:
	var result := DiceEffectResolver.ResolveResult.new()
	if not target_enemy:
		return result
	if _is_enemy_below_threshold(target_enemy, dice_def.execute_threshold):
		result.bonus_mult = maxf(dice_def.execute_mult, 2.0) if dice_def.execute_mult > 0.0 else 2.0
	return result


static func _is_enemy_below_threshold(enemy: EnemyInstance, threshold_pct: float) -> bool:
	if not enemy or enemy.max_hp <= 0:
		return false
	var current_pct := (float(enemy.hp) / float(enemy.max_hp)) * 100.0
	return current_pct <= threshold_pct


## v0.5 复仇之刃：追加基础伤害 = 当前已损失HP × 25%（向上取整，封顶 80 点）
static func _apply_scale_with_lost_hp(dice_def: DiceDef, player_hp: int, player_max_hp: int) -> DiceEffectResolver.ResolveResult:
	var result := DiceEffectResolver.ResolveResult.new()
	if player_max_hp <= 0:
		return result
	var lost_hp: int = player_max_hp - player_hp
	var bonus: int = mini(80, int(ceil(float(lost_hp) * dice_def.scale_with_lost_hp)))
	result.bonus_damage = bonus
	return result


static func _apply_berserk(dice_def: DiceDef, player_hp: int, player_max_hp: int) -> DiceEffectResolver.ResolveResult:
	var result := DiceEffectResolver.ResolveResult.new()
	if player_max_hp <= 0:
		return result
	var hp_ratio := float(player_hp) / float(player_max_hp)
	var atk_bonus := int((1.0 - hp_ratio) * 10.0)
	var self_dmg := maxi(1, int(player_max_hp * 0.05))
	result.bonus_damage = atk_bonus
	result.bonus_mult = 1.0 + (1.0 - hp_ratio)
	result.self_damage = self_dmg
	result.descriptions.append("狂暴 %d，×+%.1f，自伤 %d" % [atk_bonus, result.bonus_mult, self_dmg])
	return result


static func _calc_heal_from_value(dice_def: DiceDef) -> int:
	var avg := DiceEffectResolver._avg_faces(dice_def)
	return maxi(0, int(avg * 0.3))
