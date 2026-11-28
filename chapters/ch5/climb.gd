extends Node2D
## Chapter 5: The Climb. The last chapter. Side view, one screen wide: Blobb climbs the mountain
## from ch4, from night at the foot through blue hour to the last stars, and the sun comes up at
## the summit. O comes back, faint at first; by the top the two narrators are equals again.
## Then a glimpse of the real room in the morning (drawn in code, all silhouettes but the drawing
## of Blobb on the wall), and the end.
## Mechanics (tried out in climb_test.tscn):
##   heartbeat ledges  on every monitor beat they kick and launch whoever stands on them (no
##                     timing needed). The beat is a little uneven at the foot (as ch4 ended) and
##                     even from "steady" up.
##   stretch & swing   after O's rule ("rule" scene, @stretch): hold E / (B) near a glowing hold
##                     (roots, then low stars), swing, let go to fling.
## Ledges are one-way: Blobb jumps up through them and lands on top. Falling a long way is a
## retell. Dialogue: chapters/ch5/story.txt. Art: assets/gen/ch5/ (optional; everything has a
## drawn fallback). --warp=N starts at section N (0 foot, 1 O's rule, 2 the stars, 3 near the
## top, 4 the summit); --autoplay hops ledge to ledge to run the story through.

const ART := "res://assets/gen/ch5/"
const W := 1920.0
const DARK := Color(0.02, 0.03, 0.08)  # the night before the narrators tell it back
const GROUND := 9400.0
const TOP := 700.0             # camera limit
const EVEN := 0.95             # seconds between beats once the beat is even
const SLIGHT := Vector2(0.8, 1.35)  # at the foot: EVEN times a random factor in this range, a little
                               # uneven, as ch4 ended; it evens out as he climbs to "steady"
const LOOK := 1900.0           # at the summit the camera sweeps up this far, past Blobb, into the sky
const SKY_RISE := 700.0        # foot to top, the night picture (far ranges) sinks this far: he's above it
const SKY_PAN := 1500.0        # and this much more for the look up (the sky moves less than the mountain)
## Star layers [parallax factor, count, size]: the far ones drift least. More stars come out the
## higher he gets (each star has its own threshold), so the top, and the sky above it that the
## look up sweeps into, is the fullest sky. The first layer is a dust of tiny, faint ones.
const STAR_LAYERS := [[0.4, 1600, 0.9], [0.55, 1100, 1.3], [0.8, 800, 1.8], [1.0, 340, 2.5]]
const MOON_AT := Vector2(700, 430)   # where the moon and the bright star end up on screen
const STAR_AT := Vector2(1260, 340)  # (below the narrator lines)
const MILKY_F := 0.85          # the milky way's layer
## The painted starry sky (assets/gen/ch5/stars_sky.png, 1920x3000 on black, drawn additively):
## one tall picture, sparse at the bottom, denser upward, the milky way at the top. It scrolls with
## the night picture (the sky shift), so the climb and the sweep up move into ever more stars; at the
## end of the sweep its top fills the screen. Without it the stars are drawn in code.
const STARS_SKY := "stars_sky.png"
const FALL := 700.0            # this far below the last safe ledge is a fall (a retell)

## Plain ledges [x0, x1, top], bottom to top. The first is the ground; the last is the summit.
## Three stairs of plain hops (200 px a step, zigzag) at the foot give O's first, slow lines
## time to be told before the next beat.
const LEDGES := [
	[0, 1920, 9400],
	# the foot (night)
	[250, 550, 9200], [650, 950, 9000], [250, 550, 8800], [400, 650, 8600],  # stairs
	[700, 1000, 8420], [1150, 1450, 8220], [800, 1650, 7680],
	[450, 750, 7480], [900, 1200, 7280], [450, 750, 7080], [900, 1200, 6880],  # stairs
	[450, 700, 6680], [100, 600, 6140],
	[700, 1000, 5940], [250, 550, 5740], [700, 1000, 5540], [300, 600, 5340],  # stairs
	[750, 1000, 5160], [1150, 1700, 4620],
	# the middle (blue hour): O's rule, then roots
	[450, 800, 4320], [100, 500, 3770], [1600, 1900, 3700], [1300, 1800, 3150],
	# the high stretch (the last stars)
	[100, 450, 2750], [300, 800, 2200], [1600, 1900, 1950], [1000, 1500, 1400],
	[700, 950, 1220], [200, 700, 1050],
]
## Heartbeat ledges [x0, x1, top]; each launches Blobb up to the ledge above it.
## Where one sits beside a plain ledge at the same height they meet edge to edge: Blobb's round
## bottom (a 100 px wide capsule) wedges itself into any narrower gap between two one-way ledges.
const HEARTS := [
	[1450, 1750, 8220], [150, 450, 6680], [1000, 1300, 5160],
	[150, 450, 4320], [1400, 1600, 3700],
	[450, 680, 2750], [1350, 1600, 1950],
]
## Holds: [x, y, "root" | "star"]. They only work after O's rule.
const HOLDS := [
	[1000, 4380, "root"],
	[750, 3560, "root"], [1100, 3500, "root"], [1450, 3560, "root"],
	[1000, 2900, "star"], [600, 2690, "star"],
	[1100, 2000, "star"], [1450, 1850, "star"],
]
## Story beats by height: the scene plays once Blobb's feet are at or above this y.
## ("stars" isn't here: it follows "steady" on the same ledge, before the first star hold; see _beat)
const TRIGGERS := {8225: "heartbeat", 6145: "colour", 4625: "rule", 3155: "steady",
	2205: "pigeons", 1405: "question"}
const SUMMIT_X := 700.0
const WARPS := [Vector2(200, 9400), Vector2(1400, 4620), Vector2(1550, 3150), Vector2(1250, 1400), Vector2(450, 1050)]
## Where the drawing of Blobb hangs on the wall in the room at the end (landscape: the photo in
## assets/drawing.jpeg is portrait, so it's turned a quarter to the left).
const PAPER := Rect2(1545, 330, 300, 169)  # on the wall right of the window, in the moonbeam
const ROOM_MOON := Vector2(760, 262)  # in the window's upper panes (below the narrator lines)
const ROOM_STAR := Vector2(1170, 290)

var player: PlayerSide
var fx: StyleFX
var camera: Camera2D
var story := StoryScript.load_file("res://chapters/ch5/story.txt")
var _world: Node2D
var _sky: Node2D
var _lit := 1.0  # the stars, as told: 0 until Y puts them in (the intro), 1 after
var _sky_sprites := {}
var _rope: Line2D
var rig: ClimbRig  # the climbing moves: heartbeat ledges, holds, the swing
var _tex := {}
var _t := 0.0
var _beat_left := 2.0
var _swung := false
var _safe := Vector2(200, GROUND)
var _fired := {}
var _retelling := false
var _fail_count := 0
var _done := false
var _up := 0.0                 # 0..1: the look up into the sky at the summit
var _moon := 0.0               # 0..1: the moon and the one bright star (O's and Y's signs), @moon
var _stars: Array = []         # per layer: Array of Vector4(x, y, threshold, twinkle phase)
var _milky: Array = []         # Vector4(x, y, radius, hue) soft glows, and _milky_dust stars
var _nebula: Array[Vector4] = []  # big faint coloured glows high up (x, y, radius, hue 0..1)
var _milky_dust: Array = []
var _star_nodes: Array[MultiMeshInstance2D] = []  # one per STAR_LAYERS entry (drawn on the GPU)
var _dust_node: MultiMeshInstance2D
var _stars_sky: Sprite2D  # the painted starry sky (STARS_SKY), if there is one
var _shoot := -1.0             # when the shooting star set off (_t), or -1
var _sky_top: Node2D
var _pigeons: Array[Sprite2D] = []
var _pigeons_on := false
var _room: CanvasLayer
var _room_root: Control  # the room (dimmed under the credits)
var _room_art: TextureRect  # the drawing of Blobb on the wall (it grows to full screen at the end)
var _monitor: Control  # the heart monitor's lit screen in the room: it blips with each beep
var _beat_fade := 1.0  # the beep's loudness (linear); it fades out as the drawing grows
var _beat_times: Array[float] = []  # the last few beats (_t), for the monitor's trace
var _cover: ColorRect  # the start: all black but Blobb, until O tells the mountain back (@mountain)
var _bot_i := 0
var _bot_wait := 0.0


