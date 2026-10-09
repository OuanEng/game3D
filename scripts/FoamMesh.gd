class_name FoamMesh
extends Node3D
## Excavatable, continuous heightfield. One height per X/Z point means no tunnels,
## caves, overhangs or loose chunks; digging can only lower the surface.
## Keep this node and its ancestors unrotated and at unit scale (metres).
## The renderer, ray collider and pearl queries all use the same triangle split.

signal surface_changed(removed_volume: float)

@export_range(0, 8) var pearl_count: int = 8
@export var spawn_pearls_on_ready: bool = true
@export var layout_seed: int = 2013
@export var mound_center := Vector3(0, 0, -1.6)
@export var mound_radii := Vector2(7.0, 5.5)
@export_range(0.2, 8.0) var mound_height: float = 4.5
@export_range(9, 81) var columns: int = 65
@export_range(9, 81) var rows: int = 53
@export_enum("Foam", "Salt", "Sand", "Mixed") var material_kind := 0
@export var shallow_targets := false

func resistance() -> float:
	return [1.0, 1.65, 2.4, 1.0][material_kind]

var pearls: Array[Pearl] = []
var mesh_instance: MeshInstance3D
var foam_body: StaticBody3D
var material: ShaderMaterial
# Double precision keeps repeated bucket-volume accounting stable. Vertices are
# converted to the engine's float32 render/physics buffers when rebuilt.
var heights := PackedFloat64Array()
var _vertex_areas := PackedFloat64Array()
var _vertices := PackedVector3Array()
var _indices := PackedInt32Array()
var _collision: CollisionShape3D
var _step := Vector2.ZERO
var _random := RandomNumberGenerator.new()

func _ready() -> void:
	assert(global_basis.is_equal_approx(Basis.IDENTITY), "FoamMesh requires unit scale and no rotation.")
	assert(mound_radii.x > 0.0 and mound_radii.y > 0.0)
	columns = maxi(columns, 3)
	rows = maxi(rows, 3)
	_step = mound_radii * 2.0 / Vector2(columns - 1, rows - 1)
	if layout_seed == 0:
		_random.randomize()
	else:
		_random.seed = layout_seed
	_build_grid()
	mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "Surface"
	material = ShaderMaterial.new()
	material.shader = preload("res://shaders/FoamTerrain.gdshader")
	material.set_shader_parameter("base_height", mound_center.y)
	material.set_shader_parameter("material_kind", material_kind)
	mesh_instance.material_override = material
	add_child(mesh_instance)
	foam_body = StaticBody3D.new()
	foam_body.name = "FoamCollider"
	foam_body.collision_layer = 8 # Layer 4: Foam.
	foam_body.collision_mask = 6 # Player and released pearls rest on this surface.
	add_child(foam_body)
	_collision = CollisionShape3D.new()
	_collision.name = "SurfaceShape"
	foam_body.add_child(_collision)
	_rebuild_surface()
	if spawn_pearls_on_ready:
		spawn_pearls()

func _build_grid() -> void:
	_indices.clear()
	heights.resize(columns * rows)
	_vertex_areas.resize(columns * rows)
	_vertex_areas.fill(0.0)
	_vertices.resize(columns * rows)
	for z in range(rows):
		for x in range(columns):
			var px := -mound_radii.x + float(x) * _step.x
			var pz := -mound_radii.y + float(z) * _step.y
			var distance_squared := pow(px / mound_radii.x, 2.0) + pow(pz / mound_radii.y, 2.0)
			var index := z * columns + x
			# A softly rounded cone keeps every initial slope below 45 degrees
			# at the default scale, so the player can actually climb the mountain.
			# Enlarging a paraboloid's height produces an impassable steep rim.
			var rounding := 0.08
			var edge := sqrt(1.0 + rounding * rounding)
			var cone := (edge - sqrt(distance_squared + rounding * rounding)) / (edge - rounding)
			heights[index] = mound_height * maxf(0.0, cone)
			_vertices[index] = mound_center + Vector3(px, heights[index], pz)
	# Godot uses clockwise front-face winding. Each quad's diagonal runs from
	# top-right to bottom-left; sample_height() must use this exact same split.
	for z in range(rows - 1):
		for x in range(columns - 1):
			var a := z * columns + x
			var b := a + 1
			var c := a + columns
			var d := c + 1
			_indices.append_array(PackedInt32Array([a, b, c, b, d, c]))
	# Integral of a linear triangle's height = horizontal area * mean height.
	# Thus each triangle contributes area/3 to each of its vertex weights.
	# This includes boundary/corner weights correctly; sum(weights*h) is m³.
	var share := _step.x * _step.y / 6.0
	for index in _indices:
		_vertex_areas[index] += share

