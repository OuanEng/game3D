# Night Shift — large foam mountain, Q disposal and balanced UV

This is the current architecture. It supersedes the map sizes, UV transparency
and disposal controls in the previous guides. Open project.godot and press F5.
All scenes are assembled by Main.gd; inspect the Remote scene tree while running.
Complete runnable code is in scripts/ and shaders/, not pseudocode snippets.

## Scene tree

```text
Main (Node3D / Main.gd)
├── GameManager (Node / GameManager.gd)
├── FactoryWorld (Node3D / FactoryEnvironment.gd)
│   ├── WorldEnvironment
│   ├── Moonlight + WorkbenchLamp + service lamps
│   ├── warehouse meshes / static collisions / rain window
│   └── ventilation AudioStreamPlayer
├── FoamMesh (Node3D / FoamMesh.gd)
│   ├── Surface (MeshInstance3D / ArrayMesh + FoamTerrain.gdshader)
│   ├── FoamCollider (StaticBody3D / ConcavePolygonShape3D)
│   └── Pearl_01 … Pearl_08 (RigidBody3D / Pearl.gd)
│       ├── MeshInstance3D (SphereMesh + PearlUV.gdshader)
│       └── CollisionShape3D (SphereShape3D)
├── Player (CharacterBody3D / Player.gd)
│   ├── capsule collision
│   ├── Camera3D / HoldPoint / work light / tool models
│   └── Tools (Node3D / Tools.gd + soft sonar AudioStreamPlayer)
├── WasteBin (StaticBody3D / WasteBin.gd, group: waste_bins)
├── WashingStation (Station.gd / moving wash-belt anchor)
├── CollectionBox (Station.gd)
├── UpgradeStore (UpgradeStore.gd)
├── StoreUI (CanvasLayer / UpgradeUI.gd)
├── UI (CanvasLayer)
│   └── MinimalHUD (Control / MinimalHUD.gd)
│       ├── LeftCapacityBar (ProgressBar, bottom-to-top fill)
│       └── CapacityReadout (Label, percentage + Q)
├── IntroCutscene (IntroCutscene.gd / Camera3D + AnimationPlayer)
├── MenuManager (CanvasLayer / MenuManager.gd)
│   └── shared Main / Pause / Settings / catalog panel
├── cinematic title Camera3D
└── AmbientMusic (AudioStreamPlayer / AmbientMusic.gd)
```

## Controls and disposal

| Input | Action |
|---|---|
| WASD, mouse, Space | Move, look, jump |
| Left click | One hand/scoop stroke, subject to gloves cooldown |
| Hold left click | UV, detector, blower or vacuum |
| 1–5 / mouse wheel | Hands/scoop, UV, detector, blower, vacuum |
| Q | Empty carried foam into a nearby waste bin |
| E | Pick up, shop, return a clean sphere, or empty the targeted bin |
| Hold E | Manually wash a held sphere at the blue station |
| G | Drop the held sphere safely |
| Escape | Pause; close shop first when shop is open |

Q works with hands and every bucket level, including partially full storage.
It selects a waste bin within 3 m of the camera, checks a physics ray to that
bin, then empties storage and grants disposal credits. Looking at the rim is
unnecessary. Walls, terrain, pause, the shop and ended shifts prevent disposal.
An empty attempt gives feedback and no credits. G never deletes stored foam.

The left bar fills from bottom to top and turns amber at full capacity. A full
carry shows an edge-clamped FOAM WASTE marker, distance and Q hint. Holding a
dirty sphere instead directs the player to WASH; a clean sphere directs to RETURN.
If both are full, empty foam first. E still works when directly targeting a bin.
The return station target extends above/outside decorative furniture, and displayed
items have no collision, so later deposits cannot be blocked by earlier items.

## Large map and excavation

Warehouse: 24 × 24 m, 8.5 m roof. Foam: 14 × 11 m footprint, 4.5 m crown,
center (0,0,-1.6), 65 × 53 vertices / 6,656 triangles. The rounded cone has
climbable initial slopes. No node scaling is applied: the mesh, physics shape,
sampler and volume integral use the same world units.

Spawn (0,0,7.8); waste (-3.5,0,6); wash (-7.5,0,6); return (4,0,6);
store (8.5,0,6.5). All are outside the pile's front edge at z=3.9. Two early
spheres are buried shallowly on the entrance side; the others are distributed
farther around the pile. All use a 0.095 m sphere radius; item kind changes finish
and label only, never geometry or physics shape.

`FoamMesh.excavate(hit, radius, depth, room)`:

