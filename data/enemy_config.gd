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

# 开关：true=从 Excel → JSON 加载，false=走硬编码构建
# 数据源：config/json/enemy.json（由 config/tools/export_enemy_json.gd 生成）
# 硬编码仅作为 fallback 兜底
const USE_JSON_CONFIG: bool = true

static var _all_configs: Dictionary = {}

static func _static_init() -> void:
	if USE_JSON_CONFIG:
		_all_configs = ConfigLoader.load_enemy_configs()
		if _all_configs.is_empty():
			push_warning("[EnemyConfig] JSON 加载失败，fallback 到硬编码")
			_build_all_configs()
	else:
		_build_all_configs()

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

static func _build_all_configs() -> void:
	_build_ch1_normals()
	_build_ch2_normals()
	_build_ch3_normals()
	_build_ch4_normals()
	_build_ch5_normals()
	_build_elites()
	_build_bosses()


## ============================================================
## 章1: 幽暗森林 — 亡灵/野兽/腐化生物 (10只)
## ============================================================

static func _build_ch1_normals() -> void:
	_register("forest_ghoul", "食尸鬼", 1, 28, 10, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.WARRIOR, 20,
		[_phase(0, [_action(EnemyAction.ActionType.ATTACK, 10), _action(EnemyAction.ActionType.ATTACK, 12, "撕咬"), _action_fx(EnemyAction.ActionType.SKILL, 1, [_fx_status("weak", 1)])])],
		_quotes(["嘎嘎……新鲜的肉……", "从坟墓里爬出来了……"], ["骨头……散了……", "回到……土里……"], ["撕！", "咬碎你！", "嘎嘎嘎！"], ["嘎！", "腐肉……掉了……"], ["不……还没吃饱……"]))
	_register("forest_spider", "剧毒蛛母", 1, 18, 6, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.RANGER, 20,
		[_phase(0, [_action_fx(EnemyAction.ActionType.SKILL, 2, [_fx_status("poison", 2)]), _action(EnemyAction.ActionType.ATTACK, 6), _action(EnemyAction.ActionType.ATTACK, 6)])],
		_quotes(["嘶嘶……陷阱已经布好了……", "（密集的爬行声）"], ["嘶……蛛卵……会替我……", "（扭曲倒地）"], ["毒牙！", "吐丝！", "缠住你！"], ["嘶！", "我的……腿！"], ["蛛巢……不会忘记你……"]))
	_register("forest_treant", "腐化树人", 1, 42, 7, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.GUARDIAN, 20,
		[_phase(0, [_action(EnemyAction.ActionType.DEFEND, 8), _action(EnemyAction.ActionType.ATTACK, 7), _action(EnemyAction.ActionType.DEFEND, 6), _action(EnemyAction.ActionType.ATTACK, 10, "根须缠绕")])],
		_quotes(["这片……森林……不欢迎你……", "（树根从地面涌出）"], ["森林……会记住……", "倒下了……但种子……已经播下……"], ["根须！", "大地之力！"], ["树皮……裂了……", "不过是……划痕……"], ["我的根……断了……但森林……永存……"]))
	_register("forest_banshee", "哀嚎女妖", 1, 16, 8, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.CASTER, 20,
		[_phase(0, [_action_fx(EnemyAction.ActionType.SKILL, 1, [_fx_status("vulnerable", 1)]), _action(EnemyAction.ActionType.ATTACK, 8), _action_fx(EnemyAction.ActionType.SKILL, 1, [_fx_status("weak", 1)])])],
		_quotes(["啊啊啊——！", "听到了吗……死亡的歌声……"], ["终于……安息了……", "（哀鸣渐弱）"], ["尖叫！", "死亡之歌！", "颤抖吧！"], ["（刺耳尖啸）", "痛苦……是我的养分……"], ["最后……一曲……送你上路！"]))
	_register("forest_wolf_priest", "月光狼灵", 1, 20, 7, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.PRIEST, 20,
		[_phase(0, [_action_fx(EnemyAction.ActionType.SKILL, 2, [_fx_status("poison", 2)]), _action_fx(EnemyAction.ActionType.SKILL, 1, [_fx_status("vulnerable", 1)]), _action(EnemyAction.ActionType.ATTACK, 7)])],
		_quotes(["呜——月光指引着我……", "嗅到了……猎物的气息……"], ["月光……暗了……", "呜……（倒下）"], ["狼牙！", "月光之噬！"], ["嗷！", "这……不可能……"], ["月光……给我力量……"]))
	# [CH1-EXPANSION] 下面 5 只为章1扩充
	_register("forest_bone_reaver", "骸骨狂战", 1, 32, 11, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.WARRIOR, 22,
		[_phase(0, [_action(EnemyAction.ActionType.ATTACK, 11), _action(EnemyAction.ActionType.ATTACK, 14, "狂暴劈砍"), _action(EnemyAction.ActionType.DEFEND, 4)])],
		_quotes(["骨刃——饥渴已久！", "（咔咔咔骨节作响）"], ["散架……了……", "骨头归……尘土……"], ["劈！", "斩！", "碾碎你！"], ["咔！", "骨裂……也算伤？"], ["骨髓……最后一滴，献给这场厮杀！"]))
	_register("forest_poison_sprite", "毒雾林精", 1, 16, 5, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.RANGER, 22,
		[_phase(0, [_action_fx(EnemyAction.ActionType.SKILL, 3, [_fx_status("poison", 3)]), _action(EnemyAction.ActionType.ATTACK, 5), _action_fx(EnemyAction.ActionType.SKILL, 2, [_fx_status("poison", 2)])])],
		_quotes(["（雾气弥漫）", "吸一口……就够了。"], ["雾……散了……", "回归根须……"], ["吐毒！", "雾刺！", "呼——"], ["呃……", "叶片被撕了？"], ["最后一口毒雾——全吐出来！"]))
	_register("forest_moss_golem", "苔岩泥像", 1, 48, 6, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.GUARDIAN, 22,
		[_phase(0, [_action(EnemyAction.ActionType.DEFEND, 10), _action(EnemyAction.ActionType.ATTACK, 6), _action(EnemyAction.ActionType.DEFEND, 8), _action(EnemyAction.ActionType.ATTACK, 9, "石拳")])],
		_quotes(["……（沉重的脚步）", "土……吞噬入侵者。"], ["碎……", "归于土……"], ["砸！", "碾！"], ["……（岩石裂缝）", "一点小伤。"], ["最后的岩石……也要还击！"]))
	_register("forest_wraith_cultist", "幽冥诅祝", 1, 18, 7, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.CASTER, 22,
		[_phase(0, [_action_fx(EnemyAction.ActionType.SKILL, 2, [_fx_status("vulnerable", 2)]), _action(EnemyAction.ActionType.ATTACK, 7), _action_fx(EnemyAction.ActionType.SKILL, 1, [_fx_status("weak", 1)])])],
		_quotes(["诅咒……降临！", "（低声吟诵）"], ["咒文……断了……", "回归虚无……"], ["诅咒！", "幽冥之击！", "灵魂剥离！"], ["啊！", "仪式……被打断……"], ["黑暗……收我为仆吧——！"]))
	_register("forest_old_willow", "老槐祭司", 1, 22, 6, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.PRIEST, 22,
		[_phase(0, [_action_fx(EnemyAction.ActionType.SKILL, 2, [_fx_status("poison", 2)]), _action(EnemyAction.ActionType.DEFEND, 6), _action_fx(EnemyAction.ActionType.SKILL, 1, [_fx_status("vulnerable", 1)]), _action(EnemyAction.ActionType.ATTACK, 6)])],
		_quotes(["孩儿们，饮下我的树液……", "古老的森林，借我一分力量。"], ["枝叶……枯萎……", "根须……缩回……"], ["树液灌注！", "藤鞭！"], ["树皮……脱落……", "一点小伤不要紧。"], ["最后一片叶子——化作诅咒！"]))


## ============================================================
## 章2: 冰封山脉 — 冰霜生物 (10只)
## ============================================================