func configure_fresh_grid(grid: Vector2i) -> void:
	# Only used before a shift starts; active excavations are never resampled.
	if grid == Vector2i(columns, rows):
		return
	var depths: Array[float] = []
	for item in pearls:
		depths.append(sample_height(item.global_position) - item.global_position.y)
	columns = grid.x
	rows = grid.y
	_step = mound_radii * 2.0 / Vector2(columns - 1, rows - 1)
	_build_grid()
	_rebuild_surface()
	for i in range(pearls.size()):
		pearls[i].global_position.y = sample_height(pearls[i].global_position) - depths[i]
		pearls[i].home = pearls[i].global_position

func _rebuild_surface() -> void:
	var normals := PackedVector3Array()
	normals.resize(_vertices.size())
	normals.fill(Vector3.ZERO)
	for index in range(_vertices.size()):
		_vertices[index].y = mound_center.y + heights[index]
	for offset in range(0, _indices.size(), 3):
		var a := _indices[offset]
		var b := _indices[offset + 1]
		var c := _indices[offset + 2]
		# Reverse cross order for clockwise winding; this normal points upward.
		var normal := (_vertices[c] - _vertices[a]).cross(_vertices[b] - _vertices[a])
		normals[a] += normal
		normals[b] += normal
		normals[c] += normal
	for index in range(normals.size()):
		normals[index] = normals[index].normalized()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = _indices
	var updated := ArrayMesh.new()
	updated.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh_instance.mesh = updated
	# The default 6,656-triangle static mesh is rebuilt per successful stroke.
	# Continuous tools batch their strokes; bucket/height/collider stay in sync.
	# Substantially larger maps should partition both mesh and shape into chunks.
	# Assign both resources in the same physics callback, never on a worker or
	# in an area/body signal while the physics server is flushing queries.
	_collision.shape = updated.create_trimesh_shape()

func sample_height(world_point: Vector3) -> float:
	var local := to_local(world_point) - mound_center
	var gx := (local.x + mound_radii.x) / _step.x
	var gz := (local.z + mound_radii.y) / _step.y
	if gx < 0.0 or gz < 0.0 or gx > columns - 1 or gz > rows - 1:
		return global_position.y + mound_center.y
	var x := mini(int(floor(gx)), columns - 2)
	var z := mini(int(floor(gz)), rows - 2)
	var tx := gx - float(x)
	var tz := gz - float(z)
	var a := z * columns + x
	var h: float
	if tx + tz <= 1.0:
		h = heights[a] + tx * (heights[a + 1] - heights[a]) + tz * (heights[a + columns] - heights[a])
	else:
		var d := a + columns + 1
		h = heights[d] + (1.0 - tz) * (heights[a + 1] - heights[d]) + (1.0 - tx) * (heights[a + columns] - heights[d])
	return global_position.y + mound_center.y + h

func is_covered(world_point: Vector3) -> bool:
	# A centre this close to the surface is visibly partly exposed. Pearl.gd
	# keeps an exposed pearl frozen until its entire underside is unsupported.
	return sample_height(world_point) > world_point.y + 0.025

func foam_depth(world_point: Vector3) -> float:
	# World-space vertical thickness; callers can query the top of a sphere
	# rather than its centre when deciding how much foam hides that item.
	return maxf(0.0, sample_height(world_point) - world_point.y)

func remaining_volume() -> float:
	var volume := 0.0
	for index in range(heights.size()):
		volume += heights[index] * _vertex_areas[index]
	return volume

