## 游戏管理器 — 核心状态单例，对应原版 GameState + GameContext
## 管理整个游戏生命周期、战斗状态、骰子库、遗物等

extends Node

signal hp_changed(new_hp: int, max_hp: int)
signal armor_changed(new_armor: int)
signal gold_changed(new_gold: int)
signal phase_changed(new_phase: GameTypes.GamePhase)
signal turn_started
signal enemy_turn_started
signal battle_ended(victory: bool)
signal game_over
signal floating_text_requested(text: String, color: Color, target: String)
signal toast_requested(msg: String, type: String)
signal screen_shake_requested
signal dice_updated

# ============================================================
# 玩家状态
# ============================================================

var hp: int = 100
var max_hp: int = 100
var armor: int = 0
var gold: int = 0
var souls: int = 0
var player_class: String = ""  ## warrior / mage / rogue
var phase: GameTypes.GamePhase = GameTypes.GamePhase.START

# 回合规则
var free_rerolls_left: int = 1
var free_rerolls_per_turn: int = 1
var plays_left: int = 1
var max_plays: int = 1
var draw_count: int = 3
var battle_turn: int = 0
var is_enemy_turn: bool = false

# 职业专属
var blood_reroll_count: int = 0       ## 战士卖血次数
var charge_stacks: int = 0            ## 法师蓄力层
var mage_overcharge_mult: float = 0.0 ## 法师过充倍率
var combo_count: int = 0              ## 盗贼连击数
var locked_element: String = ""       ## 棱镜锁定元素
var last_play_hand_type: String = ""   ## 盗贼上次出牌牌型
var warrior_rage_mult: float = 0.0    ## 战士狂暴倍率

# 骰子库系统
var owned_dice: Array[Dictionary] = []   ## [{defId, level}]
var dice_bag: Array[String] = []         ## 骰子库（待抽）
var discard_pile: Array[String] = []     ## 弃骰库

# 手牌
var hand_dice: Array[Dictionary] = []    ## [{id, defId, value, element, selected, spent, rolling, ...}]

# 战斗
var target_enemy_uid: String = ""
var battle_waves: Array = []  ## [{enemies: [EnemyInstance]}]
var current_wave_index: int = 0
var enemy_hp_multiplier: float = 1.0

# 地图
var chapter: int = 1
var current_node: int = -1
var map_nodes: Array = []

# 状态效果
var statuses: Array[StatusEffect] = []

# 遗物
var relics: Array[Dictionary] = []

# 战斗内临时变量
var hp_lost_this_turn: int = 0
var hp_lost_this_battle: int = 0
var rage_fire_bonus: int = 0
var fury_bonus_damage: int = 0
var warrior_rage_mult_val: float = 0.0
var rogue_combo_draw_bonus: int = 0
var relic_temp_draw_bonus: int = 0
var relic_keep_highest: int = 0
var relic_temp_extra_play: int = 0
var fortune_wheel_used: bool = false
var temp_draw_count_bonus: int = 0

# 统计
var stats: Dictionary = {
	"totalDamageDealt": 0, "maxSingleHit": 0, "totalPlays": 0,
	"totalRerolls": 0, "totalDamageTaken": 0, "totalHealing": 0,
	"totalArmorGained": 0, "battlesWon": 0, "elitesWon": 0,
	"bossesWon": 0, "enemiesKilled": 0, "goldEarned": 0, "goldSpent": 0,
}


# ============================================================
# 初始化
# ============================================================

func _ready() -> void:
	pass


## 按职业初始化游戏状态
func start_run(class_id: String) -> void:
	var class_def := ClassDef.get_all()[class_id] as ClassDef
	if not class_def:
		push_error("Invalid class: %s" % class_id)
		return
	
	player_class = class_id
	hp = class_def.hp
	max_hp = class_def.max_hp
	armor = 0
	gold = 0
	souls = 0
	draw_count = class_def.draw_count
	max_plays = class_def.max_plays
	plays_left = max_plays
	free_rerolls_per_turn = class_def.free_rerolls
	free_rerolls_left = free_rerolls_per_turn
	blood_reroll_count = 0
	charge_stacks = 0
	mage_overcharge_mult = 0.0
	combo_count = 0
	battle_turn = 0
	is_enemy_turn = false
	statuses = []
	relics = []
	hand_dice = []
	
	# 初始化骰子库
	owned_dice = class_def.initial_dice.map(func(id): return {"defId": id, "level": 1})
	dice_bag = _shuffle(class_def.initial_dice.duplicate())
	discard_pile = []
	
	# 初始化地图
	chapter = 1
	current_node = -1
	
	# 重置统计
	_reset_stats()
	
	# 切换到地图阶段
	set_phase(GameTypes.GamePhase.MAP)
	
	hp_changed.emit(hp, max_hp)
	armor_changed.emit(armor)
	gold_changed.emit(gold)


