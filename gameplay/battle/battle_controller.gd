# battle_controller.gd — 战斗主控制器
# 挂载于 BattleScene，串联骰子选择 → 出牌 → 敌方回合 → 结算
class_name BattleController
extends Node2D

const PlayHandlerBridge = preload("res://gameplay/battle/play_handler_bridge.gd")
const RerollHandler = preload("res://gameplay/battle/reroll_handler.gd")
const TurnEndProcessor = preload("res://gameplay/battle/turn_end_processor.gd")
const ClassDefData = preload("res://data/class_def.gd")
const EnemyMgr = preload("res://gameplay/battle/battle_enemy_manager.gd")

# Prefab 场景（后续美术资源直接换这些 tscn，不动代码）
# 注：敌人视图已改走 EnemyFactory.create() 工厂模式，支持独立 tscn 优先 + 兜底
const DiceButtonScene: PackedScene = preload("res://entities/dice_button/dice_button.tscn")
const DiceTooltipScene: PackedScene = preload("res://entities/dice_tooltip/dice_tooltip.tscn")

# ── 信号
signal battle_won
signal battle_lost

# ── 节点引用
# WorldLayer：敌人 VFX 震屏层（Node2D，挂在 BattleScene 根节点下，与 UILayer 同级）
var world_layer: Node = null
var enemy_container: Node2D = null

@onready var player_status_bar: PanelContainer = %PlayerStatusBar
@onready var hp_label: Label = %HpLabel
@onready var hp_bar: ProgressBar = %HpBar
@onready var armor_label: Label = %ArmorLabel
@onready var gold_label: Label = %GoldLabel
@onready var turn_label: Label = %TurnLabel
@onready var stage_label: Label = %StageLabel
@onready var dice_container: HBoxContainer = %DiceContainer
@onready var play_btn: Button = %PlayBtn
@onready var reroll_btn: Button = %RerollBtn
@onready var end_turn_btn: Button = %EndTurnBtn
@onready var hand_label: Label = %HandLabel

# 飘字覆盖层（UILayer/Root 下，不受震屏影响）
var _float_layer: Control = null
# 骰子信息 Tooltip（选中骰子时弹出名字+描述）
var _dice_tooltip: DiceTooltip = null
# 最后一次触发 tooltip 的骰子 id（用于判断是否需要隐藏）
var _tooltip_die_id: int = -1

# ── 战斗状态
var selected_dice_indices: Array[int] = []
var enemy_views: Array[Node] = []
var _is_resolving: bool = false

# ── 生命周期

func _ready() -> void:
	# 初始化 WorldLayer 和 EnemyContainer 引用
	# 场景结构：BattleScene > WorldLayer > EnemyContainer（Node2D 世界层，承载敌人与震屏）
	#          BattleScene > UILayer > Root > VBox（状态栏 / Spacer占位 / 手牌区）
	world_layer = get_node_or_null("%WorldLayer")
	if world_layer == null:
		push_warning("[BattleController] 未找到 WorldLayer 节点，震屏将作用于自身")
		world_layer = self
	enemy_container = get_node_or_null("%EnemyContainer")
	if enemy_container == null:
		push_warning("[BattleController] 未找到 EnemyContainer，尝试 WorldLayer 子路径")
		enemy_container = get_node_or_null("%WorldLayer/EnemyContainer")
	_connect_button_signals()
	_connect_autoload_signals()
	# 内联 UI 初始化（原 _init_ui）
	play_btn.disabled = true
	reroll_btn.disabled = true
	end_turn_btn.disabled = true
	hand_label.text = "等待战斗开始..."
	_setup_float_layer()
	_setup_auto_end_timer()

func _connect_button_signals() -> void:
	play_btn.pressed.connect(_on_play_pressed)
	reroll_btn.pressed.connect(_on_reroll_pressed)
	end_turn_btn.pressed.connect(_on_end_turn_pressed)