func excavate(world_hit: Vector3, radius: float, depth: float, available_volume: float) -> float:
	# Called once per scoop from Player._physics_process(). available_volume is
	# bucket capacity minus its current contents, using m³ throughout.
	if radius <= 0.0 or depth <= 0.0 or available_volume <= 0.0:
		return 0.0
	depth /= resistance()
	var hit := to_local(world_hit)
	# Visit only the brush's grid rectangle. A small hand stroke should not
	# scan every vertex just because the warehouse contains a large mountain.
	var local_center := hit - mound_center
	var min_x := maxi(0, int(floor((local_center.x - radius + mound_radii.x) / _step.x)))
	var max_x := mini(columns - 1, int(ceil((local_center.x + radius + mound_radii.x) / _step.x)))
	var min_z := maxi(0, int(floor((local_center.z - radius + mound_radii.y) / _step.y)))
	var max_z := mini(rows - 1, int(ceil((local_center.z + radius + mound_radii.y) / _step.y)))
	var affected := PackedInt32Array()
	var drops := PackedFloat64Array()
	var proposed_volume := 0.0
	var radius_squared := radius * radius
	for z in range(min_z, max_z + 1):
		for x in range(min_x, max_x + 1):
			var index := z * columns + x
			var offset := Vector2(_vertices[index].x - hit.x, _vertices[index].z - hit.z)
			var distance_squared := offset.length_squared()
			if distance_squared >= radius_squared or heights[index] <= 0.0:
				continue
			# Clamp before measuring, so a nearly empty patch cannot generate
			# imaginary foam. Per-vertex triangle weights preserve actual m³.
			var falloff := pow(1.0 - distance_squared / radius_squared, 1.5)
			var layer_resistance := 1.0
			if material_kind == 3:
				layer_resistance = 2.4 if heights[index] < 1.0 else (1.65 if heights[index] < 2.2 else 1.0)
			var drop := minf(heights[index], depth * falloff / layer_resistance)
			affected.append(index)
			drops.append(drop)
			proposed_volume += drop * _vertex_areas[index]
	if proposed_volume <= 0.000000001:
		return 0.0
	# Scale all reductions together for a nearly full bucket. Never remove a
	# full scoop and merely clamp the inventory afterwards: that loses volume.
	var fraction := minf(1.0, available_volume / proposed_volume)
	var removed_volume := 0.0
	for affected_index in range(affected.size()):
		var index := affected[affected_index]
		var previous: float = heights[index]
		heights[index] = maxf(0.0, previous - drops[affected_index] * fraction)
		removed_volume += (previous - heights[index]) * _vertex_areas[index]
	_rebuild_surface()
	surface_changed.emit(removed_volume)
	# Guard the last floating-point ulp; deformation and returned volume agree
	# to numerical precision, including the final partially filled scoop.
	return minf(removed_volume, available_volume)

func debug_clear() -> void:
	# One mesh/collider rebuild; no storage credit or disposal reward is granted.
	var removed := 0.0
	for index in range(heights.size()):
		removed += heights[index] * _vertex_areas[index]
		heights[index] = 0.0
	_rebuild_surface()
	surface_changed.emit(removed)

func spawn_pearls() -> void:
	if not pearls.is_empty():
		return
	for index in range(pearl_count):
		var angle := TAU * (float(index) + _random.randf_range(-0.12, 0.12)) / maxf(pearl_count, 1)
		var ring := 0.48 + 0.15 * float(index % 3)
		# Two shallow finds on the entrance side make the bare-hands phase
		# achievable. Other items occupy different depths across the mountain.
		if index < 2:
			angle = PI * 0.5 + float(index) * 0.46
			ring = 0.83 - float(index) * 0.06
		var local := mound_center + Vector3(cos(angle) * mound_radii.x * ring, 0.0, sin(angle) * mound_radii.y * ring)
		var top := sample_height(to_global(local)) - global_position.y
		var burial := 0.32 + float(index) * 0.14 if index < 2 else _random.randf_range(0.65, 1.5)
		local.y = maxf(mound_center.y + 0.25, top - burial)
		if shallow_targets:
			local.y = maxf(mound_center.y + 0.16, top - 0.14)
		var pearl := Pearl.new()
		pearl.item_kind = index % 3
		pearl.item_name = ["Boss's necklace pearl", "Antique brass marble", "Precision steel bearing"][index % 3]
		pearl.name = "Pearl_%02d" % (index + 1)
		pearl.position = local
		pearl.foam_container = self
		add_child(pearl)
		pearls.append(pearl)

func set_uv_scan(origin: Vector3, direction: Vector3, enabled: bool) -> void:
	# The opaque surface receives localized fluorescence hints for shallow
	# items; the beam never cuts a transparent opening into the mountain.
	material.set_shader_parameter("uv_scan_enabled", enabled)
	material.set_shader_parameter("uv_origin", origin)
	material.set_shader_parameter("uv_direction", direction.normalized())

func world_clear(start: Vector3, finish: Vector3) -> bool:
	# UV and sonar can penetrate foam, but never barn walls/station geometry.
	var query := PhysicsRayQueryParameters3D.create(start, finish, 1 | 16)
	query.hit_from_inside = true
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()
