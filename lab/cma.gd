extends RefCounted
## CPU育成ラボ：育て方（CMA-ES）。前例のある定番のやり方。
## 候補を何個か作り（ask）、成績の良い順を渡すと（tell）、良かった候補の向きへ、次の候補の中心と広がりを寄せる。
## 数字は 0〜1 の範囲で扱う（範囲の外の候補は、使うときに端へ寄せ、並べるときに少し損をさせる）。
## 中身は Hansen の解説（The CMA Evolution Strategy: A Tutorial）の、いちばん基本の形のとおり。

var n := 0
var lam := 0
var mu := 0
var weights: Array = []
var mueff := 0.0
var cc := 0.0
var cs := 0.0
var c1 := 0.0
var cmu := 0.0
var damps := 0.0
var chi_n := 0.0
var mean: Array = []
var sigma := 0.0
var pc: Array = []
var ps: Array = []
## 広がりの形（n×n）と、その分解。
var c: Array = []
var b: Array = []
var d: Array = []
var inv_sqrt_c: Array = []
var count_eval := 0
var generation := 0


func _init(start_mean: Array, start_sigma: float, population: int) -> void:
	n = start_mean.size()
	lam = population
	mu = lam / 2
	var total := 0.0
	for i in mu:
		weights.append(log(mu + 0.5) - log(i + 1.0))
		total += weights[i]
	var sq := 0.0
	for i in mu:
		weights[i] = weights[i] / total
		sq += weights[i] * weights[i]
	mueff = 1.0 / sq
	cc = (4.0 + mueff / n) / (n + 4.0 + 2.0 * mueff / n)
	cs = (mueff + 2.0) / (n + mueff + 5.0)
	c1 = 2.0 / (pow(n + 1.3, 2.0) + mueff)
	cmu = minf(1.0 - c1, 2.0 * (mueff - 2.0 + 1.0 / mueff) / (pow(n + 2.0, 2.0) + mueff))
	damps = 1.0 + 2.0 * maxf(0.0, sqrt((mueff - 1.0) / (n + 1.0)) - 1.0) + cs
	chi_n = sqrt(n) * (1.0 - 1.0 / (4.0 * n) + 1.0 / (21.0 * n * n))
	mean = start_mean.duplicate()
	sigma = start_sigma
	pc = _zeros(n)
	ps = _zeros(n)
	c = _identity(n)
	b = _identity(n)
	d = _ones(n)
	inv_sqrt_c = _identity(n)


