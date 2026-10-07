extends AudioStreamPlayer
## Seamless 16-second mellow synth bed, generated once. Integer-cycle carriers
## and modulation close at the loop boundary. Low-pass removes bright harmonics.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	const RATE := 22050
	const SECONDS := 16
	var data := PackedByteArray()
	data.resize(RATE * SECONDS * 2)
	var filtered := 0.0
	for i in range(RATE * SECONDS):
		var t := float(i) / RATE
		var pad := 0.0
		for hz in [55.0, 82.5, 110.0, 130.8125, 164.8125]:
			pad += sin(TAU * hz * t) * (0.75 + 0.25 * sin(TAU * t / 16.0)) * 0.06
		var beat := pow(0.5 + 0.5 * cos(TAU * t * 1.0), 12.0) * sin(TAU * 45.0 * t) * 0.06
		filtered = lerpf(filtered, pad + beat, 0.09)
		# Boundary fade avoids filter-state discontinuity without a click.
		var fade := minf(1.0, minf(t, SECONDS - t) / 0.3)
		data.encode_s16(i * 2, int(filtered * fade * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = RATE * SECONDS
	stream = wav
	volume_db = -16
	play()
