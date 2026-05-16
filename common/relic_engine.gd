## 遗物效果引擎（v2 — 数据驱动）
## 职责：在正确的触发时机收集遗物效果，调用 EffectEngine 执行
## 不再直接读取 RelicDef 的字段，而是通过 effects 数组 + EffectEngine 统一处理

class_name RelicEngine


# ============================================================
# 触发入口（按时机分类）
# ============================================================

## 战斗开始触发
static func on_battle_start(relics: Array[Dictionary], game: Node) -> void:
	_trigger_relics(relics, EffectTypes.TriggerType.ON_BATTLE_START, game)


## 回合开始触发
static func on_turn_start(relics: Array[Dictionary], game: Node) -> void:
	_trigger_relics(relics, EffectTypes.TriggerType.ON_TURN_START, game)


## 出牌时触发（返回 ExecuteResult 供伤害计算合并）
static func on_play(relics: Array[Dictionary], game: Node, dice: Array[Dictionary] = [], hand_type: String = "") -> EffectEngine.ExecuteResult:
	var ctx := _build_context(game)
	ctx.hand_type = hand_type
	ctx.dice_count = dice.size()
	var total_points: int = 0
	for d: Dictionary in dice:
		total_points += d.get("value", 0)
	ctx.dice_points_total = total_points
	ctx.source = EffectTypes.EffectSource.RELIC

	var final_result := EffectEngine.ExecuteResult.new()
	for r: Dictionary in relics:
		var def: RelicDef = GameData.get_relic_def(r.get("id", ""))
		if not def:
			continue
		# 冷却检查
		if not _check_cooldown(def, r):
			continue
		# 计数器检查
		if not _check_counter(def, r):
			continue
		ctx.source_id = def.id
		var effects := EffectTriggerFilter.get_executable_effects(
			def.effects, EffectTypes.TriggerType.ON_PLAY, ctx)
		if effects.is_empty():
			continue
		var result := EffectEngine.execute(effects, ctx)
		final_result.merge(result)
	return final_result


## 击杀时触发
static func on_kill(relics: Array[Dictionary], game: Node, _overkill: int) -> void:
	var ctx := _build_context(game)
	ctx.kills_this_play = 1
	ctx.source = EffectTypes.EffectSource.RELIC
	_trigger_relics_with_ctx(relics, EffectTypes.TriggerType.ON_KILL, ctx, game)


## 受伤时触发
static func on_damage_taken(relics: Array[Dictionary], game: Node, _damage: int) -> void:
	var ctx := _build_context(game)
	ctx.was_hit_last_turn = true
	ctx.source = EffectTypes.EffectSource.RELIC
	_trigger_relics_with_ctx(relics, EffectTypes.TriggerType.ON_DAMAGE_TAKEN, ctx, game)


## 回合结束触发
static func on_turn_end(relics: Array[Dictionary], game: Node) -> void:
	_trigger_relics(relics, EffectTypes.TriggerType.ON_TURN_END, game)


## 楼层通过触发
static func on_floor_clear(relics: Array[Dictionary], game: Node) -> void:
	_trigger_relics(relics, EffectTypes.TriggerType.ON_FLOOR_CLEAR, game)


# ============================================================
# 查询接口（兼容旧代码）
# ============================================================

## 检查是否拥有指定ID的遗物
static func has_relic(relics: Array[Dictionary], relic_id: String) -> bool:
	return relics.any(func(r: Dictionary) -> bool: return r.get("id", "") == relic_id)


## 查询遗物层数
static func get_relic_level(relics: Array[Dictionary], relic_id: String) -> int:
	for r: Dictionary in relics:
		if r.get("id", "") == relic_id:
			return r.get("level", 1)
	return 0


## 检查是否有致命保护（时光沙漏）
static func has_fatal_protection(relics: Array[Dictionary]) -> bool:
	return has_relic(relics, "hourglass")


