extends GdUnitTestSuite

var target: FxPauseTarget
var pause: TrPause


func before_test() -> void:
	target = FxPauseTarget.new()
	pause = TrPause.new(get_tree(), target)


func after_test() -> void:
	pause.reset()
	Engine.time_scale = 1.0


func test_token_pauses_until_released() -> void:
	var token: TrPauseToken = pause.acquire(&"menu")
	assert_bool(target.paused).is_true()
	assert_bool(pause.is_paused()).is_true()
	assert_array(pause.holders()).contains_exactly([&"menu"])
	token.release()
	assert_bool(target.paused).is_false()
	assert_bool(token.is_held()).is_false()
	token.release()
	assert_bool(target.paused).is_false()


func test_one_release_does_not_unpause_another_holder() -> void:
	var menu: TrPauseToken = pause.acquire(&"menu")
	var dialog: TrPauseToken = pause.acquire(&"dialog")
	menu.release()
	assert_bool(target.paused).is_true()
	assert_array(pause.holders()).contains_exactly([&"dialog"])
	dialog.release()
	assert_bool(target.paused).is_false()


func test_previous_external_pause_is_restored() -> void:
	target.paused = true
	var token: TrPauseToken = pause.acquire(&"menu")
	token.release()
	assert_bool(target.paused).is_true()


func test_freed_token_releases() -> void:
	var holder: Array[TrPauseToken] = [pause.acquire(&"temporary")]
	assert_bool(target.paused).is_true()
	holder.clear()
	assert_bool(target.paused).is_false()


func test_changed_signal() -> void:
	var seen: Array[bool] = []
	pause.changed.connect(func(p: bool) -> void: seen.append(p))
	var a: TrPauseToken = pause.acquire(&"a")
	var b: TrPauseToken = pause.acquire(&"b")
	a.release()
	b.release()
	assert_array(seen).contains_exactly([true, false])


func test_hit_stop_slows_then_restores() -> void:
	pause.hit_stop(0.05, 0.1)
	assert_float(Engine.time_scale).is_equal_approx(0.1, 0.0001)
	assert_bool(pause.is_hit_stopping()).is_true()
	assert_bool(target.paused).is_false()
	await get_tree().create_timer(0.15, true, false, true).timeout
	assert_float(Engine.time_scale).is_equal(1.0)
	assert_bool(pause.is_hit_stopping()).is_false()


func test_overlapping_hit_stops_keep_lowest_until_last_ends() -> void:
	pause.hit_stop(0.05, 0.1)
	pause.hit_stop(0.2, 0.5)
	assert_float(Engine.time_scale).is_equal_approx(0.1, 0.0001)
	await get_tree().create_timer(0.1, true, false, true).timeout
	assert_float(Engine.time_scale).is_equal_approx(0.5, 0.0001)
	await get_tree().create_timer(0.2, true, false, true).timeout
	assert_float(Engine.time_scale).is_equal(1.0)


func test_hit_stop_is_relative_to_the_game_time_scale() -> void:
	Engine.time_scale = 0.5
	pause.hit_stop(0.05, 0.1)
	assert_float(Engine.time_scale).is_equal_approx(0.05, 0.0001)
	await get_tree().create_timer(0.15, true, false, true).timeout
	assert_float(Engine.time_scale).is_equal_approx(0.5, 0.0001)


func test_hit_stop_duration_is_close_to_real_time() -> void:
	var start: int = Time.get_ticks_usec()
	pause.hit_stop(0.1, 0.05)
	while pause.is_hit_stopping():
		await get_tree().process_frame
	var ms: float = (Time.get_ticks_usec() - start) / 1000.0
	# Timers fire on frame boundaries: allow about one frame (17 ms at 60 FPS) either way, plus scheduling noise.
	assert_float(ms).is_between(80.0, 170.0)


func test_reset() -> void:
	pause.acquire(&"x")
	pause.hit_stop(5.0, 0.1)
	pause.reset()
	assert_bool(target.paused).is_false()
	assert_float(Engine.time_scale).is_equal(1.0)
	assert_array(pause.holders()).is_empty()
