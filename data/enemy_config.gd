## 敌人配置资源 — 对应原版 config/enemyTypes.ts + config/enemyNormal.ts + config/enemyEliteBoss.ts

class_name EnemyConfig
extends Resource

enum EnemyCategory { NORMAL, ELITE, BOSS }

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


## ============================================================
## 所有敌人配置注册表
## ============================================================

# 开关：true=从 Excel → JSON 加载，false=走硬编码构建
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
	return _all_configs.values().filter(func(c): return c.category == EnemyCategory.NORMAL and c.chapter == chapter)

static func get_elites_for_chapter(chapter: int) -> Array[EnemyConfig]:
	return _all_configs.values().filter(func(c): return c.category == EnemyCategory.ELITE and c.chapter == chapter)

static func get_bosses_for_chapter(chapter: int) -> Array[EnemyConfig]:
	return _all_configs.values().filter(func(c): return c.category == EnemyCategory.BOSS and c.chapter == chapter)

static func _build_all_configs() -> void:
	# ===== 章1: 幽暗森林 =====
	_register("forest_ghoul", "食尸鬼", 1, 28, 7, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.WARRIOR, 20,
		[_phase(0, [_action(EnemyAction.ActionType.ATTACK, 7), _action(EnemyAction.ActionType.ATTACK, 9, "撕咬"), _action(EnemyAction.ActionType.SKILL, 1, "虚弱", false)])],
		_quotes(["嘎嘎……新鲜的肉……", "从坟墓里爬出来了……"], ["骨头……散了……", "回到……土里……"], ["撕！", "咬碎你！", "嘎嘎嘎！"], ["嘎！", "腐肉……掉了……"], ["不……还没吃饱……"]))
	_register("forest_spider", "剧毒蛛母", 1, 18, 3, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.RANGER, 20,
		[_phase(0, [_action(EnemyAction.ActionType.SKILL, 2, "剧毒", false), _action(EnemyAction.ActionType.ATTACK, 4), _action(EnemyAction.ActionType.ATTACK, 4)])],
		_quotes(["嘶嘶……陷阱已经布好了……"], ["嘶……蛛卵……会替我……"], ["毒牙！", "吐丝！", "缠住你！"], ["嘶！", "我的……腿！"], ["蛛巢……不会忘记你……"]))
	_register("forest_treant", "腐化树人", 1, 42, 4, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.GUARDIAN, 20,
		[_phase(0, [_action(EnemyAction.ActionType.DEFEND, 8), _action(EnemyAction.ActionType.ATTACK, 5), _action(EnemyAction.ActionType.DEFEND, 6), _action(EnemyAction.ActionType.ATTACK, 7, "根须缠绕")])],
		_quotes(["这片……森林……不欢迎你……"], ["森林……会记住……"], ["根须！", "大地之力！"], ["树皮……裂了……"], ["我的根……断了……"]))
	_register("forest_banshee", "哀嚎女妖", 1, 16, 3, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.CASTER, 20,
		[_phase(0, [_action(EnemyAction.ActionType.SKILL, 1, "易伤", false), _action(EnemyAction.ActionType.ATTACK, 5), _action(EnemyAction.ActionType.SKILL, 1, "虚弱", false)])],
		_quotes(["啊啊啊——！"], ["终于……安息了……"], ["尖叫！", "死亡之歌！"], ["（刺耳尖啸）"], ["最后……一曲……"]))
	_register("forest_wolf_priest", "月光狼灵", 1, 20, 2, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.PRIEST, 20,
		[_phase(0, [_action(EnemyAction.ActionType.SKILL, 2, "剧毒", false), _action(EnemyAction.ActionType.SKILL, 1, "易伤", false), _action(EnemyAction.ActionType.ATTACK, 4)])],
		_quotes(["呜——月光指引着我……"], ["月光……暗了……"], ["狼牙！", "月光之噬！"], ["嗷！"], ["月光……给我力量……"]))
	# ===== 章2: 冰封山脉 =====
	_register("ice_yeti", "雪原雪人", 2, 36, 9, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.WARRIOR, 20,
		[_phase(0, [_action(EnemyAction.ActionType.ATTACK, 9), _action(EnemyAction.ActionType.ATTACK, 11, "冰拳")])],
		_quotes(["吼————！"], ["冰……碎了……"], ["砸！", "冰拳！", "吼！"], ["吼！疼！"], ["不会……倒下……"]))
	_register("ice_mage", "霜寒女巫", 2, 18, 4, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.CASTER, 20,
		[_phase(0, [_action(EnemyAction.ActionType.SKILL, 1, "冻结", false), _action(EnemyAction.ActionType.ATTACK, 6), _action(EnemyAction.ActionType.SKILL, 2, "虚弱", false)])],
		_quotes(["冰霜……会冻结一切……"], ["冰……碎了……"], ["冰锥！", "寒冰箭！"], ["冰盾……裂了……"], ["暴风雪……最后的咏唱……"]))
	_register("ice_wolf", "霜鬃狼", 2, 22, 5, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.RANGER, 20,
		[_phase(0, [_action(EnemyAction.ActionType.ATTACK, 5), _action(EnemyAction.ActionType.ATTACK, 7, "冰霜撕咬"), _action(EnemyAction.ActionType.SKILL, 1, "灼烧", false)])],
		_quotes(["（低沉的咆哮）"], ["呜……"], ["嗷！", "撕咬！", "冰牙！"], ["嗷呜！"], ["群狼……会替我报仇……"]))
	_register("ice_golem", "寒冰石像", 2, 44, 4, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.GUARDIAN, 20,
		[_phase(0, [_action(EnemyAction.ActionType.DEFEND, 10), _action(EnemyAction.ActionType.ATTACK, 5), _action(EnemyAction.ActionType.DEFEND, 8)])],
		_quotes(["（冰晶嘎吱作响）"], ["（碎裂成冰块）"], ["碾压！", "冰拳！"], ["裂缝……"], ["还能……守住……"]))
	# ===== 章3: 熔岩深渊 =====
	_register("lava_hound", "地狱火犬", 3, 30, 8, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.WARRIOR, 20,
		[_phase(0, [_action(EnemyAction.ActionType.ATTACK, 8), _action(EnemyAction.ActionType.ATTACK, 10, "烈焰撕咬"), _action(EnemyAction.ActionType.SKILL, 2, "灼烧", false)])],
		_quotes(["（烈焰从口中喷出）"], ["火……灭了……"], ["烈焰！", "烧！", "吞噬！"], ["（痛苦嚎叫）"], ["最后……一口火焰……"]))
	_register("lava_imp", "小恶魔", 3, 16, 4, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.CASTER, 20,
		[_phase(0, [_action(EnemyAction.ActionType.SKILL, 2, "灼烧", false), _action(EnemyAction.ActionType.ATTACK, 5), _action(EnemyAction.ActionType.SKILL, 1, "易伤", false), _action(EnemyAction.ActionType.ATTACK, 6, "火球")])],
		_quotes(["嘻嘻嘻！又来送死的！"], ["嘻……不好玩了……"], ["接火球！", "嘻嘻！烫吧！"], ["哎呀！"], ["不行了……要逃了……才怪！"]))
	_register("lava_guardian", "黑铁卫士", 3, 48, 5, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.GUARDIAN, 20,
		[_phase(0, [_action(EnemyAction.ActionType.DEFEND, 12), _action(EnemyAction.ActionType.ATTACK, 6), _action(EnemyAction.ActionType.DEFEND, 8), _action(EnemyAction.ActionType.ATTACK, 8, "锻造重击")])],
		_quotes(["黑铁之盾，坚不可摧！"], ["盾……碎了……"], ["锤击！", "黑铁之力！"], ["叮！"], ["只要……盾还在……就不会倒！"]))
	_register("lava_shaman", "火焰萨满", 3, 22, 3, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.PRIEST, 20,
		[_phase(0, [_action(EnemyAction.ActionType.SKILL, 2, "灼烧", false), _action(EnemyAction.ActionType.SKILL, 1, "力量", false), _action(EnemyAction.ActionType.ATTACK, 5)])],
		_quotes(["烈焰之灵……降临吧！"], ["火灵……离开了我……"], ["烈焰冲击！", "焚烧！"], ["火盾……碎了……"], ["最后的祈祷……"]))
	# ===== 章4: 暗影要塞 =====
	_register("shadow_assassin", "暗影刺客", 4, 24, 12, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.RANGER, 20,
		[_phase(0, [_action(EnemyAction.ActionType.ATTACK, 12, "背刺"), _action(EnemyAction.ActionType.SKILL, 2, "剧毒", false), _action(EnemyAction.ActionType.ATTACK, 8)])],
		_quotes(["（从阴影中浮现）"], ["影子……消散了……"], ["背刺！", "影杀！"], ["嘶……被发现了……"], ["影遁……最后一击……"]))
	_register("shadow_felguard", "邪能卫兵", 4, 46, 6, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.GUARDIAN, 20,
		[_phase(0, [_action(EnemyAction.ActionType.ATTACK, 7), _action(EnemyAction.ActionType.DEFEND, 14), _action(EnemyAction.ActionType.ATTACK, 9, "邪能重斩")])],
		_quotes(["受主人之命……消灭一切入侵者！"], ["主人……恕我……"], ["邪能斩！", "毁灭！"], ["邪能护甲……"], ["主人的力量……赐予我……"]))
	_register("shadow_warlock", "邪能术士", 4, 20, 5, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.CASTER, 20,
		[_phase(0, [_action(EnemyAction.ActionType.SKILL, 2, "剧毒", false), _action(EnemyAction.ActionType.ATTACK, 6), _action(EnemyAction.ActionType.SKILL, 2, "灼烧", false), _action(EnemyAction.ActionType.ATTACK, 7, "暗影箭")])],
		_quotes(["邪能……是最强大的力量！"], ["不……我的灵魂……"], ["暗影箭！", "燃烧吧！"], ["灵魂石……碎了……"], ["生命分流！"]))
	_register("shadow_knight", "堕落死亡骑士", 4, 34, 10, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.WARRIOR, 20,
		[_phase(0, [_action(EnemyAction.ActionType.ATTACK, 10), _action(EnemyAction.ActionType.SKILL, 1, "虚弱", false), _action(EnemyAction.ActionType.ATTACK, 12, "凋零打击")])],
		_quotes(["曾经……我也是光明的骑士……"], ["光……我又看到了……光……"], ["凋零！", "黑暗之力！"], ["这具身体……已经不怕痛了……"], ["即便倒下……黑暗……也不会消失……"]))
	# ===== 章5: 永恒之巅 =====
	_register("eternal_sentinel", "光铸哨兵", 5, 40, 8, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.GUARDIAN, 20,
		[_phase(0, [_action(EnemyAction.ActionType.DEFEND, 14), _action(EnemyAction.ActionType.ATTACK, 8), _action(EnemyAction.ActionType.DEFEND, 10), _action(EnemyAction.ActionType.ATTACK, 10, "圣光裁决")])],
		_quotes(["此地……不可侵犯。"], ["任务……失败……"], ["裁决！", "净化！"], ["圣光护盾……动摇了……"], ["即使倒下……光明……永不熄灭……"]))
	_register("eternal_chrono", "时光龙人", 5, 26, 7, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.CASTER, 20,
		[_phase(0, [_action(EnemyAction.ActionType.SKILL, 2, "虚弱", false), _action(EnemyAction.ActionType.ATTACK, 8, "时光冲击"), _action(EnemyAction.ActionType.SKILL, 1, "冻结", false)])],
		_quotes(["你的时间线……出了偏差……"], ["时间线……修复了……"], ["时光逆转！", "沙漏之力！"], ["时间流……紊乱了……"], ["最后的沙粒……"]))
	_register("eternal_archer", "星界游侠", 5, 22, 10, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.RANGER, 20,
		[_phase(0, [_action(EnemyAction.ActionType.ATTACK, 10), _action(EnemyAction.ActionType.ATTACK, 12, "星辰之箭"), _action(EnemyAction.ActionType.SKILL, 1, "易伤", false)])],
		_quotes(["星光……指引我的箭矢……"], ["星辰……暗了……"], ["星箭！", "穿透！"], ["嘶……"], ["最后一箭……"]))
	_register("eternal_priest", "泰坦祭司", 5, 24, 3, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.PRIEST, 20,
		[_phase(0, [_action(EnemyAction.ActionType.SKILL, 2, "力量", false), _action(EnemyAction.ActionType.SKILL, 1, "易伤", false), _action(EnemyAction.ActionType.ATTACK, 6, "圣光惩击")])],
		_quotes(["泰坦的意志……不容亵渎。"], ["泰坦……我……回来了……"], ["惩击！", "圣光！"], ["信仰……不会动摇……"], ["圣光……赐予我……"]))
	# ===== 精英 =====
	_register("elite_necromancer", "亡灵巫师", 1, 85, 8, EnemyCategory.ELITE, GameTypes.EnemyCombatType.CASTER, 50,
		[_phase(0.4, [_action(EnemyAction.ActionType.ATTACK, 14, "亡灵大军"), _action(EnemyAction.ActionType.SKILL, 3, "剧毒", false)]),
		 _phase(0, [_action(EnemyAction.ActionType.ATTACK, 8), _action(EnemyAction.ActionType.SKILL, 2, "虚弱", false), _action(EnemyAction.ActionType.DEFEND, 12)])],
		_quotes(["死者……听从我的召唤！"], ["我的……亡灵们……"], ["亡灵术！", "腐蚀！", "黑暗吞噬！"], ["骨盾……碎了？"], ["用我的骸骨……召唤最后的亡灵！"]),
		true, 2)
	_register("elite_alpha_wolf", "狼人首领", 1, 100, 11, EnemyCategory.ELITE, GameTypes.EnemyCombatType.WARRIOR, 50,
		[_phase(0, [_action(EnemyAction.ActionType.ATTACK, 11), _action(EnemyAction.ActionType.ATTACK, 14, "狂暴撕咬"), _action(EnemyAction.ActionType.SKILL, 2, "力量", false), _action(EnemyAction.ActionType.ATTACK, 9)])],
		_quotes(["月光之下……狼群为王！"], ["狼王……倒下了……"], ["撕碎！", "狂暴！", "嗷——！"], ["疼痛……让我更愤怒！"], ["月光……赐予我……"]),
		true, 2)
	_register("elite_frost_wyrm", "霜龙幼崽", 2, 95, 10, EnemyCategory.ELITE, GameTypes.EnemyCombatType.CASTER, 50,
		[_phase(0.3, [_action(EnemyAction.ActionType.ATTACK, 18, "寒冰吐息"), _action(EnemyAction.ActionType.SKILL, 2, "冻结", false)]),
		 _phase(0, [_action(EnemyAction.ActionType.ATTACK, 10), _action(EnemyAction.ActionType.SKILL, 2, "虚弱", false), _action(EnemyAction.ActionType.DEFEND, 14), _action(EnemyAction.ActionType.ATTACK, 8)])],
		_quotes(["（冰冷的咆哮响彻山谷）"], ["（碎裂成无数冰晶）"], ["冰息！", "冻住吧！"], ["龙鳞……裂了？"], ["最后的……寒冰吐息……"]),
		true, 2)
	_register("elite_ice_lord", "冰霜巨人王", 2, 120, 7, EnemyCategory.ELITE, GameTypes.EnemyCombatType.GUARDIAN, 50,
		[_phase(0, [_action(EnemyAction.ActionType.DEFEND, 20), _action(EnemyAction.ActionType.ATTACK, 8), _action(EnemyAction.ActionType.ATTACK, 14, "冰锤粉碎"), _action(EnemyAction.ActionType.SKILL, 1, "冻结", false)])],
		_quotes(["渺小的生物……敢闯冰封王座？"], ["冰……不灭……"], ["碾碎！", "冰锤！"], ["蚊虫叮咬……"], ["冰封王座……不会倒塌！"]),
		true, 2)
	_register("elite_infernal", "地狱火", 3, 100, 12, EnemyCategory.ELITE, GameTypes.EnemyCombatType.WARRIOR, 50,
		[_phase(0, [_action(EnemyAction.ActionType.ATTACK, 12), _action(EnemyAction.ActionType.ATTACK, 16, "烈焰冲击"), _action(EnemyAction.ActionType.SKILL, 3, "灼烧", false), _action(EnemyAction.ActionType.DEFEND, 10)])],
		_quotes(["（从天而降，地面龟裂）"], ["烈焰……熄灭了……"], ["烈焰！", "毁灭！", "焚烧一切！"], ["石皮……裂了……"], ["最后的爆发……"]),
		true, 2)
	_register("elite_dark_iron", "黑铁议员", 3, 90, 9, EnemyCategory.ELITE, GameTypes.EnemyCombatType.CASTER, 50,
		[_phase(0.4, [_action(EnemyAction.ActionType.ATTACK, 16, "熔岩之怒"), _action(EnemyAction.ActionType.SKILL, 1, "诅咒锻造", false)]),
		 _phase(0, [_action(EnemyAction.ActionType.ATTACK, 9), _action(EnemyAction.ActionType.SKILL, 2, "灼烧", false), _action(EnemyAction.ActionType.DEFEND, 16)])],
		_quotes(["黑铁议会……判你死刑！"], ["议会……散了……"], ["熔岩之怒！", "黑铁审判！"], ["黑铁……不碎！"], ["启动……自毁程序……"]),
		true, 2)
	_register("elite_doomguard", "末日守卫", 4, 110, 11, EnemyCategory.ELITE, GameTypes.EnemyCombatType.WARRIOR, 50,
		[_phase(0, [_action(EnemyAction.ActionType.ATTACK, 11), _action(EnemyAction.ActionType.ATTACK, 16, "末日审判"), _action(EnemyAction.ActionType.SKILL, 2, "易伤", false), _action(EnemyAction.ActionType.DEFEND, 14), _action(EnemyAction.ActionType.SKILL, 1, "诅咒注入", false)])],
		_quotes(["末日……已经降临。"], ["军团……不灭……"], ["末日审判！", "灵魂撕裂！"], ["邪能护甲……动摇了？"], ["用我的生命……召唤更强大的恶魔！"]),
		true, 2)
	_register("elite_shadow_priest", "暗影大主教", 4, 80, 8, EnemyCategory.ELITE, GameTypes.EnemyCombatType.PRIEST, 50,
		[_phase(0.3, [_action(EnemyAction.ActionType.SKILL, 3, "剧毒", false), _action(EnemyAction.ActionType.SKILL, 3, "灼烧", false)]),
		 _phase(0, [_action(EnemyAction.ActionType.ATTACK, 8), _action(EnemyAction.ActionType.SKILL, 2, "虚弱", false), _action(EnemyAction.ActionType.ATTACK, 10, "精神鞭笞"), _action(EnemyAction.ActionType.SKILL, 2, "剧毒", false)])],
		_quotes(["暗影的低语……你听到了吗？"], ["暗影……弥散了……"], ["精神鞭笞！", "暗影之触！"], ["心灵屏障……裂了……"], ["暗影……形态——最终手段！"]),
		true, 2)
	_register("elite_titan_construct", "泰坦守护者", 5, 130, 10, EnemyCategory.ELITE, GameTypes.EnemyCombatType.GUARDIAN, 50,
		[_phase(0, [_action(EnemyAction.ActionType.DEFEND, 22), _action(EnemyAction.ActionType.ATTACK, 10), _action(EnemyAction.ActionType.ATTACK, 18, "泰坦之锤"), _action(EnemyAction.ActionType.SKILL, 2, "虚弱", false)])],
		_quotes(["入侵者检测完毕。启动消灭程序。"], ["系统……崩溃……"], ["泰坦之锤！", "消灭目标！"], ["护盾……承受冲击……"], ["核心过载……启动自毁倒计时……"]),
		true, 2)
	_register("elite_void_walker", "虚空行者", 5, 90, 13, EnemyCategory.ELITE, GameTypes.EnemyCombatType.CASTER, 50,
		[_phase(0.35, [_action(EnemyAction.ActionType.ATTACK, 20, "虚空爆裂"), _action(EnemyAction.ActionType.SKILL, 1, "诅咒注入", false)]),
		 _phase(0, [_action(EnemyAction.ActionType.ATTACK, 13), _action(EnemyAction.ActionType.SKILL, 2, "易伤", false), _action(EnemyAction.ActionType.ATTACK, 10), _action(EnemyAction.ActionType.SKILL, 2, "虚弱", false)])],
		_quotes(["虚空……无处不在……"], ["虚空……会记住你……"], ["虚空爆裂！", "维度撕裂！"], ["虚空……波动了……"], ["虚空的全部力量……释放！"]),
		true, 2)
	# ===== Boss =====
	_register("boss_lich_forest", "枯骨巫妖", 1, 150, 10, EnemyCategory.BOSS, GameTypes.EnemyCombatType.CASTER, 60,
		[_phase(0.4, [_action(EnemyAction.ActionType.ATTACK, 16, "亡灵风暴"), _action(EnemyAction.ActionType.SKILL, 2, "灼烧", false), _action(EnemyAction.ActionType.ATTACK, 14, "骸骨之矛"), _action(EnemyAction.ActionType.SKILL, 1, "诅咒", false), _action(EnemyAction.ActionType.DEFEND, 15)]),
		 _phase(0, [_action(EnemyAction.ActionType.ATTACK, 8), _action(EnemyAction.ActionType.ATTACK, 8), _action(EnemyAction.ActionType.SKILL, 2, "虚弱", false), _action(EnemyAction.ActionType.SKILL, 1, "易伤", false), _action(EnemyAction.ActionType.DEFEND, 15)])],
		_quotes(["哈哈哈……又一个活人，送上门来了。"], ["我的……灵魂宝石……不——！"], ["亡灵风暴！", "骸骨之矛！"], ["灵魂宝石……动摇了……"], ["灵魂宝石……碎裂吧——！"]),
		true)
	_register("boss_ancient_treant", "远古树王", 1, 300, 15, EnemyCategory.BOSS, GameTypes.EnemyCombatType.GUARDIAN, 0,
		[_phase(0.5, [_action(EnemyAction.ActionType.ATTACK, 22, "大地之怒"), _action(EnemyAction.ActionType.DEFEND, 30), _action(EnemyAction.ActionType.ATTACK, 18), _action(EnemyAction.ActionType.SKILL, 3, "剧毒", false)]),
		 _phase(0, [_action(EnemyAction.ActionType.DEFEND, 20), _action(EnemyAction.ActionType.ATTACK, 12), _action(EnemyAction.ActionType.SKILL, 2, "虚弱", false), _action(EnemyAction.ActionType.ATTACK, 15)])],
		_quotes(["千年……未曾有人……走到这里。"], ["你……是第一个……砍倒我的人……"], ["大地之怒！", "根须绞杀！"], ["不过是……树皮划痕……"], ["大地啊……赐予我……最后的力量——！"]))
	_register("boss_frost_queen", "霜寒女王", 2, 160, 10, EnemyCategory.BOSS, GameTypes.EnemyCombatType.CASTER, 60,
		[_phase(0.4, [_action(EnemyAction.ActionType.ATTACK, 18, "暴风雪"), _action(EnemyAction.ActionType.SKILL, 2, "冻结", false), _action(EnemyAction.ActionType.ATTACK, 14), _action(EnemyAction.ActionType.SKILL, 1, "碎裂诅咒", false), _action(EnemyAction.ActionType.DEFEND, 16)]),
		 _phase(0, [_action(EnemyAction.ActionType.ATTACK, 9), _action(EnemyAction.ActionType.SKILL, 1, "冻结", false), _action(EnemyAction.ActionType.ATTACK, 9), _action(EnemyAction.ActionType.SKILL, 2, "虚弱", false), _action(EnemyAction.ActionType.DEFEND, 14)])],
		_quotes(["冰封山脉的女王……亲自迎接你。"], ["（冰雕碎裂）"], ["暴风雪！", "冰封！"], ["我的冰甲……裂了？"], ["冰封……整个世界吧——！"]),
		true)
	_register("boss_frost_lich", "霜之巫妖王", 2, 320, 15, EnemyCategory.BOSS, GameTypes.EnemyCombatType.WARRIOR, 0,
		[_phase(0.5, [_action(EnemyAction.ActionType.ATTACK, 28, "霜之哀伤"), _action(EnemyAction.ActionType.ATTACK, 20), _action(EnemyAction.ActionType.SKILL, 3, "剧毒", false), _action(EnemyAction.ActionType.DEFEND, 28)]),
		 _phase(0, [_action(EnemyAction.ActionType.ATTACK, 14), _action(EnemyAction.ActionType.SKILL, 2, "冻结", false), _action(EnemyAction.ActionType.ATTACK, 18), _action(EnemyAction.ActionType.SKILL, 2, "虚弱", false)])],
		_quotes(["跪下……在巫妖王面前。"], ["永恒的寒冬……终结了？"], ["霜之哀伤！", "臣服于寒冰！"], ["不过是……暖风拂面。"], ["所有人……都将臣服于寒冰王座——！"]))
	_register("boss_ragnaros", "炎魔之王", 3, 200, 12, EnemyCategory.BOSS, GameTypes.EnemyCombatType.WARRIOR, 60,
		[_phase(0.4, [_action(EnemyAction.ActionType.ATTACK, 20, "岩浆之锤"), _action(EnemyAction.ActionType.SKILL, 3, "灼烧", false), _action(EnemyAction.ActionType.ATTACK, 16, "烈焰之手"), _action(EnemyAction.ActionType.DEFEND, 14)]),
		 _phase(0, [_action(EnemyAction.ActionType.ATTACK, 12), _action(EnemyAction.ActionType.SKILL, 2, "灼烧", false), _action(EnemyAction.ActionType.ATTACK, 10), _action(EnemyAction.ActionType.DEFEND, 12)])],
		_quotes(["太早了……你唤醒我太早了！"], ["我会……回来的……"], ["岩浆之锤！", "烈焰冲击！"], ["渣渣！你敢伤我？"], ["烈焰……最后的爆发——！"]),
		true)
	_register("boss_deathwing", "熔火死翼", 3, 380, 16, EnemyCategory.BOSS, GameTypes.EnemyCombatType.CASTER, 0,
		[_phase(0.5, [_action(EnemyAction.ActionType.ATTACK, 30, "大灾变"), _action(EnemyAction.ActionType.ATTACK, 22), _action(EnemyAction.ActionType.SKILL, 4, "灼烧", false), _action(EnemyAction.ActionType.DEFEND, 30)]),
		 _phase(0, [_action(EnemyAction.ActionType.SKILL, 3, "灼烧", false), _action(EnemyAction.ActionType.ATTACK, 14), _action(EnemyAction.ActionType.SKILL, 2, "易伤", false), _action(EnemyAction.ActionType.ATTACK, 20, "熔岩吐息")])],
		_quotes(["大灾变……来临了！"], ["（咆哮着坠入岩浆）"], ["大灾变！", "熔岩吐息！"], ["你伤到了……我的钢铁之躯？"], ["即使我倒下……世界……也已面目全非——！"]))
	_register("boss_archimonde", "深渊领主", 4, 200, 11, EnemyCategory.BOSS, GameTypes.EnemyCombatType.CASTER, 60,
		[_phase(0.4, [_action(EnemyAction.ActionType.ATTACK, 18, "暗影之手"), _action(EnemyAction.ActionType.SKILL, 2, "灼烧", false), _action(EnemyAction.ActionType.ATTACK, 14, "邪能风暴"), _action(EnemyAction.ActionType.SKILL, 1, "诅咒注入", false), _action(EnemyAction.ActionType.DEFEND, 16)]),
		 _phase(0, [_action(EnemyAction.ActionType.ATTACK, 10), _action(EnemyAction.ActionType.SKILL, 2, "虚弱", false), _action(EnemyAction.ActionType.ATTACK, 9), _action(EnemyAction.ActionType.SKILL, 2, "剧毒", false), _action(EnemyAction.ActionType.DEFEND, 14)])],
		_quotes(["燃烧军团……势不可挡！"], ["我会……在扭曲虚空中……重生！"], ["暗影之手！", "邪能风暴！"], ["你……竟敢？"], ["燃烧吧——！"]),
		true)
	_register("boss_kiljaeden", "暗影之王", 4, 380, 16, EnemyCategory.BOSS, GameTypes.EnemyCombatType.CASTER, 0,
		[_phase(0.5, [_action(EnemyAction.ActionType.ATTACK, 28, "黑暗终焉"), _action(EnemyAction.ActionType.ATTACK, 22), _action(EnemyAction.ActionType.SKILL, 3, "剧毒", false), _action(EnemyAction.ActionType.DEFEND, 30)]),
		 _phase(0, [_action(EnemyAction.ActionType.SKILL, 4, "灼烧", false), _action(EnemyAction.ActionType.ATTACK, 14), _action(EnemyAction.ActionType.SKILL, 2, "虚弱", false), _action(EnemyAction.ActionType.ATTACK, 20, "邪能陨石")])],
		_quotes(["欺骗者……来了。"], ["不可能……欺骗者……怎会被欺骗……"], ["黑暗终焉！", "邪能陨石！"], ["有趣……你确实……有些能耐。"], ["用虚空的全部力量——毁灭这个世界！"]))
	_register("boss_titan_watcher", "泰坦看守者", 5, 200, 12, EnemyCategory.BOSS, GameTypes.EnemyCombatType.GUARDIAN, 60,
		[_phase(0.4, [_action(EnemyAction.ActionType.ATTACK, 18, "泰坦审判"), _action(EnemyAction.ActionType.DEFEND, 22), _action(EnemyAction.ActionType.ATTACK, 16, "秩序之光"), _action(EnemyAction.ActionType.SKILL, 2, "易伤", false)]),
		 _phase(0, [_action(EnemyAction.ActionType.DEFEND, 18), _action(EnemyAction.ActionType.ATTACK, 10), _action(EnemyAction.ActionType.SKILL, 2, "虚弱", false), _action(EnemyAction.ActionType.ATTACK, 12)])],
		_quotes(["泰坦的秩序……不容亵渎。"], ["秩序……被打破了……"], ["泰坦审判！", "秩序之光！"], ["损伤……在可控范围内……"], ["启动……最终审判协议——！"]),
		true)
	_register("boss_eternal_lord", "永恒主宰", 5, 480, 18, EnemyCategory.BOSS, GameTypes.EnemyCombatType.CASTER, 0,
		[_phase(0.5, [_action(EnemyAction.ActionType.ATTACK, 28, "终极之光"), _action(EnemyAction.ActionType.ATTACK, 22), _action(EnemyAction.ActionType.SKILL, 3, "剧毒", false), _action(EnemyAction.ActionType.DEFEND, 30)]),
		 _phase(0, [_action(EnemyAction.ActionType.SKILL, 4, "灼烧", false), _action(EnemyAction.ActionType.ATTACK, 14), _action(EnemyAction.ActionType.SKILL, 2, "虚弱", false), _action(EnemyAction.ActionType.ATTACK, 20)])],
		_quotes(["永恒……在此。渺小的骰子掷者，你的终点……就是今天。"], ["你……究竟……是什么？"], ["终极之光！", "永恒之力，碾碎你！"], ["哼……有点意思。"], ["永恒……动摇了……但我绝不会……就此终结！终极之光——爆发！"]))


