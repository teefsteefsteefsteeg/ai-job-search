# The Keeper - sprite run QA notes

Run: sprite-gen atlas pipeline (`prepare --directions down,side,up --mirror left=side`),
cell 256x320, chroma #FF00FF. Generation provider: OpenRouter `google/gemini-3-pro-image-preview`
via `Tools/art/openrouter_gen.py` (sprite-gen has no OpenRouter provider, so rows were written
straight to `raw/` and then went through the normal `extract` -> `compose-atlas` -> `compose-gif` -> `inspect`).

## Deviations from the stock sprite-gen workflow
- **No layout-guide image attached.** Gemini copied the guide's boxes/divider lines into the output,
  so the guide was dropped and the slot layout is described in text (`Tools/art/noguide_note.txt`
  prepended to each prompt). Prompts actually sent: `.prompts-or/`.
- **Hi-res anchors.** `references/anchors/*-x8.png` are nearest-upscaled 117px cells (meant for pixel art);
  for this painted style the action rows used frame 0 cropped from each raw idle strip
  (`references/anchors-hires/`) plus `base-source.png` and `Tools/art/keeper_identity.txt`.
- **Extract with `--segmentation projection`** - in `down_walk` the poses' sticker outlines touch,
  so component segmentation could not find 6 parts.
- `side_idle` facing was locked by attaching a cleaned profile take (`raw/_rejected/side_idle_profile_cleaned.png`) as pose reference.

## Curation (`curation.json`)
- `down_walk` frames 1, 2, 4: erased a 54-74 px sliver of the neighbouring pose (projection split).
- `down_attack` all frames: scale 0.9, dy +13 to match head size / ground line of the other rows.

## Per-state verdict
| State | Verdict | Notes |
|---|---|---|
| down_idle | pass | breathing + blink |
| side_idle | pass | strict right profile; left = runtime mirror |
| up_idle | pass | |
| down_walk | experimental | readable gait, small lantern-hand drift |
| side_walk | experimental | readable gait |
| up_walk | experimental | |
| down_gather | pass | crouch and rise, lantern stays in hand |
| down_attack | best-effort | motion reads well, but rendering is cleaner/more saturated with a thicker outline than the other rows; candidate for regeneration |

Rejected takes live in `raw/_rejected/` locally (gitignored, not pushed).
