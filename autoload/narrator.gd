extends CanvasLayer
## The two storytellers. Shows typewriter text at the bottom of the screen:
## older narrator on the left (serif, warm), younger narrator on the right (hand-written, cool).
##
##   await Narrator.say(lines)             # blocking: locks player control, waits for "advance"
##   await Narrator.say(lines, false)      # ambient: player keeps control, lines auto-advance
##   Narrator.hint("text")                 # small control hint at the top of the screen
##
## Calls are queued, so overlapping say() calls play one after the other. While another scene
## is waiting in the queue, or Blobb stands at a StoryGate waiting for it, the one playing hurries
## (HURRY), so the story doesn't fall far behind.
## The "skip" key hurries a line along for players who read fast: the first press shows the whole
## line at once, the next one moves on (a blocking line too).

signal finished

const OLD_COLOR := Color(1.0, 0.92, 0.78)
const YOUNG_COLOR := Color(0.78, 0.92, 1.0)
const CPS := 42.0  # typed characters per second
const HURRY := 0.45  # pauses and reading time while another scene is queued up behind this one

var busy := false
var busy_blocking := false  # the scene being told locks the controls
var _generation := 0  # bumped by clear(); stale say() calls bail out
var _queue_ticket := 0
var _serving := 0
## Set by StoryGate while Blobb stands at a gate waiting for the scene: hurry it, as if one were queued.
var gate_waiting := false
var _band: TextureRect
var _old: Label
var _young: Label
var _old_icon: NarratorIcon
var _young_icon: NarratorIcon
var _arrow: Label
var _advance_event := false
var _taught_advance := false  # the first line that waits says which key moves the story on
var _hint: Label
## The controls legend that stays on screen in puzzle rooms (a Game.UI key, re-translated when
## the language or the input device changes).
var _legend: Label
var _legend_key := ""
var _legend_tween: Tween
var _hint_tween: Tween
var _band_tween: Tween
var _skip_typing := false
var _typing := false
var _skip_line := false  # the skip key was pressed: end this line's typing and waiting now
var _taught_skip := false
var _current := ""  # the line being shown, "O: …" / "Y: …" (for debug_state)


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS

	_band = TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0.8))
	g.set_color(1, Color(0, 0, 0, 0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 64
	_band.texture = gt
	_band.stretch_mode = TextureRect.STRETCH_SCALE
	_band.position = Vector2(0, 0)
	_band.size = Vector2(1920, 400)
	_band.modulate.a = 0.0
	_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_band)

	_old = _make_label(Fonts.serif(), 44, OLD_COLOR, Vector2(110, 44), HORIZONTAL_ALIGNMENT_LEFT)
	_young = _make_label(Fonts.hand(), 50, YOUNG_COLOR, Vector2(1920 - 110 - 1000, 168), HORIZONTAL_ALIGNMENT_RIGHT)

	# emblems: crescent moon = older narrator (left), round-edged star = younger narrator (right)
	_old_icon = NarratorIcon.new(NarratorIcon.Kind.MOON, OLD_COLOR)
	_old_icon.position = Vector2(110 - 64, 44 - 4)
	_old_icon.modulate.a = 0.0
	add_child(_old_icon)
	_young_icon = NarratorIcon.new(NarratorIcon.Kind.STAR, YOUNG_COLOR)
	_young_icon.position = Vector2(1920 - 110 + 10, 168 - 2)
	_young_icon.modulate.a = 0.0
	add_child(_young_icon)

	_arrow = Label.new()
	_arrow.text = "▾"
	_arrow.add_theme_font_size_override("font_size", 34)
	_arrow.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	_arrow.position = Vector2(1920 - 80, 300)
	_arrow.visible = false
	add_child(_arrow)

	_hint = Label.new()
	_hint.add_theme_font_override("font", Fonts.hand())
	_hint.add_theme_font_size_override("font_size", 38)
	_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	_hint.add_theme_constant_override("outline_size", 10)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.position = Vector2(0, 990)
	_hint.size = Vector2(1920, 60)
	_hint.pivot_offset = _hint.size * 0.5  # it grows and shrinks round its middle (see hint())
	_hint.modulate.a = 0.0
	add_child(_hint)

	_legend = Label.new()
	_legend.add_theme_font_override("font", Fonts.hand())
	_legend.add_theme_font_size_override("font_size", 28)
	_legend.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	_legend.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	_legend.add_theme_constant_override("outline_size", 8)
	_legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_legend.position = Vector2(0, 1032)
	_legend.size = Vector2(1920, 48)
	_legend.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var strip := StyleBoxFlat.new()  # a soft dark strip, so it reads on gravel and roofs alike
	strip.bg_color = Color(0.0, 0.0, 0.0, 0.42)
	_legend.add_theme_stylebox_override("normal", strip)
	_legend.modulate.a = 0.0
	add_child(_legend)
	Game.input_device_changed.connect(_refresh_legend)
	Game.locale_changed.connect(_refresh_legend)


func _make_label(font: Font, size: int, color: Color, pos: Vector2, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 3)
	l.add_theme_constant_override("shadow_outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.05, 0.85))
	l.add_theme_constant_override("outline_size", 9)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	l.position = pos
	l.size = Vector2(1000, 130)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


## Plays lines in order. Blocking narration locks player control until dismissed.
func say(lines: Array, blocking := true) -> void:
	var gen := _generation
	var ticket := _queue_ticket
	_queue_ticket += 1
	while _serving != ticket:
		await finished
	if gen != _generation:
		_serving += 1
		finished.emit()
		return
	busy = true
	busy_blocking = blocking
	if blocking:
		Game.control_locked = true
	_fade_band(1.0)
	for line in lines:
		if gen != _generation:
			break
		if line.has("pre"):
			await _wait(line["pre"])
			_skip_line = false  # a skip during a pause ends the pause, not the line after it
		await _type_line(line)
		if gen != _generation:
			break
		if line.has("fx"):
			var fx: Callable = line["fx"]
			if fx.is_valid():
				fx.call()
		if line.has("hold"):
			await _wait(line["hold"])
		if blocking and not Game.fast:
			_arrow.visible = true
			var teach := not _taught_advance
			if teach:
				hint(Game.t("hint_advance"), 600.0)  # stays until it's been pressed once
			await _wait_advance()
			if teach:
				_taught_advance = true
				hint_off()
			_arrow.visible = false
		else:
			if not _taught_skip and not Game.fast:
				_taught_skip = true
				hint(Game.t("hint_skip"), 5.0)
			await _wait(_read_time(line))
		_skip_line = false
	if gen == _generation:
		_fade_band(0.0)
		if blocking:
			Game.control_locked = false
	busy = false
	busy_blocking = false
	_serving += 1
	finished.emit()


## What is on screen now, for checks from outside (DebugState / gda): the line being shown, the
## hint and legend texts, and whether a blocking line is waiting for the advance key.
func debug_state() -> Dictionary:
	return {"line": _current if busy else "", "typing": _typing, "waiting": _arrow.visible, "hint": _hint.text if _hint.modulate.a > 0.05 else "",
		"legend": _legend.text if _legend_key != "" else ""}


## Immediately clears everything (used on scene change).
func clear() -> void:
	_generation += 1
	gate_waiting = false
	_old.text = ""
	_young.text = ""
	_band.modulate.a = 0.0
	_old_icon.modulate.a = 0.0
	_young_icon.modulate.a = 0.0
	_arrow.visible = false
	_skip_typing = true
	legend("")


## Shows a controls legend that stays until legend("") (or a scene change). Pass a Game.UI key.
func legend(key: String) -> void:
	_legend_key = key
	if _legend_tween:
		_legend_tween.kill()
	_refresh_legend()
	_legend_tween = create_tween()
	_legend_tween.tween_property(_legend, "modulate:a", 0.8 if key != "" else 0.0, 0.5)


func _refresh_legend() -> void:
	if _legend_key != "":
		_legend.text = Game.t(_legend_key)


func hint(text: String, dur := 5.0) -> void:
	if _hint_tween:
		_hint_tween.kill()
	_hint.text = text
	_hint_tween = create_tween()
	_hint_tween.tween_property(_hint, "modulate:a", 1.0, 0.4)
	_hint_tween.parallel().tween_method(_hint_pulse, 0.0, 1.0, 2.4)
	_hint_tween.tween_interval(maxf(dur - 2.0, 0.5))
	_hint_tween.tween_property(_hint, "modulate:a", 0.0, 0.8)


## A new hint calls for attention: it pops in, then grows and shrinks twice and settles. Only
## the text moves (nothing screen-wide), and only for a moment.
func _hint_pulse(k: float) -> void:
	var pop := 0.75 + 0.25 * ease(minf(k / 0.15, 1.0), 0.4)  # in from smaller
	var swell := sin(clampf((k - 0.15) / 0.85, 0.0, 1.0) * TAU * 2.0) * 0.07 * (1.0 - k)
	_hint.scale = Vector2.ONE * (pop + maxf(swell, -0.03))


func hint_off() -> void:
	if _hint_tween:
		_hint_tween.kill()
	_hint_tween = create_tween()
	_hint_tween.tween_property(_hint, "modulate:a", 0.0, 0.4)


func _type_line(line: Dictionary) -> void:
	var is_old: bool = line["who"] == "o"
	var lbl := _old if is_old else _young
	var other := _young if is_old else _old
	var icon := _old_icon if is_old else _young_icon
	var other_icon := _young_icon if is_old else _old_icon
	icon.modulate.a = 1.0
	icon.pop()
	# dim the other voice only if it is currently showing (not a faded line from an earlier scene)
	if other.modulate.a > 0.05 and other.text != "" and other_icon.modulate.a > 0.05:
		var dim := create_tween().set_parallel()
		dim.tween_property(other, "modulate:a", 0.38, 0.25)
		dim.tween_property(other_icon, "modulate:a", 0.38, 0.25)
	var text := Game.pick(line)
	_current = ("O: " if is_old else "Y: ") + text
	lbl.text = text
	lbl.visible_characters = 0
	lbl.modulate.a = 1.0
	_skip_typing = false
	_typing = true
	var n := text.length()
	var cps := CPS * (4.0 if Game.fast else 1.0) / (HURRY if _queued() else 1.0)
	var blip := "blip_old" if is_old else "blip_young"
	var i := 0
	var acc := 0.0
	while i < n:
		if _skip_typing:
			break
		acc += get_process_delta_time() * cps
		while acc >= 1.0 and i < n:
			acc -= 1.0
			var ch := text[i]
			i += 1
			lbl.visible_characters = i
			if i % 3 == 0 and ch != " ":
				Game.sfx(blip, -22.0, randf_range(0.92, 1.08))
			# small pauses after sentences and commas make the voices feel human
			var next := text[i] if i < n else " "
			if ch in [".", "?", "!", "…"] and next == " ":
				acc -= 7.0
			elif ch == "," :
				acc -= 3.5
		await get_tree().process_frame
	lbl.visible_characters = -1
	_typing = false


func _wait_advance() -> void:
	var gen := _generation
	await get_tree().create_timer(0.12).timeout
	_advance_event = false
	while gen == _generation:
		await get_tree().process_frame
		var pressed := Input.is_action_just_pressed("advance") or _advance_event or _skip_line
		_advance_event = false
		if pressed and not get_tree().paused:
			Game.sfx("blip_old", -20.0, 1.4)
			return


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("advance", false):
		_advance_event = true  # also caught as an event, so a press injected mid-frame (gda) counts
	if _typing and event.is_action_pressed("advance") and Game.control_locked:
		_skip_typing = true
	if busy and event.is_action_pressed("skip", false) and not get_tree().paused:
		if _typing:
			_skip_typing = true  # first press: the whole line at once, so it can still be read
		else:
			_skip_line = true  # then: on to the next line


func _read_time(line: Dictionary) -> float:
	if Game.fast:
		return 0.35
	return 1.4 + Game.pick(line).length() * 0.045


## Waits (pauses, reading time), cut short by the skip key, and shorter while scenes are queued.
func _wait(secs: float) -> void:
	if Game.fast:
		secs = minf(secs, 0.3)
	var t := 0.0
	while t < secs and not _skip_line:
		await get_tree().process_frame
		if not get_tree().paused:
			t += get_process_delta_time() / (HURRY if _queued() else 1.0)


## Someone is waiting for the scene playing: another say() queued behind it, or Blobb at a StoryGate.
func _queued() -> bool:
	return _queue_ticket - _serving > 1 or gate_waiting


func _fade_band(to: float) -> void:
	if _band_tween:
		_band_tween.kill()  # a new scene starting must cancel the previous scene's fade-out
	var tw := create_tween()
	_band_tween = tw
	tw.tween_property(_band, "modulate:a", to, 0.4)
	if to == 0.0:
		tw.parallel().tween_property(_old, "modulate:a", 0.0, 0.5)
		tw.parallel().tween_property(_young, "modulate:a", 0.0, 0.5)
		tw.parallel().tween_property(_old_icon, "modulate:a", 0.0, 0.5)
		tw.parallel().tween_property(_young_icon, "modulate:a", 0.0, 0.5)
