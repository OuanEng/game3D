extends CanvasLayer
## This node alone processes during pause. Gameplay and the boss clock inherit
## the default pausable mode. The title camera stays independent of the player.
var world: Node3D
var panel: PanelContainer
var column: VBoxContainer
var title_camera: Camera3D
var screen := "main"
var settings_return := "main"
var orbit := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 40
	title_camera = Camera3D.new()
	world.add_child(title_camera)
	title_camera.position = Vector3(9, 6.5, 9.5)
	title_camera.look_at(Vector3(0, 2, -1.6))
	title_camera.current = true
	panel = PanelContainer.new()
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	panel.offset_left = 45
	panel.offset_right = 505
	panel.offset_top = -310
	panel.offset_bottom = 310
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.015, 0.025, 0.04, 0.91)
	style.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", style)
	column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	panel.add_child(column)
	show_main()

func clear_panel(title: String) -> void:
	panel.offset_right = 505
	for child in column.get_children():
		column.remove_child(child)
		child.queue_free()
	var heading := Label.new()
	heading.text = title
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.custom_minimum_size.x = 360
	heading.add_theme_font_size_override("font_size", 32)
	column.add_child(heading)
	show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func button(text: String, action: Callable) -> void:
	var control := Button.new()
	control.text = text
	control.custom_minimum_size.y = 48
	control.add_theme_font_size_override("font_size", 20)
	control.pressed.connect(action)
	column.add_child(control)

func show_main() -> void:
	screen = "main"
	clear_panel("Hidden in Foam")
	button("Career · Choose Stage", func(): show_stages(false))
	button("Hardcore · Choose Stage", func(): show_stages(true))
	button("Upgrades", show_catalog)
	button("Settings", show_settings)
	button("Quit", quit_game)
	world.hud.hide()

func start_shift(mode: GameManager.Mode = GameManager.Mode.NORMAL) -> void:
	world.foam_mesh.configure_fresh_grid(world.settings.mesh_grid())
	world.manager.select_mode(mode)
	world.stages.begin()
	screen = "playing"
	hide()
	world.intro.play()

func _process(delta: float) -> void:
	if screen in ["main", "catalog"] or (screen == "settings" and settings_return == "main"):
		orbit += delta * 0.08
		title_camera.position.x = 9.0 + sin(orbit) * 0.5
		title_camera.look_at(Vector3(0, 2, -1.6))

func _input(event: InputEvent) -> void:
	if not world.settings.pending_action.is_empty():
		return
	if world.get_node_or_null("DebugPanel") != null and world.get_node("DebugPanel").is_open:
		return
	if not event.is_action_pressed("ui_cancel") or world.shop.is_open:
		return
	if screen == "playing" and world.manager.running:
		show_pause()
	elif screen == "pause":
		resume()
	elif screen == "settings":
		back_from_settings()
	elif screen in ["catalog", "stages"]:
		show_main()
	get_viewport().set_input_as_handled()

func show_pause() -> void:
	screen = "pause"
	get_tree().paused = true
	clear_panel("SHIFT PAUSED")
	button("Resume", resume)
	if not world.manager.is_hardcore():
		button("Upgrades", pause_upgrades)
	button("Settings", show_settings)
	button("Return to Main Menu", return_to_main)

func switch_language() -> void:
	preload("res://scripts/Localization.gd").toggle()
	if screen == "pause":
		show_pause()
	else:
		show_main()

func resume() -> void:
	get_tree().paused = false
	screen = "playing"
	hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func pause_upgrades() -> void:
	if world.manager.is_hardcore():
		return
	hide()
	world.shop.open_store(world.player, world.manager)
	world.shop.closed.connect(show_pause, CONNECT_ONE_SHOT)

func return_to_main() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func show_catalog() -> void:
	screen = "catalog"
	clear_panel("SUPPLY CATALOG")
	var info := Label.new()
	info.text = "12 upgrades · next levels cost 1.85x\n\nBucket / Scoop / Rapid gloves\nUV light / Acoustic detector\nBlower / Vacuum / Washing belt\nCarry boots / Battery / Grabber\nBoss distraction\n\nStart empty-handed. Dump foam for credits.\nBuy at the desk or from Pause → Upgrades."
	column.add_child(info)
	button("Back", show_main)

func show_stages(hardcore: bool) -> void:
	screen = "stages"
	clear_panel("Hardcore · Choose Stage" if hardcore else "Career · Choose Stage")
	var info := Label.new()
	info.text = "Sand requires Scoop II or Vacuum. Replay earlier stages to prepare."
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size.x = 360
	column.add_child(info)
	for index in range(4):
		var stage: Dictionary = world.stages.STAGES[index]
		button("%d · %s" % [index + 1, tr(stage.title)], world.stages.launch.bind(index, GameManager.Mode.HARDCORE if hardcore else GameManager.Mode.NORMAL))
		var choice := column.get_child(column.get_child_count() - 1) as Button
		choice.disabled = not world.stages.can_enter(index, hardcore)
	button("Back", show_main)

func show_settings() -> void:
	if screen != "settings":
		settings_return = screen
	screen = "settings"
	clear_panel("SETTINGS")
	panel.offset_right = 760
	world.settings.build_ui(column)
	button("Back", back_from_settings)

func back_from_settings() -> void:
	if settings_return == "results":
		show_results(world.manager.phase == GameManager.Phase.WON)
	elif settings_return == "pause":
		show_pause()
	else:
		show_main()

func quit_game() -> void:
	if OS.has_feature("web"):
		clear_panel("SHIFT CLOSED")
		button("Return to Main Menu", show_main)
	else:
		get_tree().quit()

func show_results(won: bool) -> void:
	# Connected after StageManager.complete: unlocks and career save are ready.
	screen = "results"
	clear_panel("SHIFT COMPLETE" if won else "THE BOSS HAS ARRIVED")
	var info := Label.new()
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size.x = 360
	info.text = tr("Returned %d / %d items") % [world.manager.collected, world.manager.total]
	column.add_child(info)
	var next_index: int = world.stages.selected_stage + 1
	if won and next_index < world.stages.STAGES.size():
		button("Next Stage", world.stages.launch.bind(next_index, world.manager.mode))
		var next_button := column.get_child(column.get_child_count() - 1) as Button
		next_button.disabled = not world.stages.can_enter(next_index, world.manager.is_hardcore())
		if next_button.disabled:
			var requirement := Label.new()
			requirement.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			requirement.text = "This stage is unavailable in Hardcore." if world.manager.is_hardcore() else "Sand requires Scoop II or Vacuum. Replay earlier stages to prepare."
			column.add_child(requirement)
	elif won:
		info.text += "\n" + tr("All four stages complete!")
	button("Settings", show_settings)
	button("Return to Main Menu", return_to_main)
