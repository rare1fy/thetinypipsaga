## GM 调试面板 — 开发调试工具
## 迁移自 React 版 GmDebugPanel.tsx
## 通过 ModalHub 打开，嵌入设置面板

class_name GmDebugPanel
extends VBoxContainer

const ModalHubRef := preload("res://common/ui/modal_hub.gd")

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	add_theme_constant_override("separation", 8)
	_build_ui()


# ============================================================
# 构建 UI
# ============================================================

func _build_ui() -> void:
	# 标题
	var title := Label.new()
	title.text = "— 调试功能 —"
	title.add_theme_color_override("font_color", Color("#ff6060"))
	title.add_theme_font_size_override("font_size", 12)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	
	# 快捷操作
	_build_quick_actions()
	
	# 传送
	_build_teleport()
	
	# 战斗操作
	_build_battle_actions()
	
	# 遗物管理
	_build_relic_manager()
	
	# 骰子管理
	_build_dice_manager()


# ============================================================
# 快捷操作
# ============================================================

func _build_quick_actions() -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	
	grid.add_child(_make_btn("❤ 满血", Color("#40a040"), func():
		PlayerState.hp = PlayerState.max_hp
		GameManager.hp_changed.emit(PlayerState.hp, PlayerState.max_hp)
		VFX.show_toast("GM: 满血", "buff")
	))
	grid.add_child(_make_btn("💔 HP=1", Color("#e04040"), func():
		PlayerState.hp = 1
		GameManager.hp_changed.emit(PlayerState.hp, PlayerState.max_hp)
		VFX.show_toast("GM: HP=1", "warn")
	))
	grid.add_child(_make_btn("💰 +500金", Color("#d4a030"), func():
		PlayerState.add_gold(500)
		VFX.show_toast("GM: +500金", "buff")
	))
	grid.add_child(_make_btn("💎 +100魂晶", Color("#9060d0"), func():
		PlayerState.souls += 100
		VFX.show_toast("GM: +100魂晶", "buff")
	))
	grid.add_child(_make_btn("[H] +50血上限", Color("#e04040"), func():
		PlayerState.modify_max_hp(50)
		VFX.show_toast("GM: +50最大HP", "buff")
	))
	grid.add_child(_make_btn("⬆ +10等级经验", Color("#60c0e0"), func():
		if XpSystem:
			XpSystem.apply_xp_gain(999)
			VFX.show_toast("GM: 大量经验", "buff")
	))
	
	add_child(grid)


# ============================================================
# 传送
# ============================================================

func _build_teleport() -> void:
	var sep_label := Label.new()
	sep_label.text = "传送到指定层"
	sep_label.add_theme_color_override("font_color", Color("#9aa0ac"))
	sep_label.add_theme_font_size_override("font_size", 11)
	sep_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(sep_label)
	
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	
	grid.add_child(_make_btn("中Boss(7)", Color("#e09040"), func():
		_teleport_to_depth(7)
	))
	grid.add_child(_make_btn("终Boss(14)", Color("#e09040"), func():
		_teleport_to_depth(14)
	))
	
	add_child(grid)


func _teleport_to_depth(target_depth: int) -> void:
	var nodes: Array[MapGenerator.MapNode] = PlayerState.map_nodes
	if nodes.is_empty():
		VFX.show_toast("GM: 地图为空", "warn")
		return
	
	# 标记目标深度之前的所有节点为已完成
	var prev_depth: int = target_depth - 1
	var found_prev: bool = false
	for node: MapGenerator.MapNode in nodes:
		if node.depth <= prev_depth:
			node.completed = true
			if node.depth == prev_depth:
				PlayerState.current_node = node.depth
				found_prev = true
	
	if found_prev:
		GameManager.set_phase(GameTypes.GamePhase.MAP)
		VFX.show_toast("GM: 传送到深度 %d" % target_depth, "buff")
		ModalHubRef.close_all()
	else:
		VFX.show_toast("GM: 找不到目标节点", "warn")


# ============================================================
# 战斗操作
# ============================================================

