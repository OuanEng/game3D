extends RefCounted
## Replaceable collision-free procedural props. Dimensions are metres.
static func mat(color: Color, metal: float = 0.0, glow: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metal
	m.roughness = 0.38 if metal > 0 else 0.68
	m.emission_enabled = glow > 0
	m.emission = color
	m.emission_energy_multiplier = glow
	return m

static func mesh(parent: Node3D, geometry: Mesh, at: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = geometry
	node.position = at
	node.material_override = material
	parent.add_child(node)
	return node

static func box(parent: Node3D, at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	return mesh(parent, shape, at, material)

static func tube(parent: Node3D, a: Vector3, b: Vector3, radius: float, material: Material) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = a.distance_to(b)
	shape.radial_segments = 12
	var node := mesh(parent, shape, (a + b) * 0.5, material)
	node.quaternion = Quaternion(Vector3.UP, (b - a).normalized())
	return node

static func ring(parent: Node3D, at: Vector3, radius: float, thickness: float, material: Material) -> MeshInstance3D:
	var shape := TorusMesh.new()
	shape.inner_radius = radius - thickness
	shape.outer_radius = radius + thickness
	shape.rings = 20
	shape.ring_segments = 8
	return mesh(parent, shape, at, material)

static func hand(parent: Node3D, level: int) -> void:
	# All anatomy is cube geometry. Nearest filtering keeps generated pixels crisp.
	var skin := voxel_material(level)
	# A single square-section arm/fist silhouette, without individual fingers.
	box(parent, Vector3(0, -0.005, 0.08), Vector3(0.14, 0.14, 0.38), skin)
	if level >= 3:
		box(parent, Vector3(0, 0.033, -0.015), Vector3(0.10, 0.025, 0.06), mat(Color(0.10, 0.12, 0.13), 0.3))

static func voxel_material(level: int) -> StandardMaterial3D:
	var base := Color(0.92, 0.59, 0.34) if level == 0 else Color(1.0, 0.68, 0.12)
	var pixels := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in range(16):
		for x in range(16):
			var grain := (x * 7 + y * 11 + x * y) % 13
			var color := base.lightened(0.32) if grain < 4 else base
			if grain > 10 or (y < 4 and (x / 2 + y) % 3 == 0):
				color = base.darkened(0.28)
			pixels.set_pixel(x, y, color)
	var material := mat(Color.WHITE)
	material.albedo_texture = ImageTexture.create_from_image(pixels)
	material.emission_enabled = true
	material.emission = Color.WHITE
	material.emission_texture = material.albedo_texture
	material.emission_energy_multiplier = 0.22
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return material

static func bucket(parent: Node3D, level: int) -> MeshInstance3D:
	var surface := mat(Color(0.62, 0.075, 0.035) if level < 3 else Color(0.55, 0.60, 0.62), 0.0 if level < 3 else 0.85)
	# Open pail formed from tapered staves, rather than a solid capped cylinder.
	for i in range(20):
		var angle := TAU * i / 20.0
		var panel := box(parent, Vector3(sin(angle) * 0.145, -0.025, cos(angle) * 0.145), Vector3(0.048, 0.29, 0.015), surface)
		panel.rotation.y = angle
	ring(parent, Vector3(0, 0.12, 0), 0.15, 0.013, surface)
	tube(parent, Vector3(0, -0.175, 0), Vector3(0, -0.165, 0), 0.145, surface)
	var wire := mat(Color(0.36, 0.38, 0.4), 0.8)
	for i in range(12):
		var a := PI * i / 12.0
		var b := PI * (i + 1) / 12.0
		tube(parent, Vector3(cos(a) * 0.15, 0.12 + sin(a) * 0.17, 0), Vector3(cos(b) * 0.15, 0.12 + sin(b) * 0.17, 0), 0.006, wire)
	var shape := CylinderMesh.new()
	shape.top_radius = 0.133
	shape.bottom_radius = 0.133
	shape.height = 0.015
	return mesh(parent, shape, Vector3(0, -0.15, 0), mat(Color(0.87, 0.88, 0.81)))

static func tool(parent: Node3D, kind: int, level: int) -> void:
	var dark := mat(Color(0.045, 0.055, 0.065))
	var steel := mat(Color(0.43, 0.49, 0.51), 0.85)
	match kind:
		0:
			tube(parent, Vector3(0, 0, 0.20), Vector3(0, 0, -0.29), 0.025, mat(Color(0.30, 0.16, 0.065)))
			var width := 0.17 + 0.035 * level
			box(parent, Vector3(0, -0.03, -0.34), Vector3(width, 0.018, 0.25), steel)
			for side in [-1, 1]:
				box(parent, Vector3(side * width * 0.5, -0.005, -0.34), Vector3(0.012, 0.06, 0.25), steel)
			for i in range(6):
				box(parent, Vector3(sin(i * 2.1) * width * 0.35, -0.019, -0.25 - i * 0.026), Vector3(0.032, 0.003, 0.025), mat(Color(0.29, 0.105, 0.035)))
		1:
			var purple := mat(Color(0.11, 0.055, 0.19), 0.4)
			tube(parent, Vector3(0, 0, 0.15), Vector3(0, 0, -0.25), 0.075, purple)
			tube(parent, Vector3(0, 0, -0.25), Vector3(0, 0, -0.34), 0.105, dark)
			tube(parent, Vector3(0, 0, -0.34), Vector3(0, 0, -0.345), 0.09, mat(Color(0.47, 0.1, 1), 0, 1.6))
			for i in range(5):
				var grip := ring(parent, Vector3(0, 0, i * 0.045), 0.077, 0.008, dark)
				grip.rotation.x = PI / 2
		2:
			box(parent, Vector3.ZERO, Vector3(0.21, 0.13, 0.30), mat(Color(0.18, 0.24, 0.13), 0.25))
			box(parent, Vector3(0, 0.073, -0.035), Vector3(0.16, 0.013, 0.14), dark)
			for i in range(8):
				var led := box(parent, Vector3(-0.054 + (i % 4) * 0.036, 0.083, -0.075 + (i / 4) * 0.06), Vector3(0.022, 0.008, 0.025), mat(Color(0.2, 0.85, 0.45), 0, 0.7))
				led.name = "LED%d" % i
			tube(parent, Vector3(0, 0, -0.13), Vector3(0, 0, -0.30), 0.015, steel)
			var dish := ring(parent, Vector3(0, 0, -0.31), 0.10, 0.025, steel)
			dish.rotation.x = PI / 2
		3:
			var yellow := mat(Color(0.85, 0.54, 0.025))
			box(parent, Vector3(0.04, -0.025, 0.025), Vector3(0.25, 0.22, 0.28), yellow)
			tube(parent, Vector3(0, 0, -0.1), Vector3(0, -0.015, -0.55), 0.055, dark)
			box(parent, Vector3(0, 0.13, 0.02), Vector3(0.16, 0.04, 0.06), dark)
			for i in range(5):
				box(parent, Vector3(0.17, -0.065 + i * 0.032, 0.02), Vector3(0.009, 0.012, 0.16), dark)
		4:
			tube(parent, Vector3(0.12, -0.16, 0.13), Vector3(0.12, 0.08, 0.13), 0.13, mat(Color(0.17, 0.36, 0.40), 0.7))
			for i in range(15):
				var t := float(i) / 14
				var hose := ring(parent, Vector3(0.12 * (1-t), -0.08 * sin(t * PI), 0.07 - t * 0.40), 0.04, 0.012, dark)
				hose.rotation.x = PI / 2
			tube(parent, Vector3(0, 0, -0.31), Vector3(0, 0, -0.49), 0.043, steel)

static func airflow(parent: Node3D) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.name = "AirSwirl"
	particles.position = Vector3(0, 0, -0.56)
	particles.amount = 22
	particles.lifetime = 0.5
	particles.direction = Vector3(0, 0, -1)
	particles.spread = 14
	particles.gravity = Vector3.ZERO
	particles.initial_velocity_min = 1.0
	particles.initial_velocity_max = 1.8
	particles.tangential_accel_min = 0.8
	particles.tangential_accel_max = 1.4
	particles.scale_amount_min = 0.006
	particles.scale_amount_max = 0.012
	particles.color = Color(0.65, 0.81, 0.83)
	var bead := SphereMesh.new()
	bead.radial_segments = 8
	bead.rings = 4
	particles.mesh = bead
	particles.emitting = false
	parent.add_child(particles)
	return particles