func _connect_autoload_signals() -> void:
	GameManager.hp_changed.connect(_on_hp_changed)
	GameManager.armor_changed.connect(func(_v): _refresh_status_bar())
	GameManager.gold_changed.connect(func(_v): _refresh_status_bar())
	GameManager.dice_updated.connect(func(): _refresh_hand_display(); _update_damage_preview())
	GameManager.turn_started.connect(_on_turn_started)
	GameManager.enemy_turn_started.connect(_on_enemy_turn_started)
	GameManager.phase_changed.connect(_on_phase_changed)
	GameManager.battle_ended.connect(_on_battle_ended)

## 创建飘字覆盖层：挂在 UILayer/Root 下，与 WorldLayer 分离所以不受震屏影响
## top_level=true 使其忽略父节点变换，直接使用全局坐标系
func _setup_float_layer() -> void:
	var ui_root: Node = get_node_or_null("%Root")
	if ui_root == null:
		push_warning("[BattleController] 未找到 %Root，飘字层挂到 world_layer")
		ui_root = world_layer
	_float_layer = Control.new()
	_float_layer.name = "FloatLayer"
	_float_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_float_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_float_layer.top_level = true  # 忽略父节点变换，全局坐标系
	ui_root.add_child(_float_layer)
	# 创建骰子信息 Tooltip，挂在 FloatLayer 下
	_dice_tooltip = DiceTooltipScene.instantiate() as DiceTooltip
	_dice_tooltip.z_index = 100
	_float_layer.add_child(_dice_tooltip)

## 自动结束回合定时器 — 对应原版 useBattleCombat useEffect L322-343
## 当 playsLeft<=0 或所有未消耗骰子为0时，1.0秒后自动结束回合（Godot 设计规范 §4.2）
## 延迟足够让玩家看到伤害数字飘出，但不需要手动点结束
func _setup_auto_end_timer() -> void:
	_auto_end_timer = Timer.new()
	_auto_end_timer.one_shot = true
	_auto_end_timer.wait_time = 1.0
	_auto_end_timer.timeout.connect(_on_auto_end_timer_timeout)
	add_child(_auto_end_timer)

func _check_auto_end_turn() -> void:
	# 条件：玩家回合 + 有存活敌人 + playsLeft<=0 或 无未消耗骰子
	if _is_resolving or GameManager.is_enemy_turn:
		return
	if EnemyMgr.get_living_enemies(enemy_views).is_empty():
		return
	if PlayerState.hp <= 0:
		return
	# 骰子出牌即入弃骰库，不再有 spent 骰子；手牌为空即"无可用骰子"
	if GameManager.plays_left <= 0 or DiceBag.hand_dice.is_empty():
		if _auto_end_timer and _auto_end_timer.is_stopped():
			_auto_end_timer.start()
	else:
		if _auto_end_timer and not _auto_end_timer.is_stopped():
			_auto_end_timer.stop()

func _on_auto_end_timer_timeout() -> void:
	# 再次确认状态未变
	if _is_resolving or GameManager.is_enemy_turn:
		return
	if PlayerState.hp <= 0:
		return
	if EnemyMgr.get_living_enemies(enemy_views).is_empty():
		return
	_process_turn_end_and_enemy_phase()

## 获取震屏目标节点（WorldLayer），UI 层不受震屏影响
func get_shake_target() -> CanvasItem:
	return world_layer

# ── 战斗初始化

