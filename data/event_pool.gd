## 事件数据配置

# 事件池 — 数据驱动的事件配置
# 由 EventScreen 读取并解析

class_name EventData

# ============================================================
# 事件选项中可用的 action 类型
# ============================================================
# startBattle: 触发战斗
# modifyHp: 修改当前HP（正数=回血，负数=伤害）
# modifySouls: 修改金币（正数=获得，负数=花费）
# modifyMaxHp: 修改最大HP（正数=增加，负数=减少）
# upgradeHandType: 强化牌型（需配合 needsRandomHandType 使用）
# grantRelic: 获得一个随机遗物
# removeDice: 移除一颗非基础骰子
# randomOutcome: 随机结果（按权重选一个 outcome 执行）
# noop: 无操作

# ============================================================
# 1. 阴影中的怪物 — 经典战or逃（战斗类）
# ============================================================
const SHADOW_CREATURE: Dictionary = {
	"id": "shadow_creature",
	"title": "阴影中的怪物",
	"desc": "你在一处阴影中发现了一只落单的怪物，它似乎正在守护着一个散发着微光的宝箱。",
	"icon_id": "skull",
	"options": [
		{
			"label": "发起战斗",
			"sub": "击败它以获取战利品（需要消耗资源战斗）",
			"color": "bg-red-600",
			"action": {"type": "startBattle"},
		},
		{
			"label": "悄悄绕过",
			"sub": "避免战斗，但穿越荆棘受伤 (-8 HP)",
			"color": "bg-zinc-700",
			"action": {"type": "modifyHp", "value": -8, "toast": "穿过荆棘受伤 -8 HP", "toast_type": "damage", "log": "悄悄绕过了怪物，但受到了 8 点伤害。"},
		},
	],
}

# ============================================================
# 2. 古老祭坛 — 献血换牌型升级 or 金币（神殿类）
# ============================================================
const ANCIENT_ALTAR: Dictionary = {
	"id": "ancient_altar",
	"title": "古老祭坛",
	"desc": "你发现了一个被遗忘的祭坛，上面刻着两种不同的符文。你只能选择其中一种力量。",
	"icon_id": "star",
	"options": [
		{
			"label": "贪婪符文",
			"sub": "+30 金币，但 -10 HP（献血祭祀）",
			"color": "bg-amber-600",
			"action": {"type": "randomOutcome", "outcomes": [
				{"weight": 1.0, "actions": [{"type": "modifySouls", "value": 30}, {"type": "modifyHp", "value": -10}], "toast": "获得30金币，损失10HP", "toast_type": "gold", "log": "在祭坛献血获得了 30 金币，损失 10 HP。"},
			]},
		},
		{
			"label": "力量符文",
			"sub": "获得一件遗物，但 -15 HP（剧痛刻印）",
			"color": "bg-purple-600",
			"action": {"type": "randomOutcome", "outcomes": [
				{"weight": 1.0, "actions": [{"type": "grantRelic"}, {"type": "modifyHp", "value": -15}], "toast": "获得遗物！但损失15HP", "toast_type": "buff", "log": "在祭坛忍受剧痛，获得了一件遗物。"},
			]},
		},
	],
}

# ============================================================
# 3. 虚空交易 — 强化牌型 or 安全离开（神殿类）
# ============================================================
const VOID_TRADE: Dictionary = {
	"id": "void_trade",
	"title": "虚空交易",
	"desc": "一个虚幻的身影出现在你面前，向你展示了禁忌的知识。但代价是你的生命力。",
	"icon_id": "skull",
	"needs_random_hand_type": true,
	"options": [
		{
			"label": "强化「{handType}」",
			"sub": "提升该牌型的基础威力，代价 -15 HP",
			"color": "bg-purple-600",
			"action": {"type": "upgradeHandType", "value": -15, "toast": "禁忌知识的代价 -15 HP", "toast_type": "damage", "log": "消耗 15 生命，「{handType}」升级了！"},
		},
		{
			"label": "拒绝交易",
			"sub": "安全离开，保存实力",
			"color": "bg-zinc-700",
			"action": {"type": "noop", "log": "拒绝了虚空交易，安全离开。"},
		},
	],
}

