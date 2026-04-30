## 重投处理器
## 从 battle_controller.gd 拆出（B1 行数限制）
## 职责：重投代价计算 + 血怒叠加 + 遗物触发 + 弃骰+抽新
## 对应原版 useReroll.tsx
class_name RerollHandler
extends RefCounted


# ============================================================
# 重投代价计算
# ============================================================

## 计算重投HP代价
## 返回: 0=免费, 正数=HP代价, -1=不可重投
static func get_reroll_hp_cost(reroll_count: int) -> int:
	# 使用 GameManager.free_rerolls_left 判断免费次数（含盗贼连击预备等增量）
	if GameManager.free_rerolls_left > 0:
		return 0
	# 付费重投：非战士 / 无血骰袋则拒绝
	var has_blood_relic: bool = RelicEngine.has_relic(PlayerState.relics, "blood_dice_bag")
	if PlayerState.player_class != "warrior" and not has_blood_relic:
		return -1
	var free_count: int = GameManager.free_rerolls_per_turn + RelicEngine.get_extra_free_rerolls(PlayerState.relics)
	var paid_index: int = maxi(0, reroll_count - free_count)
	var base_cost: int = ceili(PlayerState.max_hp * pow(2.0, paid_index + 1) / 100.0)
	return base_cost * 2 if PlayerState.player_class != "warrior" else base_cost


# ============================================================
# 执行重投
# ============================================================

