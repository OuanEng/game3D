# Night Shift: Lost & Found — Godot 4

Open project.godot, run Main.tscn (F6) or the project (F5). Main builds its
children in code, so the tree below appears in the editor's Remote scene tree
while running. The scripts in scripts/ are the complete implementation.

```text
Main (Node3D, Main.gd)
├── GameManager (Node, GameManager.gd)
├── FactoryWorld (Node3D, FactoryEnvironment.gd)
│   ├── WorldEnvironment
│   ├── DirectionalLight3D + work lights
│   ├── Steel shelves, floor, perimeter collisions
│   ├── Rain glass (MeshInstance3D + RainGlass.gdshader)
│   └── LoosePallet
├── FoamMesh (Node3D, FoamMesh.gd)
│   ├── Surface (MeshInstance3D / ArrayMesh)
│   ├── FoamCollider (StaticBody3D + ConcavePolygonShape3D)
│   └── InteractiveItems (individual Pearl RigidBody3D instances)
├── Player (CharacterBody3D, Player.gd)
│   ├── CollisionShape3D
│   ├── Camera3D / HoldPoint
│   └── Tools (Tools.gd)
├── WasteBin (StaticBody3D, WasteBin.gd)
├── WashingStation + CollectionBox (Station.gd)
├── UpgradeStore + StoreUI (UpgradeUI.gd)
├── IntroCutscene (Camera3D + AnimationPlayer)
├── UI (CanvasLayer, HUD)
├── Camera3D (cinematic title camera)
└── MenuManager (CanvasLayer, MenuManager.gd)
    └── PanelContainer / VBoxContainer
        └── MainMenu, PauseMenu, Settings or upgrade catalog controls
```

InteractiveItems is a conceptual group: bodies are children of FoamMesh, not
of an extra node. Main/Pause/Settings reuse one panel, preventing overlapping
modals. Pearl is the shared item class retained for compatibility; item_kind
selects pearl, relay or fuse geometry and item_name supplies the held-item label.
All types use the same exposure, cleaning and deposit state machine.

## Controls and progression

WASD moves, mouse looks, Space jumps, LMB digs, E retrieves/dumps/deposits and
held E washes. Keys 1–3 or the wheel select hands/scoop, UV, detector. G drops
an item. Escape pauses/resumes; in the supply shop it closes the shop first.
R resets the run to the title. Start Night Shift begins the intro; Space skips it.

Start with zero credits and a 12-litre hand carry. Each disposal grants one
credit per litre (rounded per disposal). The 40-credit bucket increases capacity
to 500 litres. The scoop increases radius/depth from 0.25/0.08 m to 0.75/0.30 m.
UV and detector are separately purchased. A returned clean item earns 25 credits.
Storage values represent lightweight foam bulk; tune them for your game's scale.
The menu's Upgrades button previews the catalog; purchases happen at the supply
desk during the run. Progress resets each shift. Settings apply to this session.

## State and pause ownership

MenuManager is PROCESS_MODE_ALWAYS. The world, controller, manager, item physics
and intro retain inherited pausable processing. Escape sets SceneTree.paused and
releases the cursor; Resume clears pause and captures it. The menu intercepts
Escape before Player's unhandled input. Settings opened from Pause keep the
tree paused and return to Pause. Return to Main Menu unpauses before reloading.
The supply shop remains an intentionally live-time modal. During the title and
intro, GameManager.running is false, so the boss countdown has not started.
Web Quit displays a closed-shift panel because browsers cannot close arbitrary tabs.

## Excavation and collisions

FoamMesh.excavate converts the ray hit to local coordinates, applies a radial
falloff, and clamps each height reduction against the floor. It integrates
reductions using per-vertex triangle areas, then scales the whole cut to the
remaining carry volume. Player transfers exactly that returned volume into its
inventory. A full carry removes nothing. The surface and static triangle collider
are rebuilt together. Keep FoamMesh at unit scale and axis-aligned: its sampling
and volume assumptions are designed for this setup.

This is a heightfield: one height per X/Z sample. It supports bowls and trenches,
not overhangs, tunnels or caves. For large production levels, partition the grid
into chunks and rebuild only affected chunks; rebuilding the entire collider on
every mouse-motion event is expensive. This prototype digs once per click inside
the physics tick. No loose foam rigid bodies are generated.

Items remain frozen while embedded. Exposure is checked against the current
surface. Once the whole footprint clears, the item becomes a simulated body.
Pickup requires exposure and a camera ray without intervening terrain. Held and
collected items leave collision layers; dirty or duplicate deposits are rejected
centrally by GameManager.collect.

Configure Project Settings → Layer Names → 3D Physics:

| Layer | Name | Bit mask |
|---|---|---|
| 1 | World | 1 |
| 2 | Player | 2 |
| 3 | Items | 4 |
| 4 | Foam terrain | 8 |
| 5 | Stations | 16 |

Player collides with World and Foam (9). Free items collide with World, Items
and Foam (13). Interaction rays use World, Items, Foam and Stations (29),
excluding Player. The static terrain collision follows the visual mesh exactly.

## Nighttime lighting and rain

1. Keep Compatibility for browser exports. Add a WorldEnvironment with a dark
   blue background, low blue ambient light and ordinary depth fog. FactoryEnvironment
   creates these nodes automatically; adjust its build_lighting() values.
2. Aim a cool DirectionalLight3D downward through the roof opening. Start with
   energy 0.1–0.3 and enable shadows. Avoid raising ambient light until all corners
   become equally visible.
3. Place warm SpotLight3D work lamps above the pile and wash/display stations,
   aiming at their task surfaces. Start with 35–50 degree cones and 8–12 m range.
   Keep the digging lamp steady; flicker only the distant aisle fixture.
4. Use a QuadMesh for a window inset in a wall. Assign a ShaderMaterial with
   RainGlass.gdshader. UV repetition produces thin animated rivulets; TIME advances
   the drops. The included pane overlays the back wall as a stylized window, not
   a physically refractive opening. For an exterior view, replace that wall section
   with a real opening and add dim geometry outside.
5. The title camera slowly shifts sideways while looking at the mound. Its menu
   is a dark translucent panel so the scene remains visible. Replace primitive
   assets with factory art without changing the gameplay interfaces.
6. For desktop Forward+, enable Environment volumetric fog and start density at
   0.01–0.025; increase spotlight volumetric energy for beams. Volumetric fog is
   not available in the Compatibility web build. Prefer ordinary fog and sparse
   non-colliding dust particles on the web; do not switch the web project to Forward+.

PearlUV.gdshader and FoamTerrain.gdshader already cooperate with Tools: UV reveals
nearby glints and dithers a thin foam layer in the beam. RainGlass uses no screen
texture and works with the same Compatibility pipeline.

## Validation

Run Godot with --headless --path . --script res://tests/Smoke.gd. It exercises
volume conservation, full-carry rejection, disposal ray validation, upgrades,
exposure, item physics, cleaning, deposits, timeout and pause/resume state.
MenuVisual.gd captures the title and pause screens with a graphical renderer.
The legacy README describes the previous barn version; use this guide for the
current factory/menu/progression architecture.