## 由 BattleScene 调用，启动一场战斗
func start_battle(encounter: Dictionary = {}) -> void:
	EnemyMgr.clear_enemy_views(enemy_container)
	enemy_views.clear()
	selected_dice_indices.clear()
	if _dice_tooltip:
		_dice_tooltip.hide_tip()
	_tooltip_die_id = -1
	_is_resolving = false
	_reroll_count = 0

	# 战斗状态重置：清空上场战斗残留，防止手牌跨战斗泄漏
	# - hand_dice：上场战斗没出完的骰子一律回收到弃骰库，新战斗从空手牌开始
	# - battle_turn：每场战斗独立计数，不累积
	# - target/taunt：清掉上场的目标锁定和嘲讽状态
	var leftover_ids: Array[String] = []
	for d: Dictionary in DiceBag.hand_dice:
		var did: String = d.get("defId", "")
		if did != "":
			leftover_ids.append(did)
	if not leftover_ids.is_empty():
		DiceBag.discard_hand_dice(leftover_ids)
	DiceBag.hand_dice = []
	DiceBag.dice_played_this_turn.clear()
	GameManager.battle_turn = 0
	GameManager.target_enemy_uid = ""
	GameManager.taunt_enemy_uid = ""
	GameManager.is_enemy_turn = false
	# 跨战斗状态全清（报告 P0-2：防止上场战斗残留导致伤害爆炸）
	GameManager.blood_reroll_count = 0
	GameManager.charge_stacks = 0
	GameManager.mage_overcharge_mult = 0.0
	GameManager.warrior_rage_mult = 0.0
	GameManager.warrior_rage_mult_val = 0.0
	GameManager.rage_fire_bonus = 0
	GameManager.fury_bonus_damage = 0
	GameManager.combo_count = 0
	GameManager.last_play_hand_type = ""
	GameManager.locked_element = ""
	GameManager.hp_lost_this_turn = 0
	GameManager.hp_lost_this_battle = 0
	PlayerState.statuses = []
	PlayerState.plays_per_enemy.clear()  # §6.3 每敌出牌计数在新战斗开始清零

	# 创建敌人视图：优先使用传入的 encounter，否则从 PlayerState.battle_waves 读取
	var enemies: Array[String] = []
	var raw_enemies: Array = encounter.get("enemies", [])  # [RULES-B2-EXEMPT] dict.get 返回裸 Array
	if raw_enemies.is_empty():
		var wave_data: Array[Dictionary] = GameManager.battle_waves
		var wave_index: int = GameManager.current_wave_index
		if wave_index < wave_data.size():
			var wave: Dictionary = wave_data[wave_index]
			raw_enemies = wave.get("enemies", [])
	enemies.assign(raw_enemies.filter(func(e): return e is String))
	for i: int in enemies.size():
		var enemy_id: String = enemies[i]
		# 通过工厂按 enemy_id 加载对应 tscn（独立 tscn 优先，兜底 enemy_view.tscn）
		var view: EnemyView = EnemyFactory.create(enemy_id)
		enemy_container.add_child(view)  # 先加入树触发 _ready() 构建 UI
		view.set_slot_index(i)           # 先设 slot，再 init（init→setup→_refresh_visual 会读 _slot_index）
		view.init(enemy_id)             # 再绑定数据
		# 设初始位置：用 enemy 真实 distance 查表（不再硬编码 distance=0）
		var battle_scene := owner as BattleScene
		if battle_scene != null:
			var e_inst: EnemyInstance = view.get_enemy_instance()
			var real_dist: int = e_inst.distance if e_inst else 0
			var init_visuals: Dictionary = battle_scene.get_slot_visuals(i, real_dist)
			view.position = init_visuals.position
		view.enemy_clicked.connect(_on_enemy_clicked)
		enemy_views.append(view)

	# 更新关卡标签
	stage_label.text = "第 %d 章 · 第 %d 波" % [GameManager.chapter, GameManager.current_node + 1]

	# 战斗日志：开局
	BattleLog.clear()
	BattleLog.log_write("⚔ 第 %d 章 · 第 %d 波 开战" % [GameManager.chapter, GameManager.current_node + 1])
	var enemy_names: Array[String] = []
	for enemy_id: String in enemies:
		var cfg: EnemyConfig = EnemyConfig.get_config(enemy_id)
		if cfg:
			enemy_names.append(cfg.name)
	if not enemy_names.is_empty():
		BattleLog.log_enemy("敌人登场：%s" % ", ".join(enemy_names))

	# 首回合：battle_init 不触发 endTurn，需手动抽一次牌（对应原版 battleInit.ts 初始抽牌）
	# 后续回合的抽牌由 TurnManager.end_turn_and_draw_phase 在敌人回合结束后执行
	TurnManager.plays_left = TurnManager.max_plays
	TurnManager.free_rerolls_left = TurnManager.free_rerolls_per_turn + RelicEngine.get_extra_free_rerolls(PlayerState.relics)
	GameManager.execute_draw_phase()

	# 进入玩家回合
	_begin_player_turn()

