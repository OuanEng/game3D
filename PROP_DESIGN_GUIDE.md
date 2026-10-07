# Hidden in Foam — architecture and setup

## Rich settings

`Main/SettingsManager` loads `user://settings.cfg` before environment generation
and saves preferences whenever changed. [SettingsManager.gd](scripts/SettingsManager.gd)
builds a scrollable panel inside MenuManager. Language is now an English/ภาษาไทย
dropdown inside **Settings**, reachable from the title and pause menus; the old
direct language buttons are removed. The saved language persists across launches.

- Audio: independent Master/BGM/SFX buses, volume sliders and application-focus
  muting. AmbientMusic routes to BGM; detector, intro and ventilation route to SFX.
- Display: 720p, 900p or 1080p window sizes, window/fullscreen and V-Sync.
  Fullscreen uses the desktop display size. These controls target desktop Godot;
  browsers can restrict window size, fullscreen and V-Sync requests.
- Foam quality: Low 41×33, Medium 65×53, High 81×65 vertices. A title-screen
  change applies when starting the shift. An in-game change waits until the next
  shift, preserving excavations and inventory. Render and physics mesh use the
  same grid. Quality changes are not an active-game terrain reset.
- Motion blur is optional camera-rotation screen-space blur in
  [CameraBlur.gdshader](shaders/CameraBlur.gdshader), under the HUD. It does not
  calculate per-object velocities. It is off by default and while paused.
- Controls: sensitivity, inverted Y, keyboard rebindings for movement, interaction,
  digging and tool slots. Click a binding, then press a key; Escape cancels.
  Conflicting/reserved keys are rejected. Reset controls restores defaults.
  F3 and Escape remain reserved; Q/E/F/G HUD hints follow their new bindings.

`tests/SettingsCheck.gd` verifies audio routing levels/focus restoration, controls,
quality staging and pause state, and captures the Thai settings panel. Existing
test scripts run in `.runtime` so test preferences do not overwrite normal saves.

The title and application name are **Hidden in Foam** in both languages.
The following older sections describe the gameplay systems; this Settings section
supersedes their language-button and persistence instructions.

## Game modes and Thai / English

The main menu offers **Normal** (15 minutes) and **Hardcore** (10 minutes).
`GameManager.Mode` is the authority: Hardcore returns level zero for every
upgrade, rejects purchases even with debug cash, permits only the hands slot,
and prevents the store UI from opening. Its pause menu omits Upgrades. The world
supply desk is disabled and the washing station uses manual Hold E washing.
The same 12-litre hand carry, Q waste disposal and F throwing remain available.
No pearls or terrain are removed to make the mode easier. The 600-second default
is a challenge setting, not a verified completion-time balance; tune the exported
`hardcore_seconds` after playtesting. Normal retains all twelve upgrades.

F3 developer tools remain available in both modes as requested. Infinite capacity,
clear foam and highlighting deliberately bypass normal challenge constraints for
testing; cash never unlocks Hardcore equipment. Returning to the title reloads
the scene and resets the mode and cheats.

Both the title and pause menu have a **ไทย / English** button. It calls
`TranslationServer.set_locale("th")` or `set_locale("en")`, without restarting
the shift. The locale stays selected across scene reloads within this app run;
the next app launch starts in English. Pause, inventory and timer state do not
change when switching languages.

- [Localization.gd](scripts/Localization.gd) installs translations before Main
  builds its UI. It is a static service, not an extra scene node.
- [th.json](localization/th.json) maps stable English source text to Thai. Static
  Godot labels/buttons use automatic translation; formatted prompts call `tr()`
  **before** substituting numbers. Keep `%d`, `%s` and related placeholders intact.
- MenuManager adds the two mode buttons and language buttons. UpgradeUI rebuilds
  its catalog on `NOTIFICATION_TRANSLATION_CHANGED`; item display names use
  `Pearl.localized_name()`. Gameplay IDs never become translated strings.
- SystemFont uses Tahoma, Noto Sans Thai or Leelawadee UI to render Thai glyphs
  and combining marks. Windows screenshots were checked. For a portable/web
  release, bundle a licensed Thai font and set it as the theme/default font;
  system fonts are not guaranteed on every target. Include `localization/*.json`
  in the export preset's non-resource include filter.

