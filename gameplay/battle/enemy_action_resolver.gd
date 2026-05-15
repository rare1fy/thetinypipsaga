## 敌人单次行动解算器 — 从 BattleController 抽出
## 职责：在敌人回合里针对单个 EnemyInstance 做"上盾嘲讽 / 治疗增益 / DoT / 普通攻击"分流
## 纯函数+副作用隔离：攻击会改 PlayerState / GameManager / EnemyInstance 的状态，UI 刷新由调用方负责

class_name EnemyActionResolver

const EnemyMgr = preload("res://gameplay/battle/battle_enemy_manager.gd")

const GUARDIAN_DEFENSE_CYCLE: int = 2  ## 每 N 回合上一次盾并嘲讽
const GUARDIAN_SHIELD_MULT: float = 1.5

## 精英 / Boss 回合末专属行为（塞废骰 / 叠护甲），§9.5
## 用 preload 显式声明，避免 class_name 编译顺序导致的 "Identifier not declared" 报错
const _EliteBossBehavior = preload("res://gameplay/battle/elite_boss_behavior.gd")

## controller 退出树时仍可能触发 pending timer 的 lambda，
## 用 WeakRef 包裹 controller 引用，引擎不会报 "Lambda capture was freed" 警告。
## 在 lambda 内通过 ref.get_ref() 取回 Object，返回 null 说明已释放，安全跳过。

## 敌人回合入口：驱动所有敌人分帧执行 AI（递归 timer 调度）
## 调用方 controller 需要提供以下方法:
## - _refresh_enemy_views() / _refresh_status_bar()
## - _on_battle_ended()
## - _begin_player_turn()
## - 以及 `hp_bar` 节点引用（震屏/脉冲用）
static func run_turn(controller: Node, living: Array[EnemyInstance], index: int = 0) -> void:
	if controller == null or not controller.is_inside_tree():
		return
	if index >= living.size():
		_end_turn_cleanup(controller)
		return
	var e: EnemyInstance = living[index]
	if e.hp <= 0:
		run_turn(controller, living, index + 1)
		return
	# 用 WeakRef 包裹 controller，避免场景切换时引擎报 "Lambda capture was freed"
	var wr: WeakRef = weakref(controller)
	# 冻结跳过
	if e.is_frozen():
		EnemyMgr.refresh_enemy_views(controller.enemy_views)
		controller.get_tree().create_timer(0.25).timeout.connect(
			func() -> void:
				var c: Node = wr.get_ref() as Node
				if c != null and c.is_inside_tree():
					run_turn(c, living, index + 1)
		)
		return
	# 近战推进
	var is_melee: bool = (
		e.combat_type == GameTypes.EnemyCombatType.WARRIOR
		or e.combat_type == GameTypes.EnemyCombatType.GUARDIAN
	)
	if is_melee and e.distance > 0:
		if not e.is_slowed():
			e.distance = maxi(0, e.distance - 1)
		EnemyMgr.refresh_enemy_views(controller.enemy_views)
		controller.get_tree().create_timer(0.3).timeout.connect(
			func() -> void:
				var c: Node = wr.get_ref() as Node
				if c != null and c.is_inside_tree():
					run_turn(c, living, index + 1)
		)
		return
	# 时序：攻击型敌人先播攻击动画 → 等待 → 伤害结算
	# Priest/Caster/Guardian上盾 是施法行为，不播攻击动画，直接结算
	var is_attack_action: bool = _is_attack_action(e, GameManager.battle_turn)
	if is_attack_action:
		_play_enemy_attack_anim(controller, e)
	var delay: float = 0.3 if is_attack_action else 0.0
	var wr2: WeakRef = weakref(controller)
	if delay > 0.0:
		controller.get_tree().create_timer(delay).timeout.connect(
			func() -> void:
				var c: Node = wr2.get_ref() as Node
				if c == null or not c.is_inside_tree():
					return
				_resolve_enemy_action(c, e, wr, living, index)
		)
	else:
		_resolve_enemy_action(controller, e, wr, living, index)


