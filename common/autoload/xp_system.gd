## XP / 等级系统
## 纯函数 + 全局状态管理。击杀结算时计算经验增益并处理升级。
## 迁移自 React 版 xpSystem.ts

extends Node

# ============================================================
# 信号
# ============================================================

signal xp_gained(amount: int, new_xp: int, xp_to_next: int)
signal level_up(new_level: int)

# ============================================================
# 状态
# ============================================================

var level: int = 1
var xp: int = 0
var xp_to_next: int = 30

## 升级待领取队列（每个元素是升级后的等级数）
var pending_level_ups: Array[int] = []

## 升级永久加成
var level_max_hp_bonus: int = 0
var level_turn_start_armor: int = 0
var level_map_heal: int = 0
var level_damage_bonus: int = 0
var level_damage_mult_bonus: float = 0.0
var level_pierce_bonus: int = 0
var level_gold_bonus: float = 0.0
var level_soul_bonus: float = 0.0
var level_xp_bonus: float = 0.0

# ============================================================
# 常量
# ============================================================

const MAX_LEVEL: int = 20

# ============================================================
# 经验阈值表
# ============================================================

## 升到下一级所需 XP
## Lv1→30, Lv2→50, Lv3→75, Lv4→110, Lv5→155, Lv6→210, Lv7→275, Lv8+ 每级+90
static func next_level_threshold(next_level: int) -> int:
	var table: Array[int] = [0, 30, 50, 75, 110, 155, 210, 275]
	if next_level < table.size():
		return table[next_level]
	return 275 + (next_level - 7) * 90


# ============================================================
# 击杀经验
# ============================================================

## 按节点类型给出单次击杀 XP 随机区间 [min, max]
static func get_kill_xp_range(node_type: String) -> Vector2i:
	match node_type:
		"elite": return Vector2i(25, 45)
		"boss": return Vector2i(70, 110)
		_: return Vector2i(6, 14)


## 随机区间内取整数 XP
static func roll_kill_xp(node_type: String) -> int:
	var r: Vector2i = get_kill_xp_range(node_type)
	return r.x + randi() % (r.y - r.x + 1)


# ============================================================
# 应用经验增益
# ============================================================

func apply_xp_gain(gain: int) -> void:
	# 应用 XP 加成
	var actual_gain: int = int(gain * (1.0 + level_xp_bonus))
	xp += actual_gain
	
	var levels_gained: Array[int] = []
	while xp >= xp_to_next and level < MAX_LEVEL:
		xp -= xp_to_next
		level += 1
		levels_gained.append(level)
		xp_to_next = next_level_threshold(level + 1)
	
	# 封顶后经验归零
	if level >= MAX_LEVEL:
		xp = 0
		xp_to_next = 0
	
	xp_gained.emit(actual_gain, xp, xp_to_next)
	
	for lv: int in levels_gained:
		pending_level_ups.append(lv)
		level_up.emit(lv)


# ============================================================
# 升级三选一奖励
# ============================================================

enum RewardCategory { SURVIVAL, OFFENSE, RESOURCE }

## 奖励定义
class LevelReward:
	var id: String
	var category: RewardCategory
	var title: String
	var description: String
	## 返回要 patch 的字段名和增量值
	var apply_fn: Callable
	
	func _init(p_id: String, p_cat: RewardCategory, p_title: String, p_desc: String, p_fn: Callable) -> void:
		id = p_id
		category = p_cat
		title = p_title
		description = p_desc
		apply_fn = p_fn


