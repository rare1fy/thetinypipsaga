## 全局事件总线 — 解耦各系统间的通信
## 对应原版 React Context + callbacks 的信号替代方案

extends Node

# ============================================================
# 战斗事件
# ============================================================

signal battle_started(wave_index: int)
signal battle_turn_started(turn: int)
signal battle_turn_ended(turn: int)
signal battle_victory
signal battle_defeat

signal enemy_spawned(enemy: EnemyInstance)
signal enemy_damaged(enemy_uid: String, damage: int, is_crit: bool)
signal enemy_healed(enemy_uid: String, amount: int)
signal enemy_armor_gained(enemy_uid: String, amount: int)
signal enemy_died(enemy_uid: String)
signal enemy_action_started(enemy_uid: String, action_type: String)
signal enemy_action_finished(enemy_uid: String)
signal enemy_quote(enemy_uid: String, text: String)

signal player_damaged(damage: int)
signal player_healed(amount: int)
signal player_armor_gained(amount: int)

# ============================================================
# 骰子事件
# ============================================================

signal dice_drawn(dice: Array)
signal dice_rolled(dice: Array)
signal dice_selected(die_id: int)
signal dice_deselected(die_id: int)
signal dice_played(dice: Array, hand_type: String)
signal dice_rerolled(dice: Array)
signal reroll_count_changed(count: int)

# ============================================================
# 遗物事件
# ============================================================

signal relic_acquired(relic_id: String)
signal relic_triggered(relic_id: String, trigger: String)
signal relic_removed(relic_id: String)

# ============================================================
# 地图/流程事件
# ============================================================

signal node_entered(node_type: GameTypes.NodeType)
signal chapter_changed(chapter: int)
signal shop_opened
signal campfire_opened
signal event_opened(event_id: String)
signal loot_opened(items: Array)
signal dice_reward_opened(dice_pool: Array)
signal skill_select_opened

# ============================================================
# UI事件
# ============================================================

signal floating_text(text: String, color: Color, target: String, icon: String)
signal toast(message: String, type: String)
signal screen_shake
signal fade_out
signal fade_in