static func _build_ch2_normals() -> void:
	_register("ice_yeti", "雪原雪人", 2, 36, 9, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.WARRIOR, 20,
		[_phase(0, [_action(EnemyAction.ActionType.ATTACK, 9), _action(EnemyAction.ActionType.ATTACK, 11, "冰拳")])],
		_quotes(["吼————！", "（地面在颤抖）"], ["吼……（倒地，掀起雪浪）", "冰……碎了……"], ["砸！", "冰拳！", "吼！"], ["吼！疼！", "（愤怒咆哮）"], ["吼……不会……倒下……"]))
	_register("ice_mage", "霜寒女巫", 2, 18, 4, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.CASTER, 20,
		[_phase(0, [_action_fx(EnemyAction.ActionType.SKILL, 1, [_fx_status("freeze", 1)]), _action(EnemyAction.ActionType.ATTACK, 6), _action_fx(EnemyAction.ActionType.SKILL, 2, [_fx_status("weak", 2)])])],
		_quotes(["冰霜……会冻结一切……", "寒冬……已经来临……"], ["冰……碎了……但寒意……永存……", "（冰晶四散）"], ["冰锥！", "寒冰箭！", "冻住！"], ["冰盾……裂了……", "不……可能……"], ["暴风雪……最后的咏唱……"]))
	_register("ice_wolf", "霜鬃狼", 2, 22, 5, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.RANGER, 20,
		[_phase(0, [_action(EnemyAction.ActionType.ATTACK, 5), _action(EnemyAction.ActionType.ATTACK, 7, "冰霜撕咬"), _action_fx(EnemyAction.ActionType.SKILL, 1, [_fx_status("burn", 1)])])],
		_quotes(["（低沉的咆哮）", "嗅到了……温暖的血……"], ["呜……（倒在雪中）", "（低吟消散）"], ["嗷！", "撕咬！", "冰牙！"], ["嗷呜！", "（退后一步，龇牙）"], ["呜……群狼……会替我报仇……"]))
	_register("ice_golem", "寒冰石像", 2, 44, 4, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.GUARDIAN, 20,
		[_phase(0, [_action(EnemyAction.ActionType.DEFEND, 10), _action(EnemyAction.ActionType.ATTACK, 5), _action(EnemyAction.ActionType.DEFEND, 8)])],
		_quotes(["（冰晶嘎吱作响）", "不许……通过……"], ["（碎裂成冰块）", "使命……完成……"], ["碾压！", "冰拳！"], ["裂缝……", "（冰块脱落）"], ["还能……守住……"]))
	# [CH2-EXPANSION] 章2 扩充 6 只
	_register("ice_storm_wolf", "暴风战狼", 2, 40, 10, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.WARRIOR, 22,
		[_phase(0, [_action(EnemyAction.ActionType.ATTACK, 10), _action(EnemyAction.ActionType.ATTACK, 13, "暴风突袭")])],
		_quotes(["嗷——风雪为我引路！", "（狂吠声回荡）"], ["风停了……", "回归风雪……"], ["撕咬！", "突袭！", "嗷呜！"], ["嗷！", "一点皮毛伤。"], ["最后一阵风雪——卷起全部力量！"]))
	_register("ice_crystal_archer", "冰晶射手", 2, 20, 7, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.RANGER, 22,
		[_phase(0, [_action(EnemyAction.ActionType.ATTACK, 7), _action(EnemyAction.ActionType.ATTACK, 9, "冰棱射击"), _action_fx(EnemyAction.ActionType.SKILL, 1, [_fx_status("weak", 1)])])],
		_quotes(["箭已上弦——", "（冰棱折射出寒光）"], ["箭袋空了……", "冰棱融化……"], ["冰棱！", "穿透！", "咻——"], ["擦伤。", "距离估算出错了？"], ["最后一箭——必须结霜。"]))
	_register("ice_avalanche_watch", "雪峦守望", 2, 54, 6, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.GUARDIAN, 22,
		[_phase(0, [_action(EnemyAction.ActionType.DEFEND, 12), _action(EnemyAction.ActionType.ATTACK, 6), _action(EnemyAction.ActionType.DEFEND, 10), _action(EnemyAction.ActionType.ATTACK, 8, "雪崩重击")])],
		_quotes(["……山的一部分，动了。", "（冰壳碎裂声）"], ["崩……", "归于雪中……"], ["雪崩！", "重击！"], ["（冰壳裂缝）", "一点小伤。"], ["最后的冰壳——也要砸碎他！"]))
	_register("ice_coffin_wraith", "冰棺咒灵", 2, 20, 8, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.CASTER, 22,
		[_phase(0, [_action_fx(EnemyAction.ActionType.SKILL, 2, [_fx_status("vulnerable", 2)]), _action(EnemyAction.ActionType.ATTACK, 8), _action_fx(EnemyAction.ActionType.SKILL, 1, [_fx_status("weak", 1)])])],
		_quotes(["寒气——侵骨。", "（冰棺中传出低语）"], ["咒灵散了……", "回归冰棺……"], ["冻咒！", "霜刃！", "灵魂剥离！"], ["啊——！", "寒意被扰了？"], ["全部寒意——凝成最后一击！"]))
	_register("ice_frost_elder", "霜祭冰尊", 2, 26, 6, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.PRIEST, 22,
		[_phase(0, [_action_fx(EnemyAction.ActionType.SKILL, 2, [_fx_status("vulnerable", 2)]), _action(EnemyAction.ActionType.DEFEND, 8), _action_fx(EnemyAction.ActionType.SKILL, 1, [_fx_status("weak", 1)]), _action(EnemyAction.ActionType.ATTACK, 6)])],
		_quotes(["霜之神啊——请饮下鲜血。", "（低声吟唱）"], ["祭坛……冷了……", "神……回避了我……"], ["霜之律令！", "冻骨之触！"], ["啊！", "仪式——被打断了？"], ["献祭吧——用我自己的寒骨！"]))
	_register("ice_holy_bishop", "圣冰牧首", 2, 30, 5, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.PRIEST, 22,
		[_phase(0, [_action(EnemyAction.ActionType.DEFEND, 10), _action_fx(EnemyAction.ActionType.SKILL, 2, [_fx_status("poison", 2)]), _action_fx(EnemyAction.ActionType.SKILL, 1, [_fx_status("weak", 1)]), _action(EnemyAction.ActionType.ATTACK, 5)])],
		_quotes(["圣冰之名——净化你。", "（颂圣诗）"], ["诗篇……断章……", "圣冰……融化……"], ["圣冰审判！", "圣咏！"], ["啊！", "圣服被污了。"], ["全部圣咏——凝成审判！"]))

## ============================================================
## 章3: 熔岩深渊 — 火焰/恶魔生物 (10只)
## ============================================================

static func _build_ch3_normals() -> void:
	_register("lava_hound", "地狱火犬", 3, 30, 8, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.WARRIOR, 20,
		[_phase(0, [_action(EnemyAction.ActionType.ATTACK, 8), _action(EnemyAction.ActionType.ATTACK, 10, "烈焰撕咬"), _action_fx(EnemyAction.ActionType.SKILL, 2, [_fx_status("burn", 2)])])],
		_quotes(["（烈焰从口中喷出）", "吼！猎物！"], ["（化为灰烬）", "火……灭了……"], ["烈焰！", "烧！", "吞噬！"], ["（痛苦嚎叫）", "嗷！"], ["最后……一口火焰……"]))
	_register("lava_imp", "小恶魔", 3, 16, 4, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.CASTER, 20,
		[_phase(0, [_action_fx(EnemyAction.ActionType.SKILL, 2, [_fx_status("burn", 2)]), _action(EnemyAction.ActionType.ATTACK, 5), _action_fx(EnemyAction.ActionType.SKILL, 1, [_fx_status("vulnerable", 1)]), _action(EnemyAction.ActionType.ATTACK, 6, "火球")])],
		_quotes(["嘻嘻嘻！又来送死的！", "火焰……是最好的玩具！"], ["嘻……不好玩了……", "（砰——消散）"], ["接火球！", "嘻嘻！烫吧！", "燃烧吧！"], ["哎呀！", "嘻……你打得到我？"], ["不行了……要逃了……才怪！吃火球！"]))
	_register("lava_guardian", "黑铁卫士", 3, 48, 5, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.GUARDIAN, 20,
		[_phase(0, [_action(EnemyAction.ActionType.DEFEND, 12), _action(EnemyAction.ActionType.ATTACK, 6), _action(EnemyAction.ActionType.DEFEND, 8), _action(EnemyAction.ActionType.ATTACK, 8, "锻造重击")])],
		_quotes(["黑铁之盾，坚不可摧！", "没有通行令，不许过！"], ["盾……碎了……", "黑铁……不灭……（倒下）"], ["锤击！", "黑铁之力！"], ["叮！", "铁甲……凹了？"], ["只要……盾还在……就不会倒！"]))
	_register("lava_shaman", "火焰萨满", 3, 22, 3, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.PRIEST, 20,
		[_phase(0, [_action_fx(EnemyAction.ActionType.SKILL, 2, [_fx_status("burn", 2)]), _action_fx(EnemyAction.ActionType.SKILL, 1, [_fx_defend_ally(1)]), _action(EnemyAction.ActionType.ATTACK, 5)])],
		_quotes(["烈焰之灵……降临吧！", "火焰赐予我力量！"], ["火灵……离开了我……", "（火焰熄灭）"], ["烈焰冲击！", "焚烧！"], ["火盾……碎了……", "灵体……动摇了……"], ["最后的祈祷……烈焰之怒！"]))
	# [CH3-EXPANSION] 章3 扩充 6 只
	_register("lava_bruiser", "熔岩重锤兵", 3, 38, 10, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.WARRIOR, 24,
		[_phase(0, [_action(EnemyAction.ActionType.ATTACK, 10), _action_fx(EnemyAction.ActionType.SKILL, 2, [_fx_status("burn", 2)]), _action(EnemyAction.ActionType.ATTACK, 13, "熔铁重击")])],
		_quotes(["熔铁在沸！", "（锤柄冒烟）"], ["熔……冷了……", "锤……化铁水……"], ["铁砸！", "熔击！", "烫——"], ["火花迸溅——不算伤。", "铁皮还厚着。"], ["熔心最后一击——全融了你！"]))
	_register("lava_sparkshooter", "火星箭手", 3, 22, 8, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.RANGER, 24,
		[_phase(0, [_action(EnemyAction.ActionType.ATTACK, 8), _action_fx(EnemyAction.ActionType.SKILL, 2, [_fx_status("burn", 2)]), _action(EnemyAction.ActionType.ATTACK, 11, "火星箭")])],
		_quotes(["火种——点燃！", "（弦已拉满）"], ["火种……灭了……", "箭袋烧没了……"], ["火星！", "燃穿！", "咻——"], ["擦伤。", "我低估了你的速度。"], ["最后一支——火种全注入！"]))
	_register("lava_warden", "黑铁哨卫", 3, 52, 6, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.GUARDIAN, 24,
		[_phase(0, [_action(EnemyAction.ActionType.DEFEND, 12), _action(EnemyAction.ActionType.ATTACK, 6), _action(EnemyAction.ActionType.DEFEND, 10), _action(EnemyAction.ActionType.ATTACK, 9, "铁盾撞击")])],
		_quotes(["……（盾牌撞地）", "一步不让。"], ["盾……裂了……", "归于铁砧……"], ["盾撞！", "砸！"], ["铁皮厚着。", "一层装甲，十层脾气。"], ["最后一盾——碎也要砸他！"]))
	_register("lava_fire_mage", "焚心法师", 3, 22, 9, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.CASTER, 24,
		[_phase(0, [_action_fx(EnemyAction.ActionType.SKILL, 3, [_fx_status("burn", 3)]), _action(EnemyAction.ActionType.ATTACK, 9), _action_fx(EnemyAction.ActionType.SKILL, 1, [_fx_status("vulnerable", 1)])])],
		_quotes(["焚——心！", "（焰语低吟）"], ["法术……回火……", "心头火——熄了……"], ["焚心！", "炎狱！", "焰尖刺！"], ["啊！", "咒文——被烫断？"], ["最后一缕——焚尽你！"]))
	_register("lava_ember_priest", "熔心祭司", 3, 28, 6, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.PRIEST, 24,
		[_phase(0, [_action_fx(EnemyAction.ActionType.SKILL, 2, [_fx_status("burn", 2)]), _action(EnemyAction.ActionType.DEFEND, 8), _action_fx(EnemyAction.ActionType.SKILL, 1, [_fx_status("weak", 1)]), _action(EnemyAction.ActionType.ATTACK, 6)])],
		_quotes(["火神——受我奉献。", "（炭盆燃起）"], ["火神……转身了……", "炭盆……冷了……"], ["熔心之礼！", "炎骨刃！"], ["啊——！", "仪式——被扰？"], ["以我热血——唤火神降临！"]))
	_register("lava_cinder_oracle", "余烬圣司", 3, 32, 5, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.PRIEST, 24,
		[_phase(0, [_action(EnemyAction.ActionType.DEFEND, 10), _action_fx(EnemyAction.ActionType.SKILL, 2, [_fx_status("burn", 2)]), _action_fx(EnemyAction.ActionType.SKILL, 1, [_fx_status("weak", 1)]), _action(EnemyAction.ActionType.ATTACK, 5)])],
		_quotes(["余烬——开口了。", "（经文在火中显形）"], ["经文……化灰……", "火神……不应……"], ["余烬审判！", "炭骨刃！"], ["啊！", "圣书烫着手，但不曾合上。"], ["最后一页经文——全部焚化为刃！"]))

## ============================================================
## 章4: 暗影要塞 — 恶魔/堕落生物 (10只)
## ============================================================