## 判断敌人本次行动是否为攻击（需要播放攻击动画 + 延迟结算）
## Pattern-Driven：从 get_action() 获取行动类型判断
static func _is_attack_action(e: EnemyInstance, battle_turn: int) -> bool:
	var action: Dictionary = e.get_action()
	var action_type: String = action.get("type", "攻击")
	return action_type == "攻击"

## 播放敌人攻击动画（遍历 enemy_views 找到匹配 uid 的 EnemyView）
static func _play_enemy_attack_anim(controller: Node, e: EnemyInstance) -> void:
	for view: Node in controller.enemy_views:
		if not is_instance_valid(view):
			continue
		if view.has_method("get_enemy_uid") and view.get_enemy_uid() == e.uid:
			if view.has_method("play_attack_anim"):
				view.play_attack_anim()
			break

## 执行敌人 AI 行动 + 伤害结算 + 延迟进入下一个敌人
static func _resolve_enemy_action(controller: Node, e: EnemyInstance, wr: WeakRef, living: Array[EnemyInstance], index: int) -> void:
	# 防御性检查：敌人在动画期间可能被 DoT 等效果击杀
	if e.hp <= 0:
		run_turn(controller, living, index + 1)
		return
	var on_shake: Callable = func(strength: float, duration: float) -> void:
		var c: Node = wr.get_ref() as Node
		if c != null and c.is_inside_tree():
			VFX.shake(c.get_shake_target(), strength, duration)
	var on_hp_pulse: Callable = func() -> void:
		var c: Node = wr.get_ref() as Node
		if c != null and c.is_inside_tree() and c.hp_bar:
			VFX.hp_pulse(c.hp_bar, true)
	resolve(e, GameManager.battle_turn, on_shake, on_hp_pulse)
	controller._refresh_status_bar()
	EnemyMgr.refresh_enemy_views(controller.enemy_views)
	if PlayerState.hp <= 0:
		controller._on_battle_ended(false)
		return
	controller.get_tree().create_timer(0.4).timeout.connect(
		func() -> void:
			var c: Node = wr.get_ref() as Node
			if c != null and c.is_inside_tree():
				run_turn(c, living, index + 1)
	)

## 敌人回合末结算：玩家 POISON/BURN DoT + 状态 tick，然后进入下一玩家回合
static func _end_turn_cleanup(controller: Node) -> void:
	# §9.5 精英 / Boss 专属：塞废骰 + 叠护甲（在 DoT 结算之前，对齐原版 elites.ts 调用点）
	_EliteBossBehavior.process(controller, GameManager.battle_turn)

	# [FIX-P4] 玩家中毒结算（旧版 enemy_ai.gd 中有，新版遗漏）
	var poison: int = GameManager.get_status_value(GameTypes.StatusType.POISON)
	if poison > 0:
		PlayerState.take_damage(poison)
		# 中毒递减：value-1，如果 value<=0 则 tick_statuses 会清理
		for s: StatusEffect in PlayerState.statuses:
			if s.type == GameTypes.StatusType.POISON:
				s.value = maxi(0, s.value - 1)
				break
		controller._refresh_status_bar()
		if PlayerState.hp <= 0:
			controller._on_battle_ended(false)
			return

	var burn: int = GameManager.get_status_value(GameTypes.StatusType.BURN)
	if burn > 0:
		PlayerState.take_damage(burn)
		PlayerState.statuses = PlayerState.statuses.filter(
			func(s: StatusEffect) -> bool: return s.type != GameTypes.StatusType.BURN
		)
		controller._refresh_status_bar()
		if PlayerState.hp <= 0:
			controller._on_battle_ended(false)
			return
	GameManager.tick_statuses()
	# v0.5 玩家易伤层数衰减：每敌方回合结束 -1 层
	StatusService.tick_vulnerable(PlayerState.statuses)
	controller._refresh_status_bar()
	# 回合收尾 + 抽牌（Godot 设计规范 §4.4）：reset 6 字段 + executeDrawPhase
	# 必须在 _begin_player_turn 之前完成
	TurnManager.end_turn_and_draw_phase()
	controller._begin_player_turn()


