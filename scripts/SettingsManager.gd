extends Node
## Persistent preferences. Mesh density is applied only when Main builds a shift.
const PATH := "user://settings.cfg"
const ACTIONS := ["forward", "back", "left", "right", "jump", "interact", "dump_foam", "throw_item", "drop", "brush", "tool_1", "tool_2", "tool_3", "tool_4", "tool_5"]
const ACTION_NAMES := ["Move forward", "Move backward", "Move left", "Move right", "Jump", "Interact", "Dump foam", "Throw item", "Drop item", "Dig / Use tool", "Tool 1", "Tool 2", "Tool 3", "Tool 4", "Tool 5"]
var world: Node3D
var values := {"language": "en", "master": 1.0, "bgm": 1.0, "sfx": 1.0, "focus_mute": false, "resolution": 0, "fullscreen": false, "vsync": true, "quality": 1, "blur": false, "sensitivity": 0.002, "invert": false}
var bindings: Dictionary = {}
var defaults: Dictionary = {}
static var base_defaults: Dictionary = {}
var pending_action := ""
var pending_button: Button
var focused := true
var blur_rect: ColorRect
var previous_rotation := Vector3.ZERO
var save_enabled := true
const RESOLUTIONS := [Vector2i(1280,720), Vector2i(1600,900), Vector2i(1920,1080)]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for action in ACTIONS:
		if not base_defaults.has(action):
			base_defaults[action] = InputMap.action_get_events(action).duplicate()
		defaults[action] = base_defaults[action]
	for bus in ["BGM", "SFX"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus)
			AudioServer.set_bus_send(index, "Master")
	var config := ConfigFile.new()
	if config.load(PATH) == OK:
		for key in values:
			var loaded: Variant = config.get_value("options", key, values[key])
			if typeof(loaded) == typeof(values[key]):
				values[key] = loaded
		bindings = config.get_value("controls", "bindings", {})
	for key in ["master", "bgm", "sfx"]:
		values[key] = clampf(values[key], 0, 1)
	values.quality = clampi(values.quality, 0, 2)
	values.resolution = clampi(values.resolution, 0, 2)
	values.sensitivity = clampf(values.sensitivity, 0.0005, 0.006)
	if values.language not in ["en", "th"]:
		values.language = "en"
	TranslationServer.set_locale(values.language)
	for action in bindings:
		if action in ACTIONS:
			install_binding(action, int(bindings[action]))
	apply_audio()
	apply_display()

func save() -> void:
	if not save_enabled:
		return
	var config := ConfigFile.new()
	for key in values:
		config.set_value("options", key, values[key])
	config.set_value("controls", "bindings", bindings)
	config.save(PATH)

func mesh_grid() -> Vector2i:
	return [Vector2i(41,33), Vector2i(65,53), Vector2i(81,65)][values.quality]

func apply_to_world() -> void:
	world.player.mouse_sensitivity = values.sensitivity
	world.player.invert_y = values.invert
	route_audio(world)
	var layer := CanvasLayer.new()
	layer.layer = -1
	add_child(layer)
	blur_rect = ColorRect.new()
	blur_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(blur_rect)
	blur_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/CameraBlur.gdshader")
	blur_rect.material = material
	previous_rotation = world.player.camera.global_rotation

func route_audio(node: Node) -> void:
	if node is AudioStreamPlayer:
		node.bus = "BGM" if node.get_script() == preload("res://scripts/AmbientMusic.gd") else "SFX"
	for child in node.get_children():
		route_audio(child)

func apply_audio() -> void:
	for key in ["master", "bgm", "sfx"]:
		var bus_name: String = {"master":"Master", "bgm":"BGM", "sfx":"SFX"}[key]
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus_name), linear_to_db(maxf(0.00001, values[key])))
	AudioServer.set_bus_mute(0, values.focus_mute and not focused)

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		focused = what == NOTIFICATION_APPLICATION_FOCUS_IN
		apply_audio()

func apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if values.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	if not values.fullscreen:
		DisplayServer.window_set_size(RESOLUTIONS[values.resolution])
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if values.vsync else DisplayServer.VSYNC_DISABLED)

func set_value(key: String, value: Variant) -> void:
	values[key] = value
	if key == "language":
		TranslationServer.set_locale(value)
		world.menus.call_deferred("show_settings")
	elif key in ["master", "bgm", "sfx", "focus_mute"]:
		apply_audio()
	elif key in ["resolution", "fullscreen", "vsync"]:
		apply_display()
	elif key == "sensitivity":
		world.player.mouse_sensitivity = value
	elif key == "invert":
		world.player.invert_y = value
	save()

func _process(_delta: float) -> void:
	if not is_instance_valid(blur_rect):
		return
	var rotation: Vector3 = world.player.camera.global_rotation
	var motion := Vector2(angle_difference(previous_rotation.y, rotation.y), angle_difference(previous_rotation.x, rotation.x))
	previous_rotation = rotation
	blur_rect.visible = values.blur and world.manager.running and not get_tree().paused and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	blur_rect.material.set_shader_parameter("motion", motion.limit_length(0.025) * 0.3)

