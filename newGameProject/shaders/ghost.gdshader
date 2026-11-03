shader_type spatial;
render_mode blend_mix, unshaded, cull_back, depth_draw_never;

uniform vec3 tint = vec3(0.6, 0.7, 1.0);
uniform float strength = 1.0;

void vertex() {
	// A slow ripple so the figure never quite holds still.
	float wobble = sin(TIME * 3.0 + VERTEX.y * 7.0) * 0.015 + sin(TIME * 7.0 + VERTEX.x * 11.0) * 0.008;
	VERTEX += NORMAL * wobble;
}

void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 1.8);
	float band = 0.8 + 0.2 * sin(TIME * 13.0 + FRAGCOORD.y * 0.4);
	ALBEDO = mix(tint * 0.25, tint * 1.4, rim);
	ALPHA = clamp((0.42 + rim * 0.75) * band * strength, 0.0, 1.0);
}
