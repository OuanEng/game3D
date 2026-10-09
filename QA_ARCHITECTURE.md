# Hidden in Foam — architecture and independent QA review

Reviewed 2026-10-09 by the dedicated `qa_review` sub-agent, with final audio and
washing changes re-reviewed. Scores assess implementation readiness, not measured
player satisfaction. This is a working low-poly prototype, not a production certification.

## Ten-category scorecard

| Category | /10 | Design evidence | Remaining quality gate |
|---|---:|---|---|
| Background music / mood | 7 | Cached 12-second, 80 BPM four-bar loop; extended chords, rounded bass/kick, swung filtered brushes | Mono procedural loop; human listening, repetition fatigue and mastering not evaluated |
| Equipment / action SFX | 8 | Distinct wind/noise, vacuum harmonics, modulated water, short UV click, dig/dump envelopes, sonar and damped two-note purchase sound | Radio/alarm/pickup/drop still share synthesis characteristics; audition speakers/headphones |
| UI readability / scaling | 8 | Only one left 20×260 capacity bar; 48px slots and 19/21px main text | Some destination captions are 14px and Hardcore badge 12px; assess across display sizes |
| Bright voxel hand | 8 | Block silhouette, warm 16×16 nearest-filtered palette, contrasted highlights/shadows and modest emission | Procedural geometry; no authored hand animation rig |
| Deformable terrain | 8 | Exact volume accounting, capacity-bound cuts, material resistance, mesh/collider agreement | Full mesh/trimesh rebuild per cut; browser frame-time benchmarking pending; no caves |
| Basin / washing / overflow | 9 | Visible manual basin, faucet particles, automated belt, finite FIFO intake and separate output tray | Functional score; art polish and extensive failure-injection still possible |
| Economy / shop | 7 | Central validation, 12 upgrades, exponential 1.85 scaling, fractional disposal accounting, distinctive tool utility | Full career earning rates and completion pacing need player trials |
| Stage diversity | 8 | Foam warehouse, lantern-lit salt barn, open construction yard, layered mega depot; matching props | Shared base footprint and station positions reduce spatial variety |
| Story events / atmosphere | 7 | Outage, radio and drill alarm; event pause and lamp restoration tested | Radio/alarm are cues rather than branching narrative; Compatibility lacks Forward+ SSAO/volumetric fog |
| Localization / settings | 8 | TranslationServer, bundled Thai font, TH/EN dropdown, audio buses, mouse and key rebinding | Graphics quality principally affects next-shift terrain density; broad lighting presets absent |

Mean score: **7.8/10**. Treat the table as a prioritized review checklist, not an
objective product rating. The reviewer inspected source and ran tests but did not
audition the generated music. The parent reviewed a rendered manual-basin screenshot.

## Final architecture

```text
Main (composition root; Main.tscn is the runnable scene)
├── SettingsManager (persistent preferences, BGM/SFX buses, TH/EN)
├── StageManager (career checkpoint, tutorial, random event lifecycle)
├── EquipmentAudio (tool loops, action cues, successful-purchase feedback)
├── GameManager (timer, upgrade rules, wallet, delivery validation)
├── FactoryWorld (WorldEnvironment, lamps, stage shell)
│   └── StageDecor (procedural props + imported Kenney GLBs)
├── FoamMesh (ArrayMesh + static triangle collision + hidden Pearl bodies)
├── Player (CharacterBody3D)
│   ├── Camera3D (HoldPoint, work light, voxel hand/tool visuals)
│   └── Tools (scoop, UV, detector, blower, vacuum)
├── WasteBin
├── WashingStation (Station.gd)
│   ├── ManualWashBasin (WashBasin.gd: bowl, tap, water particles)
│   ├── ConveyorWithWaterJets (WasherArt.gd)
│   ├── BeltAnchor / waiting item anchors
│   └── Clean tray item anchors
├── CollectionBox / UpgradeStore / StoreUI
├── AmbientMusic (BGM bus)
├── IntroCutscene / MenuManager / MinimalHUD
└── DebugPanel (F3, including persistent unlock-all)
```

Main connects GameManager.upgrade_bought to EquipmentAudio.on_upgrade_bought.
The signal occurs only after validation and charging, so declined purchases remain
silent. EquipmentAudio processes during pause: continuous gameplay sounds stop,
but a successful purchase in the pause shop can finish its short coin sound.
The coin cue is damped at 330/440 Hz with a quiet 660 Hz harmonic, not a long bell.

