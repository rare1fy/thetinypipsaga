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

static var _enums_cache: Dictionary = {}
static var _enums_loaded: bool = false

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
		"EL2": return GameTypes.DiceElement.ICE
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
		"ST08": return GameTypes.StatusType.SLOW
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

		# 应用效果组
		var eg: String = row.get("effect_group", "")
		if eg != "" and eg_map.has(eg):
			_apply_effects(d, eg_map[eg])

		defs[d.id] = d
	return defs

## 把 effects 数组应用到 DiceDef 对象上
static func _apply_effects(d: DiceDef, effects: Array) -> void:
	for eff in effects:
		var key: String = eff.get("param_key", "")
		var value: Variant = eff.get("param_value", null)
		var ref: String = eff.get("param_ref", "")
		var et: String = eff.get("effect_type", "")

		# 处理状态引用（ST02x2x3 形式）
		if et == "ET07":
			var parsed := parse_status_ref(ref)
			d.status_to_enemy_type = parsed[0]
			d.status_to_enemy_value = parsed[1]
			d.status_to_enemy_duration = parsed[2]
			continue
		if et == "ET08":
			var parsed2 := parse_status_ref(ref)
			d.status_to_self_type = parsed2[0]
			d.status_to_self_value = parsed2[1]
			d.status_to_self_duration = parsed2[2]
			continue

		# 普通字段：按 param_key 设置
		if key == "" or value == null:
			continue
		if key in d:
			# 自动类型转换：bool 字段存成 0/1 的情况
			var existing: Variant = d.get(key)
			if existing is bool:
				d.set(key, _as_bool(value))
			elif existing is int:
				d.set(key, int(value))
			elif existing is float:
				d.set(key, float(value))
			else:
				d.set(key, value)

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

		var eg: String = row.get("effect_group", "")
		if eg != "" and eg_map.has(eg):
			_apply_relic_effects(r, eg_map[eg])

		defs[r.id] = r
	return defs

static func _apply_relic_effects(r: RelicDef, effects: Array) -> void:
	for eff in effects:
		var key: String = eff.get("param_key", "")
		var value: Variant = eff.get("param_value", null)
		if key == "" or value == null:
			continue
		if key in r:
			var existing: Variant = r.get(key)
			if existing is bool:
				r.set(key, _as_bool(value))
			elif existing is int:
				r.set(key, int(value))
			elif existing is float:
				r.set(key, float(value))
			else:
				r.set(key, value)

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
		var items: Array = start_items.get(cid, [])
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
		var raw_phases: Array = phase_map.get(pg, [])
		raw_phases.sort_custom(func(a, b): return int(a.get("phase_idx", 0)) < int(b.get("phase_idx", 0)))
		for p in raw_phases:
			var phase := EnemyConfig.EnemyPhase.new()
			phase.hp_threshold = float(p.get("hp_threshold", 0.0))
			var ag: String = p.get("action_group", "")
			var acts: Array[EnemyConfig.EnemyAction] = []
			var raw_acts: Array = action_map.get(ag, [])
			raw_acts.sort_custom(func(a, b): return int(a.get("action_idx", 0)) < int(b.get("action_idx", 0)))
			for a in raw_acts:
				var act := EnemyConfig.EnemyAction.new()
				act.type = _action_type_from_string(a.get("type", "ATTACK"))
				act.base_value = int(a.get("base_value", 0))
				act.description = a.get("description", "")
				act.scalable = _as_bool(a.get("scalable", true))
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
		c.quotes = q

		defs[c.id] = c
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
