## ConfigLoader — Excel 驱动的配置加载器
## 职责：从 config/json/*.json 加载数据，组装成运行时需要的 DiceDef / RelicDef / EnemyConfig / ClassDef / GameBalance 对象
##
## 策略：尽量不破坏现有 API。调用方（game_data.gd / class_def.gd / enemy_config.gd）仍然返回原类型，
##       只是数据来源从硬编码函数改为读 JSON 组装。
##
## 使用：
##   ConfigLoader.get_balance("player.hp")          → int
##   ConfigLoader.load_dice_defs()                  → Dictionary[id -> DiceDef]
##   ConfigLoader.load_relic_defs()                 → Dictionary[id -> RelicDef]
##   ConfigLoader.load_class_defs()                 → Dictionary[id -> ClassDef]
##   ConfigLoader.load_enemy_configs()              → Dictionary[id -> EnemyConfig]

class_name ConfigLoader

const JSON_DIR: String = "res://config/json/"

# ============================================================
# 运行时缓存（进程级）
# ============================================================

static var _balance_cache: Dictionary = {}
static var _balance_loaded: bool = false

# ============================================================
# 通用 JSON 加载
# ============================================================

static func _load_json(file_name: String) -> Variant:
	var path := JSON_DIR + file_name
	if not FileAccess.file_exists(path):
		push_error("[ConfigLoader] JSON not found: " + path)
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("[ConfigLoader] Failed to open: " + path)
		return null
	var text := f.get_as_text()
	f.close()
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_error("[ConfigLoader] JSON parse error in %s: %s" % [path, json.get_error_message()])
		return null
	return json.data

# ============================================================
# Balance（游戏常量）
# ============================================================

## 取一个常量。找不到返回 default
static func get_balance(key: String, default: Variant = null) -> Variant:
	if not _balance_loaded:
		_load_balance()
	return _balance_cache.get(key, default)

## 取一组前缀（例如 "player." 返回所有 player.xx 键的字典，去掉前缀）
static func get_balance_group(prefix: String) -> Dictionary:
	if not _balance_loaded:
		_load_balance()
	var out: Dictionary = {}
	for k in _balance_cache:
		if k.begins_with(prefix):
			out[k.substr(prefix.length())] = _balance_cache[k]
	return out

static func _load_balance() -> void:
	var data: Variant = _load_json("balance.json")
	if data is Dictionary:
		_balance_cache = data
	_balance_loaded = true

# ============================================================
# Enums（枚举映射）
# ============================================================

## 取稀有度枚举：RA1 → GameTypes.DiceRarity.COMMON
static func rarity_from_code(code: String, for_relic: bool = false) -> int:
	match code:
		"RA1": return GameTypes.RelicRarity.COMMON if for_relic else GameTypes.DiceRarity.COMMON
		"RA2": return GameTypes.RelicRarity.UNCOMMON if for_relic else GameTypes.DiceRarity.UNCOMMON
		"RA3": return GameTypes.RelicRarity.RARE if for_relic else GameTypes.DiceRarity.RARE
		"RA4": return GameTypes.RelicRarity.LEGENDARY if for_relic else GameTypes.DiceRarity.LEGENDARY
		"RA5": return GameTypes.DiceRarity.CURSE  # 遗物无此级
	return GameTypes.DiceRarity.COMMON

static func element_from_code(code: String) -> int:
	match code:
		"EL0": return GameTypes.DiceElement.NORMAL
		"EL1": return GameTypes.DiceElement.FIRE
		"EL2": return GameTypes.DiceElement.WIND
		"EL3": return GameTypes.DiceElement.THUNDER
		"EL4": return GameTypes.DiceElement.POISON
		"EL5": return GameTypes.DiceElement.HOLY
		"EL6": return GameTypes.DiceElement.SHADOW
	return GameTypes.DiceElement.NORMAL

static func status_from_code(code: String) -> int:
	match code:
		"ST01": return GameTypes.StatusType.POISON
		"ST02": return GameTypes.StatusType.BURN
		"ST03": return GameTypes.StatusType.DODGE
		"ST04": return GameTypes.StatusType.VULNERABLE
		"ST05": return GameTypes.StatusType.STRENGTH
		"ST06": return GameTypes.StatusType.WEAK
		"ST07": return GameTypes.StatusType.ARMOR
		"ST09": return GameTypes.StatusType.FREEZE
	return GameTypes.StatusType.POISON

static func trigger_from_code(code: String) -> int:
	match code:
		"TR01": return GameTypes.RelicTrigger.ON_PLAY
		"TR02": return GameTypes.RelicTrigger.ON_KILL
		"TR03": return GameTypes.RelicTrigger.ON_REROLL
		"TR04": return GameTypes.RelicTrigger.ON_TURN_START
		"TR05": return GameTypes.RelicTrigger.ON_TURN_END
		"TR06": return GameTypes.RelicTrigger.ON_BATTLE_START
		"TR07": return GameTypes.RelicTrigger.ON_BATTLE_END
		"TR08": return GameTypes.RelicTrigger.ON_DAMAGE_TAKEN
		"TR09": return GameTypes.RelicTrigger.ON_FATAL
		"TR10": return GameTypes.RelicTrigger.ON_FLOOR_CLEAR
		"TR11": return GameTypes.RelicTrigger.ON_MOVE
		"TR99": return GameTypes.RelicTrigger.PASSIVE
	return GameTypes.RelicTrigger.PASSIVE

