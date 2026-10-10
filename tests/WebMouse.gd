extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	var small := Player.filtered_mouse_delta(Vector2(12, -8), Vector2(24, -16), true)
	check(small == Vector2(12, -8), "Web filter changed ordinary physical motion")
	var spike := Player.filtered_mouse_delta(Vector2(900, 300), Vector2.ZERO, true)
	check(is_equal_approx(spike.length(), Player.WEB_MOUSE_EVENT_LIMIT), "Web spike was not bounded")
	check(spike.normalized().is_equal_approx(Vector2(900, 300).normalized()), "Web filter changed aim direction")
	var desktop := Player.filtered_mouse_delta(Vector2(900, 300), Vector2.ZERO, false)
	check(desktop == Vector2(900, 300), "Desktop mouse motion was limited")
	var fallback := Player.filtered_mouse_delta(Vector2.ZERO, Vector2(6, 4), true)
	check(fallback == Vector2(6, 4), "Relative-motion fallback failed")
	print("WEB MOUSE FILTER: %d failures" % failures)
	quit(1 if failures else 0)
