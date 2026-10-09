extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	var world: Node3D = load("res://Main.tscn").instantiate()
	root.add_child(world)
	world.menus.start_shift()
	world.intro.complete()
	world.player.set_physics_process(false)
	var station: Station = world.get_node("WashingStation")
	station.manual_flow_remaining = 0.2
	station._physics_process(0.01)
	check(station.basin_art.visible and station.basin_art.spray.emitting, "Manual sink has water before purchasing automation")
	station._physics_process(0.3)
	station._physics_process(0.01)
	check(not station.basin_art.spray.emitting, "Tap stops after washing stops")
	var purchase: AudioStreamPlayer = world.audio.voices.purchase
	world.menus.show_pause()
	world.menus.pause_upgrades()
	world.manager.credits = 0
	purchase.stop()
	check(not world.manager.buy_upgrade("bucket") and not purchase.playing, "Rejected purchase must stay silent")
	world.manager.credits = 1000
	check(world.manager.buy_upgrade("bucket"), "Paused shop purchase succeeds")
	world.audio._process(0.01)
	check(purchase.playing, "Paused shop must not cut purchase sound")
	world.shop.close_store()
	world.menus.resume()
	world.manager.buy_upgrade("auto_washer")
	station._physics_process(0.01)
	check(not station.basin_art.visible and station.washer_art.visible, "Automation swaps sink visuals without duplicate props")
	world.manager.running = false
	world.audio._process(0.01)
	check(not purchase.playing, "Shift end stops voices")
	var bgm: AudioStreamWAV = preload("res://scripts/AmbientMusic.gd").cached_loop
	check(bgm != null and is_equal_approx(bgm.get_length(), 12.0), "BGM has complete 80BPM four-bar loop")
	for id in world.audio.voices:
		var clip: AudioStreamWAV = world.audio.voices[id].stream
		var peak := 0
		for i in range(0, clip.data.size(), 2):
			peak = maxi(peak, absi(clip.data.decode_s16(i)))
		check(peak > 0 and peak < 32767, "Non-silent unclipped SFX: " + id)
	bgm.save_to_wav("res://.runtime/lofi-preview.wav")
	(purchase.stream as AudioStreamWAV).save_to_wav("res://.runtime/purchase-preview.wav")
	world.queue_free()
	await process_frame
	print("AUDIO/WASH QA: %d failures" % failures)
	quit(1 if failures else 0)
