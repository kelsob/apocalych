"""One-shot migration: creature_tags int + optional tag_names -> tag_* bools in Enemy .tres files."""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / "resources" / "enemies"

TAG_KEYS = [
    ("tag_beast", 1 << 0),
    ("tag_humanoid", 1 << 1),
    ("tag_undead", 1 << 2),
    ("tag_spectral", 1 << 3),
    ("tag_demon", 1 << 4),
    ("tag_construct", 1 << 5),
    ("tag_dragon", 1 << 6),
    ("tag_cursed", 1 << 7),
    ("tag_corrupted", 1 << 8),
    ("tag_plant", 1 << 9),
    ("tag_elemental", 1 << 10),
    ("tag_flying", 1 << 11),
    ("tag_fel", 1 << 12),
]
# tag_names use short keys: "beast", "fel", …
NAME_TO_BIT = {
    "beast": 1 << 0,
    "humanoid": 1 << 1,
    "undead": 1 << 2,
    "spectral": 1 << 3,
    "demon": 1 << 4,
    "construct": 1 << 5,
    "dragon": 1 << 6,
    "cursed": 1 << 7,
    "corrupted": 1 << 8,
    "plant": 1 << 9,
    "elemental": 1 << 10,
    "flying": 1 << 11,
    "fel": 1 << 12,
}


def names_to_mask(inner: str) -> int:
    mask = 0
    for name in re.findall(r'"([^"]*)"', inner):
        key = name.lower().strip()
        if key in NAME_TO_BIT:
            mask |= NAME_TO_BIT[key]
    return mask


def compute_mask(text: str) -> int:
    m = re.search(r"tag_names\s*=\s*PackedStringArray\(([^\)]*)\)", text)
    if m:
        inner = m.group(1).strip()
        if inner:
            return names_to_mask(inner)
    m2 = re.search(r"creature_tags\s*=\s*(\d+)", text)
    if m2:
        return int(m2.group(1))
    return 0


def bool_block(mask: int) -> str:
    lines = []
    for name, bit in TAG_KEYS:
        lines.append(f"{name} = {'true' if (mask & bit) else 'false'}")
    return "\n".join(lines) + "\n"


def main() -> None:
    for path in sorted(ROOT.rglob("*.tres")):
        text = path.read_text(encoding="utf-8")
        if "creature_tags" not in text and "tag_names" not in text:
            continue
        mask = compute_mask(text)
        new_text, n = re.subn(
            r"(?:tag_names\s*=\s*PackedStringArray\([^\)]*\)\n)?creature_tags\s*=\s*\d+\n",
            bool_block(mask),
            text,
            count=1,
        )
        if n == 0:
            print("NO MATCH:", path)
            continue
        path.write_text(new_text, encoding="utf-8")
        print("OK", path.relative_to(ROOT.parent.parent), "mask", mask)


if __name__ == "__main__":
    main()
