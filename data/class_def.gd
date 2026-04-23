## 职业定义 — 对应原版 data/classes.ts

class_name ClassDef
extends Resource

# 开关：true=从 Excel → JSON 加载，false=走硬编码函数
const USE_JSON_CONFIG: bool = true

@export var id: String = ""  ## warrior / mage / rogue
@export var name: String = ""
@export var title: String = ""
@export var description: String = ""
@export var color: Color = Color.WHITE
@export var color_light: Color = Color.WHITE
@export var color_dark: Color = Color.BLACK

# 回合规则
@export var draw_count: int = 3       ## 每回合抽骰数
@export var max_plays: int = 1        ## 出牌次数
@export var free_rerolls: int = 1     ## 免费重投次数
@export var can_blood_reroll: bool = false  ## 嗜血
@export var keep_unplayed: bool = false     ## 保留未出牌骰子

# 生命值
@export var hp: int = 100
@export var max_hp: int = 100

# 初始骰子库
@export var initial_dice: Array[String] = []

# 职业技能
@export var passive_desc: String = ""
@export var skill_names: Array[String] = []
@export var skill_descs: Array[String] = []

# 普攻特殊规则
@export var normal_attack_multi_select: bool = false


## 获取三大职业定义
static func get_warrior() -> ClassDef:
	var d := ClassDef.new()
	d.id = "warrior"
	d.name = "嗜血狂战"
	d.title = "铁血征服者"
	d.description = "以鲜血为代价，换取毁天灭地的一击。嗜血越多，伤害越高。"
	d.color = Color("#c04040")
	d.color_light = Color("#ff6060")
	d.color_dark = Color("#601010")
	d.draw_count = 3
	d.max_plays = 1
	d.free_rerolls = 1
	d.can_blood_reroll = true
	d.keep_unplayed = false
	d.hp = 120
	d.max_hp = 120
	d.initial_dice = ["standard", "standard", "standard", "standard", "w_bloodthirst", "w_ironwall"]
	d.passive_desc = "【血怒战意】嗜血每次+15%最终伤害（最多5层+75%）；叠满后卖血改为+5护甲；血量≤50%手牌+1；手牌溢出上限时按受伤百分比加伤害倍率；普攻可多选"
	d.skill_names = ["血怒战意", "狂暴本能", "铁拳连打"]
	d.skill_descs = [
		"每次嗜血，最终伤害+15%（最多叠加5层+75%），叠满后卖血获得5点护甲",
		"血量≤50%时手牌上限+1颗；手牌达到6颗上限时，按受伤百分比获得等比例伤害倍率加成",
		"普攻牌型可多选骰子，一次打出所有选中骰子的伤害",
	]
	d.normal_attack_multi_select = true
	return d


static func get_mage() -> ClassDef:
	var d := ClassDef.new()
	d.id = "mage"
	d.name = "星界魔导"
	d.title = "星界禁咒师"
	d.description = "耐心吟唱，两三回合攒齐完美手牌，打出毁天灭地的大招。"
	d.color = Color("#7040c0")
	d.color_light = Color("#a070ff")
	d.color_dark = Color("#301060")
	d.draw_count = 3
	d.max_plays = 1
	d.free_rerolls = 1
	d.can_blood_reroll = false
	d.keep_unplayed = true
	d.hp = 100
	d.max_hp = 100
	d.initial_dice = ["standard", "standard", "standard", "standard", "mage_elemental", "mage_reverse"]
	d.passive_desc = "【星界吟唱】未出牌骰子保留到下回合（3→4→5→6递增）；吟唱回合获得递增护甲；满6后继续吟唱每次+10%伤害；出牌后重置"
	d.skill_names = ["星界吟唱", "吟唱护盾", "过充释放"]
	d.skill_descs = [
		"未出牌的骰子保留到下回合，手牌上限逐层递增（3→4→5→6）",
		"每次吟唱（不出牌）获得递增护甲（6/8/10/12...），层数越高护甲越厚",
		"手牌满6颗后继续吟唱，每回合额外+10%伤害倍率；出牌后重置",
	]
	d.normal_attack_multi_select = false
	return d


static func get_rogue() -> ClassDef:
	var d := ClassDef.new()
	d.id = "rogue"
	d.name = "影锋刺客"
	d.title = "暗影连击者"
	d.description = "一回合出牌两次，连击加成层层递增。暗影残骰是连击的灵魂。"
	d.color = Color("#30a050")
	d.color_light = Color("#60d080")
	d.color_dark = Color("#104020")
	d.draw_count = 3
	d.max_plays = 2
	d.free_rerolls = 1
	d.can_blood_reroll = false
	d.keep_unplayed = false
	d.hp = 90
	d.max_hp = 90
	d.initial_dice = ["standard", "standard", "standard", "r_quickdraw", "r_combomastery"]
	d.passive_desc = "【连击】每回合出牌2次；第2次伤害+20%；同牌型再+25%；暗影残骰是连击核心"
	d.skill_names = ["双刃连击", "精准连击", "暗影残骰"]
	d.skill_descs = [
		"每回合可出牌2次，第2次出牌伤害+20%",
		"两次出牌使用相同牌型时（非普攻），额外+25%伤害加成",
		"连击触发时补充暗影残骰；连击奖励的残骰可保留到下回合",
	]
	d.normal_attack_multi_select = false
	return d


static func get_all() -> Dictionary:
	if USE_JSON_CONFIG:
		var loaded := ConfigLoader.load_class_defs()
		if not loaded.is_empty():
			return loaded
		push_warning("[ClassDef] JSON 加载失败，fallback 到硬编码")
	return {
		"warrior": get_warrior(),
		"mage": get_mage(),
		"rogue": get_rogue(),
	}