static func _build_ch4_normals() -> void:
	_register("shadow_assassin", "暗影刺客", 4, 24, 12, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.RANGER, 20,
		[_phase(0, [_action(EnemyAction.ActionType.ATTACK, 12, "背刺"), _action_fx(EnemyAction.ActionType.SKILL, 2, [_fx_status("poison", 2)]), _action(EnemyAction.ActionType.ATTACK, 8)])],
		_quotes(["（从阴影中浮现）", "你……看不见我……"], ["影子……消散了……", "（无声倒下）"], ["背刺！", "影杀！", "无声之刃！"], ["嘶……被发现了……", "不……可能……"], ["影遁……最后一击……"]))
	_register("shadow_felguard", "邪能卫兵", 4, 46, 6, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.GUARDIAN, 20,
		[_phase(0, [_action(EnemyAction.ActionType.ATTACK, 7), _action(EnemyAction.ActionType.DEFEND, 14), _action(EnemyAction.ActionType.ATTACK, 9, "邪能重斩")])],
		_quotes(["受主人之命……消灭一切入侵者！", "邪能……流淌在我的血脉中！"], ["主人……恕我……", "邪能……回归虚空……"], ["邪能斩！", "毁灭！", "碾碎你！"], ["邪能护甲……", "不过如此……"], ["主人的力量……赐予我……最后一击！"]))
	_register("shadow_warlock", "邪能术士", 4, 20, 5, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.CASTER, 20,
		[_phase(0, [_action_fx(EnemyAction.ActionType.SKILL, 2, [_fx_status("poison", 2)]), _action(EnemyAction.ActionType.ATTACK, 6), _action_fx(EnemyAction.ActionType.SKILL, 2, [_fx_status("burn", 2)]), _action(EnemyAction.ActionType.ATTACK, 7, "暗影箭")])],
		_quotes(["邪能……是最强大的力量！", "痛苦……才刚刚开始……"], ["不……我的灵魂……", "邪能……反噬了……"], ["暗影箭！", "燃烧吧！", "腐蚀！"], ["灵魂石……碎了……", "不可能……我的结界……"], ["生命分流！用你的生命……延续我的！"]))
	_register("shadow_knight", "堕落死亡骑士", 4, 34, 10, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.WARRIOR, 20,
		[_phase(0, [_action(EnemyAction.ActionType.ATTACK, 10), _action_fx(EnemyAction.ActionType.SKILL, 1, [_fx_status("weak", 1)]), _action(EnemyAction.ActionType.ATTACK, 12, "凋零打击")])],
		_quotes(["曾经……我也是光明的骑士……", "背叛了光……便无路可退……"], ["光……我又看到了……光……", "（黑色铠甲碎裂）"], ["凋零！", "黑暗之力！", "受死吧！"], ["这具身体……已经不怕痛了……", "无用的抵抗……"], ["即便倒下……黑暗……也不会消失……"]))
	# [CH4-EXPANSION] 章4 扩充 6 只
	_register("shadow_reaver", "虚空狂徒", 4, 40, 11, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.WARRIOR, 26,
		[_phase(0, [_action(EnemyAction.ActionType.ATTACK, 11), _action(EnemyAction.ActionType.ATTACK, 14, "虚空撕扯")])],
		_quotes(["虚空——在我身后蠕动。", "（扭曲的笑声）"], ["虚空……吞回了我……", "原来……我只是它的一爪……"], ["虚空斩！", "撕！", "噬！"], ["肉身？我早就没这玩意。", "痛感……提醒我还活着。"], ["用虚空的最后一爪——报复你！"]))
	_register("shadow_crossbow", "邪能弩手", 4, 26, 10, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.RANGER, 26,
		[_phase(0, [_action(EnemyAction.ActionType.ATTACK, 10), _action_fx(EnemyAction.ActionType.SKILL, 2, [_fx_status("vulnerable", 2)]), _action(EnemyAction.ActionType.ATTACK, 12, "邪能穿透")])],
		_quotes(["准星——对准了。", "（邪能在弩箭上流动）"], ["弩弦断了……", "没瞄准核心……可惜……"], ["穿！", "破甲！", "咻——"], ["擦伤而已。", "距离我算错了一步。"], ["最后一箭——浸满邪能！"]))
	_register("shadow_gatekeeper", "深渊守门", 4, 58, 6, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.GUARDIAN, 26,
		[_phase(0, [_action(EnemyAction.ActionType.DEFEND, 14), _action(EnemyAction.ActionType.ATTACK, 6), _action(EnemyAction.ActionType.DEFEND, 12), _action(EnemyAction.ActionType.ATTACK, 10, "深渊撞击")])],
		_quotes(["门后——是你进不去的世界。", "（巨大的叩门声）"], ["门……关上了……", "无法守护了……"], ["门锤！", "撞！"], ["护甲松了两片。", "门还在。"], ["最后一击——把门带着他一起砸塌！"]))
	_register("shadow_oracle", "虚空卜者", 4, 22, 8, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.CASTER, 26,
		[_phase(0, [_action_fx(EnemyAction.ActionType.SKILL, 2, [_fx_status("vulnerable", 2)]), _action(EnemyAction.ActionType.ATTACK, 8), _action_fx(EnemyAction.ActionType.SKILL, 1, [_fx_status("weak", 1)])])],
		_quotes(["卜辞已出——你的结局，是'死'。", "（虚空之眼睁开）"], ["卜辞……错了？……", "虚空……也会欺骗我……"], ["卜辞！", "虚空之眼！", "注视——"], ["卜辞……被扰？", "数据——重新校准。"], ["最后的卜辞——全赌你死！"]))
	_register("shadow_sin_priest", "堕落司祭", 4, 28, 6, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.PRIEST, 26,
		[_phase(0, [_action_fx(EnemyAction.ActionType.SKILL, 2, [_fx_status("poison", 2)]), _action(EnemyAction.ActionType.DEFEND, 8), _action_fx(EnemyAction.ActionType.SKILL, 1, [_fx_status("vulnerable", 1)]), _action(EnemyAction.ActionType.ATTACK, 6)])],
		_quotes(["罪——是信仰的另一张脸。", "（黑色圣水泼洒）"], ["告解……被撤回了……", "罪——无人接续……"], ["罪刃！", "堕落之咒！"], ["啊——！", "祭袍破了一角——不影响。"], ["以我罪身——完成最后的献祭！"]))
	_register("shadow_void_prophet", "渊影预言者", 4, 32, 5, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.PRIEST, 26,
		[_phase(0, [_action(EnemyAction.ActionType.DEFEND, 10), _action_fx(EnemyAction.ActionType.SKILL, 2, [_fx_status("poison", 2)]), _action_fx(EnemyAction.ActionType.SKILL, 2, [_fx_status("vulnerable", 2)]), _action(EnemyAction.ActionType.ATTACK, 5)])],
		_quotes(["预言——已写在你的影子里。", "（虚空经文滴水）"], ["预言……错了……", "虚空……也会说谎？……"], ["预言之刃！", "影咏！"], ["啊！", "经书尚未合上。"], ["最后一段预言——必然应验！"]))

## ============================================================
## 章5: 永恒之巅 — 光铸/泰坦/时光造物 (11只)
## ============================================================

static func _build_ch5_normals() -> void:
	_register("eternal_sentinel", "光铸哨兵", 5, 40, 8, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.GUARDIAN, 20,
		[_phase(0, [_action(EnemyAction.ActionType.DEFEND, 14), _action(EnemyAction.ActionType.ATTACK, 8), _action(EnemyAction.ActionType.DEFEND, 10), _action(EnemyAction.ActionType.ATTACK, 10, "圣光裁决")])],
		_quotes(["此地……不可侵犯。", "以泰坦之名——退下！"], ["任务……失败……", "光……指引我……回家……"], ["裁决！", "净化！", "圣光之锤！"], ["圣光护盾……动摇了……", "不过是……考验……"], ["即使倒下……光明……永不熄灭……"]))
	_register("eternal_chrono", "时光龙人", 5, 26, 7, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.CASTER, 20,
		[_phase(0, [_action_fx(EnemyAction.ActionType.SKILL, 2, [_fx_status("weak", 2)]), _action(EnemyAction.ActionType.ATTACK, 8, "时光冲击"), _action_fx(EnemyAction.ActionType.SKILL, 1, [_fx_status("freeze", 1)])])],
		_quotes(["你的时间线……出了偏差……", "过去、现在、未来……我都能看见……"], ["时间线……修复了……", "这个结果……也在预料之中……"], ["时光逆转！", "沙漏之力！", "时间停止！"], ["时间流……紊乱了……", "这不在……预言中……"], ["最后的沙粒……也快流尽了……"]))
	_register("eternal_archer", "星界游侠", 5, 22, 10, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.RANGER, 20,
		[_phase(0, [_action(EnemyAction.ActionType.ATTACK, 10), _action(EnemyAction.ActionType.ATTACK, 12, "星辰之箭"), _action_fx(EnemyAction.ActionType.SKILL, 1, [_fx_status("vulnerable", 1)])])],
		_quotes(["星光……指引我的箭矢……", "（弓弦轻响）"], ["星辰……暗了……", "（化为星尘）"], ["星箭！", "穿透！", "星光之雨！"], ["嘶……", "星光……偏移了……"], ["最后一箭……献给星辰……"]))
	_register("eternal_priest", "泰坦祭司", 5, 24, 3, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.PRIEST, 20,
		[_phase(0, [_action_fx(EnemyAction.ActionType.SKILL, 2, [_fx_defend_ally(2)]), _action_fx(EnemyAction.ActionType.SKILL, 1, [_fx_status("vulnerable", 1)]), _action(EnemyAction.ActionType.ATTACK, 6, "圣光惩击")])],
		_quotes(["泰坦的意志……不容亵渎。", "圣光……会审判一切。"], ["泰坦……我……回来了……", "（光芒消散）"], ["惩击！", "圣光！", "泰坦之怒！"], ["信仰……不会动摇……", "只是……皮肉之伤……"], ["圣光……赐予我……最后的力量……"]))
	# [CH5-EXPANSION] 章5 扩充 7 只
	_register("eternal_champion", "永恒斗士", 5, 42, 12, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.WARRIOR, 28,
		[_phase(0, [_action(EnemyAction.ActionType.ATTACK, 12), _action(EnemyAction.ActionType.ATTACK, 15, "圣裁一击")])],
		_quotes(["斗技场永不熄灯。", "（金属轻响）"], ["斗技……结束了……", "归于荣耀……"], ["圣裁！", "劈斩！", "来啊！"], ["小伤不下场。", "还没尽兴。"], ["最后一击——为荣耀而挥！"]))
	_register("eternal_paladin", "白金骑士", 5, 48, 10, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.WARRIOR, 28,
		[_phase(0, [_action(EnemyAction.ActionType.ATTACK, 10), _action(EnemyAction.ActionType.DEFEND, 10), _action(EnemyAction.ActionType.ATTACK, 13, "圣光重击")])],
		_quotes(["圣光——与我同行。", "（甲胄铿锵）"], ["圣光……稍稍收回了……", "铠甲……还在……灵魂已退……"], ["圣光！", "重击！", "审判！"], ["小刀痕——祷告已愈。", "圣光仍伴我。"], ["以我骑士誓约——最后一刀！"]))
	_register("eternal_skyknight", "穹苍骑兵", 5, 26, 9, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.RANGER, 28,
		[_phase(0, [_action(EnemyAction.ActionType.ATTACK, 9), _action(EnemyAction.ActionType.ATTACK, 12, "俯冲射"), _action_fx(EnemyAction.ActionType.SKILL, 1, [_fx_status("weak", 1)])])],
		_quotes(["（风从头顶掠过）", "上空——是我的领地。"], ["羽翼……折了……", "风……不再载我……"], ["俯冲射！", "穿羽！", "咻——"], ["气流吹偏了。", "擦伤。"], ["最后一支箭——带着风意而至！"]))
	_register("eternal_bulwark", "永光壁垒", 5, 56, 7, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.GUARDIAN, 28,
		[_phase(0, [_action(EnemyAction.ActionType.DEFEND, 14), _action(EnemyAction.ActionType.ATTACK, 7), _action(EnemyAction.ActionType.DEFEND, 12), _action(EnemyAction.ActionType.ATTACK, 10, "永光撞击")])],
		_quotes(["光壁——合上。", "（塔盾落地声）"], ["壁……崩了……", "圣光遮不住一切……"], ["壁撞！", "圣光冲！"], ["盾面裂痕，可修。", "圣光尚在。"], ["最后一面壁——砸碎他与我！"]))
	_register("eternal_chronomancer", "时砂法师", 5, 24, 9, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.CASTER, 28,
		[_phase(0, [_action_fx(EnemyAction.ActionType.SKILL, 2, [_fx_status("vulnerable", 2)]), _action(EnemyAction.ActionType.ATTACK, 9), _action_fx(EnemyAction.ActionType.SKILL, 1, [_fx_status("weak", 1)])])],
		_quotes(["时砂——倒流片刻。", "（沙漏悬空）"], ["时砂……走空了……", "回到过去……也没用了……"], ["时砂刺！", "时之裂！", "砂流！"], ["啊！", "沙漏晃了一下。"], ["把所有剩余时砂——全倒给你！"]))
	_register("eternal_lightcantor", "永光吟唱者", 5, 30, 6, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.PRIEST, 28,
		[_phase(0, [_action_fx(EnemyAction.ActionType.SKILL, 2, [_fx_status("vulnerable", 2)]), _action(EnemyAction.ActionType.DEFEND, 8), _action_fx(EnemyAction.ActionType.SKILL, 1, [_fx_status("weak", 1)]), _action(EnemyAction.ActionType.ATTACK, 6)])],
		_quotes(["以永光之名——我为你唱挽歌。", "（唱经班低吟）"], ["挽歌……断句了……", "永光…微弱……"], ["圣咏！", "永光之音！"], ["啊！", "经书烫手——但合上很难。"], ["以我嗓音——为你奏响最终章！"]))

