## 精英 / Boss 专属回合行为 — 对应原版 logic/elites.ts
## 职责：在敌人回合所有单体 AI 执行完毕后，按 battleTurn 规则：
##   1. 塞废骰到玩家 owned_dice + dice_bag（cracked / cursed）
##   2. 给精英 / Boss 自身叠护甲
## 参考规范：designer-GODOT-PORT-SPEC §9.5

class_name EliteBossBehavior
extends RefCounted

const EnemyMgr = preload("res://gameplay/battle/battle_enemy_manager.gd")

const ELITE_STUFF_CYCLE: int = 3            ## 精英每 3 回合塞一次碎裂骰
const BOSS_STUFF_CYCLE: int = 3             ## Boss 每 3 回合塞一次碎裂骰
const BOSS_CURSE_CYCLE: int = 2             ## Boss 低血量时每 2 回合塞一次诅咒骰
const BOSS_CURSE_HP_THRESHOLD: float = 0.4  ## Boss 血量 < 40% 才开始塞诅咒骰
const ELITE_ARMOR_CYCLE: int = 3            ## 精英每 3 回合叠护甲
const BOSS_ARMOR_CYCLE: int = 2             ## Boss 每 2 回合叠护甲
const ELITE_ARMOR_MULT: float = 1.5
const BOSS_ARMOR_MULT: float = 2.0


## 敌人回合末（在 _end_turn_cleanup 之前）调用
## 顺序：塞废骰 → 叠护甲（与原版 elites.ts 一致）
static func process(controller: Node, battle_turn: int) -> void:
	if controller == null or not controller.is_inside_tree():
		return
	var living: Array[EnemyInstance] = _collect_living_from_controller(controller)
	if living.is_empty():
		return

	_stuff_broken_dice(living, battle_turn)
	_stack_armor(living, battle_turn)

	EnemyMgr.refresh_enemy_views(controller.enemy_views)
	controller._refresh_status_bar()


# ============================================================
# §9.5 塞废骰
# ============================================================

static func _stuff_broken_dice(living: Array[EnemyInstance], battle_turn: int) -> void:
	for e: EnemyInstance in living:
		var cfg: EnemyConfig = EnemyConfig.get_config(e.config_id)
		if cfg == null:
			continue

		if cfg.category == EnemyConfig.EnemyCategory.ELITE:
			if battle_turn > 0 and battle_turn % ELITE_STUFF_CYCLE == 0:
				_give_dice("cracked", "精英塞入: 碎裂骰 +1")
			continue

		if cfg.category == EnemyConfig.EnemyCategory.BOSS:
			var hp_ratio: float = float(e.hp) / float(maxi(1, e.max_hp))
			# Boss 血量 < 40% 且偶数回合：塞诅咒骰
			if hp_ratio < BOSS_CURSE_HP_THRESHOLD and battle_turn > 0 and battle_turn % BOSS_CURSE_CYCLE == 0:
				_give_dice("cursed", "Boss塞入: 诅咒骰 +1")
			# 每 3 回合塞碎裂骰（与诅咒骰独立判定，可能同回合两个都塞）
			if battle_turn > 0 and battle_turn % BOSS_STUFF_CYCLE == 0:
				_give_dice("cracked", "Boss塞入: 碎裂骰 +1")


## 把指定 defId 的废骰塞进 owned_dice + dice_bag
static func _give_dice(def_id: String, log_msg: String) -> void:
	DiceBag.owned_dice.append({"defId": def_id, "level": 1})
	DiceBag.dice_bag.append(def_id)
	VFX.show_toast(log_msg, "damage")
	BattleLog.log_status(log_msg)
	SoundPlayer.play_sound("enemy_skill")


# ============================================================
# §9.5 叠护甲
# ============================================================

static func _stack_armor(living: Array[EnemyInstance], battle_turn: int) -> void:
	if battle_turn <= 0:
		return
	for e: EnemyInstance in living:
		var cfg: EnemyConfig = EnemyConfig.get_config(e.config_id)
		if cfg == null:
			continue
		if cfg.category == EnemyConfig.EnemyCategory.ELITE and battle_turn % ELITE_ARMOR_CYCLE == 0:
			var armor_gain: int = int(e.attack_dmg * ELITE_ARMOR_MULT)
			e.armor += armor_gain
			BattleLog.log_enemy("🛡 %s 坚壁: +%d 护甲" % [_name_of(e, cfg), armor_gain])
		elif cfg.category == EnemyConfig.EnemyCategory.BOSS and battle_turn % BOSS_ARMOR_CYCLE == 0:
			var armor_gain: int = int(e.attack_dmg * BOSS_ARMOR_MULT)
			e.armor += armor_gain
			BattleLog.log_enemy("🛡 %s 坚壁: +%d 护甲" % [_name_of(e, cfg), armor_gain])


# ============================================================
# 工具
# ============================================================

## 从 BattleController 收集存活敌人（避免直接依赖 controller 的 enemy_views 细节）
static func _collect_living_from_controller(controller: Node) -> Array[EnemyInstance]:
	var result: Array[EnemyInstance] = []
	if not controller.has_method("get") or not ("enemy_views" in controller):
		return result
	for view in controller.enemy_views:
		if is_instance_valid(view) and view.has_method("get_enemy_instance"):
			var inst: EnemyInstance = view.get_enemy_instance()
			if inst != null and inst.hp > 0:
				result.append(inst)
	return result


static func _name_of(e: EnemyInstance, cfg: EnemyConfig) -> String:
	if cfg and cfg.name != "":
		return cfg.name
	return e.config_id