`tests/Hardcore.gd` checks purchase/UI/tool bypasses, manual washing, mode time
and a clean return to Normal. `tests/LocalizationCheck.gd` checks TH/EN switching,
unchanged paused game state, item names and live catalog translations, and writes
Thai menu/pause/shop screenshots to `.runtime/`.

## Latest: voxel hands and developer tools

Hands now use a single square-section BoxMesh arm/fist entering from the lower
right of the camera, without separate fingers, for a classic block-game silhouette.
`ToolArt.voxel_material()` generates a deterministic 16 × 16 dirt/glove texture
with nearest-neighbour filtering. No downloaded textures are required. Rubber
gloves recolour the pixels; level 3 adds a blocky reinforced knuckle plate.
The same builder creates the bare hand and every tool's GripHand. Existing
scoop animation moves their parent, so switching or upgrading preserves animation.

The runtime scene adds `Main/DebugPanel` (CanvasLayer, layer 60), implemented in
[DebugPanel.gd](scripts/DebugPanel.gd). Its PanelContainer contains buttons and
CheckButtons; separate collision-free marker spheres attach to the target items.
Press **F3 during active gameplay** to open it. F3, Escape or Close resumes play.
It cannot open over the title, intro, shop, pause/settings or end screen. The
panel alone processes while paused; the boss timer and world remain frozen.

| Debug action | Behaviour |
|---|---|
| +10,000 Cash | Adds credits and emits wallet_changed so the shop updates |
| Infinite Bucket Capacity | Player returns infinite capacity; actual excavated volume is still recorded and can be dumped with Q. HUD shows ∞ |
| Clear Foam Pile | Zeroes every height, rebuilds render mesh and collision together, then exposes items on the next physics tick. Gives no cash or carried foam |
| Highlight All Pearls | Shows bright green debug spheres through occlusion for remaining items; excludes held and returned objects |

Highlight is an explicit cheat using separate unshaded, no-depth-test markers.
It never changes UV penetration or the normal pearl shader. Turning it off removes
all markers. Clear Foam cannot be undone within a shift. Turning infinite capacity
off preserves carried foam even above the normal limit; Q disposal is required
before further digging. All cheats reset when the scene restarts or returns to
the main menu. They are included in exported builds for testing; remove the
DebugPanel instantiation in Main.gd to ship without the secret panel.

Run `tests/DebugTools.gd` with the graphical renderer for F3/Escape routing,
paused timer, cash, infinite carry, disable behaviour, clearing and highlight
checks. The test saves `.runtime/debug-panel.png`. The architecture and complete
source index below cover the remaining unchanged systems.

Open `project.godot` and press **F5** (run project). The entry scene is
`Main.tscn`; it opens the cinematic main menu. F6 runs only the selected scene.
These are complete runnable scripts, with procedural models and generated audio;
no external model packs are needed. See [LARGE_FOAM_GUIDE.md](LARGE_FOAM_GUIDE.md)
for the full map, physics layers, excavation and UV rules.

## Architecture and full source

```text
Main / Main.gd
├── GameManager — timer, rewards, twelve upgrades
├── FactoryWorld — warehouse, lighting, rain window, ventilation
├── FoamMesh — ArrayMesh heightfield + matching static collision
│   └── Eight round items — Pearl.gd, spherical mesh and collision
├── Player — CharacterBody3D, capsule, camera, interaction ray queries
│   ├── Camera3D
│   │   ├── HoldPoint, work light, UVBeam, HandsFillLight
│   │   ├── bare hand and carried foam
│   │   ├── PortableBucket / movable foam fill
│   │   └── ToolModel_0…4 / GripHand
│   │       ├── scoop, UV flashlight, detector, blower, vacuum
│   │       ├── detector LED0…7
│   │       └── blower AirSwirl (CPUParticles3D)
│   └── Tools — tool selection and effects
├── WasteBin — Q disposal within range and clear sight
├── WashingStation
│   ├── belt anchor — carries item during automatic cleaning
│   └── ConveyorWithWaterJets / WasherArt.gd
│       └── belt slats, rollers, pipe gantry, water jets, soap bubbles
├── CollectionBox — accepts clean items
├── UpgradeStore + StoreUI
├── UI / MinimalHUD — left vertical capacity bar, item/tool icons
├── IntroCutscene — camera animation, captions, skip
├── MenuManager — main menu, pause, settings, upgrade catalog
└── AmbientMusic — mellow filtered ambient loop
```

