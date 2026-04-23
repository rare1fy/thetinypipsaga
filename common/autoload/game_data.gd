## 游戏数据注册表 — 所有骰子定义、遗物定义的统一查询入口
## 对应原版 data/dice.ts + data/relics*.ts

extends Node

# ============================================================
# 骰子定义注册表
# ============================================================

var _dice_defs: Dictionary = {}
var _relic_defs: Dictionary = {}


func _ready() -> void:
	_register_base_dice()
	_register_warrior_dice()
	_register_mage_dice()
	_register_rogue_dice()
	_register_relics()


## 获取骰子定义
func get_dice_def(id: String) -> DiceDef:
	if _dice_defs.has(id):
		return _dice_defs[id]
	push_warning("DiceDef not found: %s, fallback to standard" % id)
	return _dice_defs.get("standard", DiceDef.new())


## 获取遗物定义
func get_relic_def(id: String) -> RelicDef:
	if _relic_defs.has(id):
		return _relic_defs[id]
	push_warning("RelicDef not found: %s" % id)
	return RelicDef.new()


## 掷骰子
func roll_dice(id: String) -> int:
	var def := get_dice_def(id)
	if def.faces.is_empty():
		return 1
	return def.faces[randi() % def.faces.size()]


## 获取骰子奖励池
func get_dice_reward_pool(battle_type: String, p_class: String = "") -> Array[DiceDef]:
	var pool: Array[DiceDef] = []
	var all_defs := _dice_defs.values() as Array[DiceDef]
	
	# 职业骰子加权
	var prefix := ""
	if p_class == "warrior":
		prefix = "w_"
	elif p_class == "mage":
		prefix = "mage_"
	elif p_class == "rogue":
		prefix = "r_"
	
	for d in all_defs:
		if prefix != "" and d.id.begins_with(prefix):
			# 职业骰子高权重
			var weight := 3
			if d.rarity == GameTypes.DiceRarity.RARE:
				weight = 2 if battle_type == "enemy" else 3
			elif d.rarity == GameTypes.DiceRarity.LEGENDARY:
				weight = 1 if battle_type != "boss" else 3
			for i in weight:
				pool.append(d)
		elif not d.id.begins_with("w_") and not d.id.begins_with("mage_") and not d.id.begins_with("r_") and not d.id == "temp_rogue" and not d.id == "cursed" and not d.id == "cracked":
			# 通用骰子
			if d.rarity != GameTypes.DiceRarity.CURSE:
				pool.append(d)
	
	return pool


## 随机挑选N个不重复骰子
func pick_random_dice(pool: Array[DiceDef], count: int) -> Array[DiceDef]:
	var shuffled := pool.duplicate()
	shuffled.shuffle()
	var seen: Dictionary = {}
	var result: Array[DiceDef] = []
	for d in shuffled:
		if not seen.has(d.id):
			seen[d.id] = true
			result.append(d)
			if result.size() >= count:
				break
	return result


# ============================================================
# 骰子注册
# ============================================================

func _reg_dice(d: DiceDef) -> void:
	_dice_defs[d.id] = d


