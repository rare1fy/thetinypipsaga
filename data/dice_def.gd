## 骰子定义资源 — 对应原版 DiceDef

class_name DiceDef
extends Resource

@export var id: String = ""
@export var name: String = ""
@export var element: GameTypes.DiceElement = GameTypes.DiceElement.NORMAL
@export var faces: Array[int] = [1, 2, 3, 4, 5, 6]
@export var description: String = ""
@export var rarity: GameTypes.DiceRarity = GameTypes.DiceRarity.COMMON
@export var is_elemental: bool = false
@export var is_cursed: bool = false
@export var is_cracked: bool = false

# onPlay 效果标记（用多个 bool/int/float 字段替代 TS 的可选字段）
# --- 通用 ---
@export var bonus_damage: int = 0
@export var bonus_mult: float = 0.0
@export var heal: int = 0
@export var pierce: int = 0
@export var self_damage: int = 0
@export var self_damage_percent: float = 0.0
@export var status_to_enemy_type: GameTypes.StatusType = GameTypes.StatusType.POISON
@export var status_to_enemy_value: int = 0
@export var status_to_enemy_duration: int = 0
@export var status_to_self_type: GameTypes.StatusType = GameTypes.StatusType.POISON
@export var status_to_self_value: int = 0
@export var status_to_self_duration: int = 0
@export var aoe: bool = false
@export var armor: int = 0

# --- 战士特殊 ---
@export var armor_from_value: bool = false
@export var armor_from_total_points: bool = false
@export var armor_break: bool = false
@export var scale_with_hits: bool = false
@export var first_play_only: bool = false
@export var scale_with_lost_hp: float = 0.0
@export var execute_threshold: float = 0.0
@export var execute_mult: float = 0.0
@export var execute_heal: int = 0
@export var aoe_damage: int = 0
@export var heal_from_value: bool = false
@export var low_hp_override_value: int = 0
@export var low_hp_threshold: float = 0.0
@export var bonus_damage_from_points: float = 0.0
@export var requires_triple: bool = false
@export var scale_with_blood_rerolls: bool = false
@export var self_berserk: bool = false
@export var scale_with_self_damage: bool = false
@export var damage_from_armor: float = 0.0
@export var max_hp_bonus: int = 0
@export var purify_all: bool = false
@export var taunt_all: bool = false
@export var heal_or_max_hp: bool = false
@export var purify_one: bool = false
@export var splinter_damage: float = 0.0
@export var aoe_damage_percent: float = 0.0
@export var combo_splash_damage: bool = false
@export var trigger_all_elements: bool = false

# --- 法师特殊 ---
@export var reverse_value: bool = false
@export var random_target: bool = false
@export var remove_burn: int = 0
@export var heal_on_skip: int = 0
@export var bonus_damage_per_element: int = 0
@export var copy_highest_value: bool = false
@export var bonus_on_keep: int = 0
@export var reroll_on_keep: bool = false
@export var dual_element: bool = false
@export var copy_majority_element: bool = false
@export var devour_die: bool = false
@export var heal_per_cleanse: int = 0
@export var bonus_mult_on_keep: float = 0.0
@export var unify_element: bool = false
@export var override_value: int = 0
@export var swap_with_unselected: bool = false
@export var freeze_bonus: int = 0
@export var bonus_per_turn_kept: int = 0
@export var keep_bonus_cap: int = 99
@export var armor_from_hand_size: float = 0.0
@export var requires_charge: int = 0
@export var bonus_mult_per_extra_charge: float = 0.0
@export var chain_bolt: bool = false
@export var splash_to_random: bool = false
@export var damage_shield: bool = false
@export var purify_one_on_skip: bool = false
@export var mult_per_element: float = 0.0
@export var ignore_for_hand_type: bool = false
@export var boost_lowest_on_keep: int = 0
@export var lock_element: bool = false
@export var multi_element_blast: bool = false
@export var burn_echo: bool = false
@export var frost_echo_damage: float = 0.0
@export var armor_to_damage: bool = false

