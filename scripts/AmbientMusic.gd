extends AudioStreamPlayer
## Four bars at 80 BPM with mellow extended chords, bass and swung brushes.
## Generated once per process; no external samples or synth plugin required.
static var cached_loop: AudioStreamWAV

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	bus = "BGM"
	if cached_loop == null:
		cached_loop = generate_loop()
	stream = cached_loop
	volume_db = -16
	play()

static func generate_loop() -> AudioStreamWAV:
	const RATE := 22050
	const SECONDS := 12
	const BEAT := 0.75
	const CHORDS := [[220.0,261.63,329.63,392.0], [146.83,174.61,220.0,261.63], [164.81,196.0,246.94,293.66], [220.0,261.63,329.63,392.0]]
	var data := PackedByteArray()
	data.resize(RATE * SECONDS * 2)
	var random := RandomNumberGenerator.new()
	random.seed = 7401
	var brush := 0.0
	var filtered := 0.0
	for i in range(RATE * SECONDS):
		var t := float(i) / RATE
		var bar := mini(3, int(t / (BEAT * 4)))
		var beat_index := int(t / BEAT)
		var phase := fmod(t, BEAT)
		var chord_phase := fmod(t, BEAT * 2)
		var pad := 0.0
		for hz in CHORDS[bar]:
			pad += (sin(TAU * hz * t) + 0.10 * sin(TAU * hz * 2 * t)) * 0.055
		pad *= minf(1.0, chord_phase / 0.025) * exp(-chord_phase * 1.1)
		var bass_hz: float = [55.0,73.415,82.405,55.0][bar]
		var bass := sin(TAU * bass_hz * t) * exp(-phase * 5.0) * minf(1.0, phase / 0.012) * 0.10
		var kick := sin(TAU * 48.0 * phase) * exp(-phase * 24.0) * 0.16 if beat_index % 2 == 0 else 0.0
		brush = lerpf(brush, random.randf_range(-1,1), 0.075)
		var snare := brush * exp(-phase * 20.0) * 0.30 if beat_index % 2 == 1 else 0.0
		var offbeat := maxf(0.0, phase - BEAT * 0.60)
		var shuffle := brush * exp(-offbeat * 45.0) * 0.15 if phase > BEAT * 0.60 else 0.0
		filtered = lerpf(filtered, pad + bass + kick + snare + shuffle, 0.12)
		var fade := minf(1.0, minf(t, SECONDS - t) / 0.08)
		data.encode_s16(i * 2, int(filtered * fade * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = RATE * SECONDS
	return wav
