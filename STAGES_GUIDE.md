# Hidden in Foam — four-stage implementation

Open `project.godot` in Godot 4.7 and press **F6 on Main.tscn or F5**. Choose
Career → Packaging Warehouse. The project builds its reusable nodes from scripts;
the editor's Remote tree shows the full runtime hierarchy. No external model or
sound download is required. This guide supersedes older balance figures.

## Runtime scene tree and script ownership

```text
Main (Main.gd; Main.tscn is the project main scene)
├── SettingsManager          audio buses, settings persistence, key rebinding
├── StageManager             stage data, career checkpoint, tutorial, timed events
├── EquipmentAudio           SFX voices and procedural audio buffers
├── GameManager              timer, collection validation, wallet, upgrade authority
├── FactoryWorld             FactoryEnvironment.gd
│   ├── WorldEnvironment     fog, dark blue ambient background
│   ├── Moon / Work lamps / AisleFluorescent
│   ├── Warehouse props / RainGlass shader
│   └── StageDecor           StageProps.gd: pipes, drums, forklift, stacked freight
├── FoamMesh                 FoamMesh.gd; configurable foam/salt/sand heightfield
│   ├── Surface              ArrayMesh + FoamTerrain.gdshader
│   ├── FoamCollider         StaticBody3D + ConcavePolygonShape3D
│   └── Pearl nodes          spherical RigidBody3D objects, Pearl.gd
├── Player                   CharacterBody3D, Player.gd
│   ├── Camera3D
│   │   ├── HoldPoint / work light / UVBeam
│   │   └── Voxel hand + equipment models (ToolArt.gd)
│   └── Tools                input routing, UV, sonar, blower, vacuum
├── WasteBin                 validates proximity and obstruction before disposal
├── WashingStation           Station.gd + WasherArt.gd, waiting FIFO and clean tray
├── CollectionBox            Station.gd display mode
├── UpgradeStore / StoreUI   UpgradeStore.gd / UpgradeUI.gd
├── IntroCutscene            camera AnimationPlayer + necklace proxies
├── MenuManager              main, stage selection, pause, settings, catalog
├── HUD / MinimalHUD         enlarged vertical LEFT bar, icons, tutorial/event hint
└── DebugPanel               F3 developer tools; normal career saving remains enabled
```

All implementations are complete source files in `scripts/`, rather than isolated
snippets requiring manual signal wiring. `Main.gd` owns construction and connections.
Keep terrain and its ancestors unrotated at unit scale. Configure dimensions before
adding it to the tree; do not scale a collider after mesh generation.

## Stages and checkpoints

| Stage | Material | Diameter X × Z / height | Items | Career timer | Item reward / clear bonus |
|---|---|---|---:|---:|---:|
| Packaging Warehouse | Foam | 4.8 × 4.0 / 1.1 m | 3 | 15 min | $60 / $200 |
| Salt Depot | Salt | 10.4 × 9.0 / 2.6 m | 5 | 16 min | $100 / $350 |
| Construction Sand Pit | Sand | 12.4 × 10.0 / 3.3 m | 6 | 18 min | $140 / $500 |
| Master Storage | Foam | 14.0 × 11.0 / 4.5 m | 8 | 15 min | $180 / $700 |

`StageManager.STAGES` is the single stage configuration table. Winning a normal
shift unlocks the next stage and stores cash (including clear bonus) and equipment
in `user://career.cfg`. Return with R and select the next stage. Delay purchases
apply only to the current shift and are not carried forward. Losing or leaving
mid-shift restores the previous winning checkpoint; this is not a mid-shift save.
Replaying unlocked stages earns funds for further upgrades.

Sand requires Scoop II or a Vacuum in the saved loadout before entry. Salt can be
entered without those tools. Hardcore is selectable on unlocked stages 1 and 4:
8 and 10 minutes respectively, shallow targets, hand capacity only, no shop, no
upgrade effects, no career rewards. An ordinary work light remains available for
navigation; it has no UV detection capability.

The tutorial observes actions: dig → Q at waste bin → buy bucket → pick up → wash
→ deliver. First disposal grants $60 once per tutorial run so a bucket is affordable.
Hardcore skips the purchase step. Hints follow rebound Q/E controls and TH/EN.

