## 抽牌阶段纯函数结算引擎
## 对应原版 logic/drawPhase.ts
## 职责：三职业弃牌/留牌、命运之轮、保留最高点遗物、抽牌数公式、7种onKeep效果
## 设计原则：
##   - 纯函数：不修改任何 autoload 状态，返回结算结果供 TurnManager wrapper 写回
##   - SRP：每个职业弃牌逻辑独立函数
## [RULES-C1-EXEMPT] resolve() 接收参数返回 DrawPhaseResult，不直接修改全局状态。
##   写回 PlayerState 由 TurnManager.execute_draw_phase() 统一执行。
##   - DRY：onKeep 效果统一走 resolve_kept_dice
class_name DrawPhaseResolver
extends RefCounted


# ============================================================
# 公开数据结构
# ============================================================

## 抽牌阶段结算结果
class DrawPhaseResult:
	## 保留的骰子（含 onKeep 效果已应用）
	var kept_dice: Array[Dictionary] = []
	## 需要放入弃骰库的骰子 defId 列表
	var discard_ids: Array[String] = []
	## 实际需要从骰子库抽取的数量
	var need_draw: int = 0
	## 战士狂暴倍率（溢出补偿）
	var warrior_rage_mult: float = 0.0
	## 飘字请求列表 [{text, color, target}]
	var floating_texts: Array[Dictionary] = []
	## Toast 请求列表 [{msg, type}]
	var toasts: Array[Dictionary] = []
	## 法师 overcharge 倍率增量（从 bonusMultOnKeep 累加）
	var mage_overcharge_mult_delta: float = 0.0
	## 命运之轮是否已消耗
	var fortune_wheel_consumed: bool = false
	## 保留最高点遗物是否已消耗
	var relic_keep_highest_consumed: bool = false


# ============================================================
# 主入口
# ============================================================

## 执行抽牌阶段全部结算（纯函数）
## 参数说明：
##   hand_dice: 当前手牌 DiceBag.hand_dice
##   player_class: 玩家职业
##   played_this_turn: 本回合是否出过牌（plays_left < max_plays）
##   charge_stacks: 法师蓄力层数
##   draw_count: 基础抽牌数
##   hp / max_hp: 玩家HP
##   relics: 玩家遗物列表
##   fortune_wheel_used: 命运之轮本战是否已用
##   relic_keep_highest: 保留最高点骰子数量
##   temp_draw_count_bonus / rogue_combo_draw_bonus / relic_temp_draw_bonus: 临时抽牌加成
##   warrior_rage_mult_current: 当前战士狂暴倍率
static func resolve(
	hand_dice: Array[Dictionary],
	player_class: String,
	played_this_turn: bool,
	charge_stacks: int,
	draw_count: int,
	hp: int,
	max_hp: int,
	relics: Array[Dictionary],
	fortune_wheel_used: bool,
	relic_keep_highest: int,
	temp_draw_count_bonus: int,
	rogue_combo_draw_bonus: int,
	relic_temp_draw_bonus: int,
	warrior_rage_mult_current: float
) -> DrawPhaseResult:
	var result := DrawPhaseResult.new()
	result.warrior_rage_mult = warrior_rage_mult_current

	# === §5.1 三职业弃牌决策 ===
	_resolve_class_discard(hand_dice, player_class, played_this_turn, charge_stacks, draw_count, relics, fortune_wheel_used, result)

	# === §5.1 遗物：保留最高点骰子（在弃牌后追加保留）===
	_resolve_relic_keep_highest(hand_dice, relic_keep_highest, result)

	# === §5.3 保留骰子 onKeep 效果 ===
	_resolve_kept_dice(result)

	# === §5.2 抽牌数公式 ===
	_resolve_draw_count(player_class, charge_stacks, draw_count, hp, max_hp, result.kept_dice.size(), temp_draw_count_bonus, rogue_combo_draw_bonus, relic_temp_draw_bonus, result)

	return result


# ============================================================
# §5.1 辅助：将未消耗骰子加入弃牌列表（DRY 提取）
# ============================================================

