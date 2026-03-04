# horizOn Example — Godot

> **Status: Under Construction**
> This project is actively being developed. Screenshots and a playable demo will be added soon.

**Seagull Storm** is a mini Vampire Survivors-style roguelike built with Godot 4.x. It serves as a comprehensive example project demonstrating all 9 [horizOn](https://horizon.pm) SDK features in a real, playable game.

## Features Demonstrated

| # | horizOn Feature | In-Game Usage |
|---|----------------|---------------|
| 1 | **Authentication** | Guest, Google, Email sign-in/sign-up on title screen |
| 2 | **Leaderboards** | Score submission, Top 10 display, player rank |
| 3 | **Cloud Save** | Persistent coins, upgrades, highscore across sessions |
| 4 | **Remote Config** | All game balancing (enemies, weapons, upgrades, wave timing) |
| 5 | **News** | In-game news feed in hub and pause menu |
| 6 | **Gift Codes** | Code redemption for coin rewards |
| 7 | **Feedback** | Bug reports and feature requests from in-game |
| 8 | **User Logs** | Aggregated run summary logged at game over |
| 9 | **Crash Reporting** | Session tracking, breadcrumbs, exception capture |

## About the Game

You play as a seagull on a beach, surviving waves of crabs, jellyfish, and pirate seagulls. Auto-attack with upgradeable weapons, collect XP shells to level up, and try to survive the final boss — a giant octopus.

- **Genre:** Vampire Survivors-style auto-attack roguelike
- **Session Length:** 3–5 minutes
- **Art Style:** Pixel art (32x32 sprites), placeholder graphics included
- **Font:** Press Start 2P

## Getting Started

1. Clone this repository
2. Open the project in Godot 4.x
3. Configure your horizOn API key in the SDK settings
4. Run the project

## Project Structure

```
addons/horizon_sdk/    # horizOn SDK addon
assets/                # Sprites, fonts, audio
scenes/                # Godot scenes (.tscn)
scripts/               # GDScript files
resources/             # Theme, configurations
project.godot          # Project configuration
```

## Requirements

- [Godot Engine 4.x](https://godotengine.org/)
- [horizOn Account](https://horizon.pm) (free tier works)
- [horizOn SDK for Godot](https://github.com/ProjectMakersDE/horizOn-SDK-Godot)

## Related Projects

- [horizOn-SDK-Godot](https://github.com/ProjectMakersDE/horizOn-SDK-Godot) — The SDK this example uses
- [horizOn-Example-Unity](https://github.com/ProjectMakersDE/horizOn-Example-Unity) — Same game in Unity
- [horizOn-Example-Unreal](https://github.com/ProjectMakersDE/horizOn-Example-Unreal) — Same game in Unreal Engine

## License

MIT
