## build_theme.gd — 像素地牢 Theme 构建器
##
## 【编辑器友好方式】
## 刘叔在 Godot 编辑器里想重新烘焙主题时：
##   File → Run EditorScript → 选 res://tools/run_build_theme.gd
## 或直接在 FileSystem 右键 run_build_theme.gd → Run
##
## 产物：res://data/dungeon_theme.tres
##
## 设计语言：
##   - 配色取自 PixelTheme（common/theme.gd 中的 CSS 变量移植）
##   - 按钮用 theme_type_variation："PrimaryButton / DangerButton / GoldButton / PurpleButton / GhostButton"
##   - 面板用 theme_type_variation："PixelPanel / PixelPanelDark / TooltipPanel"
##   - ProgressBar（血条）用 theme_type_variation："HpBar / HpBarDanger / ArmorBar"
##   - 文字变体："TitleLabel / BodyLabel / DimLabel / DigitLabel"
##
## 美术后续接入：
##   - 想把按钮换贴图 → .tres 里把 StyleBoxFlat 换成 StyleBoxTexture 即可
##   - 想改色 → 改本脚本常量再重新 Run
@tool
class_name DungeonThemeBuilder
extends RefCounted

const OUT_PATH := "res://data/dungeon_theme.tres"
const BODY_FONT_PATH := "res://fonts/fusion-pixel-12px-monospaced-zh_hans.woff2"
const TITLE_FONT_PATH := "res://fonts/AaWeiWeiDianZhenTi-2.ttf"

# ======== 像素地牢基调色 ========
const C_PANEL := Color("#1a1714")
const C_PANEL_BORDER := Color("#2e2820")
const C_PANEL_DARK_BG := Color("#0f0d0a")
const C_TEXT := Color("#b8c4cc")
const C_TEXT_DIM := Color("#5a6e7e")
const C_TEXT_BRIGHT := Color("#e0e8f0")

# ======== 按钮配色 ========
const BTN_PRIMARY := {
	"bg": Color("#18803a"), "border": Color("#0a3014"), "text": Color("#c8ffd0"),
	"hover": Color("#22a050"), "pressed": Color("#0c4418"),
}
const BTN_DANGER := {
	"bg": Color("#a02820"), "border": Color("#2a0808"), "text": Color("#ffc8c0"),
	"hover": Color("#d04838"), "pressed": Color("#601008"),
}
const BTN_GOLD := {
	"bg": Color("#907020"), "border": Color("#2a2008"), "text": Color("#fff0c0"),
	"hover": Color("#c8a040"), "pressed": Color("#604008"),
}
const BTN_PURPLE := {
	"bg": Color("#5a2080"), "border": Color("#1a0820"), "text": Color("#e8c8ff"),
	"hover": Color("#7a30c0"), "pressed": Color("#3a1050"),
}
const BTN_GHOST := {
	"bg": Color("#1a1a2e"), "border": Color("#2a2a40"), "text": Color("#8090a0"),
	"hover": Color("#282840"), "pressed": Color("#0e0e1a"),
}

# ======== 血条/护甲条配色 ========
const HP_FILL := Color("#3ec060")
const HP_FILL_DANGER := Color("#d44a2a")
const ARMOR_FILL := Color("#6ca0d0")

const CORNER := 2
const BORDER := 2


## 主入口 —— 构建并保存 dungeon_theme.tres
static func build_and_save() -> int:
	var theme := build()
	var err := ResourceSaver.save(theme, OUT_PATH)
	if err != OK:
		push_error("[build_theme] 保存失败 err=%s -> %s" % [err, OUT_PATH])
	else:
		print("[build_theme] Theme 构建完成：%s" % OUT_PATH)
	return err


