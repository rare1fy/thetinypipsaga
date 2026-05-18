## 敌人配置资源 — 魔兽世界观换皮版
## 5章 × (10普通 + 3精英 + 4Boss) = 85个敌人
## 敌人库扩充用于战斗随机多样性，地图节点数不变

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
	@export var phase2_taunt: Array[String] = []

## ============================================================
## 注册表
## ============================================================

static var _all_configs: Dictionary = {}

static func _static_init() -> void:
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
	# ===== 第一章：人族 · 飓风城外围 =====
	# 普通敌人 ×10
	_reg("human_footman", "步兵列兵", 1, 28, 7, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.WARRIOR, 20,
		[_phase(0, [_atk(7), _atk(9, "剑击"), _skill(1, "虚弱")])],
		_q(["为了联盟！站住，怪物！", "哨兵报告——发现入侵者！"], ["告诉……我的家人……", "联盟……万岁……"], ["冲锋！", "吃我一剑！", "联盟的力量！"], ["铠甲……被穿透了！", "嗬！"], ["增援……快来增援……"]))
	_reg("dwarf_musketeer", "矮人火枪手", 1, 18, 3, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.RANGER, 20,
		[_phase(0, [_skill(2, "灼烧"), _atk(4), _atk(4)])],
		_q(["哈！让老子的火枪来招待你！", "（装弹声）"], ["枪……哑火了……", "告诉酒馆……我的酒钱……还没付……"], ["开火！", "吃颗子弹！", "瞄准了！"], ["嘶！打中我了！", "该死的……"], ["弹药……快没了……最后一发给你！"]))
	_reg("heavy_knight", "重甲骑士", 1, 42, 4, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.GUARDIAN, 20,
		[_phase(0, [_def(8), _atk(5), _def(6), _atk(7, "盾击")])],
		_q(["以圣光之名……你将被制裁！", "（铠甲铿锵声）"], ["圣光……指引我……", "倒下了……但誓言……不灭……"], ["盾击！", "正义审判！"], ["板甲……凹了……", "（金属哀鸣）"], ["只要……盾还在……就不会退！"]))
	_reg("priest_apprentice", "牧师学徒", 1, 16, 3, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.CASTER, 20,
		[_phase(0, [_skill(1, "易伤"), _atk(5), _skill(1, "虚弱")])],
		_q(["圣光啊……赐予我力量驱逐邪恶！"], ["圣光……原谅我的无能……"], ["惩击！", "圣光制裁！"], ["（祈祷声中断）"], ["最后……一次祈祷……"]))
	_reg("dwarf_priest", "矮人祭司", 1, 20, 2, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.PRIEST, 20,
		[_phase(0, [_skill(2, "灼烧"), _skill(1, "易伤"), _atk(4)])],
		_q(["铁炉堡的祝福与你同在——才怪！"], ["石母……接引我……"], ["圣光之锤！", "净化邪恶！"], ["胡子……被烧了！"], ["石母……赐予我……"]))
	_reg("berserker_footman", "狂战步兵", 1, 24, 9, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.WARRIOR, 20,
		[_phase(0, [_atk(9), _atk(11, "狂暴斩"), _skill(1, "力量")])],
		_q(["啊啊啊——杀！", "血战到底！"], ["至少……死在战场上……"], ["狂暴斩！", "碎颅击！", "嗬啊！"], ["疼痛让我更强！"], ["最后的……狂暴——！"]))
	_reg("dwarf_bomber", "矮人毒弹兵", 1, 16, 4, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.RANGER, 20,
		[_phase(0, [_skill(2, "剧毒"), _atk(4), _atk(5, "毒弹")])],
		_q(["嘿嘿……尝尝这个配方！"], ["炸药……没了……"], ["毒弹！", "吃这个！"], ["我的……护目镜！"], ["最后一颗……特制的！"]))
	_reg("stone_guardian", "石盾卫兵", 1, 38, 3, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.GUARDIAN, 20,
		[_phase(0, [_def(10), _atk(4), _def(8), _atk(6, "盾墙冲撞")])],
		_q(["城门……不可逾越！"], ["城墙……倒了……"], ["盾墙！", "冲撞！"], ["盾面……裂了……"], ["只要我还站着……就是城墙！"]))
	_reg("dark_apprentice", "暗法学徒", 1, 14, 5, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.CASTER, 20,
		[_phase(0, [_skill(2, "剧毒"), _atk(6, "暗影箭"), _skill(1, "虚弱"), _atk(5)])],
		_q(["暗影的力量……比圣光更强！"], ["不……我的法力……"], ["暗影箭！", "腐蚀！"], ["法力护盾……碎了？"], ["最后的……暗影爆发！"]))
	_reg("holy_inquisitor", "圣光司铎", 1, 22, 3, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.PRIEST, 20,
		[_phase(0, [_skill(2, "力量"), _skill(1, "易伤"), _atk(5, "圣光惩击")])],
		_q(["异端……必须净化！"], ["圣光……为何……"], ["圣光惩击！", "审判！"], ["信仰……不会动摇……"], ["最后的审判……"]))
	# 精英 ×3
	_reg("elite_archmage", "大法师", 1, 85, 8, EnemyCategory.ELITE, GameTypes.EnemyCombatType.CASTER, 50,
		[_phase(0.4, [_atk(14, "奥术风暴"), _skill(3, "剧毒")]),
		 _phase(0, [_atk(8), _skill(2, "虚弱"), _def(12)])],
		_q(["法师塔的力量……不是你能想象的！"], ["我的……法力……"], ["奥术飞弹！", "暴风雪！", "火焰冲击！"], ["法力护盾……碎了？"], ["用我全部的法力……最后一击！"]),
		true, 2)
	_reg("elite_paladin", "圣骑士队长", 1, 100, 11, EnemyCategory.ELITE, GameTypes.EnemyCombatType.WARRIOR, 50,
		[_phase(0, [_atk(11), _atk(14, "圣光冲击"), _skill(2, "力量"), _atk(9)])],
		_q(["白银之手……绝不容许邪恶存在！"], ["圣光……我尽力了……"], ["圣光冲击！", "正义之锤！", "审判！"], ["圣光护盾……承受住了！"], ["圣光……赐予我……最后的力量！"]),
		true, 2)
	_reg("elite_ranger", "精锐游骑兵", 1, 70, 10, EnemyCategory.ELITE, GameTypes.EnemyCombatType.RANGER, 50,
		[_phase(0.3, [_atk(16, "三连射"), _skill(2, "易伤")]),
		 _phase(0, [_atk(10), _atk(8), _skill(1, "剧毒")])],
		_q(["（弓弦拉满）目标锁定。"], ["箭……射完了……"], ["三连射！", "穿甲箭！", "瞄准要害！"], ["嘶……闪避失败……"], ["最后三支箭……全给你！"]),
		true, 2)
	# Boss ×4（2中Boss + 1中Boss + 1终Boss）
	_reg("boss_archbishop", "大主教", 1, 150, 10, EnemyCategory.BOSS, GameTypes.EnemyCombatType.CASTER, 60,
		[_phase(0.4, [_atk(16, "神圣之火"), _skill(2, "灼烧"), _atk(14, "圣言术·罚"), _skill(1, "虚弱"), _def(15)]),
		 _phase(0, [_atk(8), _atk(8), _skill(2, "虚弱"), _skill(1, "易伤"), _def(15)])],
		_q(["迷途的灵魂……让我来净化你。"], ["圣光……为何……抛弃了我……"], ["神圣之火！", "圣言术·罚！"], ["信仰……不会动摇……"], ["圣光啊——赐予我最终的审判之力！"]),
		true)
	_reg("boss_gate_colossus", "城门巨像", 1, 180, 8, EnemyCategory.BOSS, GameTypes.EnemyCombatType.GUARDIAN, 60,
		[_phase(0.4, [_atk(14, "巨拳碾压"), _def(22), _atk(12), _skill(2, "虚弱")]),
		 _phase(0, [_def(18), _atk(8), _skill(1, "易伤"), _atk(10)])],
		_q(["（石像眼睛亮起蓝光）入侵者……检测到。"], ["系统……崩溃……"], ["巨拳碾压！", "防御协议启动！"], ["外壳……损伤……"], ["启动……最终防御——！"]),
		true)
	_reg("boss_witch_judge", "女巫审判官", 1, 140, 12, EnemyCategory.BOSS, GameTypes.EnemyCombatType.CASTER, 60,
		[_phase(0.4, [_atk(18, "烈焰审判"), _skill(3, "灼烧"), _atk(14, "灵魂拷问")]),
		 _phase(0, [_atk(10), _skill(2, "剧毒"), _atk(8), _skill(2, "虚弱")])],
		_q(["异端的灵魂……由我来审判。"], ["审判……还没结束……"], ["烈焰审判！", "灵魂拷问！"], ["你……竟敢反抗审判？"], ["最终审判——焚烧一切！"]),
		true)
	_reg("boss_grand_marshal", "人族大元帅", 1, 300, 15, EnemyCategory.BOSS, GameTypes.EnemyCombatType.GUARDIAN, 0,
		[_phase(0.5, [_atk(22, "狮心斩"), _def(30), _atk(18), _skill(3, "力量")]),
		 _phase(0, [_def(20), _atk(12), _skill(2, "虚弱"), _atk(15)])],
		_q(["千年未有……敌人攻入飓风城。今日……由我亲自了结。"], ["你……究竟……是什么怪物？"], ["狮心斩！", "暴风之怒！"], ["不过是……皮肉之伤。"], ["飓风城……绝不会倒下——全军冲锋！"]))

	# ===== 第二章：兽族 · 碎牙堡荒原 =====
	_reg("orc_grunt", "兽人步兵", 2, 36, 9, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.WARRIOR, 20,
		[_phase(0, [_atk(9), _atk(11, "战斧猛击")])],
		_q(["洛克塔尔！为了部落！", "嗬！"], ["光荣……战死……", "祖灵……接引我……"], ["砍！", "战斧！", "嗬嗬嗬！"], ["嗬！不疼！", "皮糙肉厚！"], ["战士……不会跪下……"]))
	_reg("troll_witchdoctor", "巨魔巫医", 2, 18, 4, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.CASTER, 20,
		[_phase(0, [_skill(1, "冻结"), _atk(6), _skill(2, "虚弱")])],
		_q(["巫毒之灵……降临吧，兄弟！"], ["洛阿……带我走……"], ["巫毒飞镖！", "诅咒你！"], ["嘶……我的面具！"], ["最后的……巫毒仪式……"]))
	_reg("wolf_rider", "狼骑兵", 2, 22, 5, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.RANGER, 20,
		[_phase(0, [_atk(5), _atk(7, "狼牙突袭"), _skill(1, "灼烧")])],
		_q(["（狼嚎）冲锋——！"], ["我的……狼……"], ["突袭！", "狼牙斩！", "嗷——！"], ["嗬！擦伤而已！"], ["狼兄弟……最后一次冲锋……"]))
	_reg("tauren_guard", "牛头人守卫", 2, 44, 4, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.GUARDIAN, 20,
		[_phase(0, [_def(10), _atk(5), _def(8)])],
		_q(["大地母亲……赐予我力量。"], ["（沉重倒地）"], ["战争践踏！", "图腾之力！"], ["蚊虫叮咬……"], ["大地……不会倒塌……"]))
	_reg("orc_warlock", "兽人术士", 2, 20, 5, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.CASTER, 20,
		[_phase(0, [_skill(2, "灼烧"), _atk(6, "暗影箭"), _skill(1, "易伤")])],
		_q(["恶魔之力……为我所用！"], ["灵魂石……碎了……"], ["暗影箭！", "燃烧吧！"], ["灵魂护盾……裂了……"], ["生命分流！"]))
	_reg("troll_berserker", "巨魔狂战", 2, 26, 10, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.WARRIOR, 20,
		[_phase(0, [_atk(10), _atk(12, "狂暴投掷"), _skill(1, "力量")])],
		_q(["嘿嘿……血祭开始了！"], ["洛阿……"], ["投掷！", "狂暴！", "嘿嘿嘿！"], ["哈！更来劲了！"], ["血祭……最后的仪式！"]))
	_reg("orc_shaman", "兽人萨满", 2, 22, 3, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.PRIEST, 20,
		[_phase(0, [_skill(2, "灼烧"), _skill(1, "力量"), _atk(5)])],
		_q(["元素之灵……降临吧！"], ["元素……离开了我……"], ["闪电链！", "烈焰冲击！"], ["图腾……碎了……"], ["最后的祈祷……"]))
	_reg("tauren_brave", "牛头人勇士", 2, 32, 8, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.WARRIOR, 20,
		[_phase(0, [_atk(8), _atk(10, "图腾猛击"), _def(6)])],
		_q(["大地之力——与我同在！"], ["回归……大地……"], ["图腾猛击！", "践踏！"], ["牛皮……厚着呢！"], ["大地母亲……最后的力量！"]))
	_reg("troll_headhunter", "巨魔猎头者", 2, 20, 6, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.RANGER, 20,
		[_phase(0, [_atk(6), _skill(2, "剧毒"), _atk(7, "毒矛")])],
		_q(["你的头……我要了！"], ["头……没拿到……"], ["毒矛！", "猎头！"], ["嘶！"], ["最后一根矛……淬了三倍毒！"]))
	_reg("orc_drummer", "兽人战鼓手", 2, 24, 2, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.PRIEST, 20,
		[_phase(0, [_skill(2, "力量"), _skill(1, "易伤"), _atk(4, "鼓槌")])],
		_q(["咚咚咚——战鼓响起！"], ["鼓……破了……"], ["战鼓激励！", "鼓槌！"], ["节奏……乱了……"], ["最后的鼓点——！"]))
	# 精英 ×3
	_reg("elite_shadow_hunter", "暗影猎手", 2, 95, 10, EnemyCategory.ELITE, GameTypes.EnemyCombatType.CASTER, 50,
		[_phase(0.3, [_atk(18, "暗影突袭"), _skill(2, "冻结")]),
		 _phase(0, [_atk(10), _skill(2, "虚弱"), _def(14), _atk(8)])],
		_q(["（阴影中闪烁红色眼光）暗影……猎杀开始。"], ["（碎裂成暗影碎片）"], ["暗影突袭！", "巫毒之箭！"], ["暗影护体……裂了？"], ["最后的……暗影之舞……"]),
		true, 2)
	_reg("elite_tauren_chief", "牛头人酋长", 2, 120, 7, EnemyCategory.ELITE, GameTypes.EnemyCombatType.GUARDIAN, 50,
		[_phase(0, [_def(20), _atk(8), _atk(14, "大地震击"), _skill(1, "冻结")])],
		_q(["渺小的虫子……敢闯雷霆崖？"], ["雷霆崖……永不倒……"], ["大地震击！", "图腾粉碎！"], ["蚊虫叮咬……"], ["雷霆崖……不会倒塌！"]),
		true, 2)
	_reg("elite_blademaster", "剑圣", 2, 80, 13, EnemyCategory.ELITE, GameTypes.EnemyCombatType.WARRIOR, 50,
		[_phase(0.3, [_atk(20, "剑刃风暴"), _skill(2, "易伤")]),
		 _phase(0, [_atk(13), _atk(10), _skill(1, "力量")])],
		_q(["吾之剑……斩尽一切！"], ["剑……断了……"], ["剑刃风暴！", "镜像突袭！", "致命一击！"], ["不过是……剑气擦伤。"], ["最后的剑舞——！"]),
		true, 2)
	# Boss ×4
	_reg("boss_darkspear_priestess", "暗矛女祭司", 2, 160, 10, EnemyCategory.BOSS, GameTypes.EnemyCombatType.CASTER, 60,
		[_phase(0.4, [_atk(18, "巫毒风暴"), _skill(2, "冻结"), _atk(14), _skill(1, "虚弱"), _def(16)]),
		 _phase(0, [_atk(9), _skill(1, "冻结"), _atk(9), _skill(2, "虚弱"), _def(14)])],
		_q(["巫毒之灵……审判这个入侵者。"], ["（巫毒面具碎裂）"], ["巫毒风暴！", "灵魂诅咒！"], ["我的……巫毒护盾……"], ["洛阿之怒——降临吧！"]),
		true)
	_reg("boss_kodo_beast", "科多巨兽", 2, 200, 7, EnemyCategory.BOSS, GameTypes.EnemyCombatType.GUARDIAN, 60,
		[_phase(0.4, [_atk(14, "践踏"), _def(24), _atk(10), _skill(2, "虚弱")]),
		 _phase(0, [_def(18), _atk(7), _skill(1, "易伤"), _atk(9)])],
		_q(["（震耳欲聋的吼叫）"], ["（轰然倒地）"], ["践踏！", "吞噬！"], ["厚皮……裂了？"], ["最后的冲锋——！"]),
		true)
	_reg("boss_warlord", "战争领主", 2, 160, 12, EnemyCategory.BOSS, GameTypes.EnemyCombatType.WARRIOR, 60,
		[_phase(0.4, [_atk(18, "战争践踏"), _skill(3, "力量"), _atk(14, "嗜血")]),
		 _phase(0, [_atk(12), _skill(2, "灼烧"), _atk(10), _def(12)])],
		_q(["部落的敌人……由我来碾碎！"], ["部落……不灭……"], ["战争践踏！", "嗜血！"], ["哈！挠痒痒！"], ["洛克塔尔——奥加！"]),
		true)
	_reg("boss_warchief", "兽人大酋长", 2, 320, 15, EnemyCategory.BOSS, GameTypes.EnemyCombatType.WARRIOR, 0,
		[_phase(0.5, [_atk(28, "毁灭之锤"), _atk(20), _skill(3, "灼烧"), _def(28)]),
		 _phase(0, [_atk(14), _skill(2, "冻结"), _atk(18), _skill(2, "虚弱")])],
		_q(["部落的敌人……由我亲自解决。"], ["部落……会记住……这一天……"], ["毁灭之锤！", "闪电链！"], ["不过是……暖风拂面。"], ["元素之灵——赐予我最后的力量！全军——冲锋！"]))

	# ===== 第三章：不死族 · 暗渊城 =====
	_reg("abomination", "憎恶", 3, 30, 8, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.WARRIOR, 20,
		[_phase(0, [_atk(8), _atk(10, "瘟疫撕咬"), _skill(2, "灼烧")])],
		_q(["嘎嘎……新鲜的肉……", "主人说……撕碎入侵者……"], ["缝线……散了……", "回到……土里……"], ["撕！", "吃掉你！", "嘎嘎嘎！"], ["嘎！掉了一块！"], ["还没……吃饱……"]))
	_reg("plague_bat", "瘟疫蝙蝠", 3, 16, 4, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.CASTER, 20,
		[_phase(0, [_skill(2, "灼烧"), _atk(5), _skill(1, "易伤"), _atk(6, "瘟疫吐息")])],
		_q(["嘶嘶……瘟疫……传播吧……"], ["嘶……翅膀……碎了……"], ["瘟疫吐息！", "感染！", "腐蚀！"], ["嘶！", "翼膜……破了……"], ["最后……一口毒……"]))
	_reg("ghoul_guard", "食尸鬼卫兵", 3, 48, 5, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.GUARDIAN, 20,
		[_phase(0, [_def(12), _atk(6), _def(8), _atk(8, "骨爪")])],
		_q(["骨甲……坚不可摧……"], ["骨头……散架了……"], ["骨爪！", "撕裂！"], ["叮！骨甲挡住了！"], ["只要……骨架还在……"]))
	_reg("undead_apothecary", "亡灵药剂师", 3, 22, 3, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.PRIEST, 20,
		[_phase(0, [_skill(2, "灼烧"), _skill(1, "力量"), _atk(5)])],
		_q(["新的实验品……来了。"], ["实验……失败了……"], ["瘟疫药剂！", "腐蚀之瓶！"], ["我的……试管！"], ["最后的配方……"]))
	_reg("skeleton_mage", "骷髅法师", 3, 18, 6, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.CASTER, 20,
		[_phase(0, [_skill(2, "冻结"), _atk(7, "寒冰箭"), _skill(1, "虚弱")])],
		_q(["（骨头嘎吱作响）"], ["（碎裂成骨粉）"], ["寒冰箭！", "霜冻新星！"], ["骨架……裂了……"], ["最后的……冰霜……"]))
	_reg("banshee", "女妖", 3, 20, 5, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.CASTER, 20,
		[_phase(0, [_skill(1, "虚弱"), _atk(6, "哀嚎"), _skill(2, "易伤")])],
		_q(["啊啊啊——！"], ["终于……安息了……"], ["哀嚎！", "灵魂尖啸！"], ["（刺耳尖啸）"], ["最后……一曲……"]))
	_reg("crypt_fiend", "地穴蛛魔", 3, 26, 6, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.RANGER, 20,
		[_phase(0, [_atk(6), _skill(2, "剧毒"), _atk(7, "蛛网")])],
		_q(["嘶嘶……陷阱已经布好了……"], ["蛛卵……会替我……"], ["蛛网！", "毒牙！"], ["我的……腿！"], ["蛛巢……不会忘记你……"]))
	_reg("death_knight_squire", "死亡骑士侍从", 3, 30, 9, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.WARRIOR, 20,
		[_phase(0, [_atk(9), _skill(1, "虚弱"), _atk(11, "凋零打击")])],
		_q(["黑暗……赐予我力量……"], ["光……我又看到了……光……"], ["凋零！", "黑暗之力！"], ["这具身体……已经不怕痛了……"], ["即便倒下……黑暗……也不会消失……"]))
	_reg("gargoyle", "石像鬼", 3, 24, 7, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.RANGER, 20,
		[_phase(0, [_atk(7), _atk(9, "俯冲"), _skill(1, "易伤")])],
		_q(["（从高处俯冲）"], ["石化……碎裂……"], ["俯冲！", "利爪！"], ["翅膀……破了……"], ["最后的……俯冲——！"]))
	_reg("necromancer_acolyte", "亡灵侍僧", 3, 18, 3, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.PRIEST, 20,
		[_phase(0, [_skill(2, "剧毒"), _skill(1, "力量"), _atk(4, "暗影触碰")])],
		_q(["死者……听从召唤……"], ["灵魂……消散了……"], ["暗影触碰！", "亡灵术！"], ["灵魂石……裂了……"], ["用我的灵魂……召唤……"]))
	# 精英 ×3
	_reg("elite_scourge_giant", "天灾巨人", 3, 100, 12, EnemyCategory.ELITE, GameTypes.EnemyCombatType.WARRIOR, 50,
		[_phase(0, [_atk(12), _atk(16, "瘟疫践踏"), _skill(3, "灼烧"), _def(10)])],
		_q(["（从天而降，地面龟裂）"], ["缝线……全断了……"], ["践踏！", "毁灭！", "碾碎一切！"], ["缝线……裂了……"], ["最后的爆发……"]),
		true, 2)
	_reg("elite_lich_senator", "巫妖议员", 3, 90, 9, EnemyCategory.ELITE, GameTypes.EnemyCombatType.CASTER, 50,
		[_phase(0.4, [_atk(16, "灵魂风暴"), _skill(1, "冻结")]),
		 _phase(0, [_atk(9), _skill(2, "灼烧"), _def(16)])],
		_q(["通灵学院……判你死刑！"], ["灵魂宝石……碎了……"], ["寒冰箭！", "灵魂汲取！"], ["冰盾……裂了！"], ["启动……灵魂爆破……"]),
		true, 2)
	_reg("elite_dreadlord", "恐惧魔王", 3, 85, 11, EnemyCategory.ELITE, GameTypes.EnemyCombatType.CASTER, 50,
		[_phase(0.3, [_atk(18, "吸血鬼之触"), _skill(3, "剧毒")]),
		 _phase(0, [_atk(11), _skill(2, "虚弱"), _atk(9)])],
		_q(["（从暗影中浮现）恐惧……是最好的武器。"], ["不可能……恐惧魔王……怎会……"], ["吸血鬼之触！", "催眠！"], ["暗影护甲……动摇了？"], ["用恐惧……吞噬一切！"]),
		true, 2)
	# Boss ×4
	_reg("boss_plague_lord", "瘟疫领主", 3, 200, 12, EnemyCategory.BOSS, GameTypes.EnemyCombatType.WARRIOR, 60,
		[_phase(0.4, [_atk(20, "瘟疫之锤"), _skill(3, "灼烧"), _atk(16, "天灾冲击"), _def(14)]),
		 _phase(0, [_atk(12), _skill(2, "灼烧"), _atk(10), _def(12)])],
		_q(["瘟疫……会吞噬一切活物。"], ["瘟疫……不会消失……"], ["瘟疫之锤！", "天灾冲击！"], ["渣渣！你敢伤我？"], ["瘟疫……最后的爆发——！"]),
		true)
	_reg("boss_frost_wyrm", "霜龙", 3, 180, 10, EnemyCategory.BOSS, GameTypes.EnemyCombatType.CASTER, 60,
		[_phase(0.4, [_atk(18, "寒冰吐息"), _skill(2, "冻结"), _atk(14), _def(16)]),
		 _phase(0, [_atk(10), _skill(2, "虚弱"), _atk(8), _def(14)])],
		_q(["（冰冷的咆哮响彻天际）"], ["（碎裂成无数冰晶）"], ["寒冰吐息！", "冰封！"], ["龙鳞……裂了？"], ["最后的……寒冰吐息……"]),
		true)
	_reg("boss_kel_thuzad", "大巫妖", 3, 160, 11, EnemyCategory.BOSS, GameTypes.EnemyCombatType.CASTER, 60,
		[_phase(0.4, [_atk(16, "亡灵风暴"), _skill(2, "冻结"), _atk(14, "灵魂链接"), _skill(1, "虚弱")]),
		 _phase(0, [_atk(10), _skill(2, "剧毒"), _atk(8), _skill(1, "易伤")])],
		_q(["哈哈哈……又一个活人，送上门来了。"], ["我的……灵魂宝石……不——！"], ["亡灵风暴！", "灵魂链接！"], ["灵魂宝石……动摇了……"], ["灵魂宝石……碎裂吧——！"]),
		true)
	_reg("boss_lich_king", "巫妖王", 3, 380, 16, EnemyCategory.BOSS, GameTypes.EnemyCombatType.WARRIOR, 0,
		[_phase(0.5, [_atk(30, "霜之哀伤"), _atk(22), _skill(4, "灼烧"), _def(30)]),
		 _phase(0, [_skill(3, "冻结"), _atk(14), _skill(2, "虚弱"), _atk(20, "凋零打击")])],
		_q(["跪下……在巫妖王面前。"], ["永恒的寒冬……终结了？"], ["霜之哀伤！", "臣服于寒冰！"], ["不过是……暖风拂面。"], ["所有人……都将臣服于寒冰王座——！"]))

	# ===== 第四章：暗夜精灵 · 月影城与灰谷 =====
	_reg("night_sentinel", "暗夜哨兵", 4, 24, 12, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.RANGER, 20,
		[_phase(0, [_atk(12, "月刃"), _skill(2, "剧毒"), _atk(8)])],
		_q(["（从树影中现身）入侵者……止步。"], ["月神……指引我……"], ["月刃！", "影遁突袭！"], ["嘶……被发现了……"], ["最后一刃……献给月神……"]))
	_reg("ancient_treant", "远古树人", 4, 46, 6, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.GUARDIAN, 20,
		[_phase(0, [_atk(7), _def(14), _atk(9, "根须绞杀")])],
		_q(["这片……森林……不欢迎你……"], ["森林……会记住……"], ["根须！", "大地之力！"], ["树皮……裂了……"], ["我的根……断了……"]))
	_reg("druid_caster", "德鲁伊", 4, 20, 5, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.CASTER, 20,
		[_phase(0, [_skill(2, "剧毒"), _atk(6), _skill(2, "灼烧"), _atk(7, "月火术")])],
		_q(["自然的平衡……不容破坏！"], ["回归……翡翠梦境……"], ["月火术！", "荆棘缠绕！"], ["树皮术……碎了……"], ["翡翠梦境……赐予我力量……"]))
	_reg("moonblade_huntress", "月刃女猎手", 4, 34, 10, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.WARRIOR, 20,
		[_phase(0, [_atk(10), _skill(1, "虚弱"), _atk(12, "月刃风暴")])],
		_q(["以艾露恩之名……猎杀开始。"], ["月光……暗了……"], ["月刃斩！", "猎手之怒！"], ["这具身体……还能战斗……"], ["即便倒下……月神……也不会忘记……"]))
	_reg("faerie_dragon", "精灵龙", 4, 18, 7, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.CASTER, 20,
		[_phase(0, [_skill(2, "虚弱"), _atk(8, "魔法吐息"), _skill(1, "易伤")])],
		_q(["（翅膀闪烁虹光）"], ["（化为星尘消散）"], ["魔法吐息！", "相位转移！"], ["虹光……暗了……"], ["最后的……魔法……"]))
	_reg("dryad", "树妖", 4, 22, 4, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.PRIEST, 20,
		[_phase(0, [_skill(2, "力量"), _skill(1, "易伤"), _atk(5, "荆棘")])],
		_q(["自然之力……保护森林！"], ["回归……大地……"], ["荆棘！", "自然祝福！"], ["花瓣……凋零了……"], ["最后的……祝福……"]))
	_reg("owl_scout", "猫头鹰斥候", 4, 16, 8, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.RANGER, 20,
		[_phase(0, [_atk(8), _atk(10, "俯冲利爪"), _skill(1, "易伤")])],
		_q(["（无声俯冲）"], ["（羽毛飘散）"], ["利爪！", "俯冲！"], ["翅膀……"], ["最后的……俯冲——"]))
	_reg("keeper_sapling", "守护者树苗", 4, 40, 4, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.GUARDIAN, 20,
		[_phase(0, [_def(12), _atk(5), _def(10), _atk(6, "根须缠绕")])],
		_q(["（根须从地面涌出）"], ["（枯萎倒下）"], ["根须缠绕！", "树皮护盾！"], ["树干……裂了……"], ["最后的……守护……"]))
	_reg("glaive_thrower", "月刃投掷者", 4, 20, 9, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.RANGER, 20,
		[_phase(0, [_atk(9), _atk(11, "月刃回旋"), _skill(1, "灼烧")])],
		_q(["月刃……永不偏离目标。"], ["月刃……回不来了……"], ["月刃回旋！", "穿透！"], ["嘶……"], ["最后一刃……"]))
	_reg("moonwell_keeper", "月亮井守卫", 4, 24, 3, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.PRIEST, 20,
		[_phase(0, [_skill(2, "力量"), _skill(2, "虚弱"), _atk(4, "月光冲击")])],
		_q(["月亮井的力量……不容亵渎。"], ["月光……暗了……"], ["月光冲击！", "月之祝福！"], ["月亮井……波动了……"], ["最后的……月光……"]))
	# 精英 ×3
	_reg("elite_bear_druid", "利爪德鲁伊", 4, 110, 11, EnemyCategory.ELITE, GameTypes.EnemyCombatType.WARRIOR, 50,
		[_phase(0, [_atk(11), _atk(16, "利爪撕裂"), _skill(2, "易伤"), _def(14), _skill(1, "力量")])],
		_q(["（巨熊咆哮）自然之怒……降临！"], ["回归……自然……"], ["利爪撕裂！", "野性冲锋！"], ["熊皮……承受住了！"], ["用我全部的野性……最后一击！"]),
		true, 2)
	_reg("elite_moon_priestess", "月之女祭司", 4, 80, 8, EnemyCategory.ELITE, GameTypes.EnemyCombatType.PRIEST, 50,
		[_phase(0.3, [_skill(3, "剧毒"), _skill(3, "灼烧")]),
		 _phase(0, [_atk(8), _skill(2, "虚弱"), _atk(10, "星辰坠落"), _skill(2, "剧毒")])],
		_q(["艾露恩的低语……你听到了吗？"], ["月光……弥散了……"], ["星辰坠落！", "月神之箭！"], ["月光屏障……裂了……"], ["艾露恩——最终手段！"]),
		true, 2)
	_reg("elite_warden", "典狱长", 4, 90, 12, EnemyCategory.ELITE, GameTypes.EnemyCombatType.RANGER, 50,
		[_phase(0.3, [_atk(20, "暗影突袭"), _skill(2, "易伤")]),
		 _phase(0, [_atk(12), _atk(10), _skill(1, "剧毒")])],
		_q(["（闪现）逃不掉的。"], ["正义……终将……"], ["暗影突袭！", "刀扇！", "闪现斩！"], ["影遁……失败了？"], ["最后的审判——！"]),
		true, 2)
	# Boss ×4
	_reg("boss_grove_keeper", "丛林守护者", 4, 200, 11, EnemyCategory.BOSS, GameTypes.EnemyCombatType.CASTER, 60,
		[_phase(0.4, [_atk(18, "荆棘风暴"), _skill(2, "灼烧"), _atk(14, "自然之怒"), _skill(1, "虚弱"), _def(16)]),
		 _phase(0, [_atk(10), _skill(2, "虚弱"), _atk(9), _skill(2, "剧毒"), _def(14)])],
		_q(["塞纳留斯的子嗣……守护这片森林！"], ["我会……在翡翠梦境中……重生！"], ["荆棘风暴！", "自然之怒！"], ["你……竟敢？"], ["自然的全部力量——爆发吧！"]),
		true)
	_reg("boss_ancient_king", "远古树王", 4, 220, 9, EnemyCategory.BOSS, GameTypes.EnemyCombatType.GUARDIAN, 60,
		[_phase(0.4, [_atk(16, "大地之怒"), _def(26), _atk(12), _skill(2, "虚弱")]),
		 _phase(0, [_def(20), _atk(9), _skill(1, "易伤"), _atk(11)])],
		_q(["千年……未曾有人……走到这里。"], ["你……是第一个……砍倒我的人……"], ["大地之怒！", "根须绞杀！"], ["不过是……树皮划痕……"], ["大地啊……赐予我……最后的力量——！"]),
		true)
	_reg("boss_moonguard", "月光守卫长", 4, 180, 12, EnemyCategory.BOSS, GameTypes.EnemyCombatType.WARRIOR, 60,
		[_phase(0.4, [_atk(20, "月光斩"), _skill(2, "易伤"), _atk(16, "月刃风暴"), _def(14)]),
		 _phase(0, [_atk(12), _skill(1, "虚弱"), _atk(10), _def(12)])],
		_q(["月光之下……无处可逃。"], ["月光……暗了……但会再升起……"], ["月光斩！", "月刃风暴！"], ["月光护甲……承受住了。"], ["月神之力——全部释放！"]),
		true)
	_reg("boss_tyrande", "月神大祭司", 4, 380, 16, EnemyCategory.BOSS, GameTypes.EnemyCombatType.CASTER, 0,
		[_phase(0.5, [_atk(28, "星辰风暴"), _atk(22), _skill(3, "剧毒"), _def(30)]),
		 _phase(0, [_skill(4, "灼烧"), _atk(14), _skill(2, "虚弱"), _atk(20, "月神之箭")])],
		_q(["一万年的守护……不会被你打破。"], ["不可能……月神的力量……怎会被超越……"], ["月神之箭！", "星辰风暴！"], ["有趣……你确实……有些能耐。"], ["艾露恩——用月光的全部力量——净化这个世界！"]))

	# ===== 第五章：龙族 · 龙眠圣殿 =====
	_reg("red_dragon_guard", "红龙卫士", 5, 40, 8, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.GUARDIAN, 20,
		[_phase(0, [_def(14), _atk(8), _def(10), _atk(10, "龙息裁决")])],
		_q(["生命之火……不容亵渎。"], ["任务……失败……"], ["龙息！", "烈焰裁决！"], ["龙鳞……动摇了……"], ["即使倒下……龙火……永不熄灭……"]))
	_reg("bronze_dragonkin", "青铜龙人", 5, 26, 7, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.CASTER, 20,
		[_phase(0, [_skill(2, "虚弱"), _atk(8, "时光冲击"), _skill(1, "冻结")])],
		_q(["你的时间线……出了偏差……"], ["时间线……修复了……"], ["时光逆转！", "沙漏之力！"], ["时间流……紊乱了……"], ["最后的沙粒……"]))
	_reg("blue_dragon_mage", "蓝龙法师", 5, 22, 10, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.RANGER, 20,
		[_phase(0, [_atk(10), _atk(12, "奥术射线"), _skill(1, "易伤")])],
		_q(["奥术……是宇宙的根基。"], ["奥术……消散了……"], ["奥术射线！", "魔力爆发！"], ["嘶……"], ["最后一发……"]))
	_reg("green_dreamwalker", "绿龙梦行者", 5, 24, 3, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.PRIEST, 20,
		[_phase(0, [_skill(2, "力量"), _skill(1, "易伤"), _atk(6, "梦境冲击")])],
		_q(["翡翠梦境的意志……不容亵渎。"], ["回归……梦境……"], ["梦境冲击！", "自然之怒！"], ["梦境……动摇了……"], ["梦境……赐予我……"]))
	_reg("twilight_whelp", "暮光幼龙", 5, 28, 9, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.WARRIOR, 20,
		[_phase(0, [_atk(9), _atk(11, "暮光吐息"), _skill(2, "灼烧")])],
		_q(["（暮光能量涌动）"], ["暮光……消散……"], ["暮光吐息！", "利爪！"], ["鳞片……裂了……"], ["最后的……暮光——！"]))
	_reg("chromatic_drake", "彩色龙人", 5, 32, 8, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.WARRIOR, 20,
		[_phase(0, [_atk(8), _atk(10, "五色吐息"), _skill(1, "灼烧"), _def(8)])],
		_q(["五色之力……汇聚于我！"], ["色彩……褪去了……"], ["五色吐息！", "龙爪！"], ["鳞甲……承受住了……"], ["五色……最后的爆发！"]))
	_reg("nether_drake", "虚空龙人", 5, 22, 8, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.CASTER, 20,
		[_phase(0, [_skill(2, "易伤"), _atk(9, "虚空吐息"), _skill(1, "虚弱")])],
		_q(["虚空……无处不在……"], ["虚空……回收了我……"], ["虚空吐息！", "维度撕裂！"], ["虚空……波动了……"], ["虚空的力量……释放！"]))
	_reg("dragon_priest", "龙语者", 5, 26, 4, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.PRIEST, 20,
		[_phase(0, [_skill(2, "力量"), _skill(2, "灼烧"), _atk(5, "龙语咒")])],
		_q(["龙语……是最古老的力量。"], ["龙语……沉默了……"], ["龙语咒！", "龙之祝福！"], ["咒文……中断了……"], ["最后的……龙语——！"]))
	_reg("obsidian_destroyer", "黑曜石毁灭者", 5, 36, 7, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.GUARDIAN, 20,
		[_phase(0, [_def(12), _atk(7), _def(10), _atk(9, "黑曜石碎击")])],
		_q(["黑曜石……坚不可摧。"], ["黑曜石……碎了……"], ["黑曜石碎击！", "吸魔！"], ["外壳……裂了……"], ["核心……过载——！"]))
	_reg("infinite_agent", "永恒龙人", 5, 30, 9, EnemyCategory.NORMAL, GameTypes.EnemyCombatType.RANGER, 20,
		[_phase(0, [_atk(9), _skill(1, "冻结"), _atk(11, "时间箭")])],
		_q(["时间……是我的武器。"], ["时间线……崩溃了……"], ["时间箭！", "时光停滞！"], ["时间流……紊乱了……"], ["最后的……时间裂隙——！"]))
	# 精英 ×3
	_reg("elite_black_dragon", "黑龙精英", 5, 130, 10, EnemyCategory.ELITE, GameTypes.EnemyCombatType.GUARDIAN, 50,
		[_phase(0, [_def(22), _atk(10), _atk(18, "黑曜石之锤"), _skill(2, "虚弱")])],
		_q(["入侵者检测完毕。启动消灭程序。"], ["黑曜石……碎了……"], ["黑曜石之锤！", "熔岩吐息！"], ["黑曜石护盾……承受冲击……"], ["核心过载……启动自毁倒计时……"]),
		true, 2)
	_reg("elite_twilight_walker", "暮光行者", 5, 90, 13, EnemyCategory.ELITE, GameTypes.EnemyCombatType.CASTER, 50,
		[_phase(0.35, [_atk(20, "暮光爆裂"), _skill(1, "冻结")]),
		 _phase(0, [_atk(13), _skill(2, "易伤"), _atk(10), _skill(2, "虚弱")])],
		_q(["暮光……无处不在……"], ["暮光……会记住你……"], ["暮光爆裂！", "维度撕裂！"], ["暮光……波动了……"], ["暮光的全部力量……释放！"]),
		true, 2)
	_reg("elite_time_lord", "时光领主", 5, 100, 11, EnemyCategory.ELITE, GameTypes.EnemyCombatType.WARRIOR, 50,
		[_phase(0.3, [_atk(18, "时光斩"), _skill(2, "冻结")]),
		 _phase(0, [_atk(11), _atk(14, "时间回溯"), _skill(1, "虚弱")])],
		_q(["时间……在我掌控之中。"], ["时间线……断裂了……"], ["时光斩！", "时间回溯！", "沙漏碎裂！"], ["时间护盾……动摇了？"], ["用时间的全部力量——！"]),
		true, 2)
	# Boss ×4
	_reg("boss_dragon_watcher", "龙眠守护者", 5, 200, 12, EnemyCategory.BOSS, GameTypes.EnemyCombatType.GUARDIAN, 60,
		[_phase(0.4, [_atk(18, "龙息审判"), _def(22), _atk(16, "五色之光"), _skill(2, "易伤")]),
		 _phase(0, [_def(18), _atk(10), _skill(2, "虚弱"), _atk(12)])],
		_q(["五色龙的秩序……不容亵渎。"], ["秩序……被打破了……"], ["龙息审判！", "五色之光！"], ["损伤……在可控范围内……"], ["启动……最终审判协议——！"]),
		true)
	_reg("boss_nether_lord", "虚空领主", 5, 180, 14, EnemyCategory.BOSS, GameTypes.EnemyCombatType.CASTER, 60,
		[_phase(0.4, [_atk(22, "虚空爆裂"), _skill(3, "易伤"), _atk(16), _skill(2, "虚弱")]),
		 _phase(0, [_atk(14), _skill(2, "剧毒"), _atk(10), _skill(1, "冻结")])],
		_q(["虚空……吞噬一切。"], ["虚空……关闭了……"], ["虚空爆裂！", "维度崩塌！"], ["虚空护盾……动摇了？"], ["虚空的全部力量——释放！"]),
		true)
	_reg("boss_deathwing", "熔火死翼", 5, 220, 13, EnemyCategory.BOSS, GameTypes.EnemyCombatType.WARRIOR, 60,
		[_phase(0.4, [_atk(24, "大灾变"), _skill(3, "灼烧"), _atk(18, "熔岩吐息"), _def(16)]),
		 _phase(0, [_atk(13), _skill(2, "灼烧"), _atk(11), _def(14)])],
		_q(["大灾变……来临了！"], ["（咆哮着坠入岩浆）"], ["大灾变！", "熔岩吐息！"], ["你伤到了……我的钢铁之躯？"], ["即使我倒下……世界……也已面目全非——！"]),
		true)
	_reg("boss_dragon_queen", "龙王·生命缚誓者", 5, 480, 18, EnemyCategory.BOSS, GameTypes.EnemyCombatType.CASTER, 0,
		[_phase(0.5, [_atk(28, "生命烈焰"), _atk(22), _skill(3, "剧毒"), _def(30)]),
		 _phase(0, [_skill(4, "灼烧"), _atk(14), _skill(2, "虚弱"), _atk(20)])],
		_q(["生命缚誓者……在此。渺小的骰子掷者，你的终点……就是今天。"], ["你……究竟……是什么？"], ["生命烈焰！", "龙王之怒，碾碎你！"], ["哼……有点意思。"], ["生命之火……动摇了……但我绝不会……就此终结！龙王之怒——爆发！"]))

