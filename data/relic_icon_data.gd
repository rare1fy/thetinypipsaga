## 遗物像素图标数据 — 从原版 relicPixelData.ts 移植
## 每个遗物 7x7 像素网格

class_name RelicIconData

const _ := ""
const G = "#a0a0b0"; const W = "#e8e8f0"; const D = "#606070"
const Rd_c = "#e04040"; const Rd_d = "#a03030"; const O = "#e07830"; const Od = "#b06020"
const Y = "#e8d068"; const Yd = "#c8a83c"; const Gr = "#40c060"
const B = "#4080e0"; const Bd = "#3060a0"; const P = "#a040d0"; const Pd = "#7030a0"
const C = "#40d0d0"; const Cd = "#2898a0"

static func get_all() -> Dictionary:
	return {
		"grindstone": [
			[_,_,_,_,_,Y,_],
			[_,_,_,_,Y,_,_],
			[_,D,D,D,D,D,_],
			[D,G,G,G,G,G,D],
			[D,W,W,W,W,W,D],
			[D,G,G,G,G,G,D],
			[_,D,D,D,D,D,_],
		],
		"iron_banner": [
			[_,G,Rd_c,Rd_c,Rd_c,Rd_c,_],
			[_,G,Rd_c,W,Rd_c,Rd_c,Rd_d,_],
			[_,G,Rd_c,Rd_c,Rd_c,Rd_d,Rd_d,_],
			[_,G,Rd_c,Rd_c,Rd_d,Rd_d,_,_],
			[_,G,_,_,_,_,_],
			[_,G,_,_,_,_,_],
			[_,D,_,_,_,_,_],
		],
		"crimson_grail": [
			[_,Rd_c,_,_,_,Rd_c,_],
			[_,Rd_c,Rd_c,Rd_c,Rd_c,Rd_c,_],
			[_,_,Rd_c,Rd_d,Rd_c,_,_],
			[_,_,Rd_c,Rd_d,Rd_c,_,_],
			[_,_,_,D,_,_,_],
			[_,_,D,D,D,_,_],
			[_,D,D,D,D,D,_],
		],
		"mirror_prism": [
			[_,_,_,C,_,_,_],
			[_,_,C,W,C,_,_],
			[_,C,W,C,W,C,_],
			[C,W,C,_,C,W,C],
			[_,C,W,C,W,C,_],
			[_,_,C,W,C,_,_],
			[_,_,_,C,_,_,_],
		],
		"glass_cannon": [
			[_,_,_,_,Rd_c,O,_],
			[_,G,G,G,D,Rd_c,_],
			[G,W,W,G,G,D,_],
			[G,W,G,G,G,D,_],
			[G,G,G,G,G,D,_],
			[_,G,G,G,D,_,_],
			[_,D,_,_,D,_,_],
		],
		"vampire_fangs": [
			[_,_,_,_,_,_,_],
			[_,W,_,_,_,W,_],
			[_,W,_,_,_,W,_],
			[_,G,_,_,_,G,_],
			[_,G,_,_,_,G,_],
			[_,_,Rd_c,_,Rd_c,_,_],
			[_,_,_,Rd_c,_,_,_],
		],
		"emergency_hourglass": [
			[D,D,D,D,D,D,D],
			[_,Y,Y,Y,Y,Y,_],
			[_,_,Y,Y,Y,_,_],
			[_,_,_,Y,_,_,_],
			[_,_,Od,Od,Od,_,_],
			[_,Od,Od,Od,Od,Od,_],
			[D,D,D,D,D,D,D],
		],
		"combo_master": [
			[_,_,_,_,W,W,_],
			[_,_,_,W,W,W,_],
			[O,_,W,W,W,_,_],
			[O,O,W,W,_,_,_],
			[_,O,O,_,_,_,_],
			[_,_,O,O,_,_,_],
			[_,_,_,O,O,_,_],
		],
		"healing_breeze": [
			[_,_,_,_,Gr,Gr,_],
			[_,Gr,Gr,Gr,_,_,_],
			[Gr,_,_,_,Gr,_,_],
			[_,_,Gr,Gr,_,_,_],
			[_,Gr,_,_,Gr,Gr,_],
			[Gr,_,_,_,_,_,Gr],
			[_,Gr,Gr,Gr,Gr,Gr,_],
		],
		"lucky_coin": [
			[_,_,Y,Y,Y,_,_],
			[_,Y,Yd,Yd,Yd,Y,_],
			[Y,Yd,Y,Y,Y,Yd,Y],
			[Y,Yd,Y,Yd,Y,Yd,Y],
			[Y,Yd,Y,Y,Y,Yd,Y],
			[_,Y,Yd,Yd,Yd,Y,_],
			[_,_,Y,Y,Y,_,_],
		],
		"blood_dice": [
			[Rd_c,Rd_c,Rd_c,Rd_c,Rd_c,Rd_c,Rd_c],
			[Rd_c,W,_,_,_,_,Rd_c],
			[Rd_c,_,_,_,_,_,Rd_c],
			[Rd_c,_,_,W,_,_,Rd_c],
			[Rd_c,_,_,_,_,_,Rd_c],
			[Rd_c,_,_,_,_,W,Rd_c],
			[Rd_c,Rd_c,Rd_c,Rd_c,Rd_c,Rd_c,Rd_c],
		],
		"dice_master": [
			[_,Y,_,Y,_,Y,_],
			[_,Y,Y,Y,Y,Y,_],
			[W,W,W,W,W,W,W],
			[W,G,_,_,_,G,W],
			[W,_,_,G,_,_,W],
			[W,G,_,_,_,G,W],
			[W,W,W,W,W,W,W],
		],
		"fortune_wheel": [
			[_,_,Y,Y,Y,_,_],
			[_,Y,_,_,_,Y,_],
			[Y,_,Rd_c,_,B,_,Y],
			[Y,_,_,W,_,_,Y],
			[Y,_,Gr,_,P,_,Y],
			[_,Y,_,_,_,Y,_],
			[_,_,Y,Y,Y,_,_],
		],
		"battle_medic": [
			[_,_,Rd_c,Rd_c,Rd_c,_,_],
			[_,_,Rd_c,W,Rd_c,_,_],
			[Rd_c,Rd_c,Rd_c,W,Rd_c,Rd_c,Rd_c],
			[Rd_c,W,W,W,W,W,Rd_c],
			[Rd_c,Rd_c,Rd_c,W,Rd_c,Rd_c,Rd_c],
			[_,_,Rd_c,W,Rd_c,_,_],
			[_,_,Rd_c,Rd_c,Rd_c,_,_],
		],
	}

## 获取遗物图标，未找到则返回默认问号
static func get_icon(relic_id: String) -> Array:
	var all := get_all()
	if all.has(relic_id):
		return all[relic_id]
	# 默认问号图标
	return [
		[_,_,G,G,G,_,_],
		[_,G,_,_,_,G,_],
		[_,_,_,_,G,_,_],
		[_,_,_,G,_,_,_],
		[_,_,_,G,_,_,_],
		[_,_,_,_,_,_,_],
		[_,_,_,G,_,_,_],
	]
