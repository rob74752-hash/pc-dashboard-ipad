"""Draws the app icon: a brushed-gold ring gauge on black (the app's mark, large).
Run: python Scripts/make_icon.py  -> App/Assets.xcassets/AppIcon.appiconset/icon-1024.png
"""
import math
import os
import random
from PIL import Image, ImageDraw, ImageFilter

S = 1024
SS = 3  # supersampling
W = S * SS
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
out = os.path.join(root, 'App', 'Assets.xcassets', 'AppIcon.appiconset', 'icon-1024.png')

PALE = (244, 234, 196)
AGED = (236, 228, 180)
GOLD = (200, 173, 134)
BRONZE = (143, 110, 69)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def gold_at(y):
    # light from above: pale -> aged -> gold -> bronze
    t = y / W
    if t < 0.3:
        return lerp(PALE, AGED, t / 0.3)
    if t < 0.65:
        return lerp(AGED, GOLD, (t - 0.3) / 0.35)
    return lerp(GOLD, BRONZE, min(1, (t - 0.65) / 0.35))


# Brushed gold sheet
random.seed(7)
sheet = Image.new('RGB', (W, W))
px = sheet.load()
for y in range(W):
    base = gold_at(y)
    k = 0.94 + 0.08 * random.random()
    row = tuple(min(255, int(c * k)) for c in base)
    for x in range(W):
        px[x, y] = row
# diagonal highlight
hl = Image.new('L', (W, W), 0)
d = ImageDraw.Draw(hl)
d.polygon([(int(W * 0.15), 0), (int(W * 0.42), 0), (int(W * 0.0), int(W * 0.9)), (int(-W * 0.27), int(W * 0.9))], fill=110)
hl = hl.filter(ImageFilter.GaussianBlur(W * 0.06))
sheet = Image.composite(Image.new('RGB', (W, W), (255, 246, 222)), sheet, hl)

# Ring mask: 270 degree arc open at the bottom, with a lit portion
cx = cy = W / 2
r = W * 0.30
thick = W * 0.052
mask = Image.new('L', (W, W), 0)
md = ImageDraw.Draw(mask)
box = [cx - r, cy - r, cx + r, cy + r]
# PIL angles: 0 = 3 o'clock, clockwise. Open gap centred at the bottom (90 deg).
md.arc(box, start=135, end=45, fill=255, width=int(thick))
dim = Image.new('L', (W, W), 0)
dd = ImageDraw.Draw(dim)
dd.arc(box, start=135, end=45, fill=255, width=int(thick))
lit = Image.new('L', (W, W), 0)
ld = ImageDraw.Draw(lit)
ld.arc(box, start=135, end=300, fill=255, width=int(thick))
# round caps on the lit arc (PIL draws the stroke inward from the box edge)
rc = r - thick / 2
for ang in (135, 300):
    a = math.radians(ang)
    px_, py_ = cx + rc * math.cos(a), cy + rc * math.sin(a)
    rr = thick / 2
    ld.ellipse([px_ - rr, py_ - rr, px_ + rr, py_ + rr], fill=255)
img = Image.new('RGB', (W, W), (0, 0, 0))
# faint track for the unlit part
track = Image.new('RGB', (W, W), (58, 50, 38))
img = Image.composite(track, img, dim)
img = Image.composite(sheet, img, lit)

# inner hairline ring and centre jewel
d2 = ImageDraw.Draw(img)
r2 = r - thick * 1.6
d2.ellipse([cx - r2, cy - r2, cx + r2, cy + r2], outline=(96, 82, 60), width=SS * 3)
jr = W * 0.035
jewel = Image.new('L', (W, W), 0)
ImageDraw.Draw(jewel).ellipse([cx - jr, cy - jr, cx + jr, cy + jr], fill=255)
img = Image.composite(sheet, img, jewel)

# soft warm glow behind the lit arc (decorative)
glow = lit.filter(ImageFilter.GaussianBlur(W * 0.03))
glow_col = Image.new('RGB', (W, W), (204, 145, 102))
img = Image.composite(glow_col, img, glow.point(lambda v: int(v * 0.22)))
img = Image.composite(sheet, img, lit)
img = Image.composite(sheet, img, jewel)

img = img.resize((S, S), Image.LANCZOS)
os.makedirs(os.path.dirname(out), exist_ok=True)
img.save(out)
print('wrote', out)
