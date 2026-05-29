class_name BattleArena
extends Node2D
## 战斗场景预制件
## 每张战斗背景封装为一个 BattleArena 场景，内含：
##   - Background（Sprite2D）：背景图
##   - 6 个 Marker2D 点位：3 Slot × 2 距离
##   - 每个 Marker2D 下挂 Sprite2D 预览精灵（仅编辑器可见）
##
## 点位命名规则：
##   Slot0_Dist1, Slot0_Dist2  (中)
##   Slot1_Dist1, Slot1_Dist2  (左)
##   Slot2_Dist1, Slot2_Dist2  (右)
##
## 使用方式：
##   1. 在编辑器中打开 .tscn，拖动 Marker2D 到合适位置
##   2. 预览精灵会显示敌人大致占位（运行时自动隐藏）
##   3. battle_scene.gd 运行时读取 Marker2D 的 position + scale 作为透视参数

## ─── 导出参数 ───

## 各点位的缩放（Marker2D 的 scale.x 即为该距离的敌人缩放倍率）
## 这些值也可以直接在编辑器中调整 Marker2D 的 scale
@export_group("透视参数·距离1(近)")
@export var dist1_brightness: float = 1.0
@export var dist1_z_index: int = 7

@export_group("透视参数·距离2(远)")
@export var dist2_brightness: float = 0.88
@export var dist2_z_index: int = 5

## 场景标签（用于筛选/分类）
@export var arena_tag: String = ""


## ─── 运行时接口 ───

## 获取指定 slot + distance 的全部透视参数
## slot_index: 0=中, 1=左, 2=右
## distance: 1=近(贴脸), 2=远
## 返回: { position, depth_scale, depth_y, depth_brightness, depth_z }
func get_slot_visuals(slot_index: int, distance: int) -> Dictionary:
	var marker_name: String = "Slot%d_Dist%d" % [clampi(slot_index, 0, 2), clampi(distance, 1, 2)]
	var marker: Marker2D = get_node_or_null(marker_name) as Marker2D
	if marker == null:
		push_warning("[BattleArena] 未找到点位: %s" % marker_name)
		return _fallback_visuals(slot_index, distance)

	var brightness: float = dist1_brightness if distance == 1 else dist2_brightness
	var z: int = dist1_z_index if distance == 1 else dist2_z_index

	return {
		"position": marker.position,
		"depth_scale": marker.scale.x,  # scale.x = scale.y（等比缩放）
		"depth_y": 0.0,
		"depth_brightness": brightness,
		"depth_z": z,
	}


## 降级参数（Marker2D 缺失时的兜底，视口绝对坐标 180×320）
func _fallback_visuals(slot_index: int, distance: int) -> Dictionary:
	var x_centers: Array[float] = [90.0, 55.0, 125.0]  # 中/左/右
	var x: float = x_centers[clampi(slot_index, 0, 2)]
	if distance == 1:
		return {"position": Vector2(x, 195), "depth_scale": 2.0, "depth_y": 0.0, "depth_brightness": 1.0, "depth_z": 7}
	else:
		return {"position": Vector2(x, 140), "depth_scale": 1.0, "depth_y": 0.0, "depth_brightness": 0.88, "depth_z": 5}


## 隐藏所有编辑器预览精灵（运行时调用）
func hide_preview_sprites() -> void:
	for i: int in 3:
		for d: int in [1, 2]:
			var marker_name: String = "Slot%d_Dist%d" % [i, d]
			var marker: Marker2D = get_node_or_null(marker_name) as Marker2D
			if marker == null:
				continue
			var preview: Sprite2D = marker.get_node_or_null("Preview") as Sprite2D
			if preview != null:
				preview.visible = false


## 场景进入时的可选动画（子类可覆写）
func play_enter_anim() -> void:
	hide_preview_sprites()


## 场景退出时的可选动画（子类可覆写）
func play_exit_anim() -> void:
	pass
