## 骰子库单例 — 管理骰子拥有/待抽/弃骰/手牌
## 从 game_manager.gd 拆分（GODOT-AUTOLOAD-SPLIT）

extends Node

signal dice_updated
signal toast_requested(msg: String, type: String)

# ============================================================
# 骰子库系统
# ============================================================

var owned_dice: Array[Dictionary] = []   ## [{defId, level}]
var dice_bag: Array[String] = []         ## 骰子库（待抽）
var discard_pile: Array[String] = []     ## 弃骰库

# 手牌
var hand_dice: Array[Dictionary] = []    ## [{id, defId, value, element, selected, rolling, ...}]
## 本回合已打出的骰子 defId 列表（用于嘲讽反噬等"谁打过"判定；回合结束清空）
var dice_played_this_turn: Array[String] = []

# 回合规则（由 TurnManager 设置）
var draw_count: int = 3


# ============================================================
# 骰子库操作（thin wrapper → DiceBagService）
# ============================================================

## 从骰子库抽取 count 个骰子
## 返回 {drawn: Array[Dictionary], shuffled: bool}（保持旧契约）
func draw_from_bag(count: int) -> Dictionary:
	var result := DiceBagService.draw_from_bag(dice_bag, discard_pile, count)
	dice_bag = result.bag
	discard_pile = result.discard
	if result.shuffled:
		toast_requested.emit("弃骰库已洗回骰子库!", "buff")
	return {"drawn": result.drawn, "shuffled": result.shuffled}


## 重掷单个骰子
func reroll_die(die: Dictionary) -> int:
	return DiceBagService.reroll_die(die)


## 将骰子放入弃骰库
func discard_hand_dice(dice_ids: Array[String]) -> void:
	for id in dice_ids:
		discard_pile.append(id)


## 初始化骰子库
func init_dice_bag() -> void:
	dice_bag = DiceBagService.init_bag_from_owned(owned_dice)
	discard_pile = []
