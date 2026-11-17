# Détoure une photo sur fond blanc, garde le produit (supprime les filigranes isolés), agrandit x scale.
# Usage : python3 -I tools/cutout2.py src.jpg dst.png [all]
import sys
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage
src, dst = sys.argv[1], sys.argv[2]
keep_all = len(sys.argv) > 3 and sys.argv[3] == 'all'
im = Image.open(src).convert('RGB')
scale = max(2, int(np.ceil(1100 / max(im.size))))
im = im.resize((im.width * scale, im.height * scale), Image.LANCZOS).filter(ImageFilter.UnsharpMask(radius=2, percent=90, threshold=2))
a = np.asarray(im).astype(np.int16)
white = (a.min(axis=2) > 226) & ((a.max(axis=2) - a.min(axis=2)) < 24)
lab, _ = ndimage.label(white)
border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
bg = ndimage.binary_opening(np.isin(lab, list(border)), iterations=1)
fg = ~bg
fl, n = ndimage.label(fg)
sizes = ndimage.sum(fg, fl, range(1, n + 1))
big = sizes.max()
keep = [i + 1 for i, s in enumerate(sizes) if (s > 0.05 * big if keep_all else s == big)]
fg = np.isin(fl, keep)
fg = ndimage.binary_fill_holes(fg) if not keep_all else fg
fg = ndimage.binary_erosion(fg, iterations=max(1, scale // 2))
alpha = ndimage.gaussian_filter(fg.astype(np.float32), 1.0 * scale / 2)
out = np.dstack([np.asarray(im), (np.clip(alpha, 0, 1) * 255).astype(np.uint8)])
img = Image.fromarray(out, 'RGBA')
bbox = img.getchannel('A').point(lambda v: 255 if v > 20 else 0).getbbox()
img.crop(bbox).save(dst)
print(dst, img.crop(bbox).size)
