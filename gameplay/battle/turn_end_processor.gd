## 回合结束+敌方回合处理器
## 从 battle_controller.gd 拆出（B1 行数限制）
## 职责：回合结束处理（法师吟唱/冥想/遗物/嘲讽反噬）+ 敌方回合调度
## 对应原版 turnEndProcessing.ts + enemyAI.ts
class_name TurnEndProcessor
extends RefCounted


# ============================================================
# 回合结束处理（对应原版 processTurnEnd）
# ============================================================

## 处理回合结束逻辑（法师吟唱 / 冥想 / 遗物 / 嘲讽反噬）
## 参数：
##   played_this_turn: 本回合是否出过牌
##   controller: BattleController 引用（用于 UI 刷新）
static func process_turn_end(played_this_turn: bool, controller: BattleController) -> void:
	# 法师星界吟唱 — 对应原版 turnEndProcessing L54-85
	_resolve_mage_chant(played_this_turn, controller)

	# 冥想骰子 healOnSkip — 未出牌时回血
	_resolve_meditation_skip(played_this_turn, controller)

	# on_turn_end 遗物触发
	RelicEngine.on_turn_end(PlayerState.relics, controller)

	# 嘲讽骰子 tauntAll 反噬
	_resolve_taunt_backlash(played_this_turn, controller)

	controller._refresh_status_bar()


# ============================================================
# 法师星界吟唱
# ============================================================

static func _resolve_mage_chant(played_this_turn: bool, controller: BattleController) -> void:
	if PlayerState.player_class != "mage":
		return

	if not played_this_turn:
		var current_charge: int = PlayerState.charge_stacks
		var max_charge_for_hand: int = 6 - DiceBag.draw_count
		var charge_armor: int = 6 + current_charge * 2

		if current_charge >= max_charge_for_hand:
			# 过充：手牌上限已满6，继续蓄力给倍率加成（每次+10%）
			PlayerState.charge_stacks = current_charge + 1
			PlayerState.mage_overcharge_mult += 0.1
			PlayerState.gain_armor(charge_armor)
			_emit_chant_armor_text(controller, charge_armor)
			VFX.show_toast("过充! 伤害+%d%%" % int(PlayerState.mage_overcharge_mult * 100), "buff")
		else:
			# 正常吟唱：手牌上限+1
			PlayerState.charge_stacks = current_charge + 1
			PlayerState.gain_armor(charge_armor)
			_emit_chant_armor_text(controller, charge_armor)
			var new_hand_limit: int = mini(6, DiceBag.draw_count + PlayerState.charge_stacks)
			VFX.show_toast("吟唱 %d/6" % new_hand_limit, "buff")
	else:
		# 出了牌就重置吟唱（护甲在回合收尾 end_turn_and_draw_phase 统一清零）
		PlayerState.charge_stacks = 0
		PlayerState.mage_overcharge_mult = 0.0


## §8.2 在玩家 HP 条上浮出 "+N 护甲" 文字
## 单独抽函数：吟唱/过充两条分支共用，降重复
static func _emit_chant_armor_text(controller: BattleController, armor_amount: int) -> void:
	if controller == null or controller._float_layer == null or controller.hp_bar == null:
		return
	var pos: Vector2 = controller.hp_bar.global_position + controller.hp_bar.size * 0.5
	VFX.spawn_armor_text(controller._float_layer, pos, armor_amount)


# ============================================================
# 冥想骰子 healOnSkip
# ============================================================

static func _resolve_meditation_skip(played_this_turn: bool, _controller: BattleController) -> void:
	if played_this_turn:
		return

	for d: Dictionary in DiceBag.hand_dice:
		var def: DiceDef = GameData.get_dice_def(d.get("defId", ""))
		if def == null:
			continue
		if def.heal_on_skip > 0:
			PlayerState.heal(def.heal_on_skip)
		if def.purify_one_on_skip:
			var debuff_types: Array[int] = [
				GameTypes.StatusType.POISON, GameTypes.StatusType.BURN,
				GameTypes.StatusType.VULNERABLE, GameTypes.StatusType.WEAK,
			]
			for st: int in debuff_types:
				if PlayerState.has_status(st):
					PlayerState.statuses = PlayerState.statuses.filter(
						func(s: StatusEffect) -> bool: return s.type != st
					)
					VFX.show_toast("冥想净化", "buff")
					break


# ============================================================
# 嘲讽骰子 tauntAll 反噬
# ============================================================

static func _resolve_taunt_backlash(played_this_turn: bool, _controller: BattleController) -> void:
	if not played_this_turn:
		return

	var has_taunt: bool = false
	for dice_id: String in DiceBag.dice_played_this_turn:
		var def: DiceDef = GameData.get_dice_def(dice_id)
		if def and def.taunt_all:
			has_taunt = true
			break

	if not has_taunt:
		return

	# 嘲讽骰子 tauntAll 反噬 — 累计所有存活敌人的攻击力
	var total_taunt_dmg: int = 0
	for view: Node in _controller.enemy_views:
		if not is_instance_valid(view):
			continue
		if view.has_method("get_enemy_instance"):
			var inst: EnemyInstance = view.get_enemy_instance()
			if inst and inst.hp > 0:
				total_taunt_dmg += inst.attack_dmg

	# 嘲讽拉近：所有存活敌人 distance = 0
	for view: Node in _controller.enemy_views:
		if not is_instance_valid(view):
			continue
		if view.has_method("get_enemy_instance"):
			var inst: EnemyInstance = view.get_enemy_instance()
			if inst:
				inst.distance = 0

	if total_taunt_dmg <= 0:
		return

	# TODO: §8.6 规范要求 400ms 延迟后应用伤害（原版有动画）
	# 当前为瞬间应用，需迁入 BattleController 用 SceneTreeTimer 实现异步
	var absorbed: int = mini(PlayerState.armor, total_taunt_dmg)
	PlayerState.armor = maxi(0, PlayerState.armor - absorbed)
	var hp_dmg: int = total_taunt_dmg - absorbed
	if hp_dmg > 0:
		PlayerState.hp = maxi(0, PlayerState.hp - hp_dmg)
	VFX.show_toast("咆哮反噬! -%d 伤害" % total_taunt_dmg, "damage")
	BattleLog.log_enemy("咆哮反噬: 全体敌人攻击 → %d 伤害" % total_taunt_dmg)