1. Convert hit to local coordinates and calculate affected grid bounds.
2. Visit vertices inside the brush circle, using a smooth radial falloff.
3. Clamp each drop to the floor, then integrate drop × projected triangle area.
4. Scale the cut to remaining storage so removed and stored volume agree.
5. Rebuild surface normals, ArrayMesh and static triangle collider together.

Hands/scoop cut once per click. Blower/vacuum accumulate delta and cut around
10 times per second, preserving rates while reducing collision rebuilds. The
blower disperses foam without income; vacuum transfers only the volume removed.
Full storage rejects vacuum/scoop cuts. A heightfield has one Y per X/Z sample:
it cannot create caves or overhangs. For much larger maps, partition into mesh
and collider chunks; this bounded single-grid prototype is not a voxel engine.

## Balanced UV implementation

Tools.uv_visibility is the CPU authority. The sphere must be searchable, within
7 m, inside the beam, and unobstructed by world or station geometry. Foam above
the sphere's top must be less than 0.28 m. Samples every approximately 0.04 m
along the view ray additionally reject more than 0.40 m of intervening foam,
including a thin-covered sphere on the far side of the mountain.

Eligible spheres receive a fading UV strength. FoamTerrain.gdshader receives up
to eight tested surface positions and renders localized round fluorescent hints.
Foam stays opaque: these hints simulate light diffusing through a thin covering,
without opening a transparent beam onto deeply buried models. PearlUV.gdshader
adds soft emission to an exposed sphere. Both keep ordinary depth testing.
Held/collected spheres, switching tools and released triggers clear hints.

UV levels 1–5 increase brightness only; the thickness and range limits never
increase. Battery extends UV operating time and work-light brightness. Detector
remains the deep-search tool with quiet, fixed-pitch 140 Hz pulses.

## Upgrade authority

GameManager owns wallet, level caps and purchase effects. Prices are
`ceil(base_cost * pow(2.4, current_level))`. The shop reads this authority after
each purchase. Invalid IDs, insufficient funds, capped levels and expired shifts
are rejected. Progress resets per shift. See UPGRADES_AND_AUDIO.md for effect
formulas; UV is now a five-level upgrade, not a one-off unlock.

| ID | Base cost | Max level |
|---|---:|---:|
| bucket | 40 | 5 |
| scoop | 35 | 5 |
| gloves | 80 | 5 |
| uv | 25 | 5 |
| detector | 20 | 1 |
| blower | 250 | 1 |
| vacuum | 400 | 1 |
| auto_washer | 150 | 1 |
| boots | 120 | 5 |
| battery | 100 | 5 |
| grabber | 180 | 5 |
| delay | 200 | 5 |

## Pause, atmosphere and sound

Main menu starts before the clock. Escape during a shift sets SceneTree.paused,
shows the overlay and releases the mouse. MenuManager and its pause shop process
while paused; player, item physics and countdown stop. Resume recaptures the cursor.
Returning to the menu unpauses before reload. AmbientMusic continues through menus.
This follows Godot's [process-mode pause model](https://docs.godotengine.org/en/stable/tutorials/scripting/pausing_games.html).

Keep Compatibility for web builds. The factory uses low blue ambient light,
a cool directional moon, warm work spots, depth fog and RainGlass.gdshader on a
window pane. Forward+ optionally enables volumetric fog; Compatibility does not.
Workbench shadow bias is tuned for the enlarged slopes to avoid ring-shaped
self-shadow artifacts. Rain is decorative and can animate while paused: shader
TIME is not paused by SceneTree (see [spatial shader reference](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html)).

The generated low-pass ambient bed has smooth fades and low carriers. Sonar is
140 Hz, intro impact 110 Hz; no high-pitched alarm is added. Settings includes mute
and mouse sensitivity. This remains procedural prototype art and synthesized audio.

## Verification commands

```text
godot --headless --path . --script res://tests/Smoke.gd
godot --headless --path . --script res://tests/Upgrades.gd
godot --headless --path . --script res://tests/UVBalance.gd
godot --path . --script res://tests/MenuVisual.gd
godot --path . --script res://tests/DumpInput.gd
```

Smoke checks volume/collision agreement, repeated disposal, wall/paused disposal
rejection, multiple return-box deposits and round completion. UVBalance checks
spherical models, shallow/deep separation, max-level limits and occlusion. MenuVisual
captures empty/full left bar, title, pause/shop and thin/deep UV screenshots.
DumpInput injects the Q key through Godot's input pipeline and verifies three
successive full loads empty near the bin even when facing away.
