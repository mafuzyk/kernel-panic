class_name PerformanceProfile
extends RefCounted

## Small, allocation-light measurement boundary for deterministic stress probes.
## It records presentation/runtime cost; it never changes gameplay balance.

var _frames: Array[float] = []
var _peak_entities := 0
var _peak_memory_mb := 0.0

func reset() -> void:
	_frames.clear()
	_peak_entities = 0
	_peak_memory_mb = 0.0

func sample(frame_ms: float, entity_count: int, memory_mb: float) -> void:
	_frames.append(maxf(frame_ms, 0.0))
	_peak_entities = maxi(_peak_entities, entity_count)
	_peak_memory_mb = maxf(_peak_memory_mb, memory_mb)

func frame_count() -> int:
	return _frames.size()

func percentile(fraction: float) -> float:
	if _frames.is_empty():
		return 0.0
	var ordered := _frames.duplicate()
	ordered.sort()
	var rank := clampi(int(ceil(clampf(fraction, 0.0, 1.0) * float(ordered.size()))) - 1, 0, ordered.size() - 1)
	return float(ordered[rank])

func worst_frame_ms() -> float:
	return percentile(1.0)

func snapshot() -> Dictionary:
	return {
		"frames": frame_count(),
		"p50_ms": percentile(0.50),
		"p95_ms": percentile(0.95),
		"p99_ms": percentile(0.99),
		"worst_ms": worst_frame_ms(),
		"peak_entities": _peak_entities,
		"peak_memory_mb": _peak_memory_mb,
	}.duplicate(true)
