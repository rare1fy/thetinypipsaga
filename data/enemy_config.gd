## 敌人配置资源 — 对应原版 config/enemyTypes.ts + config/enemyNormal.ts + config/enemyEliteBoss.ts
## [P0-MIGRATION 2026-05-15] 从原版 dicehero2 迁移全部敌人数据
## 新增: summons/revive 机制、扩展台词(greet/dispatch/midBossWarning/phase2_taunt)
## 数值同步: 已有敌人 baseDmg/baseHp 对齐原版最新调整

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
@export var boss_rank: BossRank = BossRank.NONE
@export var combat_type: GameTypes.EnemyCombatType = GameTypes.EnemyCombatType.WARRIOR
@export var drop_gold: int = 20
## 美术资源 ID（对应 res://assets/characters/mobs/{art_id}/sprite_frames.tres）
## 空串表示走占位方块（ColorRect + emoji）
@export var art_id: String = ""
@export var drop_relic: bool = false
@export var drop_reroll_reward: int = 0
@export var phases: Array[EnemyPhase] = []
@export var quotes: EnemyQuotes = null
## [P0-MIGRATION] Boss 召唤机制
@export var summons: EnemySummon = null
## [P0-MIGRATION] Boss 死亡分裂/复活机制
@export var revive: EnemyRevive = null


## ============================================================
## 敌人阶段（HP阈值触发不同行动模式）
## ============================================================

class EnemyPhase:
	extends Resource
	## HP 百分比阈值（低于此值切换到该阶段，0 = 无条件）
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
	## 诅咒骰子注入
	@export var curse_dice: String = ""
	@export var curse_dice_count: int = 0
	## [v2] 数据驱动效果数组 — 非空时 EnemyActionResolver 直接走 EffectEngine
	@export var effects: Array[Dictionary] = []


## ============================================================
## 敌人台词（扩展版：新增 greet/dispatch/mid_boss_warning/phase2_taunt）
## ============================================================

class EnemyQuotes:
	extends Resource
	@export var enter: Array[String] = []
	@export var death: Array[String] = []
	@export var attack: Array[String] = []
	@export var hurt: Array[String] = []
	@export var low_hp: Array[String] = []
	## [P0-MIGRATION] Boss 专用台词
	@export var greet: Array[String] = []
	@export var dispatch: Array[String] = []
	@export var mid_boss_warning: Array[String] = []
	@export var phase2_taunt: Array[String] = []


## ============================================================
## Boss 召唤配置
## ============================================================

class EnemySummon:
	extends Resource
	@export var minion_id: String = ""
	@export var interval: int = 3
	@export var count: int = 1
	@export var max_total: int = 4
	@export var wave_cap: int = 4
	## HP 阈值（低于此值才开始召唤，0 = 无条件）
	@export var hp_threshold: float = 0.0


## ============================================================
## Boss 死亡分裂/复活配置
## ============================================================

class EnemyRevive:
	extends Resource
	@export var revive_hp_ratio: float = 0.5
	@export var split_into: int = 2
	@export var split_minion_id: String = ""


## ============================================================
## 所有敌人配置注册表
## ============================================================

static var _all_configs: Dictionary = {}

static func _static_init() -> void:
	_all_configs = ConfigLoader.load_enemy_configs()
	if _all_configs.is_empty():
		push_error("[EnemyConfig] JSON 加载失败，无敌人数据！请检查 config/json/enemy.json")

static func get_config(id: String) -> EnemyConfig:
	if _all_configs.has(id):
		return _all_configs[id]
	push_warning("EnemyConfig not found: %s" % id)
	return _all_configs.values()[0] if _all_configs.size() > 0 else null

static func get_normals_for_chapter(chapter: int) -> Array[EnemyConfig]:
	return _filter_by_category_and_chapter(EnemyCategory.NORMAL, chapter)

static func get_elites_for_chapter(chapter: int) -> Array[EnemyConfig]:
	return _filter_by_category_and_chapter(EnemyCategory.ELITE, chapter)

static func get_bosses_for_chapter(chapter: int) -> Array[EnemyConfig]:
	return _filter_by_category_and_chapter(EnemyCategory.BOSS, chapter)

static func get_mid_bosses_for_chapter(chapter: int) -> Array[EnemyConfig]:
	var result: Array[EnemyConfig] = []
	for cfg in _all_configs.values():
		if cfg is EnemyConfig and cfg.category == EnemyCategory.BOSS and cfg.boss_rank == BossRank.MID and cfg.chapter == chapter:
			result.append(cfg)
	return result

static func get_final_boss_for_chapter(chapter: int) -> EnemyConfig:
	for cfg in _all_configs.values():
		if cfg is EnemyConfig and cfg.category == EnemyCategory.BOSS and cfg.boss_rank == BossRank.FINAL and cfg.chapter == chapter:
			return cfg
	return null

## 显式构造 Array[EnemyConfig] 强类型数组
static func _filter_by_category_and_chapter(cat: EnemyCategory, chapter: int) -> Array[EnemyConfig]:
	var result: Array[EnemyConfig] = []
	for cfg in _all_configs.values():
		if cfg is EnemyConfig and cfg.category == cat and cfg.chapter == chapter:
			result.append(cfg)
	return result
