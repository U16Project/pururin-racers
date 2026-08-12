extends RefCounted
## M1: Path 上の distance 進行（オフセットは常に 0。横ずれなし）。


## path_length 上で distance を進める。結果は [0, path_length)。
static func advance(distance: float, delta: float, speed: float, path_length: float) -> float:
	if path_length <= 0.0:
		return 0.0
	return fposmod(distance + speed * delta, path_length)
