extends Node2D
## Chapter 3, part 3: the rooftop chase. Isometric view, Blobb running away from the camera
## (up and to the right on screen) across the roofs, on the beat.
##
## Everything is driven by one beat clock: Blobb's distance along the roofs IS the beat
## (z = beat * BEAT_LEN), so gaps always arrive on the beat, and when the tempo rises he runs faster.
## The beat starts as a drum (kick + hat) and slowly turns into a monitor beep, then speeds up.
## Only Y speaks (LINES, by beat). O is silent. At the end the roofs run out in front of a tall
## building with a lit sign; Y calls for help; white.
##
## World units: x = lane (-1, 0, 1), z = forward, h = height. Drawn in code (faux 3D), no sprites
## except the optional pigeon art from assets/gen/ch3/.

const ART := "res://assets/gen/ch3/"
const S := 118.0                          # pixels per world unit
const AX := Vector2(0.866, 0.5) * S        # +x (lane to Blobb's right): down-right on screen
const AZ := Vector2(0.866, -0.5) * S       # +z (forward): up-right
const AH := Vector2(0, -0.92) * S          # +h: up
const BEAT_LEN := 2.0
const ROOF_HALF := 1.65                    # roofs span x in [-1.65, 1.65]
const JUMP_BEATS := 0.9                    # a jump lasts this long, so it always covers ~one beat
const JUMP_PEAK := 1.15
const LANE_TIME := 0.12
const END_BEAT := 124
const BODY_R := 0.4
const CATCH := 0.6                         # dropped less than this below a roof's edge: he scrambles up
const RETELL_SECS := 1.1                   # the pause before he's back at the start of the roof
## beat -> scene (chapters/ch3/story.txt). Only Y.
const LINES := {2: "chase_go", 14: "chase_1", 28: "chase_2", 44: "chase_3", 58: "chase_4",
	72: "chase_5", 90: "chase_6", 106: "chase_7", 113: "chase_8"}
## From here to the end Blobb runs by himself: no control, straight down the middle, hopping the
## gaps, on roofs left clear so nothing stands between him and the hospital. Y: "What is
## happening?", about the real room now, not the story.
const AUTO_BEAT := 112
## The monitor beep is assets/audio/monitor.wav (tools/gen_monitor.py).

var fx: StyleFX
var camera: Camera2D
var _world: Node2D
var _buildings: Array = []   # {z0, z1, h, seed}
var _obstacles: Array = []   # {lane, z0, z1, top, kind}
var _dives: Array = []       # {lane, beat, done}
var _hospital := {}
var _beat := 0.0             # the clock: Blobb's progress, in beats
var _last_whole := -1
var _lane := 0
var _x := 0.0
var _h := 0.0
var _vh := 0.0
var _air := -1.0             # beats since take-off, or -1 on the ground
var _air_from := 0.0
var _falling := false
var _running := false
var _ended := false
var _fail_count := 0
var _retelling := false      # between a hit and the restart: the clock stops
var _checkpoint := 0.0
var _fired := {}
var _squash := 1.0
var _t := 0.0
var _ball: Texture2D
var _pigeon_tex: Texture2D
var _cam_extra := Vector2.ZERO
var _white := 0.0
var story := StoryScript.load_file("res://chapters/ch3/story.txt")


func _ready() -> void:
	Game.music("", 0.0, 2.0)
	_build_course()
	_ball = _make_ball()
	if ResourceLoader.exists(ART + "pigeon_fly.png"):
		_pigeon_tex = load(ART + "pigeon_fly.png")
	var back := CanvasLayer.new()
	back.layer = -10
	add_child(back)
	var sky := Node2D.new()
	sky.draw.connect(_draw_sky.bind(sky))
	back.add_child(sky)
	_world = Node2D.new()
	_world.draw.connect(_draw_world)
	add_child(_world)
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 4.0
	add_child(camera)
	fx = StyleFX.new()
	fx.set_look("real", 0.0)
	fx.tint(Color(0.6, 0.7, 1.0), 0.15, 0.0)
	add_child(fx)
	if Game.warp > 0:
		_beat = float(Game.warp)
		for b in LINES:
			if b < Game.warp:
				_fired[b] = true
		_checkpoint = _checkpoint_for(_beat)
		_beat = _checkpoint
	camera.position = _proj(0, _beat * BEAT_LEN + 3.0, 0)
	camera.reset_smoothing()
	_last_whole = floori(_beat)
	await get_tree().create_timer(0.8).timeout
	Narrator.hint(Game.t("hint_chase"), 6.0)
	_running = true


# ================================================================ course

