# Myne

A top-down mining dungeon crawler built in Godot 4.2.

Mine ore, build bots, merge into mech suits, and uncover the mystery of the crystal civilization below.

## Play

- **Web:** [bajaj.itch.io/myne](https://bajaj.itch.io/myne)
- **Android:** Download APK from itch.io

## Development

### Requirements
- Godot 4.2.2+

### Run Locally
1. Open the project in Godot
2. Press F5 to run

### Build
Builds are automated via GitHub Actions. Push to `main` to trigger:
- Web export → itch.io (html5 channel)
- Android APK → itch.io (android channel)

### Setup CI/CD
1. Create a project on [itch.io](https://itch.io) named "myne"
2. Get your butler API key from [itch.io API keys](https://itch.io/user/settings/api-keys)
3. Add `BUTLER_API_KEY` as a GitHub repository secret

## Design Docs
See [docs/design/](docs/design/) for the full game design documentation.
