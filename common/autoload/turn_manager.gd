## 回合管理单例 — 管理回合流程 / 出牌次数 / 抽牌阶段 / 弃牌
## 从 game_manager.gd 拆分（GODOT-AUTOLOAD-SPLIT）

extends Node

const DrawPhaseResolver = preload("res://gameplay/battle/draw_phase_resolver.gd")
const DiceSpecialEffects = preload("res://gameplay/battle/dice_special_effects.gd")

signal phase_changed(new_phase: GameTypes.GamePhase)
signal turn_started
signal enemy_turn_started
signal floating_text_requested(text: String, color: Color, target: String)

# ============================================================
# 回合规则
# ============================================================

var phase: GameTypes.GamePhase = GameTypes.GamePhase.START
var free_rerolls_left: int = 1
var free_rerolls_per_turn: int = 1
var plays_left: int = 1
var max_plays: int = 1
var battle_turn: int = 0
var is_enemy_turn: bool = false


# ============================================================
# 回合管理
# ============================================================

## 开始新回合（对应原版 Godot 设计规范 §4 —— 玩家回合入口）
## 此时所有状态重置已经在 end_turn_and_draw_phase() / enter_enemy_turn_reset() 完成
## 本函数只负责：打开闸门 + 发信号，不做任何状态重置
## 法师蓄力护甲改到 turn_end 处理（参见原版 turnEndProcessing.ts L54-85）
func start_turn() -> void:
	turn_started.emit()


## 敌人回合入口重置（对应原版 enemyAI.ts L101 executeEnemyTurn 入口）
## 在 controller 进入敌人回合前调用。重置 5 字段（Godot 设计规范 §4.5）：
##   isEnemyTurn=true / bloodRerollCount=0 / comboCount=0
##   lastPlayHandType="" / blackMarketUsedThisTurn=false
func enter_enemy_turn_reset() -> void:
	is_enemy_turn = true
	PlayerState.blood_reroll_count = 0
	PlayerState.combo_count = 0
	PlayerState.last_play_hand_type = ""
	PlayerState.black_market_used_this_turn = false


## 回合收尾+抽牌（对应原版 useBattleCombat.tsx L280-290 的 endTurn setGame + executeDrawPhase）
## 在敌人回合全部结算完、玩家 HP>0、有存活敌人之后调用
## 顺序严格：先 reset 6 字段 → 再执行抽牌阶段（Godot 设计规范 §4.4）
func end_turn_and_draw_phase() -> void:
	# [FIX-P0] 先记录本回合是否出过牌，再重置 plays_left
	# 旧版先 reset plays_left 再调 execute_draw_phase，
	# 导致 played_this_turn = (plays_left < max_plays) 永远为 false，
	# 法师出牌后走吟唱分支（保留手牌）而非全弃分支
	var _played_this_turn: bool = plays_left < max_plays
	# [DIAG] 诊断日志：帮助定位法师吟唱弃牌问题
	print_rich("[color=cyan][TurnManager][DIAG] end_turn_and_draw_phase: plays_left=%d max_plays=%d _played_this_turn=%s charge_stacks=%d class=%s[/color]" % [
		plays_left, max_plays, _played_this_turn, PlayerState.charge_stacks, PlayerState.player_class
	])

	# Reset 6 字段（与原版 useBattleCombat.tsx:281-290 完全一致）
	is_enemy_turn = false
	PlayerState.armor = 0
	plays_left = max_plays
	free_rerolls_left = free_rerolls_per_turn + RelicEngine.get_extra_free_rerolls(PlayerState.relics)
	PlayerState.hp_lost_this_turn = 0
	PlayerState.consecutive_normal_attacks = 0
	# 清空"本回合已打出骰子"记录（此时 TurnEndProcessor 已处理完嘲讽反噬，安全清）
	DiceBag.dice_played_this_turn.clear()
	# 抽牌阶段（传入记录的 played_this_turn）
	execute_draw_phase(_played_this_turn)


## 出牌后处理
func after_play() -> void:
	plays_left = maxi(0, plays_left - 1)
	PlayerState.combo_count += 1
	
	# 法师出牌重置蓄力（护甲保留到敌人回合挡伤害，回合收尾时清零）
	# 注意：charge_stacks 在出牌结算之后清零，不影响蓄力骰子的加成计算
	# _resolve_mage_chant(true) 在回合结束时也会清零，此处先清零防止多次出牌时蓄力残留
	if PlayerState.player_class == "mage":
		PlayerState.charge_stacks = 0
		PlayerState.mage_overcharge_mult = 0.0
	
	# [FIX-P3] 盗贼连击补牌：每连击1次，下回合抽牌+1（最多+2）
	if PlayerState.player_class == "rogue" and PlayerState.combo_count >= 2:
		PlayerState.rogue_combo_draw_bonus = mini(PlayerState.combo_count - 1, 2)
	
	DiceBag.dice_updated.emit()


