class_name Pearl
extends RigidBody3D
## State transitions keep held/collected bodies out of the physics simulation.
enum State { EMBEDDED, EXPOSED, FREE, HELD, COLLECTED }
var state: State = State.EMBEDDED
var residue: float = 1.0
var home: Vector3
var surface: ShaderMaterial
var uv_strength: float = 0.0
var holder: Node3D
var foam_container: Node3D

func _ready() -> void:
	add_to_group("pearls")
	collision_layer = 4
	collision_mask = 13 # World, pearls and the continuous foam surface.
	mass = 0.08
	continuous_cd = true
	freeze = true
	home = global_position
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.095
	sphere.height = 0.19
	mesh.mesh = sphere
	surface = ShaderMaterial.new()
	surface.shader = preload("res://shaders/PearlUV.gdshader")
	mesh.material_override = surface
	add_child(mesh)
	var collider := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.095
	collider.shape = shape
	add_child(collider)

func _physics_process(_delta: float) -> void:
	if state == State.EMBEDDED:
		if is_instance_valid(foam_container) and foam_container.is_covered(global_position):
			return
		# Stable half-exposed pearls are pickable without a physics depenetration pop.
		state = State.EXPOSED
	if state == State.EXPOSED:
		if terrain_clears_bottom():
			state = State.FREE
			freeze = false
	elif state == State.HELD and is_instance_valid(holder):
		global_transform = holder.global_transform
	elif state == State.FREE and global_position.y < -3.0:
		# Recovery from physics escape; never permanently lose a required pearl.
		freeze = true
		global_position = home
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
		state = State.EMBEDDED

func pick_up(anchor: Node3D) -> bool:
	if not is_retrievable():
		return false
	state = State.HELD
	freeze = true
	collision_layer = 0
	collision_mask = 0
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	holder = anchor
	set_uv_strength(0.0)
	return true

func is_retrievable() -> bool:
	return state == State.EXPOSED or state == State.FREE

func terrain_clears_bottom() -> bool:
	if not is_instance_valid(foam_container) or not foam_container.has_method("sample_height"):
		return true
	# Check the footprint as well as the centre, since an excavated rim may be steep.
	for offset in [Vector3.ZERO, Vector3(0.095, 0, 0), Vector3(-0.095, 0, 0), Vector3(0, 0, 0.095), Vector3(0, 0, -0.095)]:
		if foam_container.sample_height(global_position + offset) > global_position.y - 0.10:
			return false
	return true

func set_uv_strength(value: float) -> void:
	# Public API for the UV tool; the stored value also supports gameplay checks.
	uv_strength = clampf(value, 0.0, 1.0)
	if state == State.HELD or state == State.COLLECTED:
		uv_strength = 0.0
	if surface != null:
		surface.set_shader_parameter("uv_strength", uv_strength)

func drop(at: Vector3) -> void:
	if state != State.HELD:
		return
	holder = null
	global_position = at
	collision_layer = 4
	collision_mask = 13
	state = State.FREE
	freeze = false
	sleeping = false

func wash(delta: float) -> void:
	if state != State.HELD:
		return
	residue = maxf(0.0, residue - delta / 2.0)
	surface.set_shader_parameter("residue", residue)

func display_at(at: Vector3) -> void:
	state = State.COLLECTED
	set_uv_strength(0.0)
	holder = null
	freeze = true
	collision_layer = 0
	collision_mask = 0
	global_position = at
