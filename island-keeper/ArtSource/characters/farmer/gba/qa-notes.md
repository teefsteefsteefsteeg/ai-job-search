# Farmer GBA-scale sprites - QA notes

Target: classic handheld overworld scale, 16px tiles, character 28px tall, cell 48x40, feet y=38.
Rows: idle (2f) and walk (4f) in down/downside/side/upside/up (left side mirrored),
hoe / water / lasso (3f) in down/side/up.

Pipeline: `sprite-gen prepare` (prompts, request) -> OpenRouter rows (`Tools/art/gba_gen.sh`,
no layout guide) -> `Tools/art/pixel_pack.py` instead of sprite-gen extract/compose:
sprite-gen pixel-unfake measured ~54px native height and fit each row separately, so
rows came out at different character sizes. pixel_pack keys each strip with
`sprite-gen cutout`, scales every row so the character is 28px (loops: median pose,
one-shots: last pose), mode-downsamples with a dark-colour bias to keep outlines,
shares one 28-colour palette and pins feet with a foot-centroid.

Raw edits: side_idle figure 3 and upside_idle figure 2 painted to key (model drew 3 figures
for a 2-frame row); originals in `run/raw/_orig/`. down_hoe regenerated once (cream border, debris).
Tool rows that touched or had loose drops use the slot split (see pixel_pack report).

Creatures: `ArtSource/creatures/creatures_gba.png` = hi-res cuts mode-downsampled to 22px +
1px outline (24px). Hand cleanup recommended before shipping.
