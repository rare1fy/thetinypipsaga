"""Batch replace ALL remaining emoji with ASCII text across the project."""
import os, sys
sys.stdout.reconfigure(encoding='utf-8')

project = r'C:\Users\slimboiliu\TheTiny-PipSaga'

# Comprehensive emoji -> ASCII mapping
REPLACEMENTS = {
    # Common UI icons
    '⚙': '[S]',
    '📖': '[B]',
    '🏺': '[R]',
    '💎': '[G]',
    '⚡': '!',
    '⚔': 'X',
    '💀': 'D',
    '👑': '*',
    '🔥': 'F',
    '🛒': '$',
    '❓': '?',
    '💰': 'G',
    '❤️': 'H',
    '❤': 'H',
    '🛍️': '$',
    '🔄': 'R',
    '☠': 'P',
    '✦': '+',
    '✕': 'x',
    '✓': 'v',
    '★': '*',
    '✨': '*',
    '💫': '*',
    '🐑': 'S',
    '👁': 'E',
    '🔒': 'L',
    '🩸': 'B',
    '💢': '!',
    '🗡': 'C',
    '💨': '~',
    '💔': 'V',
    '💪': 'S',
    '📉': 'W',
    '🌀': '@',
    '❄': 'I',
    '🔗': '-',
    '🎯': '>',
    '✚': '+',
    '⚠️': '!',
    '⚠': '!',
    '⚔️': 'X',
    '🌪': 'W',
    '📜': '[L]',
    '📊': '[T]',
    '👹': '[M]',
    '🏳': '[Q]',
    '🔧': '[D]',
    '📏': '#',
    '🎵': '[M]',
    '🔊': '[V]',
    '⚪': 'o',
    '🔵': 'o',
    '🟣': 'o',
    '🟠': 'o',
    '✅': 'OK',
}

skip_dirs = {'.godot', '.git', 'addons', 'build'}
extensions = ('.gd', '.tscn')
count = 0

for root, dirs, files in os.walk(project):
    dirs[:] = [d for d in dirs if d not in skip_dirs]
    for fname in files:
        if not fname.endswith(extensions):
            continue
        fpath = os.path.join(root, fname)
        with open(fpath, 'r', encoding='utf-8') as f:
            content = f.read()
        
        original = content
        for emoji, replacement in REPLACEMENTS.items():
            content = content.replace(emoji, replacement)
        
        if content != original:
            with open(fpath, 'w', encoding='utf-8') as f:
                f.write(content)
            count += 1
            print(f'  Updated: {os.path.relpath(fpath, project)}')

print(f'\nDone! Updated {count} files.')