## 按敌人 Pattern 配置分流执行单次行动（对齐原版 Pattern-Driven 系统）
## 优先使用 EnemyInstance.get_action() 的 phases.actions 轮播结果
## 无配置时 fallback 到旧 combatType 分支
## on_shake: Callable(strength:float, duration:float) — 震屏回调
## on_hp_pulse: Callable() — HP 条脉冲回调
static func resolve(
	e: EnemyInstance,
	battle_turn: int,
	on_shake: Callable,
	on_hp_pulse: Callable
) -> void:
	# Pattern-Driven：从配置获取本回合行动
	var action: Dictionary = e.get_action()
	var action_type: String = action.get("type", "攻击")
	var action_value: int = action.get("value", e.attack_dmg)
	var action_desc: String = action.get("description", "")

	# 分流：防御 / 技能 / 攻击
	match action_type:
		"防御":
			_execute_defend(e, action_value, action_desc, on_shake)
		"技能":
			_execute_skill(e, action_value, action_desc)
		_:
			# 攻击（含 Ranger 追击）
			_resolve_attacker(e, on_shake, on_hp_pulse)


## 执行防御行动（Guardian 上盾 + 嘲讽，或通用防御）
static func _execute_defend(e: EnemyInstance, value: int, desc: String, on_shake: Callable) -> void:
	var base_shield: int = value if value > 0 else int(e.attack_dmg * GUARDIAN_SHIELD_MULT)
	# P2 Trait: bulwark 防御获双倍护甲
	var shield_val: int = int(float(base_shield) * EnemyTraits.archetype_armor_boost(e))
	e.armor += shield_val
	# Guardian 防御时设置嘲讽
	if e.combat_type == GameTypes.EnemyCombatType.GUARDIAN:
		GameManager.taunt_enemy_uid = e.uid
		GameManager.target_enemy_uid = e.uid
		# P2 Trait: Guardian 防御后累计 guardRage
		EnemyTraits.apply_guard_rage_on_defend(e)
	var desc_tag: String = "·%s" % desc if desc != "" else ""
	BattleLog.log_enemy("🛡 %s 举盾防御%s（+%d 护甲）" % [_get_name(e), desc_tag, shield_val])
	SoundPlayer.play_sound("enemy_skill")
	if on_shake.is_valid():
		on_shake.call(3.0, 0.15)


