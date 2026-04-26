shader_type canvas_item;

uniform vec4 polygon_tint : source_color = vec4(0.62, 0.58, 0.5, 1.0);
uniform vec4 polygon_edge_tint : source_color = vec4(0.86, 0.82, 0.74, 1.0);
uniform float overlay_alpha : hint_range(0.0, 1.0) = 0.62;
uniform float polygon_strength : hint_range(0.0, 1.0) = 1.0;
uniform float tile_size_px : hint_range(4.0, 64.0) = 16.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float sd_ngon(vec2 p, float radius, float n_sides) {
	float an = 6.28318530718 / n_sides;
	float a = atan(p.x, p.y) + 3.14159265359;
	float b = floor(0.5 + a / an) * an - a;
	return length(p) * cos(b) - radius;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	if (tex.a <= 0.001) {
		COLOR = tex;
	} else {
		// Per-tile random seed from world pixel position.
		vec2 tile_coord = floor(FRAGCOORD.xy / tile_size_px);
		vec2 tile_local = fract(FRAGCOORD.xy / tile_size_px);
		float edge_mask = 0.0;
		float fill_mask = 0.0;
		vec2 c0 = vec2(-10.0);
		vec2 c1 = vec2(-10.0);
		vec2 c2 = vec2(-10.0);
		vec2 c3 = vec2(-10.0);
		float r0 = 0.0;
		float r1 = 0.0;
		float r2 = 0.0;
		float r3 = 0.0;
		int accepted = 0;

		// Random 2-4 n-gons per tile; each has 4-7 sides and keeps distance from others.
		float poly_count = 2.0 + floor(hash21(tile_coord + vec2(17.4, 3.1)) * 3.0); // 2..4
		for (int i = 0; i < 4; i++) {
			if (float(i) >= poly_count) {
				continue;
			}
			float fi = float(i);
			vec2 seed = tile_coord + vec2(fi * 13.1, fi * 7.7);
			vec2 center = vec2(
				0.2 + hash21(seed + vec2(1.3, 2.7)) * 0.6,
				0.2 + hash21(seed + vec2(4.9, 8.2)) * 0.6
			);
			float sides = 4.0 + floor(hash21(seed + vec2(6.1, 3.4)) * 4.0); // 4..7
			float radius = 0.10 + hash21(seed + vec2(9.7, 5.5)) * 0.11;
			float rot = hash21(seed + vec2(2.2, 10.8)) * 6.28318530718;

			bool can_place = true;
			float gap = 0.03;
			if (accepted > 0 && distance(center, c0) < (radius + r0 + gap)) {
				can_place = false;
			}
			if (accepted > 1 && distance(center, c1) < (radius + r1 + gap)) {
				can_place = false;
			}
			if (accepted > 2 && distance(center, c2) < (radius + r2 + gap)) {
				can_place = false;
			}
			if (accepted > 3 && distance(center, c3) < (radius + r3 + gap)) {
				can_place = false;
			}
			if (!can_place) {
				continue;
			}

			mat2 r = mat2(
				vec2(cos(rot), sin(rot)),
				vec2(-sin(rot), cos(rot))
			);
			vec2 p = r * (tile_local - center);
			float d = sd_ngon(p, radius, sides);
			fill_mask += smoothstep(0.012, -0.007, d);
			edge_mask += smoothstep(0.02, 0.002, abs(d));

			if (accepted == 0) {
				c0 = center; r0 = radius;
			} else if (accepted == 1) {
				c1 = center; r1 = radius;
			} else if (accepted == 2) {
				c2 = center; r2 = radius;
			} else if (accepted == 3) {
				c3 = center; r3 = radius;
			}
			accepted += 1;
		}

		fill_mask = clamp(fill_mask, 0.0, 1.0) * polygon_strength;
		edge_mask = clamp(edge_mask, 0.0, 1.0) * fill_mask;
		float poly_mask = clamp(fill_mask + edge_mask * 0.6, 0.0, 1.0);

		vec3 polygon_col = mix(polygon_tint.rgb, polygon_edge_tint.rgb, edge_mask);
		vec3 final_rgb = mix(tex.rgb, polygon_col, poly_mask * overlay_alpha);
		COLOR = vec4(final_rgb, tex.a);
	}
}
