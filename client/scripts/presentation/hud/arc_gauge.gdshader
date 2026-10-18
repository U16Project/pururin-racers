shader_type canvas_item;
// 弧のゲージ（ArcGauge が使う）。段々なしで、値の割合だけ、なめらかに色を塗る。
// 色は、弧の始まり（0）から終わり（1）まで、gradient の色。外側寄りにつや、まわりにぼんやりした光。
// 角度は、12時を0として時計まわりの度。終わりの角度が始まりより小さければ、反時計まわりに進む。

uniform vec2 rect_size = vec2(100.0);
uniform vec2 center = vec2(50.0);
uniform float radius = 40.0;
uniform float thickness = 10.0;
uniform float start_deg = 0.0;
uniform float end_deg = 90.0;
uniform float fill : hint_range(0.0, 1.0) = 1.0;
uniform sampler2D gradient : filter_linear, repeat_disable;
uniform vec4 track_color : source_color = vec4(1.0, 1.0, 1.0, 0.08);
uniform vec4 track_edge_color : source_color = vec4(0.6, 0.8, 1.0, 0.35);
uniform float glow_width = 8.0;
uniform float glow_strength : hint_range(0.0, 1.0) = 0.5;
uniform float gloss_strength : hint_range(0.0, 1.0) = 0.3;
uniform float inner_shade : hint_range(0.0, 1.0) = 0.2;
uniform float softness = 1.2;
// 先の丸み（ピクセル。太さの半分で半円）。光っている所の伸びていく先と、ゲージの始まり・終わりのはし（round_start・round_end）を丸くする。
// 別の弧とつながっているはし（体力の0の所など）は、丸くしない（つなぎ目が途切れないように）。
uniform float cap_radius = 0.0;
uniform bool round_start = true;
uniform bool round_end = true;
// 目印の線（弧の始まりから終わりの、どこか。0〜1。負なら描かない）。
uniform float marker_at = -1.0;
uniform vec4 marker_color : source_color = vec4(1.0);
uniform float marker_width = 4.0;
uniform float marker_overhang = 4.0;

// 角の丸い四角の、ふちからの距離（負が中）。pt は四角のまん中から、half は半分の大きさ。
float rounded_box(vec2 pt, vec2 half_size, float r) {
	vec2 q = abs(pt) - half_size + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 p = UV * rect_size;
	vec2 v = p - center;
	float d = length(v);
	float angle = degrees(atan(v.x, -v.y));
	if (angle < 0.0) {
		angle += 360.0;
	}
	float span = end_deg - start_deg;
	float direction = span < 0.0 ? -1.0 : 1.0;
	float sweep = abs(span);
	// 始まりから、進む向きに何度か（0〜360）。
	float rel = mod((angle - start_deg) * direction + 720.0, 360.0);
	float per_deg = radians(1.0) * radius;
	float length_px = sweep * per_deg;
	bool on_arc = rel <= sweep;
	// 弧にそって、始まりから何ピクセルか（始まりより手前は負）。
	float along = rel * per_deg;
	if (!on_arc && 360.0 - rel < rel - sweep) {
		along = (rel - 360.0) * per_deg;
	}
	float across = d - radius;
	float band = abs(across) - thickness * 0.5;
	float r = clamp(cap_radius, 0.0, thickness * 0.5);
	// ゲージ全体（空の所も含む）と、光っている所を、弧にそって伸ばした四角として測る。角は、はしごとに丸くするかを決める。
	float start_r = round_start ? r : 0.0;
	float end_r = round_end ? r : 0.0;
	float track_sdf = rounded_box(vec2(along - length_px * 0.5, across), vec2(length_px * 0.5, thickness * 0.5), along < length_px * 0.5 ? start_r : end_r);
	float inside = 1.0 - smoothstep(0.0, softness, track_sdf);
	float t = clamp(rel / max(sweep, 0.001), 0.0, 1.0);
	float lit_length = fill * length_px;
	// 光っている所の先は丸い。終わりのはしがまっすぐなら、そこへ近づくほど、先の丸みを小さくして、ぴったり重ねる。
	float tip_r = round_end ? r : min(r, length_px - lit_length);
	float lit_r = min(along > lit_length * 0.5 ? tip_r : start_r, lit_length * 0.5);
	float lit_sdf = rounded_box(vec2(along - lit_length * 0.5, across), vec2(lit_length * 0.5, thickness * 0.5), lit_r);
	float lit = lit_length > 0.0 ? 1.0 - smoothstep(-softness * 0.5, softness * 0.5, lit_sdf) : 0.0;
	vec4 shade = texture(gradient, vec2(t, 0.5));
	// 弧の中の、内（0）から外（1）への位置。外寄りにつや、内のふちを少し暗く。
	float s = clamp((d - (radius - thickness * 0.5)) / max(thickness, 0.001), 0.0, 1.0);
	vec3 lit_color = shade.rgb;
	lit_color *= mix(1.0 - inner_shade, 1.0, smoothstep(0.0, 0.35, s));
	lit_color += gloss_strength * smoothstep(0.5, 0.78, s) * (1.0 - smoothstep(0.78, 0.98, s));
	vec4 body = mix(track_color, vec4(lit_color, shade.a), lit);
	// 空の所の、ふちの細い線。
	float edge = (1.0 - smoothstep(0.0, 1.2, abs(track_sdf + 0.75))) * (1.0 - lit);
	body = mix(body, vec4(track_edge_color.rgb, max(body.a, track_edge_color.a)), edge * track_edge_color.a);
	body.a *= inside;
	// 光っている所のまわりの、ぼんやりした光。
	float glow = 0.0;
	if (lit_length > 0.0 && lit_sdf > 0.0) {
		glow = exp(-lit_sdf * 2.0 / max(glow_width, 0.001)) * glow_strength;
	}
	vec4 halo = vec4(shade.rgb, glow);
	float alpha = body.a + halo.a * (1.0 - body.a);
	vec3 rgb = (body.rgb * body.a + halo.rgb * halo.a * (1.0 - body.a)) / max(alpha, 0.0001);
	vec4 result = vec4(rgb, alpha);
	// 目印の線（弧を、少しはみ出して横切る）。
	if (marker_at >= 0.0) {
		float distance_px = abs(along - marker_at * length_px);
		if (!on_arc) {
			distance_px = 1e6;
		}
		float crossing = 1.0 - smoothstep(marker_overhang, marker_overhang + softness, band);
		float mark = (1.0 - smoothstep(marker_width * 0.5, marker_width * 0.5 + softness, distance_px)) * crossing;
		result = mix(result, vec4(marker_color.rgb, 1.0), mark * marker_color.a);
		result.a = max(result.a, mark * marker_color.a);
	}
	COLOR = result;
}
