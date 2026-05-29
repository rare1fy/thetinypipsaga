"""
将 tscn 文件中的 UI 坐标值 ×2，适配 viewport 从 180×320 改为 360×640。
只处理 offset、position(Vector2)、custom_minimum_size、pivot_offset。
不处理：anchor(0-1)、font_size、scale、separation、outline_size。
"""
import re
import os

root = r"C:\Users\slimboiliu\TheTiny-PipSaga"
files_to_process = [
    os.path.join(root, "gameplay", "start", "start_screen.tscn"),
    os.path.join(root, "entities", "dice_button", "dice_button.tscn"),
    os.path.join(root, "entities", "dice_tooltip", "dice_tooltip.tscn"),
    os.path.join(root, "entities", "enemy", "enemy_view.tscn"),
    os.path.join(root, "gameplay", "campfire", "campfire_screen.tscn"),
    os.path.join(root, "gameplay", "chapter_transition", "chapter_transition.tscn"),
    os.path.join(root, "gameplay", "class_select", "class_select.tscn"),
    os.path.join(root, "gameplay", "event", "event_screen.tscn"),
    os.path.join(root, "gameplay", "map", "map_screen.tscn"),
    os.path.join(root, "gameplay", "merchant", "merchant_screen.tscn"),
    os.path.join(root, "gameplay", "skill_select", "skill_select_screen.tscn"),
    os.path.join(root, "gameplay", "treasure", "treasure_screen.tscn"),
    os.path.join(root, "ui", "dice_reward", "dice_reward_screen.tscn"),
    os.path.join(root, "ui", "game_over", "game_over_screen.tscn"),
    os.path.join(root, "ui", "loot", "loot_screen.tscn"),
    os.path.join(root, "ui", "victory", "victory_screen.tscn"),
]

offset_pattern = re.compile(r"^(offset_(?:left|right|top|bottom)\s*=\s*)(-?\d+\.?\d*)")
vector2_pattern = re.compile(r"^((?:position|custom_minimum_size|size|pivot_offset)\s*=\s*Vector2\()([^)]+)\)")


def double_offset(match):
    prefix = match.group(1)
    val = float(match.group(2))
    new_val = val * 2
    if new_val == int(new_val):
        return f"{prefix}{int(new_val)}.0"
    return f"{prefix}{new_val}"


def double_vector2(match):
    prefix = match.group(1)
    parts = match.group(2).split(",")
    new_parts = []
    for p in parts:
        v = float(p.strip())
        nv = v * 2
        if nv == int(nv):
            new_parts.append(str(int(nv)))
        else:
            new_parts.append(str(nv))
    return prefix + ", ".join(new_parts) + ")"


total_changes = 0
for fpath in files_to_process:
    if not os.path.exists(fpath):
        print(f"SKIP (not found): {fpath}")
        continue
    with open(fpath, "r", encoding="utf-8") as f:
        lines = f.readlines()
    new_lines = []
    changes = 0
    for line in lines:
        original = line
        # Skip lines we don't want to modify
        if "font_size" in line or "anchor_" in line or "scale" in line:
            new_lines.append(line)
            continue
        if "separation" in line or "outline_size" in line:
            new_lines.append(line)
            continue
        # Double offsets
        line = offset_pattern.sub(double_offset, line)
        # Double Vector2 values
        line = vector2_pattern.sub(double_vector2, line)
        if line != original:
            changes += 1
        new_lines.append(line)
    if changes > 0:
        with open(fpath, "w", encoding="utf-8") as f:
            f.writelines(new_lines)
        total_changes += changes
        print(f"{os.path.basename(fpath)}: {changes} changes")

print(f"\nTotal: {total_changes} changes")