## 玩家点击敌人 → 切换锁定目标（受嘲讽限制）
func _on_enemy_clicked(enemy_uid: String) -> void:
	# 敌人回合中/结算中禁止切换目标
	if _is_resolving or GameManager.is_enemy_turn:
		return
	# 嘲讽期间强制锁定在嘲讽目标上
	if GameManager.taunt_enemy_uid != "" and EnemyMgr.is_enemy_alive(enemy_views, GameManager.taunt_enemy_uid):
		VFX.show_toast("嘲讽中！无法切换目标", "damage")
		return
	SoundPlayer.play_sound("select")
	GameManager.target_enemy_uid = enemy_uid
	EnemyMgr.refresh_enemy_views(enemy_views)

# ── 玩家回合

func _begin_player_turn() -> void:
	# 防重入 & gameover 检查（Godot 设计规范 §4.3）
	if GameManager.phase == GameTypes.GamePhase.GAME_OVER:
		return
	GameManager.is_enemy_turn = false
	GameManager.set_phase(GameTypes.GamePhase.PLAYER_TURN)
	GameManager.battle_turn += 1
	BattleLog.log_write("▶ 玩家回合 %d" % GameManager.battle_turn, BattleLog.COLOR_PLAYER)
	_reroll_count = 0
	# 注意：armor / playsLeft / freeRerollsLeft / hpLostThisTurn / consecutiveNormalAttacks
	# 全部由 TurnManager.end_turn_and_draw_phase() 在进入敌人回合前 reset（§4.4）
	# 抽牌也已经在 end_turn_and_draw_phase() 中完成
	# 本函数只负责 UI 切换 + 打开闸门
	GameManager.start_turn()

func _on_turn_started() -> void:
	_is_resolving = false
	_refresh_hand_display()
	_update_button_states()
	turn_label.text = "回合 %d" % GameManager.battle_turn
	hand_label.text = "手牌 · 剩余 %d 出牌" % GameManager.plays_left
	_refresh_status_bar()
	# 同步 battle_turn 到敌人实例（意图显示用）
	for e: EnemyInstance in EnemyMgr.collect_enemy_instances(enemy_views):
		e.battle_turn = GameManager.battle_turn
	EnemyMgr.refresh_enemy_views(enemy_views)
	_check_auto_end_turn()

# ── 骰子交互

func _on_dice_clicked(index: int) -> void:
	if _is_resolving or GameManager.is_enemy_turn:
		return
	SoundPlayer.play_sound("select")

	var idx: int = selected_dice_indices.find(index)
	if idx >= 0:
		selected_dice_indices.remove_at(idx)
	else:
		selected_dice_indices.append(index)

	_update_dice_selection_visuals()
	_update_hand_candidate_highlights()
	_update_damage_preview()
	_update_button_states()


## 骰子被点击后由 Controller 决定 tooltip 显示/隐藏（单一真源）
## 此函数在 _on_dice_clicked 之后被调用（信号顺序：dice_index_clicked → die_tap_requested）
## 此刻 selected_dice_indices 已经是"点击后"的真实状态
func _on_die_tap_requested(die_id: int, center_pos: Vector2) -> void:
	if _dice_tooltip == null:
		return
	# 查找该 die_id 对应的手牌索引
	var target_idx: int = -1
	var target_die: Dictionary = {}
	var hand: Array[Dictionary] = DiceBag.hand_dice
	for i: int in range(hand.size()):
		if int(hand[i].get("id", -1)) == die_id:
			target_idx = i
			target_die = hand[i]
			break
	if target_idx < 0:
		return
	# 以 selected_dice_indices 为真相源：当前这颗是否真的处于选中
	var is_selected_now: bool = selected_dice_indices.has(target_idx)
	if is_selected_now:
		var fury_bonus: int = 0
		if target_die.get("defId", "") == "w_fury":
			fury_bonus = int(GameManager.fury_bonus_damage)
		_tooltip_die_id = die_id
		_dice_tooltip.show_for_die(target_die, center_pos, PlayerState.player_class, fury_bonus)
	else:
		# 取消选中 → 如果 tooltip 正指向这颗，隐藏
		if _tooltip_die_id == die_id:
			_dice_tooltip.hide_tip()
			_tooltip_die_id = -1

