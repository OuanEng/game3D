extends Control
## Vector icons stay crisp at any viewport scale; text is limited to numbers,
## a contextual action hint and the end-of-shift result.
var world: Node3D
var ink := Color(0.8, 0.9, 0.88, 0.8)
var accent := Color(0.48, 0.85, 0.73)
var capacity_bar: ProgressBar
var capacity_label: Label
var stage_hint: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Actual UI controls, anchored to the left edge; fill rises from the bottom.
	capacity_bar = ProgressBar.new()
	capacity_bar.name = "LeftCapacityBar"
	capacity_bar.fill_mode = ProgressBar.FILL_BOTTOM_TO_TOP
	capacity_bar.show_percentage = false
	capacity_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.03, 0.055, 0.065, 0.82)
	background.set_corner_radius_all(6)
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = accent
	fill_style.set_corner_radius_all(6)
	capacity_bar.add_theme_stylebox_override("background", background)
	capacity_bar.add_theme_stylebox_override("fill", fill_style)
	add_child(capacity_bar)
	capacity_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	capacity_bar.offset_left = 28
	capacity_bar.offset_right = 48
	capacity_bar.offset_top = -130
	capacity_bar.offset_bottom = 130
	capacity_label = Label.new()
	capacity_label.name = "CapacityReadout"
	add_child(capacity_label)
	capacity_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	capacity_label.offset_left = 23
	capacity_label.offset_right = 83
	capacity_label.offset_top = 140
	capacity_label.offset_bottom = 190
	capacity_label.add_theme_font_size_override("font_size", 18)
	capacity_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	stage_hint = Label.new()
	add_child(stage_hint)
	stage_hint.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	stage_hint.offset_left = 180
	stage_hint.offset_right = -180
	stage_hint.offset_top = 70
	stage_hint.offset_bottom = 160
	stage_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stage_hint.add_theme_font_size_override("font_size", 21)
	stage_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	stage_hint.text = world.settings.control_hint(tr(world.stages.event_message) if not world.stages.event_message.is_empty() else world.stages.tutorial_text())
	stage_hint.visible = world.manager.running
	var player: Player = world.player
	var fill := clampf(player.bucket_load / player.bucket_capacity(), 0.0, 1.0)
	capacity_bar.value = fill * 100.0
	capacity_bar.visible = world.manager.running
	capacity_label.visible = world.manager.running
	capacity_label.text = "%d%%\nQ" % roundi(fill * 100.0)
	if world.manager.debug_infinite_bucket:
		capacity_label.text = "∞\nQ"
	capacity_label.text = world.settings.control_hint(capacity_label.text)
	var fill_style := capacity_bar.get_theme_stylebox("fill") as StyleBoxFlat
	fill_style.bg_color = Color(1.0, 0.65, 0.35) if fill >= 0.999 else accent
	queue_redraw()

func label_at(at: Vector2, text: String, font_size: int = 19) -> void:
	draw_string(ThemeDB.fallback_font, at, world.settings.control_hint(tr(text)), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)

