## 游戏管理器 — 调度中枢（从 422 行瘦身至此）
## 职责：生命周期管理 + 信号中转 + 委托各子模块
## GODOT-AUTOLOAD-SPLIT（2026-04-25）

extends Node

# ============================================================
# 信号（保持外部契约不变）
# ============================================================

signal hp_changed(new_hp: int, max_hp: int)
signal armor_changed(new_armor: int)
signal gold_changed(new_gold: int)
signal phase_changed(new_phase: GameTypes.GamePhase)
signal turn_started
signal enemy_turn_started
signal battle_ended(victory: bool)
signal battle_started(encounter: Dictionary)
signal game_over
signal floating_text_requested(text: String, color: Color, target: String)
signal toast_requested(msg: String, type: String)
signal screen_shake_requested
signal dice_updated

# ============================================================
# 初始化
# ============================================================

func _ready() -> void:
	# 信号转发：子模块 → GameManager（保持外部监听 GameManager.xxx 信号的契约）
	PlayerState.hp_changed.connect(func(h, m): hp_changed.emit(h, m))
	PlayerState.armor_changed.connect(func(a): armor_changed.emit(a))
	PlayerState.gold_changed.connect(func(g): gold_changed.emit(g))
	PlayerState.floating_text_requested.connect(func(t, c, tgt): floating_text_requested.emit(t, c, tgt))
	PlayerState.game_over_requested.connect(func(): game_over.emit())
	TurnManager.phase_changed.connect(func(p): phase_changed.emit(p))
	TurnManager.turn_started.connect(func(): turn_started.emit())
	TurnManager.enemy_turn_started.connect(func(): enemy_turn_started.emit())
	TurnManager.floating_text_requested.connect(func(t, c, tgt): floating_text_requested.emit(t, c, tgt))
	DiceBag.dice_updated.connect(func(): dice_updated.emit())
	DiceBag.toast_requested.connect(func(m, tp): toast_requested.emit(m, tp))

# ============================================================
# 生命周期管理（委托各子模块）
# ============================================================

## 按职业初始化游戏状态
func start_run(class_id: String) -> void:
	var class_def := ClassDef.get_all()[class_id] as ClassDef
	if not class_def:
		push_error("Invalid class: %s" % class_id)
		return
	
	# 委托 PlayerState
	PlayerState.player_class = class_id
	PlayerState.hp = class_def.hp
	PlayerState.max_hp = class_def.max_hp
	PlayerState.armor = 0
	PlayerState.gold = 0
	PlayerState.souls = 0
	PlayerState.statuses = []
	PlayerState.relics = []
	
	# 职业专属属性
	PlayerState.blood_reroll_count = 0
	PlayerState.can_blood_reroll = class_def.can_blood_reroll
	PlayerState.charge_stacks = 0
	PlayerState.mage_overcharge_mult = 0.0
	PlayerState.combo_count = 0
	PlayerState.locked_element = ""
	PlayerState.last_play_hand_type = ""
	PlayerState.warrior_rage_mult = 0.0
	PlayerState.hp_lost_this_turn = 0
	PlayerState.hp_lost_this_battle = 0
	PlayerState.rage_fire_bonus = 0
	PlayerState.fury_bonus_damage = 0
	PlayerState.warrior_rage_mult_val = 0.0
	PlayerState.rogue_combo_draw_bonus = 0
	PlayerState.relic_temp_draw_bonus = 0
	PlayerState.relic_keep_highest = 0
	PlayerState.relic_temp_extra_play = 0
	PlayerState.fortune_wheel_used = false
	PlayerState.temp_draw_count_bonus = 0
	
	# 委托 DiceBag
	DiceBag.owned_dice.clear()
	for dice_id in class_def.initial_dice:
		DiceBag.owned_dice.append({"defId": dice_id, "level": 1})
	var initial_dice_copy: Array[String] = class_def.initial_dice.duplicate()
	DiceBag.dice_bag = DiceBagService.shuffle(initial_dice_copy)
	DiceBag.discard_pile = []
	DiceBag.hand_dice = []
	DiceBag.draw_count = class_def.draw_count
	
	# 委托 TurnManager
	TurnManager.plays_left = class_def.max_plays
	TurnManager.max_plays = class_def.max_plays
	TurnManager.free_rerolls_per_turn = class_def.free_rerolls
	TurnManager.free_rerolls_left = class_def.free_rerolls
	TurnManager.battle_turn = 0
	TurnManager.is_enemy_turn = false
	TurnManager.phase = GameTypes.GamePhase.START
	
	# 委托 PlayerState 地图
	PlayerState.chapter = 1
	PlayerState.current_node = -1
	PlayerState.map_nodes = []
	PlayerState.pending_wave = []
	
	# 章节倍率 / 牌型升级重置
	PlayerState.enemy_hp_multiplier = 1.0
	PlayerState.hand_type_upgrades = {}
	
	# 委托 StatsTracker
	StatsTracker.reset_stats()
	
	# 发射初始信号（仅数据信号，不触发场景切换）
	hp_changed.emit(PlayerState.hp, PlayerState.max_hp)
	armor_changed.emit(PlayerState.armor)
	gold_changed.emit(PlayerState.gold)


