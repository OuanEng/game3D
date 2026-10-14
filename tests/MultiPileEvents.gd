extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		push_error(description)
func run() -> void:
	preload("res://scripts/StageManager.gd").selected_stage = 3
	var world: Node3D = load("res://Main.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	world.menus.start_shift()
	world.intro.complete()
	world.player.set_physics_process(false)
	world.stages.set_physics_process(false)
	var m: GameManager = world.manager
	var p: Player = world.player
	m.set_physics_process(false)
	check(world.foam_piles.size() == 3 and m.total == 8, "Three piles, eight registered items")
	m.credits = 100000
	check(not m.buy_upgrade("battery_pack"), "Cannot recharge an unowned blower")
	check(m.buy_upgrade("blower"), "Buy blower")
	check(not m.buy_upgrade("battery_pack"), "Full battery cannot waste money")
	check(is_equal_approx(m.consume_blower(30), 18.0) and m.blower_charge == 0, "Motor funds only available seconds")
	check(m.consume_blower(1) == 0, "Empty motor cannot work")
	check(m.buy_upgrade("battery_pack") and m.blower_charge == 18, "Recharge restores capacity")
	check(m.upgrade_price("battery_pack") == 95, "Recharge price escalates")
	m.consume_blower(4)
	check(m.buy_upgrade("battery") and m.blower_charge == 14 and m.blower_capacity() == 26, "Capacity upgrade does not refill charge")
	paused = true
	check(m.consume_blower(1) == 0 and m.blower_charge == 14, "Pause prevents drain")
	paused = false
	p.tools.select_tool(0)
	p.tools.select_tool(3)
	check(m.blower_charge == 14, "Switching preserves charge")
	m.mode = GameManager.Mode.HARDCORE
	check(not m.buy_upgrade("battery_pack") and m.consume_blower(1) == 0, "Hardcore rejects battery and motor")
	m.mode = GameManager.Mode.NORMAL
	for pile: FoamMesh in world.foam_piles:
		p.pile = pile
		p.bucket_load = 0
		p.carried_materials.clear()
		var before := pile.remaining_volume()
		var removed := p.try_scoop_at(pile.to_global(pile.mound_center))
		check(removed > 0 and absf(before - pile.remaining_volume() - removed) < 0.000001, "Every pile supports volume-conserving excavation")
		check(is_equal_approx(p.carried_materials[pile.material_kind], removed), "Inventory retains actual material")
		var volume := pile.remaining_volume()
		var start := Time.get_ticks_usec()
		var moved := pile.avalanche(Vector3(0,0,8))
		print("AVALANCHE material=%d moved=%.4f rebuild_ms=%.2f" % [pile.material_kind, moved, (Time.get_ticks_usec() - start) / 1000.0])
		check(moved > 0 and absf(volume - pile.remaining_volume()) < 0.000001, "Avalanche conserves volume")
		var item: Pearl = pile.pearls[0]
		item.global_position = pile.to_global(pile.mound_center) + Vector3.UP * 0.3
		item.state = Pearl.State.FREE
		item._physics_process(0)
		check(item.state == Pearl.State.EMBEDDED and item.freeze, "Buried released pearl is safely frozen")
	# Regression: a physics escape outside all piles must recover, not rebury below floor.
	var escaped: Pearl = world.pearls[0]
	escaped.state = Pearl.State.FREE
	escaped.global_position = Vector3(11,-4,10)
	escaped._physics_process(0)
	check(escaped.global_position.y >= 0.0, "Escaped item recovers before material burial")
	# A thrown item keeps its identity but uses the destination pile's UV shader.
	var original_position := escaped.global_position
	var original_container := escaped.foam_container
	var destination: FoamMesh = world.foam_piles[1]
	var at := destination.to_global(destination.mound_center)
	at.y = destination.sample_height(at) - Pearl.RADIUS - 0.10
	escaped.global_position = at
	escaped.state = Pearl.State.FREE
	escaped._physics_process(0)
	m.owned.uv = 1
	p.tools.pile = destination
	p.tools._update_uv(at + Vector3.UP * 2.0, Vector3.DOWN)
	check(escaped.foam_container == destination and escaped.uv_strength > 0.0, "Cross-pile UV detects near-surface item")
	check(int(destination.material.get_shader_parameter("uv_hint_count")) > 0, "UV hint belongs to destination surface")
	escaped.global_position = original_position
	escaped.foam_container = original_container
	escaped.state = Pearl.State.EMBEDDED
	# Aim actual tool rays down at each separate collider, including final ticks.
	p.tools.select_tool(3)
	for pile: FoamMesh in world.foam_piles:
		p.camera.global_position = pile.to_global(pile.mound_center) + Vector3(0, pile.mound_height + 1, 0)
		p.camera.rotation = Vector3(-PI / 2, 0, 0)
		await physics_frame
		var before := pile.remaining_volume()
		m.blower_charge = 0.05
		p.tools.use_tool(0.1, true, p.camera)
		check(pile.remaining_volume() < before and m.blower_charge == 0, "Blower funds partial cut on every pile")
		before = pile.remaining_volume()
		p.tools.use_tool(0.1, true, p.camera)
		check(pile.remaining_volume() == before, "No excavation with empty battery")
	p.camera.position = Vector3(0,1.55,0)
	p.camera.rotation = Vector3.ZERO
	p.bucket_load = 0
	p.carried_materials.clear()
	world.stages.trigger_event(0)
	check(world.stages.outage_lights.size() > 0 and p.work_light.visible, "Outage preserves player light")
	world.stages.end_event()
	check(world.stages.outage_lights.is_empty(), "Outage cleanup")
	world.stages.trigger_event(4)
	m.owned.detector = 1
	p.tools.select_tool(2)
	p.tools.use_tool(0.1, true, p.camera)
	check(world.stages.sensor_disabled and p.tools.detector_strength == 0, "Glitch disables detector")
	world.stages.end_event()
	check(not world.stages.sensor_disabled, "Sensor restored")
	world.stages.trigger_event(3)
	var events: Node = world.stages.events
	var old_density: float = events.saved_fog.fog_density
	p.global_position = world.foam_piles[1].mound_center + Vector3(0,4,0)
	events.tick(0.1)
	check(events.environment.fog_density > old_density, "Dust increases fog in sand zone")
	var environment: Environment = events.environment
	world.stages.end_event()
	check(is_equal_approx(environment.fog_density, old_density), "Dust restores original density")
	for item in world.pearls:
		item.residue = 0
	p.global_position = Vector3(0,0,8)
	p.bucket_load = 0.01
	await physics_frame
	world.stages.trigger_event(2)
	var before_time := m.remaining
	events.resolve()
	check(m.remaining == before_time - 30, "Exposed trash causes bounded patrol penalty")
	events.resolve()
	check(m.remaining == before_time - 30, "Patrol cannot resolve twice")
	world.stages.end_event()
	p.bucket_load = 0
	world.stages.trigger_event(2)
	before_time = m.remaining
	events.resolve()
	check(m.remaining == before_time, "Clean patrol has no penalty")
	world.stages.end_event()
	check(world.minimal_hud.timer_label.get_theme_font_size("font_size") >= 36, "Prominent timer")
	check(world.minimal_hud.cash_label.get_theme_font_size("font_size") >= 36, "Prominent cash")
	world.queue_free()
	await process_frame
	print("MULTIPILE EVENTS RESULT: %d failures" % failures)
	quit(1 if failures else 0)