Stages 2–4 roll outage, radio and emergency-drill events. Outages last 12 seconds,
hide warehouse lights, and retain the player's work light (F7). Radio/alarm messages
last 8 seconds with subdued audio cues; they do not deduct money or time. Stage 4
uses 35–55-second gaps after the initial 65 seconds; other stages use 65–95 seconds.
Timers pause with gameplay. Finishing a shift restores hidden lights.

## Terrain and physical interaction

`FoamMesh.excavate(world_point, radius, depth, max_volume)` lowers grid vertices
inside a radial falloff. Depth is divided by material resistance: foam 1, salt 1.65,
sand 2.4. Triangle-area weights integrate removed volume in cubic metres. When a
bucket is nearly full the cut is scaled to the remaining capacity. A full bucket
changes neither mesh nor collision. Mesh normals, triangle collider and sampling
use the same triangulation; exposed items unfreeze and roll on spherical colliders.

Continuous equipment accumulates delta time and rebuilds at most 10 times/second.
The blower uses radius 2.2 m, requested depth 0.70 m/s and a 0.50 m³/s volume cap;
it disperses material without disposal income. Vacuum uses radius 0.55 m, requested
depth 0.45 m/s, capped at 0.12 m³/s and available storage. These are limits, not
guaranteed volume rates: falloff, resistance and available material also constrain
removal. Blower 'force' is increased excavation, not simulated airborne debris.

This heightfield supports depressions only: no caves, overhangs, lateral material
transport or granular avalanche simulation. Larger maps should be tiled into chunks
before increasing resolution significantly; this prototype rebuilds the whole mesh.
Quality presets use 41×33, 65×53 and 81×65 grids. Quality changes apply on a new shift.

`FoamTerrain.gdshader` chooses warm off-white foam, cold crystalline salt or brown
grain/ripple sand through `material_kind`. UV remains shallow: maximum 0.28 m cover
above a sphere and 0.40 m accumulated material through the view ray. Walls block
scans. Upgrading UV increases brightness only, not penetration.

## Economy and equipment

Price at current level L: `ceil(base_price * pow(1.85, L))`. The first purchase uses
L=0. Levels are capped, and GameManager validates funds, mode, time and ownership.

| Upgrade | Base price | Cap | Effect |
|---|---:|---:|---|
| Bucket | 60 | 5 | 80 L × 1.75^(L−1), from 12 L hands; plastic then steel visuals |
| Scoop | 90 | 5 | radius .45+.12(L−1), depth .14+.045(L−1) metres |
| Gloves | 110 | 5 | .65 × .78^L seconds between strokes |
| UV | 140 | 5 | brighter eligible shallow glints |
| Detector | 100 | 1 | 12 m range, heading arrow, faster low pulses near targets |
| Blower | 280 | 1 | wide continuous surface clearing |
| Vacuum | 420 | 1 | continuous transfer into carry storage |
| Washer | 240 | 5 | input buffer 2+L; washing rate .67×(1+.35(L−1)) |
| Boots | 140 | 5 | movement bonus and reduced carrying slowdown |
| Battery | 110 | 5 | UV charge 45+30L seconds, stronger work light |
| Grabber | 120 | 5 | +.8L m reach, widened aim assistance for exposed items |
| Boss delay | 300 | 5 | +120 seconds per purchase, current shift only |

Disposal pays $90/m³ foam, $120/m³ salt, $160/m³ sand. Fractional credit remainder
is retained within a shift so splitting dumps cannot create free money. Item rewards
and clear bonuses are the primary progression income. These values are an initial
balance pass, not a claim that all completion times have been player-tested.

## Controls, washing and audio

WASD move, mouse look, Space jump/skip intro, left click dig (one stroke per press),
hold left click for powered equipment, 1–5/wheel select owned tools, E interact,
Q empty near waste bin, F throw, G drop, F7 work light, ESC pause, R main menu.
The grabber checks a cone and then a physical ray; it cannot retrieve buried items
or reach through walls. Throws sweep a sphere to avoid spawning inside geometry.

Manual washing holds E. An owned washer accepts dirty items into a finite FIFO,
processes them, and moves clean items to a separate tray. A full queue rejects the
deposit without losing the held object. Clean output never blocks processing; E with
empty hands retrieves tray output. Items may always be dropped/thrown during play.

