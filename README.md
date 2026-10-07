# Hidden in Foam — Godot 4

Latest update: [Normal / Hardcore, Thai / English, voxel hands and developer tools](PROP_DESIGN_GUIDE.md).

Current version: [Large foam mountain, Q disposal, left capacity bar and balanced UV](LARGE_FOAM_GUIDE.md).

Latest update: [Minimal HUD, twelve upgrades and ambient audio](UPGRADES_AND_AUDIO.md).

Current factory version: see [Night Shift guide](NIGHT_SHIFT_GUIDE.md) for the
main/pause menus, bare-hands progression, mixed items, rain shader and scene tree.
The sections below document the earlier barn prototype.

Open [project.godot](project.godot) in Godot 4 and press **F5**. [Main.tscn](Main.tscn) builds the playable scene from the complete, commented GDScript files linked below. The prototype uses local primitive art, generated audio, and a camera-and-caption intro.

The foam is now a continuous heightmap mountain. Clicking the scoop lowers its surface and transfers the removed volume into a portable bucket. Empty the bucket at the waste station to keep digging. No foam chunks are spawned or simulated; drifting barn dust is a separate atmospheric effect.

Main builds its children at runtime. Use the **Remote** scene tree while playing to inspect them. Edit the source to persist changes; Remote edits affect only the current run.

## 1. Game design and scene structure

At 02:13 AM, a panicked night-shift employee catches the boss's necklace on a splinter. Eight pearls disappear into a mountain of packaging foam in a wooden grain barn. Dig them out, rinse away residue, and return them to the velvet box before the supervisor arrives in five minutes.

The loop is **scan → scoop → dump a full bucket → retrieve → wash → return → upgrade**. Start with a scoop, a **0.22 m³ bucket**, and **60 credits**. Returning each clean pearl earns **25 credits**. The scoop and manual rinse station are sufficient to finish; purchases improve searching and carrying capacity.

| Input | Action |
|---|---|
| WASD / mouse | Move / look |
| 1 / 2 / 3 | Select Scoop / UV Light / Pearl Detector |
| Mouse wheel | Cycle owned tools, skipping locked slots |
| Click left mouse with Scoop | Make one excavation stroke; holding does not auto-scoop |
| Hold left mouse with UV / Detector | Scan for pearls |
| E | Retrieve an exposed pearl, deposit a clean pearl, open the shop, or empty the bucket at WasteBin |
| Hold E at rinse station | Wash a held pearl in two seconds |
| G | Drop a held pearl using a collision-safe sphere sweep |
| Space during intro | Skip the intro and start the round |
| Escape | Release cursor or close the shop |
| Click with cursor released | Resume mouse look |
| M / F | Mute audio / toggle gentle rear-lamp flicker |
| R | Restart the round, wallet, tools, bucket, terrain, and intro |

Put down a held pearl before using a tool. The boss timer continues while shopping or while the cursor is released. Auto-washing advances during active player control.

```text
Main (Node3D, Main.gd)
├── GameManager (Node, GameManager.gd)
├── Barn (Node3D, BarnEnvironment.gd)
│   ├── WorldEnvironment
│   ├── Moonlight (DirectionalLight3D)
│   ├── FoamWorkLamp / RinseLamp / VelvetLamp / UpgradeLamp (SpotLight3D)
│   ├── MoonShaft / RearFluorescent (SpotLight3D)
│   ├── Timber boards, trusses, pitched roof, packing crates
│   ├── Floor / perimeter / large props (StaticBody3D)
│   ├── LoosePallet (Node3D; intro animation target)
│   ├── DriftingDust (CPUParticles3D; decoration only)
│   └── DistantVentilationHum (AudioStreamPlayer)
├── FoamMesh (Node3D, FoamMesh.gd)
│   ├── Surface (MeshInstance3D, ArrayMesh + FoamTerrain.gdshader)
│   ├── FoamCollider (StaticBody3D)
│   │   └── SurfaceShape (CollisionShape3D, ConcavePolygonShape3D)
│   └── Pearls ×8 (RigidBody3D, Pearl.gd)
│       ├── MeshInstance3D + PearlUV.gdshader
│       └── CollisionShape3D (SphereShape3D)
├── WashingStation / CollectionBox (StaticBody3D, Station.gd)
├── WasteBin (StaticBody3D, WasteBin.gd)
├── UpgradeStore (StaticBody3D, UpgradeStore.gd)
├── Player (CharacterBody3D, Player.gd)
│   ├── CollisionShape3D (CapsuleShape3D)
│   ├── Camera3D
│   │   ├── HoldPoint (Marker3D)
│   │   ├── UVBeam (SpotLight3D)
│   │   └── Tool / portable bucket placeholder meshes
│   └── Tools (Node3D, Tools.gd)
│       └── SonarBeep (AudioStreamPlayer)
├── IntroCutscene (Node3D, IntroCutscene.gd)
│   ├── Camera3D / AnimationPlayer
│   ├── Decorative necklace and scattering bead proxies
│   ├── AudioStreamPlayer (snap)
│   └── CanvasLayer (captions, letterbox, skip instruction)
├── StoreUI (CanvasLayer, UpgradeUI.gd)
│   └── Catalog, wallet, purchase buttons, close button
└── UI (CanvasLayer)
    └── Boss timer, pearl count, credits, bucket meter, tool slots, crosshair, result
```

