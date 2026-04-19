shader_type canvas_item;

varying vec4 v_vertex_color;

uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.0, 0.62);
uniform vec2 shadow_offset_px = vec2(2.0, 2.0);
uniform float shadow_softness : hint_range(0.0, 3.0) = 0.75;

void vertex() {
	v_vertex_color = COLOR;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 ps = TEXTURE_PIXEL_SIZE;
	vec2 off = shadow_offset_px * ps;

	float a = texture(TEXTURE, UV - off).a;
	if (shadow_softness > 0.001) {
		float s = shadow_softness;
		a += texture(TEXTURE, UV - off - vec2(s, 0.0) * ps).a;
		a += texture(TEXTURE, UV - off + vec2(s, 0.0) * ps).a;
		a += texture(TEXTURE, UV - off - vec2(0.0, s) * ps).a;
		a += texture(TEXTURE, UV - off + vec2(0.0, s) * ps).a;
		a *= 0.2;
	}

	float shadow_a = shadow_color.a * a;
	vec3 shadow_rgb = shadow_color.rgb * shadow_a;

	float out_a = tex.a + shadow_a * (1.0 - tex.a);
	if (out_a < 0.0001) {
		COLOR = vec4(0.0);
	} else {
		vec3 out_rgb = (tex.rgb * tex.a + shadow_rgb * (1.0 - tex.a)) / out_a;
		COLOR = vec4(out_rgb, out_a) * v_vertex_color;
	}
}
