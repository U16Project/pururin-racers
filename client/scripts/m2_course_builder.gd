extends RefCounted
## M2: 小さめ競馬場形（直線＋半円ターン）の Curve3D を生成する。
## Path3D / Curve3D（Godot 4.7）: add_point(in/out) / closed / get_baked_length。
## 周回は上から見て反時計回り（左回り）。ターンは 90° 立方 Bézier 近似で円に近づける。


## 90° 円弧の立方 Bézier ハンドル長（半径比）。(4/3)*tan(π/8)。
const QUARTER_CIRCLE_KAPPA := 0.5522847498


## straight_len: 直線部の長さ(m)。turn_radius: 中心線のターン半径(m)。
## bake_interval: Curve3D のサンプリング間隔(m)。長いコースでは 0.5〜1.0 を推奨。
static func make_racecourse_curve(
	straight_len: float = 28.0,
	turn_radius: float = 18.0,
	_arc_segments: int = 20,
	bake_interval: float = 0.25
) -> Curve3D:
	var curve := Curve3D.new()
	var half_s := straight_len * 0.5
	var r := turn_radius
	var kappa := QUARTER_CIRCLE_KAPPA * r
	var third_s := straight_len / 3.0

	# 角・弧中点（左回り: ホーム右→左 → 左ターン → 向こう左→右 → 右ターン）
	var br := Vector3(half_s, 0.0, -r)
	var bl := Vector3(-half_s, 0.0, -r)
	var lm := Vector3(-half_s - r, 0.0, 0.0)
	var tl := Vector3(-half_s, 0.0, r)
	var tr := Vector3(half_s, 0.0, r)
	var rm := Vector3(half_s + r, 0.0, 0.0)

	# 半円中心まわり・角減少方向の単位接線: dθ<0 の進行
	# pos = center + (r cos θ, 0, r sin θ) → travel = (sin θ, 0, -cos θ)
	var t_br_arc := _arc_travel(-PI * 0.5) # (-1,0,0) 右弧の終点＝ホーム開始
	var t_bl_arc := _arc_travel(-PI * 0.5)
	var t_lm := _arc_travel(-PI)
	var t_tl_arc := _arc_travel(-PI * 1.5)
	var t_tr_arc := _arc_travel(PI * 0.5)
	var t_rm := _arc_travel(0.0)

	# 0 br: 閉路で右弧から流入、ホーム直線へ
	curve.add_point(br, -t_br_arc * kappa, Vector3(-third_s, 0.0, 0.0))
	# 1 bl: 直線流入、左弧へ
	curve.add_point(bl, Vector3(third_s, 0.0, 0.0), t_bl_arc * kappa)
	# 2 lm: 左弧中点（θ=-π）
	curve.add_point(lm, -t_lm * kappa, t_lm * kappa)
	# 3 tl: 左弧終了、向こう直線へ
	curve.add_point(tl, -t_tl_arc * kappa, Vector3(third_s, 0.0, 0.0))
	# 4 tr: 直線流入、右弧へ
	curve.add_point(tr, Vector3(-third_s, 0.0, 0.0), t_tr_arc * kappa)
	# 5 rm: 右弧中点（θ=0）→ 閉路で br へ
	curve.add_point(rm, -t_rm * kappa, t_rm * kappa)

	curve.closed = true
	curve.bake_interval = bake_interval
	return curve


static func _arc_travel(theta: float) -> Vector3:
	return Vector3(sin(theta), 0.0, -cos(theta))