func _update_dice_selection_visuals() -> void:
	for child: Node in dice_container.get_children():
		if child is DiceButton:
			var btn: DiceButton = child as DiceButton
			btn.set_selected(selected_dice_indices.has(btn.dice_index))

## 高亮可组成牌型的候选骰子（选中一个骰子后，其他能组成牌型的骰子边框变亮）
func _update_hand_candidate_highlights() -> void:
	if selected_dice_indices.is_empty():
		# 无选中 → 清除所有高亮
		for child: Node in dice_container.get_children():
			if child is DiceButton:
				(child as DiceButton).set_candidate(false)
		return
	# 计算候选：以第一个选中的骰子为锚，找能和它组成牌型的骰子
	var anchor_id: int = -1
	var anchor_idx: int = selected_dice_indices[0]
	if anchor_idx < DiceBag.hand_dice.size():
		anchor_id = DiceBag.hand_dice[anchor_idx].get("id", -1)
	var candidates: Dictionary = HandEvaluator.find_hand_candidates(DiceBag.hand_dice, anchor_id)
	for child: Node in dice_container.get_children():
		if child is DiceButton:
			var btn: DiceButton = child as DiceButton
			var is_candidate: bool = candidates.has(btn.get_die_id()) and not selected_dice_indices.has(btn.dice_index)
			btn.set_candidate(is_candidate)

func _update_damage_preview() -> void:
	# DamagePreview 是场景内节点，通过 %DamagePreview 或路径获取
	var preview: DamagePreview = _get_damage_preview()
	if not preview:
		return

	# 选中为空 → 直接隐藏整个面板（选中时才显示，避免占用手牌区纵向空间）
	if selected_dice_indices.is_empty():
		preview.visible = false
		return

	preview.visible = true
	var selected_dice: Array[Dictionary] = _collect_selected_dice()
	preview.refresh(selected_dice)

func _get_damage_preview() -> DamagePreview:
	# DamagePreview 在 HandVBox 下（tscn 中定义）
	var dp: Node = get_node_or_null("%DamagePreview")
	if dp == null:
		dp = get_node_or_null("../UILayer/Root/VBox/HandPanel/HandVBox/DamagePreview")
	if dp and dp is DamagePreview:
		return dp as DamagePreview
	return null

func _collect_selected_dice() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for idx: int in selected_dice_indices:
		if idx < DiceBag.hand_dice.size():
			result.append(DiceBag.hand_dice[idx])
	return result

func _update_play_button_state() -> void:
	if selected_dice_indices.is_empty() or _is_resolving:
		play_btn.disabled = true
		return
	# 出牌校验：选中的骰子必须能组成有效牌型
	var selected_dice: Array[Dictionary] = _collect_selected_dice()
	var hand_result: Dictionary = HandEvaluator.check_hands(selected_dice)
	var active_hands: Array[String] = []
	active_hands.assign(hand_result.get("activeHands", []))
	# 普通攻击只允许单颗骰子出；多颗骰子必须成牌型（activeHands中有非普通攻击的牌型）
	var has_real_hand: bool = active_hands.any(func(h: String) -> bool: return h != "普通攻击")
	var is_single_normal: bool = selected_dice.size() == 1 and active_hands.size() == 1 and active_hands[0] == "普通攻击"
	# §6.1 战士多选普攻：`normal_attack_multi_select` 允许的职业可以多选普攻
	var is_pure_normal_multi: bool = (not has_real_hand) and selected_dice.size() > 1
	var class_def: ClassDef = ClassDefData.get_all().get(PlayerState.player_class) as ClassDef
	var can_multi_normal: bool = class_def != null and class_def.normal_attack_multi_select
	var is_warrior_multi_normal: bool = is_pure_normal_multi and can_multi_normal
	play_btn.disabled = not (has_real_hand or is_single_normal or is_warrior_multi_normal)

