class_name IntroCutscene
extends Node3D
## An AnimationPlayer camera pan and necklace scatter; no character rig required.
signal finished
@export var duration: float = 11.0
var player: Player
var barn: Node3D
var pearls: Array[Pearl] = []
var camera: Camera3D
var animator: AnimationPlayer
var overlay: CanvasLayer
var caption: Label
var finished_once: bool = false
var snap_played: bool = false
var snap: AudioStreamPlayer
var proxies: Node3D
var pallet_start: Vector3

func _ready() -> void:
	# Dependencies are injected by Main before add_child().
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.fov = 68
	add_child(camera)
	animator = AnimationPlayer.new()
	animator.name = "AnimationPlayer"
	add_child(animator)
	animator.animation_finished.connect(_on_animation_finished)
	proxies = Node3D.new()
	proxies.name = "Necklace"
	add_child(proxies)
	pallet_start = barn.pallet.position
	snap = AudioStreamPlayer.new()
	snap.stream = SoundBank.tone(110, 0.18)
	snap.volume_db = -18
	add_child(snap)
	build_overlay()
	build_animation()
	proxies.hide()

func build_overlay() -> void:
	overlay = CanvasLayer.new()
	overlay.layer = 10
	add_child(overlay)
	for bottom in [false, true]:
		var bar := ColorRect.new()
		overlay.add_child(bar)
		bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE if bottom else Control.PRESET_TOP_WIDE)
		bar.offset_top = -115 if bottom else 0
		bar.offset_bottom = 0 if bottom else 70
		bar.color = Color(0.005, 0.009, 0.015, 0.94)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption = Label.new()
	overlay.add_child(caption)
	caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	caption.offset_top = -100
	caption.offset_bottom = -15
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 22)
	var heading := Label.new()
	heading.text = "02:13 AM  /  PACKING WAREHOUSE                                      SPACE · skip intro"
	heading.position = Vector2(28, 22)
	overlay.add_child(heading)

func add_keys(animation: Animation, path: NodePath, times: Array, values: Array) -> void:
	var track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, path)
	for index in range(times.size()):
		animation.track_insert_key(track, times[index], values[index])

func view_rotation(at: Vector3, target: Vector3) -> Vector3:
	return Transform3D(Basis.IDENTITY, at).looking_at(target, Vector3.UP).basis.get_euler()

func build_animation() -> void:
	var clip := Animation.new()
	clip.length = maxf(duration, 9.0)
	var views := [Vector3(9, 6.5, 9.5), Vector3(0.35, 6.4, 1.2), Vector3(0.55, 6.3, 1.4), Vector3(0, 5.7, 6.8), player.camera.global_position]
	var times := [0.0, 2.8, 3.2, 7.5, clip.length]
	var rotations: Array = []
	for index in range(views.size()):
		rotations.append(view_rotation(views[index], Vector3(0, 5.3, -1.6) if index < 3 else Vector3(0, 2.0, -1.6)))
	# End on precisely the gameplay camera pose to avoid a jarring cut.
	rotations[rotations.size() - 1] = player.camera.global_rotation
	add_keys(clip, ^"Camera3D:position", times, views)
	add_keys(clip, ^"Camera3D:rotation", times, rotations)
	# A small pallet jolt and camera lurch sell the first-person accidental bump.
	add_keys(clip, NodePath(str(get_path_to(barn.pallet)) + ":position"), [0.0, 2.85, 3.15, clip.length], [pallet_start, pallet_start, pallet_start + Vector3(0, 0, 0.16), pallet_start + Vector3(0, 0, 0.16)])
	var strand := MeshInstance3D.new()
	strand.name = "Strand"
	var ring := TorusMesh.new()
	ring.inner_radius = 0.42
	ring.outer_radius = 0.435
	strand.mesh = ring
	strand.material_override = Props.material(Color(0.71, 0.51, 0.24), 0.7)
	strand.position = Vector3(0, 5.5, -1.6)
	strand.rotation.x = PI / 2.0
	strand.scale.z = 0.33
	proxies.add_child(strand)
	add_keys(clip, ^"Necklace/Strand:visible", [0.0, 3.0], [true, false])
	clip.value_track_set_update_mode(clip.get_track_count() - 1, Animation.UPDATE_DISCRETE)
	for index in range(pearls.size()):
		var bead := MeshInstance3D.new()
		bead.name = "Bead%d" % index
		var mesh := SphereMesh.new()
		mesh.radius = 0.075
		mesh.height = 0.15
		bead.mesh = mesh
		bead.material_override = Props.material(Color(1.0, 0.92, 0.78), 0.25)
		proxies.add_child(bead)
		var angle := TAU * index / pearls.size()
		var start := Vector3(cos(angle) * 0.43, 5.5 + sin(angle) * 0.14, -1.6)
		var destination := to_local(pearls[index].global_position)
		var apex := start.lerp(destination, 0.5) + Vector3(0, 1.0 + index * 0.03, 0)
		add_keys(clip, NodePath("Necklace/Bead%d:position" % index), [0.0, 3.0, 3.55 + index * 0.025, 4.6 + index * 0.05], [start, start, apex, destination])
	var library := AnimationLibrary.new()
	library.add_animation("intro", clip)
	animator.add_animation_library("", library)

func play() -> void:
	proxies.show()
	overlay.show()
	camera.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	animator.play("intro")

func _process(_delta: float) -> void:
	if finished_once or not animator.is_playing():
		return
	var time := animator.current_animation_position
	if time < 2.85:
		caption.text = "The night shift should have been quiet.\nThe boss's valuables and crucial machine parts are missing."
	elif time < 5.5:
		caption.text = "A pallet tips. The necklace snaps.\nEverything disappears into the packaging foam."
	else:
		caption.text = "Fifteen minutes until morning rounds. No tools, no credits.\nDig by hand, dump foam, buy equipment. Find, rinse and return every item."
		if player.manager.is_hardcore():
			caption.text = "Ten minutes. Bare hands only. The supply desk is closed.\nDig, carry, rinse by hand and return every item before the boss arrives."
	if time >= 3.0 and not snap_played:
		snap_played = true
		snap.play()

func _unhandled_input(event: InputEvent) -> void:
	if not finished_once and animator.is_playing() and event.is_action_pressed("skip_intro"):
		get_viewport().set_input_as_handled()
		complete()

func _on_animation_finished(animation_name: StringName) -> void:
	if animation_name == &"intro":
		complete()

func complete() -> void:
	# One path for natural finish and skip, including cleanup and camera restoration.
	if finished_once:
		return
	finished_once = true
	animator.stop()
	snap.stop()
	proxies.hide()
	overlay.hide()
	barn.pallet.position = pallet_start + Vector3(0, 0, 0.16)
	player.camera.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	finished.emit()

