class_name Player
extends CharacterBody3D
## Input, movement and bucket inventory live here. Tools routes scoop/UV/sonar.
signal shop_requested
signal bucket_changed(load_m3: float, capacity_m3: float)
@export var speed: float = 3.5
@export var acceleration: float = 16.0
@export var mouse_sensitivity: float = 0.002
@export var reach: float = 3.0
var manager: GameManager
var pile: FoamMesh
var camera: Camera3D
var hand: Marker3D
var tools: Tools
var held: Pearl
var store_open: bool = false
var prompt: String = ""
var detector_strength: float = 0.0
var gravity: float = 9.8
var notice: String = ""
var notice_until: int = 0
var bucket_load: float = 0.0 # Cubic metres of actual terrain removed, not click count.

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 8 # Dig an actual path instead of walking inside opaque foam.
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(52.0)
	gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.7
	collider.shape = capsule
	collider.position.y = 0.85
	add_child(collider)
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.position.y = 1.55
	camera.current = true
	camera.fov = 78.0
	add_child(camera)
	hand = Marker3D.new()
	hand.name = "HoldPoint"
	hand.position = Vector3(0.24, -0.22, -0.55)
	camera.add_child(hand)
	tools = Tools.new()
	tools.name = "Tools"
	add_child(tools)
	tools.configure(self, pile, manager)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()
		return
	if not manager.running or store_open:
		return
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * mouse_sensitivity, -1.45, 1.45)
	for index in range(3):
		if event.is_action_pressed("tool_%d" % (index + 1)):
			if not tools.select_tool(index):
				notice = "Tool locked — buy it at the illuminated supply desk"
				notice_until = Time.get_ticks_msec() + 2000
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			cycle_tool(1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cycle_tool(-1)

func cycle_tool(direction: int) -> void:
	# Skip locked slots; the scoop is always owned.
	for step in range(1, 4):
		var index := posmod(tools.selected_tool + direction * step, 3)
		if tools.select_tool(index):
			break

func effective_pickup_reach() -> float:
	return reach

func bucket_capacity() -> float:
	return 0.50 if manager.owns_upgrade("bucket") else 0.22

func scoop_radius() -> float:
	return 0.75 if manager.owns_upgrade("scoop") else 0.48

func scoop_depth() -> float:
	return 0.30 if manager.owns_upgrade("scoop") else 0.18

func try_scoop_at(hit_point: Vector3) -> float:
	# Mesh and bucket form one transaction. A nearly full bucket scales the cut;
	# a full bucket must not deform the surface or consume an imaginary stroke.
	if not manager.running or store_open or held != null:
		return 0.0
	var room := maxf(0.0, bucket_capacity() - bucket_load)
	if room < 0.000001:
		return 0.0
	var removed := pile.excavate(hit_point, scoop_radius(), scoop_depth(), room)
	bucket_load = minf(bucket_capacity(), bucket_load + removed)
	if removed > 0.0:
		bucket_changed.emit(bucket_load, bucket_capacity())
	return removed

func dump_bucket(bin: WasteBin) -> float:
	if not manager.running or store_open or not is_instance_valid(bin):
		return 0.0
	# Enforce the designated waste area and line of sight, including for scripted use.
	var hit := cast_from_camera(reach, 1 | 4 | 8 | 16)
	if hit.is_empty() or hit.collider != bin:
		return 0.0
	var dumped := bucket_load
	bucket_load = 0.0
	bucket_changed.emit(bucket_load, bucket_capacity())
	return dumped

func _physics_process(delta: float) -> void:
	if not manager.running or store_open or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		tools.use_tool(delta, false, camera)
		detector_strength = 0.0
		velocity = Vector3.ZERO
		prompt = "Supply desk open — the boss clock keeps running" if store_open else "Click to resume"
		return
	var axis := Input.get_vector("left", "right", "forward", "back")
	var direction := global_basis * Vector3(axis.x, 0, axis.y)
	velocity.x = move_toward(velocity.x, direction.x * speed, acceleration * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, acceleration * delta)
	velocity.y = velocity.y - gravity * delta if not is_on_floor() else 0.0
	move_and_slide()
	# All tool physics queries run in a physics tick, never a mouse callback.
	prompt = tools.use_tool(delta, Input.is_action_pressed("brush") and held == null, camera, Input.is_action_just_pressed("brush"))
	detector_strength = tools.detector_strength
	update_auto_washer(delta)
	var hit := cast_from_camera(effective_pickup_reach(), 1 | 4 | 8 | 16)
	if not hit.is_empty():
		var target: Object = hit.collider
		if target is Pearl and held == null:
			prompt = "E • retrieve pearl" if target.is_retrievable() else "Scoop lower to expose this pearl"
			if Input.is_action_just_pressed("interact") and target.pick_up(hand):
				held = target
		elif target is UpgradeStore:
			prompt = "E • open supply desk / buy tools"
			if Input.is_action_just_pressed("interact"):
				tools.use_tool(delta, false, camera)
				shop_requested.emit()
		elif target is WasteBin:
			prompt = "E • dump portable bucket (%d litres)" % roundi(bucket_load * 1000.0)
			if Input.is_action_just_pressed("interact"):
				var dumped := dump_bucket(target)
				prompt = "Dumped %d litres — ready to scoop" % roundi(dumped * 1000.0)
		elif target is Station:
			interact_with_station(target, delta)
	if held != null and Input.is_action_just_pressed("drop"):
		drop_safely()
	if Time.get_ticks_msec() < notice_until:
		prompt = notice

func interact_with_station(station: Station, delta: float) -> void:
	if station.kind == Station.Kind.WASH:
		prompt = "Hold E • rinse the held pearl"
		if held != null and Input.is_action_pressed("interact"):
			held.wash(delta)
	else:
		prompt = "E • place clean pearl in velvet box (+%d credits)" % manager.pearl_reward
		if held != null and held.residue > 0.0:
			prompt = "Wash this pearl first, or let the auto-washer finish"
		elif held != null and Input.is_action_just_pressed("interact"):
			if manager.collect(held, station.slot(manager.collected)):
				held = null

func update_auto_washer(delta: float) -> void:
	# A portable passive upgrade; it cleans in three seconds of active play.
	if manager.running and not store_open and held != null and manager.owns_upgrade("auto_washer"):
		held.wash(delta * (2.0 / 3.0))

func cast_from_camera(distance: float, mask: int) -> Dictionary:
	var start := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(start, start - camera.global_basis.z * distance, mask)
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query)

func drop_safely() -> void:
	# The ray alone is insufficient: sweep the pearl's whole radius before release.
	var shape := SphereShape3D.new()
	shape.radius = 0.11
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, camera.global_position)
	query.motion = -camera.global_basis.z * 0.75
	query.collision_mask = 1 | 4 | 8 | 16
	var space := get_world_3d().direct_space_state
	if not space.intersect_shape(query, 1).is_empty():
		return
	var fractions := space.cast_motion(query)
	var destination := camera.global_position + query.motion * maxf(0.0, fractions[0] - 0.04)
	held.drop(destination)
	held = null
