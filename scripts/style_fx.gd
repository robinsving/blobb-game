class_name StyleFX
extends CanvasLayer
## Full-screen look controller. Add one per level; narrator lines call set_look()/tint().
## Sits above the world (layer 40) and below the narrator text (layer 60).

const LOOKS := {
	"plain":  {"saturation": 1.0, "posterize": 0.0, "paper": 0.0, "wobble": 0.0, "outline": 0.0, "darkness": 0.0, "vignette": 0.25, "contrast": 1.0},
	"paper":  {"saturation": 1.0, "posterize": 0.0, "paper": 1.0, "wobble": 0.6, "outline": 0.0, "darkness": 0.0, "vignette": 0.15, "contrast": 1.0},
	"crayon": {"saturation": 1.25, "posterize": 0.55, "paper": 0.75, "wobble": 1.0, "outline": 0.7, "darkness": 0.0, "vignette": 0.2, "contrast": 1.05},
	"dark":   {"saturation": 0.3, "posterize": 0.0, "paper": 0.0, "wobble": 0.0, "outline": 0.0, "darkness": 0.45, "vignette": 0.8, "contrast": 1.2},
	"mono":   {"saturation": 0.0, "posterize": 0.0, "paper": 0.35, "wobble": 0.3, "outline": 0.3, "darkness": 0.0, "vignette": 0.35, "contrast": 1.15},
	"real":   {"saturation": 1.05, "posterize": 0.0, "paper": 0.0, "wobble": 0.0, "outline": 0.0, "darkness": 0.0, "vignette": 0.35, "contrast": 1.05},
}

var look := "plain"
var _rect: ColorRect
var _mat: ShaderMaterial
var _tween: Tween


func _init() -> void:
	layer = 40
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.size = Vector2(1920, 1080)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://shaders/style_fx.gdshader")
	_rect.material = _mat
	add_child(_rect)
	set_look("plain", 0.0)


func set_look(name: String, dur := 1.2) -> void:
	look = name
	var preset: Dictionary = LOOKS[name]
	if _tween:
		_tween.kill()
	if dur <= 0.0:
		for k in preset:
			_mat.set_shader_parameter(k, preset[k])
		return
	_tween = create_tween().set_parallel()
	for k in preset:
		_tween.tween_method(func(v): _mat.set_shader_parameter(k, v), _param(k), preset[k], dur)


func tint(color: Color, amount: float, dur := 2.0) -> void:
	_mat.set_shader_parameter("tint", color)
	var tw := create_tween()
	tw.tween_method(func(v): _mat.set_shader_parameter("tint_amount", v), _param("tint_amount"), amount, dur)


func white(to: float, dur := 1.0) -> void:
	var tw := create_tween()
	tw.tween_method(func(v): _mat.set_shader_parameter("white", v), _param("white"), to, dur)
	await tw.finished


## Brief "the storyteller is rewinding" warble.
func rewind_pulse(dur := 1.0) -> void:
	var tw := create_tween()
	var base_w: float = _param("wobble")
	var base_s: float = _param("saturation")
	tw.set_parallel()
	tw.tween_method(func(v): _mat.set_shader_parameter("wobble", v), base_w, 6.0, dur * 0.4)
	tw.tween_method(func(v): _mat.set_shader_parameter("saturation", v), base_s, 0.1, dur * 0.4)
	tw.chain().set_parallel()
	tw.tween_method(func(v): _mat.set_shader_parameter("wobble", v), 6.0, base_w, dur * 0.6)
	tw.tween_method(func(v): _mat.set_shader_parameter("saturation", v), 0.1, base_s, dur * 0.6)


func _param(param: StringName) -> Variant:
	var v = _mat.get_shader_parameter(param)
	return 0.0 if v == null else v
