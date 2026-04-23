## 游戏平衡数值配置 — 对应原版 config/balance/*.ts

class_name GameBalance

# ============================================================
# 玩家初始值
# ============================================================

const PLAYER_INITIAL := {
	"hp": 100, "maxHp": 100, "armor": 0,
	"freeRerollsPerTurn": 1, "playsPerTurn": 1,
	"souls": 0, "relicSlots": 5,
	"drawCount": 3, "maxDrawCount": 6,
}

# ============================================================
# 层级难度系数
# ============================================================

const DEPTH_SCALING: Array[Dictionary] = [
	{"hpMult": 0.90, "dmgMult": 0.40},
	{"hpMult": 1.10, "dmgMult": 0.50},
	{"hpMult": 1.25, "dmgMult": 0.60},
	{"hpMult": 1.50, "dmgMult": 0.75},
	{"hpMult": 1.20, "dmgMult": 0.65},
	{"hpMult": 1.40, "dmgMult": 0.80},
	{"hpMult": 1.20, "dmgMult": 0.70},
	{"hpMult": 1.80, "dmgMult": 1.00},
	{"hpMult": 1.10, "dmgMult": 0.60},
	{"hpMult": 1.40, "dmgMult": 0.80},
	{"hpMult": 1.60, "dmgMult": 0.90},
	{"hpMult": 1.80, "dmgMult": 1.00},
	{"hpMult": 2.00, "dmgMult": 1.10},
	{"hpMult": 1.30, "dmgMult": 0.80},
	{"hpMult": 2.50, "dmgMult": 1.30},
]

static func get_depth_scaling(depth: int) -> Dictionary:
	if depth < 0:
		return {"hpMult": 0.90, "dmgMult": 0.80}
	if depth >= DEPTH_SCALING.size():
		return DEPTH_SCALING[DEPTH_SCALING.size() - 1]
	return DEPTH_SCALING[depth]

# ============================================================
# 状态效果修正
# ============================================================

const STATUS_EFFECT_MULT := {"weak": 0.75, "vulnerable": 1.5}

# ============================================================
# 战士血怒
# ============================================================

const FURY_CONFIG := {"damagePerStack": 0.15, "maxStack": 5, "armorAtCap": 5}

# ============================================================
# 魂晶
# ============================================================

const SOUL_CRYSTAL_CONFIG := {"baseMult": 1.0, "multPerDepth": 0.2, "conversionRate": 0.15}

static func get_soul_crystal_mult(depth: int, current_mult: float) -> float:
	return current_mult + depth * SOUL_CRYSTAL_CONFIG.multPerDepth

# ============================================================
# 商店
# ============================================================

const SHOP_CONFIG := {
	"relicCount": 3, "priceRange": [20, 80],
	"removeDicePrice": 30,
}

# ============================================================
# 营火
# ============================================================

const CAMPFIRE_CONFIG := {"restHeal": 40, "upgradeCostPerLevel": 20, "maxRelicLevel": 5}

# ============================================================
# 战利品
# ============================================================

const LOOT_CONFIG := {
	"normalDropGold": 25, "eliteDropGold": 50, "bossDropGold": 80,
	"relicChoiceCount": 3,
}

# ============================================================
# 地图
# ============================================================

const MAP_CONFIG := {
	"totalLayers": 15, "midBossLayer": 7,
	"restBeforeBossLayers": [6, 13],
}

# ============================================================
# 章节
# ============================================================

const CHAPTER_CONFIG := {
	"totalChapters": 5,
	"chapterNames": ["幽暗森林", "冰封山脉", "熔岩深渊", "暗影要塞", "永恒之巅"],
	"chapterScaling": [
		{"hpMult": 1.0, "dmgMult": 1.0},
		{"hpMult": 1.25, "dmgMult": 1.15},
		{"hpMult": 1.55, "dmgMult": 1.30},
		{"hpMult": 1.90, "dmgMult": 1.50},
		{"hpMult": 2.30, "dmgMult": 1.70},
	],
	"chapterHealPercent": 0.6,
	"chapterBonusGold": 75,
}

# ============================================================
# 精英/Boss
# ============================================================

const ELITE_CONFIG := {
	"hpThreshold": 80, "bossHpThreshold": 200,
	"bossCurseHpRatio": 0.4, "armorMult": 1.5, "bossArmorMult": 2.0,
	"eliteDiceCycle": 3, "bossCurseCycle": 2,
	"bossCrackedDiceCycle": 3, "eliteArmorCycle": 3, "bossArmorCycle": 2,
}

# ============================================================
# 动画时长(ms)
# ============================================================

const ANIMATION_TIMING := {
	"enemyDeathDuration": 1800,
	"enemyDeathCleanupDelay": 2200,
	"waveTransitionDeathBuffer": 400,
	"bossEntranceDuration": 1200,
	"attackEffectDuration": 400,
	"victoryEnemyCleanupDelay": 2200,
}

# ============================================================
# 骰子奖励
# ============================================================

const DICE_REWARD_REFRESH := {"basePrice": 5, "priceMultiplier": 2, "firstFree": true}