## 消耗出牌次数（盗贼连击等）
func consume_play() -> void:
	plays_left = maxi(0, plays_left - 1)
	PlayerState.combo_count += 1


## [DEPRECATED v0.4] 不要再调用本函数
## 原逻辑已拆分：回合收尾 → end_turn_and_draw_phase()；法师吟唱 → battle_controller._process_turn_end_and_enemy_phase()
## 保留函数体仅为兼容旧代码路径，下次清理时删除
func end_player_turn() -> void:
	push_warning("[TurnManager] end_player_turn() is deprecated, use end_turn_and_draw_phase() instead")
	execute_draw_phase()


## 抽牌阶段（委托 DrawPhaseResolver 纯函数 + 写回 autoload 状态）
## 对应原版 drawPhase.ts + applyDiceSpecialEffects
func execute_draw_phase(played_this_turn_override: Variant = null) -> void:
	# [FIX-P0] 优先使用外部传入的 played_this_turn（end_turn_and_draw_phase 先 reset 了 plays_left）
	# 若无显式传入，则从当前 plays_left 推断（兼容旧调用点如 start_battle 初始抽牌）
	var played_this_turn: bool
	if played_this_turn_override != null:
		played_this_turn = played_this_turn_override
	else:
		played_this_turn = plays_left < max_plays

	# [DIAG] 诊断日志：抽牌阶段关键参数
	print_rich("[color=cyan][TurnManager][DIAG] execute_draw_phase: played_this_turn=%s class=%s charge=%d draw_count=%d hand_size=%d[/color]" % [
		played_this_turn, PlayerState.player_class, PlayerState.charge_stacks, DiceBag.draw_count, DiceBag.hand_dice.size()
	])

	# 1. 纯函数结算
	var result: DrawPhaseResolver.DrawPhaseResult = DrawPhaseResolver.resolve(
		DiceBag.hand_dice,
		PlayerState.player_class,
		played_this_turn,
		PlayerState.charge_stacks,
		DiceBag.draw_count,
		PlayerState.hp,
		PlayerState.max_hp,
		PlayerState.relics,
		PlayerState.fortune_wheel_used,
		PlayerState.relic_keep_highest,
		PlayerState.temp_draw_count_bonus,
		PlayerState.rogue_combo_draw_bonus,
		PlayerState.relic_temp_draw_bonus,
		PlayerState.warrior_rage_mult_val,
	)

	# 2. 写回弃骰库
	DiceBag.discard_hand_dice(result.discard_ids)

	# 3. 写回命运之轮消耗
	if result.fortune_wheel_consumed:
		PlayerState.fortune_wheel_used = true

	# 4. 写回保留最高点消耗
	if result.relic_keep_highest_consumed:
		PlayerState.relic_keep_highest = maxi(0, PlayerState.relic_keep_highest - 1)

	# 5. 写回战士狂暴倍率
	PlayerState.warrior_rage_mult_val = result.warrior_rage_mult

	# 6. 写回法师 overcharge 倍率增量
	if result.mage_overcharge_mult_delta > 0.0:
		PlayerState.mage_overcharge_mult += result.mage_overcharge_mult_delta

	# 7. 清零临时加成
	PlayerState.temp_draw_count_bonus = 0
	PlayerState.rogue_combo_draw_bonus = 0
	PlayerState.relic_temp_draw_bonus = 0

	# 8. 抽牌
	var draw_result := DiceBag.draw_from_bag(result.need_draw)
	var fresh_dice: Array[Dictionary] = draw_result.drawn

	# 9. §5.6 应用骰子特殊效果（元素坍缩+小丑+棱镜+共鸣）
	var has_limit_breaker: bool = DiceSpecialEffects.has_limit_breaker_relic(PlayerState.relics)
	var all_hand: Array[Dictionary] = result.kept_dice + fresh_dice
	all_hand = DiceSpecialEffects.apply(all_hand, has_limit_breaker, PlayerState.locked_element)

	DiceBag.hand_dice = all_hand
	DiceBag.dice_updated.emit()

	# [DIAG] 诊断日志：抽牌阶段结算结果
	print_rich("[color=cyan][TurnManager][DIAG] draw_phase result: kept=%d drawn=%d hand_size=%d discard_ids=%s[/color]" % [
		result.kept_dice.size(), fresh_dice.size(), all_hand.size(), str(result.discard_ids)
	])

	# 10. 飘字
	for ft: Dictionary in result.floating_texts:
		floating_text_requested.emit(ft.text, ft.color, ft.target)

	# 11. Toast
	for t: Dictionary in result.toasts:
		DiceBag.toast_requested.emit(t.msg, t.type)


func _discard_hand() -> void:
	# 弃牌逻辑在 execute_draw_phase 中处理
	pass
