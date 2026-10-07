class_name WasteBin
extends StaticBody3D
## Deliberate raycast target for E / dump bucket. Player owns bucket inventory
## and validates that the game is running before emptying it. This station
## never empties the bucket automatically when the player walks nearby.

func _ready() -> void:
	add_to_group("waste_bins")
	collision_layer = 16 # Layer 5: interaction targets.
	collision_mask = 0
	# The target extends just in front of the rim, so the world-layer bin walls
	# cannot obstruct the interaction ray before it reaches this target.
	var target := CollisionShape3D.new()
	target.name = "DumpTarget"
	var bounds := BoxShape3D.new()
	bounds.size = Vector3(2.05, 1.35, 1.65)
	target.shape = bounds
	target.position = Vector3(0, 1.14, 0.05)
	add_child(target)

	# Four physical walls and a recessed bottom leave the top visibly open.
	# Props puts furniture on the world layer, blocking player and pearl bodies.
	var steel := Color(0.20, 0.29, 0.25)
	Props.box(self, Vector3(0, 0.13, 0), Vector3(2.0, 0.22, 1.5), steel)
	Props.box(self, Vector3(-0.94, 0.76, 0), Vector3(0.12, 1.25, 1.5), steel)
	Props.box(self, Vector3(0.94, 0.76, 0), Vector3(0.12, 1.25, 1.5), steel)
	Props.box(self, Vector3(0, 0.76, -0.69), Vector3(1.8, 1.25, 0.12), steel)
	Props.box(self, Vector3(0, 0.76, 0.69), Vector3(1.8, 1.25, 0.12), steel)
	Props.box(self, Vector3(0, 0.255, 0), Vector3(1.75, 0.025, 1.20), Color(0.065, 0.08, 0.07), false)
	var rim := Color(0.68, 0.49, 0.14)
	Props.box(self, Vector3(-0.96, 1.40, 0), Vector3(0.18, 0.10, 1.56), rim, false)
	Props.box(self, Vector3(0.96, 1.40, 0), Vector3(0.18, 0.10, 1.56), rim, false)
	Props.box(self, Vector3(0, 1.40, -0.72), Vector3(1.9, 0.10, 0.15), rim, false)
	Props.box(self, Vector3(0, 1.40, 0.72), Vector3(1.9, 0.10, 0.15), rim, false)
	Props.sign_at(self, "FOAM WASTE\nQ / EMPTY FOAM", Vector3(0, 2.03, 0.12))
	var lamp := OmniLight3D.new()
	lamp.name = "WasteMarkerLight"
	lamp.position = Vector3(0, 2.15, 0.25)
	lamp.light_color = Color(1.0, 0.69, 0.3)
	lamp.light_energy = 0.65
	lamp.omni_range = 3.5
	add_child(lamp)