| System | Complete implementation |
|---|---|
| Scene composition and input bindings | [Main.gd](scripts/Main.gd) |
| Main menu, ESC pause, cursor capture | [MenuManager.gd](scripts/MenuManager.gd) |
| Minimal icon HUD and capacity bar | [MinimalHUD.gd](scripts/MinimalHUD.gd) |
| Movement, jump, Q dump, carrying | [Player.gd](scripts/Player.gd) |
| Tool input, shallow UV, detector, blower, vacuum | [Tools.gd](scripts/Tools.gd) |
| Procedural view models and upgrade appearance | [ToolArt.gd](scripts/ToolArt.gd) |
| Excavation, vertex/collider updates, item placement | [FoamMesh.gd](scripts/FoamMesh.gd) |
| Item exposure, physics, holding, cleaning | [Pearl.gd](scripts/Pearl.gd) |
| Item material | [PearlUV.gdshader](shaders/PearlUV.gdshader) |
| Foam surface and localized UV hints | [FoamTerrain.gdshader](shaders/FoamTerrain.gdshader) |
| Washer and return interactions | [Station.gd](scripts/Station.gd) |
| Moving belt, water, soap | [WasherArt.gd](scripts/WasherArt.gd) |
| Prices, upgrade limits, timer | [GameManager.gd](scripts/GameManager.gd) |
| Shop interface | [UpgradeUI.gd](scripts/UpgradeUI.gd) |
| Environment / rain / music | [FactoryEnvironment.gd](scripts/FactoryEnvironment.gd), [RainGlass.gdshader](shaders/RainGlass.gdshader), [AmbientMusic.gd](scripts/AmbientMusic.gd) |

## Prop setup and progression

Each target uses a SphereMesh and SphereShape3D of radius 0.095 m. Keep the
physics radius unchanged when replacing the visuals: exposure and UV use this
radius. Cream pearls have a glossy blue iridescent rim; brass marbles have a
warm metallic grain; steel bearings have dark metal and an oily violet rim.
Residue hides their clean finish until washing. Pearl iridescence approximates
refraction; it is not physical screen-space refraction. This version selects
brass marbles rather than transparent glass ornaments.

`ToolArt` is a collision-free visual builder. Player camera children do not
participate in raycasts or push the player. Replace these visual children with
imported models while retaining their roots and tool selection logic.

| Upgrade | Appearance |
|---|---|
| No tools | Blocky voxel hand with pixel dirt and a short scoop animation |
| Bucket levels 1–2 | Red plastic pail, open top, wire handle, rising foam fill |
| Bucket levels 3–5 | Metallic steel pail; gameplay capacity continues to grow |
| Scoop levels 1–5 | Wooden handle, rusty blade with raised sides, increasing width |
| Gloves levels 1–2 / 3–5 | Orange rubber / reinforced knuckle protection on hands and tool grips |
| UV | Dark-purple body, grip rings, violet emissive lens |
| Detector | Green counter body, eight pulsing LED cells, circular sensor |
| Blower | Yellow housing, vents, black nozzle, curling air particles while active |
| Vacuum | Teal shop-vac body, curved ribbed hose, metal nozzle |
| Auto washer | Steel conveyor, moving slats, water jets and soap during washing |

The hose is a fixed curved visual, not a physics rope. Dirt and rust are
procedural material/geometry details, not imported texture maps. Blower particles
are cosmetic air: removed foam still deforms the terrain and never becomes loose
physics chunks. Models rebuild only when their relevant upgrade is bought;
inventory volume and current selection remain intact.

## Lighting setup in the editor

1. Run the project and use the **Remote** tree to inspect the generated nodes.
   Persist changes in `FactoryEnvironment.gd`; Remote edits disappear on restart.
