"""
从 enemy_config.gd 的硬编码 _reg() 调用中提取 85 个敌人数据，
生成符合 config_loader.gd 格式的 enemy.json。

输出结构：
{
  "base": [...],
  "phases": [...],
  "actions": [...],
  "quotes": [...]
}
"""

import re
import json
import os

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(os.path.dirname(SCRIPT_DIR))
INPUT_FILE = os.path.join(PROJECT_ROOT, "data", "enemy_config.gd")
OUTPUT_FILE = os.path.join(PROJECT_ROOT, "config", "json", "enemy.json")


def parse_gd_string_array(text: str) -> list[str]:
    """解析 GDScript 数组字面量中的字符串，如 ["foo", "bar"]"""
    results = []
    # 匹配双引号字符串
    for m in re.finditer(r'"((?:[^"\\]|\\.)*)"', text):
        results.append(m.group(1).replace('\\"', '"'))
    return results


def parse_phase_calls(text: str) -> list[dict]:
    """解析 _phase(...) 调用列表"""
    phases = []
    # 找所有 _phase(threshold, [...])
    phase_pattern = re.compile(r'_phase\(\s*([\d.]+)\s*,\s*\[(.*?)\]\s*\)', re.DOTALL)
    for m in phase_pattern.finditer(text):
        threshold = float(m.group(1))
        actions_text = m.group(2)
        actions = parse_action_calls(actions_text)
        phases.append({
            "hp_threshold": threshold,
            "actions": actions
        })
    return phases


def parse_action_calls(text: str) -> list[dict]:
    """解析 _atk/_def/_skill 调用"""
    actions = []
    # _atk(value) or _atk(value, "desc")
    atk_pattern = re.compile(r'_atk\(\s*(\d+)\s*(?:,\s*"([^"]*)")?\s*\)')
    def_pattern = re.compile(r'_def\(\s*(\d+)\s*\)')
    skill_pattern = re.compile(r'_skill\(\s*(\d+)\s*,\s*"([^"]*)"\s*\)')

    # 按出现顺序收集
    all_matches = []
    for m in atk_pattern.finditer(text):
        all_matches.append((m.start(), "ATTACK", int(m.group(1)), m.group(2) or ""))
    for m in def_pattern.finditer(text):
        all_matches.append((m.start(), "DEFEND", int(m.group(1)), ""))
    for m in skill_pattern.finditer(text):
        all_matches.append((m.start(), "SKILL", int(m.group(1)), m.group(2)))

    all_matches.sort(key=lambda x: x[0])
    for _, atype, value, desc in all_matches:
        action = {"type": atype, "base_value": value, "description": desc, "scalable": atype != "SKILL"}
        actions.append(action)
    return actions


def parse_quotes_call(text: str) -> dict:
    """解析 _q([...], [...], [...], [...], [...]) 调用"""
    # 找5个数组参数
    arrays = []
    depth = 0
    current = ""
    in_array = False
    for ch in text:
        if ch == '[':
            if depth == 0:
                in_array = True
                current = ""
            else:
                current += ch
            depth += 1
        elif ch == ']':
            depth -= 1
            if depth == 0 and in_array:
                arrays.append(parse_gd_string_array(current))
                in_array = False
                current = ""
            else:
                current += ch
        elif in_array:
            current += ch

    events = ["enter", "death", "attack", "hurt", "low_hp"]
    quotes = {}
    for i, event in enumerate(events):
        if i < len(arrays):
            quotes[event] = arrays[i]
        else:
            quotes[event] = []
    return quotes