# ── 出牌

func _on_play_pressed() -> void:
	if _is_resolving:
		return
	play_btn.disabled = true  # 防连点
	var was_resolving: bool = _is_resolving
	# 实例化桥接器（支持 await 时序编排）
	var bridge: PlayHandlerBridge = PlayHandlerBridge.new()
	bridge.name = "PlayHandlerBridge"
	add_child(bridge)
	await bridge.execute(self)
	if bridge != null and is_instance_valid(bridge):
		bridge.queue_free()
	# execute 正常完成后 _is_resolving 由 _on_after_play_resolve 重置；
	# 若提前 return（如牌型校验失败）_is_resolving 仍为 false，直接恢复按钮
	if is_inside_tree() and not _is_resolving:
		play_btn.disabled = false

# ── 重投

## 本回合累计重投次数（免费 + 付费）
var _reroll_count: int = 0

## 计算重投 HP 代价 — 对应原版 rerollCalc.ts getRerollHpCost
## 返回: 0=免费, 正数=HP代价, -1=不可重投
func _get_reroll_hp_cost() -> int:
	return RerollHandler.get_reroll_hp_cost(_reroll_count)

## 重投按钮 — 委托 RerollHandler
func _on_reroll_pressed() -> void:
	if _is_resolving:
		return
	var ok: bool = RerollHandler.execute(
		selected_dice_indices, _reroll_count,
		func(new_count: int) -> void:
			_reroll_count = new_count
			selected_dice_indices.clear()
			if _dice_tooltip:
				_dice_tooltip.hide_tip()
			_tooltip_die_id = -1
			_refresh_hand_display()
			_update_button_states()
	)
	if not ok:
		return

# ── 结束回合

## 自动结束回合定时器
var _auto_end_timer: Timer = null

func _on_end_turn_pressed() -> void:
	if _is_resolving or GameManager.is_enemy_turn:
		return
	if GameManager.phase == GameTypes.GamePhase.GAME_OVER:
		return
	_process_turn_end_and_enemy_phase()

## 回合结束处理 — 对应原版 processTurnEnd + endTurn
func _process_turn_end_and_enemy_phase() -> void:
	if _is_resolving or GameManager.is_enemy_turn:
		return
	if GameManager.phase == GameTypes.GamePhase.GAME_OVER:
		return

	SoundPlayer.play_sound("turn_end")

	var living_enemies: Array[Node] = EnemyMgr.get_living_enemies(enemy_views)
	if living_enemies.is_empty():
		return

	_is_resolving = true
	play_btn.disabled = true
	reroll_btn.disabled = true
	end_turn_btn.disabled = true
	selected_dice_indices.clear()
	if _dice_tooltip:
		_dice_tooltip.hide_tip()
	_tooltip_die_id = -1
	var dp: DamagePreview = _get_damage_preview()
	if dp:
		dp.refresh([])

	# === 回合结束处理（委托 TurnEndProcessor）===
	var played_this_turn: bool = GameManager.plays_left < GameManager.max_plays
	# [DIAG] 诊断日志：回合结束
	print_rich("[color=yellow][BattleController][DIAG] turn_end: plays_left=%d max=%d played_this_turn=%s charge=%d class=%s[/color]" % [
		GameManager.plays_left, GameManager.max_plays, played_this_turn, PlayerState.charge_stacks, PlayerState.player_class
	])
	TurnEndProcessor.process_turn_end(played_this_turn, self)

	# === 进入敌方回合（Godot 设计规范 §4.5：5 字段 reset）===
	TurnManager.enter_enemy_turn_reset()
	GameManager.set_phase(GameTypes.GamePhase.ENEMY_TURN)

	# 敌方 DoT 预结算
	EnemyMgr.settle_enemy_dots(enemy_views)
	if EnemyMgr.check_battle_over(enemy_views, _on_battle_ended.bind(true)):
		return

	# 执行敌方攻击
	_process_enemy_attacks()

