## 主场景 — 场景路由器，根据 GamePhase 切换显示的子场景
## 带淡入淡出过渡动画，连接 EventBus.fade_out / fade_in 信号

extends Control

var _scenes: Dictionary = {}
var _current_scene: Control = null
var _transitioning: bool = false

## 过渡遮罩层（全屏 ColorRect，用于淡入淡出）
var _overlay: ColorRect


func _ready() -> void:
	# 创建过渡遮罩
	_overlay = ColorRect.new()
	_overlay.color = Color.BLACK
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.z_index = 100
	# 全屏锚定
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.modulate.a = 0.0
	add_child(_overlay)
	
	# 预加载所有场景
	_scenes = {
		GameTypes.GamePhase.START: preload("res://ui/start_screen/start_screen.tscn"),
		GameTypes.GamePhase.CLASS_SELECT: preload("res://ui/class_select/class_select.tscn"),
		GameTypes.GamePhase.MAP: preload("res://ui/map_screen/map_screen.tscn"),
		GameTypes.GamePhase.BATTLE: preload("res://ui/battle/battle_scene.tscn"),
		GameTypes.GamePhase.MERCHANT: preload("res://ui/merchant/merchant_screen.tscn"),
		GameTypes.GamePhase.CAMPFIRE: preload("res://ui/campfire/campfire_screen.tscn"),
		GameTypes.GamePhase.EVENT: preload("res://ui/event/event_screen.tscn"),
		GameTypes.GamePhase.LOOT: preload("res://ui/loot/loot_screen.tscn"),
		GameTypes.GamePhase.DICE_REWARD: preload("res://ui/dice_reward/dice_reward_screen.tscn"),
		GameTypes.GamePhase.VICTORY: preload("res://ui/victory/victory_screen.tscn"),
		GameTypes.GamePhase.GAME_OVER: preload("res://ui/game_over/game_over_screen.tscn"),
	}
	
	GameManager.phase_changed.connect(_on_phase_changed)
	EventBus.fade_out.connect(_on_fade_out_request)
	EventBus.fade_in.connect(_on_fade_in_request)
	
	# 初始显示开始画面（无过渡）
	_instantiate_scene(GameTypes.GamePhase.START)
	VFX.fade_in(_current_scene, 0.5)


func _on_phase_changed(new_phase: GameTypes.GamePhase) -> void:
	if _transitioning:
		return
	_switch_to_with_transition(new_phase)


func _on_fade_out_request() -> void:
	if _overlay:
		_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
		VFX.fade_out(_overlay, 0.25)


func _on_fade_in_request() -> void:
	if _overlay:
		VFX.fade_in(_overlay, 0.25)
		# 延迟取消遮挡
		get_tree().create_timer(0.3).timeout.connect(func(): _overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE)


## 带过渡动画的场景切换：淡出 → 换场景 → 淡入
func _switch_to_with_transition(phase: GameTypes.GamePhase) -> void:
	_transitioning = true
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# 淡出
	var tween := create_tween()
	tween.tween_property(_overlay, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func(): _instantiate_scene(phase))
	# 等一帧让新场景布局完成
	tween.tween_callback(func(): await get_tree().process_frame)
	tween.tween_property(_overlay, "modulate:a", 0.0, 0.3).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func():
		_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_transitioning = false
	)


## 实例化场景（不带动画）
func _instantiate_scene(phase: GameTypes.GamePhase) -> void:
	if _current_scene:
		_current_scene.queue_free()
		_current_scene = null
	
	var scene_packed: PackedScene = _scenes.get(phase)
	if not scene_packed:
		scene_packed = _scenes.get(GameTypes.GamePhase.MAP)
	
	if scene_packed:
		_current_scene = scene_packed.instantiate()
		_current_scene.z_index = 0
		add_child(_current_scene)
