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
var dig_cooldown: float = 0.0
var uv_charge: float = 45.0
var work_light: SpotLight3D
var invert_y := false

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
	work_light = SpotLight3D.new()
	work_light.spot_range = 8.0
	work_light.spot_angle = 42.0
	work_light.light_color = Color(1.0, 0.87, 0.7)
	camera.add_child(work_light)
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
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * mouse_sensitivity * (-1.0 if invert_y else 1.0), -1.45, 1.45)
	for index in range(5):
		if event.is_action_pressed("tool_%d" % (index + 1)):
			if not tools.select_tool(index):
				notice = tr("Tool locked — buy it at the illuminated supply desk")
				notice_until = Time.get_ticks_msec() + 2000
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			cycle_tool(1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cycle_tool(-1)

func cycle_tool(direction: int) -> void:
	# Skip locked slots; the scoop is always owned.
	for step in range(1, 6):
		var index := posmod(tools.selected_tool + direction * step, 5)
		if tools.select_tool(index):
			break

func effective_pickup_reach() -> float:
	return reach + 0.8 * manager.level("grabber")

func bucket_capacity() -> float:
	if manager.debug_infinite_bucket:
		return INF # Finite removed volume divided by infinity gives an empty HUD bar.
	return 0.08 * pow(1.75, manager.level("bucket") - 1) if manager.owns_upgrade("bucket") else 0.012

func scoop_radius() -> float:
	return 0.45 + 0.12 * (manager.level("scoop") - 1) if manager.owns_upgrade("scoop") else 0.25

func scoop_depth() -> float:
	return 0.14 + 0.045 * (manager.level("scoop") - 1) if manager.owns_upgrade("scoop") else 0.08

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
		get_parent().stages.note_dig()
		get_parent().audio.one_shot("dig")
		bucket_changed.emit(bucket_load, bucket_capacity())
	return removed

func dump_bucket(bin: WasteBin, require_aim: bool = true) -> float:
	if not manager.running or get_tree().paused or store_open or not is_instance_valid(bin):
		return 0.0
	# E uses the crosshair; Q aims at a nearby bin automatically. Both validate
	# physical distance and occlusion, so Q cannot turn remote foam into credits.
	var hit: Dictionary
	if require_aim:
		hit = cast_from_camera(reach, 1 | 4 | 8 | 16)
	else:
		var target := bin.global_position + Vector3(0, 1.3, 0)
		if camera.global_position.distance_to(target) > reach:
			return 0.0
		var query := PhysicsRayQueryParameters3D.create(camera.global_position, target, 1 | 4 | 8 | 16)
		query.exclude = [get_rid()]
		hit = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit.collider != bin:
		return 0.0
	var dumped := bucket_load
	if dumped <= 0.0:
		return 0.0
	# Disposal income lets the player buy a bucket even before finding an item.
	manager.reward_disposal(dumped, pile.material_kind)
	get_parent().stages.note_dump()
	get_parent().audio.one_shot("dump")
	bucket_load = 0.0
	bucket_changed.emit(bucket_load, bucket_capacity())
	return dumped

func try_dump_foam() -> float:
	# Called on Q's rising edge in a physics tick, never in an input callback.
	if not manager.running or get_tree().paused or store_open:
		return 0.0
	var dumped := 0.0
	for node in get_tree().get_nodes_in_group("waste_bins"):
		dumped = dump_bucket(node as WasteBin, false)
		if dumped > 0.0:
			break
	if dumped > 0.0:
		notice = tr("Storage emptied")
	elif bucket_load <= 0.0:
		notice = tr("Carry storage is empty")
	else:
		notice = tr("Move near the marked FOAM WASTE bin, then press Q")
	notice_until = Time.get_ticks_msec() + 2400
	return dumped

func _physics_process(delta: float) -> void:
	dig_cooldown = maxf(0.0, dig_cooldown - delta)
	var max_charge := 45.0 + 30.0 * manager.level("battery")
	var uv_active := manager.running and not store_open and tools.selected_tool == 1 and Input.is_action_pressed("brush")
	uv_charge = clampf(uv_charge + (-delta if uv_active else delta * 2.0), 0.0, max_charge)
	work_light.light_energy = 0.35 + 0.25 * manager.level("battery")
	if not manager.running or store_open or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		tools.use_tool(delta, false, camera)
		detector_strength = 0.0
		velocity = Vector3.ZERO
		prompt = tr("Supply desk open — the boss clock keeps running") if store_open else tr("Click to resume")
		return
	if Input.is_action_just_pressed("work_light"):
		work_light.visible = not work_light.visible
	var axis := Input.get_vector("left", "right", "forward", "back")
	var direction := global_basis * Vector3(axis.x, 0, axis.y)
	var load_fraction := clampf(bucket_load / bucket_capacity(), 0.0, 1.0)
	direction *= (1.0 + 0.12 * manager.level("boots")) * (1.0 - load_fraction * 0.25 / (1.0 + manager.level("boots")))
	velocity.x = move_toward(velocity.x, direction.x * speed, acceleration * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, acceleration * delta)
	velocity.y = velocity.y - gravity * delta if not is_on_floor() else 0.0
	if is_on_floor() and Input.is_action_just_pressed("jump"):
		velocity.y = 5.0
	move_and_slide()
	if Input.is_action_just_pressed("dump_foam"):
		try_dump_foam()
	# All tool physics queries run in a physics tick, never a mouse callback.
	prompt = tools.use_tool(delta, Input.is_action_pressed("brush") and held == null, camera, Input.is_action_just_pressed("brush"))
	detector_strength = tools.detector_strength
	update_auto_washer(delta)
	var hit := cast_from_camera(effective_pickup_reach(), 1 | 4 | 8 | 16)
	if held == null and manager.level("grabber") > 0 and (hit.is_empty() or hit.collider == pile.foam_body):
		var assisted := assisted_pickup()
		if assisted != null:
			hit = {"collider": assisted}
	if not hit.is_empty():
		var target: Object = hit.collider
		if target is Pearl and held == null:
			prompt = tr("E • retrieve pearl") + " · " + target.localized_name() if target.is_retrievable() else tr("Scoop lower to expose this pearl")
			if Input.is_action_just_pressed("interact") and target.pick_up(hand):
				held = target
				get_parent().audio.one_shot("pickup")
		elif target is UpgradeStore:
			if manager.is_hardcore():
				prompt = tr("HARDCORE · supply desk disabled")
			else:
				prompt = tr("E • open supply desk / buy tools")
				if Input.is_action_just_pressed("interact"):
					tools.use_tool(delta, false, camera)
					shop_requested.emit()
		elif target is WasteBin:
			prompt = tr("Q / E · empty foam (%d litres)") % roundi(bucket_load * 1000.0)
			if Input.is_action_just_pressed("interact"):
				var dumped := dump_bucket(target)
				prompt = tr("Dumped %d litres — ready to scoop") % roundi(dumped * 1000.0)
		elif target is Station:
			interact_with_station(target, delta)
	if held != null and Input.is_action_just_pressed("drop"):
		drop_safely()
	elif held != null and Input.is_action_just_pressed("throw_item"):
		drop_safely(true)
	if Time.get_ticks_msec() < notice_until:
		prompt = notice

func interact_with_station(station: Station, delta: float) -> void:
	if station.kind == Station.Kind.WASH:
		if manager.owns_upgrade("auto_washer"):
			prompt = tr("E · wash belt %d/%d · tray %d · F to throw") % [station.queue_count(), station.buffer_capacity(), station.clean_items.size()]
			if Input.is_action_just_pressed("interact"):
				if held != null:
					if station.accept_item(held):
						held = null
					else:
						prompt = tr("E · belt full; wait for the next item, or F to throw")
				else:
					held = station.take_clean(hand)
			return
		prompt = tr("Hold E • rinse the held pearl")
		if held != null and Input.is_action_pressed("interact"):
			if held.residue > 0.0:
				get_parent().audio.manual_wash_remaining = 0.1
				station.manual_flow_remaining = 0.1
			held.wash(delta)
	else:
		prompt = tr("E • place clean pearl in velvet box (+%d credits)") % manager.pearl_reward
		if held != null and held.residue > 0.0:
			prompt = tr("Hold E at the blue WASH ITEMS station first")
		elif held != null and Input.is_action_just_pressed("interact"):
			if manager.collect(held, station.slot(manager.collected)):
				held = null

func update_auto_washer(delta: float) -> void:
	# Cleaning is now owned by the physical washing station, not the player.
	pass

func assisted_pickup() -> Pearl:
	# Widen the aiming cone, but require exposure and an unobstructed physics ray.
	var best: Pearl = null
	var best_angle := 0.03 + manager.level("grabber") * 0.015
	for item in pile.pearls:
		if not item.is_retrievable():
			continue
		var offset := item.global_position - camera.global_position
		if offset.length() > effective_pickup_reach():
			continue
		var angle := (-camera.global_basis.z).angle_to(offset)
		if angle >= best_angle:
			continue
		var query := PhysicsRayQueryParameters3D.create(camera.global_position, item.global_position, 1 | 4 | 8 | 16)
		query.exclude = [get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and hit.collider == item:
			best = item
			best_angle = angle
	return best

func cast_from_camera(distance: float, mask: int) -> Dictionary:
	var start := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(start, start - camera.global_basis.z * distance, mask)
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query)

func drop_safely(throw_item: bool = false) -> void:
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
	get_parent().audio.one_shot("drop")
	held.drop(destination)
	if throw_item:
		held.linear_velocity = -camera.global_basis.z * 3.5 + Vector3.UP * 0.8
	held = null
