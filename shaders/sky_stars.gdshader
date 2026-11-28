shader_type canvas_item;
// Ch5's stars and milky-way dust, drawn on the GPU (one MultiMesh per layer) instead of one
// draw call per star from GDScript every frame, which stuttered in the browser.
// Per instance (INSTANCE_CUSTOM): x = threshold (the star comes out once `dens` passes it),
// y = twinkle phase, z = 1 if it twinkles, w = unused.
// The script moves each layer (parallax) and sets dens/horizon; nothing else runs per star.

uniform float dens = 0.0;         // how far the stars have come out (0..1), or the milky way's
uniform float horizon = 2000.0;   // screen y of the far ranges: no stars below, a fade above
uniform float fade_over = 160.0;  // how far above the horizon they fade out
uniform float ramp = 0.12;        // how quickly one star fades in past its threshold
uniform float thresh_k = 1.0;     // threshold scale (the dust uses 0.6)
uniform vec4 tint : source_color = vec4(1.0, 1.0, 0.94, 0.85);
uniform bool round = true;        // stars are round dots, the dust is tiny squares

varying float alpha;

void vertex() {
	float y = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).y;
	float a = clamp((dens - INSTANCE_CUSTOM.x * thresh_k) / ramp, 0.0, 1.0);
	a *= 1.0 - smoothstep(horizon - fade_over, horizon, y);
	if (INSTANCE_CUSTOM.z > 0.5) {
		a *= 0.75 + 0.25 * sin(TIME * 1.7 + INSTANCE_CUSTOM.y);
	}
	alpha = a;
}

void fragment() {
	float edge = 1.0;
	if (round) {
		float d = length(UV - vec2(0.5)) * 2.0;
		edge = 1.0 - smoothstep(0.8, 1.0, d);
	}
	COLOR = vec4(tint.rgb, tint.a * alpha * edge);
}
