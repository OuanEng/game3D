class_name Tools
extends Node3D
## Tools contain no Input polling. Player passes physics-tick input explicitly.
enum Tool { SCOOP, UV, DETECTOR, BLOWER, VACUUM }
const LABELS := ["Hands / Scoop", "UV flashlight", "Item detector", "Blower", "Vacuum"]
const UV_MAX_COVER: float = 0.28 # Metres of foam above the top of a sphere.
const UV_MAX_PATH: float = 0.40 # Maximum actual foam crossed by the view ray.
const UV_SAMPLE_STEP: float = 0.04
const CONTINUOUS_CUT_INTERVAL: float = 0.10 # Limit mesh/collider rebuilds to 10 Hz.
var selected_tool: int = Tool.SCOOP
var detector_strength: float = 0.0
var player: Player
var pile: FoamMesh
var manager: GameManager
var _uv_light: SpotLight3D
var _beep: AudioStreamPlayer
var _beep_cooldown: float = 0.0
var _models: Array[Node3D] = []
var _bucket_fill: Node3D
var _stroke_tween: Tween
var _hands: Node3D
var _hand_foam: Node3D
var _continuous_elapsed: float = 0.0
const Art = preload("res://scripts/ToolArt.gd")
var _air: CPUParticles3D
var _bucket_model: Node3D

func configure(owner_player: Player, foam_mesh: FoamMesh, game_manager: GameManager) -> void:
	player = owner_player
	pile = foam_mesh
	manager = game_manager
	_beep = AudioStreamPlayer.new()
	_beep.name = "SonarBeep"
	_beep.stream = SoundBank.tone(140.0, 0.20)
	_beep.volume_db = -19.0
	add_child(_beep)
	_build_view_tools(player.camera)
	manager.upgrade_bought.connect(_refresh_art)

func select_tool(index: int) -> bool:
	if index < Tool.SCOOP or index > Tool.VACUUM or not manager.owns_tool(index):
		return false
	_reset_effects()
	selected_tool = index
	for model_index in range(_models.size()):
		_models[model_index].visible = model_index == selected_tool
	return true

func use_tool(delta: float, active: bool, camera: Camera3D, stroke: bool = false) -> String:
	if manager.is_hardcore() and selected_tool != Tool.SCOOP:
		select_tool(Tool.SCOOP)
	_air.emitting = active and manager.running and selected_tool == Tool.BLOWER and player.held == null
	for i in range(8):
		var led := _models[2].get_node_or_null("LED%d" % i) as MeshInstance3D
		if led != null:
			# Keep unlit cells readable; only the active signal cells pulse brightly.
			var lit := i < 1 + int(detector_strength * 7) and (Time.get_ticks_msec() / 250 + i) % 3 != 0
			var led_material := led.material_override as StandardMaterial3D
			led_material.emission_energy_multiplier = 1.4 if lit else 0.12
	_bucket_fill.get_parent().visible = manager.owns_upgrade("bucket")
	_hands.visible = selected_tool == Tool.SCOOP and not manager.owns_upgrade("scoop") and player.held == null
	_hand_foam.visible = player.bucket_load > 0.000001 and not manager.owns_upgrade("bucket")
	_bucket_fill.visible = player.bucket_load > 0.000001
	_bucket_fill.position.y = -0.15 + 0.23 * clampf(player.bucket_load / player.bucket_capacity(), 0, 1)
	for model_index in range(_models.size()):
		_models[model_index].visible = model_index == selected_tool and player.held == null
		if model_index == Tool.SCOOP:
			_models[model_index].visible = _models[model_index].visible and manager.owns_upgrade("scoop")
	if not active or not manager.running:
		_reset_effects()
		return tr("Click left mouse to scoop") if selected_tool == Tool.SCOOP else tr("Hold left mouse to use ") + tr(LABELS[selected_tool])
	var origin := camera.global_position
	var forward := -camera.global_basis.z
	match selected_tool:
		Tool.SCOOP:
			if player.dig_cooldown > 0.0:
				return ""
			if player.bucket_load >= player.bucket_capacity() - 0.000001:
				return tr("CARRY FULL — Q at the waste bin to empty it")
			# Holding the button cannot excavate every tick: one press is one scoop.
			if not stroke:
				return tr("Release and click again for another scoop")
			var hit := _ray(origin, origin + forward * player.reach, 1 | 4 | 8 | 16)
			if hit.is_empty() or hit.collider != pile.foam_body:
				return tr("Aim at the foam surface within reach")
			var removed := player.try_scoop_at(hit.position)
			if removed > 0.0:
				player.dig_cooldown = 0.65 * pow(0.78, manager.level("gloves"))
				animate_scoop()
				return tr("Scooped %.1f litres") % (removed * 1000.0)
			return tr("This patch is already down to the floor")
		Tool.UV:
			if player.uv_charge <= 0.0:
				_reset_effects()
				return tr("UV depleted · release to recharge")
			_uv_light.visible = true
			pile.set_uv_scan(origin, forward, true)
			_update_uv(origin, forward)
			return tr("UV: soft glints reveal items just beneath the surface")
		Tool.DETECTOR:
			_update_detector(delta, camera)
			return tr("Signal %d%% / faster beeps mean a closer pearl") % roundi(detector_strength * 100)
		Tool.BLOWER, Tool.VACUUM:
			var hit := _ray(origin, origin + forward * player.reach, 1 | 4 | 8 | 16)
			if hit.is_empty() or hit.collider != pile.foam_body:
				_continuous_elapsed = 0.0
				return tr("Aim at foam")
			_continuous_elapsed += delta
			if _continuous_elapsed < CONTINUOUS_CUT_INTERVAL:
				return ""
			# Accumulate time so lower rebuild frequency preserves litres/second.
			var cut_delta := _continuous_elapsed
			_continuous_elapsed = 0.0
			if selected_tool == Tool.BLOWER:
				# Foam is dispersed off-site, never converted into disposal credits.
				pile.excavate(hit.position, 1.15, 0.18 * cut_delta, 0.10 * cut_delta)
			else:
				var room := maxf(0.0, player.bucket_capacity() - player.bucket_load)
				var volume := pile.excavate(hit.position, 0.55, 0.45 * cut_delta, minf(room, cut_delta * 0.12))
				player.bucket_load += volume
				player.bucket_changed.emit(player.bucket_load, player.bucket_capacity())
			return ""
	return ""

