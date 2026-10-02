extends RefCounted
## ローカルと M5 の HUD で共通に使うドラフト効果の表示整形。


static func status_lines(
	racer: Dictionary,
	reference_p: float,
	require_identified_source: bool = false,
	split_source_lines: bool = false,
	show_effective_details: bool = false,
	show_speed_cap_bonus: bool = true
) -> PackedStringArray:
	var draft_scale := maxf(reference_p, 0.0001)
	var direct := maxf(0.0, float(racer.get("direct_draft_p", 0.0)))
	var chain := maxf(0.0, float(racer.get("chain_draft_p", 0.0)))
	var received := maxf(0.0, float(racer.get("received_draft_p", direct + chain)))
	var target_text := "なし"
	var has_sources := _has_identified_source(racer)
	var direct_percent := 0.0
	var chain_percent := 0.0
	var total_percent := 0.0
	if received > 0.000001 and (not require_identified_source or has_sources):
		direct_percent = direct / draft_scale * 100.0
		chain_percent = chain / draft_scale * 100.0
		total_percent = received / draft_scale * 100.0
		target_text = target_text(racer)
	var lines := PackedStringArray([
		"直接 %.0f%%" % direct_percent,
		"連鎖 %.0f%%" % chain_percent,
		"総合 %.0f%%" % total_percent,
	])
	if show_effective_details:
		lines.append("実効 %.0f%%" % (maxf(0.0, float(racer.get("effective_draft_ratio", 0.0))) * 100.0))
		lines.append("集団補正 x%.2f" % float(racer.get("pack_draft_effective_multiplier", 1.0)))
		if show_speed_cap_bonus:
			lines.append("上限補正 %+.1fkm/h" % float(racer.get("draft_speed_bonus_kmh", 0.0)))
	if split_source_lines and not racer.get("direct_source_details", []).is_empty():
		var source_index := 1
		for detail in racer.get("direct_source_details", []):
			# 左固定 544px HUD でも全対象を省略せず読めるよう、対象ごとに短い1行へ分ける。
			lines.append("対象%d %s 前%.1fm 横%.1fm" % [
				source_index,
				str(detail.get("id", "")),
				float(detail.get("gap", 0.0)),
				float(detail.get("line", 0.0)),
			])
			source_index += 1
		var chain_ids := PackedStringArray(racer.get("chain_source_ids", []))
		if not chain_ids.is_empty():
			lines.append("連鎖元 " + "、".join(chain_ids))
	else:
		lines.append("対象 %s" % target_text)
	return lines


static func target_text(racer: Dictionary) -> String:
	var targets := PackedStringArray()
	for detail in racer.get("direct_source_details", []):
		targets.append("%s（前方 %.1fm／横 %.1fm）" % [
			str(detail.get("id", "")),
			float(detail.get("gap", 0.0)),
			float(detail.get("line", 0.0)),
		])
	if targets.is_empty():
		var primary_id := str(racer.get("primary_source_id", ""))
		if not primary_id.is_empty():
			targets.append("%s（前方 %.1fm／横 %.1fm）" % [
				primary_id,
				float(racer.get("primary_gap_m", 0.0)),
				float(racer.get("primary_line_gap_m", 0.0)),
			])
		for source_id in racer.get("direct_source_ids", []):
			if str(source_id) != primary_id:
				targets.append(str(source_id))
	for source_id in racer.get("chain_source_ids", []):
		targets.append(str(source_id))
	return "、".join(targets) if not targets.is_empty() else "不明"


static func _has_identified_source(racer: Dictionary) -> bool:
	return not racer.get("direct_source_details", []).is_empty() \
		or not racer.get("direct_source_ids", []).is_empty() \
		or not racer.get("chain_source_ids", []).is_empty()
