# Détoure une photo produit sur fond blanc (remplissage depuis les bords) -> PNG transparent agrandi.
import sys
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage
src, dst = sys.argv[1], sys.argv[2]
im = Image.open(src).convert('RGB')
im = im.resize((im.width * 2, im.height * 2), Image.LANCZOS).filter(ImageFilter.UnsharpMask(radius=2, percent=80, threshold=2))
a = np.asarray(im).astype(np.int16)
white = (a.min(axis=2) > 228) & ((a.max(axis=2) - a.min(axis=2)) < 22)
lab, _ = ndimage.label(white)
border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
bg = np.isin(lab, list(border))
bg = ndimage.binary_opening(bg, iterations=1)
alpha = (~bg).astype(np.float32)
alpha = ndimage.gaussian_filter(alpha, 1.2)
# ombre portée trop claire : on garde un peu de douceur
out = np.dstack([np.asarray(im), (alpha * 255).astype(np.uint8)])
img = Image.fromarray(out, 'RGBA')
bbox = img.getchannel('A').point(lambda v: 255 if v > 20 else 0).getbbox()
img.crop(bbox).save(dst)
print(dst, img.crop(bbox).size)
