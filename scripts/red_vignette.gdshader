shader_type canvas_item;

uniform float intensity : hint_range(0.0, 2.0) = 0.0;
uniform vec4 edge_color : source_color = vec4(0.9, 0.1, 0.1, 0.45);  // červená

void fragment() {
	vec2 centered_uv = UV - 0.5;
	float dist = length(centered_uv);  // 0=centrum, 0.5=okraj
	
	// VIGNETTE efekt: INTENZITA NA OKRAJOCH
	float vignette = smoothstep(0.15, 0.95, dist);  // 0 v strede → 1 na okraji
	
	COLOR = mix(COLOR, edge_color, vignette * intensity);
}
