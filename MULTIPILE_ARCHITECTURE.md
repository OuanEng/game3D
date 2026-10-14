# Hidden in Foam — multi-pile update

Implemented 14 October 2026. Open `project.godot` and press **F5**. The entry scene
is `Main.tscn`; its scripts build the runnable nodes, so no manual wiring is needed.
Use **F3 → Unlock all / Stage 4** to inspect the final layout. The Web export is included under `docs/`; pushes to branch `new` deploy it through GitHub Pages.

## Scene structure and ownership

```text
Main (Main.tscn / scripts/Main.gd)
├── SettingsManager: language, audio buses, brightness, graphics, mouse, bindings
├── StageManager: career checkpoints, stage selection, interactive tutorial
│   └── DynamicEvents: effects and cleanup; simulation-time event deadlines
├── GameManager: clock, cash, purchase authority, battery, registered targets
├── EquipmentAudio: motor loops, washing, purchases, warnings and event cues
├── FactoryWorld: stage shell, lamps, WorldEnvironment, imported/procedural props
├── FoamMesh: FoamMesh.gd, material=Foam, 3 pearls in stage 4
│   ├── Surface: MeshInstance3D + FoamTerrain.gdshader
│   ├── FoamCollider: StaticBody3D + generated triangle CollisionShape3D
│   ├── Label3D: localized material sign
│   └── Pearl_*: RigidBody3D + SphereMesh + SphereShape3D
├── MaterialPile1: same hierarchy, Sand, 3 pearls (stage 4 only)
├── MaterialPile2: same hierarchy, Salt, 2 pearls (stage 4 only)
├── Player: CharacterBody3D / Player.gd
│   └── Camera3D: hold point, bright voxel hands, tool models, work/UV lights
│       (Tools.gd routes input and raycasts to the actual hit pile)
├── WasteBin: Q/E disposal, with per-material inventory accounting
├── WashingStation: manual sink, finite intake queue, separate clean output tray
├── CollectionBox / UpgradeStore
├── IntroCutscene / AmbientMusic
├── HUD: MinimalHUD.gd, one LEFT capacity bar, timer and cash labels
├── StoreUI: UpgradeUI.gd, equipment plus recharge consumable
├── MenuManager: title, stages, settings, pause, results/next stage
└── DebugPanel: F3 cash, capacity, all-pile clear, highlight, stage shortcuts
```

`foam_piles` is authoritative for terrain; `GameManager.registered` is authoritative
for targets. `foam_mesh` is retained as the first-pile compatibility reference only.
Each pearl tracks its current `foam_container`; cross-pile reburial updates that
reference and UV hints go to the destination shader. Held/washed/displayed objects
never participate in terrain reburial. Escaped physics objects recover before burial
tests, so the ground plane cannot trap an item below the floor.

## Final-stage setup

`StageManager.pile_layouts()` defines these independent surfaces, in metres:

| Material | Center X,Z | Radii X,Z | Height | Targets |
|---|---|---|---:|---:|
| Foam | -4.1, -1.0 | 3.1, 2.7 | 2.8 | 3 |
| Sand | 4.1, -1.0 | 3.1, 2.7 | 2.8 | 3 |
| Salt | 0, -6.3 | 3.0, 2.2 | 2.2 | 2 |

Keep all terrain nodes unrotated and unit scale. Edit radius/height data instead of
scaling nodes. Clear aisles separate the three piles; washing, shop and delivery
remain at the front. The final stage challenges coverage/material resistance and
events rather than retaining the previous single mountain's total volume.
Stages 1–3 retain their warehouse, salt-barn and construction environments.

1. The supplied project already names physics layers: World=1, Player=2,
   Pearls=3, Foam=4, Stations=5. Layer bits are 1, 2, 4, 8, 16.
2. Terrain bodies use bit 8; player mask is 1|8; free pearl mask is 1|4|8.
   Interaction rays include 1|4|8|16. Held objects have no collision.
3. Each triangle contributes its horizontal area/3 to vertex volume weights.
   Digging scales the entire cut to available carry volume before rebuilding the
   mesh and collider in the same physics callback. Sand resistance=2.4,
   salt=1.65, foam=1.0. A heightfield supports excavation, not tunnels/overhangs.
4. Avalanche performs four conservative neighbour-transfer sweeps. It moves
   existing cubic metres downhill into lower areas, excludes the player's 0.9m
   footprint, and awards no money. It rebuilds only the selected pile.
5. All materials use `shaders/FoamTerrain.gdshader`; pearl finishes use
   `PearlUV.gdshader`. UV requires <0.28m cover and <=0.40m total material traversed
   across all piles. A buried item remains unpickable until exposed.

## Battery and economy

There are **12 equipment upgrades plus one repeatable recharge purchase**.
`GameManager` validates running state, Hardcore restrictions, ownership, balance
and capacity; a UI button cannot bypass these rules.

| Purchase | Initial cost | Scaling/effect |
|---|---:|---|
| Blower | $280 | Single unlock; 18 seconds of continuous motor runtime |
| Battery capacity | $180 | ceil(base × 1.85^level), 5 levels; +8 seconds per level |
| Recharge blower pack | $70 | ceil(base × 1.35^purchase_count); restores current capacity |

Motor time drains whenever the blower trigger is held, including aiming into empty
space. Actual excavation receives only the funded time, including the last partial
tick. Cuts batch at 10 Hz; empty batteries stop cutting, airflow and motor SFX.
A soft 160 Hz one-shot warns once below 20%; purchasing a recharge resets the warning.
Switching tools, pausing or purchasing capacity does not refill the blower. Capacity
still extends the UV battery and work-light brightness; UV's separate slow recharge
remains unchanged. A fresh shift starts with full blower capacity. Successful career
checkpoints preserve equipment levels and the recharge purchase counter.