## The roofs, chimneys, vents and the birds' dives. Built from a fixed seed, so it's the same run
## every time; it gets busier as it goes.
func _build_course() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	var b := -6.0
	var h := 0.0
	while b < END_BEAT:
		var length := float(rng.randi_range(5, 8)) if b > 8 else 14.0
		var z0 := b * BEAT_LEN
		_buildings.append({"z0": z0, "z1": (b + length) * BEAT_LEN - 0.9, "h": h, "seed": rng.randi()})
		# things on this roof, on whole beats, leaving the first two beats (the checkpoint) and the last clear
		var busy := clampf((b - 6.0) / 90.0, 0.15, 0.8)
		for k in range(2, int(length) - 1):
			var at := b + k
			if at < 6 or rng.randf() > busy:
				continue
			var lane := rng.randi_range(-1, 1)
			if rng.randf() < 0.55:
				_obstacles.append({"lane": lane, "z0": at * BEAT_LEN - 0.45, "z1": at * BEAT_LEN + 0.45, "top": h + 2.0, "kind": "chimney"})
			else:
				_obstacles.append({"lane": lane, "z0": at * BEAT_LEN - 0.3, "z1": at * BEAT_LEN + 0.3, "top": h + 0.45, "kind": "vent"})
		b += length
		# the next roof: a step up or down, or the same; up steps are small enough to jump
		h = clampf(h + [-0.5, 0.0, 0.0, 0.5][rng.randi_range(0, 3)], -1.0, 1.0)
	# from beat 20 the birds start diving at the lane Blobb is in (aimed when the shadow appears)
	var d := 20
	while d < END_BEAT - 4:
		_dives.append({"beat": float(d), "lane": 99, "done": false})
		d += rng.randi_range(5, 9) if d < 70 else rng.randi_range(3, 6)
	# the last run (Blobb on his own) is clear: nothing on the roofs, no birds
	_obstacles = _obstacles.filter(func(o): return o["z1"] < (AUTO_BEAT - 1) * BEAT_LEN)
	_dives = _dives.filter(func(dv): return dv["beat"] < AUTO_BEAT - 1)
	var last: Dictionary = _buildings[-1]
	last["z1"] = END_BEAT * BEAT_LEN + 2.0
	_hospital = {"z0": last["z1"] + 7.0, "z1": last["z1"] + 15.0, "top": 13.0}


func _roof_at(z: float) -> Variant:
	for bl in _buildings:
		if z >= bl["z0"] and z <= bl["z1"]:
			return bl
	return null


func _checkpoint_for(beat: float) -> float:
	var best := 0.0
	for bl in _buildings:
		var start: float = bl["z0"] / BEAT_LEN + 1.0
		if start <= beat - 1.0 and start > best:
			best = start
	return best


# ================================================================ the beat

func _bpm(b: float) -> float:
	if b < 36:
		return 100.0
	if b < 90:
		return lerpf(100.0, 128.0, (b - 36) / 54.0)
	return lerpf(128.0, 176.0, clampf((b - 90) / float(END_BEAT - 90), 0, 1))


## 0 = all drum, 1 = all monitor beep
func _morph(b: float) -> float:
	return clampf((b - 30.0) / 40.0, 0.0, 1.0)


func _on_beat(b: int) -> void:
	var m := _morph(b)
	if m < 0.98:
		Game.sfx("kick", lerpf(-3.0, -36.0, m))
	if m > 0.02:
		Game.sfx("monitor", lerpf(-36.0, -9.0, m))
	if LINES.has(b) and not _fired.has(b):
		_fired[b] = true
		story.play(LINES[b], self)


func _on_offbeat(b: int) -> void:
	var m := _morph(b)
	if m < 0.9:
		Game.sfx("hat", lerpf(-10.0, -34.0, m))


# ================================================================ per frame

func _process(delta: float) -> void:
	_t += delta
	# small steps, so a slow frame can't skip Blobb past a chimney or a roof edge
	var steps := ceili(delta / (1.0 / 120.0))
	for i in steps:
		if not _running or _retelling or _ended:
			break
		var dt := delta / steps
		var prev := _beat
		var db := dt * _bpm(_beat) / 60.0
		_beat += db
		_tick(prev, _beat, db)
		_move(dt, db)
	if _ended:
		_tick_end(delta)
	_squash = lerpf(_squash, 1.0, 0.15)
	_update_camera()
	_world.queue_redraw()


var _end_clock := 0.0
var _end_last := -1


func _tick(prev: float, now: float, _db: float) -> void:
	var w := floori(now)
	if w > _last_whole and now >= prev:
		_last_whole = w
		_on_beat(w)
	if floori(now - 0.5) != floori(prev - 0.5) and now > prev:
		_on_offbeat(w)


## After the roofs run out the beeps keep going, faster and faster, until the white.
func _tick_end(delta: float) -> void:
	if _white > 0.0:
		return
	_end_clock += delta * lerpf(176.0, 210.0, clampf(_end_clock / 8.0, 0, 1)) / 60.0
	var w := floori(_end_clock)
	if w != _end_last:
		_end_last = w
		Game.sfx("monitor", -8.0)