# --- 盗贼特殊 ---
@export var combo_bonus: float = 0.0
@export var poison_inverse: bool = false
@export var stay_in_hand: bool = false
@export var grant_temp_die: bool = false
@export var draw_from_bag: int = 0
@export var combo_draw_bonus_next_turn: bool = false
@export var grant_play_on_combo: bool = false
@export var clone_self: bool = false
@export var crit_on_second_play: float = 0.0
@export var poison_base: int = 0
@export var poison_bonus_if_poisoned: int = 0
@export var always_bounce: bool = false
@export var bonus_damage_on_second_play: int = 0
@export var steal_armor: float = 0.0
@export var poison_from_poison_dice: int = 0
@export var bonus_mult_on_second_play: float = 0.0
@export var grant_extra_play: bool = false
@export var detonate_poison_percent: float = 0.0
@export var detonate_extra_per_play: float = 0.0
@export var wildcard: bool = false
@export var transfer_debuff: bool = false
@export var detonate_all_on_last_play: bool = false
@export var escalate_damage: float = 0.0
@export var mult_on_third_play: float = 0.0
@export var bounce_and_grow: bool = false
@export var shadow_clone_play: bool = false
@export var boomerang_play: bool = false
@export var double_poison_on_combo: bool = false
@export var grant_shadow_die: bool = false
@export var grant_persistent_shadow_remnant: bool = false
@export var grant_extra_play_on_combo: bool = false
@export var combo_persist_shadow: bool = false
@export var combo_grant_play: bool = false
@export var poison_from_value: bool = false
@export var poison_scale_damage: int = 0
@export var combo_detonate_poison: float = 0.0
@export var combo_scale_damage: float = 0.0
@export var phantom_from_shadow_dice: bool = false
@export var combo_heal: int = 0
@export var grant_play_on_third: bool = false
@export var grant_shadow_remnant: bool = false
@export var combo_grant_extra_play: bool = false


## 判断是否有 onPlay 效果
func has_on_play() -> bool:
	return bonus_damage > 0 or bonus_mult > 0.0 or heal > 0 or pierce > 0 \
		or self_damage > 0 or self_damage_percent > 0.0 or aoe \
		or armor > 0 or armor_from_value or armor_from_total_points \
		or armor_break or scale_with_hits or aoe_damage > 0 \
		or heal_from_value or execute_threshold > 0.0 \
		or scale_with_self_damage or self_berserk or purify_all \
		or taunt_all or heal_or_max_hp or purify_one \
		or chain_bolt or damage_shield or heal_on_skip > 0 \
		or copy_highest_value or bonus_on_keep > 0 or bounce_and_grow \
		or shadow_clone_play or boomerang_play or poison_from_value \
		or grant_shadow_die or draw_from_bag > 0 or combo_grant_play \
		or poison_base > 0 or poison_scale_damage > 0 \
		or combo_scale_damage > 0.0 or escalate_damage > 0.0 \
		or mult_on_third_play > 0.0 or combo_heal > 0 \
		or detonate_poison_percent > 0.0 or trigger_all_elements \
		or grant_extra_play or stay_in_hand or splinter_damage > 0.0 \
		or combo_splash_damage or burn_echo or frost_echo_damage > 0.0 \
		or armor_to_damage or mult_per_element > 0.0 \
		or multi_element_blast or lock_element \
		or bonus_per_turn_kept > 0 or requires_charge > 0 \
		or bonus_mult_per_extra_charge > 0.0 \
		or bonus_mult_on_second_play > 0.0 or combo_detonate_poison > 0.0 \
		or phantom_from_shadow_dice or detonate_all_on_last_play \
		or grant_play_on_third or grant_shadow_remnant \
		or combo_persist_shadow or combo_grant_extra_play \
		or combo_persist_shadow or poison_from_poison_dice > 0 \
		or double_poison_on_combo or steal_armor > 0.0 \
		or reverse_value or scale_with_lost_hp > 0.0 \
		or bonus_damage_from_points > 0.0 or scale_with_blood_rerolls \
		or damage_from_armor > 0.0 or max_hp_bonus > 0 \
		or freeze_bonus > 0 or aoe_damage_percent > 0.0 \
		or low_hp_override_value > 0 or status_to_enemy_value > 0 \
		or status_to_self_value > 0 or heal_per_cleanse > 0 \
		or bonus_damage_per_element > 0 or grant_temp_die \
		or swap_with_unselected or boost_lowest_on_keep > 0 \
		or bonus_mult_on_keep > 0.0 or crit_on_second_play > 0.0 \
		or bonus_damage_on_second_play > 0 or wildcard \
		or transfer_debuff or detonate_extra_per_play > 0.0 \
		or poison_bonus_if_poisoned > 0 or always_bounce \
		or grant_persistent_shadow_remnant or grant_extra_play_on_combo \
		or grant_shadow_remnant or combo_grant_extra_play \
		or grant_play_on_third or purify_one_on_skip \
		or ignore_for_hand_type or execute_heal > 0 \
		or devour_die or random_target or first_play_only \
		or requires_triple or override_value > 0