func _register_base_dice() -> void:
	# 普通
	var standard := DiceDef.new()
	standard.id = "standard"; standard.name = "普通骰子"; standard.faces = [1,2,3,4,5,6]
	standard.description = "标准六面骰"; standard.rarity = GameTypes.DiceRarity.COMMON
	_reg_dice(standard)
	
	# 稀有
	var blade := DiceDef.new()
	blade.id = "blade"; blade.name = "锋刃骰子"; blade.faces = [1,2,3,4,5,6]
	blade.description = "出牌时追加5点固定伤害"; blade.rarity = GameTypes.DiceRarity.RARE
	blade.bonus_damage = 5
	_reg_dice(blade)
	
	var amplify := DiceDef.new()
	amplify.id = "amplify"; amplify.name = "倍增骰子"; amplify.faces = [1,2,3,4,5,6]
	amplify.description = "出牌时最终伤害提升20%"; amplify.rarity = GameTypes.DiceRarity.RARE
	amplify.bonus_mult = 1.2
	_reg_dice(amplify)
	
	var split := DiceDef.new()
	split.id = "split"; split.name = "分裂骰子"; split.faces = [1,2,3,4,5,6]
	split.description = "出牌时分裂出1颗相同点数的临时骰子"; split.rarity = GameTypes.DiceRarity.RARE
	_reg_dice(split)
	
	var magnet := DiceDef.new()
	magnet.id = "magnet"; magnet.name = "磁吸骰子"; magnet.faces = [1,2,3,4,5,6]
	magnet.description = "出牌时随机将1颗同伴骰子点数变为与本骰子相同"; magnet.rarity = GameTypes.DiceRarity.RARE
	_reg_dice(magnet)
	
	var joker := DiceDef.new()
	joker.id = "joker"; joker.name = "小丑骰子"; joker.faces = [1,2,3,4,5,6,7,8,9]
	joker.description = "点数1到9随机，突破六面骰限制"; joker.rarity = GameTypes.DiceRarity.RARE
	_reg_dice(joker)
	
	# 传说
	var chaos := DiceDef.new()
	chaos.id = "chaos"; chaos.name = "混沌骰子"; chaos.faces = [1,1,1,6,6,6]
	chaos.description = "只会掷出1或6"; chaos.rarity = GameTypes.DiceRarity.LEGENDARY
	_reg_dice(chaos)
	
	# 诅咒
	var cursed := DiceDef.new()
	cursed.id = "cursed"; cursed.name = "诅咒骰子"; cursed.faces = [0,0,0,0,0,0]
	cursed.description = "点数固定0"; cursed.rarity = GameTypes.DiceRarity.CURSE; cursed.is_cursed = true
	_reg_dice(cursed)
	
	var cracked := DiceDef.new()
	cracked.id = "cracked"; cracked.name = "碎裂骰子"; cracked.faces = [1,1,1,2,2,2]
	cracked.description = "出牌后受2点反噬"; cracked.rarity = GameTypes.DiceRarity.CURSE
	cracked.self_damage = 2; cracked.is_cracked = true
	_reg_dice(cracked)
	
	# 临时
	var temp_rogue := DiceDef.new()
	temp_rogue.id = "temp_rogue"; temp_rogue.name = "暗影残骰"; temp_rogue.faces = [1,1,2,2,3,3]
	temp_rogue.description = "连击奖励临时骰子"; temp_rogue.rarity = GameTypes.DiceRarity.COMMON
	_reg_dice(temp_rogue)
	
	# 灌铅（保留兼容）
	var heavy := DiceDef.new()
	heavy.id = "heavy"; heavy.name = "灌铅骰子"; heavy.faces = [4,4,5,5,6,6]
	heavy.description = "只会掷出4/5/6"; heavy.rarity = GameTypes.DiceRarity.UNCOMMON
	_reg_dice(heavy)


func _register_warrior_dice() -> void:
	var bloodthirst := DiceDef.new()
	bloodthirst.id = "w_bloodthirst"; bloodthirst.name = "嗜血骰子"; bloodthirst.faces = [1,2,3,4,5,6]
	bloodthirst.description = "卖血重投时+3伤害"; bloodthirst.rarity = GameTypes.DiceRarity.UNCOMMON
	bloodthirst.scale_with_blood_rerolls = true; bloodthirst.bonus_damage = 3
	_reg_dice(bloodthirst)
	
	var ironwall := DiceDef.new()
	ironwall.id = "w_ironwall"; ironwall.name = "铁壁骰子"; ironwall.faces = [1,2,3,4,5,6]
	ironwall.description = "出牌时获得等同点数的护甲"; ironwall.rarity = GameTypes.DiceRarity.UNCOMMON
	ironwall.armor_from_value = true
	_reg_dice(ironwall)
	
	var fury := DiceDef.new()
	fury.id = "w_fury"; fury.name = "怒火骰子"; fury.faces = [1,2,3,4,5,6]
	fury.description = "受到敌人攻击时永久+1伤害"; fury.rarity = GameTypes.DiceRarity.RARE
	_reg_dice(fury)
	
	var execute := DiceDef.new()
	execute.id = "w_execute"; execute.name = "处刑骰子"; execute.faces = [1,2,3,4,5,6]
	execute.description = "敌人HP≤30%时伤害翻倍"; execute.rarity = GameTypes.DiceRarity.RARE
	execute.execute_threshold = 0.3; execute.execute_mult = 2.0
	_reg_dice(execute)
	
	var berserker := DiceDef.new()
	berserker.id = "w_berserker"; berserker.name = "狂暴骰子"; berserker.faces = [1,2,3,4,5,6]
	berserker.description = "自残5点HP，伤害+50%"; berserker.rarity = GameTypes.DiceRarity.RARE
	berserker.self_damage = 5; berserker.self_berserk = true; berserker.bonus_mult = 1.5
	_reg_dice(berserker)


