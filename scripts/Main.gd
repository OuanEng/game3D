extends Node3D
## Complete asset-free demonstration. Gameplay is separated into reusable scripts.
var manager: GameManager
var player: Player
var status: Label
var hint: Label
var result: Label
var detector: ProgressBar
var pearls: Array[Pearl] = []
var barn: FactoryEnvironment
var foam_mesh: FoamMesh
var intro: IntroCutscene
var hud: CanvasLayer
var shop: UpgradeUI
var loadout: Label
const TOOL_NAMES := ["Hands / Scoop", "UV", "Detector"]
var bucket_status: Label
var menus: CanvasLayer
var minimal_hud: Control
var settings: Node
var stages: Node
var audio: Node

func _ready() -> void:
	preload("res://scripts/Localization.gd").install()
	setup_input()
	settings = preload("res://scripts/SettingsManager.gd").new()
	settings.name = "SettingsManager"
	settings.world = self
	add_child(settings)
	stages = preload("res://scripts/StageManager.gd").new()
	stages.name = "StageManager"
	stages.world = self
	add_child(stages)
	audio = preload("res://scripts/EquipmentAudio.gd").new()
	audio.name = "EquipmentAudio"
	audio.world = self
	add_child(audio)
	manager = GameManager.new()
	manager.name = "GameManager"
	add_child(manager)
	manager.upgrade_bought.connect(audio.on_upgrade_bought)
	build_room()
	build_foam_and_pearls()
	player = Player.new()
	player.name = "Player"
	player.manager = manager
	player.pile = foam_mesh
	player.position = Vector3(0, 0, 7.8)
	add_child(player)
	shop = UpgradeUI.new()
	shop.name = "StoreUI"
	add_child(shop)
	player.shop_requested.connect(func(): shop.open_store(player, manager))
	build_ui()
	manager.game_ended.connect(on_game_ended)
	manager.game_ended.connect(stages.complete)
	manager.prepare(pearls)
	intro = IntroCutscene.new()
	intro.name = "IntroCutscene"
	intro.player = player
	intro.barn = barn
	intro.pearls = pearls
	add_child(intro)
	intro.finished.connect(manager.begin_search)
	intro.overlay.hide()
	menus = preload("res://scripts/MenuManager.gd").new()
	menus.world = self
	add_child(menus)
	manager.game_ended.connect(menus.show_results)
	var music := preload("res://scripts/AmbientMusic.gd").new()
	add_child(music)
	minimal_hud = preload("res://scripts/MinimalHUD.gd").new()
	minimal_hud.world = self
	hud.add_child(minimal_hud)
	var debug_panel := preload("res://scripts/DebugPanel.gd").new()
	debug_panel.name = "DebugPanel"
	debug_panel.world = self
	add_child(debug_panel)
	settings.apply_to_world()
	preload("res://scripts/StageProps.gd").build(barn, stages.selected_stage)
	if stages.pending_mode >= 0:
		var requested_mode: int = stages.pending_mode
		stages.pending_mode = -1
		menus.call_deferred("start_shift", requested_mode)

func setup_input() -> void:
	if not InputMap.has_action("work_light"):
		InputMap.add_action("work_light")
		var light_key := InputEventKey.new()
		light_key.physical_keycode = KEY_F7
		InputMap.action_add_event("work_light", light_key)
	for slot in [4, 5]:
		var action := "tool_%d" % slot
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var key := InputEventKey.new()
			key.physical_keycode = KEY_4 if slot == 4 else KEY_5
			InputMap.action_add_event(action, key)
	if not InputMap.has_action("jump"):
		InputMap.add_action("jump")
		var jump_key := InputEventKey.new()
		jump_key.physical_keycode = KEY_SPACE
		InputMap.action_add_event("jump", jump_key)
	var bindings := {"forward": KEY_W, "back": KEY_S, "left": KEY_A, "right": KEY_D, "interact": KEY_E, "dump_foam": KEY_Q, "drop": KEY_G, "throw_item": KEY_F, "restart": KEY_R, "skip_intro": KEY_SPACE, "mute": KEY_M, "toggle_flicker": KEY_F6, "tool_1": KEY_1, "tool_2": KEY_2, "tool_3": KEY_3}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var event := InputEventKey.new()
			event.physical_keycode = bindings[action]
			InputMap.action_add_event(action, event)
	if not InputMap.has_action("brush"):
		InputMap.add_action("brush")
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("brush", event)