## 奖励池
func _get_reward_pool() -> Array[LevelReward]:
	return [
		# 生存
		LevelReward.new("survival_hp", RewardCategory.SURVIVAL, "血之韧性",
			"最大生命 +8（永久叠加）",
			func(): _apply_survival_hp()),
		LevelReward.new("survival_armor_start", RewardCategory.SURVIVAL, "壁垒之心",
			"每回合开始时获得 +2 护甲（永久叠加）",
			func(): _apply_survival_armor()),
		LevelReward.new("survival_regen", RewardCategory.SURVIVAL, "生息印记",
			"每层地图结束后回复 +4 HP（永久叠加）",
			func(): _apply_survival_regen()),
		# 攻击
		LevelReward.new("offense_damage", RewardCategory.OFFENSE, "利刃精通",
			"每次出牌的基础伤害 +2（永久叠加）",
			func(): _apply_offense_damage()),
		LevelReward.new("offense_mult", RewardCategory.OFFENSE, "战意共鸣",
			"所有出牌伤害 +8%（永久叠加）",
			func(): _apply_offense_mult()),
		LevelReward.new("offense_pierce", RewardCategory.OFFENSE, "破甲之怒",
			"每次出牌附加 +1 穿透伤害（永久叠加）",
			func(): _apply_offense_pierce()),
		# 资源
		LevelReward.new("resource_gold", RewardCategory.RESOURCE, "贪婪之眼",
			"金币收益 +15%（永久叠加）",
			func(): _apply_resource_gold()),
		LevelReward.new("resource_soul", RewardCategory.RESOURCE, "魂晶共振",
			"魂晶倍率 +10%（永久叠加）",
			func(): _apply_resource_soul()),
		LevelReward.new("resource_xp", RewardCategory.RESOURCE, "智慧印记",
			"获得经验值 +15%（永久叠加）",
			func(): _apply_resource_xp()),
	]


## 取出三类奖励（每类随机抽一张 = 3 选 1）
func get_level_up_choices() -> Array[LevelReward]:
	var pool: Array[LevelReward] = _get_reward_pool()
	var result: Array[LevelReward] = []
	for cat: RewardCategory in [RewardCategory.SURVIVAL, RewardCategory.OFFENSE, RewardCategory.RESOURCE]:
		var candidates: Array[LevelReward] = []
		for r: LevelReward in pool:
			if r.category == cat:
				candidates.append(r)
		if not candidates.is_empty():
			result.append(candidates[randi() % candidates.size()])
	return result


## 消费一个待领取升级
func consume_level_up() -> void:
	if not pending_level_ups.is_empty():
		pending_level_ups.pop_front()


## 是否有待领取升级
func has_pending_level_up() -> bool:
	return not pending_level_ups.is_empty()


# ============================================================
# 奖励应用（内部）
# ============================================================

func _apply_survival_hp() -> void:
	level_max_hp_bonus += 8
	PlayerState.modify_max_hp(8)

func _apply_survival_armor() -> void:
	level_turn_start_armor += 2

func _apply_survival_regen() -> void:
	level_map_heal += 4

func _apply_offense_damage() -> void:
	level_damage_bonus += 2

func _apply_offense_mult() -> void:
	level_damage_mult_bonus += 0.08

func _apply_offense_pierce() -> void:
	level_pierce_bonus += 1

func _apply_resource_gold() -> void:
	level_gold_bonus += 0.15

func _apply_resource_soul() -> void:
	level_soul_bonus += 0.10

func _apply_resource_xp() -> void:
	level_xp_bonus += 0.15


# ============================================================
# 重置（新局开始时调用）
# ============================================================

func reset() -> void:
	level = 1
	xp = 0
	xp_to_next = next_level_threshold(2)
	pending_level_ups.clear()
	level_max_hp_bonus = 0
	level_turn_start_armor = 0
	level_map_heal = 0
	level_damage_bonus = 0
	level_damage_mult_bonus = 0.0
	level_pierce_bonus = 0
	level_gold_bonus = 0.0
	level_soul_bonus = 0.0
	level_xp_bonus = 0.0


# ============================================================
# 分类元数据
# ============================================================

static func get_category_label(cat: RewardCategory) -> String:
	match cat:
		RewardCategory.SURVIVAL: return "生存"
		RewardCategory.OFFENSE: return "攻击"
		RewardCategory.RESOURCE: return "资源"
		_: return "?"

static func get_category_color(cat: RewardCategory) -> Color:
	match cat:
		RewardCategory.SURVIVAL: return Color("#e03c3c")
		RewardCategory.OFFENSE: return Color("#d4a030")
		RewardCategory.RESOURCE: return Color("#9060d0")
		_: return Color.WHITE