## ============================================================
## 精英敌人 (15只: 原10 + 新增5)
## ============================================================

static func _build_elites() -> void:
	# ===== 章1 精英 =====
	_register("elite_necromancer", "亡灵巫师", 1, 85, 8, EnemyCategory.ELITE, GameTypes.EnemyCombatType.CASTER, 50,
		[_phase(0.4, [_action(EnemyAction.ActionType.ATTACK, 14, "亡灵大军"), _action_fx(EnemyAction.ActionType.SKILL, 3, [_fx_status("poison", 3)])]),
		 _phase(0, [_action(EnemyAction.ActionType.ATTACK, 8), _action_fx(EnemyAction.ActionType.SKILL, 2, [_fx_status("weak", 2)]), _action(EnemyAction.ActionType.DEFEND, 12)])],
		_quotes(["死者……听从我的召唤！"], ["我的……亡灵们……"], ["亡灵术！", "腐蚀！", "黑暗吞噬！"], ["骨盾……碎了？"], ["用我的骸骨……召唤最后的亡灵！"]),
		true, 2)
	_register("elite_alpha_wolf", "狼人首领", 1, 100, 11, EnemyCategory.ELITE, GameTypes.EnemyCombatType.WARRIOR, 50,
		[_phase(0, [_action(EnemyAction.ActionType.ATTACK, 11), _action(EnemyAction.ActionType.ATTACK, 14, "狂暴撕咬"), _action_fx(EnemyAction.ActionType.SKILL, 2, [_fx_status("strength", 2)]), _action(EnemyAction.ActionType.ATTACK, 9)])],
		_quotes(["月光之下……狼群为王！"], ["狼王……倒下了……"], ["撕碎！", "狂暴！", "嗷——！"], ["疼痛……让我更愤怒！"], ["月光……赐予我……"]),
		true, 2)
	# [NEW] 章1 新增精英
	_register("elite_phantom_hunter", "魅影猎手", 1, 90, 10, EnemyCategory.ELITE, GameTypes.EnemyCombatType.RANGER, 50,
		[_phase(0.35, [_action(EnemyAction.ActionType.ATTACK, 16, "幽影穿心"), _action_fx(EnemyAction.ActionType.SKILL, 2, [_fx_status("poison", 2)])]),
		 _phase(0, [_action(EnemyAction.ActionType.ATTACK, 10), _action_fx(EnemyAction.ActionType.SKILL, 1, [_fx_status("vulnerable", 1)]), _action(EnemyAction.ActionType.ATTACK, 8)])],
		_quotes(["（无声出现）你……已经在我的射程内了。"], ["影子……消散了……猎物……逃了……"], ["幽影穿心！", "暗箭！", "无声之矢！"], ["嘶……被发现了？"], ["最后一箭——从影子里射出！"]),
		true, 2)
	# ===== 章2 精英 =====
	_register("elite_frost_wyrm", "霜龙幼崽", 2, 95, 10, EnemyCategory.ELITE, GameTypes.EnemyCombatType.CASTER, 50,
		[_phase(0.3, [_action(EnemyAction.ActionType.ATTACK, 18, "寒冰吐息"), _action_fx(EnemyAction.ActionType.SKILL, 2, [_fx_status("freeze", 2)])]),
		 _phase(0, [_action(EnemyAction.ActionType.ATTACK, 10), _action_fx(EnemyAction.ActionType.SKILL, 2, [_fx_status("weak", 2)]), _action(EnemyAction.ActionType.DEFEND, 14), _action(EnemyAction.ActionType.ATTACK, 8)])],
		_quotes(["（冰冷的咆哮响彻山谷）"], ["（碎裂成无数冰晶）"], ["冰息！", "冻住吧！"], ["龙鳞……裂了？"], ["最后的……寒冰吐息……"]),
		true, 2)
	_register("elite_ice_lord", "冰霜巨人王", 2, 120, 7, EnemyCategory.ELITE, GameTypes.EnemyCombatType.GUARDIAN, 50,
		[_phase(0, [_action(EnemyAction.ActionType.DEFEND, 20), _action(EnemyAction.ActionType.ATTACK, 8), _action(EnemyAction.ActionType.ATTACK, 14, "冰锤粉碎"), _action_fx(EnemyAction.ActionType.SKILL, 1, [_fx_status("freeze", 1)])])],
		_quotes(["渺小的生物……敢闯冰封王座？"], ["冰……不灭……"], ["碾碎！", "冰锤！"], ["蚊虫叮咬……"], ["冰封王座……不会倒塌！"]),
		true, 2)
	# [NEW] 章2 新增精英
	_register("elite_frost_archon", "霜誓执政", 2, 105, 9, EnemyCategory.ELITE, GameTypes.EnemyCombatType.PRIEST, 50,
		[_phase(0.35, [_action_fx(EnemyAction.ActionType.SKILL, 3, [_fx_status("poison", 3)]), _action_fx(EnemyAction.ActionType.SKILL, 2, [_fx_status("weak", 2)]), _action(EnemyAction.ActionType.DEFEND, 16)]),
		 _phase(0, [_action(EnemyAction.ActionType.ATTACK, 9), _action_fx(EnemyAction.ActionType.SKILL, 2, [_fx_status("vulnerable", 2)]), _action(EnemyAction.ActionType.DEFEND, 12)])],
		_quotes(["霜之律法——不容违抗。"], ["律法……被推翻了……"], ["霜之律令！", "冰封审判！"], ["律法不会因一击而动摇。"], ["以霜之名——宣判最终裁决！"]),
		true, 2)
	# ===== 章3 精英 =====
	_register("elite_infernal", "地狱火", 3, 100, 12, EnemyCategory.ELITE, GameTypes.EnemyCombatType.WARRIOR, 50,
		[_phase(0, [_action(EnemyAction.ActionType.ATTACK, 12), _action(EnemyAction.ActionType.ATTACK, 16, "烈焰冲击"), _action_fx(EnemyAction.ActionType.SKILL, 3, [_fx_status("burn", 3)]), _action(EnemyAction.ActionType.DEFEND, 10)])],
		_quotes(["（从天而降，地面龟裂）"], ["烈焰……熄灭了……"], ["烈焰！", "毁灭！", "焚烧一切！"], ["石皮……裂了……"], ["最后的爆发……"]),
		true, 2)
	_register("elite_dark_iron", "黑铁议员", 3, 90, 9, EnemyCategory.ELITE, GameTypes.EnemyCombatType.CASTER, 50,
		[_phase(0.4, [_action(EnemyAction.ActionType.ATTACK, 16, "熔岩之怒"), _action_fx(EnemyAction.ActionType.SKILL, 0, [_fx_curse_die()])]),
		 _phase(0, [_action(EnemyAction.ActionType.ATTACK, 9), _action_fx(EnemyAction.ActionType.SKILL, 2, [_fx_status("burn", 2)]), _action(EnemyAction.ActionType.DEFEND, 16)])],
		_quotes(["黑铁议会……判你死刑！"], ["议会……散了……"], ["熔岩之怒！", "黑铁审判！"], ["黑铁……不碎！"], ["启动……自毁程序……"]),
		true, 2)
	# [NEW] 章3 新增精英
	_register("elite_flame_oracle", "烈焰谕者", 3, 95, 10, EnemyCategory.ELITE, GameTypes.EnemyCombatType.PRIEST, 50,
		[_phase(0.35, [_action_fx(EnemyAction.ActionType.SKILL, 3, [_fx_status("burn", 3)]), _action_fx(EnemyAction.ActionType.SKILL, 2, [_fx_status("vulnerable", 2)]), _action(EnemyAction.ActionType.DEFEND, 14)]),
		 _phase(0, [_action(EnemyAction.ActionType.ATTACK, 10), _action_fx(EnemyAction.ActionType.SKILL, 2, [_fx_status("burn", 2)]), _action(EnemyAction.ActionType.DEFEND, 10)])],
		_quotes(["火焰的谕示——你将化为灰烬。"], ["谕示……错了……"], ["烈焰谕令！", "焚烧审判！"], ["火焰不会因一击而熄灭。"], ["以烈焰之名——宣判最终焚烧！"]),
		true, 2)
	# ===== 章4 精英 =====
	_register("elite_doomguard", "末日守卫", 4, 110, 11, EnemyCategory.ELITE, GameTypes.EnemyCombatType.WARRIOR, 50,
		[_phase(0, [_action(EnemyAction.ActionType.ATTACK, 11), _action(EnemyAction.ActionType.ATTACK, 16, "末日审判"), _action_fx(EnemyAction.ActionType.SKILL, 2, [_fx_status("vulnerable", 2)]), _action(EnemyAction.ActionType.DEFEND, 14), _action_fx(EnemyAction.ActionType.SKILL, 0, [_fx_curse_die()])])],
		_quotes(["末日……已经降临。"], ["军团……不灭……"], ["末日审判！", "灵魂撕裂！"], ["邪能护甲……动摇了？"], ["用我的生命……召唤更强大的恶魔！"]),
		true, 2)
	_register("elite_shadow_priest", "暗影大主教", 4, 80, 8, EnemyCategory.ELITE, GameTypes.EnemyCombatType.PRIEST, 50,
		[_phase(0.3, [_action_fx(EnemyAction.ActionType.SKILL, 3, [_fx_status("poison", 3)]), _action_fx(EnemyAction.ActionType.SKILL, 3, [_fx_status("burn", 3)])]),
		 _phase(0, [_action(EnemyAction.ActionType.ATTACK, 8), _action_fx(EnemyAction.ActionType.SKILL, 2, [_fx_status("weak", 2)]), _action(EnemyAction.ActionType.ATTACK, 10, "精神鞭笞"), _action_fx(EnemyAction.ActionType.SKILL, 2, [_fx_status("poison", 2)])])],
		_quotes(["暗影的低语……你听到了吗？"], ["暗影……弥散了……"], ["精神鞭笞！", "暗影之触！"], ["心灵屏障……裂了……"], ["暗影……形态——最终手段！"]),
		true, 2)
	# [NEW] 章4 新增精英
	_register("elite_nightfang_stalker", "夜牙潜影", 4, 95, 12, EnemyCategory.ELITE, GameTypes.EnemyCombatType.RANGER, 50,
		[_phase(0.35, [_action(EnemyAction.ActionType.ATTACK, 18, "夜牙穿刺"), _action_fx(EnemyAction.ActionType.SKILL, 2, [_fx_status("poison", 2)])]),
		 _phase(0, [_action(EnemyAction.ActionType.ATTACK, 12), _action_fx(EnemyAction.ActionType.SKILL, 1, [_fx_status("vulnerable", 1)]), _action(EnemyAction.ActionType.ATTACK, 10)])],
		_quotes(["（从暗影中无声浮现）"], ["影子……回归了黑暗……"], ["夜牙穿刺！", "暗影突袭！"], ["嘶……不过是擦伤。"], ["最后一击——从你的影子里刺出！"]),
		true, 2)
	# ===== 章5 精英 =====
	_register("elite_titan_construct", "泰坦守护者", 5, 130, 10, EnemyCategory.ELITE, GameTypes.EnemyCombatType.GUARDIAN, 50,
		[_phase(0, [_action(EnemyAction.ActionType.DEFEND, 22), _action(EnemyAction.ActionType.ATTACK, 10), _action(EnemyAction.ActionType.ATTACK, 18, "泰坦之锤"), _action_fx(EnemyAction.ActionType.SKILL, 2, [_fx_status("weak", 2)])])],
		_quotes(["入侵者检测完毕。启动消灭程序。"], ["系统……崩溃……"], ["泰坦之锤！", "消灭目标！"], ["护盾……承受冲击……"], ["核心过载……启动自毁倒计时……"]),
		true, 2)
	_register("elite_void_walker", "虚空行者", 5, 90, 13, EnemyCategory.ELITE, GameTypes.EnemyCombatType.CASTER, 50,
		[_phase(0.35, [_action(EnemyAction.ActionType.ATTACK, 20, "虚空爆裂"), _action_fx(EnemyAction.ActionType.SKILL, 0, [_fx_curse_die()])]),
		 _phase(0, [_action(EnemyAction.ActionType.ATTACK, 13), _action_fx(EnemyAction.ActionType.SKILL, 2, [_fx_status("vulnerable", 2)]), _action(EnemyAction.ActionType.ATTACK, 10), _action_fx(EnemyAction.ActionType.SKILL, 2, [_fx_status("weak", 2)])])],
		_quotes(["虚空……无处不在……"], ["虚空……会记住你……"], ["虚空爆裂！", "维度撕裂！"], ["虚空……波动了……"], ["虚空的全部力量……释放！"]),
		true, 2)
	# [NEW] 章5 新增精英
	_register("elite_celestial_champion", "天裁斗神", 5, 115, 11, EnemyCategory.ELITE, GameTypes.EnemyCombatType.WARRIOR, 50,
		[_phase(0.35, [_action(EnemyAction.ActionType.ATTACK, 18, "天裁圣击"), _action(EnemyAction.ActionType.DEFEND, 16), _action_fx(EnemyAction.ActionType.SKILL, 2, [_fx_status("vulnerable", 2)])]),
		 _phase(0, [_action(EnemyAction.ActionType.ATTACK, 11), _action(EnemyAction.ActionType.ATTACK, 14, "圣光劈斩"), _action(EnemyAction.ActionType.DEFEND, 12)])],
		_quotes(["天裁之剑——只为审判而铸。"], ["审判……结束了……"], ["天裁圣击！", "圣光劈斩！"], ["圣甲……不过是划痕。"], ["以天裁之名——最后一剑！"]),
		true, 2)

