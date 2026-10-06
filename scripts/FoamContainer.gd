class_name FoamContainer
extends Node3D
## Owns the tub, foam volume and pearl spawn positions. Keep this node at unit scale.
## Static chunks block tools; only released pearls run rigid-body physics.
@export_range(1, 8) var pearl_count: int = 8
@export var layout_seed: int = 0 # Zero randomizes; other values reproduce a layout.
var pearls: Array[Pearl] = []
var chunks: Array[Foam] = []

func _ready() -> void:
	build_tub()
	var volume := Node3D.new()
	volume.name = "FoamVolume"
	add_child(volume)
	for x in range(7):
		for y in range(3):
			for z in range(5):
				var chunk := Foam.new()
				chunk.position = Vector3(-1.2 + x * 0.4, 0.96 + y * 0.4, -1.6 + z * 0.4)
				chunk.container = self
				volume.add_child(chunk)
				chunks.append(chunk)
	spawn_pearls()

func build_tub() -> void:
	var steel := Color(0.22, 0.32, 0.34)
	Props.box(self, Vector3(0, 0.65, -0.8), Vector3(2.8, 0.2, 2.0), steel)
	for x in [-1.45, 1.45]:
		Props.box(self, Vector3(x, 0.96, -0.8), Vector3(0.12, 0.8, 2.2), steel)
	for z in [-1.85, 0.25]:
		Props.box(self, Vector3(0, 0.96, z), Vector3(3.0, 0.8, 0.12), steel)
	# Raised rim and yellow loading-bay markings communicate a work zone.
	for x in [-1.45, 1.45]:
		Props.box(self, Vector3(x, 1.38, -0.8), Vector3(0.18, 0.06, 2.2), Color(0.55, 0.6, 0.59))
	for index in range(9):
		Props.box(self, Vector3(-1.2 + index * 0.3, 1.1, 0.316), Vector3(0.15, 0.15, 0.015), Color(0.85, 0.59, 0.13), false)
	Props.sign_at(self, "PACKING / 07", Vector3(0, 0.82, 0.325))

func spawn_pearls() -> void:
	var rng := RandomNumberGenerator.new()
	if layout_seed == 0:
		rng.randomize()
	else:
		rng.seed = layout_seed
	var cells: Array[Vector3] = []
	for x in range(1, 6):
		for z in range(1, 4):
			cells.append(Vector3(-1.2 + x * 0.4, 0.96, -1.6 + z * 0.4))
	for index in range(clampi(pearl_count, 1, 8)):
		var chosen := rng.randi_range(0, cells.size() - 1)
		var pearl := Pearl.new()
		pearl.name = "Pearl_%02d" % (index + 1)
		pearl.position = cells[chosen]
		pearl.foam_container = self
		cells.remove_at(chosen)
		add_child(pearl)
		pearls.append(pearl)

func brush(chunk: Foam, delta: float) -> void:
	# Player's closest-hit ray chooses a single frontmost cell. No clearing through walls.
	if is_instance_valid(chunk) and chunk.container == self:
		chunk.brush(delta)

func is_covered(world_point: Vector3) -> bool:
	for chunk in chunks:
		if is_instance_valid(chunk) and chunk.covers(world_point):
			return true
	return false
