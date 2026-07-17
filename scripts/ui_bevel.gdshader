shader_type canvas_item;

// Beveled (diagonal-cut) UI background drawn on a ColorRect BEHIND a Button
// (show_behind_parent) so the button's text glyphs are never touched.
// Two looks, selected by `menu_style`:
//   * bevel style (0): filled slate/orange panel + diagonal border + optional
//     bottom bevel band; focus shows a pulsing lava glow.
//   * menu style (1): 1b "Hlavné menu" list item — transparent until hovered/
//     focused, then an orange left-bar + orange gradient + dark panel appear.
// UV is 0..1 over the rect.

uniform vec2  rect_px       = vec2(120.0, 24.0);
uniform float bevel_px      = 4.0;
uniform float border_px     = 1.0;
uniform float bottom_bevel_px = 0.0;
uniform float menu_style    = 0.0;

uniform vec4  bg_color   : source_color = vec4(0.173, 0.141, 0.212, 1.0); // #2c2436
uniform vec4  border_col : source_color = vec4(0.259, 0.227, 0.306, 1.0); // #423a4e
uniform vec4  bevel_col  : source_color = vec4(0.722, 0.2,   0.102, 1.0); // #b8331a
uniform vec4  hover_col  : source_color = vec4(0.216, 0.180, 0.263, 1.0);
uniform vec4  lava_a     : source_color = vec4(1.0,   0.353, 0.122, 1.0); // #ff5a1f
uniform vec4  lava_b     : source_color = vec4(1.0,   0.541, 0.239, 1.0); // #ff8a3d

uniform float focused = 0.0;
uniform float hovered = 0.0;
uniform float pressed = 0.0;
uniform float active = 0.0;
uniform float pulse_speed = 4.5;

void fragment() {
	vec2 p = UV * rect_px;
	vec2 q = rect_px - p;
	float dTL = (p.x + p.y) - bevel_px;
	float dTR = (q.x + p.y) - bevel_px;
	float dBL = (p.x + q.y) - bevel_px;
	float dBR = (q.x + q.y) - bevel_px;
	float diag = min(min(dTL, dTR), min(dBL, dBR)) * 0.70710678;
	float straight = min(min(p.x, q.x), min(p.y, q.y));
	float edge = min(diag, straight);
	if (edge < 0.0) {
		discard;
	}

	if (menu_style > 0.5) {
		if (active > 0.5) {
			// active tab: solid orange fill (dark text set by caller).
			// On hover/focus brighten the fill and draw a pulsing bright inset
			// outline so the active tab still shows clear focus/hover feedback.
			float hl = max(clamp(focused, 0.0, 1.0), clamp(hovered, 0.0, 1.0));
			vec3 fill = mix(lava_a.rgb, lava_b.rgb, hl * 0.65);
			float pulse = 0.5 + 0.5 * sin(TIME * pulse_speed);
			float ring = (1.0 - smoothstep(1.5, 2.5, edge)) * hl;
			vec3 ring_col = mix(vec3(1.0), lava_b.rgb, pulse);
			fill = mix(fill, ring_col, ring);
			COLOR = vec4(fill, 1.0) * vec4(COLOR.rgb, 1.0);
		} else {
			// list item / tab: highlight on hover OR controller focus, else transparent.
			float hl = max(clamp(focused, 0.0, 1.0), clamp(hovered, 0.0, 1.0));
			vec3 base_dark = vec3(0.082, 0.067, 0.11);          // #15111c panel
			float grad = clamp(1.0 - UV.x, 0.0, 1.0);           // brighter on the left
			float orange_a = hl * grad * 0.55;
			float bar = (1.0 - smoothstep(3.0, 4.0, p.x)) * hl; // ~4px orange left bar
			float dark_a = hl * 0.5;
			vec3 col = mix(base_dark, lava_a.rgb, clamp(orange_a + bar, 0.0, 1.0));
			float a = clamp(max(dark_a, max(orange_a, bar)), 0.0, 1.0);
			COLOR = vec4(col, a) * vec4(COLOR.rgb, 1.0);
		}
	} else {
		vec3 fill = mix(bg_color.rgb, hover_col.rgb, clamp(hovered, 0.0, 1.0));
		if (bottom_bevel_px > 0.5) {
			float band = smoothstep(rect_px.y - bottom_bevel_px, rect_px.y, p.y);
			fill = mix(fill, bevel_col.rgb, band * 0.9);
		}
		float is_border = 1.0 - smoothstep(border_px - 1.0, border_px + 0.5, edge);
		vec3 col = mix(fill, border_col.rgb, is_border);
		col *= mix(1.0, 0.82, clamp(pressed, 0.0, 1.0));
		float out_a = bg_color.a;
		if (focused > 0.0) {
			float pulse = 0.5 + 0.5 * sin(TIME * pulse_speed);
			vec3 lava = mix(lava_a.rgb, lava_b.rgb, pulse);
			float inner = (1.0 - smoothstep(0.0, 12.0, edge)) * 0.35 * pulse;
			float glow = clamp(clamp(focused, 0.0, 1.0) * (is_border + inner), 0.0, 1.0);
			col = mix(col, lava, glow);
			// glow carries its own alpha, so a transparent-fill control (checkbox)
			// still shows the pulsing lava ring on focus.
			out_a = max(out_a, glow);
		}
		COLOR = vec4(col, out_a) * vec4(COLOR.rgb, 1.0);
	}
}
