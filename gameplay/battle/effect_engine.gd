## 统一效果执行引擎
## 职责：接收效果列表 + 上下文，按 EffectType 分发执行，返回结算结果
## 设计原则：
##   - 单一入口：所有效果（骰子/遗物/敌人技能/牌型/升级/弱点击破）都走这里
##   - 数据驱动：效果行为由 EffectType 枚举 + params 决定，不关心来源
##   - 校验前置：执行前调用 validate_params，缺字段直接报错跳过
##   - 纯结算：不直接修改游戏状态，返回 ExecuteResult 由调用方应用

class_name EffectEngine
extends RefCounted


# ============================================================
# 执行上下文（调用方填充，引擎只读）
# ============================================================

class ExecuteContext:
	## 来源信息
	var source: EffectTypes.EffectSource = EffectTypes.EffectSource.DICE_ON_PLAY
	var source_id: String = ""  # 骰子id / 遗物id / 敌人id

	## 玩家状态（只读快照）
	var player_hp: int = 0
	var player_max_hp: int = 0
	var player_armor: int = 0
	var player_combo: int = 0  # 本回合已出牌次数
	var player_rerolls: int = 0
	var player_scar_stacks: int = 0  # 伤痕层数
	var player_berserk_turns: int = 0  # 狂暴剩余回合

	## 骰子信息（出牌时填充）
	var dice_points_total: int = 0  # 选中骰子点数总和
	var dice_count: int = 0  # 选中骰子数量
	var hand_type: String = ""  # 当前牌型
	var hand_size: int = 0  # 手牌数量
	var kept_turns: int = 0  # 保留回合数（法师吟唱）

	## 目标信息
	var target_enemy: EnemyInstance = null
	var enemies: Array[EnemyInstance] = []

	## 手牌信息
	var dice_in_hand: Array = []  # DiceDef 数组
	var unselected_dice: Array = []  # 未选中的骰子

	## 战斗状态
	var was_hit_last_turn: bool = false  # 上回合是否被打
	var kills_this_play: int = 0  # 本次出牌击杀数


# ============================================================
# 执行结果（引擎输出，调用方应用）
# ============================================================