func _ready() -> void:
	process_physics_priority = 10  # after the player, so a launch overrides his own movement
	Game.music("res://assets/audio/music_dream.ogg", -24.0, 3.0)
	# cliff_bg.png is a whole canyon scene (it would cover the skies), so only its right-hand
	# strip of rock is used, as the mountain's walls at both sides
	for n in ["ledge_rock", "ledge_heart", "hold_root", "hold_star", "cliff_bg"]:
		if ResourceLoader.exists(ART + n + ".png"):
			_tex[n] = load(ART + n + ".png")
	_build_world()
	if Game.warp >= 0:
		_warp_to(clampi(Game.warp, 0, WARPS.size() - 1))
	else:
		_intro()


func _build_world() -> void:
	var sky_layer := CanvasLayer.new()
	sky_layer.layer = -10
	add_child(sky_layer)
	_sky = Node2D.new()
	_sky.draw.connect(_draw_sky)
	sky_layer.add_child(_sky)
	for n in ["night"]:  # (sky_bluehour/summit.png: the old sunrise ending, unused now)
		var path := ART + "sky_%s.png" % n
		if ResourceLoader.exists(path):
			var s := Sprite2D.new()
			s.texture = load(path)
			s.centered = false
			s.scale = Vector2(1920.0, 1080.0) / s.texture.get_size()
			s.modulate.a = 0.0
			sky_layer.add_child(s)
			_sky_sprites[n] = s
	# above the sky pictures: the sky further up, with the moon and the morning star (O and Y)
	_sky_top = Node2D.new()
	_sky_top.draw.connect(_draw_sky_top)
	sky_layer.add_child(_sky_top)
	# the painted moon and bright star (on black: drawn additively, so the black disappears)
	for n in [["moon", "moon.png", 340.0], ["star", "star_bright.png", 260.0]]:
		if ResourceLoader.exists(ART + n[1]):
			var sp := Sprite2D.new()
			sp.texture = load(ART + n[1])
			sp.scale = Vector2.ONE * (n[2] / sp.texture.get_width())
			var mat := CanvasItemMaterial.new()
			mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			sp.material = mat
			sp.modulate.a = 0.0
			sky_layer.add_child(sp)
			_sky_sprites[n[0]] = sp
	_make_stars()
	_world = Node2D.new()
	_world.draw.connect(_draw_world)
	add_child(_world)
	for i in LEDGES.size():
		_solid(LEDGES[i], i > 0)
	for h in HEARTS:
		_solid(h, true)
	_solid([-64, 0, -400], false)
	_solid([W, W + 64, -400], false)
	_rope = Line2D.new()  # Blobb's stretched arm (ClimbRig dresses it in his own fur)
	_rope.z_index = 1
	_rope.visible = false
	add_child(_rope)
	_cover = ColorRect.new()  # above the world and the sky, below Blobb (z 2)
	_cover.color = Color.BLACK
	_cover.position = Vector2(-2000, -2000)
	_cover.size = Vector2(W + 4000, GROUND + 4000)
	_cover.z_index = 1
	_cover.modulate.a = 0.0
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cover)
	player = PlayerSide.new()
	player.name = "Player"  # a stable path for gda: /root/<Level>/Player
	player.position = _safe
	player.z_index = 2
	player.jump_velocity = PlayerSide.STRONG_JUMP
	player.use_bot = false
	add_child(player)
	player.sprite.set_tint(BlobbSprite.GREEN, BlobbSprite.GREEN_AMOUNT, 0.0)
	var spots: Array[Vector2] = []
	for h in HOLDS:
		spots.append(Vector2(h[0], h[1]))
	rig = ClimbRig.new(player, HEARTS, spots, _rope)
	rig.can_reach = false  # not before O's rule
	rig.flung.connect(func() -> void:
		if not _swung:
			_swung = true
			story.play("swing", self))
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 5.0
	camera.limit_left = 0
	camera.limit_right = int(W)
	camera.limit_top = int(TOP)
	camera.limit_bottom = int(GROUND + 200)
	camera.offset = Vector2(0, -140)
	player.add_child(camera)
	fx = StyleFX.new()
	add_child(fx)
	fx.set_look("real", 0.0)


## One-way ledges: Blobb jumps up through them and lands on top (the ground and walls are solid).
func _solid(r: Array, one_way: bool) -> void:
	var bottom: float = GROUND + 400.0 if not one_way else r[2] + 40.0
	LevelKit.solid(self, Rect2(r[0], r[2], r[1] - r[0], bottom - r[2]), one_way)


func _warp_to(i: int) -> void:
	var p: Vector2 = WARPS[i]
	for y in TRIGGERS:
		if y > p.y + 5:
			_fired[TRIGGERS[y]] = true
	if i >= 1:
		_fired["intro"] = true
	if i >= 2:
		rig.can_reach = true
		Narrator.legend("hint_swing")
	player.teleport(p)
	_safe = p
	Game.control_locked = false


# ================================================================ story

## The chapter's name on black, then only Blobb in the dark while O comes back. Nothing is told
## yet: the narrators put the mountain (@mountain) and the stars (@stars) back.
func _intro() -> void:
	Game.control_locked = true
	_lit = 0.0
	_cover.modulate.a = 1.0
	fx.tint(DARK, 0.3, 0.0)  # Blobb a little dimmed: he's in the dark too
	if player.sprite.sprite_frames.has_animation("climb"):
		player.rest_anim = "climb"  # still straining from ch4's climb, while O finds the words
	await ChapterCard.title(self, 5, Color(0.85, 0.85, 0.95), Color.BLACK)
	await story.play("intro", self)
	player.rest_anim = "idle"
	Game.control_locked = false
	Narrator.hint(Game.t("hint_move"), 6.0)


func _check_triggers() -> void:
	if _retelling or _done:
		return
	var y := player.position.y
	for ty in TRIGGERS:
		var scene: String = TRIGGERS[ty]
		if y <= ty and not _fired.has(scene):
			_fired[scene] = true
			_beat(scene)
	if not _done and player.is_on_floor() and y <= LEDGES[-1][2] + 5.0 and player.position.x < SUMMIT_X:
		_summit()


func _beat(scene: String) -> void:
	match scene:
		"pigeons":
			_pigeons_in()
		"steady":
			_stars_gate()
			return
	await story.play(scene, self)


## On the ledge below the first star hold: the stars are told before he swings on them. The holds
## stay out of reach (dim) until "stars" has been said, so he waits on the ledge, then they light.
func _stars_gate() -> void:
	if _fired.has("stars"):
		return
	_fired["stars"] = true
	var had := rig.can_reach
	rig.can_reach = false
	story.play("steady", self)
	await story.play("stars", self)  # queued right after "steady"
	if had and not _done:
		rig.can_reach = true
		Game.sfx("chime", -14.0, 1.4)