func _move(delta: float, db: float) -> void:
	var z := _beat * BEAT_LEN
	# lanes
	var auto := _beat >= AUTO_BEAT
	if auto:
		_lane = 0
		var here: Variant = _roof_at(z)
		var next: Variant = _roof_at(z + 0.5)
		if _air < 0.0 and not _falling and here != null and (next == null or next["h"] > here["h"] + 0.05):
			_take_off()  # he still clears the gaps, without looking
	elif not Game.control_locked:
		if Input.is_action_just_pressed("left"):
			_lane = maxi(_lane - 1, -1)
		elif Input.is_action_just_pressed("right"):
			_lane = mini(_lane + 1, 1)
		if Input.is_action_just_pressed("jump") and _air < 0.0 and not _falling:
			_take_off()
	if Game.autoplay and not auto:
		_bot(z)
	_x = move_toward(_x, float(_lane), delta / LANE_TIME)
	var roof: Variant = _roof_at(z)
	var roof_h: float = roof["h"] if roof != null else -99.0
	if _air >= 0.0:
		_air += db
		var u := _air / JUMP_BEATS
		_h = _air_from + 4.0 * JUMP_PEAK * u * (1.0 - u) + (0.0 if u < 1.0 else -(u - 1.0) * 3.0)
		if u > 0.5 and roof != null and _h <= roof_h and _h > roof_h - CATCH:
			_land(roof_h)
		elif roof != null and _h < roof_h - CATCH:
			_fail("bonk")  # into the wall of a higher roof
			return
		elif _h < -6.0:
			_fail("fall")  # jumped short, down into the gap
			return
	elif _falling:
		_vh -= 14.0 * delta
		_h += _vh * delta
		if roof != null and _h <= roof_h and _h > roof_h - CATCH:
			_falling = false
			_land(roof_h)  # only just missed the jump: he scrambles up onto the next roof
		elif roof != null and _h < roof_h:
			_fail("fall")  # into the wall below the next roof's edge
			return
		elif _h < -6.0:
			_fail("fall")
			return
	else:
		if roof == null:
			_falling = true
			_vh = 0.0
		elif roof_h > _h + 0.05:
			_fail("bonk")
			return
		else:
			_h = roof_h
	# chimneys and vents
	for o in _obstacles:
		if auto:
			break
		if o.has("gone"):
			continue
		if z > o["z0"] - 0.2 and z < o["z1"] + 0.2 and absf(_x - o["lane"]) < 0.45 and _h < o["top"] - 0.05:
			o["gone"] = _t  # it breaks apart (see _draw_obstacle) and stays gone after the restart
			Game.sfx("bonk", -6.0, 0.8 if o["kind"] == "chimney" else 1.2)
			_fail("chimney" if o["kind"] == "chimney" else "vent")
			return
	# the birds: the shadow appears two beats ahead, aimed at Blobb's lane; then the dive
	for d in _dives:
		if d["done"]:
			continue
		if _beat > d["beat"] + 0.5:
			d["done"] = true  # long gone (after a warp)
			continue
		if d["lane"] == 99 and _beat >= d["beat"] - 2.0:
			d["lane"] = _lane
			Game.sfx("flap", -10.0, 1.2)
		if _beat >= d["beat"] and d["lane"] != 99:
			d["done"] = true
			var base: float = roof_h if roof != null else 0.0
			if absf(_x - d["lane"]) < 0.6 and _h < base + 0.7 and not auto:
				d["gone"] = true  # this bird doesn't dive again after the restart
				_fail("bird")
				return
	if _beat >= END_BEAT and not _ended:
		_end()


func _take_off() -> void:
	_air = 0.0
	_air_from = _h
	_squash = 1.25
	Game.sfx("jump", -8.0, 1.1)


func _land(roof_h: float) -> void:
	_air = -1.0
	_h = roof_h
	_squash = 0.72
	Game.sfx("land", -14.0)


## A hit is a retell: Y objects, the picture warbles, and Blobb starts again at the start of the
## roof he was on (the one before, if he'd only just landed). What he hit stays gone, so the same
## chimney, vent or bird can't stop him twice. A missed gap has nothing to take away: he simply
## tries that jump again.
func _fail(why: String) -> void:
	if Game.autoplay:  # test runs log why the bot was hit
		print("chase hit: ", why, " beat ", snappedf(_beat, 0.01), " lane ", _lane, " x ", snappedf(_x, 0.01), " h ", snappedf(_h, 0.01))
	_retelling = true
	_squash = 0.7
	Game.sfx("rewind", -6.0)
	fx.rewind_pulse(0.9)
	story.play("chase_fail_%d" % (_fail_count % 3 + 1), self)
	_fail_count += 1
	await get_tree().create_timer(0.5 if Game.fast else RETELL_SECS).timeout
	if _ended:
		return
	_checkpoint = _checkpoint_for(_beat)
	_beat = _checkpoint
	_last_whole = floori(_beat)
	_h = (_roof_at(_beat * BEAT_LEN) as Dictionary)["h"]
	_air = -1.0
	_falling = false
	_vh = 0.0
	_lane = 0
	_x = 0.0
	for d in _dives:  # the birds after the checkpoint dive again (aimed afresh), except the one that hit
		if not d.has("gone"):
			d["done"] = d["beat"] < _beat
			d["lane"] = 99
	camera.position = _proj(0, _beat * BEAT_LEN + 3.0, 0)
	camera.reset_smoothing()
	_retelling = false