## 执行技能行动（根据 description 派发具体效果）
## 对齐原版 enemyActionDispatch.ts 的 description 字典查表
static func _execute_skill(e: EnemyInstance, value: int, desc: String) -> void:
	# Priest/Caster 无 description 时走旧 archetype 分支
	if desc == "":
		match e.combat_type:
			GameTypes.EnemyCombatType.PRIEST:
				_resolve_priest(e)
			GameTypes.EnemyCombatType.CASTER:
				_resolve_caster(e)
			_:
				# 武力系"技能"视为攻击+rider（简化版：直接当攻击处理）
				SoundPlayer.play_sound("enemy")
				var damage: int = AttackCalc.get_effective_attack_dmg(e, PlayerState.statuses, e.attack_count, e.is_slowed())
				PlayerState.take_damage(damage)
				e.attack_count += 1
				BattleLog.log_enemy("⚔ %s 攻击 → %d 伤害" % [_get_name(e), damage])
		return

	# 有 description 时按字典派发
	var dot_type: String = _get_dot_from_desc(desc)
	var ctl_type: String = _get_control_from_desc(desc)

	if dot_type != "":
		# DOT 技能：灼烧/中毒
		SoundPlayer.play_sound("enemy_skill")
		var dot_val: int = maxi(1, value)
		# P2 Trait: Caster dotAmplifier 倍率加成
		var dot_mul: float = EnemyTraits.get_dot_multiplier(e)
		if dot_mul > 1.0:
			dot_val = maxi(1, int(float(dot_val) * dot_mul))
		if dot_type == "burn":
			GameManager.add_status(GameTypes.StatusType.BURN, dot_val, 3)
			BattleLog.log_status("🔥 %s 施放【%s】→ 灼烧 %d" % [_get_name(e), desc, dot_val])
		else:
			GameManager.add_status(GameTypes.StatusType.POISON, dot_val, 3)
			BattleLog.log_status("☠ %s 施放【%s】→ 中毒 %d" % [_get_name(e), desc, dot_val])
		# P2 Trait: Caster 施放 DOT 后累加 dotAmplifier
		EnemyTraits.bump_dot_amplifier(e)
	elif ctl_type != "":
		# 控制技能：虚弱/易伤/冻结
		SoundPlayer.play_sound("enemy_skill")
		match ctl_type:
			"weak":
				GameManager.add_status(GameTypes.StatusType.WEAK, 1, 2)
				BattleLog.log_status("✦ %s 施放【%s】→ 虚弱" % [_get_name(e), desc])
			"vulnerable":
				GameManager.add_status(GameTypes.StatusType.VULNERABLE, 1, 2)
				BattleLog.log_status("✦ %s 施放【%s】→ 易伤" % [_get_name(e), desc])
			"freeze":
				GameManager.add_status(GameTypes.StatusType.FREEZE, 1, 1)
				BattleLog.log_status("✦ %s 施放【%s】→ 冻结" % [_get_name(e), desc])
	elif _is_armor_bless_desc(desc):
		# 护甲祝福
		SoundPlayer.play_sound("enemy_skill")
		var all_living: Array[EnemyInstance] = _collect_all_living()
		if all_living.size() > 0:
			var target: EnemyInstance = all_living[randi() % all_living.size()]
			var armor_val: int = maxi(1, value)
			target.armor += armor_val
			BattleLog.log_enemy("✦ %s 施放【%s】→ %s +%d 护甲" % [_get_name(e), desc, _get_name(target), armor_val])
	else:
		# 未识别的 description → fallback 到 archetype 行为
		match e.combat_type:
			GameTypes.EnemyCombatType.PRIEST:
				_resolve_priest(e)
			GameTypes.EnemyCombatType.CASTER:
				_resolve_caster(e)
			_:
				SoundPlayer.play_sound("enemy")
				var damage: int = AttackCalc.get_effective_attack_dmg(e, PlayerState.statuses, e.attack_count, e.is_slowed())
				PlayerState.take_damage(damage)
				e.attack_count += 1
				BattleLog.log_enemy("⚔ %s【%s】→ %d 伤害" % [_get_name(e), desc, damage])


## 从 description 提取 DOT 类型（对齐原版 getDotFromDescription）
static func _get_dot_from_desc(desc: String) -> String:
	var lower: String = desc.to_lower()
	if lower.contains("灼烧") or lower.contains("火") or lower.contains("burn") or lower.contains("fire"):
		return "burn"
	if lower.contains("中毒") or lower.contains("毒") or lower.contains("poison"):
		return "poison"
	return ""


## 从 description 提取控制类型（对齐原版 getControlFromDescription）
static func _get_control_from_desc(desc: String) -> String:
	var lower: String = desc.to_lower()
	if lower.contains("冻结") or lower.contains("freeze") or lower.contains("冰"):
		return "freeze"
	if lower.contains("虚弱") or lower.contains("weak"):
		return "weak"
	if lower.contains("易伤") or lower.contains("vulnerable") or lower.contains("脆弱"):
		return "vulnerable"
	return ""


## 判断是否为护甲祝福类 description
static func _is_armor_bless_desc(desc: String) -> bool:
	var lower: String = desc.to_lower()
	return lower.contains("护甲") or lower.contains("祝福") or lower.contains("shield") or lower.contains("armor")