## ============================================================
## 辅助构造函数
## ============================================================

static func _reg(id: String, enemy_name: String, chapter: int, hp: int, dmg: int, category: EnemyCategory, combat_type: int, gold: int, phases: Array, quotes: EnemyQuotes, drop_relic: bool = false, drop_reroll: int = 0) -> void:
	var c := EnemyConfig.new()
	c.id = id; c.name = enemy_name; c.chapter = chapter; c.base_hp = hp; c.base_dmg = dmg
	c.category = category; c.combat_type = combat_type; c.drop_gold = gold
	c.drop_relic = drop_relic; c.drop_reroll_reward = drop_reroll
	c.phases = phases; c.quotes = quotes
	_all_configs[id] = c

static func _phase(hp_threshold: float, actions: Array) -> EnemyPhase:
	var p := EnemyPhase.new()
	p.hp_threshold = hp_threshold; p.actions = actions
	return p

static func _atk(value: int, desc: String = "") -> EnemyAction:
	var a := EnemyAction.new()
	a.type = EnemyAction.ActionType.ATTACK; a.base_value = value; a.description = desc
	return a

static func _def(value: int) -> EnemyAction:
	var a := EnemyAction.new()
	a.type = EnemyAction.ActionType.DEFEND; a.base_value = value
	return a

static func _skill(value: int, desc: String) -> EnemyAction:
	var a := EnemyAction.new()
	a.type = EnemyAction.ActionType.SKILL; a.base_value = value; a.description = desc; a.scalable = false
	return a

static func _q(enter: Array, death: Array, attack: Array, hurt: Array, low_hp: Array) -> EnemyQuotes:
	var q := EnemyQuotes.new()
	q.enter = enter; q.death = death; q.attack = attack; q.hurt = hurt; q.low_hp = low_hp
	return q