func _draw() -> void:
	var m: GameManager = world.manager
	var p: Player = world.player
	var clock := Vector2(size.x - 170, 32)
	draw_arc(clock, 9, 0, TAU, 32, ink, 1.5, true)
	draw_line(clock, clock + Vector2(0, -6), ink, 1.5)
	var seconds := int(ceil(m.remaining))
	label_at(clock + Vector2(18, 5), "%02d:%02d" % [seconds / 60, seconds % 60])
	label_at(Vector2(28, 36), "%d / %d    ·    $%d" % [m.collected, m.total, m.credits])
	if m.is_hardcore():
		label_at(Vector2(28, 58), tr("HARDCORE · HANDS ONLY"), 12)
	if not m.running:
		label_at(size * 0.5 - Vector2(200, 0), tr("SHIFT COMPLETE") if m.collected == m.total else tr("THE BOSS HAS ARRIVED"), 26)
		label_at(size * 0.5 + Vector2(-110, 36), tr("R · Return to Main Menu"))
		if m.phase == GameManager.Phase.WON and not m.is_hardcore():
			label_at(size * 0.5 + Vector2(-200, 70), tr("Career saved · bonus $%d") % world.stages.data().bonus)
		return
	if p.detector_strength > 0:
		var bearing := p.tools.detector_direction
		var origin := size * 0.5 + Vector2(0, 50)
		var tip := origin + Vector2(sin(bearing), -cos(bearing)) * 28
		draw_line(origin, tip, accent, 4, true)
		draw_circle(tip, 5, accent)
	draw_circle(size * 0.5, 2, ink)
	var start := Vector2(size.x * 0.5 - 164, size.y - 70)
	for i in range(5):
		if m.is_hardcore() and i > 0:
			continue
		var at := start + Vector2(i * 58, 0)
		var color := accent if p.tools.selected_tool == i else ink
		if not m.owns_tool(i):
			color.a = 0.18
		draw_style_box(slot_style(color, p.tools.selected_tool == i), Rect2(at, Vector2(48, 48)))
		var center := at + Vector2(24, 22)
		match i:
			0: # Hand / scoop silhouette.
				draw_line(center + Vector2(-8, 9), center + Vector2(5, -5), color, 3, true)
				draw_rect(Rect2(center + Vector2(0, -9), Vector2(12, 8)), color, false, 2)
			1:
				draw_rect(Rect2(center - Vector2(4, 0), Vector2(8, 12)), color, false, 2)
				draw_line(center, center + Vector2(-9, -10), color, 2)
				draw_line(center, center + Vector2(9, -10), color, 2)
			2:
				for r in [4, 9, 14]:
					draw_arc(center, r, PI, TAU, 16, color, 1.5, true)
			3:
				for row in [-6, 0, 6]:
					draw_line(center + Vector2(-11, row), center + Vector2(11, row), color, 2)
			4:
				draw_arc(center, 10, 0, PI, 16, color, 2, true)
				draw_line(center + Vector2(10, 0), center + Vector2(10, -10), color, 3)
	# Capacity is displayed only by the left vertical bar.
	var item_at := start + Vector2(320, 22)
	draw_arc(item_at, 13, 0, TAU, 32, ink, 1.2, true)
	if p.held != null:
		var item_color := Color(0.8, 0.66, 0.4) if p.held.residue > 0 else accent
		draw_circle(item_at, 7, item_color)
	var action := ""
	var destination: Node3D = null
	var destination_name := ""
	if p.bucket_load >= p.bucket_capacity() - 0.000001:
		destination = world.get_node("WasteBin")
		destination_name = tr("FOAM FULL · EMPTY HERE [Q]")
	elif p.held != null:
		destination = world.get_node("WashingStation" if p.held.residue > 0.0 else "CollectionBox")
		destination_name = tr("WASH HERE [HOLD E]") if p.held.residue > 0.0 else tr("RETURN HERE [E]")
		if p.held.residue > 0.0 and m.owns_upgrade("auto_washer"):
			destination_name = tr("WASH BELT [E] · THROW [F]")
	if destination != null:
		# Edge-clamped marker works even when the destination is behind the player.
		var target := destination.global_position + Vector3(0, 1.0, 0)
		var marker := p.camera.unproject_position(target)
		if p.camera.is_position_behind(target):
			var side := p.camera.to_local(target).x
			marker = Vector2(size.x - 160 if side >= 0 else 160, size.y * 0.5)
		marker.x = clampf(marker.x, 160, size.x - 160)
		marker.y = clampf(marker.y, 85, size.y - 120)
		draw_circle(marker, 5, accent)
		var caption := "%s · %.1f m" % [destination_name, p.global_position.distance_to(destination.global_position)]
		var caption_width := ThemeDB.fallback_font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		label_at(marker + Vector2(-caption_width / 2, -15), caption, 14)
	if p.prompt.begins_with("E") or p.prompt.begins_with("Q") or p.prompt.begins_with("Hold E") or p.prompt.begins_with("กด E") or p.prompt.contains("FULL") or p.prompt.contains("เต็ม") or Time.get_ticks_msec() < p.notice_until:
		action = p.prompt
	if not action.is_empty():
		var width := ThemeDB.fallback_font.get_string_size(action, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		label_at(Vector2((size.x - width) / 2, size.y - 86), action)

func slot_style(color: Color, selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.035, 0.045, 0.6)
	style.border_color = color
	style.set_border_width_all(2 if selected else 1)
	style.set_corner_radius_all(6)
	return style
