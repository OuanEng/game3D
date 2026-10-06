class_name BarnEnvironment
extends Node3D
## A 20 x 20 metre timber barn, built from replaceable primitive art.
## Only the floor, perimeter and larger props collide; dust is purely visual.
## Scene gameplay is deliberately independent of the selected renderer.

@export var flicker_enabled: bool = true
@export var dust_enabled: bool = true
var pallet: Node3D
var flickering_light: SpotLight3D
var fluorescent_material: StandardMaterial3D
var time: float = 0.0

func _ready() -> void:
	build_structure()
	build_lighting()
	if dust_enabled:
		build_dust()
	var hum := AudioStreamPlayer.new()
	hum.name = "DistantVentilationHum"
	hum.stream = SoundBank.tone(60.0, 1.0, true)
	hum.volume_db = -31.0
	add_child(hum)
	hum.play()

func timber(at: Vector3, size: Vector3, color: Color, solid: bool = false) -> Node3D:
	var board := Props.box(self, at, size, color, solid)
	var surface := (board.get_child(0) as MeshInstance3D).material_override as StandardMaterial3D
	surface.roughness = 0.88
	return board

func beam_between(start: Vector3, finish: Vector3, thickness: float, color: Color) -> void:
	var offset := finish - start
	var beam := timber((start + finish) * 0.5, Vector3(thickness, offset.length(), thickness), color)
	beam.quaternion = Quaternion(Vector3.UP, offset.normalized())

func perimeter_collision(at: Vector3, size: Vector3) -> void:
	# Keep tiny visual gaps open to LIGHT without creating 130 physics bodies.
	# An invisible collision shape does not cast shadows or obstruct the moon.
	var wall := StaticBody3D.new()
	wall.name = "PerimeterCollision"
	wall.position = at
	wall.collision_layer = 1 # World, layer 1.
	wall.collision_mask = 6 # Player + Pearls, layers 2 and 3.
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	wall.add_child(collider)
	add_child(wall)

func build_structure() -> void:
	var dark_wood := Color(0.20, 0.13, 0.075)
	var warm_wood := Color(0.34, 0.235, 0.14)
	var beam_wood := Color(0.24, 0.15, 0.08)
	timber(Vector3(0, -0.16, 0), Vector3(20.5, 0.3, 20.5), dark_wood, true)
	# Long floorboards and occasional end joints read clearly in raking light.
	for index in range(25):
		var x := -9.6 + index * 0.8
		var shade := 0.84 + float(index % 5) * 0.045
		timber(Vector3(x, 0.005, 0), Vector3(0.775, 0.018, 20), warm_wood * shade)
		for z in [-6.0, 0.0, 6.0]:
			timber(Vector3(x, 0.019, z + float(index % 3) * 0.7), Vector3(0.77, 0.005, 0.018), dark_wood)
	# 0.56 m boards on 0.625 m centres leave real 6.5 cm moonlight gaps.
	for side in [-1.0, 1.0]:
		perimeter_collision(Vector3(side * 10, 3.1, 0), Vector3(0.22, 6.2, 20.3))
		perimeter_collision(Vector3(0, 3.1, side * 10), Vector3(20.3, 6.2, 0.22))
		for index in range(32):
			var along := -9.69 + index * 0.625
			var shade := 0.75 + float((index * 7) % 6) * 0.065
			timber(Vector3(side * 10, 3.1, along), Vector3(0.16, 6.2, 0.56), warm_wood * shade)
			timber(Vector3(along, 3.1, side * 10), Vector3(0.56, 6.2, 0.16), warm_wood * shade)
		# Gable infill follows the pitched roof. It also keeps narrow light gaps.
		for index in range(31):
			var x := -9.375 + index * 0.625
			var height := 2.4 * (1.0 - absf(x) / 10.0)
			timber(Vector3(x, 6.2 + height * 0.5, side * 10), Vector3(0.56, height, 0.16), dark_wood)
	# Exposed posts and trusses are spaced beyond the central foam mountain.
	for z in [-9.5, -4.8, 0.0, 4.8, 9.5]:
		for side in [-1.0, 1.0]:
			timber(Vector3(side * 9.35, 3.15, z), Vector3(0.36, 6.3, 0.4), beam_wood, true)
			beam_between(Vector3(side * 9.35, 6.2, z), Vector3(0, 8.6, z), 0.28, beam_wood)
			beam_between(Vector3(side * 9.35, 4.9, z), Vector3(side * 7.5, 6.2, z), 0.23, beam_wood)
		timber(Vector3(0, 6.2, z), Vector3(19, 0.24, 0.26), beam_wood)
		timber(Vector3(0, 7.4, z), Vector3(0.22, 2.4, 0.22), beam_wood)
	# Split pitched panels leave a modest ridge gap, rather than an open roof.
	for side in [-1.0, 1.0]:
		var roof := timber(Vector3(side * 5.1, 7.37, 0), Vector3(10.18, 0.16, 20.5), dark_wood)
		roof.rotation.z = -side * atan2(2.4, 10.0)
	# Stacked packing crates add silhouettes along the rear wall, away from tasks.
	for side in [-1.0, 1.0]:
		for index in range(3):
			var at := Vector3(side * (6.2 + float(index % 2) * 1.8), 0.7 + float(index / 2) * 1.4, -8.1)
			build_crate(at, Vector3(1.6, 1.35, 1.5))
	Props.sign_at(self, "NIGHT SHIFT  /  BARN 07", Vector3(0, 4.7, -9.83))
	Props.sign_at(self, "PACKING FOAM\nKEEP AISLES CLEAR", Vector3(-5.2, 2.6, -9.81))
	# This prop is exposed to IntroCutscene for its animated accidental bump.
	pallet = Node3D.new()
	pallet.name = "LoosePallet"
	pallet.position = Vector3(0, 0, -5.5)
	add_child(pallet)
	for index in range(6):
		Props.box(pallet, Vector3(-0.85 + index * 0.34, 0.15, 0), Vector3(0.27, 0.16, 1.35), warm_wood, false)
	for x in [-0.7, 0.7]:
		Props.box(pallet, Vector3(x, 0.065, 0), Vector3(0.16, 0.13, 1.4), dark_wood, false)
	Props.box(pallet, Vector3(0, 0.56, 0), Vector3(1.25, 0.68, 0.85), Color(0.4, 0.31, 0.20), false)