BGM is synthesized once per application session and shared on reload. It uses an
80 BPM pattern with 60%-beat offbeats, low-pass synthesis and faded loop boundaries.
It remains available on main/pause screens and obeys BGM and Master settings. This
is an original generated sketch, not a recorded jazz performance or licensed song.

## Sink setup and inventory authority

Station owns the items; WashBasin and WasherArt own only presentation. Attach
WashBasin as a child at local origin on a Station of kind WASH. The shared station
interaction box remains on layer 5; decorative bowl/tap meshes need no additional
colliders. The bowl is a recessed base and four rims with a drain and visible water.
CPUParticles3D emits from the tap only during dirty-item manual washing. Player
refreshes manual_flow_remaining while E is held on the washing interaction target.

Before buying automation, the manual basin is visible. After purchase the conveyor
is visible instead. The existing Station collider and player ownership are preserved.
Input capacity is 2 + washer level. Full queues reject the held object without
clearing the player's reference. Clean output moves into separate tray anchors,
so a second or subsequent object cannot obstruct processing. E with empty hands
retrieves FIFO clean output. Ended shifts stop cleaning and advancing the queue.

The basin uses primitive meshes and generated materials, so it has no external
asset dependency. To replace it with an imported sink, put the GLB under a visual
wrapper and preserve Station's interface, anchors and water activation logic.

## Asset imports and complete GDScript source

Follow [FREE_ASSET_SETUP.md](FREE_ASSET_SETUP.md) for glTF/GLB import, texture paths,
scale normalization, wrapper collision and licenses. Six actual Kenney CC0 models
are bundled with original license; Itch.io/Poly Pizza are documented alternatives,
not falsely credited as included assets. In Forward+ the scene can enable SSAO and
volumetric fog; Compatibility/browser uses regular fog and direct lighting.

| System | Complete source |
|---|---|
| Stage/tutorial/events | [StageManager.gd](scripts/StageManager.gd) |
| Economy/shop authority | [GameManager.gd](scripts/GameManager.gd), [UpgradeUI.gd](scripts/UpgradeUI.gd) |
| Blower/vacuum/UV/detector | [Tools.gd](scripts/Tools.gd) |
| Music and purchase/tool audio | [AmbientMusic.gd](scripts/AmbientMusic.gd), [EquipmentAudio.gd](scripts/EquipmentAudio.gd) |
| Left-only capacity/icon HUD | [MinimalHUD.gd](scripts/MinimalHUD.gd) |
| Language/settings | [SettingsManager.gd](scripts/SettingsManager.gd), [Localization.gd](scripts/Localization.gd) |
| FPS/throw/dump/hand art | [Player.gd](scripts/Player.gd), [ToolArt.gd](scripts/ToolArt.gd) |
| Terrain and materials | [FoamMesh.gd](scripts/FoamMesh.gd), [FoamTerrain.gdshader](shaders/FoamTerrain.gdshader) |
| Item ownership and wash queue | [Pearl.gd](scripts/Pearl.gd), [Station.gd](scripts/Station.gd) |
| Manual sink and conveyor art | [WashBasin.gd](scripts/WashBasin.gd), [WasherArt.gd](scripts/WasherArt.gd) |
| Scene/main/pause | [Main.gd](scripts/Main.gd), [MenuManager.gd](scripts/MenuManager.gd) |

These are the runnable project implementations; there is no separate abbreviated
example that diverges from gameplay. Stage/economy dimensions and control setup are
documented in [STAGES_GUIDE.md](STAGES_GUIDE.md). Hardcore ignores owned equipment and
rejects shop purchases. F3 remains a test panel and does not suppress normal saves.

## Verification record

- `Stages.gd`: 0 failures, including career, tutorial, disposal grant, wall-blocked
  grabber, event pause/restore, saving and unlock-all rules.
- `WasherQueue.gd`: 0 failures after changes, including full rejection without loss,
  duplicates, clean-tray FIFO, fourth item, capacity/speed upgrades and throwing.
- `AudioWashQA.gd`: 0 failures; manual water activation/stop, automation visual swap,
  failed purchase silence, paused-shop sound survival, shift-end stop, 12-second BGM
  length and non-silent/unclipped SFX PCM buffers.
- `SinkVisual.gd`: rendered screenshot reviewed at 1280×720.

Some headless teardown runs warn about 4–9 ObjectDB instances at exit. These are
not ignored as proof of leak-free operation; prolonged-session memory profiling
remains a follow-up. Audio amplitude tests do not establish pleasant sound quality.
Browser performance, long-session listening and full economy playtests remain open.

Preview WAV files are generated locally in `.runtime/lofi-preview.wav` and
`.runtime/purchase-preview.wav` for listening review. No GitHub upload is performed.
