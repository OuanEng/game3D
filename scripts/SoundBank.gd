class_name SoundBank
extends RefCounted
## Asset-free placeholders. Generate a small PCM clip once, never per audio frame.
static func tone(frequency: float, seconds: float, loop: bool = false) -> AudioStreamWAV:
	const RATE := 22050
	var count := int(seconds * RATE)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	for index in range(count):
		var time := float(index) / RATE
		var envelope := 1.0 if loop else minf(1.0, time / 0.008) * minf(1.0, (seconds - time) / 0.025)
		var sample := (sin(TAU * frequency * time) + 0.2 * sin(TAU * frequency * 2.0 * time)) * 0.35 * envelope
		bytes.encode_s16(index * 2, int(sample * 32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = bytes
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = count
	return stream