## 将 hand_dice 中所有骰子 defId 加入 result.discard_ids。
## 骰子出牌即入弃骰库，此函数只处理"回合末手牌残留的骰子"。
static func _discard_all_to_bag(hand_dice: Array[Dictionary], result: DrawPhaseResult) -> void:
	for d: Dictionary in hand_dice:
		result.discard_ids.append(d.defId)


# ============================================================
# §5.1 三职业弃牌决策
# ============================================================

static func _resolve_class_discard(
	hand_dice: Array[Dictionary],
	player_class: String,
	played_this_turn: bool,
	charge_stacks: int,
	draw_count: int,
	relics: Array[Dictionary],
	fortune_wheel_used: bool,
	result: DrawPhaseResult
) -> void:
	match player_class:
		"mage":
			_resolve_mage_discard(hand_dice, played_this_turn, charge_stacks, draw_count, result)
		"rogue":
			_resolve_rogue_discard(hand_dice, result)
		_:
			_resolve_warrior_discard(hand_dice, played_this_turn, relics, fortune_wheel_used, result)


## 法师弃牌：出过牌→全弃；未出牌(吟唱)→保留手牌(按handLimit裁剪)
static func _resolve_mage_discard(
	hand_dice: Array[Dictionary],
	played_this_turn: bool,
	charge_stacks: int,
	draw_count: int,
	result: DrawPhaseResult
) -> void:
	if played_this_turn:
		# 出过牌 → 弃掉所有手牌（含 spent，确保骰子回收到弃骰库）
		_discard_all_to_bag(hand_dice, result)
	else:
		# 吟唱 → 保留手牌，按吟唱层上限裁剪
		var hand_limit := mini(6, draw_count + charge_stacks)
		# 收集所有骰子，按 value 降序排列（高价值优先保留）
		var all_dice: Array[Dictionary] = []
		for d: Dictionary in hand_dice:
			all_dice.append(d)
		# 注：出牌过的骰子已在 mark_spent_and_after_play 中移除，此处全为未出牌骰子
		all_dice.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return a.value > b.value
		)
		if all_dice.size() > hand_limit:
			var excess: Array[Dictionary] = []
			excess.assign(all_dice.slice(hand_limit))
			for d: Dictionary in excess:
				result.discard_ids.append(d.defId)
			var trimmed: Array[Dictionary] = []
			trimmed.assign(all_dice.slice(0, hand_limit))
			# 全部保留到下回合手牌
			result.kept_dice = []
			for d: Dictionary in trimmed:
				result.kept_dice.append(d)
		else:
			result.kept_dice = []
			for d: Dictionary in all_dice:
				result.kept_dice.append(d)


## 盗贼弃牌：持久暗影残骰保留→清persistent→变isTemp；临时残骰销毁；正式骰放回弃骰库
static func _resolve_rogue_discard(
	hand_dice: Array[Dictionary],
	result: DrawPhaseResult
) -> void:
	for d: Dictionary in hand_dice:
		var is_shadow: bool = d.get("isShadowRemnant", false)
		var is_persistent: bool = d.get("shadowRemnantPersistent", false)
		if is_shadow and is_persistent:
			# 持久暗影残骰：保留但清除 persistent 标记，下回合变临时
			# 注：出牌过的暗影残骰已在 mark_spent_and_after_play 中移除，此处遍历到的都是未出牌的
			var kept := d.duplicate()
			kept["shadowRemnantPersistent"] = false
			kept["isTemp"] = true
			result.kept_dice.append(kept)
		elif not is_shadow and not d.get("isTemp", false) and d.defId != "temp_rogue":
			# 正式骰子：放回弃骰库（含 spent 骰子）
			result.discard_ids.append(d.defId)


