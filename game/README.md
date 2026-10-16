# Nông Trại Hoang Dã

A 3D browser game mixing Harvest Moon-style farming, Don't Starve-style survival and Pokémon-style creature collecting. Built with Three.js r128.

## Run locally

The game loads GLB models from `models/`, so open it through a web server rather than `file://`:

```sh
cd game
npx http-server -p 8080
# then open http://localhost:8080
```

If the models fail to load, the game falls back to simple built-in shapes.

## Credits

3D models: [Kenney](https://kenney.nl) (Cube Pets, Mini Characters, Nature Kit, Survival Kit), CC0. See `models/LICENSE-kenney.txt`.
