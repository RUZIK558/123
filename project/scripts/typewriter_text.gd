extends Node2D
## TypewriterText — печатающийся текст в стиле Undertale (отрисовка draw_string).

signal line_finished

var text := ""
var shown := 0.0
var speed := 45.0            # символов в секунду
var rect := Rect2(160, 200, 320, 110)
var font_size := 12
var color := Color.WHITE
var _font: Font
var done := false

func setup(r: Rect2, fs := 12) -> void:
	rect = r
	font_size = fs

func set_text(t: String) -> void:
	text = t
	shown = 0.0
	done = false
	queue_redraw()

func skip() -> void:
	shown = float(text.length())
	if not done:
		done = true
		line_finished.emit()
	queue_redraw()

func _ready() -> void:
	_font = preload("res://fonts/main_font.ttf")

func _process(delta: float) -> void:
	if done:
		return
	var before := int(shown)
	shown += delta * speed
	# паузы на знаках препинания
	if before < text.length():
		var ch := text[before]
		if ch in [".", "!", "?", ",", ";", ":", "…"]:
			shown -= delta * speed * 0.8
	if int(shown) > before and before < text.length():
		AudioManager.type_tick()
	if shown >= float(text.length()):
		shown = float(text.length())
		done = true
		line_finished.emit()
	queue_redraw()

func _draw() -> void:
	if text.is_empty():
		return
	var vis := text.substr(0, int(shown))
	draw_multiline_string(_font, rect.position + Vector2(0, font_size), vis, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 4, font_size, color)