## 切换游戏阶段
func set_phase(new_phase: GameTypes.GamePhase) -> void:
	TurnManager.phase = new_phase
	phase_changed.emit(new_phase)


# ============================================================
# 便捷访问器（保持向后兼容）
# ============================================================

## HP / 护甲 / 金币
var hp: int:
	get: return PlayerState.hp
	set(v): PlayerState.hp = v

var max_hp: int:
	get: return PlayerState.max_hp

var armor: int:
	get: return PlayerState.armor
	set(v): PlayerState.armor = v

var gold: int:
	get: return PlayerState.gold
	set(v): PlayerState.gold = v

var souls: int:
	get: return PlayerState.souls
	set(v): PlayerState.souls = v

var player_class: String:
	get: return PlayerState.player_class

var phase: GameTypes.GamePhase:
	get: return TurnManager.phase


## 回合相关
var plays_left: int:
	get: return TurnManager.plays_left
	set(v): TurnManager.plays_left = v

var max_plays: int:
	get: return TurnManager.max_plays

var free_rerolls_left: int:
	get: return TurnManager.free_rerolls_left
	set(v): TurnManager.free_rerolls_left = v

var free_rerolls_per_turn: int:
	get: return TurnManager.free_rerolls_per_turn
	set(v): TurnManager.free_rerolls_per_turn = v

var battle_turn: int:
	get: return TurnManager.battle_turn
	set(v): TurnManager.battle_turn = v

var is_enemy_turn: bool:
	get: return TurnManager.is_enemy_turn
	set(v): TurnManager.is_enemy_turn = v


## 骰子相关
var owned_dice: Array[Dictionary]:
	get: return DiceBag.owned_dice

var dice_bag: Array[String]:
	get: return DiceBag.dice_bag
	set(v): DiceBag.dice_bag = v

var discard_pile: Array[String]:
	get: return DiceBag.discard_pile
	set(v): DiceBag.discard_pile = v

var hand_dice: Array[Dictionary]:
	get: return DiceBag.hand_dice
	set(v): DiceBag.hand_dice = v

var draw_count: int:
	get: return DiceBag.draw_count
	set(v): DiceBag.draw_count = v


## 状态效果
var statuses: Array[StatusEffect]:
	get: return PlayerState.statuses


## 地图相关
var chapter: int:
	get: return PlayerState.chapter
	set(v): PlayerState.chapter = v

var current_node: int:
	get: return PlayerState.current_node
	set(v): PlayerState.current_node = v

var map_nodes: Array:  # [RULES-B2-EXEMPT] MapGenerator 无 class_name，autoload 无法引用内部类
	get: return PlayerState.map_nodes
	set(v): PlayerState.map_nodes = v

var pending_wave: Array[String]:
	get: return PlayerState.pending_wave
	set(v): PlayerState.pending_wave = v


## 遗物
var relics: Array[Dictionary]:
	get: return PlayerState.relics

## 统计
var stats: Dictionary:
	get: return StatsTracker.stats


## 职业专属
var blood_reroll_count: int:
	get: return PlayerState.blood_reroll_count
	set(v): PlayerState.blood_reroll_count = v

var can_blood_reroll: bool:
	get: return PlayerState.can_blood_reroll

var charge_stacks: int:
	get: return PlayerState.charge_stacks
	set(v): PlayerState.charge_stacks = v

var mage_overcharge_mult: float:
	get: return PlayerState.mage_overcharge_mult
	set(v): PlayerState.mage_overcharge_mult = v

var combo_count: int:
	get: return PlayerState.combo_count
	set(v): PlayerState.combo_count = v

var locked_element: String:
	get: return PlayerState.locked_element
	set(v): PlayerState.locked_element = v

var last_play_hand_type: String:
	get: return PlayerState.last_play_hand_type
	set(v): PlayerState.last_play_hand_type = v

var warrior_rage_mult: float:
	get: return PlayerState.warrior_rage_mult
	set(v): PlayerState.warrior_rage_mult = v


## 战斗临时
var hp_lost_this_turn: int:
	get: return PlayerState.hp_lost_this_turn
	set(v): PlayerState.hp_lost_this_turn = v

