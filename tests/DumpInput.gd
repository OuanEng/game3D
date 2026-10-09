extends SceneTree
## Real-renderer integration check: headless DisplayServer cannot capture the
## mouse, so this input test runs graphically (without OS keyboard automation).
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	preload("res://scripts/StageManager.gd").selected_stage = 3
	var scene: Node3D = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	scene.menus.start_shift()
	scene.intro.complete()
	var player: Player = scene.player
	var waste: WasteBin = scene.get_node("WasteBin")
	player.position = waste.position + Vector3(0, 0, 2.2)
	player.rotation.y = PI # Look away; Q should work by proximity and clear path.
	await create_timer(0.15).timeout
	var failures := 0
	for stroke in range(3):
		player.bucket_load = player.bucket_capacity()
		var key := InputEventKey.new()
		key.physical_keycode = KEY_Q
		key.pressed = true
		Input.parse_input_event(key)
		await create_timer(0.08).timeout
		key.pressed = false
		Input.parse_input_event(key)
		await create_timer(0.05).timeout
		if player.bucket_load > 0.000001:
			failures += 1
			push_error("Q key failed to empty carry load %d" % stroke)
	print("Q INPUT RESULT: %d failures" % failures)
	quit(1 if failures > 0 else 0)