func _fail() -> void:
	if _retelling or _done:
		return
	_retelling = true
	rig.release()
	Game.sfx("rewind", -4.0)
	fx.rewind_pulse(1.2)
	player.visible = false
	player.frozen = true
	player.teleport(_safe)
	var scribble := Retell.scribble(self, _safe + Vector2(0, -70))
	# Y's objection is queued behind whatever is being told, so it can come much later: Blobb
	# comes back after a fixed moment, not when the line ends (he used to stay invisible).
	if not Narrator.busy:  # never queued behind a scene being told: it would come far too late
		story.play("fail_%d" % (_fail_count % 4 + 1), self)
		_fail_count += 1
	await get_tree().create_timer(0.6 if Game.fast else 1.8).timeout
	Retell.clear(scribble)
	player.teleport(_safe)
	player.frozen = false
	player.visible = true
	player.sprite.flash(0.6)
	Game.sfx("pop", -6.0)
	_retelling = false


## A save point per section (the --warp numbers): the highest one he has stood above.
## Section 0 is the start, where Continue plays the intro again.
func _save_section() -> void:
	var i := WARPS.size() - 1
	while i > 0 and player.position.y > WARPS[i].y + 5.0:
		i -= 1
	if i > 0 and i > Game.progress_at:
		Game.checkpoint(i)


## The top: the whole night sky. Blobb looks at it a while; then Y wants morning and O wants a
## little more night (the summit scene), the moon comes out beside the star, and the room.
func _summit() -> void:
	_done = true
	Narrator.legend("")
	Game.unlock_chapter(6)  # the story is finished: nothing left to continue
	rig.release()
	Game.control_locked = true
	player.velocity = Vector2.ZERO
	player.frozen = true  # he only looks from here on: a blocking line ending must not let him jump again
	await get_tree().create_timer(1.0 if Game.fast else 2.0).timeout
	await _look_up()
	# he just looks, a while; one shooting star
	await get_tree().create_timer(0.5 if Game.fast else 3.0).timeout
	_shoot = _t
	await get_tree().create_timer(0.5 if Game.fast else 4.0).timeout
	await story.play("summit", self)
	await get_tree().create_timer(1.0 if Game.fast else 4.0).timeout
	_show_room()
	await get_tree().create_timer(1.0 if Game.fast else 4.5).timeout
	await story.play("room", self)
	await get_tree().create_timer(0.5 if Game.fast else 2.0).timeout
	await _credits()
	await _zoom_drawing()
	var night := Color(0.04, 0.05, 0.12)
	await ChapterCard.closing(self, "the_end", Color(0.85, 0.87, 0.97), night, 2.5, 5.0)
	Game.go("res://scenes/title.tscn", night, 2.0)


