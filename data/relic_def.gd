## 遗物定义 — 对应原版 types/relics.ts + data/relicsCore.ts + data/relicsSpecial.ts + data/relicsAugmented.ts
## 因遗物数量庞大(60+)，此处定义数据结构，具体遗物实例在 game_data.gd 中注册

class_name RelicDef
extends Resource

@export var id: String = ""
@export var name: String = ""
@export var description: String = ""
@export var icon: String = ""
@export var rarity: GameTypes.RelicRarity = GameTypes.RelicRarity.COMMON
@export var trigger: GameTypes.RelicTrigger = GameTypes.RelicTrigger.PASSIVE

# 数值效果（用于被动遗物直接查询）
@export var damage: int = 0
@export var armor: int = 0
@export var heal: int = 0
@export var multiplier: float = 0.0
@export var pierce: int = 0
@export var gold_bonus: int = 0
@export var draw_count_bonus: int = 0
@export var shop_discount: int = 0
@export var free_rerolls: int = 0
@export var extra_play: int = 0
@export var extra_reroll: int = 0
@export var extra_draw: int = 0

# 特殊标记
@export var prevent_death: bool = false
@export var overflow_damage: int = 0
@export var can_lock_dice: bool = false
@export var max_points_unlocked: bool = false
@export var straight_upgrade: int = 0
@export var pair_as_triplet: bool = false
@export var reroll_point_boost: int = 0
@export var normal_element_chance: int = 0
@export var temp_draw_bonus: int = 0
@export var unlock_blood_reroll: bool = false
@export var grant_free_reroll: int = 0
@export var grant_extra_play: int = 0
@export var keep_unplayed_once: bool = false
@export var keep_highest_die: int = 0
@export var free_reroll_chance: int = 0
@export var once_per_turn: bool = false
@export var purify_debuff: int = 0

# 计数型遗物
@export var counter: int = 0
@export var max_counter: int = 0
@export var counter_label: String = ""