## ============================================================
## Boss 敌人 (20只: 原10 + 新增10, 含 summons/revive 机制)
## ============================================================

static func _build_bosses() -> void:
	# ===== 章1 中Boss =====
	_register_boss("boss_lich_forest", "枯骨巫妖", 1, 120, 10, BossRank.MID, GameTypes.EnemyCombatType.CASTER, 60,
		[_phase(0.4, [_action(EnemyAction.ActionType.ATTACK, 16, "亡灵风暴"), _action_fx(EnemyAction.ActionType.SKILL, 2, [_fx_status("burn", 2)]), _action(EnemyAction.ActionType.ATTACK, 14, "骸骨之矛"), _action_fx(EnemyAction.ActionType.SKILL, 0, [_fx_curse_die()]), _action(EnemyAction.ActionType.DEFEND, 15)]),
		 _phase(0, [_action(EnemyAction.ActionType.ATTACK, 8), _action(EnemyAction.ActionType.ATTACK, 8), _action_fx(EnemyAction.ActionType.SKILL, 2, [_fx_status("weak", 2)]), _action_fx(EnemyAction.ActionType.SKILL, 1, [_fx_status("vulnerable", 1)]), _action(EnemyAction.ActionType.DEFEND, 15)])],
		_boss_quotes(
			["千年的死寂，被你这小小的活人惊扰了……不可饶恕。", "又一个不知死活的来客？我的墓园从不嫌客人多。"],
			["亡魂们，听令——把他的骨头加入我的军团。", "骷髅卫，起立。让他先和你们的旧战友打个招呼。"],
			["我的……灵魂宝石……不——！", "千年的亡灵契约……断了……"],
			["亡灵风暴！", "骸骨之矛！", "让亡灵大军吞噬你！"],
			["灵魂宝石……动摇了……", "你……竟能伤到我？"],
			["灵魂宝石……碎裂吧——释放一切死灵之力！"]),
		true, 0, _summon("forest_ghoul", 3, 1, 4, 4))
	# [NEW] 章1 中Boss: 根须巨像
	_register_boss("boss_root_colossus", "根须巨像", 1, 135, 11, BossRank.MID, GameTypes.EnemyCombatType.GUARDIAN, 55,
		[_phase(0.5, [_action(EnemyAction.ActionType.ATTACK, 14, "根须重拳"), _action(EnemyAction.ActionType.DEFEND, 24), _action(EnemyAction.ActionType.ATTACK, 12), _action_fx(EnemyAction.ActionType.SKILL, 2, [_fx_status("poison", 2)])]),
		 _phase(0, [_action(EnemyAction.ActionType.DEFEND, 14), _action(EnemyAction.ActionType.ATTACK, 10), _action_fx(EnemyAction.ActionType.SKILL, 1, [_fx_status("weak", 1)])])],
		_boss_quotes(
			["森林把你交给了我——这片土地上，每一块石头都记得我的名字。"],
			["泥像们，起。把他缠住——我走一步，泥土就长一尺。"],
			["根系……断开……", "回归大地……养育下一代……"],
			["根须重拳！", "大地摇动！", "岩裂！"],
			["表皮裂开——里面还是石头。", "一层剥落，十层依旧。"],
			["根须最深处——释放全部力量！"]),
		true, 3, null, _revive(0.5, 2, "forest_treant"))
	# [NEW] 章1 中Boss: 魅森巫母
	_register_boss("boss_coven_matriarch", "魇森巫母", 1, 115, 9, BossRank.MID, GameTypes.EnemyCombatType.CASTER, 55,
		[_phase(0.5, [_action_fx(EnemyAction.ActionType.SKILL, 2, [_fx_status("vulnerable", 2)]), _action(EnemyAction.ActionType.ATTACK, 12, "诅咒爆发"), _action_fx(EnemyAction.ActionType.SKILL, 3, [_fx_status("poison", 3)]), _action(EnemyAction.ActionType.DEFEND, 12)]),
		 _phase(0, [_action_fx(EnemyAction.ActionType.SKILL, 1, [_fx_status("weak", 1)]), _action(EnemyAction.ActionType.ATTACK, 9), _action_fx(EnemyAction.ActionType.SKILL, 2, [_fx_status("poison", 2)])])],
		_boss_quotes(
			["我养育了这片森林里所有的毒草，也养育了每一个诅咒。"],
			["女儿们——起舞。让他看看诅咒真正的模样。"],
			["诅咒……反噬了我自己……", "丝网……断了……"],
			["诅咒爆发！", "毒瘴！", "千丝缠绕！"],
			["扰我施咒……代价不小。", "一点皮肉伤。"],
			["全部的毒素——融入最后一击！"]),
		true, 3, _summon("forest_spider", 3, 1, 3, 4))
	# 章1 终Boss
	_register_boss("boss_ancient_treant", "远古树王", 1, 240, 15, BossRank.FINAL, GameTypes.EnemyCombatType.GUARDIAN, 0,
		[_phase(0.5, [_action(EnemyAction.ActionType.ATTACK, 22, "大地之怒"), _action(EnemyAction.ActionType.DEFEND, 30), _action(EnemyAction.ActionType.ATTACK, 18), _action_fx(EnemyAction.ActionType.SKILL, 3, [_fx_status("poison", 3)])]),
		 _phase(0, [_action(EnemyAction.ActionType.DEFEND, 20), _action(EnemyAction.ActionType.ATTACK, 12), _action_fx(EnemyAction.ActionType.SKILL, 2, [_fx_status("weak", 2)]), _action(EnemyAction.ActionType.ATTACK, 15)])],
		_boss_quotes_full(
			["这片森林从我萌芽的那一刻起，就吞噬了无数像你这样的来客。", "我用千年生根，你却想用几个回合砍倒我？可笑。"],
			["根须巨像也倒了？真有趣……他可是我亲手种下的卫兵。", "我感受到森林的颤抖——原来是你。"],
			["根须，缠住他。落叶，蒙住他的眼。让他成为森林的一部分。"],
			["森林……终将……重生……", "你……是第一个……砍倒我的人……"],
			["大地之怒！", "根须绞杀！", "千年之力！"],
			["不过是……树皮划痕……", "千年巨木……岂会轻倒？"],
			["划痕？你以为能砍倒我？——下一刀你会记得更深。", "这点刀伤，我千年前就开始愈合了。"],
			["大地啊——赐予我最后的力量！", "千年巨木，岂会倒于你手！"]),
		false, 0, _summon("forest_wraith_cultist", 4, 1, 3, 4, 0.5))
	# ===== 章2 中Boss =====
	_register_boss("boss_frost_queen", "霜寒女王", 2, 130, 10, BossRank.MID, GameTypes.EnemyCombatType.CASTER, 60,
		[_phase(0.4, [_action(EnemyAction.ActionType.ATTACK, 18, "暴风雪"), _action_fx(EnemyAction.ActionType.SKILL, 2, [_fx_status("freeze", 2)]), _action(EnemyAction.ActionType.ATTACK, 14), _action_fx(EnemyAction.ActionType.SKILL, 0, [_fx_status("vulnerable", 2), _fx_curse_die()]), _action(EnemyAction.ActionType.DEFEND, 16)]),
		 _phase(0, [_action(EnemyAction.ActionType.ATTACK, 9), _action_fx(EnemyAction.ActionType.SKILL, 1, [_fx_status("freeze", 1)]), _action(EnemyAction.ActionType.ATTACK, 9), _action_fx(EnemyAction.ActionType.SKILL, 2, [_fx_status("weak", 2)]), _action(EnemyAction.ActionType.DEFEND, 14)])],
		_boss_quotes(
			["这片冰原的每一寸都见证过我的加冕。你来此，无非送一具新的冰雕。"],
			["冰晶卫队——上前。让他在见到我之前，就已经被冻僵了灵魂。"],
			["寒冬……永远……不会结束……", "王冠……坠地……"],
			["暴风雪！", "冰封！", "寒冰王冠之力！"],
			["我的冰甲……裂了？", "温暖……好恶心……"],
			["冰封整个世界吧——别让一缕春风留下！"]),
		true)
	# [NEW] 章2 中Boss: 冰锤领主
	_register_boss("boss_frost_hammer", "冰锤领主", 2, 140, 12, BossRank.MID, GameTypes.EnemyCombatType.WARRIOR, 55,
		[_phase(0.5, [_action(EnemyAction.ActionType.ATTACK, 16, "冰锤粉碎"), _action_fx(EnemyAction.ActionType.SKILL, 2, [_fx_status("freeze", 2)]), _action(EnemyAction.ActionType.ATTACK, 13), _action(EnemyAction.ActionType.DEFEND, 18)]),
		 _phase(0, [_action(EnemyAction.ActionType.DEFEND, 14), _action(EnemyAction.ActionType.ATTACK, 10), _action_fx(EnemyAction.ActionType.SKILL, 1, [_fx_status("weak", 1)])])],
		_boss_quotes(
			["冰锤锻造于千年冰河——它只认一件事：敲平一切拒绝臣服之物。"],
			["冰锤士——去。我不喜欢为一个蝼蚁弯腰。"],
			["锤……落地……", "冰河……封冻了我的名字……"],
			["冰锤砸下！", "粉碎！", "跪！"],
			["区区划痕。", "锤还在。"],
			["最后一锤——把天砸下来！"]),
		true, 3, _summon("ice_avalanche_watch", 3, 1, 3, 4))
	# [NEW] 章2 中Boss: 寒霜女猎
	_register_boss("boss_winter_huntress", "寒霜女猎", 2, 120, 10, BossRank.MID, GameTypes.EnemyCombatType.RANGER, 55,
		[_phase(0.5, [_action(EnemyAction.ActionType.ATTACK, 11, "冰棱连发"), _action_fx(EnemyAction.ActionType.SKILL, 2, [_fx_status("weak", 2)]), _action(EnemyAction.ActionType.ATTACK, 13, "致命一箭"), _action(EnemyAction.ActionType.DEFEND, 10)]),
		 _phase(0, [_action(EnemyAction.ActionType.ATTACK, 9), _action_fx(EnemyAction.ActionType.SKILL, 1, [_fx_status("weak", 1)]), _action(EnemyAction.ActionType.ATTACK, 10)])],
		_boss_quotes(
			["风雪里的脚印——是我给你的最后警告。"],
			["雪狼群——上。我要先看清你的步法。"],
			["箭……偏了……", "今夜的风……怪我……"],
			["致命一箭！", "冰棱连发！", "咻——"],
			["擦伤罢了。", "距离没算准。"],
			["搭上最后一支箭——必须命中心脏！"]),
		true, 3, _summon("ice_storm_wolf", 3, 1, 3, 4))
	# 章2 终Boss
	_register_boss("boss_frost_lich", "霜之巫妖王", 2, 255, 15, BossRank.FINAL, GameTypes.EnemyCombatType.WARRIOR, 0,
		[_phase(0.5, [_action(EnemyAction.ActionType.ATTACK, 28, "霜之哀伤"), _action(EnemyAction.ActionType.ATTACK, 20), _action_fx(EnemyAction.ActionType.SKILL, 3, [_fx_status("poison", 3)]), _action(EnemyAction.ActionType.DEFEND, 28)]),
		 _phase(0, [_action(EnemyAction.ActionType.ATTACK, 14), _action_fx(EnemyAction.ActionType.SKILL, 2, [_fx_status("freeze", 2)]), _action(EnemyAction.ActionType.ATTACK, 18), _action_fx(EnemyAction.ActionType.SKILL, 2, [_fx_status("weak", 2)])])],
		_boss_quotes_full(
			["永恒寒冬以我之名加冕——而你，配不上让本王亲自挥剑。"],
			["霜寒女王败了……不过她从来都只是冰原上的一颗棋子。", "能融化她的寒霜……你的体温确实比我想的要高。"],
			["霜之死徒，去。把他的灵魂，带回我的剑里。"],
			["不……霜之哀伤……不会……", "永恒的寒冬……终结了？"],
			["霜之哀伤！", "臣服于寒冰！", "灵魂收割！"],
			["不过是……暖风拂面。", "你的抵抗……毫无意义。"],
			["暖风……居然划破了我的霜甲？有意思。", "本王千年没出过剑。今天，为了你，破例。"],
			["所有人——都将臣服于寒冰王座！", "死亡，并不是终结！"]),
		false, 0, _summon("ice_coffin_wraith", 4, 1, 3, 4, 0.5))
	# ===== 章3 中Boss =====
	_register_boss("boss_ragnaros", "炎魔之王", 3, 160, 12, BossRank.MID, GameTypes.EnemyCombatType.WARRIOR, 60,
		[_phase(0.4, [_action(EnemyAction.ActionType.ATTACK, 20, "岩浆之锤"), _action_fx(EnemyAction.ActionType.SKILL, 3, [_fx_status("burn", 3)]), _action(EnemyAction.ActionType.ATTACK, 16, "烈焰之手"), _action(EnemyAction.ActionType.DEFEND, 14)]),
		 _phase(0, [_action(EnemyAction.ActionType.ATTACK, 12), _action_fx(EnemyAction.ActionType.SKILL, 2, [_fx_status("burn", 2)]), _action(EnemyAction.ActionType.ATTACK, 10), _action(EnemyAction.ActionType.DEFEND, 12)])],
		_boss_quotes(
			["熔火之核沉睡千年——只为等一个值得灼烧的灵魂。可惜，不是你。"],
			["余烬卫，将他化作我醒来的祭品。要慢一点……我喜欢听他喊叫。"],
			["不——！岩浆……在退却……", "我会……回来的……"],
			["岩浆之锤！", "烈焰冲击！", "燃烧吧——！"],
			["渣渣！你敢伤我？", "这点伤……不算什么！"],
			["烈焰最后的爆发——焚尽一切！"]),
		true)
	# [NEW] 章3 中Boss: 岩浆暴君
	_register_boss("boss_magma_tyrant", "岩浆暴君", 3, 145, 13, BossRank.MID, GameTypes.EnemyCombatType.GUARDIAN, 55,
		[_phase(0.5, [_action(EnemyAction.ActionType.ATTACK, 16, "熔岩巨锤"), _action(EnemyAction.ActionType.DEFEND, 26), _action_fx(EnemyAction.ActionType.SKILL, 3, [_fx_status("burn", 3)]), _action(EnemyAction.ActionType.ATTACK, 12)]),
		 _phase(0, [_action(EnemyAction.ActionType.DEFEND, 18), _action(EnemyAction.ActionType.ATTACK, 10), _action_fx(EnemyAction.ActionType.SKILL, 2, [_fx_status("weak", 2)])])],
		_boss_quotes(
			["熔岩从我足下流出——我走一步，大地就要塌一层。"],
			["熔岩犬，去。我要看看你能撑到第几口火焰。"],
			["熔岩……降温了……", "王座……成灰……"],
			["熔岩巨锤！", "熔地！", "跪下！"],
			["钢铁外壳，不过皮毛被烧。", "一点小伤，不影响我沉睡。"],
			["最后一锤——把我连同熔岩砸向你！"]),
		true, 3, _summon("lava_hound", 3, 1, 3, 4))
	# [NEW] 章3 中Boss: 魂炉术士
	_register_boss("boss_soulforge_warlock", "魂炉术士", 3, 120, 10, BossRank.MID, GameTypes.EnemyCombatType.CASTER, 55,
		[_phase(0.5, [_action_fx(EnemyAction.ActionType.SKILL, 0, [_fx_curse_die()]), _action(EnemyAction.ActionType.ATTACK, 12, "魂炉熔诅"), _action_fx(EnemyAction.ActionType.SKILL, 3, [_fx_status("burn", 3)]), _action(EnemyAction.ActionType.DEFEND, 12)]),
		 _phase(0, [_action(EnemyAction.ActionType.ATTACK, 10), _action_fx(EnemyAction.ActionType.SKILL, 2, [_fx_status("vulnerable", 2)]), _action_fx(EnemyAction.ActionType.SKILL, 2, [_fx_status("burn", 2)])])],
		_boss_quotes(
			["我把灵魂丢进熔炉——看它融成什么，就成什么。"],
			["锻灵们，起。先把他的意志敲软。"],
			["炉——冷了……", "灵魂……炸开……"],
			["魂炉熔诅！", "炼魂刃！", "熔！"],
			["炉盖松动，不算大事。", "刺我一下？我回你一炉。"],
			["最后的魂焰——把我自己一起炼进去！"]),
		true, 3, _summon("lava_imp", 3, 1, 4, 4))
	# 章3 终Boss
	_register_boss("boss_deathwing", "熔火死翼", 3, 305, 16, BossRank.FINAL, GameTypes.EnemyCombatType.CASTER, 0,
		[_phase(0.5, [_action(EnemyAction.ActionType.ATTACK, 30, "大灾变"), _action(EnemyAction.ActionType.ATTACK, 22), _action_fx(EnemyAction.ActionType.SKILL, 4, [_fx_status("burn", 4)]), _action(EnemyAction.ActionType.DEFEND, 30)]),
		 _phase(0, [_action_fx(EnemyAction.ActionType.SKILL, 3, [_fx_status("burn", 3)]), _action(EnemyAction.ActionType.ATTACK, 14), _action_fx(EnemyAction.ActionType.SKILL, 2, [_fx_status("vulnerable", 2)]), _action(EnemyAction.ActionType.ATTACK, 20, "熔岩吐息")])],
		_boss_quotes_full(
			["大地在我翼下战栗，王城在我焰下成灰。区区凡夫，妄图与我对视？"],
			["熔岩巨魔的咆哮……竟然停了。看来你确实让深渊有点意外。", "你居然能在岩浆里活着走过来？……有点意思。"],
			["黑龙仆从——上。让他先体会一次'灾难'，再来我面前承受第二次。"],
			["不……我是……大地的毁灭者……怎么会……", "鳞片……在剥落……"],
			["大灾变！", "熔岩吐息！", "世界……在燃烧！"],
			["你伤到了……我的钢铁之躯？", "可笑……"],
			["你……竟然能在我翼下留下伤痕？", "鳞片掉一片不算什么——真正的灾变还没开始。"],
			["即使我倒下——世界也已面目全非！"]),
		false, 0, _summon("lava_imp", 4, 1, 4, 4, 0.5))
	# ===== 章4 中Boss =====
	_register_boss("boss_archimonde", "深渊领主", 4, 160, 11, BossRank.MID, GameTypes.EnemyCombatType.CASTER, 60,
		[_phase(0.4, [_action(EnemyAction.ActionType.ATTACK, 18, "暗影之手"), _action_fx(EnemyAction.ActionType.SKILL, 2, [_fx_status("burn", 2)]), _action(EnemyAction.ActionType.ATTACK, 14, "邪能风暴"), _action_fx(EnemyAction.ActionType.SKILL, 0, [_fx_curse_die()]), _action(EnemyAction.ActionType.DEFEND, 16)]),
		 _phase(0, [_action(EnemyAction.ActionType.ATTACK, 10), _action_fx(EnemyAction.ActionType.SKILL, 2, [_fx_status("weak", 2)]), _action(EnemyAction.ActionType.ATTACK, 9), _action_fx(EnemyAction.ActionType.SKILL, 2, [_fx_status("poison", 2)]), _action(EnemyAction.ActionType.DEFEND, 14)])],
		_boss_quotes(
			["燃烧军团跨越万千星海——而你的命，连一星烬火都不值。"],
			["邪能爪牙，去吞噬他。让他在死前明白：抵抗，本就是亵渎。"],
			["不……军团……不会……", "我会……在扭曲虚空中……重生！"],
			["暗影之手！", "邪能风暴！", "毁灭一切！"],
			["你……竟敢？", "渺小的虫子……"],
			["燃烧吧——用你的世界作为我的燃料！"]),
		true)
	# [NEW] 章4 中Boss: 虚空审判官
	_register_boss("boss_void_inquisitor", "虚空审判官", 4, 135, 11, BossRank.MID, GameTypes.EnemyCombatType.PRIEST, 55,
		[_phase(0.5, [_action_fx(EnemyAction.ActionType.SKILL, 2, [_fx_status("vulnerable", 2)]), _action(EnemyAction.ActionType.ATTACK, 13, "虚空审决"), _action_fx(EnemyAction.ActionType.SKILL, 3, [_fx_status("poison", 3)]), _action(EnemyAction.ActionType.DEFEND, 18)]),
		 _phase(0, [_action_fx(EnemyAction.ActionType.SKILL, 1, [_fx_status("weak", 1)]), _action(EnemyAction.ActionType.ATTACK, 10), _action_fx(EnemyAction.ActionType.SKILL, 2, [_fx_status("poison", 2)])])],
		_boss_quotes(
			["虚空议会——已对你作出终审判决。"],
			["执法侍者，出列。让他先感受'审判'这个词的重量。"],
			["判决……被撤回了？……", "第一次……有人推翻了我的判决……"],
			["虚空审决！", "宣判！", "罪有应得！"],
			["不敬——记录在案。", "污了圣服，加重罪行。"],
			["以我性命——作最后一纸判决！"]),
		true, 3, _summon("shadow_assassin", 3, 1, 3, 4))
	# [NEW] 章4 中Boss: 混沌谋略家
	_register_boss("boss_chaos_tactician", "混沌谋略家", 4, 125, 10, BossRank.MID, GameTypes.EnemyCombatType.CASTER, 55,
		[_phase(0.5, [_action(EnemyAction.ActionType.ATTACK, 12, "混乱之触"), _action_fx(EnemyAction.ActionType.SKILL, 0, [_fx_curse_die()]), _action_fx(EnemyAction.ActionType.SKILL, 2, [_fx_status("weak", 2)]), _action(EnemyAction.ActionType.ATTACK, 10)]),
		 _phase(0, [_action(EnemyAction.ActionType.ATTACK, 9), _action_fx(EnemyAction.ActionType.SKILL, 2, [_fx_status("vulnerable", 2)]), _action(EnemyAction.ActionType.DEFEND, 12)])],
		_boss_quotes(
			["我不需要你理解我的棋局——你的任务是成为一枚被牺牲的子。"],
			["小卒们——布阵。我的价值不在于挥剑，在于预言谁该倒下。"],
			["这一步——我没算进去……", "棋盘……被掀翻了……"],
			["混乱之触！", "将军！", "落子！"],
			["这一子——我低估了。", "走得太急，我容后调整。"],
			["最后一子——把整个棋盘翻过来！"]),
		true, 3, _summon("shadow_warlock", 3, 1, 3, 4))
	# 章4 终Boss
	_register_boss("boss_kiljaeden", "暗影之王", 4, 305, 16, BossRank.FINAL, GameTypes.EnemyCombatType.CASTER, 0,
		[_phase(0.5, [_action(EnemyAction.ActionType.ATTACK, 28, "黑暗终焉"), _action(EnemyAction.ActionType.ATTACK, 22), _action_fx(EnemyAction.ActionType.SKILL, 3, [_fx_status("poison", 3)]), _action(EnemyAction.ActionType.DEFEND, 30)]),
		 _phase(0, [_action_fx(EnemyAction.ActionType.SKILL, 4, [_fx_status("burn", 4)]), _action(EnemyAction.ActionType.ATTACK, 14), _action_fx(EnemyAction.ActionType.SKILL, 2, [_fx_status("weak", 2)]), _action(EnemyAction.ActionType.ATTACK, 20, "邪能陨石")])],
		_boss_quotes_full(
			["你以为是你选择了走到这里？……不。这是我编织的剧本，第七幕，独你一人。"],
			["剧本走到一半就杀掉伪装者……你确实比剧本设计的更聪明。", "让我看看——你以为这就是真相？真正的剧本第七幕才刚开。"],
			["幻影们——上场吧。先让他怀疑自己存在，再让他怀疑自己死亡。"],
			["虚空……会记住……这一天……", "不可能……欺骗者……怎会被欺骗……"],
			["黑暗终焉！", "邪能陨石！", "所有生命——终结吧！"],
			["有趣……你确实……有些能耐。", "欺骗者……不惧伤痛。"],
			["剧本……出现了偏差？这页我没写过。", "有趣。你打破了第一幕的预设。第二幕会更黑。"],
			["用虚空的全部力量——毁灭这个世界！"]),
		false, 0, null, _revive(0.5, 2, "shadow_assassin"))
	# ===== 章5 中Boss =====
	_register_boss("boss_titan_watcher", "泰坦看守者", 5, 160, 12, BossRank.MID, GameTypes.EnemyCombatType.GUARDIAN, 60,
		[_phase(0.4, [_action(EnemyAction.ActionType.ATTACK, 18, "泰坦审判"), _action(EnemyAction.ActionType.DEFEND, 22), _action(EnemyAction.ActionType.ATTACK, 16, "秩序之光"), _action_fx(EnemyAction.ActionType.SKILL, 2, [_fx_status("vulnerable", 2)])]),
		 _phase(0, [_action(EnemyAction.ActionType.DEFEND, 18), _action(EnemyAction.ActionType.ATTACK, 10), _action_fx(EnemyAction.ActionType.SKILL, 2, [_fx_status("weak", 2)]), _action(EnemyAction.ActionType.ATTACK, 12)])],
		_boss_quotes(
			["泰坦的秩序写在我的核心。你的存在——是宇宙级的拼写错误。"],
			["执行肃清协议。子程序——出动。在他抵达本体之前，将其格式化。"],
			["秩序……被打破了……", "运行异常……核心……离线……"],
			["泰坦审判！", "秩序之光！", "修正错误！"],
			["损伤……在可控范围内……", "你的力量……超出预期……"],
			["启动——最终审判协议！"]),
		true)
	# [NEW] 章5 中Boss: 时流执政
	_register_boss("boss_chrono_archon", "时流执政", 5, 145, 12, BossRank.MID, GameTypes.EnemyCombatType.CASTER, 55,
		[_phase(0.5, [_action(EnemyAction.ActionType.ATTACK, 14, "时流撕裂"), _action_fx(EnemyAction.ActionType.SKILL, 2, [_fx_status("vulnerable", 2)]), _action(EnemyAction.ActionType.DEFEND, 18), _action(EnemyAction.ActionType.ATTACK, 11)]),
		 _phase(0, [_action(EnemyAction.ActionType.ATTACK, 10), _action_fx(EnemyAction.ActionType.SKILL, 2, [_fx_status("weak", 2)]), _action(EnemyAction.ActionType.ATTACK, 12)])],
		_boss_quotes(
			["时流在我手里是一卷可以翻阅的书——你的结局，我已经读到最后一页。"],
			["时流侍从——从过去与未来同时召唤出来。"],
			["这一页……没有记录过……", "骰子……比时间更早一步……"],
			["时流撕裂！", "时之刃！", "翻页！"],
			["时差……被扰了一步。", "剧本没写到这。"],
			["把所有时流——逆向灌入最后一击！"]),
		true, 3, _summon("eternal_chronomancer", 3, 1, 3, 4))
	# [NEW] 章5 中Boss: 圣辉执政
	_register_boss("boss_celestial_archon", "圣辉执政", 5, 135, 11, BossRank.MID, GameTypes.EnemyCombatType.PRIEST, 55,
		[_phase(0.5, [_action_fx(EnemyAction.ActionType.SKILL, 2, [_fx_status("vulnerable", 2)]), _action(EnemyAction.ActionType.ATTACK, 13, "圣辉审判"), _action(EnemyAction.ActionType.DEFEND, 20), _action_fx(EnemyAction.ActionType.SKILL, 3, [_fx_status("poison", 3)])]),
		 _phase(0, [_action_fx(EnemyAction.ActionType.SKILL, 1, [_fx_status("weak", 1)]), _action(EnemyAction.ActionType.ATTACK, 10), _action(EnemyAction.ActionType.DEFEND, 14)])],
		_boss_quotes(
			["圣辉议会——已将你列于'可以审判之物'的末位。"],
			["圣辉护卫——执行初审。我只处理不可饶恕的罪人。"],
			["议会……撤回我的判例了……", "我的审判……第一次被推翻……"],
			["圣辉审判！", "审决！", "宣判！"],
			["对圣者动手——罪加一等。", "圣服破了一角——不影响判决。"],
			["以我性命——把最后一纸判决印在他灵魂上！"]),
		true, 3, _summon("eternal_lightcantor", 3, 1, 3, 4))
	# 章5 终Boss
	_register_boss("boss_eternal_lord", "永恒主宰", 5, 385, 18, BossRank.FINAL, GameTypes.EnemyCombatType.CASTER, 0,
		[_phase(0.5, [_action(EnemyAction.ActionType.ATTACK, 28, "终极之光"), _action(EnemyAction.ActionType.ATTACK, 22), _action_fx(EnemyAction.ActionType.SKILL, 3, [_fx_status("poison", 3)]), _action(EnemyAction.ActionType.DEFEND, 30)]),
		 _phase(0, [_action_fx(EnemyAction.ActionType.SKILL, 4, [_fx_status("burn", 4)]), _action(EnemyAction.ActionType.ATTACK, 14), _action_fx(EnemyAction.ActionType.SKILL, 2, [_fx_status("weak", 2)]), _action(EnemyAction.ActionType.ATTACK, 20)])],
		_boss_quotes_full(
			["每个时代都有人走到这里。每个走到这里的人，最后都成了我王座上的灰。"],
			["果然如时间所示——你走到了这里。但你不会走过下一步。", "骰子的轨迹我看了亿万遍。这一掷，仍然是同样的结局。"],
			["永恒侍从——出列。让他先与时间为敌，再与我，为终结。"],
			["不……不可能……永恒……怎么会……", "你……究竟……是什么？……永恒……也有尽头……"],
			["终极之光！", "永恒之力，碾碎你！", "渺小者，跪下！"],
			["哼……有点意思。", "永恒之躯……竟被撼动……"],
			["骰子……真的伤到我了？让我记下这一刻——它很快会被抹去。", "有趣……所有时代里，没人让我走到这一步。"],
			["永恒动摇了——但我绝不会就此终结！终极之光——爆发！"]),
		false, 0, _summon("eternal_chronomancer", 4, 1, 3, 4, 0.7), _revive(0.5, 2, "eternal_skyknight"))


