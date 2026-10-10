extends Node2D
## DialogueBox — нижняя рамка диалогов в стиле Undertale.

signal dialogue_finished

var lines: Array = []
var index := 0
var tw: Node2D
var _font: Font
var active := false
var box_rect := Rect2(140, 250, 360, 90)

func _ready() -> void:
	_font = preload("res://fonts/main_font.ttf")
	tw = preload("res://scripts/typewriter_text.gd").new()
	add_child(tw)
	tw.setup(Rect2(box_rect.position + Vector2(14, 8), Vector2(box_rect.size.x - 28, box_rect.size.y - 16)), 12)
	tw.line_finished.connect(_on_tw_done)
	set_z_index(100)

func start(ls: Array) -> void:
	lines = ls.filter(func(l): return str(l).strip_edges() != "")
	if lines.is_empty():
		dialogue_finished.emit()
		return
	index = 0
	active = true
	GameState.dialogue_active = true
	_show_current()

func _show_current() -> void:
	tw.set_text(str(lines[index]))
	queue_redraw()

func _on_tw_done() -> void:
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		if not tw.done:
			tw.skip()
		else:
			index += 1
			if index >= lines.size():
				active = false
				GameState.dialogue_active = false
				AudioManager.cancel()
				hide_box()
				dialogue_finished.emit()
			else:
				_show_current()

func hide_box() -> void:
	visible = false
	queue_redraw()

func _draw() -> void:
	if not active:
		return
	visible = true
	draw_rect(box_rect, Color(0, 0, 0), true)
	draw_rect(box_rect, Color.WHITE, false, 3.0)
	# стрелка-подсказка, когда строка договорена
	if tw.done and index < lines.size() - 1:
		var t := Time.get_ticks_msec() / 300.0
		draw_string(_font, Vector2(box_rect.end.x - 24, box_rect.end.y - 10 + sin(t) * 2.0), "▼", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 0.85, 0.2))
