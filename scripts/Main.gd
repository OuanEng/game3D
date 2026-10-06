extends Node3D
## Complete asset-free demonstration. Gameplay is separated into reusable scripts.
var manager: GameManager
var player: Player
var status: Label
var hint: Label
var result: Label
var detector: ProgressBar
var pearls: Array[Pearl] = []
var barn: BarnEnvironment
var foam_mesh: FoamMesh
var intro: IntroCutscene
var hud: CanvasLayer
var shop: UpgradeUI
var loadout: Label
const TOOL_NAMES := ["Scoop", "UV", "Detector"]
var bucket_status: Label

func _ready() -> void:
	setup_input()
	manager = GameManager.new()
	manager.name = "GameManager"
	add_child(manager)
	build_room()
	build_foam_and_pearls()
	player = Player.new()
	player.name = "Player"
	player.manager = manager
	player.pile = foam_mesh
	player.position = Vector3(0, 0, 5.5)
	add_child(player)
	shop = UpgradeUI.new()
	shop.name = "StoreUI"
	add_child(shop)
	player.shop_requested.connect(func(): shop.open_store(player, manager))
	build_ui()
	manager.game_ended.connect(on_game_ended)
	manager.prepare(pearls)
	intro = IntroCutscene.new()
	intro.name = "IntroCutscene"
	intro.player = player
	intro.barn = barn
	intro.pearls = pearls
	add_child(intro)
	intro.finished.connect(manager.begin_search)
	intro.play()

func setup_input() -> void:
	var bindings := {"forward": KEY_W, "back": KEY_S, "left": KEY_A, "right": KEY_D, "interact": KEY_E, "drop": KEY_G, "restart": KEY_R, "skip_intro": KEY_SPACE, "mute": KEY_M, "toggle_flicker": KEY_F, "tool_1": KEY_1, "tool_2": KEY_2, "tool_3": KEY_3}
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
	barn = BarnEnvironment.new()
	barn.name = "Barn"
	add_child(barn)
	build_station(Vector3(-5, 0, 3), Station.Kind.WASH, Color(0.15, 0.45, 0.58), "RINSE / HOLD E")
	build_station(Vector3(5, 0, 3), Station.Kind.DISPLAY, Color(0.15, 0.035, 0.07), "VELVET BOX / E")
	var store := UpgradeStore.new()
	store.name = "UpgradeStore"
	store.position = Vector3(7, 0, 5)
	add_child(store)
	var waste := WasteBin.new()
	waste.name = "WasteBin"
	waste.position = Vector3(-7, 0, 5)
	add_child(waste)
	barn.hanging_lamp("WasteLamp", Vector3(-7, 4.5, 5), Vector3(-7, 0.8, 5), Color(0.77, 0.93, 0.66), 2.1, 37.0, false)

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
	Props.sign_at(self, caption, at + Vector3(0, 1.8, -0.4))
	if kind == Station.Kind.DISPLAY:
		for x in [-0.73, 0.73]:
			Props.box(self, at + Vector3(x, 1.12, 0), Vector3(0.1, 0.22, 1), color)
		for z in [-0.48, 0.48]:
			Props.box(self, at + Vector3(0, 1.12, z), Vector3(1.5, 0.22, 0.08), color)

func build_foam_and_pearls() -> void:
	foam_mesh = FoamMesh.new()
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
	controls.text = "WASD move  /  LMB click: scoop, hold: scan  /  E retrieve, rinse, place, shop, dump\n1–3 or wheel: tools  /  G drop pearl  /  R restart  /  Esc cursor  /  M mute  /  F flicker"
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
	status.text = "PEARL PANIC / THE BARN  |  %d / %d returned  |  Boss %02d:%02d  |  %d credits" % [manager.collected, manager.total, seconds / 60, seconds % 60, manager.credits]
	var slots := PackedStringArray()
	for index in range(3):
		var label: String = "%d %s" % [index + 1, TOOL_NAMES[index]]
		if not manager.owns_tool(index):
			label += " (locked)"
		if player.tools.selected_tool == index:
			label = "[ " + label + " ]"
		slots.append(label)
	loadout.text = "   ".join(slots)
	bucket_status.text = "BUCKET  %d / %d L   —   dump at the green-lit waste bin" % [roundi(player.bucket_load * 1000), roundi(player.bucket_capacity() * 1000)]
	bucket_status.modulate = Color(1, 0.58, 0.28) if player.bucket_load >= player.bucket_capacity() - 0.000001 else Color(0.75, 0.87, 0.85)
	hint.text = player.prompt if manager.running else "R • play again"
	if player.held != null and manager.running:
		hint.text += "\nHeld pearl: %d%% clean" % int((1.0 - player.held.residue) * 100)
	detector.visible = manager.running and player.tools.selected_tool == 2
	detector.value = player.detector_strength * 100.0
	detector.modulate = Color(0.4, 1.0, 0.8, 0.65 + 0.35 * sin(Time.get_ticks_msec() * 0.001 * lerpf(3.0, 18.0, player.detector_strength)))

func on_game_ended(won: bool) -> void:
	result.text = "EVERY PEARL ACCOUNTED FOR.\nFootsteps in the aisle. Close the box. Act normal." if won else "THE SUPERVISOR IS HERE.\n%d of %d pearls returned. That will be a long conversation." % [manager.collected, manager.total]