class ExecuteResult:
	## 伤害类
	var bonus_damage: int = 0
	var bonus_mult: float = 0.0  # 增量语义：+0.5 = +50%
	var aoe_damage: int = 0
	var is_aoe: bool = false
	var pierce: int = 0
	var true_damage: int = 0
	var is_armor_break: bool = false
	var overkill_transfer_ratio: float = 0.0
	var splash_ratio: float = 0.0

	## 防御类
	var heal: int = 0
	var armor: int = 0
	var barrier: int = 0
	var max_hp_delta: int = 0

	## 代价类
	var self_damage: int = 0
	var self_damage_percent: float = 0.0

	## 状态类
	var apply_statuses: Array[Dictionary] = []  # [{status, value, target, duration}]
	var purify_scope: String = ""  # "all" / "one" / ""

	## 控制类
	var controls: Array[Dictionary] = []  # [{control, duration/distance, target}]

	## 手牌操控类
	var extra_plays: int = 0
	var extra_rerolls: int = 0
	var extra_draws: int = 0
	var bounce: bool = false
	var stay_in_hand: bool = false
	var temp_dice: Array[String] = []
	var devour_die: bool = false
	var swap_with_unselected: bool = false
	var preserve_die: bool = false
	var return_to_deck: bool = false
	var lock_die: bool = false

	## 骰子数值类
	var points_delta: int = 0
	var unify_element: bool = false
	var reverse_value: bool = false
	var override_value: int = 0

	## 经济类
	var gold_gain: int = 0

	## 敌人专属（塞骰/替换骰/偷取）
	var curse_dice: Array[Dictionary] = []  # [{die_id, count}]
	var replace_dice: Array[Dictionary] = []  # [{from, to}]
	var steal_gold: int = 0  # 偷取金币数量
	var steal_armor: int = 0  # 偷取护甲数量

	## Buff类
	var berserk: Dictionary = {}  # {turns, damage_mult, taken_mult, gamble_cost} 或空
	var blood_chain_target: String = ""  # "main" / "all" / ""
	var solo_seal_mult: float = 0.0

	## 职业机制类
	var scar_consume_ratio: float = 0.0
	var scar_bonus_per_stack: float = 0.0
	var charge_turns: int = 0
	var ignore_taunt: bool = false

	## 规则改变类（由 Applier 在战斗开始/回合开始时应用）
	var draw_count_delta: int = 0
	var hand_limit_delta: int = 0
	var all_dice_points_plus: int = 0
	var death_immunity_cooldown: int = 0  # >0 表示有免死效果

	## 高级效果标记（由 Applier 根据目标状态执行）
	var execute_threshold: float = 0.0  # >0 表示有处决效果
	var execute_mult: float = 0.0
	var detonate_status: String = ""  # 非空表示有引爆效果
	var detonate_damage_per_stack: int = 0
	var damage_shield_value: int = 0
	var damage_shield_duration: int = 0

	## 法脉紊乱相关
	var reduce_disruption: int = 0  # 降低法脉紊乱层数
	var consume_disruption_aoe_damage: int = 0  # 消耗法脉紊乱转AOE伤害（已算好的总伤害）
	var consume_disruption_aoe_per_stack: int = 0  # 每层伤害系数（由调用方读取 PlayerState 计算）

	## 日志
	var descriptions: Array[String] = []

	## 合并另一个结果（用于多效果叠加）
	func merge(other: ExecuteResult) -> void:
		bonus_damage += other.bonus_damage
		bonus_mult += other.bonus_mult
		aoe_damage += other.aoe_damage
		is_aoe = is_aoe or other.is_aoe
		pierce += other.pierce
		true_damage += other.true_damage
		is_armor_break = is_armor_break or other.is_armor_break
		if other.overkill_transfer_ratio > 0.0:
			overkill_transfer_ratio = other.overkill_transfer_ratio
		if other.splash_ratio > 0.0:
			splash_ratio = other.splash_ratio
		heal += other.heal
		armor += other.armor
		barrier += other.barrier
		max_hp_delta += other.max_hp_delta
		self_damage += other.self_damage
		self_damage_percent += other.self_damage_percent
		apply_statuses.append_array(other.apply_statuses)
		if other.purify_scope != "":
			purify_scope = other.purify_scope
		controls.append_array(other.controls)
		extra_plays += other.extra_plays
		extra_rerolls += other.extra_rerolls
		extra_draws += other.extra_draws
		bounce = bounce or other.bounce
		stay_in_hand = stay_in_hand or other.stay_in_hand
		temp_dice.append_array(other.temp_dice)
		devour_die = devour_die or other.devour_die
		swap_with_unselected = swap_with_unselected or other.swap_with_unselected
		preserve_die = preserve_die or other.preserve_die
		return_to_deck = return_to_deck or other.return_to_deck
		lock_die = lock_die or other.lock_die
		points_delta += other.points_delta
		unify_element = unify_element or other.unify_element
		reverse_value = reverse_value or other.reverse_value
		if other.override_value > 0:
			override_value = other.override_value
		gold_gain += other.gold_gain
		if not other.berserk.is_empty():
			berserk = other.berserk
		if other.blood_chain_target != "":
			blood_chain_target = other.blood_chain_target
		if other.solo_seal_mult > 0.0:
			solo_seal_mult = other.solo_seal_mult
		if other.scar_consume_ratio > 0.0:
			scar_consume_ratio = other.scar_consume_ratio
		if other.scar_bonus_per_stack > 0.0:
			scar_bonus_per_stack = other.scar_bonus_per_stack
		if other.charge_turns > 0:
			charge_turns = other.charge_turns
		ignore_taunt = ignore_taunt or other.ignore_taunt
		draw_count_delta += other.draw_count_delta
		hand_limit_delta += other.hand_limit_delta
		all_dice_points_plus += other.all_dice_points_plus
		if other.death_immunity_cooldown > 0:
			death_immunity_cooldown = other.death_immunity_cooldown
		if other.execute_threshold > 0.0:
			execute_threshold = other.execute_threshold
			execute_mult = other.execute_mult
		if other.detonate_status != "":
			detonate_status = other.detonate_status
			detonate_damage_per_stack = other.detonate_damage_per_stack
		damage_shield_value += other.damage_shield_value
		if other.damage_shield_duration > 0:
			damage_shield_duration = other.damage_shield_duration
		reduce_disruption += other.reduce_disruption
		consume_disruption_aoe_damage += other.consume_disruption_aoe_damage
		if other.consume_disruption_aoe_per_stack > 0:
			consume_disruption_aoe_per_stack = other.consume_disruption_aoe_per_stack
		curse_dice.append_array(other.curse_dice)
		replace_dice.append_array(other.replace_dice)
		steal_gold += other.steal_gold
		steal_armor += other.steal_armor
		descriptions.append_array(other.descriptions)