## 触发时光沙漏（消耗遗物）
static func trigger_hourglass(relics: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for r: Dictionary in relics:
		if r.get("id", "") != "hourglass":
			result.append(r)
	return result


## 收集所有被动规则改变效果（战斗开始时一次性应用）
## 返回合并后的 ExecuteResult，调用方从中读取 extra_plays/extra_rerolls/extra_draws 等
static func collect_passive_rules(relics: Array[Dictionary]) -> EffectEngine.ExecuteResult:
	var ctx := EffectEngine.ExecuteContext.new()
	ctx.player_hp = PlayerState.hp
	ctx.player_max_hp = PlayerState.max_hp
	ctx.source = EffectTypes.EffectSource.RELIC

	var final_result := EffectEngine.ExecuteResult.new()
	for r: Dictionary in relics:
		var def: RelicDef = GameData.get_relic_def(r.get("id", ""))
		if not def:
			continue
		ctx.source_id = def.id
		# PASSIVE 触发的效果在战斗开始时一次性收集
		var effects := EffectTriggerFilter.filter_by_trigger(
			def.effects, EffectTypes.TriggerType.ON_BATTLE_START)
		if effects.is_empty():
			continue
		var result := EffectEngine.execute(effects, ctx)
		final_result.merge(result)
	return final_result


## 获取遗物提供的额外穿甲（兼容旧接口）
static func get_on_play_pierce(relics: Array[Dictionary]) -> int:
	var total: int = 0
	for r: Dictionary in relics:
		var def: RelicDef = GameData.get_relic_def(r.get("id", ""))
		if not def:
			continue
		for effect: Dictionary in def.effects:
			if effect.get("trigger", -1) == EffectTypes.TriggerType.ON_PLAY:
				if effect.get("type", -1) == EffectTypes.EffectType.PIERCE:
					total += effect.get("params", {}).get("value", 0)
	return total


## 获取遗物提供的额外免费重投
static func get_extra_free_rerolls(relics: Array[Dictionary]) -> int:
	var total: int = 0
	for r: Dictionary in relics:
		var def: RelicDef = GameData.get_relic_def(r.get("id", ""))
		if not def:
			continue
		for effect: Dictionary in def.effects:
			if effect.get("type", -1) == EffectTypes.EffectType.GRANT_REROLL:
				total += effect.get("params", {}).get("count", 0)
	return total


# ============================================================
# 内部实现
# ============================================================

## 通用触发流程
static func _trigger_relics(relics: Array[Dictionary], trigger_type: EffectTypes.TriggerType, game: Node) -> void:
	var ctx := _build_context(game)
	ctx.source = EffectTypes.EffectSource.RELIC
	_trigger_relics_with_ctx(relics, trigger_type, ctx, game)


## 带上下文的触发流程
static func _trigger_relics_with_ctx(relics: Array[Dictionary], trigger_type: EffectTypes.TriggerType, ctx: EffectEngine.ExecuteContext, game: Node) -> void:
	for r: Dictionary in relics:
		var def: RelicDef = GameData.get_relic_def(r.get("id", ""))
		if not def:
			continue
		if not _check_cooldown(def, r):
			continue
		if not _check_counter(def, r):
			continue
		ctx.source_id = def.id
		var effects := EffectTriggerFilter.get_executable_effects(
			def.effects, trigger_type, ctx)
		if effects.is_empty():
			continue
		var result := EffectEngine.execute(effects, ctx)
		_apply_result(result, game, def.id)


## 将 ExecuteResult 应用到游戏状态
static func _apply_result(result: EffectEngine.ExecuteResult, _game: Node, _relic_id: String) -> void:
	if result.armor > 0:
		PlayerState.armor += result.armor
		EventBus.floating_text.emit("+%d护甲" % result.armor, Color.CYAN, "player", "")
	if result.heal > 0:
		var actual_heal: int = mini(result.heal, PlayerState.max_hp - PlayerState.hp)
		PlayerState.hp += actual_heal
		if actual_heal > 0:
			EventBus.floating_text.emit("+%dHP" % actual_heal, Color.GREEN, "player", "")
	if result.self_damage > 0:
		PlayerState.hp = maxi(1, PlayerState.hp - result.self_damage)
		EventBus.floating_text.emit("-%dHP" % result.self_damage, Color.RED, "player", "")
	if result.extra_plays > 0:
		TurnManager.plays_left += result.extra_plays
	if result.extra_rerolls > 0:
		TurnManager.free_rerolls_left += result.extra_rerolls
	if result.extra_draws > 0:
		PlayerState.relic_temp_draw_bonus += result.extra_draws
	if result.gold_gain > 0:
		PlayerState.gold += result.gold_gain
		EventBus.floating_text.emit("+%d金币" % result.gold_gain, Color.YELLOW, "player", "")
	if not result.apply_statuses.is_empty():
		for st: Dictionary in result.apply_statuses:
			var st_type: int = EffectTypes.status_name_to_type(st.get("status", ""))
			if st_type < 0:
				push_warning("RelicEngine: 未知状态名 '%s'" % st.get("status", ""))
				continue
			var st_value: int = st.get("value", 1)
			var st_duration: int = st.get("duration", 3)
			var st_target: String = st.get("target", "self")
			if st_target == "self":
				GameManager.add_status(st_type, st_value, st_duration)


## 构建执行上下文
static func _build_context(_game: Node) -> EffectEngine.ExecuteContext:
	var ctx := EffectEngine.ExecuteContext.new()
	ctx.player_hp = PlayerState.hp
	ctx.player_max_hp = PlayerState.max_hp
	ctx.player_armor = PlayerState.armor
	ctx.player_combo = PlayerState.combo_count
	ctx.player_rerolls = TurnManager.free_rerolls_left
	ctx.hand_size = DiceBag.hand_dice.size()
	if PlayerState.has_method("get_scar_stacks"):
		ctx.player_scar_stacks = PlayerState.get_scar_stacks()
	elif "scar_stacks" in PlayerState:
		ctx.player_scar_stacks = PlayerState.scar_stacks
	return ctx


## 冷却检查（返回 true = 可触发）
static func _check_cooldown(def: RelicDef, relic_data: Dictionary) -> bool:
	if def.cooldown <= 0:
		return true
	var last_trigger_turn: int = relic_data.get("_last_trigger_turn", -999)
	var current_turn: int = TurnManager.battle_turn
	if current_turn - last_trigger_turn < def.cooldown:
		return false
	relic_data["_last_trigger_turn"] = current_turn
	return true


## 计数器检查（返回 true = 达到触发条件）
static func _check_counter(def: RelicDef, relic_data: Dictionary) -> bool:
	if def.max_counter <= 0:
		return true
	var counter: int = relic_data.get("counter", 0) + 1
	relic_data["counter"] = counter
	if counter >= def.max_counter:
		relic_data["counter"] = 0
		return true
	return false