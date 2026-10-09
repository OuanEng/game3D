extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	var previous_volume := 0.0
	for index in range(4):
		preload("res://scripts/StageManager.gd").selected_stage = index
		var world: Node3D = load("res://Main.tscn").instantiate()
		root.add_child(world)
		await physics_frame
		world.menus.start_shift()
		world.intro.complete()
		world.player.set_physics_process(false)
		var stage: Node = world.stages
		var manager: GameManager = world.manager
		var terrain: FoamMesh = world.foam_mesh
		# Exercise aim assistance against actual physics, including obstruction.
		manager.owned.grabber = 2
		var target: Pearl = world.pearls[0]
		target.state = Pearl.State.EXPOSED
		target.freeze = true
		target.global_position = world.player.camera.global_position + Vector3(0.11, 0, -2)
		await physics_frame
		await physics_frame
		check(world.player.assisted_pickup() == target, "Grabber assists a slightly off-centre target")
		var wall := Props.box(world, world.player.camera.global_position + Vector3(0, 0, -1), Vector3(1, 1, 0.1), Color.BLACK)
		await physics_frame
		await physics_frame
		check(world.player.assisted_pickup() == null, "Grabber cannot pass through walls")
		wall.queue_free()
		check(manager.total == [3,5,6,8][index], "Stage target count")
		check(terrain.remaining_volume() > previous_volume, "Increasing terrain volume")
		previous_volume = terrain.remaining_volume()
		var before := terrain.remaining_volume()
		var removed := terrain.excavate(terrain.mound_center, 0.6, 0.2, 0.01)
		check(absf(before - terrain.remaining_volume() - removed) < 0.000001, "Material volume conservation")
		if index == 0:
			stage.note_dig()
			stage._physics_process(0.0)
			stage.note_dump()
			stage._physics_process(0.0)
			check(manager.credits == 60, "Tutorial grants bucket budget")
			stage.note_dump()
			check(manager.credits == 60, "No repeated grant")
			check(manager.buy_upgrade("bucket"), "Tutorial can afford bucket")
			stage._physics_process(0.0)
			check(stage.tutorial_step == 3, "Tutorial advances after actual purchase")
			stage.unlocked = 2
			check(not stage.can_enter(2, false), "Sand gate rejects missing equipment")
			stage.equipment.scoop = 2
			check(stage.can_enter(2, false), "Sand accepts scoop II")
			check(not stage.can_enter(1, true), "Salt unavailable in hands-only mode")
		stage.trigger_event(0)
		check(stage.outage_lights.size() > 0, "Outage finds warehouse lamps")
		check(world.player.work_light.visible, "Outage retains player's work light")
		var time_left: float = stage.event_remaining
		paused = true
		await create_timer(0.05).timeout
		check(stage.event_remaining == time_left, "Pause freezes event")
		paused = false
		stage.end_event()
		check(stage.outage_lights.is_empty(), "Lights restored")
		manager.debug_used = true
		stage.unlocked = index
		for item in world.pearls:
			item.state = Pearl.State.EXPOSED
			check(item.pick_up(world.player.hand), "Target retrievable")
			item.wash(3.0)
			manager.collect(item, Vector3(4, 1, 6))
		check(not manager.running and manager.phase == GameManager.Phase.WON, "Stage completes via delivery")
		check(stage.unlocked == mini(3, index + 1), "F3 testing still unlocks next stage")
		check(stage.bank == manager.credits + stage.data().bonus, "Completion reward saved")
		if index == 0:
			stage.persistence_enabled = true
			stage.save_path = "user://career-test.cfg"
			stage.complete(true)
			var stored := ConfigFile.new()
			check(stored.load(stage.save_path) == OK and stored.get_value("career", "unlocked", -1) == 1, "Career checkpoint written to disk")
			stage.equipment.clear()
			stage.unlock_all_stages()
			for stage_index in range(4):
				check(stage.can_enter(stage_index, false) and stage.can_enter(stage_index, true), "Unlock all bypasses stage/equipment restrictions")
			check(not stage.can_enter(4, false), "Unlock all still rejects invalid stage")
			stored.load(stage.save_path)
			check(stored.get_value("career", "debug_all_stages", false) and stored.get_value("career", "unlocked", -1) == 3, "Unlock all saved immediately")
			DirAccess.remove_absolute(stage.save_path)
		world.queue_free()
		await process_frame
	print("STAGES RESULT: %d failures" % failures)
	quit(1 if failures else 0)
