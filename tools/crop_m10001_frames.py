"""
m10001 美术资源批量裁剪脚本

原因：原图 719x325 是为了入场走位动画预留的空白画布，角色实际只在右下小块区域。
      这导致 Godot AnimatedSprite2D centered=true 时视觉中心严重偏离画布中心。

策略：扫全部 44 帧求并集 bbox，按统一矩形裁剪所有帧 → 保证帧间无错位。

安全措施：
1. 自动备份原图到 backup_720x325/ 子目录
2. dry-run 模式可以只打印不执行
3. 裁剪后验证所有帧尺寸一致
"""

from PIL import Image
import os
import glob
import shutil
import sys

SRC_DIR = r"C:\Users\slimboiliu\TheTiny-PipSaga\assets\characters\mobs\m10001"
BACKUP_DIR = os.path.join(SRC_DIR, "backup_719x325")

def main(dry_run: bool = False) -> None:
    png_files = sorted([f for f in glob.glob(os.path.join(SRC_DIR, "*.png"))])
    # 排除可能已经在 backup 目录里的文件
    png_files = [f for f in png_files if "backup" not in f]

    if not png_files:
        print("[ERROR] 没找到 PNG 文件")
        return

    print(f"[INFO] 扫描 {len(png_files)} 张帧...")

    # 求并集 bbox
    lefts, tops, rights, bottoms = [], [], [], []
    for f in png_files:
        with Image.open(f) as img:
            bbox = img.getbbox()
            if bbox is None:
                print(f"[WARN] {os.path.basename(f)} 完全透明，跳过统计")
                continue
            lefts.append(bbox[0])
            tops.append(bbox[1])
            rights.append(bbox[2])
            bottoms.append(bbox[3])

    union_bbox = (min(lefts), min(tops), max(rights), max(bottoms))
    new_w = union_bbox[2] - union_bbox[0]
    new_h = union_bbox[3] - union_bbox[1]

    print(f"[INFO] 并集 bbox: {union_bbox}")
    print(f"[INFO] 裁剪后尺寸: {new_w} x {new_h}")

    if dry_run:
        print("[DRY-RUN] 不执行实际裁剪")
        return

    # 备份
    if not os.path.exists(BACKUP_DIR):
        os.makedirs(BACKUP_DIR)
        print(f"[INFO] 备份到 {BACKUP_DIR}")
        for f in png_files:
            shutil.copy2(f, os.path.join(BACKUP_DIR, os.path.basename(f)))
        print(f"[PASS] 备份完成 {len(png_files)} 张")
    else:
        print(f"[WARN] 备份目录已存在，跳过备份步骤（假定已备份过）")

    # 裁剪
    cropped = 0
    for f in png_files:
        with Image.open(f) as img:
            new_img = img.crop(union_bbox)
            new_img.save(f, optimize=True)
            cropped += 1

    print(f"[PASS] 裁剪完成 {cropped} 张")

    # 验证
    sizes = set()
    for f in png_files:
        with Image.open(f) as img:
            sizes.add(img.size)

    if len(sizes) == 1 and list(sizes)[0] == (new_w, new_h):
        print(f"[PASS] 所有帧尺寸一致: {list(sizes)[0]}")
    else:
        print(f"[ERROR] 帧尺寸不一致: {sizes}")
        sys.exit(1)


if __name__ == "__main__":
    dry_run = "--dry-run" in sys.argv
    main(dry_run=dry_run)
