extends Node2D
## Fallback crayon-style crate (top-down), used when no generated crate texture exists.

const S := 84.0


func _draw() -> void:
	var h := S * 0.5
	var wood := Color(0.72, 0.5, 0.26)
	var dark := Color(0.38, 0.22, 0.1)
	draw_rect(Rect2(-h + 5, -h + 7, S, S), Color(0, 0, 0, 0.25))
	draw_rect(Rect2(-h, -h, S, S), wood)
	for k in 3:
		var y := -h + S * (k + 1) / 4.0
		draw_line(Vector2(-h + 4, y), Vector2(h - 4, y), Color(0.55, 0.36, 0.17), 2.0)
	draw_line(Vector2(-h + 6, -h + 6), Vector2(h - 6, h - 6), dark, 6.0)
	draw_line(Vector2(h - 6, -h + 6), Vector2(-h + 6, h - 6), dark, 6.0)
	draw_rect(Rect2(-h, -h, S, S), dark, false, 5.0)
