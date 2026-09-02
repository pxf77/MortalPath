extends SceneTree
## Developer audition, not a gameplay/progression test. Uses real runtime gain.
## godot --path . --fixed-fps 60 --write-movie build/audio/audition.avi --script res://tests/audio_audition.gd

var _audio: CombatAudio
var _label: Label


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_audio = CombatAudio.new()
	root.add_child(_audio)
	var background := ColorRect.new()
	background.color = Color(0.07, 0.10, 0.11)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	_label = Label.new()
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 28)
	background.add_child(_label)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/cc0_m1/manifest.json"))
	var roles: Dictionary = {}
	for entry in manifest.cues:
		roles[entry.id] = entry
	await create_timer(0.5).timeout
	var count := 0
	for cue in CombatAudio.CUES:
		for variant in range(CombatAudio.CUES[cue].size()):
			var stream := CombatAudio.stream_for(cue, variant + 1)
			var id := stream.resource_path.get_file().get_basename()
			var entry: Dictionary = roles[id]
			count += 1
			_label.text = "MortalPath | CC0 初版音效试听\n\n%02d / 20 · %s\n\n%s\n\n%s\n\n实际游戏播放增益 · 人工听感待确认" % [count, id, entry.role, "已接入战斗" if entry.status == "integrated" else "预备素材：当前关卡未使用"]
			print("Audition: %s" % id)
			_audio.play_cue(cue, variant + 1)
			await create_timer(stream.get_length() + 0.65).timeout
	_audio.set_muted(true)
	_label.text = "试听完成 · 20 个成品\n\n来源、许可、SHA-256 与制作配方随音效库保存\n\n这不是新增符箓或元素玩法的演示"
	await create_timer(1.0).timeout
	quit()