# ============================================================
# 4. 致命陷阱 — 硬扛换金币 or 花钱避开（交易类）
# ============================================================
const DEADLY_TRAP: Dictionary = {
	"id": "deadly_trap",
	"title": "致命陷阱",
	"desc": "你触发了一个隐藏的机关！无数毒箭从墙壁中射出。",
	"icon_id": "flame",
	"options": [
		{
			"label": "硬扛毒箭",
			"sub": "-15 HP，但在残骸中找到 25 金币",
			"color": "bg-orange-600",
			"action": {"type": "randomOutcome", "outcomes": [
				{"weight": 1.0, "actions": [{"type": "modifyHp", "value": -15}, {"type": "modifySouls", "value": 25}], "toast": "-15HP, +25金币", "toast_type": "damage", "log": "踩中陷阱受伤，但在残骸中找到了 25 金币。"},
			]},
		},
		{
			"label": "舍财保命",
			"sub": "-20 金币触发备用机关，完全避开",
			"color": "bg-zinc-700",
			"action": {"type": "modifySouls", "value": -20, "toast": "丢弃20金币避开陷阱", "toast_type": "damage", "log": "丢弃了 20 金币以避开陷阱。"},
		},
	],
}

# ============================================================
# 5. 神秘旅商 — 买药 or 买最大HP or 讨价还价（交易类）
# ============================================================
const MYSTERIOUS_MERCHANT: Dictionary = {
	"id": "mysterious_merchant",
	"title": "神秘旅商",
	"desc": "一位戴着面具的旅商从暗处走来，他的背包里似乎有些不寻常的东西。",
	"icon_id": "shopBag",
	"options": [
		{
			"label": "购买生命药剂",
			"sub": "-25 金币，回复 35 HP",
			"color": "bg-emerald-600",
			"action": {"type": "randomOutcome", "outcomes": [
				{"weight": 1.0, "actions": [{"type": "modifySouls", "value": -25}, {"type": "modifyHp", "value": 35}], "toast": "-25金币, +35HP", "toast_type": "heal", "log": "购买了生命药剂，回复 35 HP。"},
			]},
		},
		{
			"label": "购买强化药水",
			"sub": "-35 金币，永久 +10 最大生命",
			"color": "bg-blue-600",
			"action": {"type": "randomOutcome", "outcomes": [
				{"weight": 1.0, "actions": [{"type": "modifySouls", "value": -35}, {"type": "modifyMaxHp", "value": 10}], "toast": "-35金币, 最大HP+10", "toast_type": "buff", "log": "购买了强化药水，最大生命 +10！"},
			]},
		},
		{
			"label": "讨价还价",
			"sub": "50%概率免费获得药剂，50%概率被赶走",
			"color": "bg-zinc-700",
			"action": {"type": "randomOutcome", "outcomes": [
				{"weight": 0.5, "actions": [{"type": "modifyHp", "value": 25}], "toast": "讨价成功！免费回复25HP", "toast_type": "heal", "log": "讨价还价成功，免费获得药剂！"},
				{"weight": 0.5, "actions": [{"type": "noop"}], "toast": "旅商不悦，拒绝交易", "toast_type": "damage", "log": "旅商被激怒，拒绝了你的交易。"},
			]},
		},
	],
}

# ============================================================
# 6. 命运之轮 — 赌金币 or 安全离开（交易类）
# ============================================================
const WHEEL_OF_FATE: Dictionary = {
	"id": "wheel_of_fate",
	"title": "命运之轮",
	"desc": "你发现了一个古老的命运之轮，轮盘上刻满了神秘的符号。转动它需要付出代价。",
	"icon_id": "refresh",
	"options": [
		{
			"label": "献血转动（-10 HP）",
			"sub": "60%概率+40金币，40%概率获得一件遗物",
			"color": "bg-cyan-600",
			"action": {"type": "randomOutcome", "outcomes": [
				{"weight": 0.6, "actions": [{"type": "modifyHp", "value": -10}, {"type": "modifySouls", "value": 40}], "toast": "幸运！-10HP, +40金币", "toast_type": "gold", "log": "命运之轮转出了 40 金币！"},
				{"weight": 0.4, "actions": [{"type": "modifyHp", "value": -10}, {"type": "grantRelic"}], "toast": "大吉！-10HP, 获得遗物！", "toast_type": "buff", "log": "命运之轮赐予了一件遗物！"},
			]},
		},
		{
			"label": "观望离开",
			"sub": "安全但错过机会",
			"color": "bg-zinc-700",
			"action": {"type": "noop", "log": "你选择了安全离开。"},
		},
	],
}