static func combat_type_from_string(s: String) -> int:
	match s:
		"WARRIOR": return GameTypes.EnemyCombatType.WARRIOR
		"GUARDIAN": return GameTypes.EnemyCombatType.GUARDIAN
		"RANGER": return GameTypes.EnemyCombatType.RANGER
		"CASTER": return GameTypes.EnemyCombatType.CASTER
		"PRIEST": return GameTypes.EnemyCombatType.PRIEST
	return GameTypes.EnemyCombatType.WARRIOR

## 解析 "ST02x2x3" → [类型枚举, 数值, 持续]
static func parse_status_ref(ref: String) -> Array:
	if ref == null or ref == "":
		return [-1, 0, 0]
	var parts := ref.split("x")
	if parts.size() < 3:
		return [-1, 0, 0]
	var st := status_from_code(parts[0])
	var v := int(parts[1])
	var d := int(parts[2])
	return [st, v, d]

# ============================================================
# Dice（骰子）
# ============================================================

## 返回 Dictionary[String(legacy_key) -> DiceDef]
## 为保持与老接口兼容，这里 key 用 legacy_key（"standard" 等）
## 同时 DiceDef.id 也写为 legacy_key（game_data.gd 旧行为如此）
static func load_dice_defs() -> Dictionary:
	var data: Variant = _load_json("dice.json")
	if not (data is Dictionary) or not data.has("base"):
		push_error("[ConfigLoader] dice.json malformed")
		return {}

	# 先构建 effect_group → list of effects
	var eg_map: Dictionary = {}
	if data.has("effects"):
		for eff in data["effects"]:
			var eg: String = eff.get("effect_group", "")
			if eg == "":
				continue
			if not eg_map.has(eg):
				eg_map[eg] = []
			eg_map[eg].append(eff)

	var defs: Dictionary = {}
	for row in data["base"]:
		var d := DiceDef.new()
		d.id = row.get("legacy_key", "")  # 兼容老代码：id 用 legacy_key
		if d.id == "":
			d.id = row.get("id", "")
		d.name = row.get("name", "")
		d.faces = _as_int_array(row.get("faces", []))
		d.description = row.get("description", "")
		d.rarity = rarity_from_code(row.get("rarity", "RA1"))
		d.element = element_from_code(row.get("element", "EL0"))
		d.is_cursed = _as_bool(row.get("flag_cursed", false))
		d.is_cracked = _as_bool(row.get("flag_cracked", false))
		d.is_rune = _as_bool(row.get("flag_rune", false))

		# 构建 effects 数组（从 effect_group 映射）
		var eg: String = row.get("effect_group", "")
		if eg != "" and eg_map.has(eg):
			d.effects = _build_dice_effects(eg_map[eg])
			# 从 effect_group 提取标记属性设置到 DiceDef
			for eff in eg_map[eg]:
				var pk: String = eff.get("param_key", "")
				match pk:
					"is_elemental":
						d.is_elemental = _as_bool(eff.get("param_value", false))
					"copy_majority_element":
						d.copy_majority_element = _as_bool(eff.get("param_value", false))
					"dual_element":
						d.dual_element = _as_bool(eff.get("param_value", false))
					"is_rune":
						d.is_rune = _as_bool(eff.get("param_value", false))

		defs[d.id] = d
	return defs


