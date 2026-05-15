@tool
## run_build_theme.gd — 编辑器一键烘焙入口
##
## 用法：
##   Godot 编辑器 → FileSystem → 右键此文件 → Run
##   或 File → Run EditorScript → 选择本文件
##
## 它会调用 DungeonThemeBuilder.build_and_save() 重新生成 data/dungeon_theme.tres
extends EditorScript


func _run() -> void:
	var err := DungeonThemeBuilder.build_and_save()
	if err == OK:
		print("[run_build_theme] ✅ dungeon_theme.tres 已重新生成")
		# 自动刷新 FileSystem，避免编辑器缓存
		EditorInterface.get_resource_filesystem().scan()
	else:
		push_error("[run_build_theme] 生成失败 err=%d" % err)