func _build_battle_actions() -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	
	grid.add_child(_make_btn("[D] 99出牌", Color("#60c0e0"), func():
		TurnManager.plays_left = 99
		TurnManager.max_plays = 99
		VFX.show_toast("GM: 99次出牌", "buff")
	))
	grid.add_child(_make_btn("🔄 99重掷", Color("#60c0e0"), func():
		TurnManager.free_rerolls_left = 99
		TurnManager.free_rerolls_per_turn = 99
		VFX.show_toast("GM: 99重掷", "buff")
	))
	
	add_child(grid)
	
	# 杀死当前波次
	add_child(_make_btn("💀 杀死当前波次", Color("#e04040"), func():
		if TurnManager.phase == GameTypes.GamePhase.BATTLE:
			# 通过信号通知 BattleController 杀死所有敌人
			for enemy: EnemyInstance in GameManager.current_enemies:
				if enemy.is_alive():
					enemy.hp = 0
			VFX.show_toast("GM: 杀死当前波次", "buff")
		else:
			VFX.show_toast("GM: 当前不在战斗中", "warn")
	))
	
	var grid2 := GridContainer.new()
	grid2.columns = 2
	grid2.add_theme_constant_override("h_separation", 6)
	grid2.add_theme_constant_override("v_separation", 6)
	
	grid2.add_child(_make_btn("⚔ 立即胜利", Color("#d4a030"), func():
		if TurnManager.phase == GameTypes.GamePhase.BATTLE:
			# 标记当前节点完成
			for node: MapGenerator.MapNode in PlayerState.map_nodes:
				if node.depth == PlayerState.current_node:
					node.completed = true
					break
			TurnManager.is_enemy_turn = false
			GameManager.set_phase(GameTypes.GamePhase.LOOT)
			VFX.show_toast("GM: 战斗胜利", "buff")
			ModalHubRef.close_all()
		else:
			VFX.show_toast("GM: 当前不在战斗中", "warn")
	))
	grid2.add_child(_make_btn("⏭ 跨大关", Color("#e09040"), func():
		for node: MapGenerator.MapNode in PlayerState.map_nodes:
			node.completed = true
		TurnManager.is_enemy_turn = false
		GameManager.set_phase(GameTypes.GamePhase.CHAPTER_TRANSITION)
		VFX.show_toast("GM: 跳到下一大关", "buff")
		ModalHubRef.close_all()
	))
	
	add_child(grid2)


# ============================================================
# 遗物管理
# ============================================================

func _build_relic_manager() -> void:
	var sep_label := Label.new()
	sep_label.text = "遗物管理"
	sep_label.add_theme_color_override("font_color", Color("#9aa0ac"))
	sep_label.add_theme_font_size_override("font_size", 11)
	sep_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(sep_label)
	
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	
	grid.add_child(_make_btn("+ 添加遗物", Color("#40a040"), func():
		_open_add_relic_panel()
	))
	grid.add_child(_make_btn("- 移除遗物", Color("#e04040"), func():
		_open_remove_relic_panel()
	))
	
	add_child(grid)


func _open_add_relic_panel() -> void:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(400, 500)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	
	var all_relics: Dictionary = GameData.get_all_relics()
	var owned_ids: Array[String] = []
	for r: Dictionary in PlayerState.relics:
		owned_ids.append(String(r.get("id", "")))
	
	for relic_id: String in all_relics:
		var relic_def: Dictionary = all_relics[relic_id]
		var relic_name: String = String(relic_def.get("name", relic_id))
		var rarity: String = String(relic_def.get("rarity", "common"))
		var is_owned: bool = relic_id in owned_ids
		
		var btn := Button.new()
		btn.text = "[%s] %s%s" % [_rarity_label(rarity), relic_name, " (已有)" if is_owned else ""]
		btn.add_theme_color_override("font_color", _rarity_color(rarity))
		if is_owned:
			btn.modulate.a = 0.5
		btn.pressed.connect(func():
			if relic_id in owned_ids:
				VFX.show_toast("已拥有该遗物", "warn")
				return
			PlayerState.relics.append(relic_def.duplicate())
			owned_ids.append(relic_id)
			VFX.show_toast("GM: +遗物「%s」" % relic_name, "buff")
		)
		vbox.add_child(btn)
	
	scroll.add_child(vbox)
	ModalHubRef.open(scroll, "添加遗物", {"size": Vector2(440, 560), "close_on_backdrop": true})


func _open_remove_relic_panel() -> void:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(400, 400)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	
	if PlayerState.relics.is_empty():
		var hint := Label.new()
		hint.text = "当前没有遗物"
		hint.add_theme_color_override("font_color", Color("#9aa0ac"))
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(hint)
	else:
		for i: int in PlayerState.relics.size():
			var relic: Dictionary = PlayerState.relics[i]
			var relic_name: String = String(relic.get("name", "?"))
			var rarity: String = String(relic.get("rarity", "common"))
			var idx: int = i  # 闭包捕获
			
			var btn := Button.new()
			btn.text = "[%s] %s  ×" % [_rarity_label(rarity), relic_name]
			btn.add_theme_color_override("font_color", _rarity_color(rarity))
			btn.pressed.connect(func():
				if idx < PlayerState.relics.size():
					var removed_name: String = String(PlayerState.relics[idx].get("name", "?"))
					PlayerState.relics.remove_at(idx)
					VFX.show_toast("GM: 移除遗物「%s」" % removed_name, "warn")
					ModalHubRef.close()
					_open_remove_relic_panel()  # 刷新列表
			)
			vbox.add_child(btn)
	
	scroll.add_child(vbox)
	ModalHubRef.open(scroll, "移除遗物", {"size": Vector2(440, 500), "close_on_backdrop": true})


# ============================================================
# 骰子管理
# ============================================================