func build_crate(at: Vector3, size: Vector3) -> void:
	timber(at, size, Color(0.28, 0.19, 0.10), true)
	for x in [-0.62, 0.62]:
		timber(at + Vector3(x, 0, size.z * 0.5 + 0.015), Vector3(0.09, size.y, 0.035), Color(0.44, 0.31, 0.16))
	for y in [-0.5, 0.5]:
		timber(at + Vector3(0, y, size.z * 0.5 + 0.035), Vector3(size.x, 0.09, 0.035), Color(0.40, 0.27, 0.13))

func build_lighting() -> void:
	var world := WorldEnvironment.new()
	world.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.009, 0.016, 0.032)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.40, 0.50, 0.68)
	environment.ambient_light_energy = 0.18
	# Volumetric lighting is a Forward+ feature. Compatibility still gets haze,
	# floating dust and the same readable task lights, with no shader dependency.
	if RenderingServer.get_current_rendering_method() == "forward_plus":
		environment.volumetric_fog_enabled = true
		environment.volumetric_fog_density = 0.012
		environment.volumetric_fog_length = 35.0
		environment.volumetric_fog_albedo = Color(0.58, 0.66, 0.78)
		environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		environment.ssao_enabled = true
	else:
		environment.fog_enabled = true
		environment.fog_density = 0.006
		environment.fog_light_color = Color(0.035, 0.055, 0.09)
		environment.fog_light_energy = 0.25
	world.environment = environment
	add_child(world)
	var moon := DirectionalLight3D.new()
	moon.name = "Moonlight"
	moon.rotation_degrees = Vector3(-24, -58, 0)
	moon.light_color = Color(0.43, 0.58, 0.91)
	moon.light_energy = 0.42
	moon.light_volumetric_fog_energy = 0.6
	moon.shadow_enabled = true
	add_child(moon)
	# Three stable pools of light preserve clear gameplay even during flicker.
	hanging_lamp("FoamWorkLamp", Vector3(0, 5.8, 0.7), Vector3(0, 0.4, -1), Color(1.0, 0.81, 0.53), 5.0, 58.0, true)
	hanging_lamp("RinseLamp", Vector3(-5, 4.4, 3.0), Vector3(-5, 0.7, 3), Color(0.68, 0.84, 1.0), 3.2, 44.0, false)
	hanging_lamp("VelvetLamp", Vector3(5, 4.4, 3.0), Vector3(5, 0.7, 3), Color(1.0, 0.74, 0.43), 3.2, 44.0, false)
	hanging_lamp("UpgradeLamp", Vector3(7, 4.5, 5), Vector3(7, 0.8, 5), Color(0.69, 0.91, 0.84), 2.1, 37.0, false)
	# A restrained shaft supplements the directional light passing through gaps.
	var shaft := spot("MoonShaft", Vector3(-9.7, 5.5, -6.5), Vector3(0, 0.3, -0.5), Color(0.43, 0.6, 1.0), 2.0, 17.0, true)
	shaft.spot_range = 19.0
	shaft.light_volumetric_fog_energy = 2.5
	flickering_light = hanging_lamp("RearFluorescent", Vector3(3, 5.5, -7.1), Vector3(3, 0, -7), Color(0.72, 0.88, 0.85), 1.15, 50.0, false)
	# Rapidly changing lights leave volumetric reprojection trails; disable that
	# contribution while keeping their direct illumination and visible bulb.
	flickering_light.light_volumetric_fog_energy = 0.0
	var fixture := Props.box(self, Vector3(3, 5.48, -7.1), Vector3(1.7, 0.07, 0.14), Color(0.72, 0.88, 0.85), false)
	fluorescent_material = (fixture.get_child(0) as MeshInstance3D).material_override
	fluorescent_material.emission_enabled = true
	fluorescent_material.emission = Color(0.72, 0.88, 0.85)
	fluorescent_material.emission_energy_multiplier = 1.15

