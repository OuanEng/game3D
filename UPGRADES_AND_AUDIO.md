# Minimal HUD, audio and twelve upgrades

This guide supersedes the economy, HUD and portable-washer sections in
NIGHT_SHIFT_GUIDE.md. The full executable GDScript lives in scripts/; F5 starts
Main.tscn and its cinematic Main Menu. The form copy is the user-facing project.

## Scene structure and ownership

```text
Main / Main.gd
├── FactoryWorld / FactoryEnvironment.gd
│   ├── WorldEnvironment + moon/work lights
│   ├── Rain window / RainGlass.gdshader
│   └── Steel warehouse + ventilation audio
├── AmbientMusic / AmbientMusic.gd (always processes)
├── GameManager / GameManager.gd (wallet, levels, timer, collection authority)
├── FoamMesh / FoamMesh.gd
│   ├── ArrayMesh surface + static triangle collider
│   └── InteractiveItems / Pearl.gd (pearls, relays, fuses)
├── Player / Player.gd (CharacterBody3D)
│   ├── Camera3D / HoldPoint / work light
│   └── Tools / Tools.gd (five slots, UV, pulse, digging)
├── WasteBin / WasteBin.gd
├── WashingStation / Station.gd / belt anchor
├── CollectionBox / Station.gd
├── UpgradeStore + StoreUI / UpgradeUI.gd
├── UI / MinimalHUD.gd (vector icons, carry fill, item silhouette)
├── IntroCutscene / IntroCutscene.gd
└── MenuManager / MenuManager.gd
    ├── Main: Start / Upgrades catalog / Settings / Quit
    └── Pause: Resume / Upgrades shop / Settings / Main Menu
```

Menu panels are built in code and reuse one container. The HUD's old controls
are retained but hidden for compatibility; MinimalHUD draws the visible interface.
Hover descriptions are intentionally absent during play: contextual E prompts
appear only while aiming at interactable objects. Full descriptions live in the shop.

## Economy and effects

`price = ceil(base_price * pow(2.4, current_level))`. Levels reset each shift.
Unlock-only purchases cap at one; other upgrades cap at five. Prices and caps
are enforced by GameManager, not only by the UI. No real-money transactions occur.

| Upgrade ID | Base credits | Cap | Effect |
|---|---:|---:|---|
| bucket | 40 | 5 | 0.5 × 1.6^(level−1) m³; hands hold 0.012 m³ |
| scoop | 35 | 5 | Radius 0.75 + 0.12 × (level−1); depth 0.30 + 0.05 × (level−1) |
| gloves | 80 | 5 | Dig cooldown 0.65 × 0.78^level seconds |
| uv | 25 | 1 | Slot 2 exposes soft glints through a thin dithered layer |
| detector | 20 | 1 | Slot 3, low 140 Hz pulses, spacing 1.2–0.28 seconds |
| blower | 250 | 1 | Slot 4 disperses surface foam, radius 1.15 m |
| vacuum | 400 | 1 | Slot 5 continuously collects foam, up to 0.12 m³/s |
| auto_washer | 150 | 1 | E places held item on wash belt, E retrieves it when clean |
| boots | 120 | 5 | +12% movement/level, reduces carry slowdown |
| battery | 100 | 5 | +30 s UV charge/level; brighter camera work lamp |
| grabber | 180 | 5 | +0.65 m pickup reach/level, with occlusion checks |
| delay | 200 | 5 | Each purchase adds 120 seconds to the boss clock |

Bucket example: 40, 96, 231, 553, 1328 credits. The 12-litre hand stage earns
credits by disposal, one credit per foam litre rounded per disposal. Depositing
a cleaned item earns 25. Blown-away foam yields no credits; vacuumed foam only
earns credits when disposed. The first scoop is available independently of a bucket.
These are initial tuning values, not a claim of a fully playtested economy.

## Input, pause and audio

WASD / mouse / Space move, look and jump. Slots 1–5 or wheel switch owned tools.
LMB clicks dig (with cooldown), held LMB scans/blows/vacuums. E interacts,
held E manually washes, G drops. Escape opens Pause. Its shop preserves pause
and visible cursor on close; the physical desk shop uses live gameplay time.
Settings offers mouse sensitivity and global mute; settings are session-only.

AmbientMusic generates a 16-second looping low synth chord with a soft bass
pulse at startup. Its one-pole low-pass removes bright content, and short boundary
fades suppress clicks. It continues during Pause. All carriers are below 165 Hz;
detector pulses are 140 Hz with a fixed pitch and no overlapping retriggers.
The intro impact was lowered to 110 Hz. Generated PCM avoids external asset
licensing and downloads. This is a synthesized ambient prototype, not a mastered
Lo-Fi recording. Audition on speakers/headphones and adjust volume_db for taste.

UV has 45 seconds of base charge and recharges at twice real time while switched
off. The ordinary work lamp stays on; the battery upgrade affects brightness and
UV runtime. Nothing consumes battery or game time while SceneTree is paused.

## Excavation and limitations

FoamMesh.excavate remains the volume-conserving heightfield implementation.
Player owns carry storage; Tools sends radius, depth and remaining capacity.
Vacuum adds only the actual removed volume; blower does not alter storage.
The mesh and collider rebuild after a cut, with no loose foam rigid bodies.
It supports surface pits, not tunnels or overhangs. Continuous tools rebuild
the prototype grid each physics tick: chunk and throttle rebuilds for larger levels.
The washing belt is a moving anchor on the existing station, not an industrial
conveyor asset. All art, icons and sound are procedural placeholders.

## Verification

Run --headless --path . --script res://tests/Smoke.gd for terrain, carry,
pickup, collection and game-state checks. Run tests/Upgrades.gd for all 12
purchases, exponential pricing, caps, pause-shop behavior, grabber reach,
boss extension and station cleaning. Run tests/MenuVisual.gd with a graphical
renderer to capture the menu, minimalist HUD and scrollable shop.
