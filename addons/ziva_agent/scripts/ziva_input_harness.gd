extends Node

const PARAMS_PATH := "res://.godot/ziva_playtest_inputs.json"
const SESSION_PATH := "res://.godot/ziva_qa_session.json"

const MIN_HOLD_FRAMES := 2

const SETTLE_FRAMES := 5

const MAX_FRAME_EDGE := 1568

const CAPTURE_DRAW_TIMEOUT_FRAMES := 60

const HEARTBEAT_MS := 500

const UNTIL_WALL_CLOCK_BUDGET_MS := 90_000

const PAUSED_RENDER_FPS_CAP := 10

const PROBE_VALUE_MAX_CHARS := 4096
const CONTAINER_LOG_LIMIT := 512
const CONTAINER_LOG_DEPTH := 6

const DRIVE_SOURCE_MAX_CHARS := 8000

const DRIVE_FAULT_CALLS := 5

const CAPTURE_EVERY_PHYSICS := 1

const RECORD_TAIL_PHYSICS := 60

const RECORD_JPEG_QUALITY := 0.75

const SPEED_MONITORS := {
	"process_ms": ["TIME_PROCESS"],
	"physics_ms": ["TIME_PHYSICS_PROCESS"],
	"navigation_ms": ["TIME_NAVIGATION_PROCESS"],
	"draw_calls": ["RENDER_TOTAL_DRAW_CALLS_IN_FRAME"],
	"objects_drawn": ["RENDER_TOTAL_OBJECTS_IN_FRAME"],
	"primitives": ["RENDER_TOTAL_PRIMITIVES_IN_FRAME"],
	"nodes": ["OBJECT_NODE_COUNT"],
	"orphan_nodes": ["OBJECT_ORPHAN_NODE_COUNT"],
	"physics_bodies": ["PHYSICS_2D_ACTIVE_OBJECTS", "PHYSICS_3D_ACTIVE_OBJECTS"],
	"collision_pairs": ["PHYSICS_2D_COLLISION_PAIRS", "PHYSICS_3D_COLLISION_PAIRS"],
	"shader_compiles_total": [
		"PIPELINE_COMPILATIONS_CANVAS",
		"PIPELINE_COMPILATIONS_MESH",
		"PIPELINE_COMPILATIONS_SURFACE",
		"PIPELINE_COMPILATIONS_DRAW",
		"PIPELINE_COMPILATIONS_SPECIALIZATION",
	],
}
const SPEED_CENSUS_TOP := 15
const SPEED_CENSUS_NODE_LIMIT := 4000
const EDITOR_REPLY_TIMEOUT_MS := 3000

const MAX_FRAMES := 9000

const OVERLAY_LAYER := 128
const OVERLAY_PAD := 24.0
const CHIP_HEIGHT := 34.0
const CAPTION_FONT_SIZE := 28
const CAPTION_FONT_MIN := 16
const CHIP_FONT_SIZE := 22
const CAPTION_PANEL_COLOR := Color(0.05, 0.06, 0.09, 0.72)
const CHIP_PANEL_COLOR := Color(0.06, 0.07, 0.10, 0.82)
const CAPTION_SUB_FONT_SIZE := 20
const CHIP_ROW_GAP := 62.0
const HARNESS_GROUP := "ziva_input_harness"
const REC_COLOR := Color(0.86, 0.13, 0.15)
const CURSOR_COLOR := Color(1.0, 0.95, 0.4)
const TRAIL_COLOR := Color(1.0, 0.85, 0.2, 0.55)
const RIPPLE_MS := 450
const TRAIL_POINTS := 40
const MOUSE_LABELS := {
	MOUSE_BUTTON_LEFT: "LMB", MOUSE_BUTTON_RIGHT: "RMB", MOUSE_BUTTON_MIDDLE: "MMB"
}

var _held_modifiers: Dictionary = {}
var _running_max_fps: int = -1
var _frozen := false
var _game_paused := false
var _params: Dictionary = {}
var _start_ms: int = 0
var _start_frame: int = 0
var _beat_ms := 0
var _beat_first_frame := 0
var _beat_first_drawn := 0
var _beat_last_drawn := 0
var _typed_targets: Dictionary = {}

var _ws: WebSocketPeer = null
var _greeted := false
var _serving := false
var _pointer_warning := ""
var _pointer_checked := false
var _shares_user_cursor := false
var _warp_skip_logged := false

var _record_dir := ""
var _record_stride := CAPTURE_EVERY_PHYSICS
var _record_next := 0
var _record_kept := PackedInt32Array()
var _record_live_ms := 0.0
var _record_last_physics := -1
var _record_error := ""
var _capturing := false
var _capture_waited := 0
var _low_processor_lifts := 0
var _app_low_processor := false
var _record_lifted_low_processor := false
var _overlay: CanvasLayer = null
var _overlay_draw: Node2D = null
var _intent := ""
var _held: Dictionary = {}
var _caption_fit: Dictionary = {}
var _session_goal := ""
var _sig_cursor := Vector2i(-9999, -9999)
var _sig_held := -1
var _sig_intent := -1
var _sig_ripples := -1
var _sig_frozen := false
var _trail: Array = []
var _ripples: Array = []
var _speed_on := false
var _speed: Dictionary = {}
var _speed_monitors: Dictionary = {}
var _speed_last_usec := 0
var _editor_replies: Dictionary = {}


func _ready() -> void:
	if EngineDebugger.is_active() and not EngineDebugger.has_capture("ziva_pt"):
		EngineDebugger.register_message_capture("ziva_pt", _on_capture)
	if FileAccess.file_exists(SESSION_PATH):
		if get_tree().get_nodes_in_group(HARNESS_GROUP).size() > 0:
			printerr(
				"ziva_input_harness: this script is registered as MORE THAN ONE autoload in "
				+ "project.godot. Only the first will drive the session; remove the duplicate "
				+ "entry (both point at res://addons/ziva_agent/scripts/ziva_input_harness.gd)."
			)
			return
		add_to_group(HARNESS_GROUP)
		_start_session()
		return
	_params = _load_params()
	if _params.is_empty():
		return
	_beat_first_frame = Engine.get_process_frames()
	_beat_first_drawn = Engine.get_frames_drawn()
	_beat_last_drawn = _beat_first_drawn
	_beat()
	get_tree().process_frame.connect(_on_beat_frame)
	_run.call_deferred()


func _beat() -> void:
	_beat_ms = Time.get_ticks_msec()
	var path := String(_params["started_path"])
	var marker := FileAccess.open(path, FileAccess.READ_WRITE)
	if marker == null:
		marker = FileAccess.open(path, FileAccess.WRITE)
	if marker == null:
		return
	var drawn := Engine.get_frames_drawn()
	marker.store_string(
		"%010d %010d %010d" % [
			Engine.get_process_frames() - _beat_first_frame,
			drawn - _beat_first_drawn,
			drawn - _beat_last_drawn,
		]
	)
	marker.close()
	_beat_last_drawn = drawn


func _on_beat_frame() -> void:
	if Time.get_ticks_msec() - _beat_ms >= HEARTBEAT_MS:
		_beat()


func _on_capture(message: String, data: Array) -> bool:
	_editor_replies[message] = data
	return true


func _ask_editor(message: String, reply: String) -> Variant:
	if not EngineDebugger.is_active():
		return null
	_editor_replies.erase(reply)
	EngineDebugger.send_message("ziva_pt:" + message, [])
	var deadline := Time.get_ticks_msec() + EDITOR_REPLY_TIMEOUT_MS
	while not _editor_replies.has(reply) and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	return _editor_replies.get(reply)