## === 辅助构造函数 ===

static func _register(id: String, name: String, chapter: int, base_hp: int, base_dmg: int, category: EnemyCategory, combat_type: GameTypes.EnemyCombatType, drop_gold: int, phases: Array[EnemyPhase], quotes: EnemyQuotes, drop_relic: bool = false, drop_reroll: int = 0) -> void:
	var c := EnemyConfig.new()
	c.id = id; c.name = name; c.chapter = chapter; c.base_hp = base_hp; c.base_dmg = base_dmg
	c.category = category; c.combat_type = combat_type; c.drop_gold = drop_gold
	c.drop_relic = drop_relic; c.drop_reroll_reward = drop_reroll
	c.phases = phases; c.quotes = quotes
	_all_configs[id] = c

static func _phase(hp_threshold: float, actions: Array[EnemyAction]) -> EnemyPhase:
	var p := EnemyPhase.new()
	p.hp_threshold = hp_threshold; p.actions = actions
	return p

static func _action(type: int, base_value: int, description: String = "", scalable: bool = true) -> EnemyAction:
	var a := EnemyAction.new()
	a.type = type; a.base_value = base_value; a.description = description; a.scalable = scalable
	return a

static func _quotes(enter: Array[String], death: Array[String], attack: Array[String], hurt: Array[String], low_hp: Array[String]) -> EnemyQuotes:
	var q := EnemyQuotes.new()
	q.enter = enter; q.death = death; q.attack = attack; q.hurt = hurt; q.low_hp = low_hp
	return q
