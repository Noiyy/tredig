shader_type canvas_item;

/// Nastavuje skript podľa veľkosti rectu a tile_size (môže byť stovky buniek)
uniform float columns : hint_range(16.0, 2048.0) = 640.0;
uniform float rows : hint_range(16.0, 2048.0) = 360.0;
uniform float flow_speed : hint_range(0.0, 2.0) = 0.42;
uniform float turbulence : hint_range(0.0, 1.0) = 0.72;
uniform float surface_rim : hint_range(0.0, 1.0) = 0.38;
/// Výška zubatozárezu na hornej / spodnej hrane ako podiel UV (0 = rovná)
uniform float edge_height : hint_range(0.0, 0.5) = 0.18;
/// Nastavuje lava.gd (čas * flow_speed) aby sedel s kolíziou
uniform float lava_sync_time = 0.0;
/// Ak true, horná/spodná hrana sa berie z textúry (CPU = kolízia); inak starý FBM v GPU
uniform bool use_cpu_edge_lut = false;
uniform sampler2D edge_lut : filter_nearest, repeat_disable;
uniform int edge_lut_width = 1;

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
	float t = lava_sync_time;
	vec2 grid = vec2(max(columns, 4.0), max(rows, 4.0));

	// --- zubaté horná + spodná hrana (UV: y=0 hore, y=1 dole) ---
	float surf_top;
	float y_max;
	if (use_cpu_edge_lut) {
		int ew = max(edge_lut_width, 1);
		int ci = clamp(int(floor(uv.x * float(ew))), 0, ew - 1);
		vec4 e = texelFetch(edge_lut, ivec2(ci, 0), 0);
		surf_top = e.r;
		y_max = e.g;
	} else {
		float col_norm = floor(uv.x * grid.x) / grid.x;
		surf_top = fbm(vec2(col_norm * 4.2 + t * 0.13, 0.37)) * edge_height;
		float bite_bottom = fbm(vec2(col_norm * 4.2 + t * 0.09, 0.91)) * edge_height;
		y_max = 1.0 - bite_bottom;
	}
	if (uv.y < surf_top || uv.y > y_max) {
		discard;
	}

	vec2 cid = floor(uv * grid);
	vec2 cuv = (cid + 0.5) / grid;

	vec2 flow = vec2(t * 0.11, t * 0.38);
	float n1 = fbm(cuv * 3.2 + flow);
	float n2 = fbm(cuv * 7.5 - vec2(t * 0.17, t * 0.52));
	float swirl = sin(cuv.x * 6.28318 * 3.0 + t * 1.7) * 0.5 + 0.5;
	float heat = mix(n1, n2, turbulence) * 0.62 + swirl * 0.22 + n2 * 0.16;
	heat = smoothstep(0.18, 0.92, heat);

	vec3 col = mix(deep_color.rgb, core_color.rgb, heat);
	float hot_spots = pow(heat, 4.2);
	col = mix(col, hot_color.rgb, hot_spots * hot_color.a);

	// tenký svetlejší okraj hladiny (horný okraj rectu)
	float rim = smoothstep(0.14, 0.0, uv.y) * surface_rim;
	col += hot_color.rgb * rim;

	// žeravý glow tesne pod horným zubatozárezom
	float glow_top = smoothstep(surf_top + 0.07, surf_top, uv.y);
	col += hot_color.rgb * glow_top * 1.5;

	// glow tesne nad spodným zubatozárezom (nad „uhryznutím“)
	float glow_bot = smoothstep(y_max - 0.08, y_max, uv.y);
	col += hot_color.rgb * glow_bot * 1.2;

	vec4 out_c = vec4(col, mix(deep_color.a, core_color.a, heat));
	out_c.a *= COLOR.a;
	out_c.rgb *= COLOR.rgb;

	COLOR = out_c;
}