func _read_sidecar(path: String, required: Array) -> Dictionary:
	if not FileAccess.file_exists(path):
		printerr("ziva_input_harness: no parameter sidecar at " + path)
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		printerr("ziva_input_harness: could not open " + path)
		return {}
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		printerr("ziva_input_harness: parameter sidecar was not a JSON object: " + text)
		return {}
	for key in required:
		if not (parsed as Dictionary).has(key):
			printerr("ziva_input_harness: parameter sidecar is missing '" + String(key) + "': " + text)
			return {}
	return parsed


func _load_params() -> Dictionary:
	return _read_sidecar(
		PARAMS_PATH,
		["results_path", "results_tmp", "report_path", "started_path", "duration_ms", "inputs"]
	)


func _inject(event: InputEvent) -> void:
	if event is InputEventWithModifiers:
		var with_mods: InputEventWithModifiers = event
		with_mods.shift_pressed = _held_modifiers.has(KEY_SHIFT)
		with_mods.ctrl_pressed = _held_modifiers.has(KEY_CTRL)
		with_mods.alt_pressed = _held_modifiers.has(KEY_ALT)
		with_mods.meta_pressed = _held_modifiers.has(KEY_META)
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _input(event: InputEvent) -> void:
	if not _record_dir.is_empty():
		_note_overlay_event(event)


func _button_index(entry: Dictionary) -> MouseButton:
	return MOUSE_BUTTON_RIGHT if str(entry.get("button", "left")) == "right" else MOUSE_BUTTON_LEFT


func _button_error(entry: Dictionary) -> String:
	if not entry.has("button"):
		return ""
	var button := str(entry["button"])
	if button == "left" or button == "right":
		return ""
	return 'button must be "left" or "right", got ' + JSON.stringify(entry["button"])


func _click_at(pos: Vector2, button: MouseButton, pressed: bool) -> void:
	if pressed:
		_move_mouse(pos, Vector2.ZERO)
	var btn := InputEventMouseButton.new()
	btn.button_index = button
	btn.position = _to_window(pos)
	btn.global_position = btn.position
	btn.pressed = pressed
	if pressed:
		btn.button_mask = (
			MOUSE_BUTTON_MASK_RIGHT if button == MOUSE_BUTTON_RIGHT else MOUSE_BUTTON_MASK_LEFT
		)
	_inject(btn)


func _focus_click(node: Control) -> void:
	var center: Vector2 = node.get_global_rect().get_center()
	_click_at(center, MOUSE_BUTTON_LEFT, true)
	await get_tree().process_frame
	_click_at(center, MOUSE_BUTTON_LEFT, false)
	await get_tree().process_frame


func _dispatch_key(entry: Dictionary, pressed: bool) -> String:
	var key_str: String = String(entry.get("key", ""))
	var ev := InputEventKey.new()
	ev.pressed = pressed
	if key_str.length() == 1:
		ev.unicode = key_str.unicode_at(0)
		ev.keycode = OS.find_keycode_from_string(key_str.to_upper())
	else:
		ev.keycode = OS.find_keycode_from_string(key_str)
	if ev.keycode == 0 and ev.unicode == 0:
		return (
			"'%s' is not a key: it is neither a single character nor a Godot key name "
			% key_str
			+ "(Enter, Space, Escape, Tab, F1...). To type a word, send one entry per "
			+ "character, each carrying the same 'target' so the field is focused first."
		)
	if ev.keycode != 0:
		ev.physical_keycode = ev.keycode
	if ev.keycode in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]:
		if pressed:
			_held_modifiers[ev.keycode] = true
		else:
			_held_modifiers.erase(ev.keycode)
	_inject(ev)
	return ""


func _dispatch_input(entry: Dictionary, pressed: bool) -> String:
	if String(entry.get("type", "action")) == "key" and not String(entry.get("target", "")).is_empty():
		var target: String = String(entry.get("target", ""))
		var control: Control = _resolve_target(target)
		if control == null:
			return "no Control matched target '" + target + "'"
		if pressed and not _typed_targets.has(target):
			_typed_targets[target] = control
			await _focus_click(control)
	return _dispatch_edge(entry, pressed)


func _dispatch_edge(entry: Dictionary, pressed: bool) -> String:
	var button_error := _button_error(entry)
	if not button_error.is_empty():
		return button_error
	var kind: String = String(entry.get("type", "action"))
	match kind:
		"key":
			return _dispatch_key(entry, pressed)
		"mouse":
			if not entry.has("x") or not entry.has("y"):
				return (
					"a mouse click needs both x and y in viewport pixels (got keys "
					+ str(entry.keys())
					+ "); without them it would land at (0,0), the corner of the screen"
				)
			_click_at(
				Vector2(float(entry.get("x", 0)), float(entry.get("y", 0))),
				_button_index(entry),
				pressed
			)
		"target":
			var node: Control = _resolve_target(String(entry.get("target", "")))
			if node == null:
				return "no Control matched target '" + String(entry.get("target", "")) + "'"
			_click_at(node.get_global_rect().get_center(), _button_index(entry), pressed)
		"motion":
			var mv := InputEventMouseMotion.new()
			mv.relative = _to_window_delta(Vector2(float(entry.get("dx", 0)), float(entry.get("dy", 0))))
			mv.position = _to_window(get_viewport().get_mouse_position())
			mv.global_position = mv.position
			_inject(mv)
		_:
			var action: String = String(entry.get("action", ""))
			if action.is_empty():
				return (
					"entry has no action name; it reached the 'action' branch with keys "
					+ str(entry.keys())
					+ " (a misspelled or missing 'type' lands here)"
				)
			var ev := InputEventAction.new()
			ev.action = action
			ev.pressed = pressed
			_inject(ev)
	return ""


func _resolve_target(target: String) -> Control:
	if target.is_empty():
		return null
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return null
	var by_path: Node = scene_root.get_node_or_null(NodePath(target))
	if by_path is Control:
		return by_path
	return _find_control_by_text(scene_root, target)


func _find_control_by_text(node: Node, target: String) -> Control:
	for child in node.get_children(false):
		if child is Control:
			if String(child.name) == target:
				return child
			if "text" in child and String(child.get("text")) == target:
				return child
		var found: Control = _find_control_by_text(child, target)
		if found != null:
			return found
	return null


func _label(entry: Dictionary) -> String:
	var kind: String = String(entry.get("type", "action"))
	match kind:
		"key":
			return "key:" + String(entry.get("key", ""))
		"mouse":
			return (
				"mouse:%s@%d,%d"
				% [
					String(entry.get("button", "left")),
					int(entry.get("x", 0)),
					int(entry.get("y", 0)),
				]
			)
		"target":
			return "target:%s:%s" % [String(entry.get("button", "left")), String(entry.get("target", ""))]
		"drag":
			return "drag:%s" % String(entry.get("button", "left"))
		"motion":
			return "motion:%d,%d" % [int(entry.get("dx", 0)), int(entry.get("dy", 0))]
		_:
			return "action:" + String(entry.get("action", ""))


func _now_ms() -> int:
	return Time.get_ticks_msec() - _start_ms


func _new_record(index: int, entry: Dictionary) -> Dictionary:
	return {
		"index": index,
		"type": String(entry.get("type", "action")),
		"label": _label(entry),
		"requested_at_ms": int(entry.get("at_ms", 0)),
		"requested_hold_ms": int(entry.get("hold_ms", 0)),
		"press_ms": -1,
		"press_frame": -1,
		"release_ms": -1,
		"release_frame": -1,
		"hold_frames": 0,
		"hold_clamped": false,
		"delivered": false,
	}


