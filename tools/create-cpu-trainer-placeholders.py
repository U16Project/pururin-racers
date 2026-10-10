"""Generate deterministic, non-AI 1024px temporary trainer portraits.

Run from any directory. Pillow is required. No gameplay data is changed.
"""
from pathlib import Path
from PIL import Image, ImageDraw

DEST = Path(__file__).resolve().parents[1] / "client/assets/ui/cpu_trainers"
# ID, hair style, hair colour, jacket colour, background colour.
PEOPLE = [
    ("yuu", "short", "#594332", "#3979B5", "#E0EDF7"),
    ("homura", "spiky", "#BD4F3E", "#DC7646", "#F8E5DA"),
    ("shizuku", "bob", "#303844", "#3D999F", "#DAEEEE"),
    ("daichi", "short", "#684F39", "#839253", "#EAEBD9"),
    ("hayate", "spiky", "#A1ADBB", "#568CAE", "#E0EDF1"),
    ("akari", "ponytail", "#985137", "#C96E8F", "#F4E2EA"),
    ("minato", "short", "#364E70", "#458E8B", "#DEECEC"),
    ("gantetsu", "beard", "#78818A", "#9D7757", "#ECE4DD"),
    ("hinata", "bob", "#D9AA4E", "#CBA345", "#F6EFD8"),
    ("kaede", "bob", "#83533D", "#598C62", "#E2EDDF"),
    ("ren", "spiky", "#303238", "#BC565A", "#F0E0E1"),
    ("ibuki", "short", "#776387", "#66648F", "#E8E3F0"),
    ("tsubaki", "long", "#34313D", "#96556F", "#EFE2E9"),
]


def portrait(style, hair, jacket, background):
    image = Image.new("RGB", (1024, 1024), background)
    draw = ImageDraw.Draw(image)
    skin, ink = "#F0C3A0", "#383A44"
    # Large, simple silhouettes remain readable at menu-icon size.
    draw.ellipse((112, 112, 912, 912), fill="#FFFFFF")
    if style == "long":
        draw.rounded_rectangle((270, 250, 754, 810), radius=130, fill=hair)
    if style == "ponytail":
        draw.ellipse((700, 270, 850, 590), fill=hair)
    draw.ellipse((174, 690, 850, 1270), fill=jacket)
    draw.rounded_rectangle((446, 596, 578, 802), radius=45, fill=skin)
    draw.ellipse((284, 195, 740, 680), fill=hair)
    if style == "spiky":
        for x, y in [(305, 174), (390, 139), (485, 125), (585, 146), (670, 179)]:
            draw.polygon([(x-40, 310), (x+80, 290), (x+30, y)], fill=hair)
    if style == "bob":
        draw.rounded_rectangle((280, 330, 744, 680), radius=80, fill=hair)
    draw.ellipse((337, 288, 687, 709), fill=skin)
    draw.polygon([(327, 365), (365, 254), (610, 246), (700, 367),
                  (608, 329), (555, 389), (510, 331), (421, 391), (418, 332)], fill=hair)
    for x in (439, 585):
        draw.line((x-28, 450, x+28, 450), fill=hair, width=12)
        draw.ellipse((x-13, 482, x+13, 512), fill=ink)
    draw.arc((466, 542, 558, 603), 15, 165, fill=ink, width=10)
    if style == "beard":
        draw.arc((365, 456, 659, 699), 0, 180, fill=hair, width=42)
    draw.polygon([(424, 738), (512, 815), (600, 738), (561, 875), (463, 875)], fill="#F8F6EF")
    draw.line((512, 877, 512, 1024), fill="#FFFFFF", width=9)
    return image


if __name__ == "__main__":
    DEST.mkdir(parents=True, exist_ok=True)
    for identifier, style, hair, jacket, background in PEOPLE:
        path = DEST / f"{identifier}_v01.png"
        portrait(style, hair, jacket, background).save(path)
        print(path)