func _build_dice_manager() -> void:
	var sep_label := Label.new()
	sep_label.text = "骰子管理"
	sep_label.add_theme_color_override("font_color", Color("#9aa0ac"))
	sep_label.add_theme_font_size_override("font_size", 11)
	sep_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(sep_label)
	
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	
	grid.add_child(_make_btn("+ 添加骰子", Color("#60c0e0"), func():
		_open_add_dice_panel()
	))
	grid.add_child(_make_btn("- 移除骰子", Color("#e04040"), func():
		_open_remove_dice_panel()
	))
	
	add_child(grid)


func _open_add_dice_panel() -> void:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(400, 500)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	
	var all_dice: Dictionary = GameData.get_all_dice()
	for dice_id: String in all_dice:
		var def: DiceDef = all_dice[dice_id]
		var btn := Button.new()
		btn.text = "[%s] %s  [%s]" % [_dice_rarity_label(def.rarity), def.name, ",".join(def.faces.map(func(f: int): return str(f)))]
		btn.add_theme_color_override("font_color", _dice_rarity_color(def.rarity))
		btn.pressed.connect(func():
			DiceBag.owned_dice.append({"defId": dice_id, "level": 1})
			DiceBag.dice_bag.append(dice_id)
			VFX.show_toast("GM: +骰子「%s」" % def.name, "buff")
		)
		vbox.add_child(btn)
	
	scroll.add_child(vbox)
	ModalHubRef.open(scroll, "添加骰子", {"size": Vector2(440, 560), "close_on_backdrop": true})


func _open_remove_dice_panel() -> void:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(400, 400)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	
	if DiceBag.owned_dice.is_empty():
		var hint := Label.new()
		hint.text = "骰子库为空"
		hint.add_theme_color_override("font_color", Color("#9aa0ac"))
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(hint)
	else:
		# 按 defId 聚合计数
		var counts: Dictionary = {}
		for od: Dictionary in DiceBag.owned_dice:
			var def_id: String = String(od.get("defId", ""))
			if not counts.has(def_id):
				counts[def_id] = 0
			counts[def_id] += 1
		
		for def_id: String in counts:
			var count: int = counts[def_id]
			var def: DiceDef = GameData.get_dice_def(def_id)
			var dice_name: String = def.name if def else def_id
			var dice_rarity: int = def.rarity if def else GameTypes.DiceRarity.COMMON
			
			var btn := Button.new()
			btn.text = "[%s] %s  ×%d  ×" % [_dice_rarity_label(dice_rarity), dice_name, count]
			btn.add_theme_color_override("font_color", _dice_rarity_color(dice_rarity))
			btn.pressed.connect(func():
				# 移除一颗
				var idx: int = -1
				for i: int in DiceBag.owned_dice.size():
					if String(DiceBag.owned_dice[i].get("defId", "")) == def_id:
						idx = i
						break
				if idx >= 0:
					DiceBag.owned_dice.remove_at(idx)
					# 从 dice_bag 也移除一个
					var bag_idx: int = DiceBag.dice_bag.find(def_id)
					if bag_idx >= 0:
						DiceBag.dice_bag.remove_at(bag_idx)
					VFX.show_toast("GM: 移除骰子「%s」" % dice_name, "warn")
					ModalHubRef.close()
					_open_remove_dice_panel()  # 刷新
			)
			vbox.add_child(btn)
	
	scroll.add_child(vbox)
	ModalHubRef.open(scroll, "移除骰子", {"size": Vector2(440, 500), "close_on_backdrop": true})


# ============================================================
# 工具方法
# ============================================================

func _make_btn(text: String, color: Color, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_color_override("font_color", color)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(callback)
	return btn


static func _rarity_label(rarity: String) -> String:
	match rarity:
		"common": return "普通"
		"uncommon": return "稀有"
		"rare": return "史诗"
		"legendary": return "传说"
		"curse": return "诅咒"
		_: return "?"


static func _rarity_color(rarity: String) -> Color:
	match rarity:
		"common": return Color("#9aa0ac")
		"uncommon": return Color("#40c040")
		"rare": return Color("#4080ff")
		"legendary": return Color("#d4a030")
		"curse": return Color("#e04040")
		_: return Color("#888888")


static func _dice_rarity_label(rarity: int) -> String:
	match rarity:
		GameTypes.DiceRarity.COMMON: return "普通"
		GameTypes.DiceRarity.UNCOMMON: return "稀有"
		GameTypes.DiceRarity.RARE: return "史诗"
		GameTypes.DiceRarity.LEGENDARY: return "传说"
		GameTypes.DiceRarity.CURSE: return "诅咒"
		_: return "?"


static func _dice_rarity_color(rarity: int) -> Color:
	match rarity:
		GameTypes.DiceRarity.COMMON: return Color("#9aa0ac")
		GameTypes.DiceRarity.UNCOMMON: return Color("#40c040")
		GameTypes.DiceRarity.RARE: return Color("#4080ff")
		GameTypes.DiceRarity.LEGENDARY: return Color("#d4a030")
		GameTypes.DiceRarity.CURSE: return Color("#e04040")
		_: return Color("#888888")