func _register_mage_dice() -> void:
	var elemental := DiceDef.new()
	elemental.id = "mage_elemental"; elemental.name = "元素骰子"; elemental.faces = [1,2,3,4,5,6]
	elemental.description = "每回合随机变为火/冰/雷/毒/圣元素"; elemental.rarity = GameTypes.DiceRarity.UNCOMMON
	elemental.is_elemental = true
	_reg_dice(elemental)
	
	var reverse := DiceDef.new()
	reverse.id = "mage_reverse"; reverse.name = "逆转骰子"; reverse.faces = [1,2,3,4,5,6]
	reverse.description = "出牌时点数翻转(7-点数)"; reverse.rarity = GameTypes.DiceRarity.UNCOMMON
	reverse.reverse_value = true
	_reg_dice(reverse)
	
	var crystal := DiceDef.new()
	crystal.id = "mage_crystal"; crystal.name = "水晶骰子"; crystal.faces = [1,2,3,4,5,6]
	crystal.description = "保留到下回合时点数+1"; crystal.rarity = GameTypes.DiceRarity.RARE
	crystal.bonus_on_keep = 1
	_reg_dice(crystal)
	
	var stardust := DiceDef.new()
	stardust.id = "mage_stardust"; stardust.name = "星尘骰子"; stardust.faces = [1,2,3,4,5,6]
	stardust.description = "每保留1回合+1点(上限5)"; stardust.rarity = GameTypes.DiceRarity.RARE
	stardust.bonus_per_turn_kept = 1; stardust.keep_bonus_cap = 5
	_reg_dice(stardust)


func _register_rogue_dice() -> void:
	var quickdraw := DiceDef.new()
	quickdraw.id = "r_quickdraw"; quickdraw.name = "快攻骰子"; quickdraw.faces = [1,2,3,4,5,6]
	quickdraw.description = "连击时+20%伤害"; quickdraw.rarity = GameTypes.DiceRarity.UNCOMMON
	quickdraw.combo_bonus = 0.2
	_reg_dice(quickdraw)
	
	var combo_mastery := DiceDef.new()
	combo_mastery.id = "r_combomastery"; combo_mastery.name = "连击心得"; combo_mastery.faces = [1,2,3,4,5,6]
	combo_mastery.description = "连击时获得暗影残骰"; combo_mastery.rarity = GameTypes.DiceRarity.UNCOMMON
	combo_mastery.grant_shadow_die = true
	_reg_dice(combo_mastery)
	
	var poison_dart := DiceDef.new()
	poison_dart.id = "r_poisondart"; poison_dart.name = "毒镖骰子"; poison_dart.faces = [1,2,3,4,5,6]
	poison_dart.description = "附加2层中毒"; poison_dart.rarity = GameTypes.DiceRarity.RARE
	poison_dart.poison_base = 2; poison_dart.status_to_enemy_type = GameTypes.StatusType.POISON
	poison_dart.status_to_enemy_value = 2; poison_dart.status_to_enemy_duration = 3
	_reg_dice(poison_dart)
	
	var shadow_clone := DiceDef.new()
	shadow_clone.id = "r_shadowclone"; shadow_clone.name = "影分身"; shadow_clone.faces = [1,2,3,4,5,6]
	shadow_clone.description = "出牌时复制自身一同结算"; shadow_clone.rarity = GameTypes.DiceRarity.RARE
	shadow_clone.shadow_clone_play = true
	_reg_dice(shadow_clone)


# ============================================================
# 遗物注册（核心遗物子集）
# ============================================================

func _reg_relic(r: RelicDef) -> void:
	_relic_defs[r.id] = r


