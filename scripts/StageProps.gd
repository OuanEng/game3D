extends RefCounted
## Distinct stage silhouettes, confined to aisles outside terrain/service routes.
const Imported = preload("res://scripts/ImportedProps.gd")
const Art = preload("res://scripts/ToolArt.gd")
static func build(parent: Node3D, stage: int) -> void:
	var root := Node3D.new()
	root.name = "StageDecor"
	parent.add_child(root)
	var steel := Art.mat(Color(0.25,0.31,0.34),0.7)
	var yellow := Art.mat(Color(0.85,0.49,0.06))
	if stage == 1:
		build_salt_barn(root)
	elif stage == 2:
		build_construction(root)
		Imported.place(root, "crane", Vector3(5.0,0,-9.5), 3.0, true)
		Props.box(root, Vector3(8.5,0.65,-5), Vector3(2.0,1.1,2.8), Color(0.80,0.45,0.025))
		for x in [7.4,9.6]:
			for z in [-5.8,-4.2]:
				Art.tube(root, Vector3(x-0.12,0.45,z), Vector3(x+0.12,0.45,z),0.45,Art.mat(Color(0.04,0.045,0.05)))
		for x in [7.8,9.2]:
			Art.box(root,Vector3(x,2,-6),Vector3(0.12,3,0.15),steel)
			Art.box(root,Vector3(x,0.20,-7),Vector3(0.18,0.12,2),steel)
		Art.box(root,Vector3(8.5,3.5,-5),Vector3(2,0.15,2),yellow)
		Props.sign_at(root,"SAND PIT · HEAVY MATERIAL",Vector3(0,6,-10))
	elif stage == 3:
		for x in [-9,9]:
			for z in [-8,-4,0]:
				Props.box(root,Vector3(x,1.7,z),Vector3(2,3.4,2),Color(0.15,0.23,0.27))
		Imported.place(root, "machine", Vector3(0,0,-9.5), 2.7, true)
		Imported.place(root, "hopper-round", Vector3(5,0,-9.5), 2.3, true)
		Props.sign_at(root,"MASTER STORAGE · FINAL SHIFT",Vector3(0,6,-10))
	else:
		build_packing(root)
		Imported.place(root, "conveyor", Vector3(4,0,-2), 2.8, true)
		Props.sign_at(root,"TRAINING BAY · START HERE",Vector3(0,2.5,4))

static func sack(root: Node3D, at: Vector3, color: Color) -> void:
	var body := SphereMesh.new()
	body.radius = 0.45
	body.height = 1.1
	var bag := Art.mesh(root, body, at, Art.mat(color))
	bag.scale = Vector3(1, 0.7, 0.65)
	Art.tube(root, at + Vector3(0,0.32,0), at + Vector3(0,0.48,0), 0.10, Art.mat(Color(0.45,0.32,0.15)))