2. Use a dark blue WorldEnvironment background `(0.008, 0.014, 0.025)` and ambient
   energy `0.12`. Keep enough ambient light to distinguish tool silhouettes.
3. Moonlight is a cool DirectionalLight3D, energy `0.12`, rotation `(-35,-30,0)`.
   Enable shadows for structural gaps and pillars.
4. WorkbenchLamp is a warm SpotLight3D above the pile, energy `5`, angle `54°`.
   Dedicated rinse and return lamps identify the service area. Keep the main
   task light steady; only the secondary fluorescent fixture flickers.
5. Desktop Forward+ automatically enables volumetric fog, density `0.018`,
   length `36 m`, filmic tonemapping and SSAO. Compatibility uses conventional
   fog at density `0.008`; this is the web-friendly path used for visual tests.
6. The rain shader animates a window quad. The menu camera frames this warehouse;
   the shared menu manager freezes gameplay and releases the cursor.
7. HandsFillLight supplies a subtle camera-relative fill, energy `0.45`, radius
   `1.5 m`, without shadows. UVBeam remains a separate purple spotlight.

## Gameplay and economy

WASD/mouse/Space move, look and jump. Click to dig; hold click for powered tools.
Select with 1–5 or the wheel. Q dumps foam near the waste bin; F throws a held
item forward and G drops it gently. A sphere sweep prevents spawning it inside
walls; release is refused if the camera itself is obstructed. F6 now toggles
light flicker, freeing F for throwing. E picks up and interacts; hold E at the rinse station for manual washing.
After buying the automatic washer, E places a dirty item into the FIFO belt queue.
Level 1 holds three items including the one washing; level 5 holds seven.
Each extra level adds 35% of the base wash speed (about 2.99 seconds at level 1,
1.24 seconds at level 5). Completed items move into anchored slots on the clean
tray automatically; an occupied tray never blocks the belt. E with empty hands
retrieves the oldest clean item. When the input buffer is full, a rejected item
stays in the player's hand and can be thrown with F. Clean items can also be
placed directly on the tray. Station.gd owns all queue and tray anchors; items
remain frozen with physics disabled until retrieved or dropped. The tray has
stacked overflow rows so it can hold all level targets without loss.

The HUD has only one foam-capacity display: the vertical bar at the left edge.
The bottom bucket-fill icon and horizontal UV-charge bar are removed; tool and
held-item icons remain. ESC pauses and opens
Resume, Upgrades, Settings and Main Menu.

The pile remains a 14 × 11 m, 4.5 m high heightfield. Brush edits scan a local
grid region, subtract a capacity-limited volume and rebuild matching geometry
and collision. It supports lowering the surface, not tunnels or overhangs.
Items remain frozen while buried and become physical when exposed.

UV eligibility requires less than 0.28 m of cover and less than 0.40 m of foam
along the viewing ray, plus cone, range and wall checks. Higher levels brighten
eligible hints without increasing penetration. Foam remains opaque; a localized
surface glow indicates a shallow sphere rather than rendering deep items through
the whole mountain.

All twelve upgrades remain in GameManager. Prices are
`ceil(base_price * pow(2.4, current_level))`. Detector, blower and vacuum
are one-time purchases; washer, bucket, scoop, gloves, UV, boots, battery, grabber and
boss delay have five levels. Buying delay adds 120 seconds. Audio remains the
soft filtered ambient bed and fixed low-pitched detector pulses.

## Verification

`tests/WasherQueue.gd` verifies three-item buffering, rejection without losing
ownership, repeated washing into an occupied tray, FIFO retrieval, upgraded
buffer/speed, throw velocity and F input mapping.

Run Godot with `--headless --path . --script tests/Smoke.gd`, then repeat for
`Upgrades.gd` and `UVBalance.gd`. Run `DumpInput.gd` without `--headless` because
it requires captured mouse input. `PropVisual.gd` also runs with the renderer
and saves screenshots of hands, both buckets, shovel, each powered tool
and the active washer to `.runtime/`. Test captures grant credits only inside
that test; normal play still starts with no tools and zero credits.