## 候補を lam 個作る。
func ask(rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	for k in lam:
		var z: Array = []
		for i in n:
			z.append(rng.randfn(0.0, 1.0) * float(d[i]))
		var y := _mat_vec(b, z)
		var x: Array = []
		for i in n:
			x.append(float(mean[i]) + sigma * float(y[i]))
		out.append(x)
	return out


## 範囲の外へ出た分の大きさ（並べるときの損に使う）。
static func outside(x: Array) -> float:
	var total := 0.0
	for v in x:
		var over := maxf(float(v) - 1.0, 0.0) + maxf(-float(v), 0.0)
		total += over * over
	return total


## 候補と、その損（小さいほど良い）を渡して、次の中心・広がりへ進める。
func tell(candidates: Array, costs: Array) -> void:
	count_eval += candidates.size()
	generation += 1
	var order: Array = range(candidates.size())
	order.sort_custom(func(a, bb): return float(costs[a]) < float(costs[bb]))
	var old := mean.duplicate()
	var new_mean := _zeros(n)
	for k in mu:
		var x: Array = candidates[order[k]]
		for i in n:
			new_mean[i] += float(weights[k]) * float(x[i])
	mean = new_mean
	var y_w: Array = []
	for i in n:
		y_w.append((float(mean[i]) - float(old[i])) / sigma)
	var z_w := _mat_vec(inv_sqrt_c, y_w)
	var ps_scale := sqrt(cs * (2.0 - cs) * mueff)
	for i in n:
		ps[i] = (1.0 - cs) * float(ps[i]) + ps_scale * float(z_w[i])
	var ps_norm := _norm(ps)
	var hsig := 1.0 if ps_norm / sqrt(1.0 - pow(1.0 - cs, 2.0 * count_eval / lam)) / chi_n < 1.4 + 2.0 / (n + 1.0) else 0.0
	var pc_scale := sqrt(cc * (2.0 - cc) * mueff)
	for i in n:
		pc[i] = (1.0 - cc) * float(pc[i]) + hsig * pc_scale * float(y_w[i])
	var steps: Array = []
	for k in mu:
		var x: Array = candidates[order[k]]
		var step: Array = []
		for i in n:
			step.append((float(x[i]) - float(old[i])) / sigma)
		steps.append(step)
	for i in n:
		for j in n:
			var rank_mu := 0.0
			for k in mu:
				rank_mu += float(weights[k]) * float(steps[k][i]) * float(steps[k][j])
			c[i][j] = (1.0 - c1 - cmu) * float(c[i][j]) \
				+ c1 * (float(pc[i]) * float(pc[j]) + (1.0 - hsig) * cc * (2.0 - cc) * float(c[i][j])) \
				+ cmu * rank_mu
	sigma *= exp((cs / damps) * (ps_norm / chi_n - 1.0))
	_decompose()


## 広がりの形を分解する（向きと大きさ）。
func _decompose() -> void:
	var eig := _jacobi(c)
	b = eig["vectors"]
	d = []
	for v in eig["values"]:
		d.append(sqrt(maxf(float(v), 1e-20)))
	inv_sqrt_c = []
	for i in n:
		var row: Array = []
		for j in n:
			var total := 0.0
			for k in n:
				total += float(b[i][k]) * float(b[j][k]) / float(d[k])
			row.append(total)
		inv_sqrt_c.append(row)


## 保存用（あとで続きから育てるため）。
func to_dict() -> Dictionary:
	return {"n": n, "lam": lam, "mean": mean, "sigma": sigma, "pc": pc, "ps": ps, "c": c, "count_eval": count_eval, "generation": generation}


## 保存したものから、続きの状態に戻す（同じ n・lam で作ってから呼ぶ）。
func restore(data: Dictionary) -> void:
	mean = (data["mean"] as Array).duplicate()
	sigma = float(data["sigma"])
	pc = (data["pc"] as Array).duplicate()
	ps = (data["ps"] as Array).duplicate()
	c = (data["c"] as Array).duplicate(true)
	count_eval = int(data["count_eval"])
	generation = int(data["generation"])
	_decompose()


static func _zeros(size: int) -> Array:
	var out: Array = []
	out.resize(size)
	out.fill(0.0)
	return out


static func _ones(size: int) -> Array:
	var out: Array = []
	out.resize(size)
	out.fill(1.0)
	return out


static func _identity(size: int) -> Array:
	var out: Array = []
	for i in size:
		var row := _zeros(size)
		row[i] = 1.0
		out.append(row)
	return out


static func _mat_vec(m: Array, v: Array) -> Array:
	var out: Array = []
	for i in m.size():
		var total := 0.0
		for j in v.size():
			total += float(m[i][j]) * float(v[j])
		out.append(total)
	return out


static func _norm(v: Array) -> float:
	var total := 0.0
	for x in v:
		total += float(x) * float(x)
	return sqrt(total)


## 対称な行列の分解（ヤコビ法）。{values: [..], vectors: 列が向き}。
static func _jacobi(m: Array) -> Dictionary:
	var size := m.size()
	var a: Array = []
	for row in m:
		a.append((row as Array).duplicate())
	var v := _identity(size)
	for sweep in 60:
		var off := 0.0
		for i in size:
			for j in range(i + 1, size):
				off += float(a[i][j]) * float(a[i][j])
		if off < 1e-22:
			break
		for p in size:
			for q in range(p + 1, size):
				var apq := float(a[p][q])
				if absf(apq) < 1e-30:
					continue
				var theta := (float(a[q][q]) - float(a[p][p])) / (2.0 * apq)
				var t := signf(theta) / (absf(theta) + sqrt(theta * theta + 1.0)) if theta != 0.0 else 1.0
				var cos_v := 1.0 / sqrt(t * t + 1.0)
				var sin_v := t * cos_v
				for k in size:
					var akp := float(a[k][p])
					var akq := float(a[k][q])
					a[k][p] = cos_v * akp - sin_v * akq
					a[k][q] = sin_v * akp + cos_v * akq
				for k in size:
					var apk := float(a[p][k])
					var aqk := float(a[q][k])
					a[p][k] = cos_v * apk - sin_v * aqk
					a[q][k] = sin_v * apk + cos_v * aqk
				for k in size:
					var vkp := float(v[k][p])
					var vkq := float(v[k][q])
					v[k][p] = cos_v * vkp - sin_v * vkq
					v[k][q] = sin_v * vkp + cos_v * vkq
	var values: Array = []
	for i in size:
		values.append(float(a[i][i]))
	return {"values": values, "vectors": v}
