# Nông Trại Hoang Dã (Godot)

A 3D farming and survival game: farm by day, survive the dark at night, and lasso wild animals to tame them. Tamed animals work the farm (milk, wool, truffles, watering, guarding at night) and the big ones can be ridden.

Built with **Godot 4.7** (GDScript). The world, UI and game logic are created in code from `main.tscn`.

## Play

1. Download Godot 4.7 (standard version, not .NET) from https://godotengine.org/download. It is a single executable; no account needed.
2. Open Godot, click **Import**, choose `godot/project.godot` from this repository.
3. The first import of the 3D models takes a minute. Press **F5** (or the ▶ button) to play.

To make a standalone game: **Project → Export**, add Windows/Linux/macOS, and let Godot download the export templates.

## Controls

| Key | Action |
|---|---|
| WASD / arrows | Move (Shift to run) |
| Space / left click | Use the selected tool |
| 1–0 | Select hotbar slot · R cycles seeds and food |
| F | Ride / dismount a tamed horse, zebra, llama, wolf or dragon |
| C | Bag and crafting · H herd and feeding trough · Esc menu |
| Q / E or right-drag | Rotate camera · mouse wheel zooms |

## Project layout

- `scripts/data.gd` – crops, items, recipes, seasons and the animal roster (jobs, diets, riding speed)
- `scripts/world.gd` – 64×64 tile map, ground texture, water, scenery (batched with MultiMesh), buildings, crops
- `scripts/main.gd` – player, animals and AI, lasso taming, riding, survival, day/night, saving
- `scripts/ui.gd` – HUD, hotbar, taming bar and menus
- `scripts/models.gd` – model loading, size normalisation, MultiMesh pools, animation helper
- `tools/logic_test.gd` – headless smoke test: `godot --headless --path godot -s tools/logic_test.gd`
- `tools/play_test.gd` – scripted run that saves screenshots (needs a display)

## Credits

- 3D models: [Quaternius](https://quaternius.com) (Ultimate Nature, Crops, Farm Animals, Animal Pack Vol.2, Animated Monsters, Ultimate Animated Characters, Medieval Village, Survival), CC0. See `assets/LICENSE-quaternius.txt`.
- Fonts: Be Vietnam Pro and Baloo 2, SIL Open Font License.
