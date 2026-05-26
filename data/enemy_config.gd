## 敌人配置资源 — 类定义 + 查询接口
## 数据源：config/json/enemy.json（由 Excel 工具链生成）
## 运行时由 ConfigLoader.load_enemy_configs() 注入 _all_configs

class_name EnemyConfig
extends Resource

enum EnemyCategory { NORMAL, ELITE, BOSS }
enum BossRank { NONE, MID, FINAL }

@export var id: String = ""
@export var name: String = ""
@export var chapter: int = 1
@export var base_hp: int = 30
@export var base_dmg: int = 5
@export var category: EnemyCategory = EnemyCategory.NORMAL
@export var combat_type: GameTypes.EnemyCombatType = GameTypes.EnemyCombatType.WARRIOR
@export var drop_gold: int = 20
@export var drop_relic: bool = false
@export var drop_reroll_reward: int = 0
@export var phases: Array[EnemyPhase] = []
@export var quotes: EnemyQuotes = null
@export var boss_rank: BossRank = BossRank.NONE
@export var summons: EnemySummon = null
@export var revive: EnemyRevive = null
## 美术资源 id，对应 spritesheet 中的格子位置（由 EnemyArtMapping 映射）
## 留空则用占位方块。详见 EnemyArtMapping.gd
@export var art_id: String = ""

## ============================================================
## 敌人阶段
## ============================================================

class EnemyPhase:
	extends Resource
	@export var hp_threshold: float = 0.0
	@export var actions: Array[EnemyAction] = []

## ============================================================
## 敌人行动
## ============================================================

class EnemyAction:
	extends Resource
	enum ActionType { ATTACK, DEFEND, SKILL }
	@export var type: ActionType = ActionType.ATTACK
	@export var base_value: int = 0
	@export var description: String = ""
	@export var scalable: bool = true
	@export var curse_dice: String = ""
	@export var curse_dice_count: int = 0
	@export var effects: Array[Dictionary] = []

## ============================================================
## 敌人台词
## ============================================================

class EnemyQuotes:
	extends Resource
	@export var enter: Array[String] = []
	@export var death: Array[String] = []
	@export var attack: Array[String] = []
	@export var hurt: Array[String] = []
	@export var low_hp: Array[String] = []
	@export var greet: Array[String] = []
	@export var dispatch: Array[String] = []
	@export var mid_boss_warning: Array[String] = []
	@export var phase2_taunt: Array[String] = []

## ============================================================
## Boss 召唤机制
## ============================================================

class EnemySummon:
	extends Resource
	@export var minion_id: String = ""
	@export var interval: int = 3
	@export var count: int = 1
	@export var max_total: int = 4
	@export var wave_cap: int = 4
	@export var hp_threshold: float = 0.0

## ============================================================
## Boss 死亡分裂/复活机制
## ============================================================

class EnemyRevive:
	extends Resource
	@export var revive_hp_ratio: float = 0.5
	@export var split_into: int = 2
	@export var split_minion_id: String = ""

## ============================================================
## 注册表 — 由 ConfigLoader 在 _ready 时注入
## ============================================================

static var _all_configs: Dictionary = {}

static func get_config(id: String) -> EnemyConfig:
	if _all_configs.has(id):
		return _all_configs[id]
	push_warning("EnemyConfig not found: %s" % id)
	return _all_configs.values()[0] if _all_configs.size() > 0 else null

static func get_normals_for_chapter(chapter: int) -> Array[EnemyConfig]:
	var result: Array[EnemyConfig] = []
	for c: EnemyConfig in _all_configs.values():
		if c.category == EnemyCategory.NORMAL and c.chapter == chapter:
			result.append(c)
	return result

static func get_elites_for_chapter(chapter: int) -> Array[EnemyConfig]:
	var result: Array[EnemyConfig] = []
	for c: EnemyConfig in _all_configs.values():
		if c.category == EnemyCategory.ELITE and c.chapter == chapter:
			result.append(c)
	return result

static func get_bosses_for_chapter(chapter: int) -> Array[EnemyConfig]:
	var result: Array[EnemyConfig] = []
	for c: EnemyConfig in _all_configs.values():
		if c.category == EnemyCategory.BOSS and c.chapter == chapter:
			result.append(c)
	return result

static func get_all() -> Dictionary:
	return _all_configs
