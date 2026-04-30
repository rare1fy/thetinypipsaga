## 骰子 onPlay 特效统一结算引擎
## 对应 React 原版 diceEffects.ts + postPlayEffects.ts
## 职责：纯函数集合，接收骰子定义 + 战斗上下文，返回特效结算结果
## 设计原则：
##   - SRP：每个特效 flag 只做一件事
##   - 纯函数：无副作用，不修改任何入参，只返回结算结果字典
##   - DRY：通用逻辑抽取为内部辅助函数
##   - 字段映射：所有字段名严格对应 DiceDef @export 属性
class_name DiceEffectResolver
extends RefCounted


# ============================================================
# 公开数据结构
# ============================================================

## 结算结果 - 所有特效效果打包返回
class ResolveResult:
	## 额外造成的伤害
	var bonus_damage: int = 0
	## 伤害乘数加成（增量语义：+0.5 = +50%；最终伤害按 (1 + bonus_mult) 计算）
	## [FIX-DMG-CH6-20260428] 默认值从 1.0 改为 0.0。原本 1.0 会在 calculate_damage 的 (1 + bonus_mult)
	## 公式中额外乘 2，导致所有职业普攻凭空 ×2。所有 `+=` 累加点本就基于"0 起步"的增量语义，此处初值是 bug。
	var bonus_mult: float = 0.0
	## 对自身的伤害
	var self_damage: int = 0
	## 自身伤害（按最高 HP 百分比）
	var self_damage_percent: float = 0.0
	## 回复 HP
	var heal: int = 0
	## 护甲穿透（无视护甲值）
	var pierce: int = 0
	## AOE 伤害
	var aoe: int = 0
	## 获得的护甲
	var armor: int = 0
	## 回复 reroll 次数
	var reroll: int = 0
	## 增加出牌次数
	var extra_plays: int = 0
	## 临时骰子 ID 列表（如影分身骰子）
	var temp_dice: Array[String] = []
	## 是否吞噬手牌中的一张骰子
	var devour_die: bool = false
	## 是否与未选中骰子交换
	var swap_with_unselected: bool = false
	## 是否统一手牌元素
	var unify_element: bool = false
	## 是否复制多数元素
	var copy_majority_element: bool = false
	## 是否护甲转伤害
	var armor_to_damage: bool = false
	## 是否弹回手牌（出牌后不标记为 spent）
	var always_bounce: bool = false
	## 是否保留在手牌（出牌后不标记为 spent，类似 always_bounce 但语义不同）
	var stay_in_hand: bool = false
	## 是否自我复制（出牌后复制自身到手牌）
	var clone_self: bool = false
	## 本次出牌产生/增加的状态效果列表
	var apply_statuses: Array[Dictionary] = []
	## 特效描述文本（用于日志 / UI 展示）
	var descriptions: Array[String] = []


# ============================================================
# 主入口
# ============================================================

## 结算一张骰子的 onPlay 特效
## §6.6 第 5 级 skip_on_play：战士多选普攻时为 true，整个 onPlay 特效链路跳过。
static func resolve_on_play(
	dice_def: DiceDef,
	player_hp: int,
	player_max_hp: int,
	player_rerolls: int,
	player_combo: int,
	player_armor: int,
	target_enemy: EnemyInstance,
	enemies: Array[EnemyInstance],
	dice_in_hand: Array[DiceDef] = [],
	unselected_dice: Array[DiceDef] = [],
	skip_on_play: bool = false
) -> ResolveResult:
	if skip_on_play:
		return ResolveResult.new()
	if not dice_def or not dice_def.has_on_play():
		return ResolveResult.new()

	var result := ResolveResult.new()

	# 通用特效
	_resolve_common(dice_def, result, target_enemy, enemies)

	# 战士特效
	DiceEffectWarrior.resolve(dice_def, result, player_hp, player_max_hp, player_rerolls, player_armor, target_enemy, enemies, dice_in_hand)

	# 法师特效
	DiceEffectMage.resolve(dice_def, result, player_hp, player_max_hp, player_rerolls, player_combo, target_enemy, enemies, dice_in_hand)

	# 盗贼特效
	DiceEffectRogue.resolve(dice_def, result, player_hp, player_max_hp, player_rerolls, player_combo, target_enemy, enemies, dice_in_hand, unselected_dice)

	return result


