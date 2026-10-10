extends Node
## AudioManager — генерирует музыку и звуки ПРОГРАММНО (синтез), поэтому проекту
## не нужны бинарные аудиофайлы. Всё работает сразу после открытия в Godot 4.

var _players: Array[AudioStreamPlayer] = []
var _music_player: AudioStreamPlayer
var music_volume := 0.35
var sfx_volume := 0.6
var _music_timer := 0.0
var _current_track := ""

const SR := 22050

func _ready() -> void:
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Master"
	add_child(_music_player)

# ---------- Синтез ----------

func _tone(freq: float, dur: float, vol: float = 0.5, type: int = 0, attack: float = 0.01) -> AudioStreamSample:
	var n := int(SR * dur)
	var data := PackedFloat32Array()
	data.resize(n)
	for i in range(n):
		var t := float(i) / SR
		var env := clampf(minf(t / maxf(attack, 0.001), (dur - t) / 0.05), 0.0, 1.0)
		var phase := fposmod(freq * t, 1.0)
		var s := 0.0
		match type:
			0: s = sin(TAU * phase)                       # синус
			1: s = signf(sin(TAU * phase))                 # квадрат
			2: s = 2.0 * absf(2.0 * phase - 1.0) - 1.0     # пила
			3: s = randf_range(-1.0, 1.0)                  # шум
		data[i] = s * env * vol
	return _make_stream(data)

func _make_stream(data: PackedFloat32Array) -> AudioStreamSample:
	var pcm := PackedByteArray()
	pcm.resize(data.size() * 4)
	for i in range(data.size()):
		var v := clampi(int(data[i] * 32767.0), -32768, 32767)
		pcm.encode_s32(i * 4, v)
	var stream := AudioStreamSample.new()
	stream.format = AudioStreamSample.FORMAT_32_BITS
	stream.data = pcm
	stream.mix_rate = SR
	stream.stereo_interleave = AudioStreamSample.INTERLEAVE_LRLR
	return stream

func play_note(freq: float, dur: float, vol: float = 0.4, type: int = 0) -> void:
	if freq <= 0: return
	for p in _players:
		if not p.playing:
			p.stream = _tone(freq, dur, vol, type)
			p.volume_db = linear_to_db(sfx_volume * vol)
			p.play()
			return

# ---------- SFX ----------

func text_blip() -> void: play_note(560.0 + randf() * 120.0, 0.045, 0.22, 1)
func cursor_move() -> void: play_note(420.0, 0.06, 0.3, 0)
func confirm() -> void:
	play_note(523.25, 0.09, 0.4, 0)
	await get_tree().create_timer(0.08).timeout
	play_note(784.0, 0.12, 0.4, 0)
func cancel() -> void: play_note(200.0, 0.12, 0.35, 2)
func hurt() -> void:
	play_note(140.0, 0.18, 0.5, 3)
	play_note(90.0, 0.25, 0.4, 1)
func heal_sound() -> void:
	for f in [523.0, 659.0, 784.0]:
		play_note(f, 0.15, 0.35, 0)
		await get_tree().create_timer(0.07).timeout
func bullet_spawn() -> void: play_note(880.0, 0.05, 0.18, 0)
func boss_hit() -> void: play_note(110.0, 0.3, 0.5, 3)
func pickup() -> void:
	play_note(660.0, 0.08, 0.4, 0)
	await get_tree().create_timer(0.06).timeout
	play_note(990.0, 0.12, 0.4, 0)
func save_chime() -> void:
	for f in [784.0, 988.0, 1175.0, 1568.0]:
		play_note(f, 0.25, 0.3, 0)
		await get_tree().create_timer(0.09).timeout
func level_up_jingle() -> void:
	for f in [392.0, 523.0, 659.0, 784.0, 1046.0]:
		play_note(f, 0.2, 0.35, 0)
		await get_tree().create_timer(0.1).timeout
func death_sound() -> void:
	play_note(220.0, 0.6, 0.5, 1)
	await get_tree().create_timer(0.1).timeout
	play_note(110.0, 0.9, 0.5, 1)

# ---------- Музыка (простой секвенсор на основе процессора) ----------