var hp_lost_this_battle: int:
	get: return PlayerState.hp_lost_this_battle
	set(v): PlayerState.hp_lost_this_battle = v

var rage_fire_bonus: int:
	get: return PlayerState.rage_fire_bonus
	set(v): PlayerState.rage_fire_bonus = v

var fury_bonus_damage: int:
	get: return PlayerState.fury_bonus_damage
	set(v): PlayerState.fury_bonus_damage = v

var warrior_rage_mult_val: float:
	get: return PlayerState.warrior_rage_mult_val
	set(v): PlayerState.warrior_rage_mult_val = v

var rogue_combo_draw_bonus: int:
	get: return PlayerState.rogue_combo_draw_bonus
	set(v): PlayerState.rogue_combo_draw_bonus = v

var relic_temp_draw_bonus: int:
	get: return PlayerState.relic_temp_draw_bonus
	set(v): PlayerState.relic_temp_draw_bonus = v

var relic_keep_highest: int:
	get: return PlayerState.relic_keep_highest
	set(v): PlayerState.relic_keep_highest = v

var relic_temp_extra_play: int:
	get: return PlayerState.relic_temp_extra_play
	set(v): PlayerState.relic_temp_extra_play = v

var fortune_wheel_used: bool:
	get: return PlayerState.fortune_wheel_used
	set(v): PlayerState.fortune_wheel_used = v

var temp_draw_count_bonus: int:
	get: return PlayerState.temp_draw_count_bonus
	set(v): PlayerState.temp_draw_count_bonus = v


## 敌人/战斗
var target_enemy_uid: String:
	get: return PlayerState.target_enemy_uid
	set(v): PlayerState.target_enemy_uid = v

## 嘲讽目标：Guardian 上盾后设置，玩家在嘲讽期间不能切换目标，出牌强制打它
var taunt_enemy_uid: String = ""

## 当前战场敌人 snapshot（Priest AI 查同伴用，避免循环依赖 BattleController）
var current_enemies: Array[EnemyInstance] = []

var battle_waves: Array[Dictionary]:
	get: return PlayerState.battle_waves
	set(v): PlayerState.battle_waves = v

var current_wave_index: int:
	get: return PlayerState.current_wave_index
	set(v): PlayerState.current_wave_index = v

var enemy_hp_multiplier: float:
	get: return PlayerState.enemy_hp_multiplier
	set(v): PlayerState.enemy_hp_multiplier = v


# ============================================================
# 委托方法（保持外部调用接口不变）
# ============================================================

## 骰子库操作
func draw_from_bag(count: int) -> Dictionary:
	return DiceBag.draw_from_bag(count)

func reroll_die(die: Dictionary) -> int:
	return DiceBag.reroll_die(die)

func discard_hand_dice(dice_ids: Array[String]) -> void:
	DiceBag.discard_hand_dice(dice_ids)

func init_dice_bag() -> void:
	DiceBag.init_dice_bag()


## 回合管理
func start_turn() -> void:
	TurnManager.start_turn()

func after_play() -> void:
	TurnManager.after_play()

func consume_play() -> void:
	TurnManager.consume_play()

func end_player_turn() -> void:
	TurnManager.end_player_turn()

func execute_draw_phase() -> void:
	TurnManager.execute_draw_phase()


## 伤害/治疗（委托 PlayerState）
func take_damage(dmg: int) -> void:
	PlayerState.take_damage(dmg)

func heal(amount: int) -> void:
	PlayerState.heal(amount)

func gain_armor(amount: int) -> void:
	PlayerState.gain_armor(amount)

func add_gold(amount: int) -> void:
	PlayerState.add_gold(amount)

func spend_gold(amount: int) -> bool:
	return PlayerState.spend_gold(amount)

func modify_max_hp(delta: int) -> void:
	PlayerState.modify_max_hp(delta)

func upgrade_hand_type() -> void:
	# 升级"玩家最近一次出的牌型"；无则升级一个"简单、易触发"的牌型（从低优先级到高优先级兜底）
	var target: String = PlayerState.last_play_hand_type
	# 兜底升级顺序：从最常见牌型到最稀有牌型
	const FALLBACK_ORDER: Array[String] = [
		"对子", "连对", "三条", "顺子", "三连对", "4顺", "葫芦", "同元素",
		"5顺", "四条", "6顺", "五条", "元素顺", "元素葫芦", "六条", "皇家元素顺"
	]
	if target == "" or target == "普通攻击":
		# 找玩家还没升过级的第一个（从简单到稀有）牌型
		target = ""
		for hand_name in FALLBACK_ORDER:
			if not PlayerState.hand_type_upgrades.has(hand_name):
				target = hand_name
				break
		if target == "":
			target = "对子"  # 全都升过级则继续堆"对子"
	var cur_level: int = int(PlayerState.hand_type_upgrades.get(target, 0))
	PlayerState.hand_type_upgrades[target] = cur_level + 1
	toast_requested.emit("「%s」升级到 Lv.%d" % [target, cur_level + 1], "buff")


