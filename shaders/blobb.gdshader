shader_type canvas_item;
// Recolours Blobb while keeping his crayon texture and dark eyes.

uniform vec4 tint : source_color = vec4(0.55, 0.8, 0.3, 1.0);
uniform float tint_amount = 0.0;
uniform vec4 glow_color : source_color = vec4(1.0, 0.9, 0.3, 1.0);
uniform float glow = 0.0;
uniform float flash = 0.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 colored = tint.rgb * smoothstep(0.05, 0.85, l) * 1.35;
	c.rgb = mix(c.rgb, colored, tint_amount);
	c.rgb += glow_color.rgb * glow * 0.35;
	c.rgb = mix(c.rgb, vec3(1.0), flash);
	COLOR = c;
}
