# Hidden in Foam: free art integration and complete script map

For the latest manual sink, groove-based BGM, purchase sound and independent ratings,
see [QA_ARCHITECTURE.md](QA_ARCHITECTURE.md).

Open project.godot and run Main.tscn. The complete implementation is already in
the project; this guide maps the requested systems to source, not incomplete snippets.
See STAGES_GUIDE.md for the runtime tree, controls, formulas and stage progression.

## Art actually included

Six GLB models and the shared colormap from [Kenney Factory Kit 3.0](https://kenney.nl/assets/factory-kit)
are bundled under assets/third_party/kenney_factory. The author's download identifies
the pack as CC0. The original License.txt and ATTRIBUTION.md are included.
Stage 1 uses imported packing boxes and a conveyor; stage 3 uses imported cones and
a crane; stage 4 uses imported machinery and a hopper. Salt-barn props, forklift,
hands and other scene furniture remain procedural. There are no purchased assets.

Other verified sources, **not bundled**:

- [Kenney Furniture Kit](https://kenney.nl/assets/furniture-kit): CC0 furniture.
- [Industrial Cyberpunk 3D Tilepack by slipperhat](https://slipperhat.itch.io/industrial-cyberpunk-3d-tilepack): creator lists GLB and CC0.
- [Poly Pizza](https://poly.pizza/docs/press): low-poly Creative Commons/public-domain models;
  check the individual model's license and author credit before redistribution.

Do not treat “free download” as a universal license. Keep the downloaded license and
the model-specific attribution alongside each pack. Use the mesh/texture files only;
no third-party editor scripts or plugins are required by this integration.

## Godot import steps

1. Extract `.glb` or `.gltf` into a dedicated assets/third_party/<pack> directory.
   Preserve relative paths to `.bin` and textures. Even GLB may reference an external
   PNG: these Kenney files require `Textures/colormap.png` beside them.
2. Open Godot and wait for import. Select the model in FileSystem and inspect its
   Import/Advanced Import settings. Verify normals, materials, units and facing.
   See [Godot 3D import documentation](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/index.html).
3. Avoid editing the generated imported scene. Use a wrapper or inherited `.tscn`
   for custom collision and attachments so a reimport does not discard your changes.
4. `ImportedProps.place(parent, "box-large", position, 0.9)` instances an imported
   PackedScene, measures transformed mesh bounds and scales the longest dimension
   to 0.9 metres. It centers X/Z and places the bottom at the given position.
   The wrapper preserves the imported root's original transform.
5. Pass `true` as the final argument for a static box collider on layer 1. Boxes
   are appropriate for stationary background machinery, not walk-through arches.
   For open machinery, replace the broad box with several hand-authored simple
   colliders in a wrapper scene. Do not enable duplicate imported collisions.
6. Missing optional resources return null; the box and cone placements use their
   procedural alternatives. Missing extra machinery is omitted. ResourceLoader
   loads local Godot-imported resources; this is not an online runtime downloader.
7. Keep decorative art separate from Pearl, Station and FoamMesh gameplay bodies.
   Replacing a washer visual must not replace its FIFO queue/interaction collider.
8. For a new pack, change the library ROOT or make another library, then call it
   from StageProps. Keep the raw assets and license in version control, but not
   the `.godot` cache. Web exports use all project resources; export license files
   with the include filter in export_presets.cfg.

## Scene structure

```text
Main
├─ SettingsManager / StageManager / GameManager / EquipmentAudio
├─ FactoryWorld (warehouse, wood barn, open construction yard, mega depot)
│  └─ StageDecor
│     ├─ procedural environment props
│     └─ Imported_<model>
│        ├─ normalized Node3D → imported GLB scene
│        └─ optional StaticBody3D → CollisionShape3D
├─ FoamMesh → Surface + triangle collider + spherical Pearl bodies
├─ Player → Camera3D → HoldPoint / voxel hand / tool models / work light
├─ WasteBin / WashingStation / CollectionBox / UpgradeStore
├─ IntroCutscene / MenuManager / StoreUI / HUD / DebugPanel
└─ AmbientMusic
```

## Complete GDScript implementations

| Requested system | Source files | Integration |
|---|---|---|
| Construction and scene wiring | scripts/Main.gd | Main.tscn entry point |
| Career, tutorial, events | scripts/StageManager.gd | stage definitions, saves, outage/radio/alarm timers |
| Scene lighting and props | scripts/FactoryEnvironment.gd, StageProps.gd, ImportedProps.gd | preconfigured stage before ready |
| Economy and shop | scripts/GameManager.gd, UpgradeUI.gd, UpgradeStore.gd | 12 upgrades; ceil(base×1.85^level) |
| Blower, vacuum, detector, UV | scripts/Tools.gd | physics-tick tool routing; 10 Hz continuous cuts |
| SFX and BGM | scripts/EquipmentAudio.gd, SoundBank.gd, AmbientMusic.gd | procedural soft sounds on SFX/BGM buses |
| Scaled icon HUD | scripts/MinimalHUD.gd | sole capacity bar is on left |
| Player and bright voxel hand | scripts/Player.gd, ToolArt.gd | movement, jump, F throw, Q dump, safe drop sweep |
| Terrain deformation | scripts/FoamMesh.gd | exact volume accounting and updated collider |
| Round targets and washing | scripts/Pearl.gd, Station.gd, WasherArt.gd | exposure, pickup, rinse, FIFO and separate clean tray |
| Settings and localization | scripts/SettingsManager.gd, Localization.gd, localization/th.json | audio, graphics, language, mouse, rebindings |
| Main/pause/intro | scripts/MenuManager.gd, IntroCutscene.gd | cursor and pause ownership |
| Test panel | scripts/DebugPanel.gd | F3, money, capacity, clear pile, highlight, unlock all |

Use the existing Main construction order; these scripts communicate through explicit
world/player/manager references and signals. No additional autoload is required.

## Art and performance rules

Compatibility remains the default for browser support. FactoryEnvironment enables
volumetric fog and SSAO only under Forward+; Compatibility uses regular fog and
direct-light shading. Do not promise volumetric fog/SSAO on the web renderer.
Imported models preserve their supplied materials and share the texture atlas.
Keep the warm work lamps and bright pixel hand readable; use dark areas mainly in
the background. Night events switch real lights while leaving navigation light usable.

Material 0/1/2 means foam/salt/sand. Mixed stage 4 uses horizontal layers; shader
appearance and per-vertex digging resistance depend on remaining surface height.
The terrain is a heightfield, not a voxel cave simulation. Mesh scale stays at one.
The full economy, layer thresholds and limitations are documented in STAGES_GUIDE.md.

## Validation

Run `--headless --path . --editor --import` once after adding models. Run
`--headless --path . --script tests/ImportedPropsCheck.gd` to check imported instances,
normalization, collision and missing-model fallback; tests/Stages.gd covers progression.
tests/StageVisual.gd renders all four environments for visual checks.
No GitHub push or website deployment is part of this local update.