## ============================================================
## 辅助构造函数
## ============================================================

static func _register(id: String, name: String, chapter: int, base_hp: int, base_dmg: int, category: EnemyCategory, combat_type: GameTypes.EnemyCombatType, drop_gold: int, phases: Array[EnemyPhase], quotes: EnemyQuotes, drop_relic: bool = false, drop_reroll: int = 0) -> void:
	var c := EnemyConfig.new()
	c.id = id; c.name = name; c.chapter = chapter; c.base_hp = base_hp; c.base_dmg = base_dmg
	c.category = category; c.combat_type = combat_type; c.drop_gold = drop_gold
	c.drop_relic = drop_relic; c.drop_reroll_reward = drop_reroll
	c.phases = phases; c.quotes = quotes
	_all_configs[id] = c

static func _register_boss(id: String, name: String, chapter: int, base_hp: int, base_dmg: int, rank: BossRank, combat_type: GameTypes.EnemyCombatType, drop_gold: int, phases: Array[EnemyPhase], quotes: EnemyQuotes, drop_relic: bool = false, drop_reroll: int = 0, p_summons: EnemySummon = null, p_revive: EnemyRevive = null) -> void:
	var c := EnemyConfig.new()
	c.id = id; c.name = name; c.chapter = chapter; c.base_hp = base_hp; c.base_dmg = base_dmg
	c.category = EnemyCategory.BOSS; c.boss_rank = rank
	c.combat_type = combat_type; c.drop_gold = drop_gold
	c.drop_relic = drop_relic; c.drop_reroll_reward = drop_reroll
	c.phases = phases; c.quotes = quotes
	c.summons = p_summons; c.revive = p_revive
	_all_configs[id] = c

