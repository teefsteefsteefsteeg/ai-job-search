# Farmer 8-direction run - QA notes

5 generated directions (down, downside, side, upside, up); downleft/left/upleft are runtime
mirrors. Cell 64x80, `fit.pixel_unfake`, feet at y=72. Provider: OpenRouter
gemini-3-pro-image-preview via `Tools/art/openrouter_gen.py`, no layout guide attached,
hi-res anchors from raw idle frame 0 (see `.prompts-or/`). Extracted with `--segmentation projection`.

Curation: stray neighbour pixels erased in downside_walk, side_walk, upside_walk;
down_walk uses frames [0,2,3,5] (frames 1 and 4 were drawn smaller and had clipped hat brims).

| State | Verdict | Notes |
|---|---|---|
| *_idle (5) | pass | down_idle frame 3 turns slightly |
| down_walk | experimental | 4 frames, small steps |
| downside_walk / side_walk / upside_walk / up_walk | experimental | readable gait |

Known: sprite-gen warns of pitch disagreement on some rows, and up/upside idle were capped
at the 64x80 cell, so the character reads slightly larger in those rows. Regenerate with a
block-count hint if this shows in game.
