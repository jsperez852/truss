class_name WaveProgress
extends RefCounted
## Domain: the current wave and how many of its enemies are left.

const ERR_NO_MORE_WAVES: StringName = &"no_more_waves"
const ERR_WAVE_RUNNING: StringName = &"wave_running"

var wave: int = 0
var remaining: int = 0


func start_next(plan: WavePlan) -> TrResult:
	if remaining > 0:
		return TrResult.failure(ERR_WAVE_RUNNING, "wave %d still has %d enemies" % [wave, remaining])
	if plan.is_last(wave):
		return TrResult.failure(ERR_NO_MORE_WAVES, "all %d waves are done" % plan.total_waves)
	wave += 1
	remaining = plan.enemies_in(wave)
	return TrResult.success(remaining)


## Returns true when this kill cleared the wave.
func enemy_down() -> bool:
	if remaining <= 0:
		return false
	remaining -= 1
	return remaining == 0