Recharge requires an owned blower and non-full charge. It is a paid recharge service,
not a physical spare-pack inventory. Cost arithmetic caps extreme prices at $1B.
All other equipment retains 1.85x scaling. Mixed bucket contents track volume per
material: foam=$90/m3, salt=$120/m3, sand=$160/m3. Fractional payouts carry forward;
changing piles or splitting dumps cannot manufacture credits. Blower removal grants
no disposal income. Career pacing still needs extended human playtesting.

## Event lifecycle

The tutorial has no random events. Later stages schedule after an initial 65s;
subsequent gaps are 65–95s, or 35–55s in the finale, measured between active events.
Only one event runs at a time. Pause freezes deadlines. Completing/losing a shift,
or replacing an event restores lights, fog and detector availability.

| Event | Duration | Gameplay consequence |
|---|---:|---|
| Power outage | 14s | Hide previously visible non-player lights; F7 work light and owned UV remain usable |
| Avalanche | 5s notice | One randomly selected pile relaxes immediately; excavations may refill |
| Boss patrol | 15s warning | Clear carried material and wash or hide dirty exposed items behind physical cover |
| Dust storm | 18s | Fog thickens within sand/salt zones; clears when leaving or event ends |
| Sensor glitch | 12s | Suppress detector strength, direction feedback and beep; restores afterward |

Patrol tests line of sight from the front doorway against world, terrain and stations.
Buried/delivered items and items already on the wash belt are exempt. Exposed dirty
items and visible carried trash cause one **30-second penalty**, never repeated for
the same warning. A clean inspection has no penalty. This is a timed inspection
mechanic, not an animated boss NPC. Avalanche is a discrete heightfield relaxation,
not a granular particle simulation. Radio/alarm audio remains procedural, not voiced.

## HUD, controls, lighting and assets

Cash (top-left) and timer (top-right) use 38px emboldened Thai-capable text, dark
plates and outlines; the timer changes colour below a minute. Item count and numeric
blower battery sit below the plates. Capacity has exactly one vertical bar on the
left. F throws the held item, G drops, Q dumps near the waste bin, E interacts;
1–5/wheel select owned tools. Hardcore remains hands-only with no shop.

For the night look, `FactoryEnvironment.gd` provides cool ambient light, warm task
spotlights, rain glass and restrained background hum. Brightness remains in Settings.
Compatibility/Web uses regular fog; Forward+ also supports the volumetric density
change. Do not promise volumetric rendering on WebGL. Settings and all new prompts
use TranslationServer; Thai glyphs are bundled instead of depending on OS fonts.

See `FREE_ASSET_SETUP.md` for the bundled Kenney glTF models and license paths.
Import additional glTF/GLB models into `assets/`, inspect scale/materials in Godot,
and attach simple static collision to large props. Keep material pile footprints
and service aisles free of prop collision. The bright voxel hands, sink and tools
are procedural project code; no original Minecraft assets are bundled.

## Independent Sub-Agent QA

The `feature_qa` sub-agent inspected the implementation and identified two defects:
below-floor recovery order and cross-pile UV hint ownership. Both were fixed and
added to `tests/MultiPileEvents.gd`. Scores are implementation assessments, not
production certification or evidence of listening quality.

| Category | /10 | Evidence / remaining limit |
|---|---:|---|
| Background music / mood | 7 | Existing quiet 80 BPM, 12-second mono procedural loop; no human listening evaluation |
| Equipment/action SFX | 8 | Separate motors, water, purchase and battery warning cues; speaker/headphone audition pending |
| HUD readability | 9 | Large bold timer/cash; parent inspected rendered EN/TH HUD and corrected overlapping secondary readouts |
| Voxel hand | 8 | Bright pixel palette and block geometry; procedural animation rather than authored rig |
| Terrain | 8 | Volume-bound cuts and conservative avalanche; full collider rebuild remains a performance limit |
| Washing / overflow | 9 | FIFO intake, ownership-preserving rejection, separate output tray; regression suite passes |
| Economy / battery | 8 | Funded partial ticks, no free capacity recharge, escalating paid refills; long-run pacing untested |
| Stage diversity | 9 | Separate foam/sand/salt finale plus prior themed environments; common service layout |
| Dynamic events | 8 | Five functional effects with restore paths and bounded penalty; narrative/long-run pacing still limited |
| Localization / settings | 8 | TH/EN font and new translations; existing brightness/audio/input settings tested |

Mean **8.2/10**. The reviewer inspected source; the parent ran tests and visual checks.
No reviewer claimed to audition the music or certify browser frame rates.

## Verification

Godot 4.7.1 Compatibility: headless integration checks passed for MultiPileEvents,
Stages, Smoke, UVBalance, Upgrades, WasherQueue, Hardcore, AudioWashQA and WebMouse.
Rendered checks passed for DumpInput (Q), DebugTools (F3), SettingsCheck,
LocalizationCheck, and ResultsBrightness. MultiPileVisual captures EN/TH overview
and shop screenshots under `.runtime/`. Input/mouse-capture tests must run rendered;
headless cannot emulate captured mouse input correctly.

Avalanche relaxation plus collider rebuild measured roughly 26–44ms per selected
pile in local headless tests. This is not a rendered or browser frame-rate benchmark;
rare event updates may hitch. Tests can report ObjectDB exit leak warnings (up to 26
in these runs); this update does not claim leak-free teardown. The Web export has been refreshed for publication; browser performance has not been benchmarked.

The complete runnable GDScript is in `scripts/`; this guide describes those files,
not disconnected snippets requiring manual assembly.