func _replay(inputs: Array, duration_ms: int, records: Array) -> void:
	var pending: Array = []
	var issued := {}
	while true:
		var elapsed: int = _now_ms()
		for i in inputs.size():
			if issued.has(i) or elapsed < int(inputs[i].get("at_ms", 0)):
				continue
			issued[i] = true
			var entry: Dictionary = inputs[i]
			var record: Dictionary = records[i]
			var dropped: String = await _dispatch_input(entry, true)
			if dropped != "":
				record["dropped"] = dropped
				continue
			record["press_ms"] = _now_ms()
			record["press_frame"] = Engine.get_process_frames() - _start_frame
			record["delivered"] = true
			if String(entry.get("type", "action")) == "motion":
				continue
			pending.append(
				{
					"entry": entry,
					"record": record,
					"release_at_ms": record["press_ms"] + int(entry.get("hold_ms", 0)),
					"press_physics_frame": Engine.get_physics_frames(),
				}
			)

		var still_pending: Array = []
		for p in pending:
			var held_frames: int = Engine.get_physics_frames() - int(p["press_physics_frame"])
			if held_frames < MIN_HOLD_FRAMES:
				if _now_ms() >= int(p["release_at_ms"]):
					p["record"]["hold_clamped"] = true
				still_pending.append(p)
				continue
			if _now_ms() < int(p["release_at_ms"]):
				still_pending.append(p)
				continue
			await _dispatch_input(p["entry"], false)
			p["record"]["release_ms"] = _now_ms()
			p["record"]["release_frame"] = Engine.get_process_frames() - _start_frame
			p["record"]["hold_frames"] = held_frames
		pending = still_pending

		if _now_ms() >= duration_ms and pending.is_empty() and issued.size() == inputs.size():
			return
		await get_tree().process_frame


func _read_back_text() -> Dictionary:
	var readback: Dictionary = {}
	for target in _typed_targets:
		var control: Control = _typed_targets[target]
		if is_instance_valid(control) and "text" in control:
			readback[target] = String(control.get("text"))
	return readback


func _run() -> void:
	var inputs: Array = _params["inputs"]
	var duration_ms: int = int(_params["duration_ms"])
	if duration_ms <= 0:
		printerr(
			"ziva_input_harness: duration_ms is %d - a run of zero length does zero work; refusing"
			% duration_ms
		)
		return
	for i in inputs.size():
		var end_ms: int = int(inputs[i].get("at_ms", 0)) + int(inputs[i].get("hold_ms", 0))
		if end_ms > duration_ms:
			printerr(
				"ziva_input_harness: input %d ends at %dms but duration_ms is %d - refusing a schedule that cannot complete"
				% [i, end_ms, duration_ms]
			)
			return
	var records: Array = []
	for i in inputs.size():
		records.append(_new_record(i, inputs[i]))

	var speed_params: Dictionary = _params.get("speed", {})
	var profiler_error := ""
	if not speed_params.is_empty():
		profiler_error = await _start_speed(bool(speed_params.get("scripts", false)))

	_start_ms = Time.get_ticks_msec()
	_start_frame = Engine.get_process_frames()
	_speed_on = not speed_params.is_empty()
	await _replay(inputs, duration_ms, records)
	_speed_on = false

	var undelivered: Array = []
	for record in records:
		if not record["delivered"]:
			undelivered.append(record)
	if not undelivered.is_empty():
		printerr(
			"ziva_input_harness: %d of %d inputs were never delivered"
			% [undelivered.size(), records.size()]
		)

	var report := {
		"duration_ms": duration_ms,
		"elapsed_ms": _now_ms(),
		"frames": Engine.get_process_frames() - _start_frame,
		"entries": records,
		"undelivered": undelivered,
		"text_readback": _read_back_text(),
	}
	if not speed_params.is_empty():
		report["speed"] = await _finish_speed(bool(speed_params.get("scripts", false)), profiler_error)

	_lift_low_processor()
	for i in range(SETTLE_FRAMES):
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
	_restore_low_processor()

	var tex := get_tree().get_root().get_texture()
	if tex == null:
		printerr("ziva_input_harness: root viewport texture is null")
		return
	var img: Image = tex.get_image()
	if img == null:
		printerr("ziva_input_harness: get_image() returned null")
		return
	if img.is_empty():
		printerr("ziva_input_harness: captured image is empty")
		return
	var longest: int = maxi(img.get_width(), img.get_height())
	if longest > MAX_FRAME_EDGE:
		img.resize(
			img.get_width() * MAX_FRAME_EDGE / longest,
			img.get_height() * MAX_FRAME_EDGE / longest,
			Image.INTERPOLATE_LANCZOS
		)
	report["screenshot_size"] = [img.get_width(), img.get_height()]
	report["viewport_size"] = _viewport_size()
	var results_tmp := String(_params["results_tmp"])
	var err: int = img.save_png(results_tmp)
	if err != OK:
		printerr("ziva_input_harness: save_png failed err " + str(err))
		return

	var report_file := FileAccess.open(String(_params["report_path"]), FileAccess.WRITE)
	if report_file == null:
		printerr("ziva_input_harness: could not write the delivery report to " + String(_params["report_path"]))
		return
	report_file.store_string(JSON.stringify(report))
	report_file.close()

	var d := DirAccess.open("res://")
	if d == null:
		printerr("ziva_input_harness: DirAccess.open(res://) failed")
		return
	var results_path := String(_params["results_path"])
	if d.file_exists(results_path):
		d.remove(results_path)
	err = d.rename(results_tmp, results_path)
	if err != OK:
		printerr("ziva_input_harness: rename to results path failed err " + str(err))
		return


func _start_speed(scripts: bool) -> String:
	_speed_monitors = {}
	for key in SPEED_MONITORS:
		var ids: Array = []
		for name in SPEED_MONITORS[key]:
			if ClassDB.class_has_integer_constant("Performance", name):
				ids.append(ClassDB.class_get_integer_constant("Performance", name))
		if not ids.is_empty():
			_speed_monitors[key] = ids
	_speed = {"frame": [], "t_ms": [], "frame_ms": [], "render_cpu_ms": [], "render_gpu_ms": []}
	for key in _speed_monitors:
		_speed[key] = []
	_speed_last_usec = 0
	RenderingServer.viewport_set_measure_render_time(get_tree().get_root().get_viewport_rid(), true)
	_speed["census_start"] = _speed_census()
	if not scripts:
		return ""
	var reply: Variant = await _ask_editor("profile_start", "profiling")
	if reply == null:
		return "the editor did not answer the profiler request"
	if not (reply is Array) or reply.is_empty() or not bool(reply[0]):
		return String(reply[1]) if reply is Array and reply.size() > 1 else "the editor could not start the profiler"
	return ""


func _tick_speed() -> void:
	if not _speed_on:
		return
	var now := Time.get_ticks_usec()
	if _speed_last_usec == 0:
		_speed_last_usec = now
		return
	_speed["frame"].append(Engine.get_process_frames())
	_speed["t_ms"].append(_now_ms())
	_speed["frame_ms"].append(snappedf((now - _speed_last_usec) / 1000.0, 0.01))
	_speed_last_usec = now
	for key in _speed_monitors:
		var total := 0.0
		for id in _speed_monitors[key]:
			total += Performance.get_monitor(id as Performance.Monitor)
		_speed[key].append(snappedf(total * 1000.0 if key.ends_with("_ms") else total, 0.01))
	var viewport := get_tree().get_root().get_viewport_rid()
	_speed["render_cpu_ms"].append(
		snappedf(
			RenderingServer.viewport_get_measured_render_time_cpu(viewport)
			+ RenderingServer.get_frame_setup_time_cpu(),
			0.01
		)
	)
	_speed["render_gpu_ms"].append(
		snappedf(RenderingServer.viewport_get_measured_render_time_gpu(viewport), 0.01)
	)