func _update_uv(origin: Vector3, forward: Vector3) -> void:
	var hints := PackedVector4Array()
	hints.resize(8)
	var hint_count := 0
	for pearl in pile.pearls:
		var result := uv_visibility(pearl, origin, forward)
		var strength: float = result.get("strength", 0.0)
		pearl.set_uv_strength(strength)
		if strength > 0.0 and result.has("surface") and hint_count < hints.size():
			var entry: Vector3 = result["surface"]
			hints[hint_count] = Vector4(entry.x, entry.y, entry.z, strength)
			hint_count += 1
	pile.material.set_shader_parameter("uv_hints", hints)
	pile.material.set_shader_parameter("uv_hint_count", hint_count)

func uv_visibility(pearl: Pearl, origin: Vector3, forward: Vector3) -> Dictionary:
	# UV is a finishing aid, not a deep-search substitute for the detector.
	# Higher levels brighten eligible items; neither penetration limit changes.
	if not _searchable(pearl):
		return {}
	var offset := pearl.global_position - origin
	var distance := offset.length()
	if distance <= 0.001 or distance >= 7.0 or offset.normalized().dot(forward.normalized()) <= 0.91:
		return {}
	var cover := maxf(0.0, pile.sample_height(pearl.global_position) - pearl.global_position.y - Pearl.RADIUS)
	if cover >= UV_MAX_COVER or not pile.world_clear(origin, pearl.global_position):
		return {}
	# A near-surface sphere on the far side of a mountain must not glow through
	# metres of intervening foam. Integrate the traversed layer along the ray,
	# ending at the sphere's near face; vertical cover alone is insufficient.
	var ray_direction := offset / distance
	var ray_length := maxf(0.0, distance - Pearl.RADIUS)
	var samples := maxi(1, int(ceil(ray_length / UV_SAMPLE_STEP)))
	var step_length := ray_length / samples
	var foam_path := 0.0
	var entry := Vector3.ZERO
	var has_entry := false
	for index in range(samples):
		var point := origin + ray_direction * (float(index) + 0.5) * step_length
		if pile.sample_height(point) > point.y + 0.003:
			foam_path += step_length
			if not has_entry:
				entry = point
				entry.y = pile.sample_height(point)
				has_entry = true
			if foam_path > UV_MAX_PATH:
				return {}
	var thinness := 1.0 - smoothstep(0.02, UV_MAX_COVER, cover)
	var brightness := minf(1.0, 0.55 + 0.11 * maxi(0, manager.level("uv") - 1))
	var result := {"strength": brightness * thinness * clampf(1.2 - distance / 10.0, 0.35, 1.0)}
	if has_entry:
		result["surface"] = entry
	return result

func _searchable(pearl: Pearl) -> bool:
	return pearl.state in [Pearl.State.EMBEDDED, Pearl.State.EXPOSED, Pearl.State.FREE]

func _ray(start: Vector3, finish: Vector3, mask: int) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(start, finish, mask)
	query.hit_from_inside = true
	return get_world_3d().direct_space_state.intersect_ray(query)