## 章节推进：打完 15 层最终 Boss 后调用
## 返回 true 表示进入下一章，false 表示已通关全部章节
func advance_chapter() -> bool:
	var next_chapter: int = PlayerState.chapter + 1
	var total: int = int(GameBalance.CHAPTER_CONFIG.get("totalChapters", 5))
	if next_chapter > total:
		return false  # 通关全游戏
	
	# 推进章节
	PlayerState.chapter = next_chapter
	
	# 敌人血量倍率按 chapterScaling 配置更新
	var scaling_list: Array = GameBalance.CHAPTER_CONFIG.get("chapterScaling", [])  # [RULES-B2-EXEMPT] dict.get 返回裸 Array
	if next_chapter - 1 < scaling_list.size():
		var scaling: Dictionary = scaling_list[next_chapter - 1]
		PlayerState.enemy_hp_multiplier = float(scaling.get("hpMult", 1.0))
	
	# 章节奖励：回血 + 金币
	var heal_percent: float = float(GameBalance.CHAPTER_CONFIG.get("chapterHealPercent", 0.6))
	var heal_amount: int = int(PlayerState.max_hp * heal_percent)
	PlayerState.heal(heal_amount)
	var bonus_gold: int = int(GameBalance.CHAPTER_CONFIG.get("chapterBonusGold", 75))
	PlayerState.add_gold(bonus_gold)
	
	# 清空当前章节地图，下一章进入地图时自动重新生成
	PlayerState.map_nodes = []
	PlayerState.current_node = -1
	PlayerState.pending_wave = []
	
	toast_requested.emit("进入第 %d 章：%s" % [next_chapter, GameBalance.CHAPTER_CONFIG.chapterNames[next_chapter - 1]], "buff")
	return true


## 状态效果
func add_status(type: GameTypes.StatusType, value: int, duration: int) -> void:
	PlayerState.add_status(type, value, duration)

func has_status(type: GameTypes.StatusType) -> bool:
	return PlayerState.has_status(type)

func get_status_value(type: GameTypes.StatusType) -> int:
	return PlayerState.get_status_value(type)

func tick_statuses() -> void:
	PlayerState.tick_statuses()


## 统计
func _reset_stats() -> void:
	StatsTracker.reset_stats()

func record_damage(dmg: int, is_single_hit: bool = false) -> void:
	StatsTracker.record_damage(dmg, is_single_hit)


## 本回合已用的重投次数（免费 + 卖血）
## free_rerolls_left 可被连击预备等机制增量（> per_turn），需 maxi 防负
var rerolls_this_turn: int:
	get: return maxi(0, TurnManager.free_rerolls_per_turn - TurnManager.free_rerolls_left) + PlayerState.blood_reroll_count


# ============================================================
# 骰子效果查询接口（dice_effect_mage / dice_effect_rogue 使用）
# ============================================================

## 获取指定骰子的蓄力层数
## 新版设计：蓄力为全局回合级层数，不按骰子 id 区分
## 参数 dice_id 保留接口一致性，当前实现返回全局 charge_stacks
func get_charge_count(_dice_id: String = "") -> int:
	return PlayerState.charge_stacks


## 获取玩家身上负面状态数量（净化回血等骰子使用）
func get_debuff_count() -> int:
	var count: int = 0
	const DEBUFF_TYPES: Array[int] = [
		GameTypes.StatusType.POISON,
		GameTypes.StatusType.BURN,
		GameTypes.StatusType.FREEZE,
		GameTypes.StatusType.WEAK,
		GameTypes.StatusType.VULNERABLE,
		GameTypes.StatusType.SLOW,
	]
	for s: StatusEffect in PlayerState.statuses:
		if s.type in DEBUFF_TYPES:
			count += 1
	return count


## 获取当前手牌中出现的所有元素（去重）
func get_hand_elements() -> Array[int]:
	var seen: Dictionary = {}
	for d: Dictionary in DiceBag.hand_dice:
		var def_id: String = d.get("defId", "")
		if def_id == "":
			continue
		var def: DiceDef = GameData.get_dice_def(def_id)
		if def == null:
			continue
		seen[def.element] = true
	var result: Array[int] = []
	for k in seen.keys():
		result.append(int(k))
	return result