## 执行重投（替代 battle_controller._on_reroll_pressed 的业务逻辑）
## 参数：
##   selected_indices: 选中的骰子索引列表
##   reroll_count: 当前已重投次数
##   on_reroll_done: 重投完成回调（参数：新的 reroll_count）
## 返回：true=成功执行, false=条件不满足
static func execute(
	selected_indices: Array[int],
	reroll_count: int,
	on_reroll_done: Callable
) -> bool:
	if selected_indices.is_empty() or GameManager.is_enemy_turn:
		return false
	if GameManager.plays_left <= 0:
		return false

	var hp_cost: int = get_reroll_hp_cost(reroll_count)
	if hp_cost == -1:
		VFX.show_toast("无法重投", "damage")
		return false

	# 诅咒骰子代价翻倍
	var has_cursed: bool = false
	for idx: int in selected_indices:
		if idx < DiceBag.hand_dice.size():
			var def: DiceDef = GameData.get_dice_def(DiceBag.hand_dice[idx].get("defId", ""))
			if def and def.is_cursed:
				has_cursed = true
				break
	if has_cursed:
		hp_cost *= 2

	# §7.1 生命不足检查：原版 `hpCost > hp` 拒绝（正好打光允许）
	if hp_cost > 0 and hp_cost > PlayerState.hp:
		VFX.show_toast("生命不足！重投需要 %d HP" % hp_cost, "damage")
		return false

	var is_blood_reroll: bool = hp_cost > 0

	# === §7.2 on_reroll 遗物触发 ===
	# is_blood_reroll 作为遗物上下文，区分免费 / 卖血
	# 黑市契约：本回合首次卖血后 PlayerState.black_market_used_this_turn = true，禁止二次触发
	var on_reroll_gold: int = 0
	var on_reroll_armor: int = 0
	for r: Dictionary in PlayerState.relics:
		var r_def: RelicDef = GameData.get_relic_def(r.get("id", ""))
		if r_def and r_def.trigger == GameTypes.RelicTrigger.ON_REROLL:
			# 黑市契约仅在卖血且本回合未触发时生效
			if r_def.id == "black_market_contract":
				if is_blood_reroll and not PlayerState.black_market_used_this_turn:
					on_reroll_gold += r_def.gold_bonus
					PlayerState.black_market_used_this_turn = true
				continue
			# 血铸铠甲仅在卖血时触发
			if r_def.id == "blood_forged_armor":
				if is_blood_reroll:
					on_reroll_armor += r_def.armor
				continue
			# 通用 on_reroll 遗物（免费 / 卖血都触发）
			if r_def.gold_bonus > 0:
				on_reroll_gold += r_def.gold_bonus
			if r_def.armor > 0:
				on_reroll_armor += r_def.armor

	# === 血怒叠加 ===
	if is_blood_reroll:
		var current_fury: int = PlayerState.blood_reroll_count
		var at_cap: bool = current_fury >= GameBalance.FURY_CONFIG.maxStack
		var cap_armor: int = GameBalance.FURY_CONFIG.armorAtCap if at_cap else 0

		PlayerState.take_damage(hp_cost)
		PlayerState.blood_reroll_count = mini(current_fury + 1, GameBalance.FURY_CONFIG.maxStack)
		if on_reroll_armor + cap_armor > 0:
			PlayerState.gain_armor(on_reroll_armor + cap_armor)
		if on_reroll_gold > 0:
			PlayerState.add_gold(on_reroll_gold)

		if at_cap:
			VFX.show_toast("血怒已满→+%d护甲" % GameBalance.FURY_CONFIG.armorAtCap, "buff")
		else:
			var display_stacks: int = mini(current_fury + 1, GameBalance.FURY_CONFIG.maxStack)
			VFX.show_toast("血怒+%d%%伤害（%d/%d层）" % [
				display_stacks * int(GameBalance.FURY_CONFIG.damagePerStack * 100),
				display_stacks, GameBalance.FURY_CONFIG.maxStack
			], "buff")
		BattleLog.log_player("嗜血重投 -%d HP（血怒%d/%d）" % [
			hp_cost, mini(current_fury + 1, GameBalance.FURY_CONFIG.maxStack), GameBalance.FURY_CONFIG.maxStack
		])
	else:
		# 免费重投：仍然触发遗物
		if on_reroll_armor > 0:
			PlayerState.gain_armor(on_reroll_armor)
		if on_reroll_gold > 0:
			PlayerState.add_gold(on_reroll_gold)
		BattleLog.log_player("免费重投 x%d" % selected_indices.size())

	SoundPlayer.play_sound("reroll")

	# === 弃骰 + 从骰子库抽新 ===
	var reroll_def_ids: Array[String] = []
	var temp_reroll_ids: Array[int] = []
	for idx: int in selected_indices:
		if idx < DiceBag.hand_dice.size():
			var d: Dictionary = DiceBag.hand_dice[idx]
			if d.get("isTemp", false) and d.get("defId", "") != "temp_rogue":
				temp_reroll_ids.append(idx)
			else:
				reroll_def_ids.append(d.get("defId", ""))

	# 非临时骰子放入弃骰库
	DiceBag.discard_hand_dice(reroll_def_ids)

	# 从骰子库抽新骰子替换
	var draw_result: Dictionary = DiceBag.draw_from_bag(reroll_def_ids.size())
	var drawn_dice: Array[Dictionary] = draw_result.get("drawn", [])

	# 替换手牌中的重投骰子
	var draw_idx: int = 0
	for idx: int in selected_indices:
		if idx < DiceBag.hand_dice.size():
			if idx in temp_reroll_ids:
				var new_val: int = DiceBagService.reroll_die(DiceBag.hand_dice[idx])
				DiceBag.hand_dice[idx]["value"] = new_val
				DiceBag.hand_dice[idx]["selected"] = false
				DiceBag.hand_dice[idx]["rolling"] = false
			elif draw_idx < drawn_dice.size():
				var new_die: Dictionary = drawn_dice[draw_idx]
				new_die["id"] = DiceBag.hand_dice[idx].get("id", randi())
				new_die["selected"] = false
				new_die["rolling"] = false
				DiceBag.hand_dice[idx] = new_die
				draw_idx += 1

	var new_reroll_count: int = reroll_count + 1
	# 不能用"重算"公式覆盖 free_rerolls_left！
	# 盗贼连击预备等机制可能已经往 free_rerolls_left 加过值（play_handler_bridge.gd），
	# 重算 = 抹掉这些增量。正确做法：消费一个免费次数。
	if GameManager.free_rerolls_left > 0:
		GameManager.free_rerolls_left -= 1

	# §7.5 rerollsThisWave（StatsTracker 统计 / 成就挂钩）
	StatsTracker.record_reroll()

	on_reroll_done.call(new_reroll_count)
	return true