func _end() -> void:
	_ended = true
	await get_tree().create_timer(1.0).timeout
	# look up at the sign
	var sign := _proj(0.0, _hospital["z0"], _hospital["top"] - 1.3)
	var from := _proj(_x * 0.3, _beat * BEAT_LEN + 3.2, maxf(_h, -1.0) * 0.5) + Vector2(0, 40)
	var tw := create_tween()
	tw.tween_property(self, "_cam_extra", sign + Vector2(-180, 260) - from, 4.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await get_tree().create_timer(2.2).timeout
	await story.play("help", self)


func fx_white_out() -> void:
	_white = 1.0
	await fx.white(1.0, 4.0)
	await get_tree().create_timer(2.5 if not Game.fast else 0.3).timeout
	await _chapter_card()
	Game.unlock_chapter(4)
	Game.go("res://scenes/title.tscn", Color.WHITE, 1.5)


func _chapter_card() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 101
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color.WHITE
	bg.size = Vector2(1920, 1080)
	layer.add_child(bg)
	var box := VBoxContainer.new()
	box.position = Vector2(0, 400)
	box.size = Vector2(1920, 300)
	box.add_theme_constant_override("separation", 20)
	layer.add_child(box)
	for spec in [[Game.t("chapter_3"), 44, Fonts.serif()], [Game.t("chapter_3_name"), 84, Fonts.hand()], [Game.t("chapter_end_3"), 36, Fonts.serif()]]:
		var l := Label.new()
		l.text = spec[0]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_override("font", spec[2])
		l.add_theme_font_size_override("font_size", spec[1])
		l.add_theme_color_override("font_color", Color(0.35, 0.37, 0.42))
		l.modulate.a = 0.0
		box.add_child(l)
		create_tween().tween_property(l, "modulate:a", 1.0, 1.4)
		await get_tree().create_timer(1.6 if not Game.fast else 0.2).timeout
	await get_tree().create_timer(3.5 if not Game.fast else 0.5).timeout


## Test bot: jump at roof edges and steps up, sidestep chimneys and birds, hop vents.
func _bot(z: float) -> void:
	if _air >= 0.0 or _falling:
		return
	var roof: Variant = _roof_at(z)
	var ahead: Variant = _roof_at(z + 0.5)
	if roof != null and (ahead == null or ahead["h"] > roof["h"] + 0.05):
		_take_off()
		return
	# lanes that are blocked soon (ahead) and right now (beside Blobb, if he steps over)
	var ahead_blocked := {}
	var now_blocked := {}
	for o in _obstacles:
		var near: bool = o["z1"] - z > -0.5 and o["z0"] - z < 0.7
		if o["kind"] == "chimney":
			if o["z1"] - z > -0.3 and o["z0"] - z < 3.5:
				ahead_blocked[o["lane"]] = true
			if near:
				now_blocked[o["lane"]] = true
		elif o["z0"] - z > 0.0 and o["z0"] - z < 0.6 and o["lane"] == _lane:
			_take_off()
			return
	for d in _dives:
		if not d["done"] and d["lane"] != 99 and d["beat"] - _beat < 1.0:
			ahead_blocked[d["lane"]] = true
			if d["lane"] == _lane and d["beat"] - _beat < 0.45:
				_take_off()  # no way round it: jump, the bird misses
				return
	if ahead_blocked.has(_lane):
		for l in [0, -1, 1]:
			if not ahead_blocked.has(l):
				var step := _lane + signi(l - _lane)
				if not now_blocked.has(step):
					_lane = step
				break


# ================================================================ drawing

func _proj(x: float, z: float, h: float) -> Vector2:
	return AX * x + AZ * z + AH * h


func _update_camera() -> void:
	var z := _beat * BEAT_LEN
	camera.position = _proj(_x * 0.3, z + 3.2, maxf(_h, -1.0) * 0.5) + Vector2(0, 40) + _cam_extra


func _draw_sky(n: Node2D) -> void:
	var top := Color(0.02, 0.03, 0.09)
	var low := Color(0.1, 0.12, 0.26)
	for i in 30:
		n.draw_rect(Rect2(0, i * 36, 1920, 37), top.lerp(low, i / 29.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 220:
		n.draw_circle(Vector2(rng.randf() * 1920, rng.randf() * 1080), rng.randf_range(0.7, 2.0), Color(1, 1, 0.92, rng.randf_range(0.25, 0.85)))


func _draw_world() -> void:
	var z := _beat * BEAT_LEN
	var view_far := z + 70.0
	var view_near := z - 22.0
	# the hospital, far behind everything else
	if _hospital["z0"] < view_far + 40:
		_draw_hospital()
	var far := []
	var near := []
	for bl in _buildings:
		if bl["z1"] < view_near or bl["z0"] > view_far:
			continue
		if bl["z1"] >= z - 0.2:
			far.append(bl)
		else:
			near.append(bl)
	far.sort_custom(func(a, b): return a["z0"] > b["z0"])
	near.sort_custom(func(a, b): return a["z0"] > b["z0"])
	for bl in far:
		_draw_building(bl)
	# things on the roofs, back to front, with Blobb among them
	var items := []
	for o in _obstacles:
		if o["z1"] > z - 1.0 and o["z0"] < view_far:
			items.append({"k": o["z0"] - o["lane"] * 0.6, "o": o})
	items.append({"k": z - _x * 0.6, "blobb": true})
	items.sort_custom(func(a, b): return a["k"] > b["k"])
	for d in _dives:
		if not d["done"] and d["lane"] != 99:
			_draw_dive_shadow(d)
	for it in items:
		if it.has("blobb"):
			_draw_blobb()
		else:
			_draw_obstacle(it["o"])
	for bl in near:
		_draw_building(bl)
	_draw_birds()


func _quad(a: Vector2, b: Vector2, c: Vector2, d: Vector2, col: Color) -> void:
	_world.draw_colored_polygon(PackedVector2Array([a, b, c, d]), col)


func _box(x0: float, x1: float, z0: float, z1: float, h0: float, h1: float, top: Color, front: Color, side: Color) -> void:
	# visible: the top, the face toward the camera's back (-z), and the right side (+x)
	_quad(_proj(x0, z0, h1), _proj(x1, z0, h1), _proj(x1, z1, h1), _proj(x0, z1, h1), top)
	_quad(_proj(x0, z0, h0), _proj(x1, z0, h0), _proj(x1, z0, h1), _proj(x0, z0, h1), front)
	_quad(_proj(x1, z0, h0), _proj(x1, z1, h0), _proj(x1, z1, h1), _proj(x1, z0, h1), side)


func _draw_building(bl: Dictionary) -> void:
	var h: float = bl["h"]
	var z0: float = bl["z0"]
	var z1: float = bl["z1"]
	_box(-ROOF_HALF, ROOF_HALF, z0, z1, h - 9.0, h, Color(0.27, 0.3, 0.42), Color(0.19, 0.17, 0.25), Color(0.13, 0.12, 0.19))
	# slate courses across the roof, and a lit edge so the gap reads
	var zz := z0 + 1.0
	while zz < z1:
		_world.draw_line(_proj(-ROOF_HALF, zz, h), _proj(ROOF_HALF, zz, h), Color(0.22, 0.25, 0.36), 2.0)
		zz += 1.0
	_world.draw_line(_proj(-ROOF_HALF, z0, h), _proj(ROOF_HALF, z0, h), Color(0.62, 0.68, 0.85), 4.0)
	_world.draw_line(_proj(-ROOF_HALF, z1, h), _proj(ROOF_HALF, z1, h), Color(0.4, 0.45, 0.6), 3.0)
	# lit windows on the side wall
	var rng := RandomNumberGenerator.new()
	rng.seed = bl["seed"]
	var wz := z0 + 0.6
	while wz < z1 - 0.6:
		for k in 3:
			if rng.randf() < 0.3:
				var hh := h - 1.4 - k * 1.6
				_quad(_proj(ROOF_HALF, wz, hh), _proj(ROOF_HALF, wz + 0.45, hh), _proj(ROOF_HALF, wz + 0.45, hh - 0.7), _proj(ROOF_HALF, wz, hh - 0.7), Color(1.0, 0.8, 0.45, 0.85))
		wz += 1.3


func _draw_obstacle(o: Dictionary) -> void:
	var l: float = o["lane"]
	var roof: Variant = _roof_at((o["z0"] + o["z1"]) * 0.5)
	var base: float = roof["h"] if roof != null else 0.0
	if o.has("gone"):
		_draw_debris(o, base)
		return
	var z0: float = o["z0"]
	var z1: float = o["z1"]
	var top: float = o["top"]
	if o["kind"] == "chimney":
		var x0 := l - 0.38
		var x1 := l + 0.38
		_box(x0, x1, z0, z1, base, top, Color(0.55, 0.3, 0.22), Color(0.42, 0.21, 0.16), Color(0.3, 0.15, 0.12))
		# brick courses with staggered joints, on the two faces we see
		var mortar_f := Color(0.3, 0.15, 0.12)
		var mortar_s := Color(0.21, 0.1, 0.08)
		var row := 0
		var hh := base + 0.3
		while hh < top - 0.05:
			_world.draw_line(_proj(x0, z0, hh), _proj(x1, z0, hh), mortar_f, 2.0)
			_world.draw_line(_proj(x1, z0, hh), _proj(x1, z1, hh), mortar_s, 2.0)
			var off := 0.19 if row % 2 == 0 else 0.0
			var u := off + 0.19
			while u < 0.76 - 0.05:
				_world.draw_line(_proj(x0 + u, z0, hh), _proj(x0 + u, z0, hh + 0.3), mortar_f, 2.0)
				_world.draw_line(_proj(x1, z0 + u * 0.9 / 0.76, hh), _proj(x1, z0 + u * 0.9 / 0.76, hh + 0.3), mortar_s, 2.0)
				u += 0.38
			hh += 0.3
			row += 1
		# moonlit corner, and the cap with a sooty flue
		_world.draw_line(_proj(x1, z0, base), _proj(x1, z0, top), Color(0.72, 0.45, 0.36), 2.0)
		_box(l - 0.46, l + 0.46, z0 - 0.08, z1 + 0.08, top, top + 0.15, Color(0.35, 0.2, 0.16), Color(0.28, 0.16, 0.13), Color(0.2, 0.12, 0.1))
		var t2 := top + 0.15
		_quad(_proj(l - 0.24, z0 + 0.2, t2), _proj(l + 0.24, z0 + 0.2, t2), _proj(l + 0.24, z1 - 0.2, t2), _proj(l - 0.24, z1 - 0.2, t2), Color(0.08, 0.05, 0.06))
		_world.draw_line(_proj(l - 0.46, z0 - 0.08, t2), _proj(l + 0.46, z0 - 0.08, t2), Color(0.62, 0.4, 0.32), 2.0)
		_world.draw_line(_proj(l + 0.46, z0 - 0.08, t2), _proj(l + 0.46, z1 + 0.08, t2), Color(0.5, 0.32, 0.26), 2.0)
	else:
		var x0 := l - 0.42
		var x1 := l + 0.42
		_box(x0, x1, z0, z1, base, top, Color(0.6, 0.64, 0.72), Color(0.38, 0.4, 0.48), Color(0.28, 0.3, 0.36))
		# louvre slats on the front, a lit top edge
		for i in 3:
			var hs := base + (top - base) * (0.25 + i * 0.22)
			_world.draw_line(_proj(x0 + 0.1, z0, hs), _proj(x1 - 0.1, z0, hs), Color(0.2, 0.21, 0.27), 3.0)
		_world.draw_line(_proj(x0, z0, top), _proj(x1, z0, top), Color(0.82, 0.86, 0.95), 2.0)
		_world.draw_line(_proj(x1, z0, top), _proj(x1, z1, top), Color(0.7, 0.74, 0.84), 2.0)


## A smashed chimney or vent: chunks thrown up and out, falling and fading over 0.7 s.
func _draw_debris(o: Dictionary, base: float) -> void:
	var k: float = (_t - o["gone"]) / 0.7
	if k >= 1.0:
		return
	var chimney: bool = o["kind"] == "chimney"
	var col := Color(0.55, 0.3, 0.22) if chimney else Color(0.6, 0.64, 0.72)
	col.a = 1.0 - k * k
	var zc: float = (o["z0"] + o["z1"]) * 0.5
	var top: float = o["top"]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(zc * 100.0) + int(o["lane"]) * 7
	for i in (10 if chimney else 6):
		var h0 := lerpf(base, top, rng.randf())
		var v := Vector3(rng.randf_range(-1.6, 1.6), rng.randf_range(1.0, 2.6), rng.randf_range(0.4, 2.2))
		var tt := k * 0.7
		var p := _proj(o["lane"] + v.x * tt, zc + v.z * tt, h0 + v.y * tt - 6.0 * tt * tt)
		var sz := rng.randf_range(10.0, 20.0) * (1.0 - k * 0.5)
		var a := rng.randf() * TAU + k * 6.0
		var c := col.darkened(rng.randf() * 0.35)
		var pts := PackedVector2Array()
		for j in 4:
			pts.append(p + Vector2(cos(a + j * PI * 0.5), sin(a + j * PI * 0.5) * 0.7) * sz)
		_world.draw_colored_polygon(pts, c)


func _draw_dive_shadow(d: Dictionary) -> void:
	var k := clampf(1.0 - (d["beat"] - _beat) / 2.0, 0.0, 1.0)
	var zt: float = d["beat"] * BEAT_LEN
	var roof: Variant = _roof_at(zt)
	var h: float = roof["h"] if roof != null else 0.0
	var c := _proj(d["lane"], zt, h)
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		pts.append(c + (AX * cos(a) + AZ * sin(a)) * (0.25 + 0.3 * k))
	_world.draw_colored_polygon(pts, Color(0.0, 0.0, 0.05, 0.25 + 0.35 * k))
	# the diving bird, coming down out of the dark
	_draw_bird(_proj(d["lane"], zt - 1.5 * (1.0 - k), h + 5.0 * (1.0 - k) + 0.4), 0.8 + 0.4 * k, true)


func _draw_birds() -> void:
	# the flock, flapping along behind and above
	var z := _beat * BEAT_LEN
	var roof: Variant = _roof_at(z)
	var h: float = roof["h"] if roof != null else 0.0
	for i in 5:
		var off := Vector3(sin(_t * 0.9 + i * 1.7) * 1.4, -3.0 - i * 0.7, 2.2 + sin(_t * 1.3 + i) * 0.4 + i * 0.3)
		_draw_bird(_proj(off.x, z + off.y, h + off.z), 0.7, false)


func _draw_bird(p: Vector2, size: float, diving: bool) -> void:
	if _pigeon_tex:
		var k := 70.0 * size / _pigeon_tex.get_height()
		var flap := 1.0 + sin(_t * 14.0 + p.x * 0.01) * 0.15
		_world.draw_set_transform(p, -0.5 if diving else -0.2, Vector2(k, k * flap))
		_world.draw_texture(_pigeon_tex, -Vector2(_pigeon_tex.get_size()) * 0.5)
		_world.draw_set_transform(Vector2.ZERO)
		return
	var w := sin(_t * 14.0 + p.x * 0.01) * 18.0 * size
	var col := Color(0.55, 0.58, 0.68)
	_world.draw_colored_polygon(PackedVector2Array([p + Vector2(-34, -w) * size, p + Vector2(-6, 4) * size, p + Vector2(6, 4) * size, p + Vector2(34, -w) * size, p + Vector2(0, -6) * size]), col.darkened(0.2))
	_world.draw_circle(p, 11.0 * size, col)
	_world.draw_circle(p + Vector2(10, -8) * size, 7.0 * size, col.lightened(0.1))
	_world.draw_circle(p + Vector2(13, -9) * size, 1.8 * size, Color(0.9, 0.4, 0.2))


## Faux-3D Blobb: a cel-shaded fuzzy ball with a contact shadow on the roof below him.
func _draw_blobb() -> void:
	var z := _beat * BEAT_LEN
	var roof: Variant = _roof_at(z)
	if roof != null and _h >= roof["h"] - 0.3:
		var c := _proj(_x, z, roof["h"])
		var pts := PackedVector2Array()
		var spread := 1.0 - clampf((_h - roof["h"]) / 3.0, 0.0, 0.6)
		for i in 20:
			var a := TAU * i / 20.0
			pts.append(c + (AX * cos(a) + AZ * sin(a)) * 0.36 * spread)
		_world.draw_colored_polygon(pts, Color(0, 0, 0.05, 0.4 * spread))
	var run := 0.0 if _air >= 0.0 or _falling else absf(sin(_beat * PI * 2.0))
	var foot := _proj(_x, z, _h)
	var r := BODY_R * S
	var sq := Vector2(1.0 / sqrt(_squash), _squash)
	var center := foot + Vector2(0, -r * sq.y - run * 8.0)
	# feet, stepping on the beat
	var step := sin(_beat * PI * 2.0) * 9.0 if run > 0.0 else 0.0
	_world.draw_set_transform(foot + Vector2(-16 + step * 0.4, -6 - maxf(step, 0.0)), 0.0, Vector2(1, 0.55))
	_world.draw_circle(Vector2.ZERO, 14.0, Color(0.25, 0.4, 0.95))
	_world.draw_set_transform(foot + Vector2(18 - step * 0.4, -10 - maxf(-step, 0.0)), 0.0, Vector2(1, 0.55))
	_world.draw_circle(Vector2.ZERO, 14.0, Color(0.25, 0.4, 0.95))
	# body
	_world.draw_set_transform(center, sin(_t * 9.0) * 0.04, sq)
	_world.draw_texture_rect(_ball, Rect2(-r * 1.15, -r * 1.15, r * 2.3, r * 2.3), false)
	# no face: he runs away from the camera (into the screen), so we see the back of him.
	# A face here made him look like he was running backwards.
	_world.draw_set_transform(Vector2.ZERO)


func _draw_hospital() -> void:
	var z0: float = _hospital["z0"]
	var z1: float = _hospital["z1"]
	var top: float = _hospital["top"]
	_box(-4.0, 4.0, z0, z1, -12.0, top, Color(0.25, 0.28, 0.38), Color(0.18, 0.2, 0.3), Color(0.12, 0.13, 0.22))
	# rows of pale windows on the face toward Blobb
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var hh := top - 3.0
	while hh > -8.0:
		var xx := -3.4
		while xx < 3.3:
			var lit := rng.randf() < 0.55
			_quad(_proj(xx, z0, hh), _proj(xx + 0.5, z0, hh), _proj(xx + 0.5, z0, hh - 0.7), _proj(xx, z0, hh - 0.7), Color(0.8, 0.9, 1.0, 0.75) if lit else Color(0.1, 0.12, 0.2))
			xx += 0.95
		hh -= 1.3
	# a helipad on the roof: a pale ring with an H
	var pad: float = (_hospital["z0"] + _hospital["z1"]) * 0.5
	var ring := PackedVector2Array()
	for i in 28:
		var ang := TAU * i / 28.0
		ring.append(_proj(cos(ang) * 2.4, pad + sin(ang) * 2.4, top))
	_world.draw_colored_polygon(ring, Color(0.85, 0.88, 0.95, 0.85))
	ring = PackedVector2Array()
	for i in 28:
		var ang := TAU * i / 28.0
		ring.append(_proj(cos(ang) * 2.05, pad + sin(ang) * 2.05, top))
	_world.draw_colored_polygon(ring, Color(0.22, 0.25, 0.34))
	for r in [[-1.0, -0.6, -1.2, 1.2], [0.6, 1.0, -1.2, 1.2], [-0.6, 0.6, -0.2, 0.2]]:
		_quad(_proj(r[0], pad + r[2], top), _proj(r[1], pad + r[2], top), _proj(r[1], pad + r[3], top), _proj(r[0], pad + r[3], top), Color(0.92, 0.94, 1.0))
	# the sign: the hospital H, white on a glowing blue square (no words, so it reads in any language)
	var glow := 0.8 + 0.2 * sin(_t * 2.0)
	var zf: float = z0 - 0.05
	_quad(_proj(-1.35, zf, top - 0.0), _proj(1.35, zf, top - 0.0), _proj(1.35, zf, top - 2.6), _proj(-1.35, zf, top - 2.6), Color(0.35, 0.6, 1.0, 0.3 * glow))
	_quad(_proj(-1.0, zf, top - 0.35), _proj(1.0, zf, top - 0.35), _proj(1.0, zf, top - 2.25), _proj(-1.0, zf, top - 2.25), Color(0.12, 0.38, 0.92).lightened(0.15 * glow))
	for r in [[-0.62, -0.3, 0.6, 2.0], [0.3, 0.62, 0.6, 2.0], [-0.3, 0.3, 1.15, 1.45]]:
		_quad(_proj(r[0], zf - 0.01, top - r[2]), _proj(r[1], zf - 0.01, top - r[2]), _proj(r[1], zf - 0.01, top - r[3]), _proj(r[0], zf - 0.01, top - r[3]), Color(1, 1, 1, 0.95))


## Blobb's body: a round fuzzy ball, lit from up and to the left, three flat bands of light
## (cel shading) and a warm rim from the lamps, with a ragged, furry edge.
func _make_ball() -> Texture2D:
	const N := 128
	var img := Image.create(N, N, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var spikes := []
	for i in 64:
		spikes.append(rng.randf_range(0.86, 1.0))
	var light := Vector3(-0.5, -0.6, 0.62).normalized()
	for y in N:
		for x in N:
			var p := Vector2(x - N * 0.5 + 0.5, y - N * 0.5 + 0.5) / (N * 0.5 / 1.15)
			var ang := fposmod(p.angle(), TAU) / TAU * 64.0
			var edge: float = lerpf(spikes[int(ang) % 64], spikes[(int(ang) + 1) % 64], ang - floorf(ang))
			var d := p.length()
			if d > edge:
				continue
			var nz := sqrt(maxf(0.0, 1.0 - minf(d, 1.0) * minf(d, 1.0)))
			var lam := Vector3(p.x, p.y, nz).normalized().dot(light)
			var band := 0.55 if lam < 0.15 else (0.8 if lam < 0.6 else 1.0)
			var col := Color(0.45, 0.72, 0.24) * band
			col.a = 1.0
			if d > 0.78 and p.x > 0.2:
				col = col.lerp(Color(1.0, 0.82, 0.4), 0.45)  # warm rim from the lamps
			if rng.randf() < 0.18:
				col = col.darkened(0.12)  # fuzz
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)

# ================================================================ checking from outside

## For gda (`gda game call /root/<Level> debug_state`): see scripts/debug_state.gd. Read-only.
const GDA_CALLABLE := ["debug_state"]


func debug_state() -> Dictionary:
	var d := DebugState.base(null)
	d.merge(DebugState.json({"beat": _beat, "x": _x, "h": _h, "retelling": _retelling, "fails": _fail_count, "gone": _obstacles.filter(func(o): return o.has("gone")).size() + _dives.filter(func(d): return d.has("gone")).size(), "checkpoint": _checkpoint, "ended": _ended}), true)
	return d
