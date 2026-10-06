class_name FactoryEnvironment
extends Node3D
## Cold warehouse surround with a stable, warm pool of readable task lighting.
@export var flicker_enabled: bool = true
var flickering_light: SpotLight3D
var fluorescent_material: StandardMaterial3D
var time: float = 0.0
var pallet: Node3D

func _ready() -> void:
	build_lighting()
	build_structure()
	var hum := AudioStreamPlayer.new()
	hum.name = "VentilationHum"
	hum.stream = SoundBank.tone(60.0, 1.0, true)
	hum.volume_db = -28.0
	add_child(hum)
	hum.play()

func build_lighting() -> void:
	var world := WorldEnvironment.new()
	world.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.008, 0.014, 0.025)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.34, 0.45, 0.63)
	environment.ambient_light_energy = 0.12
	# Volumetric fog needs Forward+. Compatibility uses conventional depth fog.
	if RenderingServer.get_current_rendering_method() == "forward_plus":
		environment.volumetric_fog_enabled = true
		environment.volumetric_fog_density = 0.018
		environment.volumetric_fog_length = 24.0
		environment.volumetric_fog_albedo = Color(0.66, 0.74, 0.83)
		environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		environment.ssao_enabled = true
	else:
		environment.fog_enabled = true
		environment.fog_density = 0.008
		environment.fog_light_color = Color(0.04, 0.06, 0.09)
		environment.fog_light_energy = 0.3
	world.environment = environment
	add_child(world)
	var moon := DirectionalLight3D.new()
	moon.name = "Moonlight"
	moon.rotation_degrees = Vector3(-35, -30, 0)
	moon.light_color = Color(0.42, 0.56, 0.85)
	moon.light_energy = 0.12
	moon.shadow_enabled = true
	add_child(moon)
	spot("WorkbenchLamp", Vector3(0, 4.2, 1.4), Vector3(0, 0.9, -0.8), Color(1.0, 0.82, 0.58), 4.0, 48.0, true)
	spot("RinseLamp", Vector3(-3.1, 3.5, 0.3), Vector3(-3.1, 1, -0.4), Color(0.64, 0.82, 1.0), 2.5, 38.0, false)
	spot("VelvetLamp", Vector3(3.1, 3.5, 0.3), Vector3(3.1, 1, -0.4), Color(1.0, 0.79, 0.5), 2.5, 38.0, false)
	flickering_light = spot("AisleFluorescent", Vector3(-3, 4.5, -4.5), Vector3(-3, 0, -4.3), Color(0.7, 0.85, 0.82), 1.3, 55.0, false)
	# A flickering source should not leave temporal trails in volumetric fog.
	flickering_light.light_volumetric_fog_energy = 0.0
	var fixture := Props.box(self, Vector3(-3, 4.48, -4.5), Vector3(2.1, 0.08, 0.2), Color(0.7, 0.86, 0.81), false)
	fluorescent_material = (fixture.get_child(0) as MeshInstance3D).material_override
	fluorescent_material.emission_enabled = true
	fluorescent_material.emission = Color(0.7, 0.86, 0.81)
	fluorescent_material.emission_energy_multiplier = 1.3

func spot(label: String, at: Vector3, target: Vector3, color: Color, energy: float, angle: float, shadows: bool) -> SpotLight3D:
	var light := SpotLight3D.new()
	light.name = label
	light.position = at
	light.light_color = color
	light.light_energy = energy
	light.spot_range = 9.0
	light.spot_angle = angle
	light.shadow_enabled = shadows
	add_child(light)
	light.look_at(target)
	return light

func build_structure() -> void:
	var steel := Color(0.12, 0.17, 0.2)
	Props.box(self, Vector3(0, -0.15, 0), Vector3(16, 0.3, 14), Color(0.18, 0.2, 0.21))
	Props.box(self, Vector3(0, 2.7, -7), Vector3(16, 5.4, 0.2), Color(0.14, 0.19, 0.22))
	Props.box(self, Vector3(0, 2.7, 7), Vector3(16, 5.4, 0.2), steel)
	for x in [-8, 8]:
		Props.box(self, Vector3(x, 2.7, 0), Vector3(0.2, 5.4, 14), steel)
	for z in [-6, -2, 3, 6]:
		for x in [-6.8, 6.8]:
			Props.box(self, Vector3(x, 2.6, z), Vector3(0.22, 5.2, 0.3), steel)
		Props.box(self, Vector3(0, 5.1, z), Vector3(14, 0.3, 0.25), steel)
	# Split roof leaves a narrow skylight for the cool directional source.
	for x in [-4.65, 4.65]:
		Props.box(self, Vector3(x, 5.4, 0), Vector3(6.7, 0.15, 14), steel)
	for x in [-4.5, 0.0, 4.5]:
		build_shelf(Vector3(x, 0, -5.8))
	for x in [-2.05, 2.05]:
		Props.box(self, Vector3(x, 0.012, -0.5), Vector3(0.045, 0.015, 4.0), Color(0.7, 0.49, 0.12), false)
	Props.sign_at(self, "NIGHT SHIFT / PACKING BAY 07", Vector3(0, 3.5, -6.85))
	pallet = Node3D.new()
	pallet.name = "LoosePallet"
	pallet.position = Vector3(0, 0, -2.7)
	add_child(pallet)
	for index in range(5):
		Props.box(pallet, Vector3(-0.65 + index * 0.32, 0.15, 0), Vector3(0.24, 0.13, 1.1), Color(0.35, 0.25, 0.15), false)
	Props.box(pallet, Vector3(0, 0.5, 0), Vector3(1.3, 0.55, 0.8), Color(0.34, 0.29, 0.22), false)

func build_shelf(at: Vector3) -> void:
	var steel := Color(0.23, 0.28, 0.3)
	for x in [-1.6, 1.6]:
		for z in [-0.5, 0.5]:
			Props.box(self, at + Vector3(x, 1.65, z), Vector3(0.1, 3.3, 0.1), steel)
	for level in range(3):
		var y := 0.25 + level * 1.25
		Props.box(self, at + Vector3(0, y, 0), Vector3(3.3, 0.09, 1.2), steel)
		for index in range(3):
			Props.box(self, at + Vector3(-1 + index, y + 0.35, 0), Vector3(0.7, 0.6, 0.8), Color(0.33, 0.28, 0.21))

func _process(delta: float) -> void:
	time += delta
	# One gentle dip per eight seconds, away from the stable gameplay lamp.
	var cycle := fmod(time, 8.0)
	var energy := 1.3
	if flicker_enabled and cycle < 0.5:
		energy -= 0.45 * sin(cycle / 0.5 * PI)
	flickering_light.light_energy = energy
	fluorescent_material.emission_energy_multiplier = energy

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_flicker"):
		flicker_enabled = not flicker_enabled
	if event.is_action_pressed("mute"):
		AudioServer.set_bus_mute(0, not AudioServer.is_bus_mute(0))
