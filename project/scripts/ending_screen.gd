extends Node2D
## EndingScreen — финальные титры LowerTale.

const VIEW := Vector2(640, 360)

var lines: Array = []
var route_name := "NEUTRAL"
var _font: Font
var _index := 0
var _tw: Node2D
var _done := false
var _time := 0.0

func _ready() -> void:
	z_index = 200
	set_process_input(true)
	move_to_front()
	_font = load("res://fonts/main_font.ttf")
	_tw = preload("res://scripts/typewriter_text.gd").new()
	add_child(_tw)
	_tw.setup(Rect2(120, 150, 400, 140), 12)
	_tw.line_finished.connect(func(): _show_next())
	if AudioManager.has_method("play_music"):
		AudioManager.play_music("hope" if route_name == "TRUE PACIFIST" else ("genocide" if route_name == "GENOCIDE" else "sad"))
	_show_next()

func _show_next() -> void:
	if _index >= lines.size():
		_done = true
		queue_redraw()
		return
	var l = lines[_index]
	_index += 1
	_tw.set_text(str(l))
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode in [KEY_Z, KEY_ENTER, KEY_SPACE, KEY_E]:
			if _done:
				get_tree().change_scene_to_file("res://scenes/title_screen.tscn")
			elif _tw.has_method("skip"):
				_tw.skip()

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW), Color.BLACK)
	var col := Color(1.0, 0.85, 0.4) if route_name == "TRUE PACIFIST" else (Color(0.9, 0.2, 0.2) if route_name == "GENOCIDE" else Color.WHITE)
	draw_string(_font, Vector2(0, 60), route_name, HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 28, col)
	draw_string(_font, Vector2(0, 90), ("* КОНЕЦ *" if _done else ""), HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 12, Color(0.7, 0.7, 0.7))
	if _done:
		draw_string(_font, Vector2(0, 330), "[Z] — в титульный экран", HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 12, Color(0.6, 0.6, 0.6))