static func build_salt_barn(root: Node3D) -> void:
	var wood := ShaderMaterial.new()
	wood.shader = preload("res://shaders/SaltWood.gdshader")
	# Interior planks cover the structural shell; salt accumulates near the floor.
	for i in range(48):
		Art.box(root, Vector3(-11.75+i*0.5,4,-11.82),Vector3(0.47,8,0.08),wood)
		for side in [-1,1]:
			Art.box(root,Vector3(side*11.82,4,-11.75+i*0.5),Vector3(0.08,8,0.47),wood)
	var iron := Art.mat(Color(0.14,0.12,0.09),0.65)
	for side in [-1,1]:
		for z in [-7,-3,1]:
			var at := Vector3(side*9,0.65,z)
			Art.tube(root,at-Vector3(0,0.65,0),at+Vector3(0,0.65,0),0.55,wood)
			for y in [-0.45,0.45]:
				Art.ring(root,at+Vector3(0,y,0),0.56,0.035,iron)
			sack(root,at+Vector3(-side*0.95,-0.25,0.5),Color(0.79,0.72,0.52))
			# Caged amber lantern, hung from a short chain.
			var lamp_at := Vector3(side*8,3.4,z)
			Art.tube(root,lamp_at+Vector3(0,0.3,0),lamp_at+Vector3(0,1.5,0),0.02,iron)
			Art.box(root,lamp_at,Vector3(0.25,0.4,0.25),Art.mat(Color(1,0.59,0.18),0,1.1))
			for x in [-0.16,0.16]:
				Art.tube(root,lamp_at+Vector3(x,-0.25,0),lamp_at+Vector3(x,0.25,0),0.025,iron)
			var light := OmniLight3D.new()
			light.position = lamp_at
			light.light_color = Color(1,0.61,0.26)
			light.light_energy = 2.2
			light.omni_range = 7
			root.add_child(light)
	# Hopper, grinding drum and crank form a coarse salt mill.
	Art.box(root,Vector3(7.5,0.65,-8),Vector3(1.4,1.3,1.1),wood)
	Art.tube(root,Vector3(7.5,1.3,-8),Vector3(7.5,2,-8),0.45,iron)
	Art.tube(root,Vector3(7.5,1.7,-8),Vector3(8.3,1.7,-8),0.055,iron)
	Art.tube(root,Vector3(8.3,1.7,-8),Vector3(8.3,2,-8),0.06,iron)
	Props.sign_at(root,"RUSTIC SALT BARN",Vector3(0,6,-10))

static func build_construction(root: Node3D) -> void:
	var steel := Art.mat(Color(0.48,0.54,0.58),0.7)
	var timber := Art.mat(Color(0.54,0.38,0.19))
	for z in [-8,-4,0]:
		for x in [-10.5,-8]:
			Art.tube(root,Vector3(x,0,z),Vector3(x,5,z),0.065,steel)
		for y in [1.8,3.6]:
			Art.box(root,Vector3(-9.25,y,z),Vector3(2.8,0.12,1.2),timber)
		Art.tube(root,Vector3(-10.5,0,z),Vector3(-8,3.6,z),0.035,steel)
	for i in range(5):
		var at := Vector3(-6.7+i*1.8,0.025,4.2)
		if Imported.place(root, "cone", at, 0.7) != null:
			continue
		Art.box(root,at,Vector3(0.48,0.06,0.48),Art.mat(Color(0.09,0.10,0.11)))
		var cone := CylinderMesh.new()
		cone.top_radius = 0.04
		cone.bottom_radius = 0.19
		cone.height = 0.65
		Art.mesh(root,cone,at+Vector3(0,0.35,0),Art.mat(Color(1,0.24,0.035)))
		Art.ring(root,at+Vector3(0,0.38,0),0.115,0.04,Art.mat(Color.WHITE))
	for i in range(6):
		sack(root,Vector3(-9+(i%2)*0.8,0.4+(i/2)*0.55,2),Color(0.65,0.66,0.59))
	for i in range(3):
		var at := Vector3(7.6+i*0.5,0.2,2)
		Art.box(root,at,Vector3(0.35,0.08,0.48),steel)
		Art.tube(root,at,at+Vector3(0,1.7,0.3),0.035,timber)

static func build_packing(root: Node3D) -> void:
	var card := Art.mat(Color(0.68,0.43,0.21))
	var tape := Art.mat(Color(0.93,0.77,0.44))
	for side in [-1,1]:
		for i in range(4):
			var at := Vector3(side*(7.8+(i%2)*1.0),0.45+(i/2)*0.9,-3)
			if Imported.place(root, "box-large", at - Vector3(0,0.425,0), 0.9) == null:
				Art.box(root,at,Vector3(0.9,0.85,0.9),card)
			Art.box(root,at+Vector3(0,0.43,0),Vector3(0.13,0.015,0.9),tape)
		Art.ring(root,Vector3(side*8,1.9,-3),0.20,0.07,tape)
