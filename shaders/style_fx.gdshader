shader_type canvas_item;
// Full-screen post-process that lets the narrators restyle the world:
// crayon/child drawing (posterize + outline + paper + boil), dark/realistic, monochrome, tints, fade to white.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float saturation = 1.0;
uniform float posterize = 0.0;     // 0..1 mix toward posterized colour
uniform float levels = 6.0;
uniform float paper = 0.0;         // paper grain + warm tint
uniform float wobble = 0.0;        // hand-drawn "boil"
uniform float outline = 0.0;       // dark crayon edges
uniform float darkness = 0.0;
uniform float vignette = 0.25;
uniform vec4 tint : source_color = vec4(1.0);
uniform float tint_amount = 0.0;
uniform float white = 0.0;         // fade to white
uniform float contrast = 1.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
	           mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float lum(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

void fragment() {
	vec2 uv = SCREEN_UV;
	float boil = floor(TIME * 6.0);
	vec2 w = vec2(noise(uv * vec2(14.0, 9.0) + boil * 1.7), noise(uv * vec2(9.0, 14.0) - boil * 2.3)) - 0.5;
	uv += w * wobble * 0.0045;
	vec3 c = textureLod(screen_tex, uv, 0.0).rgb;

	if (outline > 0.001) {
		vec2 px = SCREEN_PIXEL_SIZE * 1.6;
		float lx = lum(textureLod(screen_tex, uv + vec2(px.x, 0.0), 0.0).rgb) - lum(textureLod(screen_tex, uv - vec2(px.x, 0.0), 0.0).rgb);
		float ly = lum(textureLod(screen_tex, uv + vec2(0.0, px.y), 0.0).rgb) - lum(textureLod(screen_tex, uv - vec2(0.0, px.y), 0.0).rgb);
		float e = smoothstep(0.06, 0.25, length(vec2(lx, ly)));
		e *= 0.6 + 0.4 * noise(uv * vec2(300.0, 40.0));  // broken, crayon-like line
		c = mix(c, c * 0.22, e * outline);
	}

	vec3 pc = floor(c * levels + 0.5) / levels;
	c = mix(c, pc, posterize);

	c = (c - 0.5) * contrast + 0.5;
	float g = lum(c);
	c = mix(vec3(g), c, saturation);
	c *= mix(vec3(1.0), tint.rgb * 1.25, tint_amount);

	float n = noise(SCREEN_UV * vec2(1400.0, 840.0)) * 0.6 + noise(SCREEN_UV * vec2(160.0, 100.0)) * 0.4;
	float fib = noise(vec2(SCREEN_UV.x * 60.0 + SCREEN_UV.y * 30.0, SCREEN_UV.y * 900.0));
	c *= 1.0 - paper * (0.07 * n + 0.035 * fib);
	c = mix(c, c * vec3(1.0, 0.96, 0.88) + vec3(0.05, 0.04, 0.02), paper * 0.6);

	c *= 1.0 - darkness;
	float v = distance(SCREEN_UV, vec2(0.5));
	c *= 1.0 - vignette * smoothstep(0.3, 0.85, v);
	c = mix(c, vec3(1.0, 0.99, 0.97), white);
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