func _update_detector(delta: float, camera: Camera3D) -> void:
	var nearest := 7.0
	for pearl in pile.pearls:
		if _searchable(pearl) and pile.world_clear(camera.global_position, pearl.global_position):
			nearest = minf(nearest, camera.global_position.distance_to(pearl.global_position))
	detector_strength = clampf(1.0 - nearest / 7.0, 0.0, 1.0)
	if detector_strength <= 0.0:
		_beep.stop()
		_beep_cooldown = 0.0
		return
	_beep_cooldown -= delta
	if _beep_cooldown <= 0.0:
		_beep.pitch_scale = 1.0
		_beep.play()
		_beep_cooldown = lerpf(1.2, 0.28, detector_strength)

func _reset_effects() -> void:
	_air.emitting = false
	detector_strength = 0.0
	_beep_cooldown = 0.0
	_continuous_elapsed = 0.0
	_beep.stop()
	_uv_light.visible = false
	pile.set_uv_scan(Vector3.ZERO, Vector3.FORWARD, false)
	pile.material.set_shader_parameter("uv_hint_count", 0)
	for pearl in pile.pearls:
		pearl.set_uv_strength(0.0)

func animate_scoop() -> void:
	if _stroke_tween != null and _stroke_tween.is_running():
		_stroke_tween.kill()
	_stroke_tween = create_tween()
	var moving := _models[0] if manager.owns_upgrade("scoop") else _hands
	_stroke_tween.tween_property(moving, "rotation:x", -0.5, 0.08)
	_stroke_tween.tween_property(moving, "rotation:x", 0.0, 0.15)

func _build_view_tools(camera: Camera3D) -> void:
	var fill_light := OmniLight3D.new()
	fill_light.name = "HandsFillLight"
	fill_light.position = Vector3(-0.1, 0.12, -0.12)
	fill_light.omni_range = 1.5
	fill_light.light_energy = 0.45
	fill_light.light_color = Color(0.82, 0.88, 1.0)
	fill_light.shadow_enabled = false
	camera.add_child(fill_light)
	_hands = Node3D.new()
	_hands.position = Vector3(0.3, -0.34, -0.55)
	camera.add_child(_hands)
	Art.hand(_hands, manager.level("gloves"))
	_hand_foam = Props.box(_hands, Vector3(0, 0.07, -0.04), Vector3(0.16, 0.1, 0.16), Color(0.9, 0.89, 0.8), false)
	_uv_light = SpotLight3D.new()
	_uv_light.name = "UVBeam"
	_uv_light.position = Vector3(0.18, -0.16, -0.22)
	_uv_light.light_color = Color(0.25, 0.25, 1.0)
	_uv_light.light_energy = 1.2
	_uv_light.spot_range = 7.0
	_uv_light.spot_angle = 30.0
	_uv_light.light_volumetric_fog_energy = 0.0
	_uv_light.shadow_enabled = true
	_uv_light.visible = false
	camera.add_child(_uv_light)
	for index in range(5):
		var model := Node3D.new()
		model.name = "ToolModel_%d" % index
		model.position = Vector3(0.34, -0.3, -0.65)
		camera.add_child(model)
		Art.tool(model, index, manager.level("scoop"))
		_add_grip(model)
		model.visible = index == selected_tool
		_models.append(model)
	# A small stylized carried bucket mirrors inventory; it has no physics body.
	var bucket := Node3D.new()
	_bucket_model = bucket
	bucket.name = "PortableBucket"
	bucket.position = Vector3(-0.36, -0.4, -0.62)
	camera.add_child(bucket)
	_bucket_fill = Art.bucket(bucket, manager.level("bucket"))
	_air = Art.airflow(_models[3])

func _refresh_art(id: String) -> void:
	# Rebuild only at purchase boundaries, not per frame. The gameplay nodes,
	# inventory volume and tool selection survive the visual replacement.
	if id == "bucket":
		_clear_art(_bucket_model)
		_bucket_fill = Art.bucket(_bucket_model, manager.level(id))
	elif id == "scoop":
		_clear_art(_models[0])
		Art.tool(_models[0], 0, manager.level(id))
		_add_grip(_models[0])
	elif id == "gloves":
		for child in _hands.get_children():
			if child != _hand_foam:
				_hands.remove_child(child)
				child.queue_free()
		Art.hand(_hands, manager.level(id))
		for model in _models:
			var old_grip := model.get_node("GripHand")
			model.remove_child(old_grip)
			old_grip.queue_free()
			_add_grip(model)

func _add_grip(model: Node3D) -> void:
	var grip := Node3D.new()
	grip.name = "GripHand"
	grip.position = Vector3(0, -0.07, 0.10)
	grip.rotation.z = -0.35
	model.add_child(grip)
	Art.hand(grip, manager.level("gloves"))

func _clear_art(root: Node3D) -> void:
	for child in root.get_children():
		root.remove_child(child)
		child.queue_free()