static func _phase(hp_threshold: float, actions: Array[EnemyAction]) -> EnemyPhase:
	var p := EnemyPhase.new()
	p.hp_threshold = hp_threshold; p.actions = actions
	return p

static func _action(type: int, base_value: int, description: String = "", scalable: bool = true) -> EnemyAction:
	var a := EnemyAction.new()
	a.type = type; a.base_value = base_value; a.description = description; a.scalable = scalable
	return a

## [v2] 带 effects 数组的行动构造 — 直接走 EffectEngine，不经过 description 字符串匹配
static func _action_fx(type: int, base_value: int, effects: Array[Dictionary], scalable: bool = true) -> EnemyAction:
	var a := EnemyAction.new()
	a.type = type; a.base_value = base_value; a.scalable = scalable; a.effects = effects
	return a

## [v2] 效果构建快捷方法 — 消除配置中的 EffectTypes 冗长引用
## 攻击效果
static func _fx_attack(value: int) -> Dictionary:
	return EffectTypes.create_effect(EffectTypes.EffectType.BONUS_DAMAGE,
		{"value": value},
		EffectTypes.TriggerType.ON_PLAY, EffectTypes.EffectScope.INSTANT)

## 防御效果（给自己加护甲）
static func _fx_defend(value: int) -> Dictionary:
	return EffectTypes.create_effect(EffectTypes.EffectType.ARMOR,
		{"value": value},
		EffectTypes.TriggerType.ON_PLAY, EffectTypes.EffectScope.INSTANT)