## 结算一张骰子的 onSkip 特效
static func resolve_on_skip(
	dice_def: DiceDef,
	_player_hp: int,
	_player_max_hp: int,
	_dice_in_hand: Array[DiceDef] = [],
	_unselected_dice: Array[DiceDef] = []
) -> ResolveResult:
	if not dice_def:
		return ResolveResult.new()

	var result := ResolveResult.new()

	if dice_def.heal_on_skip > 0:
		result.heal += dice_def.heal_on_skip
		result.descriptions.append("跳过回复 %d HP" % dice_def.heal_on_skip)

	if dice_def.purify_one_on_skip:
		result.apply_statuses.append({"type": GameTypes.StatusType.POISON, "value": -1, "duration": 0, "target": "self"})
		result.apply_statuses.append({"type": GameTypes.StatusType.BURN, "value": -1, "duration": 0, "target": "self"})
		result.descriptions.append("跳过时净化一个负面状态")

	if dice_def.bonus_on_keep > 0:
		# onSkip 时视为保持，适用 onKeep 加成
		result.bonus_damage += dice_def.bonus_on_keep
		result.descriptions.append("保持加成 +%d 伤害" % dice_def.bonus_on_keep)

	return result


## 结算一张骰子的 onKeep 特效
static func resolve_on_keep(
	dice_def: DiceDef,
	_player_hp: int,
	_player_max_hp: int,
	kept_turns: int
) -> ResolveResult:
	if not dice_def:
		return ResolveResult.new()

	var result := ResolveResult.new()

	if dice_def.bonus_on_keep > 0:
		var kept_bonus: int = mini(kept_turns * dice_def.bonus_on_keep, dice_def.keep_bonus_cap)
		result.bonus_damage += kept_bonus
		result.descriptions.append("保持加成 +%d 伤害" % kept_bonus)

	if dice_def.reroll_on_keep:
		result.reroll += 1
		result.descriptions.append("保持 +1 重投")

	if dice_def.bonus_mult_on_keep > 0.0:
		result.bonus_mult += dice_def.bonus_mult_on_keep
		result.descriptions.append("保持 ×+%.1f" % dice_def.bonus_mult_on_keep)

	if dice_def.boost_lowest_on_keep > 0:
		result.bonus_damage += dice_def.boost_lowest_on_keep
		result.descriptions.append("提升最低 +%d" % dice_def.boost_lowest_on_keep)

	return result


# ============================================================
# 通用特效（所有职业共用）
# ============================================================