## A slow sweep up from the summit, past Blobb and the mountain, into more and more sky.
func _look_up() -> void:
	var center := camera.get_screen_center_position()
	camera.limit_top = int(TOP - LOOK - 1500.0)
	camera.offset.y = center.y - player.global_position.y  # carry on from where the view is
	camera.reset_smoothing()
	var dur := 2.5 if Game.fast else 15.0
	var tw := create_tween().set_parallel()
	tw.tween_property(camera, "offset:y", camera.offset.y - LOOK, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(self, "_up", 1.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished


# ================================================================ story effects

## O's rule: "In my half, Blobb is a good deal longer than he looks." The holds wake up.
## O, faint, tells the mountain back: it shows, dimly.
func fx_mountain() -> void:
	fx.tint(DARK, 0.45, 2.5)
	create_tween().tween_property(_cover, "modulate:a", 0.0, 2.5)


## Y's half: the stars, all of them.
func fx_stars() -> void:
	fx.tint(DARK, 0.0, 2.5)
	Game.sfx("chime", -10.0, 1.2)
	create_tween().tween_property(self, "_lit", 1.0, 2.5)


func fx_stretch() -> void:
	rig.can_reach = true
	Game.sfx("pop", -6.0, 0.8)
	Narrator.legend("hint_swing")  # stays at the bottom of the screen: easy to miss if it faded
	_hint_after_lines("hint_swing_use")


## The big hint, once the lines being told are done (a hint under a blocking scene goes unseen).
func _hint_after_lines(key: String) -> void:
	while Narrator.busy or Game.control_locked:
		await get_tree().process_frame
	Narrator.hint(Game.t(key), 7.0)


## "And your moon." The moon comes out beside the bright star: the narrators' signs, night kept.
func fx_moon() -> void:
	create_tween().tween_property(self, "_moon", 1.0, 1.0 if Game.fast else 4.0).set_trans(Tween.TRANS_SINE)
	Game.sfx("chime", -14.0, 0.8)


# ================================================================ the room and the end

## The credits, over the room: a slow roll from below to above, the room dimmed behind it.
## Holding {advance} or {skip} rolls them faster while it's held.
const CREDITS := [  # [Game.UI key, style]: title, head (the role) or name; "" = a gap
	["credits_title", "title"], [""],
	["credits_art", "head"], ["credits_art_by", "name"], [""],
	["credits_director", "head"], ["credits_director_by", "name"], [""],
	["credits_qa", "head"], ["credits_qa_by", "name"], [""],
	["credits_code", "head"], ["credits_code_by", "name"], [""],
	["credits_pictures", "head"], ["credits_pictures_by", "name"], [""],
	["credits_engine", "head"], ["credits_engine_by", "name"], [""],
	[""],
	["credits_thanks", "name"],
]

func _credits() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50  # over the room, under the narrator
	add_child(layer)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 1920  # full width, so every line centres
	box.add_theme_constant_override("separation", 10)
	layer.add_child(box)
	for c in CREDITS:
		var l := Label.new()
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if c[0] == "":
			l.custom_minimum_size.y = 40
		else:
			l.text = Game.t(c[0])
			var title: bool = c[1] == "title"
			l.add_theme_font_override("font", Fonts.hand() if c[1] != "head" else Fonts.serif())
			l.add_theme_font_size_override("font_size", 110 if title else (30 if c[1] == "head" else 48))
			l.add_theme_color_override("font_color", Color(0.7, 0.74, 0.86) if c[1] == "head" else Color(0.95, 0.95, 1.0))
			l.add_theme_color_override("font_shadow_color", Color(0, 0, 0.05, 0.8))
			l.add_theme_constant_override("shadow_outline_size", 12)
		box.add_child(l)
	box.reset_size()
	box.position.y = 1080.0
	var dur := 4.0 if Game.fast else 38.0
	create_tween().tween_property(_room_root, "modulate", Color(0.45, 0.45, 0.5), 3.0)
	var tw := create_tween()
	tw.tween_property(box, "position:y", -box.size.y, dur)
	var speed := 1.0  # holding {advance} or {skip} rolls them faster, only while it's held
	while tw.is_running():
		var held := Input.is_action_pressed("advance") or Input.is_action_pressed("skip")
		var want := 6.0 if held else 1.0
		speed = move_toward(speed, want, get_process_delta_time() * 20.0)  # eases in and out, no jolt
		tw.set_speed_scale(speed)
		await get_tree().process_frame
	layer.queue_free()
	await create_tween().tween_property(_room_root, "modulate", Color.WHITE, 2.0).finished


## Last of all, the drawing on the wall grows until it fills the screen, out of the moonlight,
## and stays there until {advance} is pressed.
func _zoom_drawing() -> void:
	if not _room_art:
		return
	var back := ColorRect.new()  # the room fades behind it, so the drawing is all there is
	back.color = Color(0.02, 0.02, 0.05)
	back.size = Vector2(1920, 1080)
	back.modulate.a = 0.0
	_room.add_child(back)
	_room.move_child(back, _room.get_child_count() - 1)
	var art := _room_art
	art.reparent(_room)  # out of the dimmed room, above the backdrop
	var big := Vector2(1000, 1800)  # turned a quarter to the left: 1800 wide, 1000 high
	var dur := 1.5 if Game.fast else 7.0
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(back, "modulate:a", 1.0, dur)
	tw.tween_property(self, "_beat_fade", 0.0, dur)  # the beep fades away with the room
	tw.tween_property(art, "size", big, dur)
	tw.tween_property(art, "pivot_offset", big * 0.5, dur)
	tw.tween_property(art, "position", Vector2(960, 540) - big * 0.5, dur)
	tw.tween_property(art, "modulate", Color.WHITE, dur)
	await tw.finished
	if Game.fast or Game.autoplay:
		await get_tree().create_timer(1.0).timeout
		return
	while not Input.is_action_just_pressed("advance"):  # it stays until {advance} is pressed
		await get_tree().process_frame


## The real room at night: two people, the moon and the star in the window, and the drawing of
## Blobb on the wall.
func _show_room() -> void:
	_room = CanvasLayer.new()
	_room.layer = 45  # above the world and StyleFX, below the narrator
	add_child(_room)
	var root := Control.new()
	root.size = Vector2(1920, 1080)
	root.modulate.a = 0.0
	_room.add_child(root)
	_room_root = root
	var drawn := Control.new()
	drawn.size = Vector2(1920, 1080)
	drawn.draw.connect(_draw_room.bind(drawn))
	root.add_child(drawn)
	# the same painted moon and bright star as on the summit, in the window's upper panes
	for n in [["moon.png", ROOM_MOON, 230.0], ["star_bright.png", ROOM_STAR, 170.0]]:
		if ResourceLoader.exists(ART + n[0]):
			var sp := Sprite2D.new()
			sp.texture = load(ART + n[0])
			sp.scale = Vector2.ONE * (n[2] / sp.texture.get_width())
			sp.position = n[1]
			var mat := CanvasItemMaterial.new()
			mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			sp.material = mat
			root.add_child(sp)
	var front := Control.new()  # the frame, curtains, bed and people, in front of the moon and star
	front.size = Vector2(1920, 1080)
	front.draw.connect(_draw_room_rest.bind(front))
	root.add_child(front)
	_monitor = Control.new()  # the monitor's screen, lit: that's where the beep comes from
	_monitor.size = Vector2(1920, 1080)
	_monitor.draw.connect(_draw_monitor.bind(_monitor))
	root.add_child(_monitor)
	if ResourceLoader.exists("res://assets/drawing.jpeg"):
		var art := TextureRect.new()
		var photo := AtlasTexture.new()  # trimmed a little, so no table shows round the paper
		photo.atlas = load("res://assets/drawing.jpeg")
		photo.region = Rect2(Vector2(photo.atlas.get_size()) * 0.05, Vector2(photo.atlas.get_size()) * 0.9)
		art.texture = photo
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE  # before the size, or the photo's own size wins
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.size = Vector2(PAPER.size.y, PAPER.size.x)
		art.pivot_offset = art.size * 0.5
		art.position = PAPER.get_center() - art.size * 0.5
		art.rotation = -PI * 0.5
		art.modulate = Color(0.66, 0.7, 0.84)  # in the moonlight
		root.add_child(art)
		_room_art = art
	create_tween().tween_property(root, "modulate:a", 1.0, 1.0 if Game.fast else 4.0)


## The real room, all in silhouette against a night window (the same mountains outside, the moon
## and the bright star in its panes): the hospital bed with O propped up, the monitor beside it, Y
## on a chair leaning on the bed, their hands meeting on the blanket. The drawing of Blobb on the
## wall catches the moonlight.
const ROOM_WALL := Color(0.1, 0.1, 0.16)
const ROOM_WIN := Rect2(560, 120, 800, 580)


## The back of the room: the wall and the night in the window (the moon and star go over this).
func _draw_room(c: Control) -> void:
	var wall := ROOM_WALL
	c.draw_rect(Rect2(0, 0, 1920, 1080), wall)
	# the window: the night sky over the mountains, stars, the moon and the star
	var win := ROOM_WIN
	var top := Color(0.02, 0.03, 0.1)
	var low := Color(0.12, 0.14, 0.3)
	for i in 29:
		c.draw_rect(Rect2(win.position.x, win.position.y + i * 20.0, win.size.x, 21.0), top.lerp(low, i / 28.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 90:
		c.draw_circle(Vector2(rng.randf_range(win.position.x, win.end.x), rng.randf_range(win.position.y, 560.0)), rng.randf_range(0.8, 2.0), Color(1, 1, 0.94, rng.randf_range(0.3, 0.9)))
	if not (ResourceLoader.exists(ART + "moon.png") and ResourceLoader.exists(ART + "star_bright.png")):
		_room_icons(c, ROOM_MOON, ROOM_STAR)  # else the painted ones, as sprites over this


## The narrators' icon shapes as moon and star, when the paintings are missing.
func _room_icons(c: Control, moon: Vector2, star: Vector2) -> void:
	for k in 4:
		c.draw_circle(moon, 54.0 + k * 26.0, Color(1.0, 0.92, 0.78, 0.07))
		c.draw_circle(star, 22.0 + k * 20.0, Color(0.78, 0.92, 1.0, 0.07))
	var pts := NarratorIcon.moon_points(48.0)
	for i in pts.size():
		pts[i] += moon
	c.draw_colored_polygon(pts, Color(1.0, 0.95, 0.84))
	pts = NarratorIcon.star_points(26.0)
	for i in pts.size():
		pts[i] += star
	c.draw_colored_polygon(pts, Color(0.9, 0.97, 1.0))


## The front of the room: the window frame, curtains, bed, monitor and the two of them.
func _draw_room_rest(c: Control) -> void:
	var wall := ROOM_WALL
	var win := ROOM_WIN
	var far := Color(0.06, 0.06, 0.1)    # the machine and the bed (a little behind)
	var near := Color(0.02, 0.02, 0.04)  # Y, nearest
	c.draw_colored_polygon(PackedVector2Array([Vector2(560, 700), Vector2(560, 640), Vector2(700, 600), Vector2(820, 640),
		Vector2(960, 556), Vector2(1100, 628), Vector2(1250, 592), Vector2(1360, 640), Vector2(1360, 700)]), Color(0.1, 0.11, 0.22))
	# frame, cross bars and curtains
	c.draw_rect(win, wall.darkened(0.2), false, 26.0)
	c.draw_rect(Rect2(951, 120, 18, 580), wall.darkened(0.2))
	c.draw_rect(Rect2(560, 401, 800, 18), wall.darkened(0.2))
	c.draw_colored_polygon(PackedVector2Array([Vector2(500, 90), Vector2(640, 90), Vector2(600, 400), Vector2(630, 760), Vector2(480, 760)]), far)
	c.draw_colored_polygon(PackedVector2Array([Vector2(1280, 90), Vector2(1420, 90), Vector2(1440, 760), Vector2(1300, 760), Vector2(1320, 400)]), far)
	# the moonlight: a faint beam across the wall (onto the drawing) and the floor
	c.draw_colored_polygon(PackedVector2Array([Vector2(1360, 200), Vector2(1360, 560), Vector2(1960, 680), Vector2(1960, 150)]), Color(0.7, 0.8, 1.0, 0.07))
	c.draw_rect(Rect2(0, 860, 1920, 220), Color(0.07, 0.07, 0.11))
	c.draw_colored_polygon(PackedVector2Array([Vector2(640, 860), Vector2(1300, 860), Vector2(1560, 1080), Vector2(420, 1080)]), Color(0.7, 0.8, 1.0, 0.08))
	# the monitor on its stand, a cable to the bed
	c.draw_rect(Rect2(470, 330, 12, 540), far)
	c.draw_rect(Rect2(420, 858, 112, 14), far)
	c.draw_rect(Rect2(396, 300, 160, 112), far)
	c.draw_rect(Rect2(410, 412, 30, 14), far)
	c.draw_line(Vector2(500, 412), Vector2(640, 640), far, 4.0)
	# the hospital bed: frame, wheels, the raised back, head- and footboard
	c.draw_rect(Rect2(560, 752, 900, 44), far)
	for x in [600.0, 1410.0]:
		c.draw_rect(Rect2(x, 796, 18, 62), far)
		c.draw_circle(Vector2(x + 9, 864), 14.0, far)
	c.draw_rect(Rect2(556, 620, 26, 180), far)
	c.draw_rect(Rect2(1440, 650, 26, 150), far)
	c.draw_colored_polygon(PackedVector2Array([Vector2(586, 752), Vector2(600, 700), Vector2(800, 690), Vector2(1000, 676),
		Vector2(1100, 650), Vector2(1180, 672), Vector2(1438, 690), Vector2(1438, 752)]), far)
	c.draw_colored_polygon(PackedVector2Array([Vector2(590, 700), Vector2(640, 520), Vector2(706, 512), Vector2(690, 700)]), far)
	# O, propped up, awake, looking out at the night
	c.draw_colored_polygon(PackedVector2Array([Vector2(640, 702), Vector2(672, 606), Vector2(760, 584), Vector2(840, 630), Vector2(880, 700)]), far)
	c.draw_circle(Vector2(728, 548), 46.0, far)
	c.draw_colored_polygon(PackedVector2Array([Vector2(700, 586), Vector2(748, 586), Vector2(752, 610), Vector2(700, 612)]), far)
	c.draw_colored_polygon(PackedVector2Array([Vector2(770, 620), Vector2(860, 676), Vector2(900, 688), Vector2(896, 700), Vector2(850, 694), Vector2(764, 648)]), far)  # an arm on the blanket
	# Y on a chair beside the bed, leaning on it; their hands meet
	c.draw_rect(Rect2(880, 820, 140, 16), near)
	c.draw_rect(Rect2(1004, 690, 14, 146), near)
	for x in [886.0, 1002.0]:
		c.draw_rect(Rect2(x, 836, 12, 50), near)
	c.draw_colored_polygon(PackedVector2Array([Vector2(926, 822), Vector2(998, 822), Vector2(990, 730), Vector2(944, 704), Vector2(906, 726)]), near)
	c.draw_circle(Vector2(912, 690), 36.0, near)
	c.draw_colored_polygon(PackedVector2Array([Vector2(930, 718), Vector2(900, 700), Vector2(906, 688), Vector2(940, 706)]), near)
	c.draw_colored_polygon(PackedVector2Array([Vector2(946, 726), Vector2(904, 700), Vector2(900, 688), Vector2(912, 686), Vector2(956, 712)]), near)  # an arm across to O's hand
	c.draw_colored_polygon(PackedVector2Array([Vector2(936, 822), Vector2(966, 822), Vector2(950, 900), Vector2(924, 900)]), near)
	c.draw_colored_polygon(PackedVector2Array([Vector2(972, 822), Vector2(996, 822), Vector2(984, 900), Vector2(960, 900)]), near)
	# the paper with the drawing, taped up in the beam of light (the drawing itself is a TextureRect)
	c.draw_rect(PAPER.grow(10.0), Color(0.58, 0.6, 0.7))  # the paper, in moonlight
	c.draw_rect(Rect2(PAPER.position + Vector2(PAPER.size.x * 0.5 - 30, -18), Vector2(60, 18)), Color(0.66, 0.68, 0.74, 0.8))


## The heart monitor's screen (in the silhouette on its stand, beside the bed): a green trace
## that sweeps left to right and spikes on every beep, a dot that flashes with it, a soft glow.
const MON_SCREEN := Rect2(408, 312, 136, 82)
const MON_SWEEP := 3.0  # seconds across the screen
const MON_GREEN := Color(0.45, 1.0, 0.6)

func _draw_monitor(c: Control) -> void:
	var r := MON_SCREEN
	var last: float = _beat_times.back() if _beat_times.size() > 0 else -9.0
	var since := _t - last
	var flash := clampf(1.0 - since / 0.35, 0.0, 1.0)
	for k in 3:  # the glow round the screen, a little brighter on the beat
		c.draw_rect(r.grow(10.0 + k * 12.0), Color(MON_GREEN, 0.03 + flash * 0.025))
	c.draw_rect(r, Color(0.01, 0.05, 0.03))
	var head := fmod(_t, MON_SWEEP) / MON_SWEEP  # the sweep: new trace written over the old
	var n := 68
	var prev := Vector2.ZERO
	for i in n + 1:
		var u := float(i) / n
		var age := head - u if u <= head else head + 1.0 - u  # how long ago (in sweeps) this was written
		if age > 0.94:
			continue  # the gap just ahead of the sweep
		var y := r.get_center().y + 8.0 - _ecg(_t - age * MON_SWEEP) * 30.0
		var p := Vector2(r.position.x + 4.0 + u * (r.size.x - 8.0), y)
		if i > 0 and prev != Vector2.ZERO:
			c.draw_line(prev, p, Color(MON_GREEN, 1.0 - age * 0.8), 2.0, true)
		prev = p
	c.draw_circle(Vector2(r.end.x - 10.0, r.position.y + 9.0), 3.5, Color(1.0, 0.35, 0.35, 0.25 + flash * 0.75))


## The trace's height at time `at`: a little bump, the spike on the beat, then a slow wave.
func _ecg(at: float) -> float:
	var dt := 99.0
	for b in _beat_times:
		if b <= at:
			dt = at - b
	if dt < 0.04:
		return dt / 0.04 * 1.0
	if dt < 0.08:
		return 1.0 - (dt - 0.04) / 0.04 * 1.35
	if dt < 0.12:
		return -0.35 + (dt - 0.08) / 0.04 * 0.35
	if dt < 0.45:
		return sin((dt - 0.12) / 0.33 * PI) * 0.18
	return 0.0


# ================================================================ per frame

func _physics_process(delta: float) -> void:
	_t += delta
	_beat_left -= delta
	if _beat_left <= 0.0:
		_beat_left = _next_interval()
		_on_beat()
	if _done or _retelling:
		return
	rig.update(delta)
	if player.is_on_floor() and rig.standing_heart < 0 and rig.hold < 0:
		_safe = player.position
		_save_section()
	if player.position.y > _safe.y + FALL and rig.hold < 0:
		_fail()
		return
	if Input.is_action_just_pressed("restart") and rig.hold < 0 and not Game.control_locked:
		player.teleport(_safe)
	_check_triggers()
	if Game.autoplay:
		_bot(delta)


func _process(delta: float) -> void:
	_update_sky()
	_update_pigeons(delta)
	_world.queue_redraw()
	if _monitor:
		_monitor.queue_redraw()


# ================================================================ the beat

## 1 = uneven (the foot), 0 = even (from "steady" up, and at the summit).
func unevenness() -> float:
	if _done:
		return 0.0
	return clampf((player.position.y - 3150.0) / (8200.0 - 3150.0), 0.0, 1.0)


func _next_interval() -> float:
	return lerpf(EVEN, EVEN * randf_range(SLIGHT.x, SLIGHT.y), unevenness())


func _on_beat() -> void:
	if _beat_fade > 0.02:
		Game.sfx("monitor", (-19.0 if not _room else -24.0) + linear_to_db(_beat_fade))  # quieter than at first (-12 / -20)
	_beat_times.append(_t)
	if _beat_times.size() > 8:
		_beat_times.remove_at(0)
	rig.kick(_t)
	if rig.standing_heart >= 0 and rig.hold < 0 and not _done and not Game.control_locked:
		rig.launch()


# ================================================================ stretch & swing

# ================================================================ pigeons (cameo)

func _pigeons_in() -> void:
	_pigeons_on = true
	var tex: Texture2D = load("res://assets/gen/ch3/pigeon_fly.png") if ResourceLoader.exists("res://assets/gen/ch3/pigeon_fly.png") else null
	for i in 4:
		var s := Sprite2D.new()
		s.texture = tex
		s.scale = Vector2.ONE * 0.45
		s.z_index = 3
		s.position = player.position + Vector2(-700 - i * 90, -200 + i * 40)
		s.set_meta("i", i)
		if tex == null:
			s.draw.connect(func(): s.draw_circle(Vector2.ZERO, 26.0, Color(0.6, 0.62, 0.7)))
		add_child(s)
		_pigeons.append(s)


func _update_pigeons(delta: float) -> void:
	if _pigeons.is_empty():
		return
	var leave := player.position.y < 1500.0 or _done
	for s in _pigeons:
		var i: int = s.get_meta("i")
		var target: Vector2
		if leave:
			target = s.position + Vector2(900, -500)
		else:
			# keeping up, a little ahead and above, bobbing (small and slow: no wobble)
			target = player.position + Vector2(-260 + i * 170, -260 - (i % 2) * 70 + sin(_t * 2.0 + i) * 14.0)
		s.position = s.position.lerp(target, clampf(delta * (0.8 if leave else 2.2), 0.0, 1.0))
		s.flip_h = target.x < s.position.x
		s.scale.y = 0.45 * (1.0 + sin(_t * 12.0 + i) * 0.08)
	if leave and _pigeons[0].position.y < player.position.y - 1400.0:
		for s in _pigeons:
			s.queue_free()
		_pigeons.clear()


# ================================================================ drawing

## 0 at the foot, 1 at the top: by the camera (not Blobb), so the sky moves smoothly.
func _sky_mix() -> float:
	if not camera:
		return 0.0
	var y := camera.get_screen_center_position().y - camera.offset.y
	return clampf((8400.0 - y) / (8400.0 - 1100.0), 0.0, 1.0)


## How far the sky has moved down the screen: the climb, then the look up.
func _sky_shift() -> float:
	return _sky_mix() * SKY_RISE + _up * SKY_PAN


## How much of the sky is out: more the higher he gets, all of it at the summit.
func _star_density() -> float:
	return maxf(lerpf(0.3, 1.0, _sky_mix()), _up) * _lit


func _make_stars() -> void:
	if ResourceLoader.exists(ART + STARS_SKY):
		_stars_sky = Sprite2D.new()
		_stars_sky.texture = load(ART + STARS_SKY)
		_stars_sky.centered = false
		_stars_sky.scale = Vector2.ONE * (1920.0 / _stars_sky.texture.get_width())
		# its bottom edge just under the screen's at the foot; its top at the screen's top at the end
		_stars_sky.offset.y = 640.0 / _stars_sky.scale.y - _stars_sky.texture.get_height()
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://shaders/sky_layer.gdshader")
		_stars_sky.material = mat
		_sky_top.add_child(_stars_sky)
		return  # (the milky way's glows and the nebulae are in the paintings too)
	var rng := RandomNumberGenerator.new()
	rng.seed = 55
	var reach := SKY_RISE + SKY_PAN
	for l in STAR_LAYERS:
		var arr: Array[Vector4] = []
		for i in int(l[1]):
			arr.append(Vector4(rng.randf() * 1920.0, rng.randf_range(-reach * l[0] - 80.0, 560.0), rng.randf(), rng.randf() * TAU))
		_stars.append(arr)
	# the milky way: a soft diagonal band of glows with dust of tiny stars, high up
	for i in 70:
		var x := -200.0 + i * 34.0
		var y := _milky_y(x) + rng.randf_range(-40.0, 40.0)
		_milky.append(Vector4(x, y, rng.randf_range(110.0, 220.0), rng.randf()))
	for i in 3200:
		var x := rng.randf() * 1920.0
		_milky_dust.append(Vector4(x, _milky_y(x) + rng.randfn(0.0, 95.0), rng.randf_range(0.35, 1.0), rng.randf() * TAU))
	for li in STAR_LAYERS.size():
		var size: float = STAR_LAYERS[li][2]
		var pts: Array = []
		for st: Vector4 in _stars[li]:
			pts.append([Vector2(st.x, st.y), size * (0.6 + 0.4 * (1.0 - st.z)) * 2.0, Color(st.z, st.w, 1.0 if size > 2.0 else 0.0, 0.0)])
		_star_nodes.append(_star_layer(pts, {"round": true}))
	var dust: Array = []
	for d: Vector4 in _milky_dust:
		dust.append([Vector2(d.x, d.y), 1.8, Color(d.z, d.w, 0.0, 0.0)])
	_dust_node = _star_layer(dust, {"round": false, "thresh_k": 0.6, "ramp": 0.3, "fade_over": 1.0, "tint": Color(0.95, 0.93, 1.0, 0.8)})
	for i in 14:  # faint clouds of colour, in the milky way's layer, over the sky the sweep reveals
		_nebula.append(Vector4(rng.randf_range(-100.0, 2020.0), rng.randf_range(-reach * MILKY_F - 200.0, -300.0), rng.randf_range(260.0, 520.0), rng.randf()))


## A layer of stars (or dust) as one MultiMesh, faded in and out by shaders/sky_stars.gdshader:
## [position, size, custom (threshold, twinkle phase, twinkles)] per star.
func _star_layer(pts: Array, params: Dictionary) -> MultiMeshInstance2D:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_custom_data = true
	mm.mesh = quad
	mm.instance_count = pts.size()
	for i in pts.size():
		var p: Array = pts[i]
		mm.set_instance_transform_2d(i, Transform2D(0.0, Vector2(p[1], p[1]), 0.0, p[0]))
		mm.set_instance_custom_data(i, p[2])
	var node := MultiMeshInstance2D.new()
	node.multimesh = mm
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/sky_stars.gdshader")
	for k in params:
		mat.set_shader_parameter(k, params[k])
	node.material = mat
	_sky_top.add_child(node)
	return node


func _milky_y(x: float) -> float:
	return -1150.0 - (x - 960.0) * 0.28 + sin(x * 0.004) * 40.0  # in its layer (MILKY_F): the sweep up reveals it


func _update_sky() -> void:
	var shift := _sky_shift()
	if _sky_sprites.has("night"):
		_sky_sprites["night"].modulate.a = lerpf(0.4, 1.0, _lit)
		_sky_sprites["night"].position.y = shift
	_sky.position.y = shift
	var reach := SKY_RISE + SKY_PAN
	if _sky_sprites.has("moon"):
		_sky_sprites["moon"].position = MOON_AT + Vector2(0, shift - reach)
		_sky_sprites["moon"].modulate = Color(1, 1, 1, _moon)
	if _sky_sprites.has("star"):
		_sky_sprites["star"].position = STAR_AT + Vector2(0, shift - reach)
		var breathe := 0.85 + 0.15 * sin(_t * 1.3)
		_sky_sprites["star"].modulate = Color(breathe, breathe, breathe, _moon)
	_sky.queue_redraw()
	_sky_top.queue_redraw()
	# the stars only move (parallax) and fade; the GPU does the rest
	var dens := _star_density()
	var horizon := shift + 430.0
	if _stars_sky:
		# scrolls so that the whole picture passes between the foot and the end of the sweep
		var h := _stars_sky.texture.get_height() * _stars_sky.scale.y
		_stars_sky.position.y = shift * (h - 640.0) / (SKY_RISE + SKY_PAN)
		(_stars_sky.material as ShaderMaterial).set_shader_parameter("alpha", _lit)  # out once Y tells them
		(_stars_sky.material as ShaderMaterial).set_shader_parameter("horizon", horizon)
	for li in _star_nodes.size():
		var n := _star_nodes[li]
		n.position.y = shift * float(STAR_LAYERS[li][0])
		(n.material as ShaderMaterial).set_shader_parameter("dens", dens)
		(n.material as ShaderMaterial).set_shader_parameter("horizon", horizon)
	if _dust_node:
		_dust_node.position.y = shift * MILKY_F
		(_dust_node.material as ShaderMaterial).set_shader_parameter("dens", smoothstep(0.55, 1.0, dens))
		(_dust_node.material as ShaderMaterial).set_shader_parameter("horizon", horizon)


## Behind the picture (or instead of it): the night gradient and far ranges.
func _draw_sky() -> void:
	var top := Color(0.03, 0.04, 0.12)
	var low := Color(0.12, 0.12, 0.28)
	for i in 30:
		_sky.draw_rect(Rect2(0, i * 36, 1920, 37), top.lerp(low, i / 29.0))
	var pts := PackedVector2Array([Vector2(0, 1080)])
	for x in range(0, 1921, 80):
		pts.append(Vector2(x, 820 + sin(x * 0.006) * 50.0 + sin(x * 0.017) * 22.0))
	pts.append(Vector2(1920, 1080))
	_sky.draw_colored_polygon(pts, Color(0.12, 0.13, 0.24))


## Above the picture: the deep sky it sinks away from, the stars (in parallax layers, more of
## them the higher he gets), the milky way near the top, a shooting star, and at the very end the
## moon and the bright star (the narrators' signs, the icons by their lines).
func _draw_sky_top() -> void:
	var shift := _sky_shift()
	var dens := _star_density()
	var deep := Color(0.01, 0.015, 0.06)
	var edge := _sky_top_color()
	# above the picture's top edge: up into the deep night, and a soft join (no seam)
	_vgrad(shift - 700.0, shift + 1.0, deep, edge)
	if shift - 700.0 > 0.0:
		_sky_top.draw_rect(Rect2(0, 0, 1920, shift - 700.0), deep)
	_vgrad(shift - 1.0, shift + 220.0, edge, Color(edge, 0.0))
	var horizon := shift + 430.0  # the picture's far ranges: no stars over them
	# the milky way, high up: it comes out over the last part of the climb
	var mw := smoothstep(0.55, 1.0, dens)
	if mw > 0.0:
		for g in _nebula:
			var at := Vector2(g.x, g.y + shift * MILKY_F)
			if at.y > -g.z and at.y < horizon + g.z:
				var col := Color(0.35, 0.3, 0.75).lerp(Color(0.25, 0.55, 0.8), g.w).lerp(Color(0.7, 0.35, 0.6), maxf(0.0, g.w - 0.75) * 3.0)
				_halo(at, g.z, Color(col, 0.11 * mw))
		for g in _milky:
			var at := Vector2(g.x, g.y + shift * MILKY_F)
			if at.y > -g.z and at.y < horizon:
				var col := Color(0.55, 0.45, 0.85).lerp(Color(0.4, 0.6, 0.95), g.w)
				_halo(at, g.z, Color(col, 0.26 * mw))
	# (the stars and the milky way's dust are MultiMeshes, see _star_layer and _update_sky)
	# one shooting star while Blobb looks up
	if _shoot >= 0.0:
		var k := (_t - _shoot) / 1.1
		if k < 1.0:
			var from := Vector2(1500, 140)
			var dir := Vector2(-1, 0.42).normalized()
			var head := from + dir * 900.0 * k
			var tail := head - dir * 220.0 * (1.0 - k * 0.5)
			var fade := sin(k * PI)
			_sky_top.draw_line(tail, head, Color(1, 1, 0.95, 0.0), 1.0)
			_sky_top.draw_polygon(PackedVector2Array([tail, head + Vector2(0, -1.5), head + Vector2(0, 1.5)]),
				PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 0.95, 0.9 * fade), Color(1, 1, 0.95, 0.9 * fade)]))
	# the moon (warm, like O's) and the star (cool, like Y's), side by side, when they come out.
	# The painted ones are sprites (additive, see _update_sky); without them, the icon shapes.
	if _moon > 0.0:
		var reach := SKY_RISE + SKY_PAN
		var moon := MOON_AT + Vector2(0, shift - reach)
		var star := STAR_AT + Vector2(0, shift - reach)
		var breathe := 0.85 + 0.15 * sin(_t * 1.3)
		_halo(moon, 330.0, Color(1.0, 0.92, 0.78, 0.3 * _moon))
		_halo(star, 260.0, Color(0.78, 0.92, 1.0, 0.4 * breathe * _moon))
		if not _sky_sprites.has("moon"):
			_shape(NarratorIcon.moon_points(90.0), moon, Color(1.0, 0.95, 0.84, 0.95 * _moon))
		if not _sky_sprites.has("star"):
			_shape(NarratorIcon.star_points(48.0), star, Color(0.9, 0.97, 1.0, _moon))
			_sky_top.draw_circle(star, 16.0, Color(1, 1, 1, 0.9 * breathe * _moon))


## A smooth vertical gradient across the screen (vertex colours, so no bands).
func _vgrad(y0: float, y1: float, c0: Color, c1: Color) -> void:
	_sky_top.draw_polygon(PackedVector2Array([Vector2(0, y0), Vector2(1920, y0), Vector2(1920, y1), Vector2(0, y1)]),
		PackedColorArray([c0, c0, c1, c1]))


var _halo_tex: GradientTexture2D


## A soft round glow (a radial gradient), no rings.
func _halo(at: Vector2, r: float, col: Color) -> void:
	if not _halo_tex:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.35, Color(1, 1, 1, 0.35))
		_halo_tex = GradientTexture2D.new()
		_halo_tex.gradient = g
		_halo_tex.fill = GradientTexture2D.FILL_RADIAL
		_halo_tex.fill_from = Vector2(0.5, 0.5)
		_halo_tex.fill_to = Vector2(1.0, 0.5)
		_halo_tex.width = 256
		_halo_tex.height = 256
	_sky_top.draw_texture_rect(_halo_tex, Rect2(at - Vector2(r, r), Vector2(r, r) * 2.0), false, col)


