class_name StoryScript
extends RefCounted
## Loads a chapter's dialogue script (e.g. chapters/ch1/story.txt) and plays its scenes.
##
## File format (see the header of any story.txt):
##   === name ===            starts a scene; "=== name (ambient) ===" = player keeps control
##   O: text / Y: text       older / younger narrator line (English)
##     sv: text              Swedish version of the line above
##     @effect [args...]     calls fx_<effect>(args...) on the level when the line above finishes typing
##     @hold N               extra wait (seconds) after the line above
##   @pause N                silence before the next line
##   # ...                   comment / stage direction (ignored)
##
## Usage in a level:
##   var story := StoryScript.load_file("res://chapters/ch1/story.txt")
##   await story.play("intro", self)

var path := ""
var scenes := {}   # name -> {"ambient": bool, "lines": Array[Dictionary]}
var errors: Array[String] = []


static func load_file(p: String) -> StoryScript:
	var s := StoryScript.new()
	s.path = p
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		s.errors.append("cannot open %s" % p)
		push_error(s.errors[-1])
		return s
	s._parse(f.get_as_text())
	for e in s.errors:
		push_error(e)
	return s


func has_scene(name: String) -> bool:
	return scenes.has(name)


## Plays a scene. Effects are resolved as fx_<name> methods on `level`.
func play(name: String, level: Object) -> void:
	if not scenes.has(name):
		push_error("%s: no scene '%s'" % [path, name])
		return
	var scene: Dictionary = scenes[name]
	var lines: Array = []
	for raw in scene["lines"]:
		var line: Dictionary = raw.duplicate()
		var fxs: Array = line.get("effects", [])
		line.erase("effects")
		if not fxs.is_empty():
			line["fx"] = func():
				for e in fxs:
					_run_effect(level, e)
		lines.append(line)
	# looked up at runtime (not the Narrator global) so this class also loads in headless tests
	var narrator: Node = (Engine.get_main_loop() as SceneTree).root.get_node("Narrator")
	await narrator.say(lines, not scene["ambient"])


func _run_effect(level: Object, e: Array) -> void:
	var method := "fx_" + String(e[0])
	if not is_instance_valid(level) or not level.has_method(method):
		push_error("%s: level has no %s()" % [path, method])
		return
	level.callv(method, e.slice(1))


## All effect names used by the script (for tests).
func effect_names() -> Array:
	var out := []
	for sc in scenes.values():
		for l in sc["lines"]:
			for e in l.get("effects", []):
				if not out.has(e[0]):
					out.append(e[0])
	return out


func _parse(text: String) -> void:
	var current: Dictionary = {}
	var last: Dictionary = {}
	var pending_pause := 0.0
	var n := 0
	for raw in text.split("\n"):
		n += 1
		var l := raw.strip_edges()
		if l == "" or l.begins_with("#"):
			continue
		var where := "%s:%d" % [path, n]
		if l.begins_with("==="):
			var name := l.trim_prefix("===").trim_suffix("===").strip_edges()
			var ambient := name.ends_with("(ambient)")
			name = name.trim_suffix("(ambient)").strip_edges()
			if scenes.has(name):
				errors.append("%s: duplicate scene '%s'" % [where, name])
			current = {"ambient": ambient, "lines": []}
			scenes[name] = current
			last = {}
			continue
		if current.is_empty():
			errors.append("%s: text outside a === scene ===" % where)
			continue
		if l.begins_with("O:") or l.begins_with("Y:"):
			last = {"who": l[0].to_lower(), "en": l.substr(2).strip_edges(), "sv": ""}
			if pending_pause > 0.0:
				last["pre"] = pending_pause
				pending_pause = 0.0
			current["lines"].append(last)
		elif l.begins_with("sv:"):
			if last.is_empty():
				errors.append("%s: sv: without a line above" % where)
			else:
				last["sv"] = l.substr(3).strip_edges()
		elif l.begins_with("@pause"):
			pending_pause = float(l.get_slice(" ", 1))
		elif l.begins_with("@hold"):
			if last.is_empty():
				errors.append("%s: @hold without a line above" % where)
			else:
				last["hold"] = float(l.get_slice(" ", 1))
		elif l.begins_with("@"):
			if last.is_empty():
				errors.append("%s: effect without a line above" % where)
			else:
				var parts := Array(l.substr(1).split(" ", false))
				if not last.has("effects"):
					last["effects"] = []
				last["effects"].append(parts)
		else:
			errors.append("%s: can't parse '%s'" % [where, l])
	for name in scenes:
		for line in scenes[name]["lines"]:
			if line["sv"] == "":
				errors.append("%s: scene '%s' line missing sv: \"%s\"" % [path, name, line["en"]])