## 防御效果（给随机友军加护甲）
static func _fx_defend_ally(value: int) -> Dictionary:
	return EffectTypes.create_effect(EffectTypes.EffectType.ARMOR,
		{"value": value},
		EffectTypes.TriggerType.ON_PLAY, EffectTypes.EffectScope.INSTANT,
		EffectTypes.StackingRule.INDEPENDENT, EffectTypes.TargetScope.RANDOM_ALLY)

## 施加状态效果（给玩家）
static func _fx_status(status: String, value: int) -> Dictionary:
	return EffectTypes.create_effect(EffectTypes.EffectType.APPLY_STATUS,
		{"status": status, "value": value, "target": "enemy"},
		EffectTypes.TriggerType.ON_PLAY, EffectTypes.EffectScope.INSTANT)

## 嘲讽效果
static func _fx_taunt() -> Dictionary:
	return EffectTypes.create_effect(EffectTypes.EffectType.CONTROL,
		{"control": "taunt", "duration": 1, "target": "self"},
		EffectTypes.TriggerType.ON_PLAY, EffectTypes.EffectScope.INSTANT)

## 治疗效果（给血量最低友军）
static func _fx_heal_ally(value: int) -> Dictionary:
	return EffectTypes.create_effect(EffectTypes.EffectType.HEAL,
		{"value": value},
		EffectTypes.TriggerType.ON_PLAY, EffectTypes.EffectScope.INSTANT,
		EffectTypes.StackingRule.INDEPENDENT, EffectTypes.TargetScope.ALLY_LOWEST_HP)

## 治疗效果（给自己）
static func _fx_heal_self(value: int) -> Dictionary:
	return EffectTypes.create_effect(EffectTypes.EffectType.HEAL,
		{"value": value},
		EffectTypes.TriggerType.ON_PLAY, EffectTypes.EffectScope.INSTANT)

## 塞诅咒骰
static func _fx_curse_die(die_id: String = "cursed", count: int = 1) -> Dictionary:
	return EffectTypes.create_effect(EffectTypes.EffectType.INSERT_CURSE_DIE,
		{"die_id": die_id, "count": count},
		EffectTypes.TriggerType.ON_PLAY, EffectTypes.EffectScope.INSTANT)

static func _quotes(enter: Array[String], death: Array[String], attack: Array[String], hurt: Array[String], low_hp: Array[String]) -> EnemyQuotes:
	var q := EnemyQuotes.new()
	q.enter = enter; q.death = death; q.attack = attack; q.hurt = hurt; q.low_hp = low_hp
	return q

## Boss 台词构造（无 midBossWarning / phase2_taunt）
static func _boss_quotes(greet: Array[String], dispatch: Array[String], death: Array[String], attack: Array[String], hurt: Array[String], low_hp: Array[String]) -> EnemyQuotes:
	var q := EnemyQuotes.new()
	q.greet = greet; q.dispatch = dispatch
	var enter_arr: Array[String] = []
	if greet.size() > 0 and dispatch.size() > 0:
		enter_arr.append(greet[0]); enter_arr.append(dispatch[0])
	else:
		enter_arr = greet
	q.enter = enter_arr
	q.death = death; q.attack = attack; q.hurt = hurt; q.low_hp = low_hp
	return q

## 终Boss 台词构造（含 midBossWarning + phase2_taunt）
static func _boss_quotes_full(greet: Array[String], mid_boss_warning: Array[String], dispatch: Array[String], death: Array[String], attack: Array[String], hurt: Array[String], phase2_taunt: Array[String], low_hp: Array[String]) -> EnemyQuotes:
	var q := EnemyQuotes.new()
	q.greet = greet; q.mid_boss_warning = mid_boss_warning; q.dispatch = dispatch
	var enter_arr: Array[String] = []
	if greet.size() > 0 and dispatch.size() > 0:
		enter_arr.append(greet[0]); enter_arr.append(dispatch[0])
	else:
		enter_arr = greet
	q.enter = enter_arr
	q.death = death; q.attack = attack; q.hurt = hurt
	q.phase2_taunt = phase2_taunt; q.low_hp = low_hp
	return q

static func _summon(minion_id: String, interval: int, count: int, max_total: int, wave_cap: int, hp_threshold: float = 0.0) -> EnemySummon:
	var s := EnemySummon.new()
	s.minion_id = minion_id; s.interval = interval; s.count = count
	s.max_total = max_total; s.wave_cap = wave_cap; s.hp_threshold = hp_threshold
	return s

static func _revive(revive_hp_ratio: float, split_into: int, split_minion_id: String) -> EnemyRevive:
	var r := EnemyRevive.new()
	r.revive_hp_ratio = revive_hp_ratio; r.split_into = split_into; r.split_minion_id = split_minion_id
	return r