func _shape(pts: PackedVector2Array, at: Vector2, col: Color) -> void:
	for i in pts.size():
		pts[i] += at
	_sky_top.draw_colored_polygon(pts, col)


## The colour at the top edge of the night picture, so the sky above it joins without a seam.
var _top_col := Color(-1, 0, 0)


func _sky_top_color() -> Color:
	if _top_col.r >= 0.0:
		return _top_col
	_top_col = Color(0.03, 0.04, 0.12)  # the drawn night's top
	var spr: Sprite2D = _sky_sprites.get("night")
	if spr:
		var img := spr.texture.get_image()
		if img:
			if img.is_compressed():
				img.decompress()
			var sum := Color(0, 0, 0)
			var n := 0
			for x in range(0, img.get_width(), 16):
				for y in 3:
					sum += img.get_pixel(x, y)
					n += 1
			_top_col = Color(sum.r / n, sum.g / n, sum.b / n)
	return _top_col


func _draw_world() -> void:
	# the mountain's walls at both sides: the painted rock strip, tinted to the hour
	var mood := Color(0.42, 0.42, 0.62).lerp(Color(0.56, 0.56, 0.8), _sky_mix())  # starlight, a little brighter up high
	if _tex.has("cliff_bg"):
		var tex: Texture2D = _tex["cliff_bg"]
		var src := Rect2(1640, 0, 280, tex.get_height())
		var w := 220.0
		var h := tex.get_height() * w / src.size.x
		var y := TOP - 600.0
		# the top of the walls fades into the sky just above the summit view, so the sweep up
		# leaves them behind (drawn in strips)
		const FADE := 600.0
		const STRIP := 20.0
		var k := src.size.x / w  # source pixels per world pixel
		for i in int(FADE / STRIP):
			var c := Color(mood, smoothstep(0.0, 1.0, (i + 0.5) * STRIP / FADE))
			var s_rect := Rect2(src.position.x, i * STRIP * k, src.size.x, STRIP * k)
			_world.draw_texture_rect_region(tex, Rect2(W - w, y + i * STRIP, w, STRIP + 0.5), s_rect, c)
			_world.draw_set_transform(Vector2(w, 0), 0.0, Vector2(-1, 1))
			_world.draw_texture_rect_region(tex, Rect2(0, y + i * STRIP, w, STRIP + 0.5), s_rect, c)
			_world.draw_set_transform(Vector2.ZERO)
		var first := true
		while y < GROUND + 600.0:
			var skip := FADE if first else 0.0  # the faded strips already drew the first tile's top
			var part := Rect2(src.position.x, skip * k, src.size.x, src.size.y - skip * k)
			_world.draw_texture_rect_region(tex, Rect2(W - w, y + skip, w, h - skip), part, mood)
			_world.draw_set_transform(Vector2(w, 0), 0.0, Vector2(-1, 1))  # mirrored for the left wall
			_world.draw_texture_rect_region(tex, Rect2(0, y + skip, w, h - skip), part, mood)
			_world.draw_set_transform(Vector2.ZERO)
			first = false
			y += h
	else:
		var rock := Color(0.16, 0.15, 0.24).lerp(Color(0.32, 0.3, 0.42), _sky_mix())
		_world.draw_rect(Rect2(-40, TOP - 600, 260, GROUND - TOP + 1200), rock.darkened(0.15))
		_world.draw_rect(Rect2(W - 220, TOP - 600, 260, GROUND - TOP + 1200), rock.darkened(0.15))
	for i in LEDGES.size():
		_draw_ledge(LEDGES[i], i == 0, -1)
	for i in HEARTS.size():
		_draw_ledge(HEARTS[i], false, i)
	for i in HOLDS.size():
		_draw_hold(i)