func _finish_speed(scripts: bool, profiler_error: String) -> Dictionary:
	_speed["census_end"] = _speed_census()
	_speed["physics_ticks_per_second"] = Engine.physics_ticks_per_second
	_speed["max_fps"] = Engine.max_fps
	_speed["vsync"] = DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED
	_speed["renderer"] = (
		RenderingServer.call("get_current_rendering_method")
		if RenderingServer.has_method("get_current_rendering_method")
		else ProjectSettings.get_setting("rendering/renderer/rendering_method")
	)
	_speed["debug_build"] = OS.is_debug_build()
	if not scripts:
		return _speed
	if profiler_error != "":
		_speed["profiler_error"] = profiler_error
		return _speed
	var reply: Variant = await _ask_editor("profile_stop", "profile_saved")
	if not (reply is Array) or reply.is_empty():
		_speed["profiler_error"] = "the editor did not save the profiler data"
		return _speed
	var path := String(reply[0])
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_speed["profiler_error"] = "could not read the profiler data at " + path
		return _speed
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		_speed["profiler"] = parsed
	else:
		_speed["profiler_error"] = "the profiler data at " + path + " is not a JSON object"
	return _speed


func _speed_census() -> Dictionary:
	var counts: Dictionary = {}
	var stack: Array = [get_tree().get_root()]
	var visited := 0
	while not stack.is_empty() and visited < SPEED_CENSUS_NODE_LIMIT:
		var node: Node = stack.pop_back()
		visited += 1
		if node == self:
			continue
		var script: Variant = node.get_script()
		var key := node.get_class()
		if script is Script and (script as Script).resource_path != "":
			key = (script as Script).resource_path
		counts[key] = int(counts.get(key, 0)) + 1
		for child in node.get_children():
			stack.push_back(child)
	var keys: Array = counts.keys()
	keys.sort_custom(func(a, b): return counts[a] > counts[b])
	var top: Dictionary = {}
	for key in keys.slice(0, SPEED_CENSUS_TOP):
		top[key] = counts[key]
	return {"visited": visited, "truncated": not stack.is_empty(), "top": top}


func _start_session() -> void:
	var cfg := _read_sidecar(SESSION_PATH, ["port", "token", "path"])
	if cfg.is_empty():
		return
	_shares_user_cursor = OS.get_environment("ZIVA_VIRTUAL_CURSOR") != "1"
	process_mode = Node.PROCESS_MODE_ALWAYS
	if bool(cfg.get("record", false)):
		_record_dir = String(cfg.get("record_dir", ""))
		if _record_dir.is_empty():
			printerr("ziva_input_harness: the sidecar set record=true but named no record_dir")
		else:
			_build_overlay()
	var url := (
		"ws://127.0.0.1:%d%s?token=%s"
		% [int(cfg["port"]), String(cfg["path"]), String(cfg["token"]).uri_encode()]
	)
	_session_goal = String(cfg.get("goal", ""))
	_ws = WebSocketPeer.new()
	_ws.outbound_buffer_size = 8 << 20
	var err := _ws.connect_to_url(url)
	if err != OK:
		printerr("ziva_input_harness: could not dial the QA session socket at %s (err %d)" % [url, err])
		_ws = null


func _process(delta: float) -> void:
	_tick_speed()
	_tick_recorder(delta)
	if _ws == null:
		return
	_ws.poll()
	var state := _ws.get_ready_state()
	if state == WebSocketPeer.STATE_CLOSED:
		printerr("ziva_input_harness: QA session socket closed (code %d)" % _ws.get_close_code())
		_ws = null
		get_tree().quit()
		return
	if state != WebSocketPeer.STATE_OPEN or _serving:
		return
	if not _greeted:
		_greeted = true
		_serving = true
		_greet()
		return
	if _ws.get_available_packet_count() == 0:
		return
	_serving = true
	_serve(_ws.get_packet().get_string_from_utf8())


func _greet() -> void:
	for i in range(SETTLE_FRAMES):
		await get_tree().process_frame
	_freeze()
	_start_frame = Engine.get_physics_frames()
	var scene: Node = get_tree().current_scene
	_send({"op": "hello", "scene": "" if scene == null else scene.scene_file_path})
	_serving = false


func _freeze() -> void:
	if _running_max_fps == -1:
		_running_max_fps = Engine.max_fps
	Engine.max_fps = PAUSED_RENDER_FPS_CAP
	_game_paused = get_tree().paused
	_frozen = true
	get_tree().paused = true


func _thaw() -> void:
	if _running_max_fps != -1:
		Engine.max_fps = _running_max_fps
	_frozen = false
	get_tree().paused = _game_paused


func _send(payload: Dictionary) -> void:
	var text := JSON.stringify(payload)
	if _ws.send_text(text) == OK:
		return
	printerr("ziva_input_harness: could not send a %d-byte reply for op %s" % [text.length(), str(payload.get("id", -1))])
	var notice := {
		"id": payload.get("id", -1),
		"ok": false,
		"error": (
			"the harness could not put a %d-byte reply on the socket. " % text.length()
			+ "A screenshot of this game is larger than the WebSocket outbound buffer "
			+ "(currently %d bytes); lower MAX_FRAME_EDGE or raise outbound_buffer_size."
			% _ws.outbound_buffer_size
		),
	}
	if _ws.send_text(JSON.stringify(notice)) != OK:
		printerr("ziva_input_harness: the failure notice would not send either; the caller will time out")


func _serve(text: String) -> void:
	var msg: Variant = JSON.parse_string(text)
	if not (msg is Dictionary) or not msg.has("id") or not msg.has("op"):
		printerr("ziva_input_harness: malformed QA session op: " + text)
		_serving = false
		return
	var op := String(msg["op"])
	var reply: Dictionary
	match op:
		"observe":
			reply = await _op_observe(msg)
		"drive":
			reply = await _op_drive(msg)
		"stop":
			if not _record_dir.is_empty():
				_thaw()
				for i in range(RECORD_TAIL_PHYSICS):
					await get_tree().physics_frame
				_freeze()
				_write_recording_json()
			reply = {"ok": true}
		_:
			reply = {"ok": false, "error": "unknown QA session op '" + op + "'"}
	if _pointer_warning != "":
		reply["pointer_unreliable"] = _pointer_warning
		_pointer_warning = ""
	reply["id"] = msg["id"]
	_send(reply)
	if op == "stop":
		for i in range(3):
			_ws.poll()
			await get_tree().process_frame
		get_tree().quit()
		return
	_serving = false


func _jsonable(value: Variant) -> Variant:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT:
			return value
		TYPE_STRING:
			return _capped(value)
		TYPE_STRING_NAME, TYPE_NODE_PATH:
			return _capped(String(value))
		TYPE_OBJECT:
			return _describe_object(value)
		TYPE_DICTIONARY, TYPE_ARRAY:
			var count: int = value.size()
			if count > CONTAINER_LOG_LIMIT:
				return (
					"<%s with %d entries - too large to record; the value itself was returned "
					% [type_string(typeof(value)), count]
					+ "to the caller, but refine the expression if you want it in the log>"
				)
			return _capped(var_to_str(_loggable(value, 0)))
		_:
			return _capped(var_to_str(value))


func _loggable(value: Variant, depth: int) -> Variant:
	if depth > CONTAINER_LOG_DEPTH:
		return "<deeper than %d levels>" % CONTAINER_LOG_DEPTH
	match typeof(value):
		TYPE_OBJECT:
			return _describe_object(value)
		TYPE_ARRAY:
			var items := []
			for item in value:
				items.append(_loggable(item, depth + 1))
			return items
		TYPE_DICTIONARY:
			var pairs := {}
			for key in value:
				pairs[str(key)] = _loggable(value[key], depth + 1)
			return pairs
		_:
			return value


