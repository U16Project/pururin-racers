shader_type canvas_item;
// ハートのゲージ（HeartGauge が使う）。光るふち、中のガラス、値の分だけ下から入る水（波と横じま）。
// 形は、ハートの式 x² + (k·y - √|x|)² ≦ 1 を、横 size_x・縦 size_y に広げたもの（y は上向き）。
// k（dip）が大きいほど、上のくぼみが浅く、全体が丸くなる。

uniform vec2 rect_size = vec2(200.0);
uniform vec2 center = vec2(100.0);
uniform float size_x = 80.0;
uniform float size_y = 80.0;
uniform float dip = 1.25;
uniform float fill : hint_range(0.0, 1.0) = 0.5;
uniform vec4 water_color : source_color = vec4(0.2, 0.92, 1.0, 1.0);
uniform float water_bottom_shade : hint_range(0.0, 1.0) = 0.25;
uniform float wave_height = 3.0;
uniform float wave_length = 40.0;
uniform float wave_phase = 0.0;
uniform vec4 surface_color : source_color = vec4(1.0, 1.0, 1.0, 0.7);
uniform float surface_width = 3.0;
uniform float stripe_spacing = 6.0;
uniform float stripe_strength : hint_range(0.0, 1.0) = 0.12;
uniform vec4 glass_color : source_color = vec4(0.08, 0.11, 0.2, 0.92);
uniform float gloss_strength : hint_range(0.0, 1.0) = 0.25;
uniform vec4 edge_color : source_color = vec4(1.0, 0.2, 0.7, 1.0);
uniform float edge_width = 6.0;
uniform vec4 edge_core_color : source_color = vec4(1.0, 0.82, 0.95, 1.0);
uniform float edge_core_width = 1.5;
uniform float glow_width = 18.0;
uniform float glow_strength : hint_range(0.0, 1.0) = 0.55;
// 鼓動の光（0〜1。1で一番明るい）。
uniform float beat : hint_range(0.0, 1.0) = 0.0;
uniform vec4 beat_color : source_color = vec4(1.0, 0.7, 0.9, 1.0);

// ハートの式の値（負が中）。まん中の縦の線で、とがりすぎないよう、|x| を少しなめらかにする。
float heart_value(vec2 q) {
	float ax = sqrt(q.x * q.x + 0.006);
	float b = dip * q.y - sqrt(ax);
	return q.x * q.x + b * b - 1.0;
}

void fragment() {
	vec2 p = UV * rect_size;
	vec2 q = vec2((p.x - center.x) / size_x, -(p.y - center.y) / size_y);
	float f = heart_value(q);
	// ふちからの距離（ピクセル）。式の値を、その場の傾きで割って、おおよその距離にする。
	vec2 slope = vec2(dFdx(f), dFdy(f));
	float distance_px = f / max(length(slope), 1e-5);
	float inside = 1.0 - smoothstep(-0.75, 0.75, distance_px);
	// 中：ガラス。左上のふくらみに、うすいつや。
	vec4 color = glass_color;
	float gloss = smoothstep(0.55, 0.0, length((q - vec2(-0.45, 0.72)) * vec2(1.0, 1.6))) * gloss_strength;
	color.rgb += gloss;
	// 水：値の高さまで（水面は波）。下ほど少し暗く、横じま。
	// ハートの下の先と、上のふくらみのてっぺん（式の上で、y の範囲）。
	float heart_bottom = -1.0 / dip;
	float heart_top = 1.577 / dip;
	float level = mix(heart_bottom, heart_top, fill);
	float wave = sin(p.x / max(wave_length, 0.001) * 6.2832 + wave_phase) * wave_height / size_y;
	float surface = level + wave;
	float below_px = (surface - q.y) * size_y;
	if (fill > 0.0 && below_px > 0.0) {
		float depth = clamp((surface - q.y) / max(surface - heart_bottom, 0.001), 0.0, 1.0);
		vec3 water = water_color.rgb * mix(1.0, 1.0 - water_bottom_shade, depth);
		float stripe = step(0.5, fract(p.y / max(stripe_spacing, 0.001))) * stripe_strength;
		water += stripe;
		color = vec4(mix(color.rgb, water, water_color.a), max(color.a, water_color.a));
	}
	if (fill > 0.0 && fill < 1.0) {
		float line = 1.0 - smoothstep(surface_width * 0.5, surface_width * 0.5 + 1.0, abs(below_px));
		color.rgb = mix(color.rgb, surface_color.rgb, line * surface_color.a);
	}
	color.a *= inside;
	// ふち：光る線（芯は明るく）と、外へのぼんやりした光。鼓動で明るくなる。
	vec3 edge = mix(edge_color.rgb, beat_color.rgb, beat * 0.7);
	float edge_line = 1.0 - smoothstep(edge_width * 0.5, edge_width * 0.5 + 1.0, abs(distance_px));
	float core_line = 1.0 - smoothstep(edge_core_width * 0.5, edge_core_width * 0.5 + 1.0, abs(distance_px));
	float glow = distance_px > 0.0 ? exp(-distance_px * 2.0 / max(glow_width * (1.0 + 0.4 * beat), 0.001)) * min(glow_strength * (1.0 + 0.6 * beat), 1.0) : 0.0;
	float inner_glow = distance_px < 0.0 ? exp(distance_px * 3.0 / max(glow_width, 0.001)) * glow_strength * 0.35 : 0.0;
	color.rgb = mix(color.rgb, edge, inner_glow);
	vec4 halo = vec4(edge, glow);
	float alpha = color.a + halo.a * (1.0 - color.a);
	vec3 rgb = (color.rgb * color.a + halo.rgb * halo.a * (1.0 - color.a)) / max(alpha, 0.0001);
	vec4 result = vec4(rgb, alpha);
	result = mix(result, vec4(edge, 1.0), edge_line * edge_color.a);
	result = mix(result, vec4(mix(edge_core_color.rgb, vec3(1.0), beat * 0.3), 1.0), core_line * edge_core_color.a);
	COLOR = result;
}