# ============================================================
# 主入口
# ============================================================

## 执行一组效果，返回合并后的结算结果
static func execute(effects: Array, ctx: ExecuteContext) -> ExecuteResult:
	var final_result := ExecuteResult.new()

	for effect: Dictionary in effects:
		# 校验
		if not EffectTypes.validate_params(effect):
			continue

		# 条件检查：params 中的 condition 字段
		var params: Dictionary = effect.get("params", {})
		var condition: String = params.get("condition", "")
		if condition != "" and not _check_condition(condition, ctx):
			continue

		# 执行单个效果
		var result := _execute_single(effect, ctx)
		final_result.merge(result)

	return final_result


## 检查效果条件是否满足
static func _check_condition(condition: String, ctx: ExecuteContext) -> bool:
	match condition:
		"full_hp":
			return ctx.player_hp >= ctx.player_max_hp
		"not_full_hp":
			return ctx.player_hp < ctx.player_max_hp
		"was_hit":
			return ctx.was_hit_last_turn
		"has_scar":
			return ctx.player_scar_stacks > 0
		"berserk":
			return ctx.player_berserk_turns > 0
		_:
			return true


## 执行单个效果
static func _execute_single(effect: Dictionary, ctx: ExecuteContext) -> ExecuteResult:
	var result := ExecuteResult.new()
	var type: int = effect.get("type", -1)
	var params: Dictionary = effect.get("params", {})

	match type:
		# ---- 伤害类 ----
		EffectTypes.EffectType.BONUS_DAMAGE:
			result.bonus_damage += params.get("value", 0)
			result.descriptions.append("追加伤害 +%d" % params.get("value", 0))

		EffectTypes.EffectType.BONUS_DAMAGE_SCALED:
			var value := _calc_scaled_damage(params, ctx)
			result.bonus_damage += value
			result.descriptions.append("比例追加伤害 +%d" % value)

		EffectTypes.EffectType.BONUS_MULT:
			result.bonus_mult += params.get("value", 0.0)
			result.descriptions.append("伤害倍率 +%.0f%%" % (params.get("value", 0.0) * 100))

		EffectTypes.EffectType.AOE:
			result.is_aoe = true
			var aoe_val: int = params.get("value", 0)
			if aoe_val > 0:
				result.aoe_damage += aoe_val
			result.descriptions.append("AOE" + (" +%d" % aoe_val if aoe_val > 0 else ""))

		EffectTypes.EffectType.SPLASH:
			result.splash_ratio = params.get("ratio", 0.0)
			result.descriptions.append("溅射 %.0f%%" % (result.splash_ratio * 100))

		EffectTypes.EffectType.OVERKILL_TRANSFER:
			result.overkill_transfer_ratio = params.get("ratio", 0.0)
			result.descriptions.append("溢出转移 %.0f%%" % (result.overkill_transfer_ratio * 100))

		EffectTypes.EffectType.PIERCE:
			result.pierce += params.get("value", 0)
			result.descriptions.append("穿透 %d" % params.get("value", 0))

		EffectTypes.EffectType.TRUE_DAMAGE:
			result.true_damage += params.get("value", 0)
			result.descriptions.append("真实伤害 %d" % params.get("value", 0))

		EffectTypes.EffectType.EXECUTE:
			# 处决逻辑由 Applier 根据目标HP判断
			result.execute_threshold = params.get("threshold", 0.0)
			result.execute_mult = params.get("mult", 999.0)
			result.descriptions.append("处决（阈值%.0f%%）" % (result.execute_threshold * 100))

		EffectTypes.EffectType.ARMOR_BREAK:
			result.is_armor_break = true
			result.descriptions.append("摧毁护甲")

		EffectTypes.EffectType.ESCALATE:
			# 递增伤害由外部追踪触发次数，这里只标记
			result.descriptions.append("递增伤害")

		EffectTypes.EffectType.DETONATE:
			# 引爆逻辑由 Applier 根据目标状态层数计算
			result.detonate_status = params.get("status", "")
			result.detonate_damage_per_stack = params.get("damage_per_stack", 0)
			result.descriptions.append("引爆 %s" % result.detonate_status)

		# ---- 防御类 ----
		EffectTypes.EffectType.HEAL:
			result.heal += params.get("value", 0)
			result.descriptions.append("回复 %d HP" % params.get("value", 0))

		EffectTypes.EffectType.HEAL_ON_TRIGGER:
			# 条件治疗由触发系统处理，这里标记
			result.descriptions.append("条件治疗")

		EffectTypes.EffectType.ARMOR:
			var armor_val := _calc_armor(params, ctx)
			result.armor += armor_val
			result.descriptions.append("获得 %d 护甲" % armor_val)

		EffectTypes.EffectType.BARRIER:
			result.barrier += params.get("value", 0)
			result.descriptions.append("获得 %d 屏障" % params.get("value", 0))

		EffectTypes.EffectType.MAX_HP_CHANGE:
			result.max_hp_delta += params.get("delta", 0)
			result.descriptions.append("最大HP %+d" % params.get("delta", 0))

		# ---- 状态类 ----
		EffectTypes.EffectType.APPLY_STATUS:
			result.apply_statuses.append({
				"status": params.get("status", ""),
				"value": params.get("value", 0),
				"target": params.get("target", "enemy"),
				"duration": params.get("duration", 3),
			})
			result.descriptions.append("施加 %s %d层" % [params.get("status", ""), params.get("value", 0)])

		EffectTypes.EffectType.PURIFY:
			result.purify_scope = params.get("scope", "all")
			result.descriptions.append("净化 %s" % result.purify_scope)

		# ---- 控制类 ----
		EffectTypes.EffectType.CONTROL:
			result.controls.append({
				"control": params.get("control", ""),
				"duration": params.get("duration", 0),
				"distance": params.get("distance", 0),
				"target": params.get("target", "main"),
			})
			result.descriptions.append("控制: %s" % params.get("control", ""))

		EffectTypes.EffectType.IGNORE_TAUNT:
			result.ignore_taunt = true
			result.descriptions.append("无视嘲讽")

		# ---- 代价类 ----
		EffectTypes.EffectType.SELF_DAMAGE:
			if params.has("value"):
				result.self_damage += params.get("value", 0)
			if params.has("percent"):
				result.self_damage_percent += params.get("percent", 0.0)
			result.descriptions.append("自伤")

		# ---- Buff类 ----
		EffectTypes.EffectType.BERSERK:
			result.berserk = {
				"turns": params.get("turns", 0),
				"damage_mult": params.get("damage_mult", 0.0),
				"taken_mult": params.get("taken_mult", 0.0),
				"gamble_cost": params.get("gamble_cost", 0.0),
			}
			result.descriptions.append("狂暴 %d回合" % params.get("turns", 0))

		EffectTypes.EffectType.BLOOD_CHAIN:
			result.blood_chain_target = params.get("target", "main")
			result.descriptions.append("血锁链: %s" % result.blood_chain_target)

		EffectTypes.EffectType.SOLO_SEAL:
			result.solo_seal_mult = params.get("damage_mult", 0.0)
			result.descriptions.append("单挑 ×%.1f" % result.solo_seal_mult)

		# ---- 手牌操控类 ----
		EffectTypes.EffectType.BOUNCE:
			result.bounce = true
			result.descriptions.append("弹回手牌")

		EffectTypes.EffectType.RECOVER:
			result.descriptions.append("回收 %d" % params.get("count", 0))

		EffectTypes.EffectType.GRANT_PLAY:
			result.extra_plays += params.get("count", 0)
			result.descriptions.append("+%d 出牌" % params.get("count", 0))

		EffectTypes.EffectType.GRANT_REROLL:
			result.extra_rerolls += params.get("count", 0)
			result.descriptions.append("+%d 重投" % params.get("count", 0))

		EffectTypes.EffectType.DRAW:
			result.extra_draws += params.get("count", 0)
			result.descriptions.append("+%d 抽牌" % params.get("count", 0))

		EffectTypes.EffectType.LOCK_DIE:
			result.lock_die = true
			result.descriptions.append("锁定骰子")

		EffectTypes.EffectType.RETURN_TO_DECK:
			result.return_to_deck = true
			result.descriptions.append("回库")

		EffectTypes.EffectType.GRANT_TEMP_DIE:
			for i: int in range(params.get("count", 1)):
				result.temp_dice.append(params.get("die_type", "shadow"))
			result.descriptions.append("产出 %d 临时骰" % params.get("count", 1))

		EffectTypes.EffectType.CONSUME_TEMP_DIE:
			result.descriptions.append("消耗临时骰")

		EffectTypes.EffectType.TRANSFORM_DIE:
			result.descriptions.append("变形骰子")

		EffectTypes.EffectType.PRESERVE_DIE:
			result.preserve_die = true
			result.descriptions.append("保留骰子")

		EffectTypes.EffectType.INSERT_CURSE_DIE:
			var die_id: String = params.get("die_id", "cursed")
			var count: int = params.get("count", 1)
			result.curse_dice.append({"die_id": die_id, "count": count})
			result.descriptions.append("塞入 %s ×%d" % [die_id, count])

		EffectTypes.EffectType.REPLACE_PLAYER_DIE:
			var from_id: String = params.get("from", "")
			var to_id: String = params.get("to", "")
			result.replace_dice.append({"from": from_id, "to": to_id})
			result.descriptions.append("替换骰子: %s → %s" % [from_id, to_id])

		# ---- 骰子数值类 ----
		EffectTypes.EffectType.MODIFY_POINTS:
			result.points_delta += params.get("delta", 0)
			result.descriptions.append("点数 %+d" % params.get("delta", 0))

		EffectTypes.EffectType.COPY_VALUE:
			result.descriptions.append("复制点数: %s" % params.get("source", ""))

		EffectTypes.EffectType.REVERSE_VALUE:
			result.reverse_value = true
			result.descriptions.append("翻转点数")

		EffectTypes.EffectType.OVERRIDE_VALUE:
			result.override_value = params.get("value", 0)
			result.descriptions.append("覆写点数 → %d" % result.override_value)

		EffectTypes.EffectType.BONUS_ON_KEEP:
			var keep_val: int = params.get("value", 0) * ctx.kept_turns
			var cap: int = params.get("cap", 99)
			keep_val = mini(keep_val, cap)
			result.bonus_damage += keep_val
			result.descriptions.append("保留加成 +%d" % keep_val)

		EffectTypes.EffectType.UNIFY_ELEMENT:
			result.unify_element = true
			result.descriptions.append("统一元素")

		EffectTypes.EffectType.LOCK_ELEMENT:
			result.descriptions.append("锁定元素 %d回合" % params.get("duration", 0))

		# ---- 经济类 ----
		EffectTypes.EffectType.GAIN_GOLD:
			result.gold_gain += params.get("value", 0)
			result.descriptions.append("+%d 金币" % params.get("value", 0))

		EffectTypes.EffectType.DAMAGE_TO_GOLD:
			result.descriptions.append("伤害转金币 %.0f%%" % (params.get("ratio", 0.0) * 100))

		EffectTypes.EffectType.SHOP_DISCOUNT:
			result.descriptions.append("商店折扣 %.0f%%" % (params.get("percent", 0.0) * 100))

		EffectTypes.EffectType.STEAL_GOLD:
			result.steal_gold = params.get("value", 0)
			result.descriptions.append("偷取 %d 金币" % result.steal_gold)

		# ---- 职业机制类 ----
		EffectTypes.EffectType.SCAR_CONSUME:
			result.scar_consume_ratio = params.get("ratio", 0.0)
			result.scar_bonus_per_stack = params.get("bonus_per_stack", 0.0)
			result.descriptions.append("消耗伤痕 %.0f%%" % (result.scar_consume_ratio * 100))

		EffectTypes.EffectType.SCAR_BONUS:
			result.scar_bonus_per_stack = params.get("per_stack", 0.0)
			var scar_dmg: int = int(ctx.player_scar_stacks * result.scar_bonus_per_stack)
			result.bonus_damage += scar_dmg
			result.descriptions.append("伤痕加成 +%d" % scar_dmg)

		EffectTypes.EffectType.CHARGE:
			result.charge_turns = params.get("turns", 0)
			result.descriptions.append("蓄力 %d回合" % result.charge_turns)

		EffectTypes.EffectType.CHAIN_BOLT:
			result.descriptions.append("连锁闪电 弹射%d次" % params.get("bounce", 0))

		EffectTypes.EffectType.BURN_ECHO:
			result.descriptions.append("灼烧回响")

		EffectTypes.EffectType.ELEMENT_TRIGGER:
			result.descriptions.append("元素触发")

		EffectTypes.EffectType.BARRIER_TO_DAMAGE:
			result.descriptions.append("屏障转伤 %.0f%%" % (params.get("ratio", 0.0) * 100))

		EffectTypes.EffectType.POISON_FROM_VALUE:
			var poison_val: int = ctx.dice_points_total + params.get("bonus", 0)
			result.apply_statuses.append({
				"status": "poison",
				"value": poison_val,
				"target": "enemy",
			})
			result.descriptions.append("施毒 %d" % poison_val)

		EffectTypes.EffectType.POISON_FROM_DICE_COUNT:
			var per: int = params.get("per_dice", 0)
			var poison_val: int = ctx.dice_count * per
			result.apply_statuses.append({
				"status": "poison",
				"value": poison_val,
				"target": "enemy",
			})
			result.descriptions.append("毒骰施毒 %d" % poison_val)

		EffectTypes.EffectType.AMPLIFY_SELF:
			var mult: float = params.get("mult", 1.0)
			var amplified: int = ceili(float(ctx.dice_points_total) * mult)
			result.bonus_damage += amplified
			result.descriptions.append("放大 ×%.1f = +%d" % [mult, amplified])

		EffectTypes.EffectType.STEAL_ARMOR:
			# ratio 表示偷取目标护甲的百分比，value 表示固定值
			var steal_ratio: float = params.get("ratio", 0.0)
			var steal_flat: int = params.get("value", 0)
			if steal_ratio > 0.0:
				# 百分比偷取：由 Applier/Resolver 根据目标护甲计算实际值
				result.steal_armor = maxi(1, steal_flat)  # 暂存 ratio 信息到 descriptions
			else:
				result.steal_armor = steal_flat
			result.descriptions.append("偷取护甲 %d" % result.steal_armor)

		EffectTypes.EffectType.DOUBLE_STATUS_ON_COMBO:
			result.descriptions.append("连击双倍 %s" % params.get("status", ""))

		EffectTypes.EffectType.DEVOUR_DIE:
			result.devour_die = true
			result.bonus_damage += ctx.dice_points_total
			result.descriptions.append("吞噬 +%d" % ctx.dice_points_total)

		EffectTypes.EffectType.SWAP_WITH_UNSELECTED:
			result.swap_with_unselected = true
			result.descriptions.append("交换未选骰")

		EffectTypes.EffectType.DAMAGE_SHIELD:
			result.damage_shield_value = params.get("value", 0)
			result.damage_shield_duration = params.get("duration", 1)
			result.descriptions.append("伤害护盾 %d（%d回合）" % [result.damage_shield_value, result.damage_shield_duration])

		EffectTypes.EffectType.BONUS_MULT_ON_KEEP:
			result.bonus_mult += params.get("value", 0.0) * ctx.kept_turns
			result.descriptions.append("保留倍率 +%.1f" % (params.get("value", 0.0) * ctx.kept_turns))

		EffectTypes.EffectType.REDUCE_ARCANE_DISRUPTION:
			result.reduce_disruption += params.get("value", 0)
			result.descriptions.append("降低法脉紊乱 %d层" % params.get("value", 0))

		EffectTypes.EffectType.CONSUME_DISRUPTION_AOE:
			result.consume_disruption_aoe_per_stack = params.get("damage_per_stack", 0)
			result.descriptions.append("消耗法脉紊乱转AOE伤害")

		# ---- 规则改变类（由 Applier 在战斗开始/回合开始时应用） ----
		EffectTypes.EffectType.MODIFY_DRAW_COUNT:
			result.draw_count_delta += params.get("delta", 0)
			result.descriptions.append("抽牌数 %+d" % params.get("delta", 0))
		EffectTypes.EffectType.MODIFY_HAND_LIMIT:
			result.hand_limit_delta += params.get("delta", 0)
			result.descriptions.append("手牌上限 %+d" % params.get("delta", 0))
		EffectTypes.EffectType.MODIFY_PLAY_COUNT:
			result.extra_plays += params.get("delta", 0)
			result.descriptions.append("出牌次数 %+d" % params.get("delta", 0))
		EffectTypes.EffectType.MODIFY_REROLL_COUNT:
			result.extra_rerolls += params.get("delta", 0)
			result.descriptions.append("重投次数 %+d" % params.get("delta", 0))
		EffectTypes.EffectType.ALL_DICE_POINTS_PLUS:
			result.all_dice_points_plus += params.get("value", 0)
			result.descriptions.append("全骰 +%d" % params.get("value", 0))
		EffectTypes.EffectType.DEATH_IMMUNITY:
			result.death_immunity_cooldown = params.get("cooldown_turns", 0)
			result.descriptions.append("免死（冷却%d回合）" % result.death_immunity_cooldown)
		EffectTypes.EffectType.DAMAGE_MULT_GLOBAL:
			result.bonus_mult += params.get("value", 0.0)
			result.descriptions.append("全局伤害 +%.0f%%" % (params.get("value", 0.0) * 100))
		EffectTypes.EffectType.ARMOR_PER_TURN:
			result.armor += params.get("value", 0)
			result.descriptions.append("每回合护甲 +%d" % params.get("value", 0))

		_:
			result.descriptions.append("[未实现效果: %d]" % type)

	return result