# ============================================================
# 7. 诅咒之泉 — 回血但降最大HP or 花钱净化（神殿类）
# ============================================================
const CURSED_SPRING: Dictionary = {
	"id": "cursed_spring",
	"title": "诅咒之泉",
	"desc": "一汪散发着诡异紫光的泉水出现在你面前。泉水能恢复伤口，但也会留下诅咒。",
	"icon_id": "heart",
	"options": [
		{
			"label": "饮用泉水",
			"sub": "+40 HP，但最大生命永久 -5",
			"color": "bg-emerald-600",
			"action": {"type": "randomOutcome", "outcomes": [
				{"weight": 1.0, "actions": [{"type": "modifyHp", "value": 40}, {"type": "modifyMaxHp", "value": -5}], "toast": "+40HP, 最大生命-5", "toast_type": "heal", "log": "饮用诅咒之泉，恢复40HP但最大生命永久-5。"},
			]},
		},
		{
			"label": "净化泉水",
			"sub": "-15 金币净化后安全饮用，+20 HP",
			"color": "bg-blue-600",
			"action": {"type": "randomOutcome", "outcomes": [
				{"weight": 1.0, "actions": [{"type": "modifySouls", "value": -15}, {"type": "modifyHp", "value": 20}], "toast": "-15金币, +20HP", "toast_type": "heal", "log": "花费15金币净化泉水，安全回复20HP。"},
			]},
		},
	],
}

# ============================================================
# 8. 骰子赌徒 — 赌金币 or 赌HP or 离开（交易类）
# ============================================================
const DICE_GAMBLER: Dictionary = {
	"id": "dice_gambler",
	"title": "骰子赌徒",
	"desc": "一个神秘的赌徒向你发起挑战：用你的资源赌一把，赢了翻倍，输了全无。",
	"icon_id": "question",
	"options": [
		{
			"label": "赌上 30 金币",
			"sub": "50%概率+60金币，50%概率-30金币",
			"color": "bg-amber-600",
			"action": {"type": "randomOutcome", "outcomes": [
				{"weight": 0.5, "actions": [{"type": "modifySouls", "value": 60}], "toast": "赢了！+60金币", "toast_type": "gold", "log": "赌赢了！获得60金币！"},
				{"weight": 0.5, "actions": [{"type": "modifySouls", "value": -30}], "toast": "输了...-30金币", "toast_type": "damage", "log": "赌输了，损失30金币。"},
			]},
		},
		{
			"label": "赌上生命力",
			"sub": "50%概率获得遗物，50%概率-20HP",
			"color": "bg-red-600",
			"action": {"type": "randomOutcome", "outcomes": [
				{"weight": 0.5, "actions": [{"type": "grantRelic"}], "toast": "赢了！获得遗物！", "toast_type": "buff", "log": "赌赢了！获得一件遗物！"},
				{"weight": 0.5, "actions": [{"type": "modifyHp", "value": -20}], "toast": "输了...-20HP", "toast_type": "damage", "log": "赌输了，损失20HP。"},
			]},
		},
		{
			"label": "拒绝赌博",
			"sub": "安全离开",
			"color": "bg-zinc-700",
			"action": {"type": "noop", "log": "你拒绝了赌徒的挑战。"},
		},
	],
}

