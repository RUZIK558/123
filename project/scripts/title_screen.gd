extends Node2D
## TitleScreen — титульный экран LowerTale в стиле Undertale.

const VIEW := Vector2(640, 360)

var _font: Font
var _items := ["НОВАЯ ИГРА", "ПРОДОЛЖИТЬ", "НАСТРОЙКИ"]
var _index := 0
var _has_save := false
var _mode := "menu"          # menu | settings | intro
var _soul_pos := Vector2(320, 250)
var _time := 0.0
var _settings_index := 0
var _settings := ["СКОРОСТЬ ТЕКСТА", "ВЕРНУТЬСЯ"]
var _intro_lines: Array = []
var _tw: Node2D

func _ready() -> void:
	_font = load("res://fonts/main_font.ttf")
	_has_save = GameState.has_save(0)
	set_process(true)

func _process(delta: float) -> void:
	_time += delta
	if _mode == "menu":
		var t := clampf(_time / 3.0, 0.0, 1.0)
		_soul_pos = Vector2(320, 150 + 100 * t)
		if _time > 3.0 and not _has_save:
			# лёгкое покачивание души на месте
			_soul_pos.y = 250 + sin(_time * 2.0) * 3.0
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match _mode:
			"menu":
				if event.physical_keycode in [KEY_LEFT, KEY_A]:
					_index = (_index - 1) % _items.size(); AudioManager.cursor_move()
				elif event.physical_keycode in [KEY_RIGHT, KEY_D]:
					_index = (_index + 1) % _items.size(); AudioManager.cursor_move()
				elif event.physical_keycode in [KEY_Z, KEY_ENTER, KEY_SPACE, KEY_E]:
					_confirm()
			"settings":
				if event.physical_keycode in [KEY_UP, KEY_W]:
					_settings_index = wrapi(_settings_index - 1, 0, _settings.size()); AudioManager.cursor_move()
				elif event.physical_keycode in [KEY_DOWN, KEY_S]:
					_settings_index = wrapi(_settings_index + 1, 0, _settings.size()); AudioManager.cursor_move()
				elif event.physical_keycode in [KEY_LEFT, KEY_A]:
					if _settings_index == 0:
						GameState.text_speed = clampf(GameState.text_speed + 0.01, 0.01, 0.09); AudioManager.cursor_move()
				elif event.physical_keycode in [KEY_RIGHT, KEY_D]:
					if _settings_index == 0:
						GameState.text_speed = clampf(GameState.text_speed - 0.01, 0.01, 0.09); AudioManager.cursor_move()
				elif event.physical_keycode in [KEY_Z, KEY_ENTER, KEY_SPACE]:
					if _settings_index == _settings.size() - 1:
						_mode = "menu"; AudioManager.confirm()
				elif event.physical_keycode == KEY_ESCAPE:
					_mode = "menu"; AudioManager.cancel()
			"intro":
				if event.physical_keycode in [KEY_Z, KEY_ENTER, KEY_SPACE, KEY_E]:
					get_tree().change_scene_to_file("res://scenes/overworld.tscn")

func _confirm() -> void:
	match _index:
		0:
			GameState.reset_for_new_game()
			GameState.current_location = "fall"
			AudioManager.confirm()
			_start_intro()
		1:
			if _has_save and GameState.load_game(0):
				AudioManager.confirm()
				get_tree().change_scene_to_file("res://scenes/overworld.tscn")
			else:
				AudioManager.cancel()
		2:
			_mode = "settings"
			_settings_index = 0
			AudioManager.confirm()

func _start_intro() -> void:
	_mode = "intro"
	_tw = preload("res://scripts/typewriter_text.gd").new()
	add_child(_tw)
	_tw.setup(Rect2(120, 140, 400, 120), 12)
	_tw.set_text(
		"Давным-давно два мира разделились.\n" +
		"Один — наверху, под солнцем.\n" +
		"Другой — внизу, в тишине камня.\n\n" +
		"Однажды ты упал(а) между ними...\n" +
		"Добро пожаловать в LOWER TALE."
	)

func _draw() -> void:
	var vs := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vs), Color.BLACK)
	# заголовок
	var title := "LowerTale"
	var ts := 48.0
	draw_string(_font, Vector2(0, 90), title, HORIZONTAL_ALIGNMENT_CENTER, vs.x, ts, Color.WHITE)
	draw_string(_font, Vector2(0, 118), "* сказание о тех, кто пал вниз *", HORIZONTAL_ALIGNMENT_CENTER, vs.x, 12, Color(0.7, 0.7, 0.7))
	# падающая душа
	if _mode == "menu":
		if ResourceLoader.exists("res://sprites/soul_red.png"):
			var spr: Texture2D = load("res://sprites/soul_red.png")
			draw_texture(spr, _soul_pos - spr.get_size() * 0.5)
	# меню
	for i in _items.size():
		var col := Color.WHITE if i == _index and _mode == "menu" else Color(0.55, 0.55, 0.55)
		if i == 1 and not _has_save:
			col = Color(col.r, col.g, col.b, 0.35)
		var x := 120.0 + i * 160.0
		draw_string(_font, Vector2(x, 300), _items[i], HORIZONTAL_ALIGNMENT_LEFT, 150, 14, col)
		if i == _index and _mode == "menu":
			if ResourceLoader.exists("res://sprites/heart_ui.png"):
				draw_texture(load("res://sprites/heart_ui.png"), Vector2(x - 24, 290))
	# настройки
	if _mode == "settings":
		var sw := maxf(vs.x, 640.0)
		draw_rect(Rect2((sw - 360) * 0.5, 150, 360, 120), Color(0.08, 0.08, 0.08))
		draw_rect(Rect2((sw - 360) * 0.5, 150, 360, 120), Color.WHITE, false, 2)
		for j in _settings.size():
			var c := Color.WHITE if j == _settings_index else Color(0.6, 0.6, 0.6)
			var txt: String = str(_settings[j])
			if j == 0:
				var lvl := int(round((0.1 - GameState.text_speed) * 100.0))
				txt += ": " + ">".repeat(clampi(lvl, 1, 9))
			draw_string(_font, Vector2((sw - 360) * 0.5 + 30, 185 + j * 30), txt, HORIZONTAL_ALIGNMENT_LEFT, 320, 13, c)
	# интро
	if _mode == "intro":
		draw_string(_font, Vector2(0, 330), "[Z] продолжить", HORIZONTAL_ALIGNMENT_CENTER, vs.x, 11, Color(0.5, 0.5, 0.5))
	draw_string(_font, Vector2(0, vs.y - 8), "© LowerTale Team — сделано в Godot 4", HORIZONTAL_ALIGNMENT_CENTER, vs.x, 9, Color(0.4, 0.4, 0.4))
