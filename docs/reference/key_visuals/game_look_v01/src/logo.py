# ロゴの下書きを作る（透明PNG）。文字は「源暎ぽっぷる Black」。
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageChops
import os, sys
S = os.path.dirname(os.path.abspath(__file__))
FONT = os.path.expanduser("~/.local/share/fonts/GenEiPOPle-Bk.ttf")
NAVY = (22, 37, 79, 255)
WHITE = (255, 255, 255, 255)

def glyph(ch, size, top, bottom, angle, navy_w, white_w, shear=0.0):
    font = ImageFont.truetype(FONT, size)
    pad = navy_w + 40
    box = font.getbbox(ch)
    w, h = box[2] - box[0] + pad * 2, box[3] - box[1] + pad * 2
    at = (pad - box[0], pad - box[1])
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).text(at, ch, font=font, fill=255)
    outer = Image.new("L", (w, h), 0)
    ImageDraw.Draw(outer).text(at, ch, font=font, fill=255, stroke_width=navy_w, stroke_fill=255)
    inner = Image.new("L", (w, h), 0)
    ImageDraw.Draw(inner).text(at, ch, font=font, fill=255, stroke_width=white_w, stroke_fill=255)
    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    layer.paste(Image.new("RGBA", (w, h), NAVY), (0, 0), outer)
    layer.paste(Image.new("RGBA", (w, h), WHITE), (0, 0), inner)
    # 上から下へ、色を少し濃くする。
    grad = Image.new("RGBA", (w, h))
    gd = ImageDraw.Draw(grad)
    y0, y1 = pad, h - pad
    for y in range(h):
        t = min(max((y - y0) / max(y1 - y0, 1), 0.0), 1.0)
        gd.line([(0, y), (w, y)], fill=tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)) + (255,))
    layer.paste(grad, (0, 0), mask)
    # つや（上のほうを、少し白く）。
    shrink = mask.filter(ImageFilter.MinFilter(max(3, (size // 26) | 1)))
    gloss = Image.new("L", (w, h), 0)
    gl = ImageDraw.Draw(gloss)
    for y in range(h):
        t = min(max((y - y0) / max(y1 - y0, 1), 0.0), 1.0)
        gl.line([(0, y), (w, y)], fill=int(max(0.0, 1.0 - t / 0.5) * 120))
    gloss = ImageChops.multiply(gloss, shrink).filter(ImageFilter.GaussianBlur(size / 90))
    layer.paste(Image.new("RGBA", (w, h), WHITE), (0, 0), gloss)
    if shear:
        layer = layer.transform((w + int(abs(shear) * h), h), Image.AFFINE, (1, shear, -shear * h if shear > 0 else 0, 0, 1, 0), Image.BICUBIC)
    if angle:
        layer = layer.rotate(angle, Image.BICUBIC, expand=True)
    return layer

def build(out, with_pururin=True):
    W, H = 3000, 1500
    canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    # 1行目：ぷるりん（水・火・風・地の色）。
    colors = [((98, 190, 255), (30, 112, 224)), ((255, 150, 96), (232, 66, 44)), ((128, 228, 150), (40, 168, 92)), ((255, 214, 110), (226, 150, 36))]
    angles = [7, -5, 4, -7]
    lifts = [20, -40, 10, -30]
    x = 250
    for i, ch in enumerate("ぷるりん"):
        g = glyph(ch, 560, colors[i][0], colors[i][1], angles[i], 40, 22)
        canvas.alpha_composite(g, (x, 150 + lifts[i] + (760 - g.height) // 2))
        x += g.width - 150
    first_right = x + 150
    # 2行目：レーサーズ（白。少し斜め）。
    x = 600
    for ch in "レーサーズ":
        g = glyph(ch, 300, (255, 255, 255), (214, 228, 250), 0, 30, 0, shear=0.16)
        canvas.alpha_composite(g, (x, 870))
        x += g.width - 205
    second_right = x + 150
    # 2行目の下に、市松のしま。
    d = ImageDraw.Draw(canvas)
    cell = 34
    x0, y0 = 600, 1268
    cols = (second_right - x0) // cell
    d.rounded_rectangle([x0 - 12, y0 - 12, x0 + cols * cell + 12, y0 + cell * 2 + 12], 14, fill=NAVY)
    for r in range(2):
        for c in range(cols):
            d.rectangle([x0 + c * cell, y0 + r * cell, x0 + (c + 1) * cell - 1, y0 + (r + 1) * cell - 1], fill=WHITE if (r + c) % 2 == 0 else (22, 37, 79, 255))
    # 英字。
    small = ImageFont.truetype(FONT, 78)
    text = "PURURIN  RACERS"
    tw = d.textlength(text, font=small)
    d.text(((x0 + x0 + cols * cell) / 2 - tw / 2, 1368), text, font=small, fill=NAVY, stroke_width=10, stroke_fill=WHITE)
    if with_pururin:
        p = Image.open(os.path.join(S, "out", "logo_pururin.png")).convert("RGBA")
        p = p.crop(p.getbbox())
        scale = 520 / p.width
        p = p.resize((int(p.width * scale), int(p.height * scale)), Image.LANCZOS).rotate(-8, Image.BICUBIC, expand=True)
        canvas.alpha_composite(p, (second_right - 20, 790))
    # まわりに、やわらかい影。
    alpha = canvas.split()[3]
    shadow = Image.new("RGBA", (W, H), (10, 20, 50, 0))
    shadow.putalpha(alpha.filter(ImageFilter.GaussianBlur(18)).point(lambda v: int(v * 0.45)))
    result = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    result.alpha_composite(shadow, (0, 16))
    result.alpha_composite(canvas)
    result = result.crop(result.getbbox())
    result.save(out)
    return result

build(os.path.join(S, "out", "logo.png"))
build(os.path.join(S, "out", "logo_text_only.png"), with_pururin=False)
