extends Node3D
## Conveyor dressing and low-count CPU effects, compatible with the web renderer.
const Art = preload("res://scripts/ToolArt.gd")
var jets: Array[CPUParticles3D] = []
var slats: Array[MeshInstance3D] = []
var bubbles: Array[MeshInstance3D] = []
var motion := 0.0

func _ready() -> void:
	var steel := Art.mat(Color(0.42, 0.49, 0.51), 0.8)
	var rubber := Art.mat(Color(0.025, 0.045, 0.045))
	Art.box(self, Vector3(0, 0.025, 0), Vector3(1.15, 0.07, 0.65), rubber)
	for side in [-1, 1]:
		Art.tube(self, Vector3(side * 0.54, 0.08, -0.32), Vector3(side * 0.54, 0.08, 0.32), 0.06, steel)
		Art.tube(self, Vector3(0, 0.05, side * 0.33), Vector3(0, 0.65, side * 0.33), 0.023, steel)
	Art.tube(self, Vector3(0, 0.65, -0.33), Vector3(0, 0.65, 0.33), 0.025, steel)
	for i in range(12):
		slats.append(Art.box(self, Vector3(-0.5 + i * 0.09, 0.07, 0), Vector3(0.012, 0.01, 0.6), steel))
	for z in [-0.18, 0.18]:
		Art.tube(self, Vector3(0, 0.65, z), Vector3(0, 0.58, z), 0.025, steel)
		var spray := CPUParticles3D.new()
		spray.position = Vector3(0, 0.58, z)
		spray.amount = 20
		spray.lifetime = 0.3
		spray.direction = Vector3.DOWN
		spray.spread = 12
		spray.gravity = Vector3(0, -3, 0)
		spray.initial_velocity_min = 0.6
		spray.initial_velocity_max = 1.0
		spray.scale_amount_min = 0.008
		spray.scale_amount_max = 0.016
		spray.color = Color(0.48, 0.81, 0.94)
		spray.mesh = SphereMesh.new()
		spray.emitting = false
		add_child(spray)
		jets.append(spray)
	for i in range(14):
		var sphere := SphereMesh.new()
		sphere.radius = 0.024 + (i % 3) * 0.008
		sphere.height = sphere.radius * 2
		sphere.radial_segments = 8
		sphere.rings = 4
		var bubble := Art.mesh(self, sphere, Vector3(sin(i * 2.3) * 0.3, 0.10, cos(i * 1.7) * 0.22), Art.mat(Color(0.85, 0.95, 0.97)))
		bubble.visible = false
		bubbles.append(bubble)

func update_washing(delta: float, active: bool) -> void:
	for spray in jets:
		spray.emitting = active and visible
	for bubble in bubbles:
		bubble.visible = active
	if not active:
		return
	motion += delta * 0.16
	for i in range(slats.size()):
		slats[i].position.x = fposmod(i * 0.09 + motion, 1.08) - 0.54