# ============================================================
# 内部计算辅助
# ============================================================

## 计算比例追加伤害
static func _calc_scaled_damage(params: Dictionary, ctx: ExecuteContext) -> int:
	var source: String = params.get("source", "")
	var ratio: float = params.get("ratio", 0.0)
	var cap: int = params.get("cap", 9999)
	var base_value: int = 0

	match source:
		"points":
			base_value = ctx.dice_points_total
		"lost_hp":
			base_value = ctx.player_max_hp - ctx.player_hp
		"scar":
			base_value = ctx.player_scar_stacks
		"poison":
			if ctx.target_enemy:
				base_value = ctx.target_enemy.get_status_stacks("poison")
		"armor":
			base_value = ctx.player_armor
		"combo":
			base_value = ctx.player_combo
		"hand_size":
			base_value = ctx.hand_size
		_:
			base_value = 0

	var result: int = int(float(base_value) * ratio)
	return mini(result, cap)


## 计算护甲值
static func _calc_armor(params: Dictionary, ctx: ExecuteContext) -> int:
	var value: int = params.get("value", 0)
	var source: String = params.get("source", "")
	var ratio: float = params.get("ratio", 1.0)

	match source:
		"points":
			value = int(float(ctx.dice_points_total) * ratio)
		"hand_size":
			value = int(float(ctx.hand_size) * ratio)
		"fixed", "":
			pass  # 直接用 value

	# 伤痕加成
	var scar_bonus: Dictionary = params.get("scar_bonus", {})
	if not scar_bonus.is_empty():
		var threshold: int = scar_bonus.get("threshold", 0)
		var bonus_ratio: float = scar_bonus.get("ratio", 0.0)
		if ctx.player_scar_stacks >= threshold:
			value = int(float(value) * (1.0 + bonus_ratio))

	return value
