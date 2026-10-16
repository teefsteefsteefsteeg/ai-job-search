#!/usr/bin/env python3
"""Pack chroma-key sprite strips into a small, consistently scaled pixel-art atlas.

The image model draws each row at its own size and on a finer grid than asked, so
sprite-gen's per-row fit gives rows of different character heights. This tool instead
scales every row so the character's median pose height equals --char-height, quantises
all frames to one shared palette, and pins feet to one baseline (foot-centroid x).

Input: a sprite-gen run dir (sprite-request.json + raw/<dir>/<pose>.png).
Background removal uses `sprite-gen cutout` (magenta engine) per strip.
Output: <out>/atlas.png + <out>/manifest.json (frame_layout schema as sprite-gen) +
<out>/preview.png (4x, on grass) + per-state report on stdout.

usage: pixel_pack.py RUN_DIR OUT_DIR --sprite-gen BIN [--char-height 28] [--cell 48x40]
       [--colors 20] [--states a,b] [--palette-from down_idle]
"""
import argparse, json, subprocess, tempfile
from pathlib import Path
import numpy as np
from PIL import Image


def figures(alpha, min_gap=6):
    cols = np.nonzero((alpha > 128).any(0))[0]
    if not len(cols):
        return []
    runs, s, p = [], cols[0], cols[0]
    for x in cols[1:]:
        if x - p > min_gap:
            runs.append((s, p)); s = x
        p = x
    runs.append((s, p))
    return [r for r in runs if r[1] - r[0] > 8]


def slot_split(alpha, n):
    """Cut a strip into n figures at the emptiest column near each even split point."""
    occ = (alpha > 128).sum(0).astype(float)
    W = alpha.shape[1]; cuts = [0]
    for k in range(1, n):
        c = int(W * k / n); r = int(W / n * 0.35)
        win = occ[c - r:c + r]
        cuts.append(c - r + int(np.argmin(win + np.abs(np.arange(len(win)) - r) * 1e-3)))
    cuts.append(W)
    return [(cuts[i], cuts[i + 1] - 1) for i in range(n)]


