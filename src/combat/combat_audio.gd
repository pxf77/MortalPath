class_name CombatAudio
extends Node
## Offline CC0 sample pack. Source archives/recipes live in MortalPath-Art.
## Preloads keep all cues in exported builds; gameplay never reads the source repo.

const VOICE_LIMIT := 8
const PACK_ID := "mortalpath_cc0_m1_v0_1"
const CUES := {
	&"attack": [preload("res://assets/audio/cc0_m1/attack_01.wav"), preload("res://assets/audio/cc0_m1/attack_02.wav"), preload("res://assets/audio/cc0_m1/attack_03.wav")],
	&"sword_art": [preload("res://assets/audio/cc0_m1/sword_art.wav")],
	&"guard_cast": [preload("res://assets/audio/cc0_m1/guard_cast.wav")],
	&"dodge": [preload("res://assets/audio/cc0_m1/dodge.wav")],
	&"hit": [preload("res://assets/audio/cc0_m1/hit.wav")],
	&"hurt": [preload("res://assets/audio/cc0_m1/hurt.wav")],
	&"guard": [preload("res://assets/audio/cc0_m1/guard.wav")],
	&"evade": [preload("res://assets/audio/cc0_m1/evade.wav")],
	&"break": [preload("res://assets/audio/cc0_m1/break.wav")],
	&"death": [preload("res://assets/audio/cc0_m1/death.wav")],
	&"guardian_spell": [preload("res://assets/audio/cc0_m1/guardian_spell.wav")],
	&"talisman_cast": [preload("res://assets/audio/cc0_m1/talisman_cast.wav")],
	# Generic fallback and element samples are reserved; not new player abilities.
	&"enemy_spell": [preload("res://assets/audio/cc0_m1/enemy_spell.wav")],
	&"spell_fire": [preload("res://assets/audio/cc0_m1/spell_fire.wav")],
	&"spell_ice": [preload("res://assets/audio/cc0_m1/spell_ice.wav")],
	&"spell_lightning": [preload("res://assets/audio/cc0_m1/spell_lightning.wav")],
	&"spell_wind": [preload("res://assets/audio/cc0_m1/spell_wind.wav")],
	&"spell_earth": [preload("res://assets/audio/cc0_m1/spell_earth.wav")],
}
const GAIN_DB := {
	&"attack": -16.0, &"sword_art": -15.0, &"guard_cast": -18.0,
	&"dodge": -20.0, &"hit": -17.0, &"hurt": -14.0,
	&"guard": -17.0, &"evade": -21.0, &"break": -14.0,
	&"death": -18.0, &"enemy_spell": -18.0, &"guardian_spell": -18.0,
	&"talisman_cast": -18.0,
}

var muted := false
var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0


func _ready() -> void:
	for index in range(VOICE_LIMIT):
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		_voices.append(voice)


static func stream_for(cue: StringName, combo_step: int = 0) -> AudioStreamWAV:
	if not CUES.has(cue):
		return null
	var variants: Array = CUES[cue]
	return variants[clampi(combo_step - 1, 0, variants.size() - 1)] as AudioStreamWAV


func play_cue(cue: StringName, combo_step: int = 0) -> void:
	if muted or _voices.is_empty():
		return
	var stream := stream_for(cue, combo_step)
	if stream == null:
		return
	# Reuse an idle voice first. Once full, steal in bounded round-robin order.
	for offset in range(VOICE_LIMIT):
		var candidate := (_next_voice + offset) % VOICE_LIMIT
		if not _voices[candidate].playing:
			_next_voice = candidate
			break
	var voice := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % VOICE_LIMIT
	voice.stop()
	voice.stream = stream
	voice.volume_db = minf(-14.0, float(GAIN_DB.get(cue, -18.0)))
	voice.pitch_scale = 1.0 # Variants are authored; don't shift unrelated cues.
	# Dummy/headless servers do not drain playback objects during fast fixed-fps tests.
	# Keep resource selection/gain testable there; real mixing is a graphical gate.
	if DisplayServer.get_name() != "headless":
		voice.play()


func set_muted(value: bool) -> void:
	muted = value
	if muted:
		for voice in _voices:
			voice.stop()


func _exit_tree() -> void:
	# Scene restarts must not leave a tail or queued playback owning the sample.
	for voice in _voices:
		voice.stop()
		voice.stream = null
