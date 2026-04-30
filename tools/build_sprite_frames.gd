@tool
extends EditorScript

## 批量生成 SpriteFrames 资源工具（一次性编辑器脚本）
##
## 用法：
##   1. 在 Godot 编辑器里打开本文件
##   2. 顶部菜单 File → Run（或 Ctrl+Shift+X）
##   3. 控制台会打印每个角色的生成进度
##
## 规则：
##   - 扫 res://assets/characters/mobs/*/ 每个子目录作为一个角色
##   - 文件名格式 {角色名}-{动作名}_{帧号}.png
##   - 为每个角色生成 sprite_frames.tres（SpriteFrames 资源）
##   - 每个动作 fps=12, 循环播放（death 不循环）
##
## 美术替换：后续再加角色，把素材拖到 mobs/xxx/ 下重跑这个脚本即可。

const MOBS_ROOT := "res://assets/characters/mobs"
const DEFAULT_FPS := 12.0
const NON_LOOP_ACTIONS := ["death", "born", "vertigo"]

func _run() -> void:
	print("[BuildSpriteFrames] 开始扫描 %s" % MOBS_ROOT)
	var dir := DirAccess.open(MOBS_ROOT)
	if dir == null:
		push_error("[BuildSpriteFrames] 无法打开目录 %s" % MOBS_ROOT)
		return

	var char_count := 0
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name != "." and name != ".." and dir.current_is_dir():
			var ok := _build_character(name)
			if ok:
				char_count += 1
		name = dir.get_next()
	dir.list_dir_end()

	print("[BuildSpriteFrames] 完成，共生成 %d 个角色资源" % char_count)

func _build_character(char_name: String) -> bool:
	var char_dir := "%s/%s" % [MOBS_ROOT, char_name]
	var d := DirAccess.open(char_dir)
	if d == null:
		push_error("无法打开 %s" % char_dir)
		return false

	# 扫 png 按 action 分组
	var action_frames: Dictionary = {}  # action -> Array[Dict{frame:int, path:String}]
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		if f.ends_with(".png") and not f.begins_with("."):
			var parsed := _parse_filename(char_name, f)
			if not parsed.is_empty():
				var action: String = parsed.action
				if not action_frames.has(action):
					action_frames[action] = []
				action_frames[action].append({
					"frame": parsed.frame,
					"path": "%s/%s" % [char_dir, f]
				})
		f = d.get_next()
	d.list_dir_end()

	if action_frames.is_empty():
		push_warning("[%s] 无可识别的帧文件，跳过" % char_name)
		return false

	# 生成 SpriteFrames
	var sf := SpriteFrames.new()
	# 默认动画名"default"必须存在，Godot 要求
	# 我们用第一个动作当作 default 的占位
	sf.remove_animation("default")

	var actions_sorted: Array = action_frames.keys()
	actions_sorted.sort()

	for action: String in actions_sorted:
		sf.add_animation(action)
		sf.set_animation_speed(action, DEFAULT_FPS)
		sf.set_animation_loop(action, not NON_LOOP_ACTIONS.has(action))
		var frames: Array = action_frames[action]
		frames.sort_custom(func(a, b): return a.frame < b.frame)
		for entry: Dictionary in frames:
			var tex: Texture2D = load(entry.path)
			if tex == null:
				push_warning("[%s] 加载失败 %s" % [char_name, entry.path])
				continue
			sf.add_frame(action, tex)

	# 把 idle 作为 default animation（若存在）
	if sf.has_animation("idle"):
		# 不重命名 idle，代码侧用 play("idle")
		pass

	var out_path := "%s/sprite_frames.tres" % char_dir
	var err := ResourceSaver.save(sf, out_path)
	if err != OK:
		push_error("[%s] 保存失败 err=%d" % [char_name, err])
		return false

	var summary: Array[String] = []
	for a: String in actions_sorted:
		summary.append("%s(%d)" % [a, (action_frames[a] as Array).size()])
	print("[%s] OK → %s | actions: %s" % [char_name, out_path, ", ".join(summary)])
	return true

## 文件名解析：m10001-idle_00.png → {action:"idle", frame:0}
func _parse_filename(char_name: String, filename: String) -> Dictionary:
	var prefix := "%s-" % char_name
	if not filename.begins_with(prefix):
		return {}
	var tail := filename.trim_prefix(prefix).trim_suffix(".png")
	var idx := tail.rfind("_")
	if idx <= 0:
		return {}
	var action := tail.substr(0, idx)
	var frame_str := tail.substr(idx + 1)
	if not frame_str.is_valid_int():
		return {}
	return {
		"action": action,
		"frame": frame_str.to_int()
	}