func _draw_ledge(r: Array, ground: bool, heart: int) -> void:
	var x0: float = r[0]
	var x1: float = r[1]
	var top: float = r[2]
	var k := 0.0
	if heart >= 0:
		k = clampf(1.0 - (_t - rig.kicked.get(heart, -9.0)) / 0.3, 0.0, 1.0)
	var up := sin(k * PI) * 16.0
	if ground:
		_world.draw_rect(Rect2(x0, top, x1 - x0, 600), Color(0.2, 0.18, 0.26))
		_world.draw_rect(Rect2(x0, top, x1 - x0, 10), Color(0.42, 0.4, 0.5))
		return
	var key := "ledge_heart" if heart >= 0 else "ledge_rock"
	if _tex.has(key):
		var tex: Texture2D = _tex[key]
		var sy := 0.8
		var dest := Rect2(x0 - 14.0, top - up - 20.0 * sy, x1 - x0 + 28.0, tex.get_height() * sy)
		if heart >= 0:
			_world.draw_texture_rect(tex, dest.grow(8.0 * k), false, Color(1, 0.7, 0.75, 0.4 * k))
		_world.draw_texture_rect(tex, dest, false)
		return
	var body := Color(0.36, 0.33, 0.45) if heart < 0 else Color(0.74, 0.34, 0.44).lerp(Color(1.0, 0.6, 0.66), k)
	var rect := Rect2(x0, top - up, x1 - x0, 44)
	if heart >= 0:
		_world.draw_rect(rect.grow(6.0 * k), Color(1.0, 0.45, 0.55, 0.35 * k))
	_world.draw_rect(rect, body)
	_world.draw_rect(Rect2(rect.position, Vector2(rect.size.x, 8)), body.lightened(0.35))