def mode_downsample(c, w, h, pal, dark_share=0.3):
    """Each target pixel takes the most common palette colour of its source block, but a
    dark (outline/eye) colour wins when it covers >= dark_share of the block."""
    src = np.array(c)
    idx = np.array(c.convert('RGB').quantize(palette=pal, dither=Image.Dither.NONE))
    pal_rgb = np.array(pal.getpalette()[:3 * 256]).reshape(-1, 3)
    lum = pal_rgb @ [0.299, 0.587, 0.114]
    dark = lum < 70
    ys = np.linspace(0, c.height, h + 1).round().astype(int)
    xs = np.linspace(0, c.width, w + 1).round().astype(int)
    out = np.zeros((h, w, 4), 'uint8')
    for j in range(h):
        for i in range(w):
            a = src[ys[j]:ys[j + 1], xs[i]:xs[i + 1], 3]
            if a.size == 0 or (a > 128).mean() < 0.5:
                continue
            blk = idx[ys[j]:ys[j + 1], xs[i]:xs[i + 1]][a > 128]
            cnt = np.bincount(blk, minlength=len(pal_rgb))
            dk = np.where(dark[:len(cnt)], cnt, 0)
            k = int(dk.argmax()) if dk.sum() >= dark_share * blk.size else int(cnt.argmax())
            out[j, i, :3] = pal_rgb[k]; out[j, i, 3] = 255
    return Image.fromarray(out)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('run'); ap.add_argument('out')
    ap.add_argument('--sprite-gen', required=True)
    ap.add_argument('--char-height', type=int, default=28)
    ap.add_argument('--cell', default='48x40')
    ap.add_argument('--colors', type=int, default=20)
    ap.add_argument('--states')
    ap.add_argument('--palette-from', default='down_idle')
    a = ap.parse_args()
    run, out = Path(a.run), Path(a.out); out.mkdir(parents=True, exist_ok=True)
    cw, ch = map(int, a.cell.split('x')); base_y = ch - 2
    req = json.load(open(run / 'sprite-request.json'))
    states = req['states']
    order = a.states.split(',') if a.states else list(states)
    tmp = Path(tempfile.mkdtemp())

    rows, report = {}, {}
    for st in order:
        d, pose = st.split('_', 1)
        raw = run / 'raw' / d / f'{pose}.png'
        if not raw.exists():
            report[st] = 'missing raw'; continue
        cut = tmp / f'{st}.png'
        subprocess.run([a.sprite_gen, 'cutout', str(raw), '--key', 'magenta', '--out', str(cut)],
                       check=True, capture_output=True)
        im = Image.open(cut).convert('RGBA'); al = np.array(im)[:, :, 3]
        runs = figures(al)
        want = states[st]['frames']
        note = ''
        if len(runs) != want:
            note = f' (column runs {len(runs)} != {want}, slot split)'
            runs = slot_split(al, want)
        crops = []
        for x0, x1 in runs:
            c = im.crop((x0, 0, x1 + 1, im.height)); crops.append(c.crop(c.getbbox()))
        rows[st] = crops
        report[st] = note

    # shared palette from the opaque pixels of every hi-res crop
    opaque = []
    for frames in rows.values():
        for f in frames:
            arr = np.array(f); opaque.append(arr[arr[:, :, 3] > 128][:, :3][::7])
    pix = np.concatenate(opaque)
    pal = Image.fromarray(pix.reshape(1, -1, 3).astype('uint8')).quantize(colors=a.colors, method=Image.Quantize.MEDIANCUT)
    for st, crops in list(rows.items()):
        # loops: median pose; one-shot actions: the last (recovered, standing) pose
        ref_h = np.median([c.height for c in crops]) if states[st].get('loop', True) else crops[-1].height
        s = a.char_height / float(ref_h)
        rows[st] = [mode_downsample(c, max(1, round(c.width * s)), max(1, round(c.height * s)), pal) for c in crops]
        report[st] = f'ok scale={s:.4f} heights={[c.height for c in rows[st]]}' + report.get(st, '')

    ncols = max(len(v) for v in rows.values())
    atlas = Image.new('RGBA', (ncols * cw, len(rows) * ch), (0, 0, 0, 0))
    layout = {}
    for ri, (st, frames) in enumerate(rows.items()):
        layout[st] = []
        for fi, f in enumerate(frames):
            q = f
            al = np.array(q)[:, :, 3] > 0
            foot = al[int(al.shape[0] * .75):]
            fx = np.nonzero(foot)[1].mean() if foot.any() else q.width / 2
            ox = int(round(cw / 2 - fx)); oy = base_y - q.height
            cell = Image.new('RGBA', (cw, ch), (0, 0, 0, 0)); cell.paste(q, (ox, oy), q)
            atlas.paste(cell, (fi * cw, ri * ch))
            layout[st].append({'x': fi * cw, 'y': ri * ch, 'w': cw, 'h': ch})
    atlas.save(out / 'atlas.png')
    anim = {st: {'fps': states[st].get('fps', 8), 'loop': states[st].get('loop', True), 'frames': len(layout[st])} for st in layout}
    json.dump({'cell': {'w': cw, 'h': ch, 'foot_y': base_y}, 'char_height': a.char_height,
               'frame_layout': {'sheetWidth': atlas.width, 'sheetHeight': atlas.height, 'rows': layout},
               'animation': {'rows': anim}}, open(out / 'manifest.json', 'w'), indent=1)
    big = atlas.resize((atlas.width * 4, atlas.height * 4), Image.NEAREST)
    prev = Image.new('RGBA', big.size, (124, 178, 82, 255)); prev.alpha_composite(big); prev.convert('RGB').save(out / 'preview.png')
    for k, v in report.items():
        print(f'{k}: {v}')


if __name__ == '__main__':
    main()
