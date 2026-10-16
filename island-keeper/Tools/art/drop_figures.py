#!/usr/bin/env python3
"""Paint chosen figures of a chroma-key strip back to the key colour (keeps a copy of the original).
usage: drop_figures.py strip.png 2 [0 ...]   (0-based figure indices, found as column runs)"""
import sys, shutil
import numpy as np
from PIL import Image
path, drop = sys.argv[1], {int(i) for i in sys.argv[2:]}
shutil.copy(path, path.replace('.png', '.orig.png'))
a = np.array(Image.open(path).convert('RGB')).astype(int)
fg = (np.abs(a - [255, 0, 255]).sum(2) > 90).any(0)
xs = np.nonzero(fg)[0]; runs = []; s = p = xs[0]
for x in xs[1:]:
    if x - p > 6: runs.append((s, p)); s = x
    p = x
runs.append((s, p)); print('figures', runs)
for i in drop:
    x0, x1 = runs[i]; a[:, max(0, x0 - 3):x1 + 4] = [255, 0, 255]
Image.fromarray(a.astype('uint8')).save(path)
