extends Node
## StageManager owns scheduling; this node owns reversible event effects.
## All time is simulation time: pause freezes warnings and interference.
enum Kind { OUTAGE, AVALANCHE, PATROL, DUST, SENSOR }
var stage: Node
var kind := -1
var environment: Environment
var saved_fog: Dictionary = {}

func begin(value: int) -> void:
	kind = value
	stage.event_remaining = [14.0, 5.0, 15.0, 18.0, 12.0][kind]
	stage.event_message = [
		"Power outage! Use your work light (F7).",
		"Pile avalanche! Excavated paths may refill.",
		"Boss patrol: dump trash; wash dirty finds or hide them behind cover!",
		"Dust storm: poor visibility near sand and salt.",
		"Sensor interference - signal unavailable"][kind]
	var world: Node3D = stage.world
	world.audio.one_shot("collapse" if kind == Kind.AVALANCHE else ("radio" if kind == Kind.PATROL else "alarm"))
	match kind:
		Kind.OUTAGE:
			for lamp in world.find_children("*", "Light3D", true, false):
				if not world.player.is_ancestor_of(lamp) and lamp.visible:
					stage.outage_lights.append(lamp)
					lamp.hide()
		Kind.AVALANCHE:
			var pile: FoamMesh = world.foam_piles[stage.rng.randi_range(0, world.foam_piles.size() - 1)]
			pile.avalanche(world.player.global_position)
		Kind.DUST:
			var env_node := world.find_children("*", "WorldEnvironment", true, false)[0] as WorldEnvironment
			environment = env_node.environment
			for key in ["fog_enabled", "fog_density", "volumetric_fog_density"]:
				saved_fog[key] = environment.get(key)
		Kind.SENSOR:
			stage.sensor_disabled = true

func tick(_delta: float) -> void:
	if kind != Kind.DUST or environment == null:
		return
	var in_zone := false
	for pile in stage.world.foam_piles:
		if pile.material_kind not in [1, 2, 3]:
			continue
		var point: Vector3 = pile.to_local(stage.world.player.global_position) - pile.mound_center
		if Vector2(point.x / (pile.mound_radii.x + 2.0), point.z / (pile.mound_radii.y + 2.0)).length() < 1.0:
			in_zone = true
	environment.fog_enabled = true if in_zone else saved_fog.fog_enabled
	environment.fog_density = 0.12 if in_zone else saved_fog.fog_density
	# Compatibility/Web uses regular fog; Forward+ also gets volumetric dust.
	environment.volumetric_fog_density = 0.10 if in_zone else saved_fog.volumetric_fog_density

func visible_from_door(target: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(Vector3(0, 1.7, 10.7), target, 1 | 8 | 16)
	return stage.world.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func resolve() -> void:
	if kind != Kind.PATROL or not stage.world.manager.running:
		return
	var world: Node3D = stage.world
	var caught: bool = world.player.bucket_load > 0.000001 and visible_from_door(world.player.camera.global_position)
	for item in world.pearls:
		if item.residue <= 0.0 or item.state in [Pearl.State.EMBEDDED, Pearl.State.COLLECTED]:
			continue
		# Conveyor-owned items are already being dealt with, not loose contraband.
		if item.state == Pearl.State.HELD and item != world.player.held:
			continue
		caught = caught or visible_from_door(item.global_position)
	if caught:
		world.manager.remaining = maxf(0.0, world.manager.remaining - 30.0)
		world.player.notice = tr("Patrol found a mess: 30 seconds lost")
		world.player.notice_until = Time.get_ticks_msec() + 4000
		if world.manager.remaining <= 0.0:
			world.manager.finish(false)
	else:
		world.player.notice = tr("Patrol passed - keep searching")
		world.player.notice_until = Time.get_ticks_msec() + 3000
	# Never resolve the same warning twice, even if the run ended above.
	kind = -1

func restore() -> void:
	for lamp in stage.outage_lights:
		if is_instance_valid(lamp):
			lamp.show()
	stage.outage_lights.clear()
	stage.sensor_disabled = false
	if environment != null:
		for key in saved_fog:
			environment.set(key, saved_fog[key])
	saved_fog.clear()
	environment = null
	kind = -1
