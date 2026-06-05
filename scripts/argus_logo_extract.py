#!/usr/bin/env python3
# © 2026 Gabor Szeman – Alle Rechte vorbehalten. Proprietär, Nutzung nur mit Genehmigung.
"""
Stellt das ARGUS-Logo aus ARGUS_Icon.png frei (heller Hintergrund -> transparent)
und erzeugt vier Marken-Assets in assets/:
  argus-logo.png        (A+Kreuz+Schriftzug, dunkel)
  argus-logo-light.png  (weiß, Kreuz rot)  -> für dunkle Hintergründe
  argus-mark.png        (nur Symbol, dunkel)
  argus-mark-light.png  (nur Symbol, weiß/rot)

Benötigt Pillow:  python3 -m pip install --user Pillow
Aufruf:           python3 scripts/argus_logo_extract.py
"""
import os
from PIL import Image, ImageChops

SRC = "ARGUS_Icon.png"; OUT = "assets"
LO, HI = 110, 205   # Min-Kanal-Schwellen (Logo dunkel/rot vs. heller Hintergrund)

def main():
    os.makedirs(OUT, exist_ok=True)
    im = Image.open(SRC).convert("RGBA"); W, H = im.size
    r, g, b, a = im.split()
    mn = ImageChops.darker(ImageChops.darker(r, g), b)
    tab = [255 if v <= LO else (0 if v >= HI else int((HI - v) / (HI - LO) * 255)) for v in range(256)]
    alpha = ImageChops.multiply(mn.point(tab), a)

    def crop(rgba, pad=24):
        x0, y0, x1, y1 = rgba.getchannel('A').getbbox()
        return rgba.crop((max(0, x0 - pad), max(0, y0 - pad),
                          min(rgba.width, x1 + pad), min(rgba.height, y1 + pad)))

    dark = crop(Image.merge('RGBA', (r, g, b, alpha)))
    dark.save(os.path.join(OUT, "argus-logo.png"))

    maxGB = ImageChops.lighter(g, b)
    redmask = ImageChops.subtract(r, maxGB).point(lambda v: 255 if v > 45 else 0)
    base = Image.new('RGB', (W, H), (243, 245, 247))
    base.paste(Image.merge('RGB', (r, g, b)), (0, 0), redmask)
    light = base.convert('RGBA'); light.putalpha(alpha)
    light = crop(light)
    light.save(os.path.join(OUT, "argus-logo-light.png"))

    # Symbol-only: vertikale Lücke zwischen Kreuz und Schriftzug finden
    al = dark.getchannel('A'); h = al.height
    rows = list(al.resize((1, h)).getdata())
    gap = None; run = None
    for y in range(int(h * 0.50), int(h * 0.92)):
        if rows[y] < 5:
            run = (run[0], y) if run else (y, y)
        else:
            if run and run[1] - run[0] >= 8 and gap is None: gap = run
            run = None
    if run and run[1] - run[0] >= 8 and gap is None: gap = run
    if gap:
        cut = (gap[0] + gap[1]) // 2
        dark.crop((0, 0, dark.width, cut)).save(os.path.join(OUT, "argus-mark.png"))
        light.crop((0, 0, light.width, cut)).save(os.path.join(OUT, "argus-mark-light.png"))
    print("Fertig:", os.listdir(OUT))

if __name__ == "__main__":
    main()