**Responsibilities:** FoamMesh owns the authoritative height samples, render mesh, collider, and removed-volume calculation. Player owns movement, carrying, bucket fill, and interactions. Tools handles selected-tool behavior, UV, and detector audio. Pearl owns exposure and held/free/collected states. GameManager owns the round, wallet, purchased upgrades, and validated pearl deposits. WasteBin is a raycast target; bucket volume is cleared only through the player's waste interaction.

### Tools, upgrades, and task stations

| Tool or upgrade | Cost | Effect |
|---|---:|---|
| Scoop | Free | One stroke per click, radius **0.48 m**, maximum center depth **0.18 m** |
| UV flashlight | 25 | Cyan-green fluorescence through a temporarily translucent scan region |
| Pearl detector / sonar | 20 | Faster beeps as the nearest remaining pearl approaches |
| Large scoop | 35 | Radius **0.75 m**, maximum center depth **0.30 m** |
| Larger bucket | 40 | Capacity increases from **0.22 m³ to 0.50 m³** |
| Portable auto-washer | 50 | Rinses a dirty held pearl in three seconds of active play |

Scoop size does not increase pickup range: pearl retrieval stays at **3 m**. A larger scoop can fill a small bucket faster; buy capacity to reduce disposal trips. Capacity purchases preserve the foam already carried. The HUD reports the bucket's current fill and capacity; **1 m³ = 1,000 liters**. These are deliberately generous game capacities rather than an ergonomic real bucket model.

| Station | World position | Action |
|---|---|---|
| WasteBin | (−7, 0, 5) | Aim at the waste target and press E to empty the portable bucket |
| Rinse | (−5, 0, 3) | Hold E to wash a held pearl |
| Velvet box | (5, 0, 3) | Press E with a clean held pearl to deposit it |
| Supply desk | (7, 0, 5) | Press E to open the upgrade catalog |

The shop disables unaffordable/owned purchases; `GameManager.buy_upgrade()` also validates cost, ownership, and round state. Dropping a pearl onto the box does not count as a deposit. Dumping foam changes bucket fill, without refilling the excavated terrain or granting credits.

### Continuous excavation and volume accounting

The mountain is a **2.5D height field**, `y = h(x, z)`: every horizontal position has a single surface height. A **41 × 35** grid supplies **1,435 vertices** and **2,720 triangles**. One ArrayMesh renders the surface and a matching trimesh supplies collision. Scooping changes the height data; it does not create foam RigidBody3D nodes.

For each vertex inside the scoop radius, calculate a smooth radial falloff and a proposed downward change, clamped above the pile's floor. Do not charge the bucket a fixed amount per click: an edge scoop or an almost-empty patch removes less foam.

For a triangle with horizontal projected area `A` and corner heights `h₀, h₁, h₂` above the floor, the volume beneath its linear surface is:

```text
V_triangle = A × (h₀ + h₁ + h₂) / 3
weight_i   = sum(projected_triangle_area / 3) for triangles touching vertex i
V_removed  = sum(weight_i × (old_height_i − new_height_i))
```

Precomputing the weights makes each scoop's volume calculation inexpensive and exact for the rendered piecewise-linear terrain, including boundary vertices. The Player passes remaining bucket capacity as the scoop budget. If a full stroke would exceed it, scale the proposed height reductions down to fit the remaining space. Add the actual returned volume to the bucket, so a partial final stroke cannot overflow it. Empty space, a full bucket, or a blocked target removes zero volume.