## 构建 Theme 但不保存（方便单元测试）
static func build() -> Theme:
	var theme := Theme.new()
	var body_font: Font = load(BODY_FONT_PATH)
	var title_font: Font = load(TITLE_FONT_PATH)
	if body_font == null:
		push_warning("[build_theme] 正文字体未找到：%s" % BODY_FONT_PATH)

	theme.default_font = body_font
	theme.default_font_size = 14

	# 全局 Label 文字色
	theme.set_color("font_color", "Label", C_TEXT)
	theme.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.75))
	theme.set_constant("outline_size", "Label", 2)

	# 字体变体
	if title_font:
		_reg_font_v(theme, &"TitleLabel", "Label", title_font, 28, C_TEXT_BRIGHT)
	_reg_font_v(theme, &"BodyLabel", "Label", body_font, 14, C_TEXT)
	_reg_font_v(theme, &"DimLabel", "Label", body_font, 13, C_TEXT_DIM)
	_reg_font_v(theme, &"DigitLabel", "Label", body_font, 24, C_TEXT_BRIGHT)

	# 默认 Button 走 ghost 风格（没挂变体也不会太丑）
	_apply_btn(theme, "Button", BTN_GHOST)

	# 按钮变体
	_reg_btn(theme, &"PrimaryButton", BTN_PRIMARY)
	_reg_btn(theme, &"DangerButton", BTN_DANGER)
	_reg_btn(theme, &"GoldButton", BTN_GOLD)
	_reg_btn(theme, &"PurpleButton", BTN_PURPLE)
	_reg_btn(theme, &"GhostButton", BTN_GHOST)

	# 面板变体
	_reg_panel(theme, &"PixelPanel", C_PANEL, C_PANEL_BORDER, 3)
	_reg_panel(theme, &"PixelPanelDark", C_PANEL_DARK_BG, C_PANEL_BORDER, 3)
	_reg_panel(theme, &"TooltipPanel", Color("#161410"), C_TEXT_DIM, 2)

	# 进度条变体
	_reg_pb(theme, &"HpBar", Color("#000000"), HP_FILL, Color("#3a0a0a"))
	_reg_pb(theme, &"HpBarDanger", Color("#000000"), HP_FILL_DANGER, Color("#3a0a0a"))
	_reg_pb(theme, &"ArmorBar", Color("#000000"), ARMOR_FILL, Color("#0a1a3a"))

	return theme


# ================================================================
# Helpers
# ================================================================

static func _make_btn(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(BORDER)
	sb.set_corner_radius_all(CORNER)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 2
	sb.shadow_offset = Vector2(0, 2)
	return sb


static func _apply_btn(t: Theme, node_type: String, cfg: Dictionary) -> void:
	t.set_stylebox("normal", node_type, _make_btn(cfg.bg, cfg.border))
	t.set_stylebox("hover", node_type, _make_btn(cfg.hover, cfg.border))
	t.set_stylebox("pressed", node_type, _make_btn(cfg.pressed, cfg.border))
	var dis := _make_btn(cfg.bg.darkened(0.4), cfg.border.darkened(0.3))
	dis.bg_color.a = 0.5
	t.set_stylebox("disabled", node_type, dis)
	var focus := _make_btn(cfg.bg, C_TEXT_BRIGHT)
	focus.border_color = C_TEXT_BRIGHT
	t.set_stylebox("focus", node_type, focus)
	t.set_color("font_color", node_type, cfg.text)
	t.set_color("font_hover_color", node_type, cfg.text)
	t.set_color("font_pressed_color", node_type, cfg.text)
	t.set_color("font_disabled_color", node_type, Color(cfg.text.r, cfg.text.g, cfg.text.b, 0.4))
	t.set_color("font_outline_color", node_type, Color(0, 0, 0, 0.9))
	t.set_constant("outline_size", node_type, 2)


static func _reg_btn(t: Theme, v: StringName, cfg: Dictionary) -> void:
	t.set_type_variation(v, "Button")
	_apply_btn(t, v, cfg)


static func _reg_panel(t: Theme, v: StringName, bg: Color, border: Color, margin: int) -> void:
	t.set_type_variation(v, "PanelContainer")
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(BORDER)
	sb.set_corner_radius_all(CORNER)
	sb.content_margin_left = margin * 4
	sb.content_margin_right = margin * 4
	sb.content_margin_top = margin * 3
	sb.content_margin_bottom = margin * 3
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 3
	sb.shadow_offset = Vector2(0, 3)
	t.set_stylebox("panel", v, sb)


static func _reg_pb(t: Theme, v: StringName, bg: Color, fill: Color, bg_border: Color) -> void:
	t.set_type_variation(v, "ProgressBar")
	var sbbg := StyleBoxFlat.new()
	sbbg.bg_color = bg
	sbbg.border_color = bg_border
	sbbg.set_border_width_all(2)
	sbbg.set_corner_radius_all(2)
	t.set_stylebox("background", v, sbbg)
	var sbf := StyleBoxFlat.new()
	sbf.bg_color = fill
	sbf.set_corner_radius_all(1)
	t.set_stylebox("fill", v, sbf)
	t.set_color("font_color", v, C_TEXT_BRIGHT)
	t.set_color("font_outline_color", v, Color(0, 0, 0, 0.9))
	t.set_constant("outline_size", v, 2)


static func _reg_font_v(t: Theme, v: StringName, base: String, font: Font, size: int, color: Color) -> void:
	t.set_type_variation(v, base)
	if font:
		t.set_font("font", v, font)
	t.set_font_size("font_size", v, size)
	t.set_color("font_color", v, color)
	t.set_color("font_outline_color", v, Color(0, 0, 0, 0.75))
	t.set_constant("outline_size", v, 2)