## 战士/其他弃牌：全弃；命运之轮首次出牌后保留手牌1次/战
static func _resolve_warrior_discard(
	hand_dice: Array[Dictionary],
	played_this_turn: bool,
	relics: Array[Dictionary],
	fortune_wheel_used: bool,
	result: DrawPhaseResult
) -> void:
	var has_keep_once: bool = RelicEngine.has_relic(relics, "fortune_wheel_relic") and not fortune_wheel_used
	if has_keep_once and played_this_turn:
		# 命运之轮：首次出牌后保留手牌1次
		# 注：出牌过的骰子已在 mark_spent_and_after_play 中移除并入 discard_pile，
		# 此处 hand_dice 里只有未出牌的骰子，全部保留
		for d: Dictionary in hand_dice:
			result.kept_dice.append(d.duplicate())
		result.fortune_wheel_consumed = true
		result.floating_texts.append({"text": "命运之轮: 保留手牌!", "color": Color.YELLOW, "target": "player"})
	else:
		# 战士默认全弃（含 spent，确保骰子回收到弃骰库）
		_discard_all_to_bag(hand_dice, result)


# ============================================================
# §5.1 遗物：保留最高点骰子
# ============================================================

static func _resolve_relic_keep_highest(
	hand_dice: Array[Dictionary],
	keep_highest: int,
	result: DrawPhaseResult
) -> void:
	if keep_highest <= 0 or result.discard_ids.is_empty():
		return

	# 从所有骰子（含 spent）中按点数降序排列，从 discard_ids 中捞出保留
	var all_dice: Array[Dictionary] = []
	for d: Dictionary in hand_dice:
		all_dice.append(d)
	all_dice.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.value > b.value)

	var to_keep: Array[Dictionary] = []
	to_keep.assign(all_dice.slice(0, mini(keep_highest, all_dice.size())))
	# 按索引倒序移除，避免索引偏移（先收集要移除的索引）
	var remove_indices: Array[int] = []
	for d: Dictionary in to_keep:
		# 在 discard_ids 中找对应 defId 的索引（从后往前找避免重复冲突）
		var found_idx: int = -1
		for di: int in range(result.discard_ids.size() - 1, -1, -1):
			if result.discard_ids[di] == d.defId and not (di in remove_indices):
				found_idx = di
				break
		if found_idx >= 0:
			remove_indices.append(found_idx)
			var kept_d: Dictionary = d.duplicate()
			result.kept_dice.append(kept_d)
	# 倒序移除（索引大的先删，不影响小索引）
	remove_indices.sort()
	remove_indices.reverse()
	for idx: int in remove_indices:
		result.discard_ids.remove_at(idx)

	if to_keep.size() > 0:
		var values: Array[int] = []
		for d: Dictionary in to_keep:
			values.append(d.value)
		result.floating_texts.append({"text": "保留%s点骰子" % ",".join(values), "color": Color.CYAN, "target": "player"})
		result.relic_keep_highest_consumed = true


# ============================================================
# §5.3 保留骰子 onKeep 效果（7 种）
# ============================================================

static func _resolve_kept_dice(result: DrawPhaseResult) -> void:
	var mult_bonus_total: float = 0.0

	for i: int in result.kept_dice.size():
		var d: Dictionary = result.kept_dice[i]
		var def: DiceDef = GameData.get_dice_def(d.get("defId", ""))
		if def == null:
			continue

		# 1. bonusOnKeep（水晶骰）：保留到下回合时点数+N
		if def.bonus_on_keep > 0:
			var old_val: int = d.get("value", 1)
			var new_val: int = mini(6, old_val + def.bonus_on_keep)
			d["value"] = new_val
			result.floating_texts.append({"text": "%s+%d点" % [def.name, def.bonus_on_keep], "color": Color.CYAN, "target": "player"})

		# 2. boostLowestOnKeep（时光沙）：保留时手牌中最低点骰子+N
		if def.boost_lowest_on_keep > 0:
			var min_val: int = 99
			for kd: Dictionary in result.kept_dice:
				if kd.get("value", 1) < min_val:
					min_val = kd.get("value", 1)
			for kd: Dictionary in result.kept_dice:
				if kd.get("value", 1) == min_val:
					kd["value"] = mini(6, kd.get("value", 1) + def.boost_lowest_on_keep)
			result.floating_texts.append({"text": "%s: 最低点+%d" % [def.name, def.boost_lowest_on_keep], "color": Color.CYAN, "target": "player"})

		# 3. bonusPerTurnKept（星辰骰）：每保留1回合+N，累积有上限
		if def.bonus_per_turn_kept > 0:
			var cap: int = def.keep_bonus_cap
			var accumulated: int = d.get("keptBonusAccum", 0)
			if accumulated < cap:
				var bonus: int = mini(def.bonus_per_turn_kept, cap - accumulated)
				d["value"] = mini(6, d.get("value", 1) + bonus)
				d["keptBonusAccum"] = accumulated + bonus
				result.floating_texts.append({"text": "%s+%d点(%d/%d)" % [def.name, bonus, accumulated + bonus, cap], "color": Color.MEDIUM_PURPLE, "target": "player"})

		# 4. rerollOnKeep（时光骰）：保留到下回合时自动重投
		if def.reroll_on_keep:
			d["value"] = DiceBagService.roll_dice_def(def)
			result.floating_texts.append({"text": "%s自动重投" % def.name, "color": Color.DODGER_BLUE, "target": "player"})

		# 5. bonusMultOnKeep（法力涌动）：保留时给下次出牌额外倍率
		if def.bonus_mult_on_keep > 0.0:
			mult_bonus_total += def.bonus_mult_on_keep

		# 清理：确保保留骰子 selected=false, kept=true
		d["selected"] = false
		d["kept"] = true

	# 汇总 bonusMultOnKeep
	if mult_bonus_total > 0.0:
		result.mage_overcharge_mult_delta = mult_bonus_total
		result.floating_texts.append({"text": "蓄力倍率+%d%%" % int(mult_bonus_total * 100), "color": Color.MEDIUM_PURPLE, "target": "player"})


