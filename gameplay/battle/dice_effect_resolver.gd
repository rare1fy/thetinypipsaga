## 骰子效果结算入口（v2 — 薄代理层）
## 职责：构建 ExecuteContext，调用 EffectEngine，返回结果
## 保留 resolve_on_play / resolve_on_skip / resolve_on_keep 接口签名，
## 让调用方（battle_controller / play_handler_bridge）无需改动

class_name DiceEffectResolver
extends RefCounted


# ============================================================
# 公开数据结构（兼容旧接口）
# ============================================================

## 结算结果 — 直接复用 EffectEngine.ExecuteResult
## 为保持向后兼容，提供类型别名
const ResolveResult = EffectEngine.ExecuteResult


# ============================================================
# 主入口
# ============================================================

## 结算一张骰子的 onPlay 特效
static func resolve_on_play(
	dice_def: DiceDef,
	player_hp: int,
	player_max_hp: int,
	player_rerolls: int,
	player_combo: int,
	player_armor: int,
	target_enemy: EnemyInstance,
	enemies: Array[EnemyInstance],
	dice_in_hand: Array = [],
	unselected_dice: Array = [],
	skip_on_play: bool = false
) -> EffectEngine.ExecuteResult:
	if skip_on_play:
		return EffectEngine.ExecuteResult.new()
	if not dice_def or not dice_def.has_on_play():
		return EffectEngine.ExecuteResult.new()

	# 构建上下文
	var ctx := _build_context(dice_def, player_hp, player_max_hp, player_rerolls,
		player_combo, player_armor, target_enemy, enemies, dice_in_hand, unselected_dice)
	ctx.source = EffectTypes.EffectSource.DICE_ON_PLAY
	ctx.source_id = dice_def.id

	# 获取 ON_PLAY 触发的效果
	var effects := EffectTriggerFilter.get_executable_effects(
		dice_def.effects, EffectTypes.TriggerType.ON_PLAY, ctx)

	# 执行
	return EffectEngine.execute(effects, ctx)


## 结算一张骰子的 onSkip 特效
static func resolve_on_skip(
	dice_def: DiceDef,
	player_hp: int,
	player_max_hp: int,
	dice_in_hand: Array = [],
	unselected_dice: Array = []
) -> EffectEngine.ExecuteResult:
	if not dice_def:
		return EffectEngine.ExecuteResult.new()

	var ctx := EffectEngine.ExecuteContext.new()
	ctx.player_hp = player_hp
	ctx.player_max_hp = player_max_hp
	ctx.source = EffectTypes.EffectSource.DICE_ON_PLAY
	ctx.source_id = dice_def.id
	ctx.dice_points_total = dice_def.get_points_total()
	ctx.dice_count = dice_def.faces.size()
	ctx.hand_size = dice_in_hand.size()

	var effects := EffectTriggerFilter.get_executable_effects(
		dice_def.effects, EffectTypes.TriggerType.ON_SKIP, ctx)

	return EffectEngine.execute(effects, ctx)


## 结算一张骰子的 onKeep 特效
static func resolve_on_keep(
	dice_def: DiceDef,
	player_hp: int,
	player_max_hp: int,
	kept_turns: int
) -> EffectEngine.ExecuteResult:
	if not dice_def:
		return EffectEngine.ExecuteResult.new()

	var ctx := EffectEngine.ExecuteContext.new()
	ctx.player_hp = player_hp
	ctx.player_max_hp = player_max_hp
	ctx.kept_turns = kept_turns
	ctx.source = EffectTypes.EffectSource.DICE_ON_PLAY
	ctx.source_id = dice_def.id
	ctx.dice_points_total = dice_def.get_points_total()

	var effects := EffectTriggerFilter.get_executable_effects(
		dice_def.effects, EffectTypes.TriggerType.ON_KEEP, ctx)

	return EffectEngine.execute(effects, ctx)


# ============================================================
# 内部辅助
# ============================================================

static func _build_context(
	dice_def: DiceDef,
	player_hp: int,
	player_max_hp: int,
	player_rerolls: int,
	player_combo: int,
	player_armor: int,
	target_enemy: EnemyInstance,
	enemies: Array[EnemyInstance],
	dice_in_hand: Array,
	unselected_dice: Array
) -> EffectEngine.ExecuteContext:
	var ctx := EffectEngine.ExecuteContext.new()
	ctx.player_hp = player_hp
	ctx.player_max_hp = player_max_hp
	ctx.player_rerolls = player_rerolls
	ctx.player_combo = player_combo
	ctx.player_armor = player_armor
	ctx.target_enemy = target_enemy
	ctx.enemies = enemies
	ctx.dice_in_hand = dice_in_hand
	ctx.unselected_dice = unselected_dice
	ctx.dice_points_total = dice_def.get_points_total()
	ctx.dice_count = dice_def.faces.size()
	ctx.hand_size = dice_in_hand.size()

	# 从 PlayerState 获取额外信息
	# 伤痕层数
	if PlayerState and PlayerState.has_method("get_scar_stacks"):
		ctx.player_scar_stacks = PlayerState.get_scar_stacks()
	elif PlayerState and "scar_stacks" in PlayerState:
		ctx.player_scar_stacks = PlayerState.scar_stacks
	# 狂暴状态
	if PlayerState and "berserk_turns" in PlayerState:
		ctx.player_berserk_turns = PlayerState.berserk_turns
	# 上回合是否被打 + 被打次数
	if PlayerState and "was_hit_last_enemy_turn" in PlayerState:
		ctx.was_hit_last_turn = PlayerState.was_hit_last_enemy_turn
	elif PlayerState and "was_hit_last_turn" in PlayerState:
		ctx.was_hit_last_turn = PlayerState.was_hit_last_turn
	if PlayerState and "hit_count_last_enemy_turn" in PlayerState:
		ctx.hit_count_last_turn = PlayerState.hit_count_last_enemy_turn

	return ctx
