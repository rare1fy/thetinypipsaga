## click_guard.gd — 全局点击冷却守卫
## 防止快速连点导致重复触发（对齐原版 useGlobalClickCooldown.ts）
## 用法：if ClickGuard.try_click("play"): ... else: return
class_name ClickGuard
extends RefCounted

## 冷却时间（毫秒）
const COOLDOWN_MS: int = 400

## 各按钮的上次点击时间戳（key = 按钮标识字符串）
static var _last_click_map: Dictionary = {}


## 尝试点击：如果冷却期内返回 false（拦截），否则返回 true（放行）
static func try_click(button_id: String) -> bool:
	var now: int = Time.get_ticks_msec()
	var last: int = _last_click_map.get(button_id, 0) as int
	if now - last < COOLDOWN_MS:
		return false
	_last_click_map[button_id] = now
	return true


## 强制重置某个按钮的冷却（用于状态切换后立即允许点击）
static func reset(button_id: String) -> void:
	_last_click_map.erase(button_id)


## 重置所有冷却
static func reset_all() -> void:
	_last_click_map.clear()