var _seq_thread: Thread
var _seq_active := false
var _seq_track := ""

func play_music(track: String) -> void:
	if track == _current_track and _music_player.playing:
		return
	stop_music()
	_current_track = track
	var patterns := _get_pattern(track)
	if patterns.is_empty():
		return
	var stream := _render_pattern(patterns)
	_music_player.stream = stream
	_music_player.volume_db = linear_to_db(music_volume)
	_music_player.play()

func stop_music() -> void:
	_music_player.stop()
	_current_track = ""

func _render_pattern(pat: Dictionary) -> AudioStreamSample:
	var bpm: float = pat.get("bpm", 100.0)
	var beats: Array = pat.get("beats", [])
	var bass: Array = pat.get("bass", [])
	var lead_type: int = pat.get("lead_type", 0)
	var bass_type: int = pat.get("bass_type", 1)
	var spb := 60.0 / bpm                # секунд на бит
	var total_beats := maxi(len(beats), len(bass))
	var dur := spb * total_beats + 0.5
	var n := int(SR * dur)
	var data := PackedFloat32Array()
	data.resize(n * 2)
	var midi_to_hz := func(m: float) -> float: return 440.0 * pow(2.0, (m - 69.0) / 12.0)

	for i in range(n):
		var t := float(i) / SR
		var beat_f := t / spb
		var bi := int(floor(beat_f)) % maxi(len(beats), 1)
		var bs := int(floor(beat_f)) % maxi(len(bass), 1)
		var frac := beat_f - floor(beat_f)

		# мелодия
		var note_midi: float = beats[bi] if len(beats) > 0 else 0.0
		var s_lead := 0.0
		if note_midi > 0:
			var f := midi_to_hz.call(note_midi)
			var env := clampf(minf(frac * 12.0, (1.0 - frac) * 6.0), 0.0, 1.0)
			var ph := fposmod(f * t, 1.0)
			match lead_type:
				0: s_lead = sin(TAU * ph)
				1: s_lead = signf(sin(TAU * ph))
				2: s_lead = 2.0 * absf(2.0 * ph - 1.0) - 1.0
			s_lead *= env * 0.32

		# бас
		var b_midi: float = bass[bs] if len(bass) > 0 else 0.0
		var s_bass := 0.0
		if b_midi > 0:
			var fb := midi_to_hz.call(b_midi)
			var envb := clampf(minf(frac * 20.0, (1.0 - frac) * 4.0), 0.0, 1.0)
			var phb := fposmod(fb * t, 1.0)
			match bass_type:
				0: s_bass = sin(TAU * phb)
				1: s_bass = signf(sin(TAU * phb)) * 0.6
				2: s_bass = 2.0 * absf(2.0 * phb - 1.0) - 1.0
			s_bass *= envb * 0.22

		# лёгкий перкуссионный шум на слабые доли
		var s_drum := 0.0
		if fposmod(beat_f, 1.0) < 0.03:
			s_drum = randf_range(-1, 1) * (0.03 - fposmod(beat_f, 1.0)) / 0.03 * 0.12

		var mix := (s_lead + s_bass + s_drum) * 0.8
		data[i * 2] = mix
		data[i * 2 + 1] = mix
	return _make_stream(data)

