## 核心类型定义 — 对应原版 types/game.ts + types/dice.ts + types/entities.ts + types/relics.ts

class_name GameTypes

# ============================================================
# 骰子元素与稀有度
# ============================================================

enum DiceElement { NORMAL, FIRE, ICE, THUNDER, POISON, HOLY, SHADOW }
enum DiceRarity { COMMON, UNCOMMON, RARE, LEGENDARY, CURSE }

# ============================================================
# 牌型
# ============================================================

enum HandType {
	NORMAL_ATTACK,  ## 普通攻击
	PAIR,           ## 对子
	DOUBLE_PAIR,    ## 连对
	TRIPLE_PAIR,    ## 三连对
	TRIPLET,        ## 三条
	STRAIGHT_3,     ## 顺子(3)
	STRAIGHT_4,     ## 4顺
	STRAIGHT_5,     ## 5顺
	STRAIGHT_6,     ## 6顺
	SAME_ELEMENT,   ## 同元素
	FULL_HOUSE,     ## 葫芦
	FOUR_OF_KIND,   ## 四条
	FIVE_OF_KIND,   ## 五条
	SIX_OF_KIND,    ## 六条
	ELEMENT_STRAIGHT, ## 元素顺
	ELEMENT_FULL_HOUSE, ## 元素葫芦
	ROYAL_ELEMENT_STRAIGHT, ## 皇家元素顺
	INVALID,
}

# ============================================================
# 状态效果
# ============================================================

enum StatusType { POISON, BURN, DODGE, VULNERABLE, STRENGTH, WEAK, ARMOR, SLOW, FREEZE }

# ============================================================
# 遗物触发时机与稀有度
# ============================================================

enum RelicTrigger {
	ON_PLAY, ON_KILL, ON_REROLL, ON_TURN_START, ON_TURN_END,
	ON_BATTLE_START, ON_BATTLE_END, ON_DAMAGE_TAKEN, ON_FATAL,
	ON_FLOOR_CLEAR, ON_MOVE, PASSIVE
}

enum RelicRarity { COMMON, UNCOMMON, RARE, LEGENDARY }

# ============================================================
# 地图节点类型
# ============================================================

enum NodeType { ENEMY, ELITE, BOSS, EVENT, CAMPFIRE, TREASURE, MERCHANT }

# ============================================================
# 敌人战斗类型
# ============================================================

enum EnemyCombatType { WARRIOR, GUARDIAN, RANGER, CASTER, PRIEST }

# ============================================================
# 游戏阶段
# ============================================================

enum GamePhase {
	START, CLASS_SELECT, MAP, BATTLE, PLAYER_TURN, ENEMY_TURN, MERCHANT, EVENT,
	CAMPFIRE, VICTORY, GAME_OVER, LOOT, SKILL_SELECT,
	DICE_REWARD, CHAPTER_TRANSITION, TREASURE
}