func set_phase(new_phase: GameTypes.GamePhase) -> void:
	phase = new_phase
	phase_changed.emit(new_phase)


# ============================================================
# 骰子库操作
# ============================================================

## Fisher-Yates 洗牌
func _shuffle(arr: Array) -> Array:
	var result := arr.duplicate()
	for i in range(result.size() - 1, 0, -1):
		var j = randi() % (i + 1)
		var tmp = result[i]
		result[i] = result[j]
		result[j] = tmp
	return result


## 从骰子库抽取骰子
func draw_from_bag(count: int) -> Dictionary:
	var bag := dice_bag.duplicate()
	var discard := discard_pile.duplicate()
	var shuffled := false
	
	if bag.size() < count:
		bag = bag + _shuffle(discard)
		discard = []
		shuffled = true
	
	var drawn_ids := bag.slice(0, count)
	bag = bag.slice(count)
	
	var drawn: Array[Dictionary] = []
	for def_id in drawn_ids:
		var def: DiceDef = GameData.get_dice_def(def_id)
		var value = _roll_dice_def(def)
		drawn.append({
			"id": randi(), "defId": def_id, "value": value,
			"element": GameTypes.DiceElement.keys()[def.element].to_lower(),
			"selected": false, "spent": false, "rolling": false,
			"kept": false, "isShadowRemnant": false, "isTemp": false,
			"shadowRemnantPersistent": false, "keptBonusAccum": 0,
		})
	
	dice_bag = bag
	discard_pile = discard
	
	if shuffled:
		toast_requested.emit("弃骰库已洗回骰子库!", "buff")
	
	return {"drawn": drawn, "shuffled": shuffled}


## 掷骰子定义
func _roll_dice_def(def: DiceDef) -> int:
	if def.faces.is_empty():
		return 1
	return def.faces[randi() % def.faces.size()]


## 重掷单个骰子
func reroll_die(die: Dictionary) -> int:
	var def: DiceDef = GameData.get_dice_def(die.defId)
	return _roll_dice_def(def)


## 将骰子放入弃骰库
func discard_hand_dice(dice_ids: Array[String]) -> void:
	for id in dice_ids:
		discard_pile.append(id)


## 初始化骰子库
func init_dice_bag() -> void:
	var ids := owned_dice.map(func(d): return d.defId)
	dice_bag = _shuffle(ids)
	discard_pile = []


# ============================================================
# 回合管理
# ============================================================

## 开始新回合
func start_turn() -> void:
	plays_left = max_plays
	free_rerolls_left = free_rerolls_per_turn
	blood_reroll_count = 0
	combo_count = 0
	last_play_hand_type = ""
	hp_lost_this_turn = 0
	
	# 法师蓄力护甲
	if player_class == "mage" and charge_stacks > 0:
		var armor_gain = 6 + charge_stacks * 2
		armor += armor_gain
		armor_changed.emit(armor)
		floating_text_requested.emit("吟唱护甲+%d" % armor_gain, Color.CYAN, "player")
	
	turn_started.emit()


## 出牌后处理
func after_play() -> void:
	plays_left = max(0, plays_left - 1)
	combo_count += 1
	
	# 法师出牌重置蓄力
	if player_class == "mage":
		charge_stacks = 0
		mage_overcharge_mult = 0.0
	
	dice_updated.emit()


## 消耗出牌次数（盗贼连击等）
func consume_play() -> void:
	plays_left = max(0, plays_left - 1)
	combo_count += 1


## 结束回合（玩家点结束回合按钮）
func end_player_turn() -> void:
	# 法师未出牌 → 蓄力
	if player_class == "mage" and plays_left >= max_plays:
		charge_stacks = min(charge_stacks + 1, 3)
	
	# 弃牌处理
	_discard_hand()
	
	# 抽新骰子
	_execute_draw_phase()