func _get_pattern(track: String) -> Dictionary:
	match track:
		"title":
			return {
				"bpm": 90.0, "lead_type": 0, "bass_type": 0,
				# A минор: A4 C5 E5 G5 ...
				"beats": [69, 0, 72, 0, 76, 0, 79, 76, 72, 0, 76, 0, 81, 0, 79, 76,
				          69, 0, 72, 0, 76, 0, 79, 81, 84, 0, 81, 79, 76, 0, 72, 0],
				"bass": [45, 45, 52, 52, 48, 48, 55, 55, 45, 45, 52, 52, 53, 53, 55, 55],
			}
		"ruins":
			return {
				"bpm": 72.0, "lead_type": 0, "bass_type": 0,
				"beats": [57, 0, 60, 0, 64, 0, 60, 0, 55, 0, 59, 0, 62, 0, 59, 0,
				          57, 0, 60, 0, 64, 67, 64, 0, 62, 0, 65, 0, 69, 0, 65, 0],
				"bass": [33, 0, 40, 0, 36, 0, 43, 0, 33, 0, 40, 0, 38, 0, 45, 0],
			}
		"village":
			return {
				"bpm": 112.0, "lead_type": 2, "bass_type": 0,
				"beats": [64, 67, 64, 60, 62, 65, 62, 59, 60, 64, 67, 64, 69, 67, 64, 62,
				          64, 67, 64, 60, 62, 65, 67, 69, 71, 69, 67, 64, 62, 60, 57, 0],
				"bass": [40, 45, 40, 45, 38, 43, 38, 43, 40, 45, 40, 45, 43, 48, 43, 48],
			}
		"forest":
			return {
				"bpm": 96.0, "lead_type": 0, "bass_type": 2,
				"beats": [62, 0, 65, 0, 69, 0, 65, 67, 69, 0, 72, 0, 69, 0, 65, 0,
				          64, 0, 67, 0, 71, 0, 67, 69, 71, 0, 74, 0, 71, 0, 67, 0],
				"bass": [38, 38, 41, 41, 36, 36, 43, 43],
			}
		"lake":
			return {
				"bpm": 64.0, "lead_type": 0, "bass_type": 0,
				"beats": [76, 0, 0, 72, 0, 0, 69, 0, 0, 71, 0, 0, 74, 0, 0, 0,
				          76, 0, 0, 79, 0, 0, 76, 0, 0, 72, 0, 0, 69, 0, 0, 0],
				"bass": [45, 0, 0, 0, 41, 0, 0, 0, 43, 0, 0, 0, 40, 0, 0, 0],
			}
		"battle":
			return {
				"bpm": 140.0, "lead_type": 1, "bass_type": 1,
				"beats": [57, 57, 60, 57, 64, 57, 62, 57, 55, 55, 59, 55, 62, 55, 60, 55,
				          57, 57, 60, 57, 64, 67, 64, 62, 60, 59, 57, 55, 52, 55, 57, 0],
				"bass": [33, 33, 33, 33, 29, 29, 29, 29, 31, 31, 31, 31, 28, 28, 28, 28],
			}
		"boss":
			return {
				"bpm": 152.0, "lead_type": 2, "bass_type": 1,
				"beats": [69, 68, 69, 72, 69, 68, 69, 75, 74, 72, 74, 77, 74, 72, 74, 69,
				          69, 68, 69, 72, 74, 75, 77, 79, 81, 80, 79, 77, 75, 74, 72, 0],
				"bass": [33, 33, 34, 34, 33, 33, 31, 31, 33, 33, 34, 34, 36, 36, 33, 33],
			}
		"sad":
			return {
				"bpm": 58.0, "lead_type": 0, "bass_type": 0,
				"beats": [69, 0, 0, 67, 0, 0, 64, 0, 62, 0, 0, 60, 0, 0, 0, 0,
				          57, 0, 0, 60, 0, 0, 64, 0, 0, 62, 0, 0, 59, 0, 0, 0],
				"bass": [45, 0, 0, 0, 43, 0, 0, 0, 41, 0, 0, 0, 40, 0, 0, 0],
			}
		"hope":
			return {
				"bpm": 84.0, "lead_type": 0, "bass_type": 0,
				"beats": [60, 64, 67, 64, 60, 62, 65, 62, 57, 60, 64, 60, 62, 65, 69, 65,
				          67, 71, 74, 71, 69, 72, 76, 72, 74, 71, 69, 67, 64, 67, 69, 0],
				"bass": [36, 36, 41, 41, 33, 33, 40, 40, 38, 38, 43, 43, 40, 40, 45, 45],
			}
		"genocide":
			return {
				"bpm": 130.0, "lead_type": 1, "bass_type": 3,
				"beats": [45, 45, 45, 46, 45, 45, 48, 45, 45, 45, 45, 43, 45, 45, 42, 0,
				          45, 45, 45, 46, 45, 45, 51, 50, 49, 48, 47, 46, 45, 44, 43, 0],
				"bass": [33, 33, 33, 33, 33, 33, 33, 33, 33, 33, 33, 33, 33, 33, 33, 33],
			}
	return {}