func _describe_object(value: Variant) -> String:
	if value == null:
		return "<freed Object>"
	var obj: Object = value
	if obj is Node:
		var node: Node = obj
		if node.is_inside_tree():
			return "<%s %s>" % [node.get_class(), String(node.get_path())]
		return "<%s %s, not in the tree>" % [node.get_class(), node.name]
	return "<%s>" % obj.get_class()


func _capped(text: String) -> String:
	if text.length() <= PROBE_VALUE_MAX_CHARS:
		return text
	return (
		text.substr(0, PROBE_VALUE_MAX_CHARS)
		+ (
			" ...truncated: %d chars total, full-value hash %d - refine the expression to return just the part you need"
			% [text.length(), hash(text)]
		)
	)


func _eval(expression: String) -> Dictionary:
	var result := _eval_raw(expression)
	if result.has("error"):
		return result
	return {"value": _jsonable(result["value"])}


func _eval_raw(expression: String) -> Dictionary:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return {"error": "there is no current scene to evaluate '" + expression + "' against"}
	var parsed := Expression.new()
	if parsed.parse(expression, ["tree", "root"]) != OK:
		return {"error": "could not parse '" + expression + "': " + parsed.get_error_text()}
	var value: Variant = parsed.execute([get_tree(), get_tree().get_root()], scene, false)
	if parsed.has_execute_failed():
		return {"error": "could not evaluate '" + expression + "': " + parsed.get_error_text()}
	return {"value": value}


func _truthy(value: Variant) -> bool:
	match typeof(value):
		TYPE_NIL:
			return false
		TYPE_BOOL:
			return value
		TYPE_INT:
			return value != 0
		TYPE_FLOAT:
			return value != 0.0
		TYPE_STRING:
			return value != ""
		_:
			return true


func _eval_all(probes: Array) -> Dictionary:
	var values := {}
	for probe in probes:
		values[String(probe)] = _eval(String(probe))
	return values


func _first_probe_error(values: Dictionary) -> String:
	for key in values:
		if (values[key] as Dictionary).has("error"):
			return String(values[key]["error"])
	return ""


func _op_observe(msg: Dictionary) -> Dictionary:
	var values := _eval_all(msg.get("probes", []))
	var bad := _first_probe_error(values)
	if bad != "":
		return {"ok": false, "error": bad}
	var reply := {
		"ok": true,
		"probes": values,
		"frame": Engine.get_physics_frames() - _start_frame,
		"render": {"max_fps": Engine.max_fps, "frames_drawn": Engine.get_frames_drawn()},
	}
	if bool(msg.get("screenshot", false)):
		var shot := await _capture_frame()
		if shot.has("error"):
			return {"ok": false, "error": String(shot["error"])}
		reply["screenshot"] = shot["png_base64"]
		reply["screenshot_size"] = shot["size"]
		reply["viewport_size"] = _viewport_size()
	return reply


func _capture_frame() -> Dictionary:
	var overlay_was_visible := _overlay != null and _overlay.visible
	if overlay_was_visible:
		_overlay.visible = false
	var shot := await _capture_frame_raw()
	if overlay_was_visible:
		_overlay.visible = true
	return shot


func _lift_low_processor() -> void:
	if _low_processor_lifts == 0:
		_app_low_processor = OS.low_processor_usage_mode
		OS.low_processor_usage_mode = false
	_low_processor_lifts += 1


func _restore_low_processor() -> void:
	_low_processor_lifts -= 1
	if _low_processor_lifts == 0 and not OS.low_processor_usage_mode:
		OS.low_processor_usage_mode = _app_low_processor


func _capture_frame_raw() -> Dictionary:
	var drawn_before := Engine.get_frames_drawn()
	var waited := 0
	_lift_low_processor()
	while Engine.get_frames_drawn() == drawn_before and waited < CAPTURE_DRAW_TIMEOUT_FRAMES:
		await get_tree().process_frame
		waited += 1
	_restore_low_processor()
	if Engine.get_frames_drawn() == drawn_before:
		return {
			"error": (
				"the game drew no frame in %d process frames, so there is nothing new to "
				% CAPTURE_DRAW_TIMEOUT_FRAMES
				+ (
					"capture (frames_drawn stuck at %d, window visible=%s). "
					% [drawn_before, get_window().visible]
				)
				+ "A game embedded in the editor's Game tab stops drawing while that window "
				+ "is covered or minimized; raise the editor to capture frames."
			)
		}
	var tex := get_tree().get_root().get_texture()
	if tex == null:
		return {"error": "root viewport texture is null"}
	var img: Image = tex.get_image()
	if img == null or img.is_empty():
		return {"error": "the captured frame was empty"}
	var longest: int = maxi(img.get_width(), img.get_height())
	if longest > MAX_FRAME_EDGE:
		img.resize(
			img.get_width() * MAX_FRAME_EDGE / longest,
			img.get_height() * MAX_FRAME_EDGE / longest,
			Image.INTERPOLATE_LANCZOS
		)
	return {
		"png_base64": Marshalls.raw_to_base64(img.save_png_to_buffer()),
		"size": [img.get_width(), img.get_height()],
	}


func _tick_recorder(delta: float) -> void:
	if _record_dir.is_empty():
		return
	var playing := not _frozen
	if not playing:
		if _overlay_dirty():
			_overlay_draw.queue_redraw()
		return
	_record_live_ms += delta * 1000.0
	var cursor: Vector2 = get_viewport().get_mouse_position()
	if _trail.is_empty() or (_trail[-1] as Vector2).distance_squared_to(cursor) > 4.0:
		_trail.append(cursor)
		if _trail.size() > TRAIL_POINTS:
			_trail.remove_at(0)
	if _overlay_dirty():
		_overlay_draw.queue_redraw()
	if _capturing:
		_capture_waited += 1
		if _capture_waited > CAPTURE_DRAW_TIMEOUT_FRAMES:
			_fail_recording(
				"the game drew no frame in %d process frames while a capture was pending"
				% CAPTURE_DRAW_TIMEOUT_FRAMES
			)
		return
	if not _record_error.is_empty():
		return
	var physics := Engine.get_physics_frames()
	if _record_last_physics >= 0 and physics - _record_last_physics < _record_stride:
		return
	_record_last_physics = physics
	_capture_waited = 0
	_capture_recording_frame()


func _capture_recording_frame() -> void:
	_capturing = true
	_lift_low_processor()
	_record_lifted_low_processor = true
	await RenderingServer.frame_post_draw
	_end_record_low_processor_lift()
	var img: Image = get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		_fail_recording("the viewport read back an empty image")
		return
	var path := "%s/frame_%06d.jpg" % [_record_dir, _record_next]
	var err := img.save_jpg(path, RECORD_JPEG_QUALITY)
	if err != OK:
		_fail_recording("could not write %s (error %d)" % [path, err])
		return
	_record_kept.append(_record_next)
	_record_next += 1
	if _record_kept.size() >= MAX_FRAMES:
		_decimate()
	_write_recording_json()
	_capturing = false


func _decimate() -> void:
	_record_stride *= 2
	var kept := PackedInt32Array()
	for i in range(_record_kept.size()):
		if i % 2 == 0:
			kept.append(_record_kept[i])
		else:
			DirAccess.remove_absolute("%s/frame_%06d.jpg" % [_record_dir, _record_kept[i]])
	_record_kept = kept


