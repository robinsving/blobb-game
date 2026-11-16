extends SceneTree
## Checks every chapter's story.txt: parses cleanly, every line has Swedish, every @effect exists
## as an fx_<name> method in that chapter's level scripts, and every scene the code plays exists.
## Run: godot-flatpak --headless --path . --script res://tests/test_story.gd

var failures := 0


func _init() -> void:
	var dir := DirAccess.open("res://chapters")
	for ch in dir.get_directories():
		var base := "res://chapters/%s" % ch
		if not FileAccess.file_exists(base + "/story.txt"):
			continue
		_check_chapter(base)
	print("FAILED: %d" % failures if failures else "ALL TESTS PASSED")
	quit(1 if failures else 0)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
		print("FAIL: ", msg)


func _check_chapter(base: String) -> void:
	var story := StoryScript.load_file(base + "/story.txt")
	for e in story.errors:
		_check(false, e)
	# Level code is read as text: level scripts depend on autoloads, which --script mode lacks.
	var code := ""
	for f in DirAccess.get_files_at(base):
		if f.ends_with(".gd"):
			code += FileAccess.get_file_as_string(base + "/" + f) + "\n"
	for name in story.effect_names():
		_check(code.contains("func fx_%s(" % name), "%s: @%s has no func fx_%s() in the level code" % [base, name, name])
	var re := RegEx.create_from_string("story\\.play\\(\"([a-z0-9_]+)\"")
	for m in re.search_all(code):
		_check(story.has_scene(m.get_string(1)), "%s: code plays missing scene '%s'" % [base, m.get_string(1)])
	# trigger tables: {col: "scene"} in TRIGGERS
	var trig := RegEx.create_from_string("const TRIGGERS := \\{([^}]*)\\}")
	var tm := trig.search(code)
	if tm:
		for m in RegEx.create_from_string("\"([a-z0-9_]+)\"").search_all(tm.get_string(1)):
			_check(story.has_scene(m.get_string(1)), "%s: trigger scene '%s' missing" % [base, m.get_string(1)])
	if code.contains("\"fail_%d\""):
		for i in range(1, 5):
			_check(story.has_scene("fail_%d" % i), "%s: fail_%d missing" % [base, i])
	print("%s: %d scenes OK" % [base, story.scenes.size()])
