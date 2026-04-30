## 玩家状态单例 — 管理 HP / 护甲 / 金币 / 灵魂 / 职业专属属性 / 状态效果
## 从 game_manager.gd 拆分（GODOT-AUTOLOAD-SPLIT）

extends Node

signal hp_changed(new_hp: int, max_hp: int)
signal armor_changed(new_armor: int)
signal gold_changed(new_gold: int)
signal floating_text_requested(text: String, color: Color, target: String)
signal game_over_requested

# ============================================================
# 玩家核心属性
# ============================================================

var hp: int = 100
var max_hp: int = 100
var armor: int = 0
var gold: int = 0
var souls: int = 0
var player_class: String = ""  ## warrior / mage / rogue

# 职业专属
var blood_reroll_count: int = 0       ## 战士卖血次数
var can_blood_reroll: bool = false     ## 是否有卖血资格
var charge_stacks: int = 0            ## 法师蓄力层
var mage_overcharge_mult: float = 0.0 ## 法师过充倍率
var combo_count: int = 0              ## 盗贼连击数
var locked_element: String = ""       ## 棱镜锁定元素
var last_play_hand_type: String = ""   ## 盗贼上次出牌牌型
var warrior_rage_mult: float = 0.0    ## 战士狂暴倍率

# 状态效果
var statuses: Array[StatusEffect] = []

# 战斗内临时变量
var hp_lost_this_turn: int = 0
var hp_lost_this_battle: int = 0
var rage_fire_bonus: int = 0
var fury_bonus_damage: int = 0
## §9.1 怒火骰累计伤害上限（对齐 game-knowledge.md「最多+10」）
const FURY_BONUS_CAP: int = 10
var warrior_rage_mult_val: float = 0.0
var rogue_combo_draw_bonus: int = 0
var relic_temp_draw_bonus: int = 0
var relic_keep_highest: int = 0
var relic_temp_extra_play: int = 0
## 连续普攻计数（影响盗贼连击链/部分遗物触发）— 对应原版 consecutiveNormalAttacks
## 在 endTurn 后 reset 0（参见 Godot 设计规范 §4.4）
var consecutive_normal_attacks: int = 0
## 黑市遗物本回合是否已用 — 对应原版 blackMarketUsedThisTurn
## 在敌人回合入口 reset false（参见 Godot 设计规范 §4.5）
var black_market_used_this_turn: bool = false
## §6.3 每敌出牌次数 Dictionary[enemy_uid(String) -> count(int)]
## 对齐原版 playsPerEnemy，为 per-enemy 遗物触发（如"同敌第 N 击额外伤害"类）保留数据入口
## 战斗结束时由 TurnManager 统一清空
var plays_per_enemy: Dictionary = {}
var fortune_wheel_used: bool = false
var temp_draw_count_bonus: int = 0

# 敌人/战斗相关
var target_enemy_uid: String = ""
var battle_waves: Array[Dictionary] = []
var current_wave_index: int = 0
var enemy_hp_multiplier: float = 1.0

# 地图
var chapter: int = 1
var current_node: int = -1
var map_nodes: Array[MapGenerator.MapNode] = []

# 地图 → 战斗 数据桥
var pending_wave: Array[String] = []

# 遗物
var relics: Array[Dictionary] = []

# 骰子
var dice_bag: Array[String] = []  ## 骰子 ID 列表
var dice_levels: Dictionary = {}  ## dice_id → level

# 牌型升级：{handType: upgrade_level}，每级 base + 15, mult + 0.1
var hand_type_upgrades: Dictionary = {}


# ============================================================
# HP / 护甲 / 金币 / 灵魂
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
	
	# §9.1 / §9.4 怒火骰：每次受攻击（不论是否真实掉血）按 w_fury 持有数累加 fury_bonus_damage，上限 +10
	# 对齐 React 原版 enemyAI.ts L355：furyBonusDamage += furyLevel
	_accumulate_fury_on_hit()
	
	if hp <= 0:
		game_over_requested.emit()


## §9.1 怒火骰触发：统计手牌 + 骰包 + 弃牌库 中的 w_fury 数量作为 furyLevel
## 上限 FURY_BONUS_CAP = 10（对齐 game-knowledge.md「最多+10」）
func _accumulate_fury_on_hit() -> void:
	if fury_bonus_damage >= FURY_BONUS_CAP:
		return
	var fury_level: int = _count_fury_dice()
	if fury_level <= 0:
		return
	fury_bonus_damage = mini(FURY_BONUS_CAP, fury_bonus_damage + fury_level)


## 统计玩家持有的怒火骰数量（owned_dice 已覆盖 bag/hand/discard/spent 所有形态）
static func _count_fury_dice() -> int:
	var count: int = 0
	for d: Dictionary in DiceBag.owned_dice:
		if d.get("defId", "") == "w_fury":
			count += 1
	return count


func heal(amount: int) -> void:
	var old_hp := hp
	hp = mini(max_hp, hp + amount)
	var healed := hp - old_hp
	if healed > 0:
		StatsTracker.record_healing(healed)
		floating_text_requested.emit("+%d" % healed, Color.GREEN, "player")
		hp_changed.emit(hp, max_hp)


func gain_armor(amount: int) -> void:
	armor += amount
	StatsTracker.record_armor_gained(amount)
	armor_changed.emit(armor)


func add_gold(amount: int) -> void:
	gold += amount
	StatsTracker.record_gold_earned(amount)
	gold_changed.emit(gold)


func modify_max_hp(delta: int) -> void:
	max_hp = maxi(1, max_hp + delta)
	hp = mini(hp, max_hp)
	hp_changed.emit(hp, max_hp)
	if delta > 0:
		floating_text_requested.emit("+%d 最大HP" % delta, Color.GREEN, "player")
	elif delta < 0:
		floating_text_requested.emit("%d 最大HP" % delta, Color.RED, "player")


func spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	StatsTracker.record_gold_spent(amount)
	gold_changed.emit(gold)
	return true


# ============================================================
# 状态效果（thin wrapper → StatusService）
# ============================================================

func add_status(type: GameTypes.StatusType, value: int, duration: int) -> void:
	StatusService.add(statuses, type, value, duration)


func has_status(type: GameTypes.StatusType) -> bool:
	return StatusService.has(statuses, type)


func get_status_value(type: GameTypes.StatusType) -> int:
	return StatusService.get_value(statuses, type)


func tick_statuses() -> void:
	StatusService.tick(statuses)
