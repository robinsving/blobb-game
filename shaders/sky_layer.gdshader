shader_type canvas_item;
render_mode blend_add;
// A painted star layer for ch5 (stars_far/stars_near/milky_way.png, on black): drawn additively,
// faded in as Blobb climbs (`alpha`), and hidden over the far ranges below `horizon` (screen y).

uniform float alpha = 0.0;
uniform float horizon = 2000.0;
uniform float fade_over = 160.0;

varying float screen_y;

void vertex() {
	screen_y = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).y;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = alpha * (1.0 - smoothstep(horizon - fade_over, horizon, screen_y));
	COLOR = vec4(c.rgb * a, 1.0);
}