# ============================================================
# §5.2 抽牌数公式
# ============================================================

static func _resolve_draw_count(
	player_class: String,
	charge_stacks: int,
	draw_count: int,
	hp: int,
	max_hp: int,
	kept_count: int,
	temp_draw_count_bonus: int,
	rogue_combo_draw_bonus: int,
	relic_temp_draw_bonus: int,
	result: DrawPhaseResult
) -> void:
	# 法师吟唱加成
	var charge_bonus: int = 1 if player_class == "mage" else 0
	if player_class == "mage":
		charge_bonus = charge_stacks

	# 战士血怒补牌
	var warrior_bonus: int = 0
	if player_class == "warrior" and hp <= max_hp * 0.5:
		warrior_bonus = 1
		result.floating_texts.append({"text": "血怒补牌+1", "color": Color.RED, "target": "player"})

	var raw_target_hand_size: int = draw_count + charge_bonus + warrior_bonus
	var target_hand_size: int = mini(6, raw_target_hand_size)

	# 战士狂暴倍率（手牌上限溢出补偿）
	if player_class == "warrior" and raw_target_hand_size > 6:
		var hp_lost_pct: float = maxf(0.0, 1.0 - float(hp) / float(max_hp))
		var rage_mult: float = round(hp_lost_pct * 100.0) / 100.0
		result.warrior_rage_mult = rage_mult
		if rage_mult > 0.0:
			result.floating_texts.append({"text": "狂暴+%d%%" % int(rage_mult * 100), "color": Color.RED, "target": "player"})
	elif player_class == "warrior":
		result.warrior_rage_mult = 0.0

	# 盗贼连击心得额外抽牌
	if player_class == "rogue" and rogue_combo_draw_bonus > 0:
		result.floating_texts.append({"text": "连击心得+%d手牌" % rogue_combo_draw_bonus, "color": Color.GREEN, "target": "player"})

	# 魔法手套遗物临时手牌加成
	if relic_temp_draw_bonus > 0:
		result.floating_texts.append({"text": "魔法手套+%d手牌" % relic_temp_draw_bonus, "color": Color.CYAN, "target": "player"})

	# 薛定谔袋子加成（tempDrawCountBonus，原版 schrodingerBonus）
	if temp_draw_count_bonus > 0:
		result.floating_texts.append({"text": "临时+%d手牌" % temp_draw_count_bonus, "color": Color.MEDIUM_SEA_GREEN, "target": "player"})

	# needDraw = max(0, targetHandSize + 3个临时加成 - 保留数)
	result.need_draw = maxi(0, target_hand_size + temp_draw_count_bonus + rogue_combo_draw_bonus + relic_temp_draw_bonus - kept_count)