func _draw_hold(i: int) -> void:
	var c := rig.holds[i]
	var star: bool = HOLDS[i][2] == "star"
	var lit := rig.can_reach and i == rig.aim and rig.hold < 0
	var a := 1.0 if rig.can_reach else 0.45
	if lit:
		_world.draw_arc(c, 40.0 + sin(_t * 8.0) * 4.0, 0.0, TAU, 32, Color(1.0, 0.9, 0.5, 0.8), 4.0)
	var key := "hold_star" if star else "hold_root"
	if _tex.has(key):
		var tex: Texture2D = _tex[key]
		var s := 110.0
		_world.draw_texture_rect(tex, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), false, Color(1, 1, 1, a))
		return
	if star:
		for k in 4:
			var ang := k * PI * 0.25 + _t * 0.2
			_world.draw_line(c - Vector2(cos(ang), sin(ang)) * 34.0, c + Vector2(cos(ang), sin(ang)) * 34.0, Color(1.0, 0.95, 0.75, 0.6 * a), 3.0)
		_world.draw_circle(c, 16.0, Color(1.0, 0.95, 0.8, a))
	else:
		_world.draw_circle(c, 22.0, Color(0.55, 0.38, 0.2, a))
		_world.draw_circle(c, 14.0, Color(0.95, 0.75, 0.3, a))


# ================================================================ test bot (--autoplay)

## Hops ledge to ledge (teleporting) so the whole story runs through, up to the end card.
func _bot(delta: float) -> void:
	if Narrator.busy or Game.control_locked:
		return
	_bot_wait -= delta
	if _bot_wait > 0.0:
		return
	_bot_wait = 0.6
	_bot_i += 1
	if _bot_i >= LEDGES.size():
		return
	var l: Array = LEDGES[_bot_i]
	var p := Vector2((l[0] + l[1]) * 0.5, l[2])
	if _bot_i == LEDGES.size() - 1:
		p.x = l[0] + 120.0
	if p.y < player.position.y - 5.0:
		player.teleport(p)
		print("BOT ledge ", _bot_i, " at ", p)

# ================================================================ checking from outside

## For gda (`gda game call /root/<Level> debug_state`): see scripts/debug_state.gd. Read-only.
const GDA_CALLABLE := ["debug_state"]


func debug_state() -> Dictionary:
	var d := DebugState.base(player)
	d.merge(DebugState.json({"fired": _fired.keys(), "stretch": rig.can_reach, "hold": rig.hold, "standing_heart": rig.standing_heart, "done": _done, "moon": _moon, "sky": _sky_mix()}), true)
	return d
