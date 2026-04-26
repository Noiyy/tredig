shader_type canvas_item;

uniform vec4 ice_tint : source_color = vec4(0.36, 0.66, 1.0, 1.0);
uniform float desaturate_amount : hint_range(0.0, 1.0) = 0.55;
uniform float frost_strength : hint_range(0.0, 1.0) = 0.56;
uniform float blue_tint_strength : hint_range(0.0, 1.0) = 0.62;
uniform float shimmer_speed : hint_range(0.0, 4.0) = 1.25;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 34.45);
	return fract(p.x * p.y);
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	if (tex.a > 0.001) {
		float gray = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
		vec3 desat = mix(tex.rgb, vec3(gray), desaturate_amount);

		// Fine frost grain + subtle animated shimmer so frozen players look icy.
		float grain = hash21(UV * 128.0 + floor(TIME * shimmer_speed));
		float frost_mask = smoothstep(0.55, 1.0, grain);
		vec3 frosted = mix(desat, ice_tint.rgb, frost_mask * frost_strength);
		frosted = mix(frosted, ice_tint.rgb, blue_tint_strength);

		// Slight vertical light band to mimic icy reflection.
		float shine = 0.08 * sin((UV.y * 26.0) + TIME * shimmer_speed * 2.0);
		frosted += shine;

		COLOR = vec4(clamp(frosted, 0.0, 1.0), tex.a) * COLOR;
	} else {
		COLOR = tex;
	}
}
