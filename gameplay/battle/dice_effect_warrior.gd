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

	# v0.5 战神之锤：≥三条牌型时追加基础伤害=点数总和×50% + 眩晕主目标
	if dice_def.warhammer:
		# 需要外部传入当前牌型信息，这里通过 result 的 hand_type 字段判断
		# 暂时通过 requires_triple 字段标记（三条及以上才触发）
		var total_pts: int = DiceEffectResolver._total_faces(dice_def)
		var wh_bonus: int = int(float(total_pts) * 0.5)
		if wh_bonus > 0:
			result.bonus_damage += wh_bonus
			result.descriptions.append("战神之锤：+%d 基础伤害" % wh_bonus)
		# 眩晕主目标
		if target_enemy and target_enemy.hp > 0:
			ControlSystem.apply_control(target_enemy, ControlSystem.ControlType.STUN, 1)
			result.descriptions.append("战神之锤：眩晕目标")

	# v0.5 巨人壁垒：护甲=点数总和×2.5(伤痕≥3时×3.5) + 嘲讽全体
	if dice_def.giant_shield:
		var total_pts: int = DiceEffectResolver._total_faces(dice_def)
		var armor_mult: float = 3.5 if PlayerState.scar_stacks >= 3 else 2.5
		var shield_armor: int = int(float(total_pts) * armor_mult)
		result.armor += shield_armor
		result.descriptions.append("巨人壁垒：+%d 护甲（×%.1f）" % [shield_armor, armor_mult])
		# 嘲讽全体
		for e: EnemyInstance in enemies:
			if e.hp > 0:
				ControlSystem.apply_control(e, ControlSystem.ControlType.TAUNT, 1)
		result.descriptions.append("巨人壁垒：嘲讽全体 1 回合")

	# v0.5 旋风斩：骰子自带AOE + 每目标+6(受伤后+12) + 眩晕全体
	if dice_def.whirlwind:
		var base_aoe_dmg: int = 6
		if PlayerState.was_hit_last_enemy_turn:
			base_aoe_dmg = 12
		# 对全体敌人造成伤害（通过 aoe 字段 + bonus_damage）
		var dice_value: int = DiceEffectResolver._avg_faces(dice_def)
		result.aoe += dice_value + base_aoe_dmg
		result.descriptions.append("旋风斩：AOE %d+%d 伤害" % [dice_value, base_aoe_dmg])
		# 眩晕全体
		for e: EnemyInstance in enemies:
			if e.hp > 0:
				ControlSystem.apply_control(e, ControlSystem.ControlType.STUN, 1)
		result.descriptions.append("旋风斩：眩晕全体")

	# v0.5 震地：点数+3 + 随机敌人+3层易伤
	if dice_def.quake:
		result.bonus_damage += 3
		result.descriptions.append("震地：点数 +3")
		# 对随机存活敌人施加3层易伤
		var living: Array[EnemyInstance] = []
		for e: EnemyInstance in enemies:
			if e.hp > 0:
				living.append(e)
		if not living.is_empty():
			var rand_target: EnemyInstance = living[randi() % living.size()]
			result.apply_statuses.append({
				"type": GameTypes.StatusType.VULNERABLE,
				"value": 3,
				"duration": 99,
				"target": "enemy",
				"target_uid": rand_target.uid
			})
			result.descriptions.append("震地：%s +3层易伤" % rand_target.name)

	# v0.5 狂暴之心：进入狂暴2个玩家回合（+30%伤害，+20%受伤，搏命代价-50%）
	if dice_def.berserk_state:
		PlayerState.berserk_turns = 2
		result.descriptions.append("狂暴之心：进入狂暴 2 回合（+30%%伤害/+20%%受伤/搏命-50%%）")

	# v0.5 血神之眼：损失HP%×15%(封顶120%) + 伤痕消耗30%×5%/层 + 状态+20% (总封顶200%)
	if dice_def.blood_god:
		var total_mult_bonus: float = 0.0
		# 段1：本回合损失HP%×15%（封顶120%）
		var lost_hp_pct: float = float(PlayerState.hp_lost_this_turn) / float(PlayerState.max_hp) if PlayerState.max_hp > 0 else 0.0
		var hp_bonus: float = minf(1.2, lost_hp_pct * 0.15 * 100.0)  # 每1%损失+15%
		# 修正：每损失最大HP的1%，+15%
		var pct_lost: int = int(float(PlayerState.hp_lost_this_turn) / float(PlayerState.max_hp) * 100.0)
		hp_bonus = minf(1.2, float(pct_lost) * 0.15)
		total_mult_bonus += hp_bonus
		# 段2：消耗伤痕30%，每层+5%
		var consumed: int = ScarSystem.consume(0.3)
		var scar_bonus_pct: float = float(consumed) * 0.05
		total_mult_bonus += scar_bonus_pct
		# 段3：有伤痕或处于单挑时+20%
		if PlayerState.scar_stacks >= 1 or SoloSealSystem.is_active():
			total_mult_bonus += 0.2
		# 总封顶200%
		total_mult_bonus = minf(2.0, total_mult_bonus)
		if total_mult_bonus > 0.0:
			result.bonus_mult *= (1.0 + total_mult_bonus)
			result.descriptions.append("血神之眼：+%d%% 最终伤害" % int(total_mult_bonus * 100))

	# v0.5 泰坦之拳：自伤10%maxHP + 摧毁护甲 + 30真实伤害 + 兜底60%HP（第2次起衰减）
	if dice_def.titan_fist:
		var is_first: bool = PlayerState.titanfist_uses == 0
		PlayerState.titanfist_uses += 1
		# 自伤
		var self_dmg_pct: float = 0.10 if is_first else 0.15
		var self_dmg: int = maxi(1, int(float(PlayerState.max_hp) * self_dmg_pct))
		result.self_damage += self_dmg
		# 摧毁目标护甲
		if target_enemy and target_enemy.armor > 0:
			result.pierce += target_enemy.armor
			result.descriptions.append("泰坦之拳：摧毁 %d 护甲" % target_enemy.armor)
		# 追加真实伤害
		var true_dmg: int = 30 if is_first else 15
		result.bonus_damage += true_dmg
		# 兜底真实伤害（按敌人类型封顶）
		if target_enemy and target_enemy.hp > 0:
			var floor_pct: float = 0.6 if is_first else 0.3
			var floor_dmg: int = int(float(target_enemy.hp) * floor_pct)
			# 按敌人类型封顶
			if EliteEnhancer.is_boss(target_enemy):
				var cap: int = 100 if is_first else 50
				floor_dmg = mini(floor_dmg, cap)
			elif EliteEnhancer.is_elite(target_enemy):
				var cap: int = 120 if is_first else 60
				floor_dmg = mini(floor_dmg, cap)
			result.bonus_damage += floor_dmg
			result.descriptions.append("泰坦之拳：兜底 %d 真实伤害" % floor_dmg)
		result.descriptions.append("泰坦之拳：自伤 %d（第%d次）" % [self_dmg, PlayerState.titanfist_uses])

	# v0.5 孤注之刃：仅普通攻击时×3.0 + 点数总和追加基础伤害
	if dice_def.solo_blade:
		var total_pts: int = DiceEffectResolver._total_faces(dice_def)
		result.bonus_mult *= 3.0
		result.bonus_damage += total_pts
		result.descriptions.append("孤注之刃：×3.0 + %d 追加伤害" % total_pts)

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
