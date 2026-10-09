extends Node
## Soft procedural SFX: low-pass noise plus low fundamentals, no sharp ringing.
var world: Node3D
var voices: Dictionary = {}
var manual_wash_remaining := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for id in ["blower", "vacuum", "wash", "dig", "dump", "pickup", "drop", "uv", "radio", "alarm", "purchase"]:
		var voice := AudioStreamPlayer.new()
		voice.name = id
		voice.bus = "SFX"
		voice.volume_db = -22.0
		voice.stream = make_clip(id, id in ["blower", "vacuum", "wash"])
		add_child(voice)
		voices[id] = voice

func make_clip(id: String, looping: bool) -> AudioStreamWAV:
	var rate := 22050
	var count := rate if looping else int(rate * (0.48 if id == "purchase" else 0.24))
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var random := RandomNumberGenerator.new()
	random.seed = hash(id)
	var filtered := 0.0
	var frequency := 90.0 if id == "vacuum" else 130.0
	for i in range(count):
		filtered = lerpf(filtered, random.randf_range(-1, 1), 0.045)
		var t := float(i) / rate
		var envelope := 1.0 if looping else sin(PI * float(i) / count)
		# Loop endpoints fade to silence to prevent clicks at the buffer boundary.
		envelope *= minf(1.0, minf(i, count - i - 1) / 128.0)
		var sample := (filtered * 1.5 + sin(TAU * frequency * t) * 0.15) * envelope
		match id:
			"blower": sample = filtered * (1.8 + 0.25 * sin(TAU * 3 * t)) * envelope
			"vacuum": sample = (sin(TAU * 90 * t) * 0.22 + sin(TAU * 180 * t) * 0.06 + filtered * 0.45) * envelope
			"wash": sample = filtered * (1.1 + 0.7 * sin(TAU * 7 * t) * sin(TAU * 11 * t)) * envelope
			"uv": sample = (filtered * 2.0 + sin(TAU * 260 * t) * 0.10) * exp(-t * 60) * envelope
			"dig": sample = filtered * 2.5 * exp(-t * 9) * envelope
			"dump": sample = (filtered * 2.0 + sin(TAU * 70 * t) * 0.16) * envelope
			"purchase":
				# Two damped coin notes without a piercing, sustained ring.
				var second := maxf(0.0, t - 0.12)
				sample = sin(TAU * 330 * t) * exp(-t * 24) * 0.35
				if t >= 0.12:
					sample += (sin(TAU * 440 * second) + 0.18 * sin(TAU * 660 * second)) * exp(-second * 20) * 0.30
				sample *= minf(1.0, t / 0.005)
		bytes.encode_s16(i * 2, int(clampf(sample, -1, 1) * 22000))
	var clip := AudioStreamWAV.new()
	clip.format = AudioStreamWAV.FORMAT_16_BITS
	clip.mix_rate = rate
	clip.data = bytes
	if looping:
		clip.loop_mode = AudioStreamWAV.LOOP_FORWARD
		clip.loop_end = count
	return clip

func one_shot(id: String) -> void:
	if voices.has(id):
		voices[id].play()

func _process(delta: float) -> void:
	var enabled: bool = world.manager != null and world.manager.running and not get_tree().paused
	var using_tool: bool = enabled and not world.player.store_open and world.player.held == null and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_action_pressed("brush")
	var washer := world.get_node_or_null("WashingStation") as Station
	set_loop("blower", using_tool and world.player.tools.selected_tool == Tools.Tool.BLOWER)
	set_loop("vacuum", using_tool and world.player.tools.selected_tool == Tools.Tool.VACUUM and world.player.bucket_load < world.player.bucket_capacity())
	set_loop("wash", enabled and washer != null and (washer.washing_item != null or manual_wash_remaining > 0.0))
	manual_wash_remaining = maxf(0.0, manual_wash_remaining - delta)
	if not enabled:
		for id in voices:
			# The paused shop can complete purchases; retain its one-shot feedback.
			if id != "purchase" or not world.manager.running:
				voices[id].stop()

func on_upgrade_bought(_id: String) -> void:
	one_shot("purchase")

func set_loop(id: String, enabled: bool) -> void:
	var voice: AudioStreamPlayer = voices[id]
	if enabled and not voice.playing:
		voice.play()
	elif not enabled:
		voice.stop()