func build_room() -> void:
	barn = FactoryEnvironment.new()
	barn.name = "FactoryWorld"
	barn.stage_index = stages.selected_stage
	add_child(barn)
	build_station(Vector3(-7.5, 0, 6), Station.Kind.WASH, Color(0.15, 0.45, 0.58), "WASH ITEMS / HOLD E")
	build_station(Vector3(4, 0, 6), Station.Kind.DISPLAY, Color(0.15, 0.035, 0.07), "RETURN ITEMS / E")
	var store := UpgradeStore.new()
	store.name = "UpgradeStore"
	store.position = Vector3(8.5, 0, 6.5)
	add_child(store)
	var waste := WasteBin.new()
	waste.name = "WasteBin"
	waste.position = Vector3(-3.5, 0, 6)
	add_child(waste)
	var waste_light := OmniLight3D.new()
	waste_light.name = "WasteLamp"
	waste_light.position = waste.position + Vector3(0, 3, 0)
	waste_light.light_color = Color(0.77, 0.93, 0.66)
	waste_light.omni_range = 6.0
	barn.add_child(waste_light)

func build_station(at: Vector3, kind: Station.Kind, color: Color, caption: String) -> void:
	Props.box(self, at + Vector3(0, 0.5, 0), Vector3(1.6, 1.0, 1.1), Color(0.12, 0.2, 0.25))
	var top := Props.box(self, at + Vector3(0, 1.02, 0), Vector3(1.3, 0.08, 0.85), color, false)
	if kind == Station.Kind.DISPLAY:
		var velvet := (top.get_child(0) as MeshInstance3D).material_override as StandardMaterial3D
		velvet.roughness = 1.0
		velvet.metallic_specular = 0.1
		velvet.rim_enabled = true
		velvet.rim = 0.25
	var station := Station.new()
	station.name = "WashingStation" if kind == Station.Kind.WASH else "CollectionBox"
	station.kind = kind
	station.position = at + Vector3(0, 1.07, 0)
	add_child(station)
	var task_light := OmniLight3D.new()
	task_light.position = at + Vector3(0, 2.5, 0.5)
	task_light.omni_range = 4.5
	task_light.light_energy = 1.3
	task_light.light_color = Color(0.55, 0.85, 1.0) if kind == Station.Kind.WASH else Color(1.0, 0.78, 0.45)
	add_child(task_light)
	Props.sign_at(self, caption, at + Vector3(0, 1.8, -0.4))
	if kind == Station.Kind.DISPLAY:
		for x in [-0.73, 0.73]:
			Props.box(self, at + Vector3(x, 1.12, 0), Vector3(0.1, 0.22, 1), color)
		for z in [-0.48, 0.48]:
			Props.box(self, at + Vector3(0, 1.12, z), Vector3(1.5, 0.22, 0.08), color)

func build_foam_and_pearls() -> void:
	foam_mesh = FoamMesh.new()
	stages.configure(foam_mesh)
	var grid: Vector2i = settings.mesh_grid()
	foam_mesh.columns = grid.x
	foam_mesh.rows = grid.y
	foam_mesh.name = "FoamMesh"
	add_child(foam_mesh)
	pearls = foam_mesh.pearls