func _register_relics() -> void:
	# --- 通用遗物 ---
	_reg_relic(_mk_relic("iron_heart", "铁之心", "获得5点护甲", GameTypes.RelicRarity.COMMON,
		GameTypes.RelicTrigger.ON_BATTLE_START, {"armor": 5}))
	_reg_relic(_mk_relic("healing_herb", "治愈草药", "战斗开始时恢复10HP", GameTypes.RelicRarity.COMMON,
		GameTypes.RelicTrigger.ON_BATTLE_START, {"heal": 10}))
	_reg_relic(_mk_relic("sharp_blade", "锋利之刃", "每次出牌+3伤害", GameTypes.RelicRarity.COMMON,
		GameTypes.RelicTrigger.ON_PLAY, {"damage": 3}))
	_reg_relic(_mk_relic("lucky_coin", "幸运金币", "金币获取+20%", GameTypes.RelicRarity.COMMON,
		GameTypes.RelicTrigger.PASSIVE, {"gold_bonus": 20}))
	_reg_relic(_mk_relic("hourglass", "时光沙漏", "致命伤害时免死一次，消耗此遗物", GameTypes.RelicRarity.RARE,
		GameTypes.RelicTrigger.ON_FATAL, {"prevent_death": true}))
	_reg_relic(_mk_relic("fortune_wheel_relic", "命运之轮", "首次出牌后保留手牌一次", GameTypes.RelicRarity.UNCOMMON,
		GameTypes.RelicTrigger.PASSIVE, {"keep_unplayed_once": true}))
	_reg_relic(_mk_relic("blood_pact", "血之契约", "回合结束保留1颗最高点骰子", GameTypes.RelicRarity.RARE,
		GameTypes.RelicTrigger.ON_TURN_END, {"keep_highest_die": 1}))
	_reg_relic(_mk_relic("magic_glove", "魔法手套", "每场战斗下回合+1手牌", GameTypes.RelicRarity.UNCOMMON,
		GameTypes.RelicTrigger.ON_TURN_END, {"temp_draw_bonus": 1}))
	_reg_relic(_mk_relic("whetstone", "磨砺石", "每场战斗下回合+1出牌", GameTypes.RelicRarity.RARE,
		GameTypes.RelicTrigger.ON_TURN_END, {"grant_extra_play": 1}))
	_reg_relic(_mk_relic("rage_fire", "怒火燎原", "受到伤害后下次出牌+5伤害", GameTypes.RelicRarity.UNCOMMON,
		GameTypes.RelicTrigger.ON_DAMAGE_TAKEN, {"damage": 5}))
	# --- 稀有 ---
	_reg_relic(_mk_relic("prism_focus", "棱镜聚焦", "锁定一个元素，同元素牌型伤害+30%", GameTypes.RelicRarity.RARE,
		GameTypes.RelicTrigger.PASSIVE, {"multiplier": 0.3}))
	_reg_relic(_mk_relic("limit_breaker", "突破极限", "小丑骰子可掷出10-12", GameTypes.RelicRarity.LEGENDARY,
		GameTypes.RelicTrigger.PASSIVE, {"max_points_unlocked": true}))
	_reg_relic(_mk_relic("pair_upgrade", "对子大师", "对子视为三条", GameTypes.RelicRarity.RARE,
		GameTypes.RelicTrigger.PASSIVE, {"pair_as_triplet": true}))
	_reg_relic(_mk_relic("straight_master", "顺子大师", "顺子牌型等级+1", GameTypes.RelicRarity.RARE,
		GameTypes.RelicTrigger.PASSIVE, {"straight_upgrade": 1}))
	# --- 传说 ---
	_reg_relic(_mk_relic("soul_crystal", "魂晶之心", "溢出伤害×倍率×15%转化为魂晶", GameTypes.RelicRarity.LEGENDARY,
		GameTypes.RelicTrigger.ON_KILL, {"multiplier": 0.15}))
	_reg_relic(_mk_relic("life_furnace", "生命熔炉", "每出牌5次恢复15HP", GameTypes.RelicRarity.LEGENDARY,
		GameTypes.RelicTrigger.ON_PLAY, {"heal": 15, "counter": 0, "max_counter": 5}))


func _mk_relic(id: String, name: String, desc: String, rarity: GameTypes.RelicRarity,
	trigger: GameTypes.RelicTrigger, props: Dictionary = {}) -> RelicDef:
	var r := RelicDef.new()
	r.id = id; r.name = name; r.description = desc; r.rarity = rarity; r.trigger = trigger
	# 应用属性
	for key in props:
		if key in r:
			r.set(key, props[key])
	return r
