class_name Tools
extends Node3D
## Tools contain no Input polling. Player passes physics-tick input explicitly.
enum Tool { SCOOP, UV, DETECTOR }
const LABELS := ["Scoop", "UV flashlight", "Pearl detector"]
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

func configure(owner_player: Player, foam_mesh: FoamMesh, game_manager: GameManager) -> void:
	player = owner_player
	pile = foam_mesh
	manager = game_manager
	_beep = AudioStreamPlayer.new()
	_beep.name = "SonarBeep"
	_beep.stream = SoundBank.tone(920.0, 0.065)
	_beep.volume_db = -19.0
	add_child(_beep)
	_build_view_tools(player.camera)

func select_tool(index: int) -> bool:
	if index < Tool.SCOOP or index > Tool.DETECTOR or not manager.owns_tool(index):
		return false
	_reset_effects()
	selected_tool = index
	for model_index in range(_models.size()):
		_models[model_index].visible = model_index == selected_tool
	return true

func use_tool(delta: float, active: bool, camera: Camera3D, stroke: bool = false) -> String:
	_bucket_fill.visible = player.bucket_load > 0.000001
	_bucket_fill.position.y = -0.15 + 0.23 * clampf(player.bucket_load / player.bucket_capacity(), 0, 1)
	for model_index in range(_models.size()):
		_models[model_index].visible = model_index == selected_tool and player.held == null
	if not active or not manager.running:
		_reset_effects()
		return "Click left mouse to scoop" if selected_tool == Tool.SCOOP else "Hold left mouse to use " + LABELS[selected_tool]
	var origin := camera.global_position
	var forward := -camera.global_basis.z
	match selected_tool:
		Tool.SCOOP:
			if player.bucket_load >= player.bucket_capacity() - 0.000001:
				return "BUCKET FULL — E at the waste bin to empty it"
			# Holding the button cannot excavate every tick: one press is one scoop.
			if not stroke:
				return "Release and click again for another scoop"
			var hit := _ray(origin, origin + forward * player.reach, 1 | 4 | 8 | 16)
			if hit.is_empty() or hit.collider != pile.foam_body:
				return "Aim at the foam surface within reach"
			var removed := player.try_scoop_at(hit.position)
			if removed > 0.0:
				animate_scoop()
				return "Scooped %.1f litres" % (removed * 1000.0)
			return "This patch is already down to the floor"
		Tool.UV:
			_uv_light.visible = true
			pile.set_uv_scan(origin, forward, true)
			for pearl in pile.pearls:
				var offset := pearl.global_position - origin
				var distance := offset.length()
				var lit := _searchable(pearl) and distance > 0.001 and distance < 7.0 and offset.normalized().dot(forward) > 0.88
				lit = lit and pile.world_clear(origin, pearl.global_position)
				pearl.set_uv_strength(clampf(1.3 - distance / 9.0, 0.3, 1.0) if lit else 0.0)
			return "UV: locate a cyan pearl, then scoop the surface above it"
		Tool.DETECTOR:
			_update_detector(delta, camera)
			return "Signal %d%% / faster beeps mean a closer pearl" % roundi(detector_strength * 100)
	return ""

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
		_beep.pitch_scale = lerpf(0.72, 1.6, detector_strength)
		_beep.play()
		_beep_cooldown = lerpf(1.05, 0.10, detector_strength)

func _reset_effects() -> void:
	detector_strength = 0.0
	_beep_cooldown = 0.0
	_beep.stop()
	_uv_light.visible = false
	pile.set_uv_scan(Vector3.ZERO, Vector3.FORWARD, false)
	for pearl in pile.pearls:
		pearl.set_uv_strength(0.0)

func animate_scoop() -> void:
	if _stroke_tween != null and _stroke_tween.is_running():
		_stroke_tween.kill()
	_stroke_tween = create_tween()
	_stroke_tween.tween_property(_models[0], "rotation:x", -0.5, 0.08)
	_stroke_tween.tween_property(_models[0], "rotation:x", 0.0, 0.15)

func _build_view_tools(camera: Camera3D) -> void:
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
	for index in range(3):
		var model := Node3D.new()
		model.name = "ToolModel_%d" % index
		model.position = Vector3(0.34, -0.3, -0.65)
		camera.add_child(model)
		if index == Tool.SCOOP:
			Props.box(model, Vector3.ZERO, Vector3(0.045, 0.05, 0.48), Color(0.35, 0.23, 0.10), false)
			Props.box(model, Vector3(0, -0.015, -0.30), Vector3(0.23, 0.035, 0.23), Color(0.48, 0.53, 0.54), false)
		else:
			var color := Color(0.22, 0.11, 0.42) if index == Tool.UV else Color(0.16, 0.26, 0.15)
			Props.box(model, Vector3.ZERO, Vector3(0.15, 0.15, 0.38), color, false)
		model.visible = index == selected_tool
		_models.append(model)
	# A small stylized carried bucket mirrors inventory; it has no physics body.
	var bucket := Node3D.new()
	bucket.name = "PortableBucket"
	bucket.position = Vector3(-0.36, -0.4, -0.62)
	camera.add_child(bucket)
	for x in [-0.16, 0.16]:
		Props.box(bucket, Vector3(x, -0.05, 0), Vector3(0.025, 0.3, 0.29), Color(0.18, 0.35, 0.34), false)
	for z in [-0.14, 0.14]:
		Props.box(bucket, Vector3(0, -0.05, z), Vector3(0.34, 0.3, 0.025), Color(0.18, 0.35, 0.34), false)
	var fill := Props.box(bucket, Vector3(0, -0.15, 0), Vector3(0.28, 0.02, 0.25), Color(0.85, 0.83, 0.71), false)
	_bucket_fill = fill