# ── 敌方回合

func _process_enemy_attacks() -> void:
	# 嘲讽清理：敌人回合开始先清旧嘲讽（若 Guardian 在本回合再次 resolve 会重新设置）
	GameManager.taunt_enemy_uid = ""
	var instances: Array[EnemyInstance] = EnemyMgr.collect_enemy_instances(enemy_views)
	for e: EnemyInstance in instances:
		e.battle_turn = GameManager.battle_turn
	GameManager.current_enemies = instances  # Priest AI 查同伴用
	var living: Array[EnemyInstance] = []
	living.assign(instances.filter(
		func(e: EnemyInstance) -> bool: return e.hp > 0
	))
	if living.is_empty():
		_on_battle_ended(true)
		return
	EnemyActionResolver.run_turn(self, living)

# ── UI 更新

func _on_hp_changed(hp: int, max_hp: int) -> void:
	hp_label.text = "%d/%d" % [hp, max_hp]
	hp_bar.value = float(hp) / float(max_hp) * 100.0

func _on_enemy_turn_started() -> void:
	_is_resolving = true
	_refresh_status_bar()

func _on_phase_changed(new_phase: GameTypes.GamePhase) -> void:
	match new_phase:
		GameTypes.GamePhase.PLAYER_TURN:
			_is_resolving = false
		GameTypes.GamePhase.ENEMY_TURN:
			_is_resolving = true

func _refresh_status_bar() -> void:
	_on_hp_changed(PlayerState.hp, PlayerState.max_hp)
	armor_label.text = "护甲: %d" % PlayerState.armor
	gold_label.text = "金币: %d" % PlayerState.gold

func _refresh_hand_display() -> void:
	for child: Node in dice_container.get_children():
		child.queue_free()
	var hand: Array[Dictionary] = DiceBag.hand_dice
	for i: int in hand.size():
		var btn := DiceButtonScene.instantiate() as DiceButton
		dice_container.add_child(btn)  # 先加入树触发 _ready()
		btn.init(hand[i], i)           # 再绑定数据
		btn.dice_index_clicked.connect(_on_dice_clicked)
		btn.die_tap_requested.connect(_on_die_tap_requested)
	hand_label.text = "手牌 · 剩余 %d 出牌" % GameManager.plays_left

func _update_button_states() -> void:
	var is_player_turn: bool = not GameManager.is_enemy_turn and not _is_resolving
	# play_btn：走牌型校验逻辑（_update_play_button_state 已实现）
	_update_play_button_state()
	if not is_player_turn:
		play_btn.disabled = true
	# reroll_btn：选中非空 + HP 能付得起 + 玩家回合
	var reroll_cost: int = _get_reroll_hp_cost()
	var can_reroll: bool = reroll_cost != -1 and (reroll_cost <= 0 or PlayerState.hp >= reroll_cost)
	reroll_btn.disabled = not is_player_turn or not can_reroll or selected_dice_indices.is_empty()
	# end_turn_btn：仅玩家回合可点
	end_turn_btn.disabled = not is_player_turn


func _on_battle_ended(victory: bool) -> void:
	_is_resolving = true
	play_btn.disabled = true
	reroll_btn.disabled = true
	end_turn_btn.disabled = true
	if victory:
		hand_label.text = "战斗胜利!"
		BattleLog.log_write("战斗胜利", BattleLog.COLOR_PLAYER)
		SoundPlayer.play_sound("victory")
		battle_won.emit()
	else:
		hand_label.text = "战斗失败..."
		BattleLog.log_write("战斗失败", BattleLog.COLOR_ENEMY)
		SoundPlayer.play_sound("defeat")
		# [E1-FIX] 等待双手死亡动画播完（PlayerHands.play_death = 1.2s）
		# 再切 GAME_OVER，否则帧末 queue_free 会截断 Tween
		await get_tree().create_timer(1.3).timeout
		if not is_inside_tree():
			return
		GameManager.set_phase(GameTypes.GamePhase.GAME_OVER)
		battle_lost.emit()