static func _resolve_common(
	dice_def: DiceDef,
	result: ResolveResult,
	target_enemy: EnemyInstance,
	_enemies: Array[EnemyInstance]
) -> void:
	if dice_def.bonus_damage > 0:
		result.bonus_damage += dice_def.bonus_damage
		result.descriptions.append("额外伤害 +%d" % dice_def.bonus_damage)

	if dice_def.bonus_mult > 0.0:
		result.bonus_mult += dice_def.bonus_mult
		result.descriptions.append("伤害 ×+%.1f" % dice_def.bonus_mult)

	if dice_def.self_damage > 0:
		result.self_damage += dice_def.self_damage
		result.descriptions.append("自伤 %d" % dice_def.self_damage)

	if dice_def.self_damage_percent > 0.0:
		result.self_damage_percent += dice_def.self_damage_percent
		result.descriptions.append("自伤 %.0f%% HP" % (dice_def.self_damage_percent * 100))

	if dice_def.heal > 0:
		result.heal += dice_def.heal
		result.descriptions.append("回复 %d HP" % dice_def.heal)

	if dice_def.pierce > 0:
		result.pierce += dice_def.pierce
		result.descriptions.append("穿透 %d 护甲" % dice_def.pierce)

	if dice_def.armor > 0:
		result.armor += dice_def.armor
		result.descriptions.append("获得 %d 护甲" % dice_def.armor)

	# AOE 标记 + AOE 伤害
	if dice_def.aoe and dice_def.aoe_damage > 0:
		result.aoe += dice_def.aoe_damage
		result.descriptions.append("AOE %d 伤害" % dice_def.aoe_damage)
	elif dice_def.aoe:
		result.descriptions.append("AOE")

	# AOE 百分比伤害
	if dice_def.aoe_damage_percent > 0.0 and target_enemy:
		var pct_dmg: int = int(float(target_enemy.max_hp) * dice_def.aoe_damage_percent)
		result.aoe += pct_dmg
		result.descriptions.append("AOE %.0f%% 最大HP 伤害" % (dice_def.aoe_damage_percent * 100))

	# 状态效果给敌人
	if dice_def.status_to_enemy_value > 0:
		result.apply_statuses.append({
			"type": dice_def.status_to_enemy_type,
			"value": dice_def.status_to_enemy_value,
			"duration": dice_def.status_to_enemy_duration,
			"target": "enemy"
		})
		result.descriptions.append("敌人 %s %d回合" % [
			GameTypes.StatusType.keys()[dice_def.status_to_enemy_type],
			dice_def.status_to_enemy_duration
		])

	# 状态效果给自己
	if dice_def.status_to_self_value > 0:
		result.apply_statuses.append({
			"type": dice_def.status_to_self_type,
			"value": dice_def.status_to_self_value,
			"duration": dice_def.status_to_self_duration,
			"target": "self"
		})
		result.descriptions.append("自身 %s %d回合" % [
			GameTypes.StatusType.keys()[dice_def.status_to_self_type],
			dice_def.status_to_self_value,
			dice_def.status_to_self_duration
		])

	# 净化所有
	if dice_def.purify_all:
		result.apply_statuses.append({"type": GameTypes.StatusType.POISON, "value": -999, "duration": 0, "target": "self"})
		result.apply_statuses.append({"type": GameTypes.StatusType.BURN, "value": -999, "duration": 0, "target": "self"})
		result.descriptions.append("净化所有负面状态")

	# 移除灼烧
	if dice_def.remove_burn > 0:
		result.apply_statuses.append({"type": GameTypes.StatusType.BURN, "value": -dice_def.remove_burn, "duration": 0, "target": "self"})
		result.descriptions.append("移除 %d 层灼烧" % dice_def.remove_burn)

	# 最高 HP 加成
	if dice_def.max_hp_bonus > 0:
		result.heal += dice_def.max_hp_bonus
		result.descriptions.append("最高HP +%d" % dice_def.max_hp_bonus)

	# 反向数值
	if dice_def.reverse_value:
		var total_faces: int = _total_faces(dice_def)
		var reversed_dmg: int = maxi(0, 7 * dice_def.faces.size() - total_faces)
		result.bonus_damage += reversed_dmg
		result.descriptions.append("反转数值 %d 伤害" % reversed_dmg)

	# 覆盖数值
	if dice_def.override_value > 0:
		result.bonus_damage += dice_def.override_value
		result.descriptions.append("固定 %d 伤害" % dice_def.override_value)

	# 复制最高面值
	if dice_def.copy_highest_value:
		var highest_face: int = _get_highest_face_in_hand()
		result.bonus_damage += highest_face
		result.descriptions.append("复制最高面值 %d 伤害" % highest_face)

	# 吞噬骰子
	if dice_def.devour_die:
		var total_faces: int = _total_faces(dice_def)
		result.bonus_damage += total_faces
		result.devour_die = true
		result.descriptions.append("吞噬 +%d 伤害（消耗一张骰子）" % total_faces)

	# 与未选中骰子交换
	if dice_def.swap_with_unselected:
		result.swap_with_unselected = true
		result.descriptions.append("交换未选骰子")

	# 随机目标
	if dice_def.random_target:
		result.descriptions.append("随机目标")

	# 首次出牌标记
	if dice_def.first_play_only:
		result.descriptions.append("仅首次出牌生效（待 controller 追踪）")

	# 需要三条
	if dice_def.requires_triple:
		result.descriptions.append("需要三条才能触发")

	# 不参与牌型判定
	if dice_def.ignore_for_hand_type:
		result.descriptions.append("不参与牌型判定")

	# 万能牌
	if dice_def.wildcard:
		result.descriptions.append("万能牌")

	# 回血或增上限（补充版，含参数）
	if dice_def.heal_or_max_hp and dice_def.heal_per_cleanse <= 0:
		var heal_val: int = _calc_heal_or_max_hp(dice_def, 0, 0)
		result.heal += heal_val
		result.descriptions.append("回复 %d HP（满血则增加上限）" % heal_val)

	# 净化回复
	if dice_def.heal_per_cleanse > 0:
		result.heal += dice_def.heal_per_cleanse
		result.descriptions.append("净化回复 %d HP" % dice_def.heal_per_cleanse)


# ============================================================
# 内部辅助函数 - 面值计算
# ============================================================

static func _total_faces(dice_def: DiceDef) -> int:
	if dice_def.faces.is_empty():
		return 0
	var total: int = 0
	for face: int in dice_def.faces:
		total += face
	return total


static func _avg_faces(dice_def: DiceDef) -> float:
	if dice_def.faces.is_empty():
		return 0.0
	return float(_total_faces(dice_def)) / float(dice_def.faces.size())


static func _get_highest_face_in_hand() -> int:
	if GameManager and GameManager.has_method("get_highest_face_in_hand"):
		return GameManager.get_highest_face_in_hand()
	return 1


static func _calc_heal_or_max_hp(dice_def: DiceDef, player_hp: int, player_max_hp: int) -> int:
	if player_hp >= player_max_hp:
		return dice_def.max_hp_bonus
	return maxi(1, int(player_max_hp * 0.1))
