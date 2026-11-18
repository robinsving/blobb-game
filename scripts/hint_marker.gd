class_name HintMarker
extends Node2D
## A puzzle hint drawn in the world: a pulsing gold ring on the thing to use next, with a little
## bobbing arrow (pointing down at it, or along `dir` for a push), and an optional trail of dots
## (the way to walk there). Fades out by itself. Motion is small and slow (no screen wobble).

var radius := 70.0
var dir := Vector2.ZERO            # a push direction, or zero for "this one"
var trail := PackedVector2Array()  # dots to follow, in this node's parent's space
var life := 7.0
var _t := 0.0


## Puts a marker at `pos` in `parent` (a world node) and frees any earlier one from `old`.
static func at(parent: Node, pos: Vector2, radius := 70.0, dir := Vector2.ZERO, trail := PackedVector2Array(), old: HintMarker = null) -> HintMarker:
	if is_instance_valid(old):
		old.queue_free()
	var m := HintMarker.new()
	m.position = pos
	m.radius = radius
	m.dir = dir
	for p in trail:
		m.trail.append(p - pos)
	m.z_index = 20
	parent.add_child(m)
	Game.sfx("pop", -10.0, 1.3)
	return m


func _process(delta: float) -> void:
	_t += delta
	modulate.a = clampf(minf(_t / 0.3, (life - _t) / 1.0), 0.0, 1.0)
	if _t >= life:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var gold := Color(1.0, 0.86, 0.35)
	for i in trail.size():
		var a := clampf((_t * 3.0 - i * 0.25), 0.0, 1.0)
		draw_circle(trail[i], 9.0, Color(gold, 0.75 * a))
	var r := radius + sin(_t * 5.0) * 6.0
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(gold, 0.9), 6.0)
	draw_arc(Vector2.ZERO, r + 12.0, 0.0, TAU, 48, Color(gold, 0.3), 4.0)
	var d := dir.normalized() if dir != Vector2.ZERO else Vector2.DOWN
	# the arrow sits outside the ring, behind the direction it points, and bobs along it
	var bob := sin(_t * 4.0) * 8.0
	var tip := -d * (radius + 18.0) + d * bob if dir == Vector2.ZERO else d * (radius + 60.0) + d * bob
	var side := Vector2(-d.y, d.x)
	var base := tip - d * 44.0
	draw_colored_polygon(PackedVector2Array([tip, base + side * 26.0, base - side * 26.0]), gold)
	draw_line(base, base - d * 36.0, gold, 12.0)
