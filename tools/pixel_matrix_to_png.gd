@tool
extends EditorScript
## 像素矩阵 JSON → PNG 批量生成器
## 作用：读 tools/pixel_raw/icons.json 和 relics.json，生成 112 张像素 PNG
## 运行：编辑器 → File → Run，或打开本文件后按 Ctrl+Shift+X
## 产物：
##   res://assets/art/generated/icons/*.png    (46 张 UI 图标)
##   res://assets/art/generated/relics/*.png   (66 张遗物图标)
##
## 源数据来自 dicehero2 项目，由 tools/pixel_ts_parser.py 解析为 JSON


const ICONS_JSON_PATH := "res://tools/pixel_raw/icons.json"
const RELICS_JSON_PATH := "res://tools/pixel_raw/relics.json"
const ICONS_OUTPUT_DIR := "res://assets/art/generated/icons"
const RELICS_OUTPUT_DIR := "res://assets/art/generated/relics"


func _run() -> void:
	print("========== 像素矩阵 → PNG 批量生成器 ==========")

	_ensure_dir(ICONS_OUTPUT_DIR)
	_ensure_dir(RELICS_OUTPUT_DIR)

	var icon_count := _process_group(ICONS_JSON_PATH, ICONS_OUTPUT_DIR, "图标")
	var relic_count := _process_group(RELICS_JSON_PATH, RELICS_OUTPUT_DIR, "遗物")

	print("")
	print("[DONE] 共生成 %d 张 PNG" % (icon_count + relic_count))
	print("  图标: %d 张 → %s" % [icon_count, ICONS_OUTPUT_DIR])
	print("  遗物: %d 张 → %s" % [relic_count, RELICS_OUTPUT_DIR])
	print("")
	print("请在编辑器 FileSystem 面板刷新 (右键 Reimport) 确认新资源已识别")


func _ensure_dir(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		var err := DirAccess.make_dir_recursive_absolute(path)
		if err != OK:
			push_error("无法创建目录: %s (err=%d)" % [path, err])
		else:
			print("  创建目录: %s" % path)


func _process_group(json_path: String, output_dir: String, label: String) -> int:
	print("")
	print("---------- 处理 %s ----------" % label)

	if not FileAccess.file_exists(json_path):
		push_error("JSON 文件不存在: %s" % json_path)
		return 0

	var file := FileAccess.open(json_path, FileAccess.READ)
	if file == null:
		push_error("无法打开 JSON: %s" % json_path)
		return 0

	var text := file.get_as_text()
	file.close()

	var parse_result: Variant = JSON.parse_string(text)
	if typeof(parse_result) != TYPE_DICTIONARY:
		push_error("JSON 解析失败: %s" % json_path)
		return 0

	var data: Dictionary = parse_result
	var success_count := 0
	for name_raw: Variant in data.keys():
		var icon_name := String(name_raw)
		var matrix_variant: Variant = data[icon_name]
		if typeof(matrix_variant) != TYPE_ARRAY:
			push_warning("跳过 %s: 矩阵不是数组" % icon_name)
			continue
		var matrix: Array = matrix_variant

		var file_name := icon_name.to_lower() + ".png"
		var output_path := output_dir.path_join(file_name)

		if _save_matrix_as_png(matrix, output_path):
			success_count += 1

	print("%s 完成: %d 张" % [label, success_count])
	return success_count


func _save_matrix_as_png(matrix: Array, output_path: String) -> bool:
	if matrix.is_empty():
		push_warning("矩阵为空: %s" % output_path)
		return false

	# 计算尺寸（取最大列数，防止不整齐）
	var height := matrix.size()
	var width := 0
	for row_variant: Variant in matrix:
		if typeof(row_variant) == TYPE_ARRAY:
			var row_arr: Array = row_variant
			if row_arr.size() > width:
				width = row_arr.size()

	if width <= 0 or height <= 0:
		push_warning("尺寸无效 %dx%d: %s" % [width, height, output_path])
		return false

	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	# 默认全透明 - Image.create 创建的像素都是 (0,0,0,0)，无需手动清

	for y in height:
		var row_variant: Variant = matrix[y]
		if typeof(row_variant) != TYPE_ARRAY:
			continue
		var row_arr: Array = row_variant
		for x in row_arr.size():
			var cell: String = String(row_arr[x])
			if cell.is_empty():
				continue
			# 把 '#rrggbb' 转 Color；容错处理（非法格式跳过）
			var color := Color.from_string(cell, Color(0, 0, 0, 0))
			if color.a <= 0.001:
				# 色值解析失败时 Color.from_string 返回默认值（透明），跳过
				continue
			image.set_pixel(x, y, color)

	var err := image.save_png(output_path)
	if err != OK:
		push_error("save_png 失败 %s (err=%d)" % [output_path, err])
		return false

	print("  [%dx%d] %s" % [width, height, output_path.get_file()])
	return true