EquipmentAudio creates short, filtered-noise/low-tone SFX locally and three looping
voices for blower, vacuum and washer. Dig, pickup, dump, drop, selection and story
cues use separate voices. Detector uses its existing soft 140 Hz tone. These are
procedural prototype sounds, not recorded machinery or voiceover. Master/BGM/SFX
buses independently control volume; loops stop on pause or shift completion.

## Lighting, UI and editor setup

1. Use Compatibility for browser builds. FactoryEnvironment enables volumetric fog
   only under Forward+; conventional depth fog is the browser fallback.
2. Keep ambient energy around .12 with dark blue color. Use a weak cool moon
   DirectionalLight3D and warm workbench SpotLight3D cones. Leave task lights stable;
   one distant fluorescent light gently dips rather than flashing repeatedly.
3. Place strong work lights around the mound and colored station lights around the
   washing, waste and delivery areas. Stage props stay in side aisles. The rain-glass
   shader animates the title background without needing physics raindrops.
4. Collision layers: 1 world, 2 player, 3 round items, 4 terrain, 5 stations. Player
   mask is world+terrain. Interaction rays include world+items+terrain+stations.
5. Keep the camera hand mesh nonphysical. ToolArt builds square brown pixel-textured
   arm and fist primitives in the lower-right view; no copied Minecraft texture is
   required. Round targets use pearl, brass and steel procedural materials.
6. MinimalHUD owns the only capacity progress bar (20×260 at left), 48-pixel icon
   slots and a top tutorial/event hint. Legacy HUD references remain hidden for
   compatibility. No bottom capacity bar is shown.
7. Settings includes English/ภาษาไทย, all three volume buses, quality, window options,
   mouse sensitivity/inversion and collision-checked key rebinding. Noto Sans Thai is
   bundled; do not remove the font from web exports. Preferences use settings.cfg.

## Verification and delivery

Run Godot with `--headless --path . --script tests/Stages.gd` for four-stage setup,
tutorial funding, sand prerequisites, outage/pause behavior, F3-compatible progression, delivery
and unlock checks. Smoke, Upgrades, Hardcore, WasherQueue and UVBalance cover their
respective interactions. MenuVisual, SettingsCheck, LocalizationCheck and DebugTools
need a rendered window because they capture screenshots.

For web delivery, export using the project's Web preset and run
`scripts/version_web.ps1` after each export. Source edits alone do not update GitHub
Pages. Career storage in a browser is local to that browser/profile and can be removed
by clearing site data. F3 is available for testing; using it does not block normal career saves or stage unlocks. Debug cash and purchased equipment therefore persist after a successful normal shift.

F3 → Unlock All Stages saves all four stage unlocks immediately, bypassing sand equipment requirements and allowing all stages in either mode for testing. Return through ESC → Main Menu to select a stage. This does not grant equipment or complete the current shift.

## Tailored environment update

Stage 1 adds taped cardboard boxes and packing-tape rolls. Stage 2 is now Rustic Salt Barn with timber walls, procedural salt crust, sacks, wooden barrels, a grinder and amber lanterns. Stage 3 is Construction Site Yard with an open roof, low perimeter barriers, scaffolding, cement sacks, cones, shovels and forklift. Stage 4 is Industrial Mega Depot with mixed strata: sand below 1 m, salt from 1–2.2 m, foam above 2.2 m. Exposed height drives both shader appearance and per-vertex resistance (2.4/1.65/1). These are horizontal strata, so lower outer slopes also expose dense materials. Mixed disposal pays the foam rate conservatively. The warmer pixel hand uses nearest filtering, brighter highlights and subtle texture-matched emission to remain readable in darkness. Props are stylized procedural geometry, not external photo assets.

## Results, brightness and stage shortcuts

Winning shows a results menu with Next Stage when the next stage is eligible. Sand still requires saved Scoop II/Vacuum unless testing unlock-all is active. Hardcore keeps its stage eligibility rules. Stage 4 shows campaign completion instead of a nonexistent stage 5. Settings is accessible from results and returns there. Scene brightness (0.5–2.5) changes ambient illumination immediately and is saved; baseline ambient is increased to 0.24 and moon energy to 0.18 for clearer navigation. F3 stage buttons 1–4 immediately start a fresh shift in the selected stage/current mode, persist test unlock-all and abandon unfinished shift progress; they do not grant victory rewards.
