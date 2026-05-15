"""
像素矩阵 TS → JSON 解析器
作用：把 dicehero2 的 pixelIconData.ts / relicPixelData.ts 解析为 Godot 可读的 JSON
运行：python pixel_ts_parser.py
输出：tools/pixel_raw/icons.json + relics.json
"""
from __future__ import annotations
import json
import os
import re
import sys

SOURCE_DIR = r'F:\UGit\dicehero2\src\data'
OUTPUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'pixel_raw')


def parse_matrix_text(text: str) -> list[list[str]]:
    """解析形如 [ [ '', '#fff' ], [ '#aaa', '' ] ] 的矩阵文本, 返回二维列表"""
    # 提取每一行 [ ... ]（行内不能再有 [] 嵌套）
    row_pattern = re.compile(r'\[([^\[\]]*)\]')
    cell_pattern = re.compile(r"'([^']*)'")
    rows: list[list[str]] = []
    for row_match in row_pattern.finditer(text):
        row_inner = row_match.group(1)
        cells = cell_pattern.findall(row_inner)
        if cells:
            rows.append(cells)
    return rows


def parse_pixel_icon_data(file_path: str) -> dict[str, list[list[str]]]:
    """解析 pixelIconData.ts - export const NAME: readonly ... = [ ... ] as const;"""
    with open(file_path, 'r', encoding='utf-8') as f:
        text = f.read()

    # 抓每一条 export const
    pattern = re.compile(
        r'export\s+const\s+(\w+)\s*:\s*readonly[^=]*=\s*(\[[\s\S]*?\])\s*as\s+const\s*;',
        re.MULTILINE,
    )
    result: dict[str, list[list[str]]] = {}
    for m in pattern.finditer(text):
        name = m.group(1)
        arr_text = m.group(2)
        matrix = parse_matrix_text(arr_text)
        if matrix:
            result[name] = matrix
            print(f'  [ICON] {name:20s} {len(matrix[0])}x{len(matrix)}')
    return result


def parse_relic_pixel_data(file_path: str) -> dict[str, list[list[str]]]:
    """解析 relicPixelData.ts - 先做别名替换，再抓 const NAME: string[][] = [ ... ]"""
    with open(file_path, 'r', encoding='utf-8') as f:
        source = f.read()

    # 1) 抽出色板别名 const G = '#a0a0b0';
    alias_pattern = re.compile(r"const\s+(\w+)\s*=\s*'([^']*)'\s*;")
    alias_map = {m.group(1): m.group(2) for m in alias_pattern.finditer(source)}
    print(f'  色板别名数量: {len(alias_map)}')

    # 2) 全文替换：只在矩阵段内（即被 [ , ] 包夹时）把别名替换为 '#xxx'
    # 长的别名优先，避免短别名抢先
    sorted_aliases = sorted(alias_map.keys(), key=len, reverse=True)
    working = source
    for alias in sorted_aliases:
        hex_val = alias_map[alias]
        replacement = f"'{hex_val}'"
        # 别名必须前后被分隔（逗号/空格/方括号等），且不是 'xxx' 字符串里的内容
        pattern = re.compile(
            r'(?<=[\[\s,])' + re.escape(alias) + r'(?=[\s,\]])'
        )
        working = pattern.sub(replacement, working)

    # 3) 抓 const NAME: string[][] = [ 矩阵 ];
    matrix_pattern = re.compile(
        r'const\s+(\w+)\s*:\s*string\[\]\[\]\s*=\s*(\[[\s\S]*?\])\s*;',
        re.MULTILINE,
    )
    result: dict[str, list[list[str]]] = {}
    for m in matrix_pattern.finditer(working):
        name = m.group(1)
        arr_text = m.group(2)
        matrix = parse_matrix_text(arr_text)
        if matrix:
            result[name] = matrix
            print(f'  [RELIC] {name:30s} {len(matrix[0])}x{len(matrix)}')
    return result


def main() -> int:
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    print('========== 解析 pixelIconData.ts ==========')
    icons_path = os.path.join(SOURCE_DIR, 'pixelIconData.ts')
    icons_map = parse_pixel_icon_data(icons_path)
    print(f'总计解析图标: {len(icons_map)}')

    icons_json_path = os.path.join(OUTPUT_DIR, 'icons.json')
    with open(icons_json_path, 'w', encoding='utf-8') as f:
        json.dump(icons_map, f, ensure_ascii=False, separators=(',', ':'))
    print(f'已写出: {icons_json_path}')

    print()
    print('========== 解析 relicPixelData.ts ==========')
    relics_path = os.path.join(SOURCE_DIR, 'relicPixelData.ts')
    relics_map = parse_relic_pixel_data(relics_path)
    print(f'总计解析遗物: {len(relics_map)}')

    relics_json_path = os.path.join(OUTPUT_DIR, 'relics.json')
    with open(relics_json_path, 'w', encoding='utf-8') as f:
        json.dump(relics_map, f, ensure_ascii=False, separators=(',', ':'))
    print(f'已写出: {relics_json_path}')

    print()
    print('[DONE] 全部解析完成')
    return 0


if __name__ == '__main__':
    sys.exit(main())