## 抽牌阶段
func _execute_draw_phase() -> void:
	var kept_dice: Array[Dictionary] = []
	var discard_ids: Array[String] = []
	
	# 职业差异弃牌逻辑
	if player_class == "mage":
		var played_this_turn = plays_left < max_plays
		if played_this_turn:
			# 出过牌 → 弃掉所有手牌
			for d in hand_dice:
				if not d.spent:
					discard_ids.append(d.defId)
		else:
			# 吟唱 → 保留手牌
			var hand_limit = mini(6, draw_count + charge_stacks)
			kept_dice = hand_dice.filter(func(d): return not d.spent)
			if kept_dice.size() > hand_limit:
				var excess = kept_dice.slice(0, kept_dice.size() - hand_limit)
				for d in excess:
					discard_ids.append(d.defId)
				kept_dice = kept_dice.slice(kept_dice.size() - hand_limit)
	elif player_class == "rogue":
		# 持久暗影残骰保留，临时销毁
		for d in hand_dice:
			if d.spent:
				continue
			if d.get("isShadowRemnant", false) and d.get("shadowRemnantPersistent", false):
				kept_dice.append(d.duplicate())
				kept_dice[-1]["shadowRemnantPersistent"] = false
				kept_dice[-1]["isTemp"] = true
			elif not d.get("isShadowRemnant", false) and not d.get("isTemp", false) and d.defId != "temp_rogue":
				discard_ids.append(d.defId)
	else:
		# 战士/其他：全部弃掉
		for d in hand_dice:
			if not d.spent:
				discard_ids.append(d.defId)
	
	# 放入弃骰库
	discard_hand_dice(discard_ids)
	
	# 计算抽牌数
	var target_hand_size := draw_count
	if player_class == "mage":
		target_hand_size = mini(6, draw_count + charge_stacks)
	if player_class == "warrior" and hp <= max_hp * 0.5:
		target_hand_size += 1
		floating_text_requested.emit("血怒补牌+1", Color.RED, "player")
	
	target_hand_size = mini(6, target_hand_size + temp_draw_count_bonus + rogue_combo_draw_bonus + relic_temp_draw_bonus)
	temp_draw_count_bonus = 0
	rogue_combo_draw_bonus = 0
	relic_temp_draw_bonus = 0
	
	var need_draw = maxi(0, target_hand_size - kept_dice.size())
	
	# 抽牌
	var result := draw_from_bag(need_draw)
	var fresh_dice: Array = result.drawn
	
	# 标记新骰子为 rolling
	for d in fresh_dice:
		d["rolling"] = true
	
	hand_dice = kept_dice + fresh_dice
	dice_updated.emit()


func _discard_hand() -> void:
	# 弃牌逻辑在 _execute_draw_phase 中处理
	pass


# ============================================================
# 伤害/治疗
# ============================================================

func take_damage(dmg: int) -> void:
	var absorbed := mini(armor, dmg)
	armor -= absorbed
	var hp_dmg := dmg - absorbed
	hp = maxi(0, hp - hp_dmg)
	hp_lost_this_turn += hp_dmg
	hp_lost_this_battle += hp_dmg
	
	if absorbed > 0:
		floating_text_requested.emit("-%d" % absorbed, Color.BLUE, "player")
	if hp_dmg > 0:
		floating_text_requested.emit("-%d" % hp_dmg, Color.RED, "player")
	
	hp_changed.emit(hp, max_hp)
	armor_changed.emit(armor)
	
	if hp <= 0:
		game_over.emit()


func heal(amount: int) -> void:
	var old_hp := hp
	hp = mini(max_hp, hp + amount)
	var healed := hp - old_hp
	if healed > 0:
		stats.totalHealing += healed
		floating_text_requested.emit("+%d" % healed, Color.GREEN, "player")
		hp_changed.emit(hp, max_hp)


func gain_armor(amount: int) -> void:
	armor += amount
	stats.totalArmorGained += amount
	armor_changed.emit(armor)


func add_gold(amount: int) -> void:
	gold += amount
	stats.goldEarned += amount
	gold_changed.emit(gold)


func spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	stats.goldSpent += amount
	gold_changed.emit(gold)
	return true


# ============================================================
# 状态效果
# ============================================================

func add_status(type: GameTypes.StatusType, value: int, duration: int) -> void:
	for s in statuses:
		if s.type == type:
			s.value = maxi(s.value, value)
			s.duration = maxi(s.duration, duration)
			return
	var new_status := StatusEffect.new()
	new_status.type = type
	new_status.value = value
	new_status.duration = duration
	statuses.append(new_status)


func has_status(type: GameTypes.StatusType) -> bool:
	return statuses.any(func(s): return s.type == type and s.duration > 0)


func get_status_value(type: GameTypes.StatusType) -> int:
	for s in statuses:
		if s.type == type:
			return s.value
	return 0


func tick_statuses() -> void:
	var to_remove: Array[int] = []
	for i in statuses.size():
		statuses[i].duration -= 1
		if statuses[i].duration <= 0:
			to_remove.append(i)
	for i in range(to_remove.size() - 1, -1, -1):
		statuses.remove_at(to_remove[i])


# ============================================================
# 统计
# ============================================================

func _reset_stats() -> void:
	stats = {
		"totalDamageDealt": 0, "maxSingleHit": 0, "totalPlays": 0,
		"totalRerolls": 0, "totalDamageTaken": 0, "totalHealing": 0,
		"totalArmorGained": 0, "battlesWon": 0, "elitesWon": 0,
		"bossesWon": 0, "enemiesKilled": 0, "goldEarned": 0, "goldSpent": 0,
	}


func record_damage(dmg: int, is_single_hit: bool = false) -> void:
	stats.totalDamageDealt += dmg
	if is_single_hit and dmg > stats.maxSingleHit:
		stats.maxSingleHit = dmg