The terrain height query uses the same triangle diagonal and interpolation as the visible mesh. This matters for pearl exposure: bilinear interpolation over a grid quad would disagree with the two rendered triangles at some points. Render mesh, height sampling, and collision must represent the same surface.

The surface is supported by a StaticBody3D, even though its collision shape is replaced after edits. A concave shape belongs on a static terrain body, not a dynamic foam body. [Godot ConcavePolygonShape3D reference](https://docs.godotengine.org/en/stable/classes/class_concavepolygonshape3d.html)

A heightmap supports depressions, trenches, and floor-level clearing. **It cannot create tunnels, overhangs, or undercuts.** Those require a true 3D density/voxel field and surface extraction. Use this simpler heightmap for the requested scoop-down gameplay; keep the pile root at unit scale and a fixed orientation.

### Pearl exposure and round state

Pearls follow `EMBEDDED → EXPOSED → HELD → COLLECTED`. An exposed pearl may instead become `FREE` when fully clear, and `HELD → FREE` allows dropping.

An embedded pearl remains frozen. Once the sampled surface is at or below its center plus the exposure clearance, it becomes **EXPOSED**: visible enough to pick up, but still frozen so partially buried physics cannot eject it. It becomes an unfrozen **FREE** rigid body only once the surrounding surface clears the bottom of its sphere. Free pearls collide with the world, the remaining foam terrain, and other pearls. Held/displayed pearls have collision disabled.

UV affects visibility only. It cannot change exposure or make a buried pearl collectible. The pickup ray uses the nearest physics hit, preserving solid foam and wall occlusion. Washing reduces residue; GameManager accepts only clean, held, registered pearls and rewards each once.

Round state is `INTRO → PLAYING → WON / LOST`. `prepare(pearls)` resets progress, wallet, upgrades, and the five-minute clock without starting it. The intro's guarded completion calls `begin_search()` once. Returning every pearl wins; expiry loses. Tool use, purchases, and collection require an active round.

### UV and detector implementation

The UV tool checks range, facing cone, and world/station occlusion. Eligible pearls receive `uv_strength` on [PearlUV.gdshader](shaders/PearlUV.gdshader); [FoamTerrain.gdshader](shaders/FoamTerrain.gdshader) uses dithered pixel discard in the scan region to approximate translucency. The pearls retain depth testing, and world geometry blocks candidate highlighting. Releasing the tool, switching slots, or losing active control restores the normal material state. This visual scan does not change collision or terrain volume.

The detector considers embedded, exposed, and free pearls, excluding held or collected ones. Foam is transparent to the scan; solid world/station geometry blocks it. Distance maps to a **1.05–0.10 second** beep interval and **0.72–1.6** pitch scale over **7 m**. It gives a proximity cue without digging or collecting automatically.

## 2. Atmospheric barn lighting: editor setup

The project defaults to **Compatibility**. For volumetric shafts, select **Forward+** in the editor's renderer menu and restart when prompted. BarnEnvironment selects the appropriate fog setup. Volumetric fog is a Forward+ feature; Compatibility and Mobile use regular fog. [Godot volumetric fog reference](https://docs.godotengine.org/en/stable/tutorials/3d/volumetric_fog.html)

These values match the included **20 × 20 m** barn and use standard light-energy units:

1. **Build the enclosure.** Floor at y = 0, walls at x/z = ±10, eaves at y = 6.2, ridge at y = 8.6. Place **0.56 m** timber planks on **0.625 m** centers for real **6.5 cm gaps**. Separate invisible perimeter colliders retain players and pearls without blocking light. Add trusses and pitched roof panels; avoid an opaque backing wall behind the planks.
2. **WorldEnvironment.** Assign a unique Environment resource. Background: Custom Color **(0.009, 0.016, 0.032)**. Ambient source: Color, **(0.40, 0.50, 0.68)**, energy **0.18**. Use local lamps to illuminate tasks while preserving dark barn edges.
3. **Forward+ fog.** Enable Volumetric Fog: density **0.012**, length **35 m**, albedo **(0.58, 0.66, 0.78)**. Enable Filmic tonemapping and SSAO. Start with global fog; add local FogVolumes only if particular distant areas need extra density.
4. **Compatibility fallback.** Use regular Fog: density **0.006**, light color **(0.035, 0.055, 0.09)**, energy **0.25**. This preserves haze and readability, but does not recreate volumetric shafts.
5. **Moonlight.** DirectionalLight3D rotation **(−24°, −58°, 0°)**, color **(0.43, 0.58, 0.91)**, energy **0.42**, shadows on, Volumetric Fog Energy **0.6**. The wall gaps and roof ridge admit light. Verify the direction and shadows from inside the barn.
6. **Steady work lamps.** Add the SpotLight3D nodes in the table below. Lights aim along local −Z. A straight-down `look_at()` requires a nonparallel up vector; the supplied helper handles it. Only the central task lamp casts shadows.
7. **Moon shaft.** Spotlight at **(−9.7, 5.5, −6.5)** toward **(0, 0.3, −0.5)**. Color **(0.43, 0.60, 1.0)**, energy **2.0**, angle **17°**, range **19 m**, shadows on, fog energy **2.5**. It supplements the directional light through the gaps.
8. **Gentle flicker.** RearFluorescent at **(3, 5.5, −7.1)** aims toward **(3, 0, −7)**. Color **(0.72, 0.88, 0.85)**, energy **1.15**, angle **50°**, range **14 m**. A half-second dip every eight seconds reduces intensity by up to **0.35**, synchronized with mesh emission. Set fog energy to **0** to avoid temporal trails. F disables flicker. [Godot guidance on changing lights and fog](https://docs.godotengine.org/en/stable/tutorials/3d/volumetric_fog.html)
9. **Drifting dust.** CPUParticles3D: **110** small billboard quads, lifetime **18 s**, Box emission extents **(8, 2.5, 8)** centered at **(0, 3, 0)**, speed **0.015–0.07 m/s**, gravity **(0, −0.004, 0)**. Fade alpha with a Gradient and disable shadows. Dust is decorative and independent of foam physics. [CPUParticles3D reference](https://docs.godotengine.org/en/stable/classes/class_cpuparticles3d.html)
10. **Materials and audio.** Timber roughness **0.88**, foam **0.94**, velvet matte burgundy. Keep exposed pearl highlights readable. The generated ventilation tone is **60 Hz at −31 dB**; sonar is **−19 dB**. M mutes Master. Replace placeholder tones with appropriate licensed recordings for production.

| Lamp | Position | Aim target | Color | Energy | Angle | Range |
|---|---|---|---|---:|---:|---:|
| FoamWorkLamp | (0, 5.8, 0.7) | (0, 0.4, −1) | (1.0, 0.81, 0.53) | 5.0 | 58° | 14 m |
| RinseLamp | (−5, 4.4, 3) | (−5, 0.7, 3) | (0.68, 0.84, 1.0) | 3.2 | 44° | 14 m |
| VelvetLamp | (5, 4.4, 3) | (5, 0.7, 3) | (1.0, 0.74, 0.43) | 3.2 | 44° | 14 m |
| UpgradeLamp | (7, 4.5, 5) | (7, 0.8, 5) | (0.69, 0.91, 0.84) | 2.1 | 37° | 14 m |
| WasteLamp | (−7, 4.5, 5) | (−7, 0.8, 5) | (0.77, 0.93, 0.66) | 2.1 | 37° | 14 m |

Emission makes fixtures visible; separate lights illuminate the scene. Keep gameplay lamps stable. Check both renderers from the player camera after changing light energy, fog, or materials.

## 3. Complete GDScript source and integration

These are the implementation files, not pseudocode fragments. Each is included in the runnable project.

| File | Responsibility |
|---|---|
| [FoamMesh.gd](scripts/FoamMesh.gd) | Height field, ArrayMesh, triangle collider, volume-limited excavation, height sampling, pearl spawning |
| [FoamTerrain.gdshader](shaders/FoamTerrain.gdshader) | Fine surface texture, bare-floor cutoff and dithered UV scan patch |
| [Player.gd](scripts/Player.gd) | Smooth movement, mouse look, bucket inventory, tool input, waste interaction, pickup/wash/deposit/drop |
| [Tools.gd](scripts/Tools.gd) | Scoop dispatch, owned-slot selection, UV, detector, audio, tool models |
| [Pearl.gd](scripts/Pearl.gd) | Buried/exposed/free/held/collected lifecycle, residue, recovery, UV strength |
| [PearlUV.gdshader](shaders/PearlUV.gdshader) | Pearl residue shading and fluorescence |
| [GameManager.gd](scripts/GameManager.gd) | Clock, validated collection, funds, upgrades, win/loss |
| [WasteBin.gd](scripts/WasteBin.gd) | Designated disposal interaction target |
| [UpgradeStore.gd](scripts/UpgradeStore.gd) / [UpgradeUI.gd](scripts/UpgradeUI.gd) | Physical shop and catalog interface |
| [BarnEnvironment.gd](scripts/BarnEnvironment.gd) | Timber barn, lighting, fog fallback, dust, flicker, hum |
| [IntroCutscene.gd](scripts/IntroCutscene.gd) | Necklace/camera animation, captions, skip and handoff |
| [Main.gd](scripts/Main.gd) | Runtime assembly, dependency wiring, InputMap, stations, bucket HUD |
| [Station.gd](scripts/Station.gd) | Wash/display types and eight display slots |
| [Props.gd](scripts/Props.gd) / [SoundBank.gd](scripts/SoundBank.gd) | Primitive geometry and generated audio |

`Foam.gd`, `FoamPile.gd`, `FoamContainer.gd`, and `FactoryEnvironment.gd` remain as legacy source from earlier prototypes. Main no longer instantiates the foam-cell systems. Blower and vacuum are absent from the new inventory and catalog.

### Physics layers and editor nodes

1. In **Project Settings → Layer Names → 3D Physics**, use **1 World**, **2 Player**, **3 Pearls**, **4 Foam**, **5 Stations**. The names are already configured. Layer numbers are editor checkboxes; the numbers below are integer bitmasks.

| Object/query | Layer bitmask | Mask bitmask | Purpose |
|---|---:|---:|---|
| Barn floor, perimeter, tables, large crates | 1 | 6 | World colliding with Player + Pearls |
| Player | 2 | 9 | Collides with World + Foam |
| Pearl before pickup | 4 | 13 | World + Pearls + Foam; buried/exposed bodies remain frozen |
| Held/collected pearl | 0 | 0 | Disabled collision |
| Foam terrain | 8 | 6 | Player + Pearls and interaction-ray target |
| Station/shop/waste target | 16 | 0 | Interaction target over solid furniture |
| Player interaction/drop query | — | 29 | World + Pearls + Foam + Stations |
| Tool world-occlusion query | — | 17 | World + Stations; ignores foam |

2. **Player:** CharacterBody3D with a capsule of radius **0.3 m**, height **1.7 m**, center y **0.85 m**. Camera y **1.55 m**, FOV **78°**. HoldPoint **(0.24, −0.22, −0.55)** relative to the camera. Spawn at **(0, 0, 5.5)**. Terrain collision and floor snapping make the character follow walkable slopes. Keep physics nodes at unit scale; resize their shapes instead.
3. **FoamMesh:** Node3D with a MeshInstance3D and a StaticBody3D containing CollisionShape3D, all generated by its script. The vertex heights are the source of truth. Editing only shader displacement would leave collision and pearl exposure unchanged; this implementation edits CPU geometry. Use the supplied mesh generation rather than adding a second editor mesh/collider. [ArrayMesh guide](https://docs.godotengine.org/en/stable/tutorials/3d/procedural_geometry/arraymesh.html)
4. **Pearls:** RigidBody3D with SphereShape3D radius **0.095 m**, mass **0.08 kg**, continuous collision detection enabled. Assign the foam reference before adding the node. Begin frozen; the pearl's state machine decides when to unfreeze. A body that escapes below y = −3 is recovered rather than permanently losing an objective.
5. **Stations:** put the wash, display, shop, and waste ray targets on layer 5 above separate layer-1 furniture. Use Station.kind WASH or DISPLAY. WasteBin is a separate class, so a generic E press away from it cannot empty the bucket.
6. **Queries:** perform interaction rays and release sphere sweeps from `_physics_process()`, not mouse callbacks. Always honor the nearest obstruction. A ray for aim and a sphere sweep for release solve different problems: a clear center ray alone does not guarantee room for a pearl's radius. [Godot ray-casting guide](https://docs.godotengine.org/en/stable/tutorials/physics/ray-casting.html)
7. **InputMap:** `forward` W, `back` S, `left` A, `right` D, `interact` E, `drop` G, `brush` LMB, `tool_1`…`tool_3` 1–3, `restart` R, `skip_intro` Space, `mute` M, `toggle_flicker` F, built-in `ui_cancel` Escape. Main adds missing bindings. Mouse-wheel cycling is handled directly. Scoop input is edge-triggered; scan tools use held input.

### Initialization and editor integration

GameManager is a scene node, **not an Autoload**. Main creates the manager, barn, stations, shop, waste station, and FoamMesh first. The mesh generates its terrain and pearls. Main assigns Player's `manager` and `pile` dependencies before adding it. Player creates its camera and hold marker and configures Tools. Main connects the shop request and HUD, and calls `manager.prepare(foam_mesh.pearls)`.

Assign IntroCutscene's `player`, `barn`, and `pearls` before adding it, connect `finished` to `manager.begin_search`, then call `play()`. The **11-second** intro uses AnimationPlayer, camera pans, necklace proxies, pallet movement, snap audio, and captions. Space and natural animation completion both call a guarded common handoff: stop animation/audio, hide cinematic nodes, restore the player camera, capture the cursor, and emit completion once. Actual gameplay pearls stay embedded during the cinematic.

To build editor-authored scenes instead, replace runtime child construction with exported node references or `@onready` paths and preserve dependency initialization. Do not leave both construction paths active. The current source has complete behavior, but the character, tools, stations, and cutscene use placeholder art rather than a rigged employee or recorded voiceover.

### Tuning and performance

Adjust round duration, starting funds, pearl rewards, and purchase costs in GameManager. Tune scoop dimensions and bucket capacities in Player/Tools. Change the foam grid, footprint, height, and layout seed in FoamMesh before it enters the tree. Keep pearl count within the eight display slots. `layout_seed = 0` randomizes the layout; a nonzero seed repeats it.

This small prototype rebuilds terrain geometry after accepted scoops rather than every idle frame. For a much larger barn, split the terrain into chunks and rebuild only dirty chunks, including affected neighbors for normals. Keep shared-edge heights synchronized and update matching collision before allowing physics interactions against the edited surface. Replacing an entire large trimesh on every frame is unnecessary for click-based digging.

The heightmap has no avalanche or granular-fluid simulation, no tunnels, and no floating excavated foam chunks. Bucket fill is numerical inventory; dumping removes that inventory. The project has no save system. Balance the bucket sizes and five-minute timer through full-round playtesting.

## Validation and manual checks

The new excavation smoke suite passed on **Godot 4.7.1**: conserved volume, partial capacity, full-bucket blocking, one-click scooping, dump range/target validation, capacity/scoop upgrades, mesh/collider height agreement, stable pearl exposure, UV occlusion, clean collection, intro handoff, timeout and restart. Rendering checks completed in Compatibility and Forward+; the mountain, actual excavation depression, UV and shop screens were inspected. Visual tests save images to `.runtime/`, including `excavation.png`; the preview test funds upgrades and performs controlled scoops, without changing the normal starting wallet.

```powershell
godot --headless --path . --script res://tests/Smoke.gd
godot --path . --script res://tests/VisualCheck.gd
godot --path . --rendering-method forward_plus --rendering-driver vulkan --script res://tests/VisualCheck.gd
```

Use the full installed Godot executable path if `godot` is not on PATH. Check: one click makes one depression; holding Scoop does not repeat; bucket gain matches removed mesh volume; a near-full bucket accepts only the remaining amount; a full bucket changes no terrain; E empties it only at the waste station; upgrades preserve carried foam; lowered collision follows the mesh; exposed pearls stay stable and become retrievable; UV alone does not permit pickup; clean deposits count once; intro skip, timeout, and restart still behave correctly.

Play a complete round to assess search difficulty, disposal-trip pacing, slope traversal, audio balance, and comfort in both intended renderers. Automated checks cannot establish those play-feel qualities.

## Web play
The committed browser build is in [docs/](docs/). Pushing branch
`new` triggers `.github/workflows/pages.yml`, which uploads
that folder to GitHub Pages. Play the deployed branch build at
https://ouaneng.github.io/game3D/. GitHub Pages provides one production site per
repository, so deploying this branch replaces the currently published build.
