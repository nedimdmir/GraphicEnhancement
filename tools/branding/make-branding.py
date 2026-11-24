"""Regenerate Graphic Enhancement brand images (wordmark, logo, app icon).

Run from the repo root: python tools/branding/make-branding.py
Canvas sizes match what the QML and resource files expect.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont

FONT = next((f for f in ("C:/Windows/Fonts/segoeuib.ttf", "C:/Windows/Fonts/arialbd.ttf") if Path(f).exists()), None)
TOP, MID, BOTTOM = (122, 92, 210), (236, 96, 160), (255, 178, 120)  # lavender -> pink -> peach


def gradient(size):
    w, h = size
    g = Image.new("RGBA", size)
    px = g.load()
    for y in range(h):
        t = y / max(1, h - 1)
        a, b, u = (TOP, MID, t * 2) if t < 0.5 else (MID, BOTTOM, t * 2 - 1)
        c = tuple(int(a[i] + (b[i] - a[i]) * u) for i in range(3)) + (255,)
        for x in range(w):
            px[x, y] = c
    return g


def font(size):
    return ImageFont.truetype(FONT, size) if FONT else ImageFont.load_default(size)


def fit(text, width, height):
    size = height
    while size > 8:
        f = font(size)
        l, t, r, b = f.getbbox(text)
        if r - l <= width and b - t <= height:
            return f
        size -= 4
    return font(8)


def text_mask(size, lines):
    """lines: [(text, box)] -> one L mask with each text centred in its box."""
    m = Image.new("L", size, 0)
    d = ImageDraw.Draw(m)
    for text, (x0, y0, x1, y1) in lines:
        f = fit(text, x1 - x0, y1 - y0)
        l, t, r, b = f.getbbox(text)
        d.text((x0 + (x1 - x0 - (r - l)) / 2 - l, y0 + (y1 - y0 - (b - t)) / 2 - t), text, font=f, fill=255)
    return m


def paint(mask):
    img = gradient(mask.size)
    img.putalpha(mask)
    return img


def wordmark(root):
    size = (1164, 969)
    w, h = size
    line1 = ("Graphic", (20, 40, w - 20, h // 2 - 20))
    line2 = ("Enhancement", (20, h // 2 + 20, w - 20, h - 40))
    full = text_mask(size, [line1, line2])
    top = text_mask(size, [line1])
    bottom = text_mask(size, [line2])
    left = Image.new("L", size, 0); left.paste(bottom.crop((0, 0, w // 2, h)), (0, 0))
    right = Image.new("L", size, 0); right.paste(bottom.crop((w // 2, 0, w, h)), (w // 2, 0))
    paint(full).save(root / "wordmark-dusk.png")
    paint(top).save(root / "wordmark-dusk-graphicenhancement.png")
    paint(left).save(root / "wordmark-dusk-n.png")
    paint(right).save(root / "wordmark-dusk-r.png")
    glow = paint(full).resize((768, 670)).filter(ImageFilter.GaussianBlur(24))
    glow.save(root / "wordmark-dusk-glow.png")


def monogram(size, colour=None):
    w, h = size
    s = min(w, h)
    m = Image.new("L", size, 0)
    d = ImageDraw.Draw(m)
    pad = s // 10
    box = ((w - s) // 2 + pad, (h - s) // 2 + pad, (w + s) // 2 - pad, (h + s) // 2 - pad)
    d.rounded_rectangle(box, radius=s // 6, outline=255, width=max(2, s // 14))
    inner = text_mask(size, [("GE", (box[0] + s // 8, box[1] + s // 8, box[2] - s // 8, box[3] - s // 8))])
    m = Image.composite(Image.new("L", size, 255), m, inner)
    if colour is None:
        return paint(m)
    img = Image.new("RGBA", size, colour + (255,))
    img.putalpha(m)
    return img


def main():
    repo = Path(__file__).resolve().parents[2]
    qml = repo / "qml" / "GraphicEnhancement"
    wordmark(qml)
    monogram((360, 240), (255, 255, 255)).save(qml / "logo.png")
    monogram((720, 480)).save(qml / "logo-dusk.png")
    assets = repo / "assets"
    icon = Image.new("RGBA", (1254, 1254), (0, 0, 0, 0))
    bg = Image.new("L", icon.size, 0)
    ImageDraw.Draw(bg).rounded_rectangle((40, 40, 1214, 1214), radius=240, fill=255)
    dark = Image.new("RGBA", icon.size, (28, 20, 48, 255)); dark.putalpha(bg)
    icon = Image.alpha_composite(dark, monogram(icon.size))
    icon.save(assets / "graphicenhancement-app-icon.png")
    icon.resize((1536, 1536)).crop((0, 256, 1536, 1280)).save(assets / "graphicenhancement-logo.png")
    icon.save(assets / "graphicenhancement.ico", sizes=[(n, n) for n in (16, 20, 24, 32, 40, 48, 64, 96, 128, 256)])


if __name__ == "__main__":
    main()