func _write_recording_json() -> void:
	var payload := {
		"frames": _record_kept.size(),
		"live_ms": int(_record_live_ms),
		"stride": _record_stride,
		"physics_hz": Engine.physics_ticks_per_second,
	}
	if not _record_error.is_empty():
		payload["error"] = _record_error
	var f := FileAccess.open("%s/recording.json" % _record_dir, FileAccess.WRITE)
	if f == null:
		_record_error = "could not open recording.json in " + _record_dir
		printerr("ziva_input_harness: recording stopped - " + _record_error)
		return
	f.store_string(JSON.stringify(payload))
	f.close()


func _end_record_low_processor_lift() -> void:
	if _record_lifted_low_processor:
		_record_lifted_low_processor = false
		_restore_low_processor()


func _fail_recording(why: String) -> void:
	_record_error = why
	_capturing = false
	_end_record_low_processor_lift()
	printerr("ziva_input_harness: recording stopped - " + why)
	_write_recording_json()


func _build_overlay() -> void:
	_overlay = CanvasLayer.new()
	_overlay.layer = OVERLAY_LAYER
	_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay_draw = Node2D.new()
	_overlay_draw.draw.connect(_draw_overlay)
	_overlay.add_child(_overlay_draw)
	add_child(_overlay)


func _note_overlay_event(event: InputEvent) -> void:
	var label := ""
	var pressed := false
	if event is InputEventKey:
		var key: InputEventKey = event
		if key.is_echo():
			return
		var code: Key = key.keycode if key.keycode != KEY_NONE else key.physical_keycode
		label = OS.get_keycode_string(code) if code != KEY_NONE else String.chr(key.unicode)
		pressed = key.pressed
	elif event is InputEventMouseButton:
		var button: InputEventMouseButton = event
		label = String(MOUSE_LABELS.get(button.button_index, "mouse %d" % button.button_index))
		pressed = button.pressed
		if pressed:
			_ripples.append([get_viewport().get_mouse_position(), Time.get_ticks_msec()])
	elif event is InputEventAction:
		var action: InputEventAction = event
		label = String(action.action)
		pressed = action.pressed
	else:
		return
	if label.is_empty():
		return
	if pressed:
		_held[label] = true
	else:
		_held.erase(label)


func _draw_overlay() -> void:
	var size: Vector2 = get_viewport().get_visible_rect().size
	var font: Font = ThemeDB.fallback_font

	if _trail.size() > 1:
		_overlay_draw.draw_polyline(PackedVector2Array(_trail), TRAIL_COLOR, 3.0)
	var now := Time.get_ticks_msec()
	var alive: Array = []
	for ripple in _ripples:
		var age: float = float(now - int(ripple[1])) / float(RIPPLE_MS)
		if age > 1.0:
			continue
		alive.append(ripple)
		_overlay_draw.draw_arc(
			ripple[0], 12.0 + age * 48.0, 0.0, TAU, 32, Color(CURSOR_COLOR, 1.0 - age), 3.0
		)
	_ripples = alive
	var cursor: Vector2 = get_viewport().get_mouse_position()
	_overlay_draw.draw_arc(cursor, 14.0, 0.0, TAU, 24, CURSOR_COLOR, 3.0)
	_overlay_draw.draw_line(cursor - Vector2(22, 0), cursor + Vector2(22, 0), CURSOR_COLOR, 2.0)
	_overlay_draw.draw_line(cursor - Vector2(0, 22), cursor + Vector2(0, 22), CURSOR_COLOR, 2.0)

	var goal := _intent
	if goal.is_empty():
		goal = ("GOAL: " + _session_goal) if not _session_goal.is_empty() else "no stated goal"
	var under := (
		"paused between actions - Ziva is deciding what to do next"
		if _frozen
		else _input_line(cursor)
	)
	var pad := 22.0
	var goal_size := _fit_caption(font, goal, size.x - 120.0, CAPTION_FONT_SIZE)
	var under_size := CAPTION_SUB_FONT_SIZE
	var goal_w: float = font.get_string_size(goal, HORIZONTAL_ALIGNMENT_LEFT, -1, goal_size).x
	var under_w: float = font.get_string_size(under, HORIZONTAL_ALIGNMENT_LEFT, -1, under_size).x
	var block_w: float = maxf(goal_w, under_w) + pad * 2.0
	var block_h: float = float(goal_size) + float(under_size) + pad * 2.0
	var bx: float = (size.x - block_w) * 0.5
	var by: float = size.y - CHIP_ROW_GAP - block_h
	_overlay_draw.draw_rect(Rect2(bx, by, block_w, block_h), CAPTION_PANEL_COLOR)
	_overlay_draw.draw_rect(Rect2(bx, by, 3.0, block_h), REC_COLOR)
	_overlay_draw.draw_string(
		font, Vector2(bx + pad, by + pad + float(goal_size) * 0.78), goal,
		HORIZONTAL_ALIGNMENT_LEFT, -1, goal_size, Color(0.99, 0.95, 0.74)
	)
	_overlay_draw.draw_string(
		font, Vector2(bx + pad, by + pad + float(goal_size) + float(under_size) * 0.82), under,
		HORIZONTAL_ALIGNMENT_LEFT, -1, under_size, Color(0.74, 0.87, 0.99)
	)

	var labels: Array = _held.keys()
	if not labels.is_empty():
		var widths: Array = []
		var total := 0.0
		for label in labels:
			var w: float = font.get_string_size(
				String(label), HORIZONTAL_ALIGNMENT_LEFT, -1, CHIP_FONT_SIZE
			).x + 30.0
			widths.append(w)
			total += w + 10.0
		var cx: float = (size.x - total) * 0.5
		for i in range(labels.size()):
			var w2: float = widths[i]
			var chip := Rect2(cx, size.y - CHIP_ROW_GAP + 14.0, w2, CHIP_HEIGHT)
			_overlay_draw.draw_rect(chip, CHIP_PANEL_COLOR)
			_overlay_draw.draw_rect(chip, CURSOR_COLOR, false, 2.0)
			_overlay_draw.draw_string(
				font, Vector2(cx + 15.0, chip.position.y + 24.0), String(labels[i]),
				HORIZONTAL_ALIGNMENT_LEFT, -1, CHIP_FONT_SIZE, Color(1, 1, 1, 0.97)
			)
			cx += w2 + 10.0

	var rec_y := size.y - OVERLAY_PAD - 7.0
	_overlay_draw.draw_circle(
		Vector2(OVERLAY_PAD + 7.0, rec_y), 7.0,
		Color(0.55, 0.55, 0.6) if _frozen else REC_COLOR
	)
	var rec_label := "PAUSED" if _frozen else "REC"
	_overlay_draw.draw_string(
		font, Vector2(OVERLAY_PAD + 23.0, rec_y + 8.0), rec_label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, CHIP_FONT_SIZE, Color(0, 0, 0, 0.55)
	)
	_overlay_draw.draw_string(
		font, Vector2(OVERLAY_PAD + 22.0, rec_y + 7.0), rec_label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, CHIP_FONT_SIZE, Color(1, 1, 1, 0.93)
	)


func _overlay_dirty() -> bool:
	var cursor: Vector2i = Vector2i(get_viewport().get_mouse_position())
	if (
		cursor == _sig_cursor
		and _held.size() == _sig_held
		and _intent.length() == _sig_intent
		and _ripples.size() == _sig_ripples
		and _frozen == _sig_frozen
	):
		return false
	_sig_cursor = cursor
	_sig_held = _held.size()
	_sig_intent = _intent.length()
	_sig_ripples = _ripples.size()
	_sig_frozen = _frozen
	return true