## 将旧格式的 param_key/param_value/effect_type 转换为新的 effects 数组
static func _build_dice_effects(raw_effects: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var trigger := EffectTypes.TriggerType.ON_PLAY

	for eff in raw_effects:
		var key: String = eff.get("param_key", "")
		var value: Variant = eff.get("param_value", null)
		var ref: String = eff.get("param_ref", "")
		var et: String = eff.get("effect_type", "")

		# 状态效果（ET07=对敌施加, ET08=对己施加）
		if et == "ET07":
			var parsed := parse_status_ref(ref)
			if parsed[0] != -1:
				result.append(EffectTypes.create_effect(EffectTypes.EffectType.APPLY_STATUS,
					{"status": parsed[0], "value": parsed[1], "target": "enemy"}, trigger))
			continue
		if et == "ET08":
			var parsed2 := parse_status_ref(ref)
			if parsed2[0] != -1:
				result.append(EffectTypes.create_effect(EffectTypes.EffectType.APPLY_STATUS,
					{"status": parsed2[0], "value": parsed2[1], "target": "self"}, trigger))
			continue

		if key == "" or value == null:
			continue

		# 按 param_key 映射到 EffectType
		var effect: Dictionary = _dice_param_to_effect(key, value, trigger)
		if not effect.is_empty():
			result.append(effect)
	return result


## 骰子 param_key → EffectType 映射
static func _dice_param_to_effect(key: String, value: Variant, trigger: EffectTypes.TriggerType) -> Dictionary:
	match key:
		"bonus_damage":
			return EffectTypes.create_effect(EffectTypes.EffectType.BONUS_DAMAGE,
				{"value": int(value)}, trigger)
		"bonus_mult":
			return EffectTypes.create_effect(EffectTypes.EffectType.BONUS_MULT,
				{"value": float(value)}, trigger)
		"self_damage":
			return EffectTypes.create_effect(EffectTypes.EffectType.SELF_DAMAGE,
				{"value": int(value)}, trigger)
		"self_damage_percent":
			return EffectTypes.create_effect(EffectTypes.EffectType.SELF_DAMAGE,
				{"percent": float(value)}, trigger)
		"heal":
			return EffectTypes.create_effect(EffectTypes.EffectType.HEAL,
				{"value": int(value)}, trigger)
		"armor":
			return EffectTypes.create_effect(EffectTypes.EffectType.ARMOR,
				{"value": int(value)}, trigger)
		"pierce":
			return EffectTypes.create_effect(EffectTypes.EffectType.PIERCE,
				{"value": int(value)}, trigger)
		"aoe":
			if _as_bool(value):
				return EffectTypes.create_effect(EffectTypes.EffectType.AOE, {}, trigger)
		"bounce":
			if _as_bool(value):
				return EffectTypes.create_effect(EffectTypes.EffectType.BOUNCE, {}, trigger)
		"extra_play":
			return EffectTypes.create_effect(EffectTypes.EffectType.GRANT_PLAY,
				{"count": int(value)}, trigger)
		"extra_reroll":
			return EffectTypes.create_effect(EffectTypes.EffectType.GRANT_REROLL,
				{"count": int(value)}, trigger)
		"gold_bonus":
			return EffectTypes.create_effect(EffectTypes.EffectType.GAIN_GOLD,
				{"value": int(value)}, trigger)
		"execute_threshold":
			return EffectTypes.create_effect(EffectTypes.EffectType.EXECUTE,
				{"threshold": float(value), "mult": 999.0}, trigger)
		"bonus_mult_on_keep":
			return EffectTypes.create_effect(EffectTypes.EffectType.BONUS_MULT_ON_KEEP,
				{"value": float(value)}, EffectTypes.TriggerType.ON_KEEP)
		"bonus_on_keep":
			return EffectTypes.create_effect(EffectTypes.EffectType.BONUS_ON_KEEP,
				{"value": int(value), "cap": 99}, EffectTypes.TriggerType.ON_KEEP)
		"true_damage":
			return EffectTypes.create_effect(EffectTypes.EffectType.TRUE_DAMAGE,
				{"value": int(value)}, trigger)
		"armor_break":
			if _as_bool(value):
				return EffectTypes.create_effect(EffectTypes.EffectType.ARMOR_BREAK, {}, trigger)
		"overkill_transfer":
			return EffectTypes.create_effect(EffectTypes.EffectType.OVERKILL_TRANSFER,
				{"ratio": float(value)}, trigger)
		"splash":
			return EffectTypes.create_effect(EffectTypes.EffectType.SPLASH,
				{"ratio": float(value)}, trigger)
		"reverse_value":
			if _as_bool(value):
				return EffectTypes.create_effect(EffectTypes.EffectType.REVERSE_VALUE, {}, trigger)
		"armor_from_value":
			if _as_bool(value):
				return EffectTypes.create_effect(EffectTypes.EffectType.ARMOR,
					{"value": 0, "source": "points", "ratio": 1.0}, trigger)
		"execute_mult":
			return EffectTypes.create_effect(EffectTypes.EffectType.EXECUTE,
				{"threshold": 0.3, "mult": float(value)}, trigger)
		"self_berserk":
			if _as_bool(value):
				return EffectTypes.create_effect(EffectTypes.EffectType.BERSERK,
					{"turns": 2, "damage_mult": 0.5, "taken_mult": 0.3, "gamble_cost": 0.0}, trigger)
		"fury_stack":
			if _as_bool(value):
				return EffectTypes.create_effect(EffectTypes.EffectType.ESCALATE,
					{"per_trigger": 0.1, "cap": 1.0}, trigger)
		"combo_bonus":
			return EffectTypes.create_effect(EffectTypes.EffectType.BONUS_MULT,
				{"value": float(value), "condition": "combo"}, EffectTypes.TriggerType.ON_COMBO)
		"grant_shadow_die":
			return EffectTypes.create_effect(EffectTypes.EffectType.GRANT_TEMP_DIE,
				{"die_type": "shadow", "count": int(value)}, trigger)
		"poison_base":
			return EffectTypes.create_effect(EffectTypes.EffectType.APPLY_STATUS,
				{"status": "poison", "value": int(value), "target": "enemy"}, trigger)
		"shadow_clone_play":
			if _as_bool(value):
				return EffectTypes.create_effect(EffectTypes.EffectType.GRANT_PLAY,
					{"count": 1, "condition": "combo"}, EffectTypes.TriggerType.ON_COMBO)
		"bonus_per_turn_kept":
			return EffectTypes.create_effect(EffectTypes.EffectType.BONUS_ON_KEEP,
				{"value": int(value), "cap": 99}, EffectTypes.TriggerType.ON_KEEP)
		"keep_bonus_cap":
			# 仅作为 bonus_on_keep 的 cap 参数，单独出现时忽略（由 bonus_per_turn_kept 一起处理）
			return {}
		"split_dice", "magnet_dice", "joker_dice", "chaos_dice":
			# 特殊骰子标记，由骰子 id 本身驱动逻辑，不需要转为 effect
			return {}
		"scale_with_blood_rerolls":
			# 血重投缩放：伤害随重投次数增长，由 DiceSpecialEffects 运行时处理
			return {}
		"is_elemental":
			# 元素标记：由骰子 element 字段驱动，不需要额外 effect
			return {}
		"reduce_disruption":
			return EffectTypes.create_effect(EffectTypes.EffectType.REDUCE_ARCANE_DISRUPTION,
				{"value": int(value)}, EffectTypes.TriggerType.ON_HOLD)
		"consume_disruption_aoe":
			return EffectTypes.create_effect(EffectTypes.EffectType.CONSUME_DISRUPTION_AOE,
				{"damage_per_stack": int(value)}, trigger)
		"charge_bonus":
			return EffectTypes.create_effect(EffectTypes.EffectType.BONUS_DAMAGE,
				{"value": int(value), "condition": "charge"}, trigger)
		# ---- 战士新骰子 param_key 映射 (v0.5) ----
		"bonus_damage_scaled":
			# 按某数值×ratio追加基础伤害 {source, ratio, cap?}
			var params_bds: Dictionary = {"source": str(value), "ratio": 1.0}
			return EffectTypes.create_effect(EffectTypes.EffectType.BONUS_DAMAGE_SCALED, params_bds, trigger)
		"bonus_damage_scaled_ratio":
			# 配合 bonus_damage_scaled 使用，单独出现时忽略
			return {}
		"bonus_damage_scaled_cap":
			# 配合 bonus_damage_scaled 使用，单独出现时忽略
			return {}
		"blood_chain":
			if _as_bool(value):
				return EffectTypes.create_effect(EffectTypes.EffectType.BLOOD_CHAIN,
					{"target": "main"}, trigger)
		"solo_seal":
			return EffectTypes.create_effect(EffectTypes.EffectType.SOLO_SEAL,
				{"damage_mult": float(value)}, trigger)
		"scar_consume":
			# 消耗伤痕层数 {ratio, bonus_per_stack}
			return EffectTypes.create_effect(EffectTypes.EffectType.SCAR_CONSUME,
				{"ratio": float(value), "bonus_per_stack": 0.0}, trigger)
		"scar_bonus":
			# 伤痕加成（不消耗）{per_stack}
			return EffectTypes.create_effect(EffectTypes.EffectType.SCAR_BONUS,
				{"per_stack": float(value)}, trigger)
		"control_taunt":
			# 施加嘲讽 {control, duration, target}
			return EffectTypes.create_effect(EffectTypes.EffectType.CONTROL,
				{"control": "taunt", "duration": int(value), "target": "all"}, trigger)
		"control_taunt_single":
			return EffectTypes.create_effect(EffectTypes.EffectType.CONTROL,
				{"control": "taunt", "duration": int(value), "target": "main"}, trigger)
		"control_stun":
			# 施加眩晕 {control, duration, target}
			return EffectTypes.create_effect(EffectTypes.EffectType.CONTROL,
				{"control": "stun", "duration": int(value), "target": "main"}, trigger)
		"control_stun_aoe":
			return EffectTypes.create_effect(EffectTypes.EffectType.CONTROL,
				{"control": "stun", "duration": int(value), "target": "all"}, trigger)
		"purify_all":
			if _as_bool(value):
				return EffectTypes.create_effect(EffectTypes.EffectType.PURIFY,
					{"scope": "all"}, trigger)
		"heal_percent":
			return EffectTypes.create_effect(EffectTypes.EffectType.HEAL,
				{"value": 0, "source": "percent", "ratio": float(value)}, trigger)
		"heal_on_kill":
			return EffectTypes.create_effect(EffectTypes.EffectType.HEAL_ON_TRIGGER,
				{"trigger": "kill", "percent": float(value)}, trigger)
		"draw_on_kill":
			return EffectTypes.create_effect(EffectTypes.EffectType.DRAW,
				{"count": int(value)}, EffectTypes.TriggerType.ON_KILL)
		"armor_from_points_mult":
			return EffectTypes.create_effect(EffectTypes.EffectType.ARMOR,
				{"value": 0, "source": "points", "ratio": float(value)}, trigger)
		"apply_vulnerable":
			return EffectTypes.create_effect(EffectTypes.EffectType.APPLY_STATUS,
				{"status": "vulnerable", "value": int(value), "target": "enemy"}, trigger)
		"berserk":
			return EffectTypes.create_effect(EffectTypes.EffectType.BERSERK,
				{"turns": int(value), "damage_mult": 0.3, "taken_mult": 0.2, "gamble_cost": 0.5}, trigger)
		"modify_points":
			return EffectTypes.create_effect(EffectTypes.EffectType.MODIFY_POINTS,
				{"delta": int(value)}, trigger)
		"escalate":
			return EffectTypes.create_effect(EffectTypes.EffectType.ESCALATE,
				{"per_trigger": float(value), "cap": 999.0}, trigger)
		"bonus_mult_condition":
			# 条件倍率 {value, condition} - value 从 param_value 读，condition 从 param_ref 读
			return EffectTypes.create_effect(EffectTypes.EffectType.BONUS_MULT,
				{"value": float(value)}, trigger)
		"is_rune":
			# 符文骰标记，由 flag_rune 字段驱动
			return {}
		_:
			push_warning("[ConfigLoader] 未映射的骰子参数: %s = %s" % [key, str(value)])
	return {}

# ============================================================
# Relic（遗物）
# ============================================================

static func load_relic_defs() -> Dictionary:
	var data: Variant = _load_json("relic.json")
	if not (data is Dictionary) or not data.has("base"):
		push_error("[ConfigLoader] relic.json malformed")
		return {}

	var eg_map: Dictionary = {}
	if data.has("effects"):
		for eff in data["effects"]:
			var eg: String = eff.get("effect_group", "")
			if eg == "":
				continue
			if not eg_map.has(eg):
				eg_map[eg] = []
			eg_map[eg].append(eff)

	var defs: Dictionary = {}
	for row in data["base"]:
		var r := RelicDef.new()
		r.id = row.get("legacy_key", "")
		if r.id == "":
			r.id = row.get("id", "")
		r.name = row.get("name", "")
		r.description = row.get("description", "")
		r.rarity = rarity_from_code(row.get("rarity", "RA1"), true)
		r.trigger = trigger_from_code(row.get("trigger", "TR99"))

		# 计数/冷却字段
		r.counter = int(row.get("counter", 0))
		r.max_counter = int(row.get("max_counter", 0))
		r.counter_label = row.get("counter_label", "")
		r.cooldown = int(row.get("cooldown", 0))
		r.consumable = _as_bool(row.get("consumable", false))

		# 构建 effects 数组（从 effect_group 映射）
		var eg: String = row.get("effect_group", "")
		if eg != "" and eg_map.has(eg):
			r.effects = _build_relic_effects(eg_map[eg], r.trigger)

		defs[r.id] = r
	return defs


## 将旧格式的 param_key/param_value 转换为新的 effects 数组
static func _build_relic_effects(raw_effects: Array, relic_trigger: GameTypes.RelicTrigger) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var trigger_type: EffectTypes.TriggerType = _relic_trigger_to_effect_trigger(relic_trigger)

	for eff in raw_effects:
		var key: String = eff.get("param_key", "")
		var value: Variant = eff.get("param_value", null)
		if key == "" or value == null:
			continue
		var effect: Dictionary = _param_to_effect(key, value, trigger_type)
		if not effect.is_empty():
			result.append(effect)
	return result


## 将 param_key + param_value 映射为 EffectTypes 格式的效果字典
static func _param_to_effect(key: String, value: Variant, trigger_type: EffectTypes.TriggerType) -> Dictionary:
	match key:
		"damage":
			return EffectTypes.create_effect(EffectTypes.EffectType.BONUS_DAMAGE,
				{"value": int(value)}, trigger_type)
		"armor":
			return EffectTypes.create_effect(EffectTypes.EffectType.ARMOR,
				{"value": int(value)}, trigger_type)
		"heal":
			return EffectTypes.create_effect(EffectTypes.EffectType.HEAL,
				{"value": int(value)}, trigger_type)
		"multiplier":
			return EffectTypes.create_effect(EffectTypes.EffectType.BONUS_MULT,
				{"value": float(value)}, trigger_type)
		"pierce":
			return EffectTypes.create_effect(EffectTypes.EffectType.PIERCE,
				{"value": int(value)}, trigger_type)
		"gold_bonus":
			return EffectTypes.create_effect(EffectTypes.EffectType.GAIN_GOLD,
				{"value": int(value)}, trigger_type)
		"draw_count_bonus":
			return EffectTypes.create_effect(EffectTypes.EffectType.DRAW,
				{"count": int(value)}, trigger_type)
		"shop_discount":
			return EffectTypes.create_effect(EffectTypes.EffectType.SHOP_DISCOUNT,
				{"percent": float(value) / 100.0}, trigger_type)
		"free_rerolls", "extra_reroll":
			return EffectTypes.create_effect(EffectTypes.EffectType.GRANT_REROLL,
				{"count": int(value)}, trigger_type)
		"extra_play":
			return EffectTypes.create_effect(EffectTypes.EffectType.GRANT_PLAY,
				{"count": int(value)}, trigger_type)
		"extra_draw":
			return EffectTypes.create_effect(EffectTypes.EffectType.DRAW,
				{"count": int(value)}, trigger_type)
		"prevent_death":
			if _as_bool(value):
				# cooldown_turns 从配置读取，若无则默认一次性（99=实质无冷却）
				return EffectTypes.create_effect(EffectTypes.EffectType.DEATH_IMMUNITY,
					{"cooldown_turns": int(value) if value is int or value is float else 99}, trigger_type)
		"temp_draw_bonus":
			return EffectTypes.create_effect(EffectTypes.EffectType.DRAW,
				{"count": int(value)}, EffectTypes.TriggerType.ON_TURN_END)
		"grant_extra_play":
			return EffectTypes.create_effect(EffectTypes.EffectType.GRANT_PLAY,
				{"count": int(value)}, EffectTypes.TriggerType.ON_TURN_END)
		"bonus_mult_on_keep":
			return EffectTypes.create_effect(EffectTypes.EffectType.BONUS_MULT_ON_KEEP,
				{"value": float(value)}, EffectTypes.TriggerType.ON_KEEP)
		"execute_threshold":
			return EffectTypes.create_effect(EffectTypes.EffectType.EXECUTE,
				{"threshold": float(value), "mult": 999.0}, trigger_type)
		"true_damage":
			return EffectTypes.create_effect(EffectTypes.EffectType.TRUE_DAMAGE,
				{"value": int(value)}, trigger_type)
		"armor_break":
			if _as_bool(value):
				return EffectTypes.create_effect(EffectTypes.EffectType.ARMOR_BREAK, {}, trigger_type)
		"keep_unplayed_once":
			if _as_bool(value):
				return EffectTypes.create_effect(EffectTypes.EffectType.PRESERVE_DIE,
					{}, EffectTypes.TriggerType.ON_TURN_END)
		"keep_highest_die":
			if _as_bool(value):
				return EffectTypes.create_effect(EffectTypes.EffectType.PRESERVE_DIE,
					{"condition": "highest"}, EffectTypes.TriggerType.ON_TURN_END)
		"max_points_unlocked":
			if _as_bool(value):
				return EffectTypes.create_effect(EffectTypes.EffectType.ALL_DICE_POINTS_PLUS,
					{"value": 1}, EffectTypes.TriggerType.PASSIVE)
		"pair_as_triplet":
			if _as_bool(value):
				return EffectTypes.create_effect(EffectTypes.EffectType.HAND_TYPE_TOLERANCE,
					{"type": "same", "tolerance": 1}, EffectTypes.TriggerType.PASSIVE)
		"straight_upgrade":
			if _as_bool(value):
				return EffectTypes.create_effect(EffectTypes.EffectType.HAND_TYPE_TOLERANCE,
					{"type": "straight", "tolerance": 1}, EffectTypes.TriggerType.PASSIVE)
		"max_counter":
			# 计数器上限：由遗物运行时逻辑管理，不转为 effect
			return {}
		# ---- 以下为运行时逻辑标记型参数，由 RelicEngine 运行时检查 ----
		"draw_bonus", "draw_penalty", "return_to_top", "free_reroll", \
		"mirror_draw", "shotgun_aoe", "all_in_play", "echo_play", \
		"straight_tolerance", "pair_tolerance", "straight_full_aoe", \
		"fullhouse_return", "sync_bonus", "lucky_reroll", "stable_reroll", \
		"auto_reroll", "fixed_points", "straight_to_gold", "chest_bonus", \
		"shop_extra_dice", "heal_on_kill", "low_hp_extra_play", \
		"rhythm_reroll", "lean_draw", "forge_destroy", "duplicate_die", \
		"discard_to_bottom", "chance_draw", "time_rewind", "peek_top", \
		"bounty_reward", "mirror_enemy", "blood_reroll_discount", \
		"scar_decay_slow", "chain_duration", "undying_reroll", \
		"scatter_crit", "kill_draw", "berserk_extra_play", "armor_snowball", \
		"chant_cap_bonus", "chant_cap_speed", "element_balance", \
		"disruption_cap", "chant_return", "barrier_to_damage", \
		"meteor_discount", "element_lock_extend", "element_double", \
		"first_round_play", "detonate_bonus", "shadow_carry", \
		"shadow_preserve", "venom_spread", "dodge_first", "poison_base":
			# 这些参数由 RelicEngine 运行时逻辑直接读取 relic_data，不转为 effect
			return {}
		_:
			push_warning("[ConfigLoader] 未映射的遗物参数: %s = %s" % [key, str(value)])
	return {}


## RelicTrigger → EffectTypes.TriggerType 映射
static func _relic_trigger_to_effect_trigger(rt: GameTypes.RelicTrigger) -> EffectTypes.TriggerType:
	match rt:
		GameTypes.RelicTrigger.ON_BATTLE_START:
			return EffectTypes.TriggerType.ON_BATTLE_START
		GameTypes.RelicTrigger.ON_PLAY:
			return EffectTypes.TriggerType.ON_PLAY
		GameTypes.RelicTrigger.ON_KILL:
			return EffectTypes.TriggerType.ON_KILL
		GameTypes.RelicTrigger.ON_DAMAGE_TAKEN:
			return EffectTypes.TriggerType.ON_DAMAGE_TAKEN
		GameTypes.RelicTrigger.ON_TURN_END:
			return EffectTypes.TriggerType.ON_TURN_END
		GameTypes.RelicTrigger.ON_FLOOR_CLEAR:
			return EffectTypes.TriggerType.ON_FLOOR_CLEAR
		GameTypes.RelicTrigger.PASSIVE:
			return EffectTypes.TriggerType.ON_BATTLE_START
		_:
			return EffectTypes.TriggerType.ON_PLAY

# ============================================================
# Class（职业）
# ============================================================

static func load_class_defs() -> Dictionary:
	var data: Variant = _load_json("class.json")
	if not (data is Dictionary) or not data.has("base"):
		push_error("[ConfigLoader] class.json malformed")
		return {}

	# starting_items 按 class_id 聚合
	var start_items: Dictionary = {}
	if data.has("starting_items"):
		for si in data["starting_items"]:
			var cid: String = si.get("class_id", "")
			if cid == "":
				continue
			if not start_items.has(cid):
				start_items[cid] = []
			# 使用 legacy_key（兼容 initial_dice: Array[String]）
			var lk: String = si.get("legacy_key", "")
			if lk == "":
				lk = si.get("item_id", "")
			start_items[cid].append(lk)

	var defs: Dictionary = {}
	for row in data["base"]:
		var c := ClassDef.new()
		c.id = row.get("legacy_key", "")
		if c.id == "":
			c.id = row.get("id", "")
		c.name = row.get("name", "")
		c.title = row.get("title", "")
		c.description = row.get("description", "")
		c.color = Color(row.get("color", "#ffffff"))
		c.color_light = Color(row.get("color_light", "#ffffff"))
		c.color_dark = Color(row.get("color_dark", "#000000"))
		c.hp = int(row.get("hp", 100))
		c.max_hp = c.hp
		c.draw_count = int(row.get("draw_count", 3))
		c.max_plays = int(row.get("max_plays", 1))
		c.free_rerolls = int(row.get("free_rerolls", 1))
		c.can_blood_reroll = _as_bool(row.get("flag_blood_reroll", false))
		c.keep_unplayed = _as_bool(row.get("flag_keep_unplayed", false))
		c.normal_attack_multi_select = _as_bool(row.get("flag_multi_select", false))
		c.passive_desc = row.get("passive_desc", "")

		var cid: String = row.get("id", "")
		var items: Array = start_items.get(cid, [])  # [RULES-B2-EXEMPT] dict.get 返回裸 Array
		var typed: Array[String] = []
		for it in items:
			typed.append(str(it))
		c.initial_dice = typed

		defs[c.id] = c

	# 技能描述
	if data.has("skills"):
		var by_class: Dictionary = {}
		for sk in data["skills"]:
			var cid2: String = sk.get("class_id", "")
			# class_id 是 C01 等，需要映射到 legacy_key
			# 简化：通过 row 查找
			var legacy_cid := ""
			for row in data["base"]:
				if row.get("id", "") == cid2:
					legacy_cid = row.get("legacy_key", "")
					break
			if legacy_cid == "":
				continue
			if not by_class.has(legacy_cid):
				by_class[legacy_cid] = {"names": [], "descs": []}
			by_class[legacy_cid]["names"].append(sk.get("name", ""))
			by_class[legacy_cid]["descs"].append(sk.get("description", ""))
		for lid in by_class:
			if defs.has(lid):
				var names_arr: Array[String] = []
				var descs_arr: Array[String] = []
				for n in by_class[lid]["names"]: names_arr.append(str(n))
				for d in by_class[lid]["descs"]: descs_arr.append(str(d))
				defs[lid].skill_names = names_arr
				defs[lid].skill_descs = descs_arr

	return defs

# ============================================================
# Enemy（敌人）
# ============================================================

static func load_enemy_configs() -> Dictionary:
	var data: Variant = _load_json("enemy.json")
	if not (data is Dictionary) or not data.has("base"):
		push_error("[ConfigLoader] enemy.json malformed")
		return {}

	# phases 按 phase_group 聚合 → [ {phase_idx, threshold, action_group} ]
	var phase_map: Dictionary = {}
	if data.has("phases"):
		for p in data["phases"]:
			var pg: String = p.get("phase_group", "")
			if pg == "":
				continue
			if not phase_map.has(pg):
				phase_map[pg] = []
			phase_map[pg].append(p)

	# actions 按 action_group 聚合 → [ action ]
	var action_map: Dictionary = {}
	if data.has("actions"):
		for a in data["actions"]:
			var ag: String = a.get("action_group", "")
			if ag == "":
				continue
			if not action_map.has(ag):
				action_map[ag] = []
			action_map[ag].append(a)

	# quotes 按 quote_group 聚合 → {event: [text]}
	var quote_map: Dictionary = {}
	if data.has("quotes"):
		for q in data["quotes"]:
			var qg: String = q.get("quote_group", "")
			if qg == "":
				continue
			if not quote_map.has(qg):
				quote_map[qg] = {}
			var ev: String = q.get("event", "")
			if not quote_map[qg].has(ev):
				quote_map[qg][ev] = []
			quote_map[qg][ev].append(q.get("text", ""))

	var defs: Dictionary = {}
	for row in data["base"]:
		var c := EnemyConfig.new()
		c.id = row.get("legacy_key", "")
		if c.id == "":
			c.id = row.get("id", "")
		c.name = row.get("name", "")
		c.chapter = int(row.get("chapter", 1))
		c.base_hp = int(row.get("base_hp", 30))
		c.base_dmg = int(row.get("base_dmg", 5))
		c.drop_gold = int(row.get("drop_gold", 20))
		c.art_id = String(row.get("art_id", ""))
		c.drop_relic = _as_bool(row.get("drop_relic", false))
		c.drop_reroll_reward = int(row.get("drop_reroll_reward", 0))

		var cat: String = row.get("category", "NORMAL")
		c.category = EnemyConfig.EnemyCategory.NORMAL
		if cat == "ELITE":
			c.category = EnemyConfig.EnemyCategory.ELITE
		elif cat == "BOSS":
			c.category = EnemyConfig.EnemyCategory.BOSS
		c.combat_type = combat_type_from_string(row.get("combat_type", "WARRIOR"))

		# 组装 phases
		var pg: String = row.get("phase_group", "")
		var phases_arr: Array[EnemyConfig.EnemyPhase] = []
		var raw_phases: Array = phase_map.get(pg, [])  # [RULES-B2-EXEMPT] dict.get 返回裸 Array
		raw_phases.sort_custom(func(a, b): return int(a.get("phase_idx", 0)) < int(b.get("phase_idx", 0)))
		for p in raw_phases:
			var phase := EnemyConfig.EnemyPhase.new()
			phase.hp_threshold = float(p.get("hp_threshold", 0.0))
			var ag: String = p.get("action_group", "")
			var acts: Array[EnemyConfig.EnemyAction] = []
			var raw_acts: Array = action_map.get(ag, [])  # [RULES-B2-EXEMPT] dict.get 返回裸 Array
			raw_acts.sort_custom(func(a, b): return int(a.get("action_idx", 0)) < int(b.get("action_idx", 0)))
			for a in raw_acts:
				var act := EnemyConfig.EnemyAction.new()
				act.type = _action_type_from_string(a.get("type", "ATTACK"))
				act.base_value = int(a.get("base_value", 0))
				act.description = a.get("description", "")
				act.scalable = _as_bool(a.get("scalable", true))
				# [v2] 解析 effects 数组（JSON 中直接配置的效果列表）
				var raw_effects: Array = a.get("effects", [])  # [RULES-B2-EXEMPT]
				if not raw_effects.is_empty():
					var typed_effects: Array[Dictionary] = []
					for fx in raw_effects:
						if fx is Dictionary:
							typed_effects.append(fx)
					act.effects = typed_effects
				acts.append(act)
			phase.actions = acts
			phases_arr.append(phase)
		c.phases = phases_arr

		# 组装 quotes
		var qg: String = row.get("quote_group", "")
		var q := EnemyConfig.EnemyQuotes.new()
		var qdata: Dictionary = quote_map.get(qg, {})
		q.enter = _typed_string_array(qdata.get("enter", []))
		q.death = _typed_string_array(qdata.get("death", []))
		q.attack = _typed_string_array(qdata.get("attack", []))
		q.hurt = _typed_string_array(qdata.get("hurt", []))
		q.low_hp = _typed_string_array(qdata.get("low_hp", []))
		# [P0-MIGRATION] Boss 扩展台词
		q.greet = _typed_string_array(qdata.get("greet", []))
		q.dispatch = _typed_string_array(qdata.get("dispatch", []))
		q.mid_boss_warning = _typed_string_array(qdata.get("mid_boss_warning", []))
		q.phase2_taunt = _typed_string_array(qdata.get("phase2_taunt", []))
		c.quotes = q

		# [P0-MIGRATION] Boss 召唤机制
		var summon_data: Dictionary = row.get("summons", {})
		if summon_data.size() > 0:
			var s := EnemyConfig.EnemySummon.new()
			s.minion_id = summon_data.get("minion_id", "")
			s.interval = int(summon_data.get("interval", 3))
			s.count = int(summon_data.get("count", 1))
			s.max_total = int(summon_data.get("max_total", 4))
			s.wave_cap = int(summon_data.get("wave_cap", 4))
			s.hp_threshold = float(summon_data.get("hp_threshold", 0.0))
			c.summons = s

		# [P0-MIGRATION] Boss 死亡分裂/复活机制
		var revive_data: Dictionary = row.get("revive", {})
		if revive_data.size() > 0:
			var r := EnemyConfig.EnemyRevive.new()
			r.revive_hp_ratio = float(revive_data.get("revive_hp_ratio", 0.5))
			r.split_into = int(revive_data.get("split_into", 2))
			r.split_minion_id = revive_data.get("split_minion_id", "")
			c.revive = r

		# [P0-MIGRATION] Boss rank
		var rank_str: String = row.get("boss_rank", "NONE")
		match rank_str:
			"MID": c.boss_rank = EnemyConfig.BossRank.MID
			"FINAL": c.boss_rank = EnemyConfig.BossRank.FINAL
			_: c.boss_rank = EnemyConfig.BossRank.NONE

		defs[c.id] = c

	# 将 JSON 加载的数据注入到 EnemyConfig 静态注册表，取代硬编码
	EnemyConfig._all_configs = defs
	return defs

static func _action_type_from_string(s: String) -> int:
	match s:
		"ATTACK": return EnemyConfig.EnemyAction.ActionType.ATTACK
		"DEFEND": return EnemyConfig.EnemyAction.ActionType.DEFEND
		"SKILL": return EnemyConfig.EnemyAction.ActionType.SKILL
	return EnemyConfig.EnemyAction.ActionType.ATTACK

# ============================================================
# 工具函数
# ============================================================

static func _as_bool(v: Variant) -> bool:
	if v is bool:
		return v
	if v is int or v is float:
		return v != 0
	if v is String:
		var s := (v as String).strip_edges().to_lower()
		return s == "1" or s == "true" or s == "yes"
	return false

static func _as_int_array(v: Variant) -> Array[int]:
	var out: Array[int] = []
	if v is Array:
		for x in v:
			out.append(int(x))
	return out

static func _typed_string_array(v: Variant) -> Array[String]:
	var out: Array[String] = []
	if v is Array:
		for x in v:
			out.append(str(x))
	return out