func spot(label: String, at: Vector3, target: Vector3, color: Color, energy: float, angle: float, shadows: bool) -> SpotLight3D:
	var light := SpotLight3D.new()
	light.name = label
	light.position = at
	light.light_color = color
	light.light_energy = energy
	light.spot_range = 14.0
	light.spot_angle = angle
	light.shadow_enabled = shadows
	add_child(light)
	# Godot's lights point along local -Z; a nonparallel up vector is needed
	# when a hanging light aims straight downward.
	var up := Vector3.FORWARD if absf((target - at).normalized().dot(Vector3.UP)) > 0.99 else Vector3.UP
	light.look_at(target, up)
	return light

func hanging_lamp(label: String, at: Vector3, target: Vector3, color: Color, energy: float, angle: float, shadows: bool) -> SpotLight3D:
	var light := spot(label, at, target, color, energy, angle, shadows)
	Props.box(self, Vector3(at.x, (at.y + 6.15) * 0.5, at.z), Vector3(0.025, 6.15 - at.y, 0.025), Color(0.075, 0.08, 0.085), false)
	var shade := MeshInstance3D.new()
	var shade_mesh := CylinderMesh.new()
	shade_mesh.top_radius = 0.10
	shade_mesh.bottom_radius = 0.34
	shade_mesh.height = 0.2
	shade.mesh = shade_mesh
	shade.material_override = Props.material(Color(0.18, 0.23, 0.2), 0.55)
	shade.position = at + Vector3(0, 0.16, 0)
	add_child(shade)
	var bulb := MeshInstance3D.new()
	var bulb_mesh := SphereMesh.new()
	bulb_mesh.radius = 0.075
	bulb_mesh.height = 0.15
	bulb.mesh = bulb_mesh
	var surface := Props.material(color)
	surface.emission_enabled = true
	surface.emission = color
	surface.emission_energy_multiplier = 2.0
	bulb.material_override = surface
	bulb.position = at + Vector3(0, 0.015, 0)
	bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bulb)
	return light

func build_dust() -> void:
	# CPU particles are supported on both renderers. 110 quads cost very little;
	# they are decoration, never colliders or collectible foam.
	var dust := CPUParticles3D.new()
	dust.name = "DriftingDust"
	dust.position = Vector3(0, 3.0, 0)
	dust.amount = 110
	dust.lifetime = 18.0
	dust.preprocess = 18.0
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(8, 2.5, 8)
	dust.direction = Vector3(1, 0.08, 0)
	dust.spread = 45.0
	dust.gravity = Vector3(0, -0.004, 0)
	dust.initial_velocity_min = 0.015
	dust.initial_velocity_max = 0.07
	dust.scale_amount_min = 0.45
	dust.scale_amount_max = 1.2
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.15, 0.85, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0)])
	dust.color_ramp = fade
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.028, 0.028)
	var surface := StandardMaterial3D.new()
	surface.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	surface.vertex_color_use_as_albedo = true
	surface.albedo_color = Color(0.72, 0.80, 0.91, 0.55)
	surface.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	surface.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# A soft radial texture avoids visibly square dust when particles pass nearby.
	var dust_gradient := Gradient.new()
	dust_gradient.set_color(0, Color(1, 1, 1, 0.7))
	dust_gradient.set_color(1, Color(1, 1, 1, 0))
	var dust_texture := GradientTexture2D.new()
	dust_texture.width = 32
	dust_texture.height = 32
	dust_texture.fill = GradientTexture2D.FILL_RADIAL
	dust_texture.fill_from = Vector2(0.5, 0.5)
	dust_texture.fill_to = Vector2(1.0, 0.5)
	dust_texture.gradient = dust_gradient
	surface.albedo_texture = dust_texture
	mesh.material = surface
	dust.mesh = mesh
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(dust)

func _process(delta: float) -> void:
	time += delta
	# A single soft dip every eight seconds avoids constant flashing.
	var cycle := fmod(time, 8.0)
	var energy := 1.15
	if flicker_enabled and cycle < 0.5:
		energy -= 0.35 * sin(cycle / 0.5 * PI)
	flickering_light.light_energy = energy
	fluorescent_material.emission_energy_multiplier = energy

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_flicker"):
		flicker_enabled = not flicker_enabled
	if event.is_action_pressed("mute"):
		AudioServer.set_bus_mute(0, not AudioServer.is_bus_mute(0))
