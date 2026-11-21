class_name NarratorIcon
extends Control
## Small emblem next to a narrator's text: a soft round-edged star for the younger narrator,
## a crescent moon for the older one. Drawn procedurally (no texture).

enum Kind { STAR, MOON }

var kind := Kind.STAR
var color := Color.WHITE
var radius := 24.0


func _init(k: Kind = Kind.STAR, c: Color = Color.WHITE) -> void:
	kind = k
	color = c
	size = Vector2(radius, radius) * 2.4
	pivot_offset = size * 0.5
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Small one-off "pop" when this narrator starts speaking (brief, no continuous motion).
func pop() -> void:
	scale = Vector2.ONE * 1.25
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _draw() -> void:
	var pts := _star() if kind == Kind.STAR else _moon()
	var c := size * 0.5
	for i in pts.size():
		pts[i] += c
	# soft shadow, fill, outline
	var shadow := PackedVector2Array()
	for p in pts:
		shadow.append(p + Vector2(2, 3))
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.45))
	draw_colored_polygon(pts, color)
	var loop := pts.duplicate()
	loop.append(pts[0])
	draw_polyline(loop, Color(0.08, 0.06, 0.05, 0.8), 2.5, true)


## Five-pointed star with rounded tips and valleys: r(t) blends between inner and outer radius.
func _star() -> PackedVector2Array:
	return star_points(radius)


func _moon() -> PackedVector2Array:
	return moon_points(radius)


## The shapes on their own (centred on 0,0), also used for the moon and star in ch5's last sky.
static func star_points(radius: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := 80
	for i in n:
		var t := TAU * i / n - PI / 2.0
		var k := (cos(5.0 * (t + PI / 2.0)) + 1.0) * 0.5   # 1 at tips, 0 in valleys
		out.append(Vector2(cos(t), sin(t)) * radius * (0.6 + 0.4 * k))
	return out


## Crescent: the outer circle's arc outside an offset inner circle, then the inner arc back.
static func moon_points(radius: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var c1 := Vector2.ZERO
	var r1 := radius
	var c2 := Vector2(radius * 0.45, -radius * 0.3)
	var r2 := radius * 0.85
	var away := (c1 - c2).angle()
	var n := 96
	for k in range(-n / 2, n / 2 + 1):
		var p := c1 + Vector2.from_angle(away + TAU * k / n) * r1
		if p.distance_to(c2) > r2:
			out.append(p)
	for k in range(n / 2, -n / 2 - 1, -1):
		var p := c2 + Vector2.from_angle(away + TAU * k / n) * r2
		if p.distance_to(c1) < r1:
			out.append(p)
	return out