func _fit_caption(font: Font, text: String, limit: float, base: int) -> int:
	var key := "%s|%d|%d" % [text, int(limit), base]
	if _caption_fit.has(key):
		return int(_caption_fit[key])
	var size_px := base
	while size_px > CAPTION_FONT_MIN:
		if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x <= limit:
			break
		size_px -= 1
	if _caption_fit.size() > 64:
		_caption_fit.clear()
	_caption_fit[key] = size_px
	return size_px


func _input_line(cursor: Vector2) -> String:
	var held := "nothing held" if _held.is_empty() else ", ".join(PackedStringArray(_held.keys()))
	return "game receives: %s | pointer %d,%d" % [held, int(cursor.x), int(cursor.y)]


func _drag_point(entry: Dictionary, key: String) -> Variant:
	var spec: Variant = entry.get(key)
	if spec is Dictionary and (spec as Dictionary).has("x") and (spec as Dictionary).has("y"):
		return Vector2(float(spec["x"]), float(spec["y"]))
	if spec is String:
		var control: Control = _resolve_target(String(spec))
		if control == null:
			return "no Control matched %s '%s'" % [key, String(spec)]
		return control.get_global_rect().get_center()
	return "drag needs %s as {\"x\":<px>,\"y\":<px>} or a Control name" % key


func _dispatch_drag(entry: Dictionary, label: String) -> Dictionary:
	var from_point: Variant = _drag_point(entry, "from")
	if from_point is String:
		return {"label": label, "type": "drag", "dropped": from_point}
	var to_point: Variant = _drag_point(entry, "to")
	if to_point is String:
		return {"label": label, "type": "drag", "dropped": to_point}
	var start: Vector2 = from_point
	var end: Vector2 = to_point
	var steps: int = maxi(int(entry.get("frames", 12)), 2)
	var button: MouseButton = _button_index(entry)

	var press_frame := Engine.get_physics_frames() - _start_frame
	_move_mouse(start, Vector2.ZERO)
	await get_tree().physics_frame
	_click_at(start, button, true)
	await get_tree().physics_frame

	var previous := start
	for step in range(1, steps + 1):
		var point: Vector2 = start.lerp(end, float(step) / float(steps))
		_move_mouse(point, point - previous)
		previous = point
		await get_tree().physics_frame

	var extra: int = maxi(int(entry.get("hold_frames", 0)), 0)
	for _i in range(extra):
		await get_tree().physics_frame

	_click_at(end, button, false)
	await get_tree().physics_frame
	return {
		"label": label,
		"type": "drag",
		"press_frame": press_frame,
		"release_frame": Engine.get_physics_frames() - _start_frame,
		"from": [start.x, start.y],
		"to": [end.x, end.y],
		"frames": steps,
		"released": true,
	}


func _move_mouse(position: Vector2, relative: Vector2) -> void:
	if not _shares_user_cursor:
		Input.warp_mouse(_to_window(position))
	elif not _warp_skip_logged:
		_warp_skip_logged = true
		print(
			"ziva_input_harness: not moving the cursor: this game shares the user's desktop "
			+ "(no ZIVA_VIRTUAL_CURSOR), so the pointer moves by events only"
		)
	var motion := InputEventMouseMotion.new()
	motion.position = _to_window(position)
	motion.global_position = motion.position
	motion.relative = _to_window_delta(relative)
	_inject(motion)
	if not _pointer_checked and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		_check_polled_pointer(position)


func _check_polled_pointer(placed: Vector2) -> void:
	_pointer_checked = true
	var polled := get_viewport().get_mouse_position()
	if polled.distance_to(placed) <= 2.0:
		return
	var cause := (
		(
			"On a background Windows or macOS playtest this means the virtual cursor shim is "
			+ "not active (see the game log)."
		)
		if not _shares_user_cursor
		else (
			"This game runs from a visible part editor, so the harness does not move the "
			+ "user's real cursor."
		)
	)
	_pointer_warning = (
		"Polled cursor disagrees with injected input: the pointer was placed at %s but " % placed
		+ "get_viewport().get_mouse_position() reads %s. %s Judge drag/aim " % [polled, cause]
		+ "by events and frames, not polled cursor values."
	)
	printerr("ziva_input_harness: " + _pointer_warning)


func _to_window(position: Vector2) -> Vector2:
	return get_viewport().get_final_transform() * position


func _to_window_delta(relative: Vector2) -> Vector2:
	return get_viewport().get_final_transform().basis_xform(relative)


func _viewport_size() -> Array:
	var size: Vector2 = get_viewport().get_visible_rect().size
	return [int(size.x), int(size.y)]