func build_ui() -> void:
	var layer := CanvasLayer.new()
	hud = layer
	layer.name = "UI"
	add_child(layer)
	status = Label.new()
	status.position = Vector2(28, 22)
	status.add_theme_font_size_override("font_size", 24)
	layer.add_child(status)
	var controls := Label.new()
	controls.text = "WASD move / Space jump / LMB dig or scan / E interact\n1–5 tools / Q dump foam / G drop item / R restart / Esc pause"
	controls.position = Vector2(28, 80)
	layer.add_child(controls)
	loadout = Label.new()
	loadout.position = Vector2(28, 135)
	layer.add_child(loadout)
	bucket_status = Label.new()
	bucket_status.position = Vector2(28, 163)
	layer.add_child(bucket_status)
	hint = Label.new()
	layer.add_child(hint)
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hint.offset_left = -340
	hint.offset_right = 340
	hint.offset_top = -80
	hint.offset_bottom = -20
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 20)
	var crosshair := Label.new()
	crosshair.text = "+"
	layer.add_child(crosshair)
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.offset_left = -7
	crosshair.offset_right = 12
	crosshair.offset_top = -14
	crosshair.offset_bottom = 16
	crosshair.add_theme_font_size_override("font_size", 24)
	detector = ProgressBar.new()
	detector.position = Vector2(28, 197)
	detector.size = Vector2(250, 20)
	layer.add_child(detector)
	result = Label.new()
	layer.add_child(result)
	result.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	result.offset_left = -500
	result.offset_right = 500
	result.offset_top = -90
	result.offset_bottom = 90
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result.add_theme_font_size_override("font_size", 32)

func _process(_delta: float) -> void:
	hud.visible = manager.phase != GameManager.Phase.INTRO and not player.store_open
	var seconds := int(ceil(manager.remaining))
	status.text = tr("NIGHT SHIFT | %d / %d items | Boss %02d:%02d | %d credits") % [manager.collected, manager.total, seconds / 60, seconds % 60, manager.credits]
	var slots := PackedStringArray()
	for index in range(3):
		var label: String = "%d %s" % [index + 1, TOOL_NAMES[index]]
		if not manager.owns_tool(index):
			label += " (locked)"
		if player.tools.selected_tool == index:
			label = "[ " + label + " ]"
		slots.append(label)
	loadout.text = "   ".join(slots)
	var capacity_text := "∞" if manager.debug_infinite_bucket else str(roundi(player.bucket_capacity() * 1000))
	bucket_status.text = tr("BUCKET  %d / %s L   —   dump at the green-lit waste bin") % [roundi(player.bucket_load * 1000), capacity_text]
	if not manager.owns_upgrade("bucket"):
		bucket_status.text = tr("HANDS %d / 12 L — dump foam to earn bucket money") % roundi(player.bucket_load * 1000)
	bucket_status.modulate = Color(1, 0.58, 0.28) if player.bucket_load >= player.bucket_capacity() - 0.000001 else Color(0.75, 0.87, 0.85)
	hint.text = player.prompt if manager.running else "R • play again"
	if player.held != null and manager.running:
		hint.text += tr("\n%s: %d%% clean") % [player.held.localized_name(), int((1.0 - player.held.residue) * 100)]
	detector.visible = manager.running and player.tools.selected_tool == 2
	detector.value = player.detector_strength * 100.0
	detector.modulate = Color(0.4, 1.0, 0.8, 0.65 + 0.35 * sin(Time.get_ticks_msec() * 0.001 * lerpf(3.0, 18.0, player.detector_strength)))
	# Keep legacy HUD references for scene compatibility, but render only icons.
	for child in hud.get_children():
		if child is CanvasItem:
			child.visible = child == minimal_hud

func on_game_ended(won: bool) -> void:
	result.text = tr("EVERY PEARL ACCOUNTED FOR.\nFootsteps in the aisle. Close the box. Act normal.") if won else tr("THE SUPERVISOR IS HERE.\n%d of %d pearls returned. That will be a long conversation.") % [manager.collected, manager.total]

