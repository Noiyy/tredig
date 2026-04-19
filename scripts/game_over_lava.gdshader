shader_type canvas_item;

uniform float fill_progress : hint_range(0.0, 1.5) = 0.0;
uniform float lava_time = 0.0;
uniform float wave_strength : hint_range(0.0, 0.2) = 0.03;
uniform float flow_speed : hint_range(0.0, 2.0) = 0.42;
uniform float turbulence : hint_range(0.0, 1.0) = 0.72;
uniform float surface_rim : hint_range(0.0, 1.0) = 0.38;
uniform float grid_columns : hint_range(4.0, 512.0) = 160.0;
uniform float grid_rows : hint_range(4.0, 512.0) = 180.0;
uniform float warp_strength : hint_range(0.0, 0.25) = 0.08;

uniform vec4 deep_color : source_color = vec4(0.42, 0.05, 0.02, 0.9);
uniform vec4 core_color : source_color = vec4(0.92, 0.32, 0.06, 0.94);
uniform vec4 hot_color : source_color = vec4(1.0, 0.95, 0.42, 1.0);

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yxz + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV;
	float t = lava_time * flow_speed;

	// Flood front (zhora nadol) s jemne zvlnenou hranou
	float wave = sin(uv.x * 18.0 + t * 1.8) * 0.45 + sin(uv.x * 31.0 - t * 1.2) * 0.55;
	float jitter = fbm(vec2(uv.x * 8.0 + t * 0.35, t * 0.25)) * 2.0 - 1.0;
	float edge_offset = (wave + jitter) * wave_strength;
	float front = fill_progress + edge_offset;

	if (uv.y > front) {
		discard;
	}

	// 1:1 farebný výpočet s level lava shaderom
	vec2 cell_grid = vec2(max(grid_columns, 4.0), max(grid_rows, 4.0));
	vec2 cid = floor(uv * cell_grid);
	vec2 cuv = (cid + 0.5) / cell_grid;

	// Základ pohybu ako v level láve + jemný 2D warp,
	// ktorý rozbije efekt "zvislých stĺpcov" bez zmeny farebného charakteru.
	vec2 flow = vec2(t * 0.11, t * 0.38);
	vec2 warp;
	warp.x = (fbm(cuv * 2.0 + vec2(t * 0.07, -t * 0.15)) - 0.5) * 2.0;
	warp.y = (fbm(cuv.yx * 2.0 + vec2(-t * 0.09, t * 0.06)) - 0.5) * 2.0;
	vec2 warped_uv = cuv + warp * warp_strength;
	float n1 = fbm(warped_uv * 3.2 + flow);
	float n2 = fbm(warped_uv * 7.5 - vec2(t * 0.17, t * 0.52));
	float swirl = sin((warped_uv.x + warped_uv.y * 0.35) * 6.28318 * 3.0 + t * 1.7) * 0.5 + 0.5;
	float heat = mix(n1, n2, turbulence) * 0.62 + swirl * 0.22 + n2 * 0.16;
	heat = smoothstep(0.18, 0.92, heat);
	vec3 col = mix(deep_color.rgb, core_color.rgb, heat);

	float hot_spots = pow(heat, 4.2);
	col = mix(col, hot_color.rgb, hot_spots * hot_color.a);

	float rim = smoothstep(0.14, 0.0, uv.y) * surface_rim;
	col += hot_color.rgb * rim;

	vec4 out_c = vec4(col, mix(deep_color.a, core_color.a, heat));
	out_c.a *= COLOR.a;
	out_c.rgb *= COLOR.rgb;
	COLOR = out_c;
}
