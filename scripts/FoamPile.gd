class_name FoamPile
extends Node3D
## A floor-level paraboloid mound, not a tub. Keep this node at unit scale.
## Hundreds of cheap static cells are affordable; thousands of RigidBody3Ds are not.
@export_range(1, 8) var pearl_count: int = 8
@export var layout_seed: int = 0 # Nonzero gives a reproducible layout for debugging.
@export var mound_center := Vector3(0, 0, -1)
@export var mound_radii := Vector2(3.8, 3.0)
@export var mound_height: float = 3.0
var pearls: Array[Pearl] = []
var chunks: Array[Foam] = []
var _random := RandomNumberGenerator.new()

func _ready() -> void:
	if layout_seed == 0:
		_random.randomize()
	else:
		_random.seed = layout_seed
	var volume := Node3D.new()
	volume.name = "FoamVolume"
	add_child(volume)
	# Layered columns give a mountain silhouette without hidden interior voids.
	for x in range(-7, 8):
		for z in range(-5, 6):
			var px := float(x) * 0.54
			var pz := float(z) * 0.54
			var radius_squared := pow(px / mound_radii.x, 2) + pow(pz / mound_radii.y, 2)
			var column_height := mound_height * (1.0 - radius_squared)
			for y in range(6):
				var py := 0.28 + float(y) * 0.51
				if py > column_height or chunks.size() >= 600:
					continue
				var chunk := Foam.new()
				chunk.name = "Foam_%03d" % chunks.size()
				chunk.position = mound_center + Vector3(px, py, pz)
				chunk.position.x += _random.randf_range(-0.025, 0.025)
				chunk.position.z += _random.randf_range(-0.025, 0.025)
				chunk.container = self
				volume.add_child(chunk)
				chunks.append(chunk)
	spawn_pearls()

func spawn_pearls() -> void:
	var candidates: Array[Foam] = []
	for chunk in chunks:
		var relative := chunk.position - mound_center
		# Deep enough to search, low enough to recover after digging a floor path.
		if relative.y <= 1.35 and absf(relative.x) < 2.9 and absf(relative.z) < 2.2:
			candidates.append(chunk)
	for index in range(clampi(pearl_count, 1, 8)):
		if candidates.is_empty():
			break
		var chosen := _random.randi_range(0, candidates.size() - 1)
		var location := candidates[chosen].position
		var pearl := Pearl.new()
		pearl.name = "Pearl_%02d" % (index + 1)
		pearl.position = location
		pearl.foam_container = self
		add_child(pearl)
		pearls.append(pearl)
		# Prevent two pearls occupying the same column, including vertically stacked cells.
		for candidate_index in range(candidates.size() - 1, -1, -1):
			var offset := candidates[candidate_index].position - location
			offset.y = 0.0
			if offset.length() < 0.70:
				candidates.remove_at(candidate_index)

func brush(chunk: Foam, delta: float) -> void:
	if is_instance_valid(chunk) and chunk.container == self:
		chunk.brush(delta)

func is_covered(world_point: Vector3) -> bool:
	for chunk in chunks:
		if is_instance_valid(chunk) and chunk.covers(world_point):
			return true
	return false

func world_clear(start: Vector3, end: Vector3) -> bool:
	# Tools penetrate foam, never World or Station geometry. Call in physics ticks only.
	var query := PhysicsRayQueryParameters3D.create(start, end, 1 | 16)
	query.hit_from_inside = true
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func push_gust(origin: Vector3, direction: Vector3, delta: float, tool_range: float = 5.0) -> int:
	var moved := 0
	var forward := direction.normalized()
	for chunk in chunks:
		if not is_instance_valid(chunk) or chunk.cleared:
			continue
		var offset := chunk.global_position - origin
		var depth := offset.dot(forward)
		if depth < 0.75 or depth > tool_range:
			continue
		var side := offset - forward * depth
		if side.length() > 0.30 + depth * 0.23:
			continue
		if not world_clear(origin, chunk.global_position):
			continue
		# Fan sideways and settle onto the floor. This is intentional kinematic foam,
		# not a rigid-body simulation. It moves away from the player's camera.
		var push := forward * 2.4 + side.normalized() * 1.5 + Vector3.DOWN * 0.45
		var destination := chunk.global_position + push * delta
		var local_destination := to_local(destination)
		local_destination.x = clampf(local_destination.x, -5.0, 5.0)
		local_destination.y = clampf(local_destination.y, 0.28, 3.4)
		local_destination.z = clampf(local_destination.z, -5.0, 3.0)
		destination = to_global(local_destination)
		# Stop the centre short of solid props, leaving room for the cell's shape.
		var motion := destination - chunk.global_position
		if motion.length_squared() > 0.000001:
			var clearance_end := destination + motion.normalized() * 0.32
			if world_clear(chunk.global_position, clearance_end):
				chunk.global_position = destination
		# Gradual dispersal ensures foam cannot accumulate forever at the boundaries.
		chunk.brush(delta * 0.10)
		moved += 1
		if moved >= 32:
			break
	return moved

func vacuum_at(point: Vector3, radius: float, delta: float, origin: Vector3) -> int:
	var removed := 0
	for chunk in chunks:
		if not is_instance_valid(chunk) or chunk.cleared:
			continue
		if chunk.global_position.distance_to(point) > radius:
			continue
		if world_clear(origin, chunk.global_position):
			chunk.brush(delta * 1.8)
			removed += 1
			if removed >= 28:
				break
	return removed