def parse_reg_calls(content: str) -> list[dict]:
    """解析所有 _reg(...) 调用"""
    enemies = []

    # 找每个 _reg 调用 — 它们可能跨多行
    # 策略：找 _reg( 开头，然后匹配到对应的闭括号
    reg_starts = [m.start() for m in re.finditer(r'\t_reg\(', content)]

    for i, start in enumerate(reg_starts):
        # 找到匹配的闭括号
        depth = 0
        end = start
        found_open = False
        for j in range(start, len(content)):
            if content[j] == '(':
                depth += 1
                found_open = True
            elif content[j] == ')':
                depth -= 1
                if found_open and depth == 0:
                    end = j + 1
                    break

        call_text = content[start:end]

        # 提取参数 — 第一层括号内的内容
        inner_start = call_text.index('(') + 1
        inner_end = len(call_text) - 1
        inner = call_text[inner_start:inner_end]

        # 提取前几个简单参数（id, name, chapter, hp, dmg, category, combat_type, gold）
        # 用正则提取前面的字符串和数字参数
        # id
        id_match = re.search(r'"([^"]+)"', inner)
        if not id_match:
            continue
        enemy_id = id_match.group(1)

        # name (第二个字符串)
        strings = re.findall(r'"([^"]*)"', inner[:200])
        if len(strings) < 2:
            continue
        enemy_name = strings[1]

        # 数字参数：chapter, hp, dmg
        # 在 name 之后找数字
        after_name = inner[inner.index(f'"{enemy_name}"') + len(enemy_name) + 2:]
        numbers = re.findall(r'\b(\d+)\b', after_name[:50])
        if len(numbers) < 3:
            continue
        chapter = int(numbers[0])
        base_hp = int(numbers[1])
        base_dmg = int(numbers[2])

        # category
        if "EnemyCategory.ELITE" in call_text:
            category = "ELITE"
        elif "EnemyCategory.BOSS" in call_text:
            category = "BOSS"
        else:
            category = "NORMAL"

        # combat_type
        combat_type = "WARRIOR"
        for ct in ["WARRIOR", "RANGER", "GUARDIAN", "CASTER", "PRIEST"]:
            if f"EnemyCombatType.{ct}" in call_text:
                combat_type = ct
                break

        # gold (在 combat_type 之后的第一个数字)
        ct_pos = call_text.find(f"EnemyCombatType.{combat_type}")
        after_ct = call_text[ct_pos:]
        gold_match = re.search(r',\s*(\d+)', after_ct)
        drop_gold = int(gold_match.group(1)) if gold_match else 20

        # phases
        phases = parse_phase_calls(call_text)

        # quotes — 找 _q( 调用
        q_start = call_text.find('_q(')
        quotes = {}
        if q_start >= 0:
            q_text = call_text[q_start:]
            quotes = parse_quotes_call(q_text)

        # drop_relic 和 drop_reroll
        # 在 _q(...) 之后找 true/false 和数字
        drop_relic = "true" in call_text.split("_q(")[0].split(",")[-1:] if "_q(" in call_text else False
        # 更简单的方式：看最后几个参数
        after_q = call_text[call_text.rfind(')') - 20:] if '_q(' in call_text else ""
        # 找 _reg 的最后两个可选参数
        drop_relic = False
        drop_reroll = 0
        # 在 quotes 调用之后找 true/false
        if '_q(' in call_text:
            q_call_end = find_matching_paren(call_text, call_text.find('_q(') + 2)
            if q_call_end > 0:
                remainder = call_text[q_call_end + 1:].strip().rstrip(')')
                if 'true' in remainder:
                    drop_relic = True
                reroll_match = re.search(r'(\d+)', remainder)
                if reroll_match:
                    drop_reroll = int(reroll_match.group(1))

        # boss_rank 推断
        boss_rank = "NONE"
        if category == "BOSS":
            if drop_gold == 0:
                boss_rank = "FINAL"
            else:
                boss_rank = "MID"

        enemies.append({
            "id": enemy_id,
            "name": enemy_name,
            "chapter": chapter,
            "category": category,
            "combat_type": combat_type,
            "base_hp": base_hp,
            "base_dmg": base_dmg,
            "drop_gold": drop_gold,
            "drop_relic": drop_relic,
            "drop_reroll_reward": drop_reroll,
            "boss_rank": boss_rank,
            "phases": phases,
            "quotes": quotes,
        })

    return enemies


def find_matching_paren(text: str, open_pos: int) -> int:
    """找到 open_pos 位置的 ( 对应的 ) 位置"""
    depth = 0
    for i in range(open_pos, len(text)):
        if text[i] == '(':
            depth += 1
        elif text[i] == ')':
            depth -= 1
            if depth == 0:
                return i
    return -1


def build_json(enemies: list[dict]) -> dict:
    """将解析结果转换为 config_loader.gd 期望的 JSON 格式"""
    base = []
    phases_list = []
    actions_list = []
    quotes_list = []

    for idx, enemy in enumerate(enemies, 1):
        eid = f"E{idx:04d}"
        pg = f"PG{idx:04d}"
        qg = f"QG{idx:04d}"

        base_entry = {
            "id": eid,
            "legacy_key": enemy["id"],
            "art_id": enemy["id"],
            "name": enemy["name"],
            "chapter": enemy["chapter"],
            "category": enemy["category"],
            "combat_type": enemy["combat_type"],
            "base_hp": enemy["base_hp"],
            "base_dmg": enemy["base_dmg"],
            "drop_gold": enemy["drop_gold"],
            "drop_relic": enemy["drop_relic"],
            "drop_reroll_reward": enemy["drop_reroll_reward"],
            "phase_group": pg,
            "quote_group": qg,
            "boss_rank": enemy["boss_rank"],
        }
        base.append(base_entry)

        # phases + actions
        for pi, phase in enumerate(enemy["phases"]):
            ag = f"AG{idx:04d}_{pi:02d}"
            phases_list.append({
                "phase_group": pg,
                "phase_idx": pi,
                "hp_threshold": phase["hp_threshold"],
                "action_group": ag,
            })
            for ai, action in enumerate(phase["actions"]):
                actions_list.append({
                    "action_group": ag,
                    "action_idx": ai,
                    "type": action["type"],
                    "base_value": action["base_value"],
                    "description": action["description"],
                    "scalable": action["scalable"],
                })

        # quotes
        for event, texts in enemy["quotes"].items():
            for text in texts:
                quotes_list.append({
                    "quote_group": qg,
                    "event": event,
                    "text": text,
                })

    return {
        "base": base,
        "phases": phases_list,
        "actions": actions_list,
        "quotes": quotes_list,
    }


def main():
    with open(INPUT_FILE, "r", encoding="utf-8") as f:
        content = f.read()

    enemies = parse_reg_calls(content)
    print(f"解析到 {len(enemies)} 个敌人")

    if len(enemies) < 85:
        print(f"警告：期望 85 个敌人，实际解析到 {len(enemies)} 个")

    # 统计
    normals = [e for e in enemies if e["category"] == "NORMAL"]
    elites = [e for e in enemies if e["category"] == "ELITE"]
    bosses = [e for e in enemies if e["category"] == "BOSS"]
    print(f"  普通: {len(normals)}, 精英: {len(elites)}, Boss: {len(bosses)}")

    for ch in range(1, 6):
        ch_enemies = [e for e in enemies if e["chapter"] == ch]
        print(f"  第{ch}章: {len(ch_enemies)} 个")

    result = build_json(enemies)
    print(f"生成 JSON: base={len(result['base'])}, phases={len(result['phases'])}, actions={len(result['actions'])}, quotes={len(result['quotes'])}")

    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(result, f, ensure_ascii=False, indent=2)

    print(f"已写入: {OUTPUT_FILE}")


if __name__ == "__main__":
    main()