## Priest：§9.2 完整优先级（对齐原版 enemySkills.ts executePriestSkill）
##   P1. 疗盟 — 存在受伤盟友，血量最低者优先
##   P2. 自疗 — 本尊 HP < maxHp
##   P3. 护甲祝福 — 给随机友军加护甲（无受伤目标时）
##   P4. 减益兜底 — weak / vulnerable / 塞诅咒骰
static func _resolve_priest(e: EnemyInstance) -> void:
	# P1: 疗盟（优先级最高，对齐原版）
	var wounded: Array[EnemyInstance] = _find_wounded_allies(e)
	if wounded.size() > 0:
		var target: EnemyInstance = wounded[0]
		var heal_amount: int = int(e.attack_dmg * 4.0)
		target.hp = mini(target.max_hp, target.hp + heal_amount)
		SoundPlayer.play_sound("heal")
		BattleLog.log_enemy("✚ %s 治疗 %s（+%d HP）" % [_get_name(e), _get_name(target), heal_amount])
		return

	# P2: 自疗（自己受伤时）
	if e.max_hp > 0 and e.hp < e.max_hp:
		var self_heal: int = int(e.attack_dmg * 3.0)
		e.hp = mini(e.max_hp, e.hp + self_heal)
		SoundPlayer.play_sound("heal")
		BattleLog.log_enemy("✚ %s 自疗（+%d HP）" % [_get_name(e), self_heal])
		return

	# P3: 护甲祝福（给随机友军加护甲，无受伤目标时）
	var all_living: Array[EnemyInstance] = _collect_all_living()
	var allies: Array[EnemyInstance] = []
	for a: EnemyInstance in all_living:
		if a.uid != e.uid:
			allies.append(a)
	if allies.size() > 0:
		var target: EnemyInstance = allies[randi() % allies.size()]
		var armor_val: int = int(e.attack_dmg * 1.5)
		target.armor += armor_val
		SoundPlayer.play_sound("enemy_skill")
		BattleLog.log_enemy("✦ %s 为 %s 施加护甲祝福（+%d 护甲）" % [_get_name(e), _get_name(target), armor_val])
		return

	# P4: 减益兜底（对齐原版：50% weak / 30% vulnerable / 20% 塞诅咒骰）
	var debuff_roll: float = randf()
	if debuff_roll < 0.5:
		GameManager.add_status(GameTypes.StatusType.WEAK, 1, 2)
		BattleLog.log_status("✦ %s 施加虚弱" % _get_name(e))
	elif debuff_roll < 0.8:
		GameManager.add_status(GameTypes.StatusType.VULNERABLE, 1, 2)
		BattleLog.log_status("✦ %s 施加易伤" % _get_name(e))
	else:
		# 塞诅咒骰（原版 Priest debuff 兜底分支）
		DiceBag.owned_dice.append({"defId": "cursed", "level": 1})
		DiceBag.dice_bag.append("cursed")
		VFX.show_toast("%s 诅咒: 诅咒骰 +1" % _get_name(e), "damage")
		BattleLog.log_status("✦ %s 施加诅咒骰" % _get_name(e))
		SoundPlayer.play_sound("enemy_skill")


## Caster：§9.2 三分支（对齐原版 enemySkills.ts executeCasterSkill）
## default archetype: poisonChance(40%) 中毒 / fireballThreshold(30%) 灼烧 / 余下(30%) 诅咒（毒素+虚弱双debuff）
## 注：诅咒分支是施加"毒素+虚弱"双debuff，不是塞诅咒骰子（塞骰子是 Priest 的行为）
static func _resolve_caster(e: EnemyInstance) -> void:
	SoundPlayer.play_sound("enemy")
	# P2 Trait: Caster dotAmplifier 倍率
	var dot_mul: float = EnemyTraits.get_dot_multiplier(e)
	var roll: float = randf()
	if roll < 0.4:
		# 毒雾：施加中毒
		var poison_val: int = maxi(2, int(float(e.attack_dmg) * 0.4 * dot_mul))
		GameManager.add_status(GameTypes.StatusType.POISON, poison_val, 3)
		BattleLog.log_status("☠ %s 施加中毒 %d" % [_get_name(e), poison_val])
	elif roll < 0.7:
		# 火球：施加灼烧
		var burn_val: int = maxi(1, int(float(e.attack_dmg) * 0.3 * dot_mul))
		GameManager.add_status(GameTypes.StatusType.BURN, burn_val, 3)
		BattleLog.log_status("🔥 %s 施加灼烧 %d" % [_get_name(e), burn_val])
	else:
		# 诅咒：毒素 + 虚弱双 debuff（对齐原版 cursemaster 分支）
		var curse_poison: int = maxi(1, int(float(e.attack_dmg) * 0.25 * dot_mul))
		GameManager.add_status(GameTypes.StatusType.POISON, curse_poison, 3)
		GameManager.add_status(GameTypes.StatusType.WEAK, 1, 2)
		BattleLog.log_status("✦ %s 施放诅咒（毒素 %d + 虚弱）" % [_get_name(e), curse_poison])
	# P2 Trait: 施放 DOT 后累加 dotAmplifier
	EnemyTraits.bump_dot_amplifier(e)