class DriveApi:
	var _h: Node
	var calls: Array = []
	var logs: Array = []
	var held: Dictionary = {}
	var fault := ""
	var dead := false
	var unfinished := 0
	var start_physics: int
	var frame_budget: int
	var deadline_ms: int

	func _init(harness: Node, budget: int) -> void:
		_h = harness
		frame_budget = budget
		start_physics = Engine.get_physics_frames()
		deadline_ms = Time.get_ticks_msec() + harness.UNTIL_WALL_CLOCK_BUDGET_MS

	func _enter(name: String, summary: String) -> bool:
		if dead:
			return false
		calls.append({
			"call": name,
			"args": summary.left(160),
			"physics_frame": Engine.get_physics_frames() - _h._start_frame,
		})
		if fault != "":
			return false
		if Engine.get_physics_frames() - start_physics >= frame_budget:
			fault = "the drive's %d-physics-frame budget is exhausted" % frame_budget
			return false
		if Time.get_ticks_msec() >= deadline_ms:
			fault = "the drive ran out of wall clock (%ds)" % (_h.UNTIL_WALL_CLOCK_BUDGET_MS / 1000)
			return false
		unfinished += 1
		return true

	func _finish(outcome: Variant = null) -> void:
		if outcome != null:
			(calls.back() as Dictionary)["outcome"] = outcome
		unfinished -= 1

	func _press_now(entry: Dictionary) -> String:
		var kind := String(entry.get("type", "action"))
		if kind == "drag":
			return "use `await api.drag(from, to, frames)` for drags"
		if kind == "key" and not String(entry.get("target", "")).is_empty():
			return (
				"a drive cannot press a key at a 'target': `await api.tap({\"type\": \"target\", "
				+ "\"target\": ...})` to click-focus the field first, then press keys with no target"
			)
		return _h._dispatch_edge(entry, true)

	func press(entry: Dictionary) -> bool:
		if not _enter("press", str(entry)):
			return false
		var problem := _press_now(entry)
		if problem == "" and String(entry.get("type", "action")) != "motion":
			held[_h._label(entry)] = entry.duplicate()
		if problem != "":
			fault = "press: " + problem
		_finish()
		return problem == ""

	func release(entry: Dictionary) -> bool:
		if not _enter("release", str(entry)):
			return false
		var label: String = _h._label(entry)
		var problem := ""
		if not held.has(label):
			problem = "release: %s is not held by this drive (held: %s)" % [label, str(held.keys())]
		else:
			problem = _h._dispatch_edge(entry, false)
			held.erase(label)
		if problem != "":
			fault = problem
		_finish()
		return problem == ""

	func _refuse_yielding() -> bool:
		await _h.get_tree().physics_frame
		return false

	func tap(entry: Dictionary, hold_frames: int = 4) -> bool:
		if not _enter("tap", str(entry)):
			return await _refuse_yielding()
		await _h.get_tree().physics_frame
		if dead:
			return false
		var problem := _press_now(entry)
		if problem == "":
			var edgeless := String(entry.get("type", "action")) == "motion"
			for _i in range(maxi(hold_frames, _h.MIN_HOLD_FRAMES)):
				await _h.get_tree().physics_frame
				if dead:
					if not edgeless:
						_h._dispatch_edge(entry, false)
					return false
			if not edgeless:
				problem = _h._dispatch_edge(entry, false)
				await _h.get_tree().physics_frame
				if dead:
					return false
		if problem != "":
			fault = "tap: " + problem
		_finish()
		return problem == ""

	func drag(from: Variant, to: Variant, frames: int = 12) -> bool:
		if not _enter("drag", "%s -> %s over %d" % [str(from), str(to), frames]):
			return await _refuse_yielding()
		var entry := {"type": "drag", "from": _point(from), "to": _point(to), "frames": frames}
		var record: Dictionary = await _h._dispatch_drag(entry, _h._label(entry))
		if dead:
			return false
		var problem := String(record.get("dropped", ""))
		if problem != "":
			fault = "drag: " + problem
		_finish()
		return problem == ""

	func move_mouse(to: Variant) -> bool:
		if not _enter("move_mouse", str(to)):
			return false
		var problem := ""
		var point: Variant = _point(to)
		if point is Dictionary and (point as Dictionary).has("x") and (point as Dictionary).has("y"):
			_h._move_mouse(Vector2(float(point["x"]), float(point["y"])), Vector2.ZERO)
		elif point is String:
			var control: Control = _h._resolve_target(String(point))
			if control == null:
				problem = "move_mouse: no Control matched '%s'" % String(point)
			else:
				_h._move_mouse(control.get_global_rect().get_center(), Vector2.ZERO)
		else:
			problem = "move_mouse needs a Vector2, an {x, y} dictionary, or a Control name"
		if problem != "":
			fault = problem
		_finish()
		return problem == ""

	func eval(expression: String) -> Variant:
		if not _enter("eval", expression):
			return null
		var result: Dictionary = _h._eval_raw(expression)
		if result.has("error"):
			fault = "eval: " + String(result["error"])
			_finish()
			return null
		_finish(_h._jsonable(result["value"]))
		return result["value"]

	func until(expression: String, max_physics_frames: int) -> bool:
		if not _enter("until", expression):
			return await _refuse_yielding()
		var waited := 0
		var satisfied := false
		while true:
			var probed: Dictionary = _h._eval_raw(expression)
			if probed.has("error"):
				fault = "until: " + String(probed["error"])
				_finish({"satisfied": false, "frames_waited": waited})
				return false
			if _h._truthy(probed["value"]):
				satisfied = true
				break
			if waited >= max_physics_frames:
				break
			if Engine.get_physics_frames() - start_physics >= frame_budget:
				fault = (
					"the drive's %d-physics-frame budget ran out inside until(\"%s\")"
					% [frame_budget, expression]
				)
				break
			if Time.get_ticks_msec() >= deadline_ms:
				fault = "the drive ran out of wall clock inside until(\"%s\")" % expression
				break
			await _h.get_tree().physics_frame
			if dead:
				return false
			waited += 1
		_finish({"satisfied": satisfied, "frames_waited": waited})
		return satisfied

	func wait_physics(frames: int) -> bool:
		if not _enter("wait_physics", str(frames)):
			return await _refuse_yielding()
		for _i in range(maxi(frames, 0)):
			if Engine.get_physics_frames() - start_physics >= frame_budget:
				fault = "the drive's %d-physics-frame budget ran out inside wait_physics" % frame_budget
				break
			if Time.get_ticks_msec() >= deadline_ms:
				fault = "the drive ran out of wall clock inside wait_physics"
				break
			await _h.get_tree().physics_frame
			if dead:
				return false
		_finish()
		return fault == ""

	func log(message: Variant) -> void:
		if not _enter("log", ""):
			return
		logs.append(_h._capped(str(message)))
		_finish()

	static func _point(p: Variant) -> Variant:
		if p is Vector2:
			return {"x": (p as Vector2).x, "y": (p as Vector2).y}
		return p


func _compile_drive(source: String) -> Variant:
	var uses_tabs := false
	for line in source.split("\n"):
		if line.begins_with("\t"):
			uses_tabs = true
			break
	var indent := "\t" if uses_tabs else "    "
	var body := ""
	for line in source.split("\n"):
		body += indent + line + "\n"
	var script := GDScript.new()
	script.source_code = "extends RefCounted\nfunc run(api):\n" + body
	if script.reload() != OK:
		return (
			"the drive source did not compile. Send only the statements of a function BODY "
			+ "(no `func` header), indent nested blocks consistently with tabs or spaces "
			+ "(never both), and remember this is GDScript, not Python: `var x = ...`, "
			+ "`str(...)`, no f-strings. The editor log has the parser's exact message."
		)
	return script


func _run_drive_body(runner: RefCounted, api: DriveApi, done: Dictionary) -> void:
	done["returned"] = await runner.run(api)
	done["finished"] = true


func _op_drive(msg: Dictionary) -> Dictionary:
	_intent = String(msg.get("intent", ""))
	var source := String(msg.get("source", ""))
	if source.strip_edges().is_empty():
		return {"ok": false, "error": "game_drive needs `source`: the statements of a GDScript function body"}
	if source.length() > DRIVE_SOURCE_MAX_CHARS:
		return {
			"ok": false,
			"error": (
				"the drive source is %d chars; more than %d is not one maneuver - split it"
				% [source.length(), DRIVE_SOURCE_MAX_CHARS]
			),
		}
	var compiled: Variant = _compile_drive(source)
	if compiled is String:
		return {"ok": false, "error": compiled}
	var runner: RefCounted = (compiled as GDScript).new()
	var api := DriveApi.new(self, maxi(int(msg.get("max_physics_frames", 600)), 1))
	var start := Engine.get_physics_frames()
	_thaw()
	var done := {"finished": false, "returned": null}
	_run_drive_body(runner, api, done)
	var body_deadline := Time.get_ticks_msec() + UNTIL_WALL_CLOCK_BUDGET_MS
	var fault_grace := -1
	while not bool(done["finished"]) and Time.get_ticks_msec() < body_deadline:
		if fault_grace == -1 and api.fault != "":
			fault_grace = Time.get_ticks_msec() + 3000
		if fault_grace != -1 and Time.get_ticks_msec() >= fault_grace:
			break
		await get_tree().process_frame
	var returned: Variant = done["returned"]
	if not bool(done["finished"]):
		var note := (
			"The body never returned and was abandoned mid-flight: its api is dead and "
			+ "anything it held was released, but its coroutine cannot be killed - avoid "
			+ "unbounded loops in drive bodies; give every loop an exit."
		)
		api.fault = note if api.fault == "" else api.fault + " | " + note
	if api.fault == "" and api.unfinished > 0:
		api.fault = (
			"%d api call(s) were started but never finished: the body called an async api "
			% api.unfinished
			+ "function without `await`. The calls that span time (tap, drag, until, "
			+ "wait_physics) must be awaited: `await api.tap(...)`. The abandoned call may "
			+ "have left an input pressed, so this drive's results are unusable."
		)
	api.dead = true
	var released: Array = []
	for label in api.held:
		_dispatch_edge(api.held[label], false)
		released.append(label)
	if not released.is_empty():
		await get_tree().physics_frame
	_freeze()
	var reply := {
		"ok": api.fault == "",
		"calls": api.calls,
		"physics_frames": Engine.get_physics_frames() - start,
	}
	if not api.logs.is_empty():
		reply["log"] = api.logs
	if not released.is_empty():
		reply["released_at_end"] = released
	if api.fault != "":
		reply["error"] = (
			api.fault + " | last calls: " + _capped(JSON.stringify(api.calls.slice(-DRIVE_FAULT_CALLS)))
		)
	else:
		reply["returned"] = _jsonable(returned)
	return reply