# ============================================================
# 9. 遗忘铸炉 — 强化牌型 or 获取遗物（神殿类）
# ============================================================
const FORGOTTEN_FORGE: Dictionary = {
	"id": "forgotten_forge",
	"title": "遗忘铸炉",
	"desc": "一座仍在燃烧的古老铸炉隐藏在洞穴深处。炉火中似乎蕴含着某种力量。",
	"icon_id": "flame",
	"needs_random_hand_type": true,
	"options": [
		{
			"label": "投入金币淬炼",
			"sub": "-30 金币，强化「{handType}」牌型",
			"color": "bg-orange-600",
			"action": {"type": "randomOutcome", "outcomes": [
				{"weight": 1.0, "actions": [{"type": "modifySouls", "value": -30}, {"type": "upgradeHandType", "value": 0}], "toast": "-30金币，牌型强化！", "toast_type": "buff", "log": "花费30金币在铸炉中淬炼，「{handType}」升级了！"},
			]},
		},
		{
			"label": "探索铸炉遗迹",
			"sub": "70%概率找到遗物，30%概率被烫伤(-12HP)",
			"color": "bg-amber-600",
			"action": {"type": "randomOutcome", "outcomes": [
				{"weight": 0.7, "actions": [{"type": "grantRelic"}], "toast": "在遗迹中找到了遗物！", "toast_type": "buff", "log": "在铸炉遗迹中发现了一件遗物！"},
				{"weight": 0.3, "actions": [{"type": "modifyHp", "value": -12}], "toast": "被铸炉烫伤 -12HP", "toast_type": "damage", "log": "探索时被铸炉烫伤，损失12HP。"},
			]},
		},
		{
			"label": "离开",
			"sub": "安全离开",
			"color": "bg-zinc-700",
			"action": {"type": "noop", "log": "你选择离开铸炉。"},
		},
	],
}

# ============================================================
# 10. 灵魂裂隙 — 高风险高收益（神殿类）
# ============================================================
const SOUL_RIFT: Dictionary = {
	"id": "soul_rift",
	"title": "灵魂裂隙",
	"desc": "空间中出现了一道闪烁的裂隙，另一侧传来强大的能量波动。踏入其中可能改变命运。",
	"icon_id": "star",
	"options": [
		{
			"label": "踏入裂隙",
			"sub": "-20 HP，但获得遗物 + 30金币",
			"color": "bg-purple-600",
			"action": {"type": "randomOutcome", "outcomes": [
				{"weight": 1.0, "actions": [{"type": "modifyHp", "value": -20}, {"type": "grantRelic"}, {"type": "modifySouls", "value": 30}], "toast": "-20HP, 获得遗物+30金币！", "toast_type": "buff", "log": "踏入灵魂裂隙，付出20HP的代价，获得遗物和30金币。"},
			]},
		},
		{
			"label": "谨慎观察",
			"sub": "从裂隙边缘拾取散落的金币 (+15金币)",
			"color": "bg-amber-600",
			"action": {"type": "modifySouls", "value": 15, "toast": "+15金币", "toast_type": "gold", "log": "从裂隙边缘拾取了15金币。"},
		},
	],
}

# ============================================================
# 11. 神秘熔炉 — 删骰子事件（交易类）
# ============================================================
const MYSTIC_FURNACE: Dictionary = {
	"id": "mystic_furnace",
	"title": "神秘熔炉",
	"desc": "你发现了一座燃烧着异火的古老熔炉。火焰似乎可以熔炼一切。你可以将一颗骰子投入其中，但熔炉的火焰会灼伤你。",
	"icon_id": "flame",
	"options": [
		{
			"label": "投入骰子",
			"sub": "移除一颗非基础骰子，但 -12 HP",
			"color": "bg-red-600",
			"action": {"type": "randomOutcome", "outcomes": [
				{"weight": 1.0, "actions": [{"type": "removeDice"}, {"type": "modifyHp", "value": -12}], "toast": "骰子已熔炼，-12HP", "toast_type": "damage", "log": "将一颗骰子投入熔炉，火焰灼伤了你 12 HP。"},
			]},
		},
		{
			"label": "离开",
			"sub": "不冒险，安全离开",
			"color": "bg-zinc-700",
			"action": {"type": "noop", "toast": "你谨慎地离开了熔炉。", "log": "没有使用神秘熔炉。"},
		},
	],
}


# ============================================================
# 事件池 — 所有事件的合集
# ============================================================
const EVENTS_POOL: Array[Dictionary] = [
	SHADOW_CREATURE,
	ANCIENT_ALTAR,
	VOID_TRADE,
	DEADLY_TRAP,
	MYSTERIOUS_MERCHANT,
	WHEEL_OF_FATE,
	CURSED_SPRING,
	DICE_GAMBLER,
	FORGOTTEN_FORGE,
	SOUL_RIFT,
	MYSTIC_FURNACE,
]