func row(parent: Node, title: String) -> HBoxContainer:
	var line := HBoxContainer.new()
	parent.add_child(line)
	var label := Label.new()
	label.text = title
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(label)
	return line

func dropdown(parent: Node, title: String, choices: Array, selected: int, callback: Callable) -> void:
	var line := row(parent, title)
	var option := OptionButton.new()
	option.custom_minimum_size.x = 210
	for choice in choices:
		option.add_item(tr(choice))
	option.select(selected)
	option.item_selected.connect(callback)
	line.add_child(option)

func slider(parent: Node, title: String, key: String, minimum: float, maximum: float, step: float) -> void:
	var line := row(parent, title)
	var control := HSlider.new()
	control.custom_minimum_size.x = 210
	control.min_value = minimum
	control.max_value = maximum
	control.step = step
	control.value = values[key]
	control.value_changed.connect(func(value: float): set_value(key, value))
	line.add_child(control)

func toggle(parent: Node, title: String, key: String) -> void:
	var control := CheckButton.new()
	control.text = title
	control.button_pressed = values[key]
	control.toggled.connect(func(value: bool): set_value(key, value))
	parent.add_child(control)

func build_ui(parent: Node) -> void:
	pending_action = ""
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 450
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 12)
	scroll.add_child(list)
	dropdown(list, "Language", ["English", "ภาษาไทย"], 1 if values.language == "th" else 0, func(i: int): set_value("language", "en" if i == 0 else "th"))
	for key in ["master", "bgm", "sfx"]:
		slider(list, {"master":"Master Volume", "bgm":"BGM Volume", "sfx":"SFX Volume"}[key], key, 0, 1, 0.01)
	toggle(list, "Mute on focus loss", "focus_mute")
	dropdown(list, "Resolution", ["1280 × 720", "1600 × 900", "1920 × 1080"], values.resolution, func(i: int): set_value("resolution", i))
	dropdown(list, "Display Mode", ["Windowed", "Fullscreen"], int(values.fullscreen), func(i: int): set_value("fullscreen", i == 1))
	toggle(list, "V-Sync", "vsync")
	dropdown(list, "Foam mesh (next shift)", ["Low", "Medium", "High"], values.quality, func(i: int): set_value("quality", i))
	toggle(list, "Motion blur (camera rotation)", "blur")
	slider(list, "Mouse sensitivity", "sensitivity", 0.0005, 0.006, 0.0001)
	toggle(list, "Invert Y axis", "invert")
	for i in range(ACTIONS.size()):
		var line := row(list, ACTION_NAMES[i])
		var button := Button.new()
		button.custom_minimum_size.x = 210
		button.text = InputMap.action_get_events(ACTIONS[i])[0].as_text()
		button.pressed.connect(func(): pending_action = ACTIONS[i]; pending_button = button; button.text = tr("Press a key · Esc cancels"))
		line.add_child(button)
	var reset := Button.new()
	reset.text = "Reset controls"
	reset.pressed.connect(reset_controls)
	list.add_child(reset)

func install_binding(action: String, code: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, event)

func control_hint(text: String) -> String:
	# One pass prevents chained replacement when two keys have been reassigned.
	var pattern := RegEx.new()
	pattern.compile("(?<![A-Za-z0-9])[QEFG](?![A-Za-z0-9])")
	var actions := {"Q":"dump_foam", "E":"interact", "F":"throw_item", "G":"drop"}
	var matches := pattern.search_all(text)
	for i in range(matches.size() - 1, -1, -1):
		var found: RegExMatch = matches[i]
		var event: InputEvent = InputMap.action_get_events(actions[found.get_string()])[0]
		var name := OS.get_keycode_string(event.physical_keycode) if event is InputEventKey else event.as_text()
		text = text.substr(0, found.get_start()) + name + text.substr(found.get_end())
	return text

func reset_controls() -> void:
	bindings.clear()
	for action in defaults:
		InputMap.action_erase_events(action)
		for event in defaults[action]:
			InputMap.action_add_event(action, event)
	save()
	world.menus.call_deferred("show_settings")

func _input(event: InputEvent) -> void:
	if pending_action.is_empty() or not event is InputEventKey or not event.pressed:
		return
	get_viewport().set_input_as_handled()
	if event.physical_keycode == KEY_ESCAPE:
		pending_action = ""
		world.menus.call_deferred("show_settings")
		return
	# Reject reserved and duplicate keys rather than silently breaking another action.
	for action in InputMap.get_actions():
		if action != pending_action and InputMap.event_is_action(event, action):
			pending_button.text = tr("Key already in use")
			return
	if event.physical_keycode == KEY_F3:
		pending_button.text = tr("Key already in use")
		return
	bindings[pending_action] = int(event.physical_keycode)
	install_binding(pending_action, event.physical_keycode)
	pending_action = ""
	save()
	world.menus.call_deferred("show_settings")
