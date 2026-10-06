class_name UpgradeStore
extends StaticBody3D
## A world-space interaction target. Prices and purchases belong to GameManager;
## the player's raycast simply opens UpgradeUI when it hits this body.

func _ready() -> void:
	collision_layer = 16 # Layer 5: stations and shop targets.
	collision_mask = 0
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.1, 1.25, 1.05)
	collider.shape = shape
	collider.position.y = 1.1
	add_child(collider)
	# World-layer furniture still blocks walking. Its interaction volume rises
	# above the desk so a standing player can easily select the supply terminal.
	Props.box(self, Vector3(0, 0.53, 0), Vector3(2.0, 1.06, 0.9), Color(0.2, 0.16, 0.11))
	Props.box(self, Vector3(0, 1.08, 0), Vector3(2.2, 0.1, 1.0), Color(0.11, 0.14, 0.15))
	Props.box(self, Vector3(0, 1.32, -0.2), Vector3(0.82, 0.43, 0.12), Color(0.035, 0.1, 0.11), false)
	var screen := Props.box(self, Vector3(0, 1.33, -0.126), Vector3(0.71, 0.32, 0.025), Color(0.22, 0.76, 0.59), false)
	var screen_material := (screen.get_child(0) as MeshInstance3D).material_override as StandardMaterial3D
	screen_material.emission_enabled = true
	screen_material.emission = Color(0.14, 0.6, 0.36)
	screen_material.emission_energy_multiplier = 1.3
	Props.sign_at(self, "NIGHT SHIFT SUPPLIES\nE / BUY TOOLS", Vector3(0, 2.05, -0.27))
	var lamp := OmniLight3D.new()
	lamp.name = "TerminalGlow"
	lamp.position = Vector3(0, 1.6, 0.1)
	lamp.light_color = Color(0.4, 0.9, 0.65)
	lamp.light_energy = 0.45
	lamp.omni_range = 3.0
	add_child(lamp)