## Warrior/Ranger/默认：走 AttackCalc 计算伤害，Ranger 额外追击
static func _resolve_attacker(
	e: EnemyInstance,
	on_shake: Callable,
	on_hp_pulse: Callable
) -> void:
	SoundPlayer.play_sound("enemy")
	var damage: int = AttackCalc.get_effective_attack_dmg(
		e, PlayerState.statuses, e.attack_count, e.is_slowed()
	)
	# P2 Trait: trait 攻击力修正（guardRage/archetype）
	var trait_mul: float = EnemyTraits.attack_trait_multiplier(e)
	if trait_mul > 1.0:
		damage = int(float(damage) * trait_mul)
	PlayerState.take_damage(damage)
	e.attack_count += 1
	BattleLog.log_enemy("⚔ %s 攻击 → %d 伤害" % [_get_name(e), damage])
	if on_shake.is_valid():
		on_shake.call(5.0, 0.2)
	if on_hp_pulse.is_valid():
		on_hp_pulse.call()
	# Ranger 追击（玩家未死才打）
	if e.combat_type == GameTypes.EnemyCombatType.RANGER and PlayerState.hp > 0:
		var follow_up: int = AttackCalc.get_ranger_follow_up_dmg(e, e.attack_count)
		PlayerState.take_damage(follow_up)
		BattleLog.log_enemy("⚔ %s 追击 → %d 伤害" % [_get_name(e), follow_up])
		if on_shake.is_valid():
			on_shake.call(3.0, 0.15)
	# P2 Trait: Guardian 攻击后清空 guardRage
	if e.combat_type == GameTypes.EnemyCombatType.GUARDIAN:
		EnemyTraits.consume_guard_rage_on_attack(e)


## 从 EnemyInstance 拿显示名（EnemyConfig 查表，失败用 config_id 兜底）
static func _get_name(e: EnemyInstance) -> String:
	var cfg: EnemyConfig = EnemyConfig.get_config(e.config_id)
	if cfg and cfg.name != "":
		return cfg.name
	return e.config_id


## Priest 辅助：找出血量最低且未满血的非自身盟友
static func _find_wounded_allies(self_enemy: EnemyInstance) -> Array[EnemyInstance]:
	var instances: Array[EnemyInstance] = _collect_all_living()
	var wounded: Array[EnemyInstance] = []
	for a: EnemyInstance in instances:
		if a.hp > 0 and a.uid != self_enemy.uid and a.hp < a.max_hp:
			wounded.append(a)
	wounded.sort_custom(
		func(a: EnemyInstance, b: EnemyInstance) -> bool: return a.hp < b.hp
	)
	return wounded


## 从 GameManager 拿当前战场所有活敌（Priest 治疗友军用）
## 注：通过 EnemyView 反查比通过全局状态更准确，但在 Resolver 里无法直接拿到 enemy_views 引用
## 因此由 BattleController 在调用前 push 一份 snapshot 到 GameManager.current_enemies（已约定）
static func _collect_all_living() -> Array[EnemyInstance]:
	var result: Array[EnemyInstance] = []
	for e in GameManager.current_enemies:
		if e is EnemyInstance and e.hp > 0:
			result.append(e)
	return result
