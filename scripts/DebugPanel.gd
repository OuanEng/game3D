extends CanvasLayer
## Session-only developer cheats. This overlay owns pause only while it is open.
## It cannot interrupt the intro, store, settings, pause menu or end screen.
var world: Node3D
var is_open := false
var highlight_all := false
var panel: PanelContainer
var markers: Array[MeshInstance3D] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 60
	panel = PanelContainer.new()
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -210
	panel.offset_right = 210
	panel.offset_top = -290
	panel.offset_bottom = 290
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.04, 0.055, 0.97)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	var title := Label.new()
	title.text = "DEVELOPER TOOLS · F3"
	title.add_theme_font_size_override("font_size", 22)
	column.add_child(title)
	add_button(column, "Unlock All Stages", unlock_all_stages)
	var stage_grid := GridContainer.new()
	stage_grid.columns = 2
	column.add_child(stage_grid)
	for index in range(4):
		var shortcut := Button.new()
		shortcut.text = tr("Go to Stage %d") % (index + 1)
		shortcut.custom_minimum_size = Vector2(175, 38)
		shortcut.pressed.connect(jump_to_stage.bind(index))
		stage_grid.add_child(shortcut)
	add_button(column, "+10,000 Cash", grant_cash)
	add_toggle(column, "Infinite Bucket Capacity", set_infinite)
	add_button(column, "Clear Foam Pile", clear_foam)
	add_toggle(column, "Highlight All Pearls", set_highlight)
	var note := Label.new()
	note.text = "Clear Foam cannot be undone this shift.\nStage unlocks are saved immediately."
	note.add_theme_font_size_override("font_size", 13)
	column.add_child(note)
	add_button(column, "Close · F3 / Esc", close_panel)
	hide()
	# Separate cheat markers never modify the balanced UV material or ray rules.
	for item in world.pearls:
		var marker := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = Pearl.RADIUS * 1.15
		sphere.height = sphere.radius * 2
		marker.mesh = sphere
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.no_depth_test = true
		material.albedo_color = Color(0.15, 1.0, 0.72)
		marker.material_override = material
		marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		marker.visible = false
		item.add_child(marker)
		markers.append(marker)

func jump_to_stage(index: int) -> void:
	if not is_open or index < 0 or index >= world.stages.STAGES.size():
		return
	# Explicit test shortcut: preserve the career checkpoint, discard current shift.
	# Persist unlocks so the reloaded scene can enter without prerequisite tools.
	world.stages.unlock_all_stages()
	close_panel()
	world.stages.launch(index, world.manager.mode)

func add_button(column: VBoxContainer, title: String, action: Callable) -> void:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size.y = 40
	button.pressed.connect(action)
	column.add_child(button)

func add_toggle(column: VBoxContainer, title: String, action: Callable) -> void:
	var toggle := CheckButton.new()
	toggle.text = title
	toggle.toggled.connect(action)
	column.add_child(toggle)

func _input(event: InputEvent) -> void:
	var f3: bool = event is InputEventKey and event.physical_keycode == KEY_F3 and event.pressed and not event.echo
	if is_open and (f3 or event.is_action_pressed("ui_cancel")):
		close_panel()
		get_viewport().set_input_as_handled()
	elif f3 and open_panel():
		get_viewport().set_input_as_handled()

func open_panel() -> bool:
	if is_open or get_tree().paused or world.shop.is_open or world.menus.screen != "playing" or not world.manager.running:
		return false
	is_open = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	show()
	return true

func close_panel() -> void:
	if not is_open:
		return
	is_open = false
	hide()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func grant_cash() -> void:
	if not is_open:
		return
	world.manager.debug_used = true
	world.manager.credits += 10000
	world.manager.wallet_changed.emit(world.manager.credits)

func set_infinite(enabled: bool) -> void:
	world.manager.debug_used = world.manager.debug_used or enabled
	world.manager.debug_infinite_bucket = enabled
	# Retain all previously excavated foam on disable, even if over capacity.
	# Digging then stops until Q empties the inventory at the normal waste bin.
	world.player.bucket_changed.emit(world.player.bucket_load, world.player.bucket_capacity())

func clear_foam() -> void:
	if is_open:
		world.manager.debug_used = true
		world.foam_mesh.debug_clear()

func set_highlight(enabled: bool) -> void:
	world.manager.debug_used = world.manager.debug_used or enabled
	highlight_all = enabled
	update_markers()

func _process(_delta: float) -> void:
	update_markers()

func update_markers() -> void:
	for marker in markers:
		var item := marker.get_parent() as Pearl
		marker.visible = highlight_all and world.manager.running and item.state not in [Pearl.State.HELD, Pearl.State.COLLECTED]

func unlock_all_stages() -> void:
	if not is_open:
		return
	world.stages.unlock_all_stages()
	world.player.notice = tr("All stages unlocked. Return to Main Menu to choose a stage.")
	world.player.notice_until = Time.get_ticks_msec() + 6000
	close_panel()
