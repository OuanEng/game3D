extends Node3D
## Decorative sink shares Station's interaction body. It never owns inventory.
const Art = preload("res://scripts/ToolArt.gd")
var water: MeshInstance3D
var spray: CPUParticles3D
var ripple_time := 0.0

func _ready() -> void:
	var steel := Art.mat(Color(0.52,0.63,0.68), 0.75)
	var inner := Art.mat(Color(0.20,0.31,0.36), 0.5)
	# Open bowl made from a recessed base and four rims, not a solid cube.
	Art.box(self, Vector3(0,0.035,0), Vector3(1.15,0.05,0.72), inner)
	for x in [-0.61,0.61]:
		Art.box(self, Vector3(x,0.13,0), Vector3(0.08,0.22,0.86), steel)
	for z in [-0.39,0.39]:
		Art.box(self, Vector3(0,0.13,z), Vector3(1.3,0.22,0.08), steel)
	water = Art.box(self, Vector3(0,0.075,0), Vector3(1.10,0.012,0.66), Art.mat(Color(0.16,0.48,0.60),0.25))
	Art.ring(self, Vector3(0,0.084,0), 0.06,0.014, inner)
	Art.tube(self, Vector3(0.42,0.16,-0.32), Vector3(0.42,0.65,-0.32),0.035,steel)
	Art.tube(self, Vector3(0.42,0.65,-0.32), Vector3(0.10,0.65,-0.06),0.035,steel)
	Art.tube(self, Vector3(0.10,0.65,-0.06), Vector3(0.10,0.54,-0.06),0.035,steel)
	Art.box(self, Vector3(0.42,0.30,-0.32),Vector3(0.2,0.04,0.06),steel)
	spray = CPUParticles3D.new()
	spray.name = "TapWater"
	spray.position = Vector3(0.10,0.53,-0.06)
	spray.amount = 28
	spray.lifetime = 0.35
	spray.direction = Vector3.DOWN
	spray.spread = 8
	spray.gravity = Vector3(0,-4,0)
	spray.initial_velocity_min = 0.7
	spray.initial_velocity_max = 1.0
	spray.scale_amount_min = 0.008
	spray.scale_amount_max = 0.015
	spray.mesh = SphereMesh.new()
	spray.color = Color(0.50,0.85,1)
	spray.emitting = false
	add_child(spray)

func update_water(delta: float, active: bool) -> void:
	spray.emitting = active and visible
	if active:
		ripple_time += delta
	water.position.y = 0.075 + (sin(ripple_time * 8) * 0.004 if active else 0.0)
