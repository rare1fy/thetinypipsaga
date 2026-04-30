## 统计追踪单例 — 战斗/经济统计
## 从 game_manager.gd 拆分（GODOT-AUTOLOAD-SPLIT）

extends Node

# ============================================================
# 统计数据
# ============================================================

var stats: Dictionary = {
	"totalDamageDealt": 0, "maxSingleHit": 0, "totalPlays": 0,
	"totalRerolls": 0, "totalDamageTaken": 0, "totalHealing": 0,
	"totalArmorGained": 0, "battlesWon": 0, "elitesWon": 0,
	"bossesWon": 0, "enemiesKilled": 0, "goldEarned": 0, "goldSpent": 0,
}


# ============================================================
# 记录方法
# ============================================================

func record_damage_dealt(dmg: int) -> void:
	stats.totalDamageDealt += dmg

func record_single_hit(dmg: int) -> void:
	if dmg > stats.maxSingleHit:
		stats.maxSingleHit = dmg

func record_play() -> void:
	stats.totalPlays += 1

func record_reroll() -> void:
	stats.totalRerolls += 1

func record_damage_taken(dmg: int) -> void:
	stats.totalDamageTaken += dmg

func record_healing(amount: int) -> void:
	stats.totalHealing += amount

func record_armor_gained(amount: int) -> void:
	stats.totalArmorGained += amount

func record_battle_won() -> void:
	stats.battlesWon += 1

func record_elite_won() -> void:
	stats.elitesWon += 1

func record_boss_won() -> void:
	stats.bossesWon += 1

func record_enemy_killed() -> void:
	stats.enemiesKilled += 1

func record_gold_earned(amount: int) -> void:
	stats.goldEarned += amount

func record_gold_spent(amount: int) -> void:
	stats.goldSpent += amount

## 兼容旧接口（PlayerState / GameManager 直接调 StatsTracker 的简便入口）
func record_damage(dmg: int, is_single_hit: bool = false) -> void:
	stats.totalDamageDealt += dmg
	if is_single_hit and dmg > stats.maxSingleHit:
		stats.maxSingleHit = dmg

func reset_stats() -> void:
	stats = {
		"totalDamageDealt": 0, "maxSingleHit": 0, "totalPlays": 0,
		"totalRerolls": 0, "totalDamageTaken": 0, "totalHealing": 0,
		"totalArmorGained": 0, "battlesWon": 0, "elitesWon": 0,
		"bossesWon": 0, "enemiesKilled": 0, "goldEarned": 0, "goldSpent": 0,
	}
