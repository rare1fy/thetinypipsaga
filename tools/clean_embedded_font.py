"""
清理 battle_scene.tscn 中的内嵌字体污染。

问题：
- HpLabel 上误用了"New FontFile → Embed Data"
- 导致 168MB 的字体二进制 + 109 张字形位图被内嵌进 .tscn

修复：
1. 把 HpLabel 上的 theme_override_fonts/font 从 SubResource("FontFile_2v3j5")
   改为引用已存在的 ExtResource("3_t4vxl") （res://fonts/fusion-pixel-12px-monospaced-latin.woff2）
2. 删除第 36~4766 行之间的所有污染子资源（109 张 Image + 1 个内嵌 FontFile）

安全性：
- 先备份原文件为 .tscn.bak
- 逐行流式处理，避免一次性载入 168MB 到内存
"""
from __future__ import annotations

import shutil
from pathlib import Path

TSCN_PATH = Path(r"C:\Users\slimboiliu\TheTiny-PipSaga\gameplay\battle\battle_scene.tscn")
BACKUP_PATH = TSCN_PATH.with_suffix(".tscn.bak")

# 污染范围（1-based line 号）
DIRTY_START = 36        # 第一个 [sub_resource type="Image" ...]
DIRTY_END_EXCLUSIVE = 4767  # 第一个正常 [sub_resource type="StyleBoxFlat" id="StyleBoxFlat_c466e"]


def main() -> None:
    assert TSCN_PATH.exists(), f"场景文件不存在: {TSCN_PATH}"

    original_size = TSCN_PATH.stat().st_size
    print(f"原文件大小: {original_size / 1024 / 1024:.2f} MB")

    # 备份
    if not BACKUP_PATH.exists():
        print(f"备份到: {BACKUP_PATH}")
        shutil.copy2(TSCN_PATH, BACKUP_PATH)
    else:
        print(f"备份已存在，跳过: {BACKUP_PATH}")

    # 流式读 + 流式写
    tmp_path = TSCN_PATH.with_suffix(".tscn.tmp")
    replaced_ref = False
    dropped_lines = 0
    kept_lines = 0

    with BACKUP_PATH.open("r", encoding="utf-8", errors="replace") as fin, \
         tmp_path.open("w", encoding="utf-8", newline="\n") as fout:
        for idx, line in enumerate(fin, start=1):
            # 删除污染段
            if DIRTY_START <= idx < DIRTY_END_EXCLUSIVE:
                dropped_lines += 1
                continue

            # 替换 HpLabel 的字体引用
            if 'theme_override_fonts/font = SubResource("FontFile_2v3j5")' in line:
                line = line.replace(
                    'SubResource("FontFile_2v3j5")',
                    'ExtResource("3_t4vxl")',
                )
                replaced_ref = True

            fout.write(line)
            kept_lines += 1

    # 原子替换
    TSCN_PATH.unlink()
    tmp_path.rename(TSCN_PATH)

    new_size = TSCN_PATH.stat().st_size
    print(f"新文件大小: {new_size / 1024:.2f} KB ({new_size / 1024 / 1024:.4f} MB)")
    print(f"删除行数:   {dropped_lines}")
    print(f"保留行数:   {kept_lines}")
    print(f"字体引用已替换: {replaced_ref}")
    print(f"\n压缩比: {original_size / max(new_size, 1):.1f}x")
    print(f"\n原文件已备份为: {BACKUP_PATH}")
    print("如需回滚: 删除 .tscn 后把 .tscn.bak 改名回 .tscn")


if __name__ == "__main__":
    main()
