extends Node2D
## BattleScreen — боевая система в стиле Undertale.
## Фазы: intro -> menu(БОЙ/ДЕЙСТВ/ПРЕДМ/ПОЩАДА) -> player_action -> enemy_turn (уворачивание душой) -> repeat.
## Убить можно только через БОЙ; пощадить — через ПОЩАДУ, когда шкала милости заполнена ACT-действиями.

signal battle_ended(result: String, monster_id: String)   # "spared" | "killed" | "fled"

const ARENA := Rect2(160, 196, 320, 120)
const MENU_LABELS := ["БОЙ", "ДЕЙСТВ", "ПРЕДМ", "ПОЩАДА"]

var monster_data: Dictionary = {}
var monster_id := ""
var m_hp := 0
var m_max_hp := 0
var mercy := 0.0
var turn := 0
var phase := "intro"
var pending_after: Array = []
var after_result := ""

var menu_index := 0
var sub_index := 0
var sub_options: Array = []
var sub_callback: Callable = Callable()
var msg_done := false

var attack_active := false
var attack_pos := 0.0
var attack_dir := 1.0
var attack_speed := 3.4

var bullets: Array[Node2D] = []
var enemy_attack_time := 0.0
var current_pattern := ""
var spawn_interval := 0.0
var spawn_accum := 0.0
var pattern_duration := 4.5

var soul: Node2D
var soul_speed := 95.0
var invuln := 0.0

var _font: Font
var _tw: Node2D
var shake := 0.0

var _msg_queue: Array[String] = []
var _msg_index := 0

func setup(mid: String, data: Dictionary, after_events: Array = []) -> void:
	monster_id = mid
	monster_data = data
	pending_after = after_events
	m_max_hp = int(data.get("hp", 30))
	m_hp = m_max_hp

func _ready() -> void:
	_font = preload("res://fonts/main_font.ttf")
	_tw = preload("res://scripts/typewriter_text.gd").new()
	add_child(_tw)
	_tw.setup(Rect2(ARENA.position + Vector2(8, 8), ARENA.size - Vector2(16, 16)), ARENA.size.x - 24)
	_tw.line_finished.connect(func(): msg_done = true)
	soul = Node2D.new()
	soul.position = ARENA.get_center()
	add_child(soul)
	GameState.dialogue_active = true
	if ResourceLoader.exists("res://sprites/soul_red.png"):
		var spr := Sprite2D.new()
		spr.texture = load("res://sprites/soul_red.png")
		spr.scale = Vector2(0.7, 0.7)
		soul.add_child(spr)
	AudioManager.play_music("boss" if monster_data.get("boss", false) else "battle")
	_set_phase_intro()

# ---------------- фазы ----------------

func _set_phase_intro() -> void:
	phase = "intro"
	msg_done = false
	_tw.set_text(str(monster_data.get("intro", "* Появился враг!")))

func _set_phase_menu() -> void:
	phase = "menu"
	menu_index = 0
	queue_redraw()

func _start_player_action() -> void:
	phase = "player_action"
	sub_index = 0
	match menu_index:
		0: _begin_fight()
		1: _build_sub(_act_options(), func(i): _do_act(sub_options[i]))
		2: _build_sub(_item_options(), func(i): _do_item(sub_options[i]))
		3: _build_sub(_mercy_options(), func(i): _do_mercy(sub_options[i]))

func _build_sub(opts: Array, cb: Callable) -> void:
	sub_options = opts
	sub_callback = cb
	if opts.is_empty():
		_show_msg("* Пусто... но бой продолжается!")
		await get_tree().create_timer(0.5).timeout
		_set_phase_menu()
	else:
		phase = "submenu"
		queue_redraw()

func _show_msg(t: String) -> void:
	msg_done = false
	_tw.set_text(t)
	phase = "message"

# ---------------- БОЙ ----------------

func _begin_fight() -> void:
	phase = "attack_bar"
	attack_pos = 0.0
	attack_dir = 1.0
	attack_speed = clampf(2.6 + GameState.lv * 0.15 + float(monster_data.get("atk", 4)) * 0.08, 2.4, 5.2)

func _finish_attack_bar() -> void:
	phase = "message"
	var offset := absf(attack_pos - 0.5)
	var dmg := 0
	if offset < 0.06:
		dmg = int(GameState.atk * 2.2)
	elif offset < 0.18:
		dmg = int(GameState.atk * 1.4)
	elif offset < 0.34:
		dmg = int(GameState.atk * 0.8)
	else:
		dmg = maxi(1, int(GameState.atk * 0.25))
	dmg += randi_range(-1, 2)
	dmg = maxi(0, dmg - int(monster_data.get("def", 0)))
	m_hp = maxi(0, m_hp - dmg)
	shake = 0.35
	AudioManager.boss_hit()
	if dmg <= 0:
		_show_msg("* Промах!\n* Враг едва заметил.")
	else:
		_show_msg("* Ты рубишь на %d урона!" % dmg)
	await get_tree().create_timer(0.7).timeout
	if m_hp <= 0:
		_win_by_kill()
	else:
		_start_enemy_turn()

# ---------------- ДЕЙСТВОВАТЬ ----------------

func _act_options() -> Array:
	var acts: Dictionary = monster_data.get("acts", {})
	var out: Array = []
	for k in acts.keys():
		out.append({"key": k, "label": str(k).replace("_", " ").to_upper()})
	return out

func _do_act(opt: Dictionary) -> void:
	var act: Dictionary = monster_data["acts"][opt.key]
	mercy = clampf(mercy + float(act.get("mercy", 25)), 0, 100)
	_show_msg(str(act.get("text", "* Ты пробуешь договориться.")))
	await get_tree().create_timer(0.6).timeout
	_start_enemy_turn()

# ---------------- ПРЕДМЕТ ----------------

func _item_options() -> Array:
	var out: Array = []
	for id in GameState.inventory.keys():
		var it: Dictionary = DataLoader.get_item(id)
		if it.is_empty():
			continue
		out.append({"id": id, "label": "%s x%d" % [it.name, GameState.item_count(id)]})
	return out

func _do_item(opt: Dictionary) -> void:
	var it: Dictionary = DataLoader.get_item(opt.id)
	GameState.remove_item(opt.id)
	var heal_amt := int(it.get("heal", 0))
	if heal_amt > 0:
		GameState.heal(heal_amt)
		AudioManager.heal_sound()
		_show_msg("* Ты ешь %s.\n* Восстановлено %d HP." % [it.name, heal_amt])
	else:
		_show_msg("* Ты используешь %s.\n* Хм. Неочевидно, но красиво." % it.name)
	await get_tree().create_timer(0.6).timeout
	_start_enemy_turn()

# ---------------- ПОЩАДА ----------------

func _mercy_options() -> Array:
	return [{"key": "spare", "label": "ПОЩАДИТЬ"}, {"key": "flee", "label": "СБЕЖАТЬ"}]

func _do_mercy(opt: Dictionary) -> void:
	if opt.key == "flee":
		_show_msg("* Ты сбегаешь из боя!")
		AudioManager.cancel()
		await get_tree().create_timer(0.5).timeout
		_finish_battle("fled")
		return
	if mercy >= 99.0:
		_show_msg(str(monster_data.get("spare_text", "* Враг хочет мира.")))
		AudioManager.confirm()
		await get_tree().create_timer(0.8).timeout
		_win_by_spare()
	else:
		_show_msg(DialogueDB.get_line("mercy_low"))
		await get_tree().create_timer(0.5).timeout
		_start_enemy_turn()

# ---------------- ход врага ----------------

func _start_enemy_turn() -> void:
	turn += 1
	phase = "enemy_turn"
	_tw.set_text("")
	msg_done = true
	var patterns: Array = monster_data.get("attack_patterns", ["spores_rain"])
	current_pattern = str(patterns[randi() % patterns.size()])
	enemy_attack_time = 0.0
	spawn_accum = 0.0
	_clear_bullets()
	soul.position = ARENA.get_center()
	_prepare_pattern()
	queue_redraw()

func _prepare_pattern() -> void:
	match current_pattern:
		"spores_rain", "tear_meteors", "ember_shower", "royal_icicles", "leaf_storm", "gear_missiles", "diamond_shot", "ghost_tears", "judgement_rain", "final_resolve":
			spawn_interval = 0.16 if monster_data.get("boss", false) else 0.24
			pattern_duration = 4.2
		_:
			spawn_interval = 0.45
			pattern_duration = 4.0

func _bullet_texture(pat: String) -> Texture2D:
	if pat in ["royal_icicles", "icicle_fang", "barrier_pulse"]:
		return load("res://sprites/bullet_icicle.png")
	if pat in ["leaf_storm", "vine_lash", "spark_leaves", "root_eruption", "sonar_waves"]:
		return load("res://sprites/bullet_leaf.png")
	if pat in ["ember_shower", "fire_dash"]:
		return load("res://sprites/bullet_ember.png")
	if pat in ["gear_missiles", "spring_punch", "gear_storm"]:
		return load("res://sprites/bullet_gear.png")
	if pat in ["diamond_shot", "seal_beams", "judgement_rain", "final_resolve"]:
		return load("res://sprites/bullet_diamond.png")
	return load("res://sprites/bullet_white.png")

func _spawn_bullet() -> void:
	var b := Sprite2D.new()
	b.texture = _bullet_texture(current_pattern)
	var side := randi() % 4
	var margin := 12.0
	match side:
		0: b.position = Vector2(randf_range(ARENA.position.x, ARENA.end.x), ARENA.position.y - margin)
		1: b.position = Vector2(randf_range(ARENA.position.x, ARENA.end.x), ARENA.end.y + margin)
		2: b.position = Vector2(ARENA.position.x - margin, randf_range(ARENA.position.y, ARENA.end.y))
		3: b.position = Vector2(ARENA.end.x + margin, randf_range(ARENA.position.y, ARENA.end.y))
	var target := soul.position + Vector2(randf_range(-24, 24), randf_range(-24, 24))
	var dirv := (target - b.position).normalized()
	var spd := randf_range(70.0, 105.0) + float(monster_data.get("atk", 5)) * 4.0
	if current_pattern in ["slow_glob", "spores_rain", "tear_meteors"]:
		spd *= 0.7
	b.rotation = dirv.angle()
	b.set_meta("vel", dirv * spd)
	b.set_meta("life", 6.0)
	add_child(b)
	bullets.append(b)

func _clear_bullets() -> void:
	for b in bullets:
		if is_instance_valid(b):
			b.queue_free()
	bullets.clear()

func _end_enemy_turn() -> void:
	_clear_bullets()
	var flavor: Array = monster_data.get("flavor_turns", ["* Враг дышит ровно."])
	if mercy >= 99.0:
		_show_msg("* Враг СИЯЕТ желанием мира.\n* Жми ПОЩАДУ!")
	else:
		_show_msg(str(flavor[randi() % flavor.size()]))
	await get_tree().create_timer(0.55).timeout
	_set_phase_menu()

# ---------------- финалы ----------------

func _win_by_spare() -> void:
	GameState.spare_count += 1
	if not monster_id in GameState.spared_monsters:
		GameState.spared_monsters.append(monster_id)
	match monster_id:
		"boss_ember": GameState.set_flag("ember_spared")
		"boss_cog_legion": GameState.set_flag("legion_spared")
		"boss_thorn": GameState.set_flag("thorn_spared")
		"boss_guardian": GameState.set_flag("guardian_spared")
		"boss_hollow_king": GameState.set_flag("hollow_spared")
	GameState.add_exp(int(monster_data.get("xp", 5)) / 2)
	GameState.gold += int(monster_data.get("gold", 5))
	_finish_battle("spared")

func _win_by_kill() -> void:
	GameState.kill_count += 1
	GameState.kr += 1.0
	if not monster_id in GameState.killed_monsters:
		GameState.killed_monsters.append(monster_id)
	GameState.add_exp(int(monster_data.get("xp", 5)))
	GameState.gold += int(monster_data.get("gold", 5))
	AudioManager.death_sound()
	_finish_battle("killed")

func _finish_battle(result: String) -> void:
	_clear_bullets()
	phase = "aftermath"
	after_result = result
	var lines: Array[String] = []
	if result == "spared":
		lines.append("* Ты пощадил(а). Тепло разливается по душе.")
	elif result == "killed":
		lines.append("* Враг рассыпается пылью.\n* ...Ты чувствуешь, как LV растёт в тишине.")
	elif result == "fled":
		lines.append("* Ты убегаешь. Иногда это тоже храбрость.")
	for entry in pending_after:
		if typeof(entry) == TYPE_STRING:
			lines.append(str(entry))
		elif typeof(entry) == TYPE_DICTIONARY:
			var e := WorldLogic.resolve_effect(entry, monster_id)
			if e.text != "":
				lines.append(e.text)
	_msg_queue = lines
	_msg_index = 0
	_show_next_aftermath()

func _show_next_aftermath() -> void:
	if _msg_index >= _msg_queue.size():
		_confirm_end()
		return
	msg_done = false
	_tw.set_text(_msg_queue[_msg_index])
	_msg_index += 1

func _confirm_end() -> void:
	GameState.dialogue_active = false
	AudioManager.stop_music()
	battle_ended.emit(after_result, monster_id)

func _lose() -> void:
	_clear_bullets()
	phase = "lost"
	GameState.hp = 0
	msg_done = true
	_tw.set_text("* Твоя решимость угасла...\n* (Z — попробовать снова)")
	AudioManager.stop_music()

# ---------------- ввод ----------------

func _unhandled_input(event: InputEvent) -> void:
	if phase == "lost":
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
			GameState.revive_at_save()
			get_tree().reload_current_scene()
		return
	if phase == "aftermath":
		if (event.is_action_pressed("ui_accept") or event.is_action_pressed("interact")) and msg_done:
			_show_next_aftermath()
		return
	if phase in ["message", "intro", "enemy_turn"]:
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
			if not msg_done:
				_tw.skip()
		return
	if phase == "attack_bar":
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
			_finish_attack_bar()
		return
	if phase == "submenu":
		if event.is_action_pressed("move_up"):
			sub_index = posmod(sub_index - 1, sub_options.size())
			AudioManager.cursor_move()
			queue_redraw()
		elif event.is_action_pressed("move_down"):
			sub_index = posmod(sub_index + 1, sub_options.size())
			AudioManager.cursor_move()
			queue_redraw()
		elif event.is_action_pressed("ui_cancel"):
			phase = "menu"
			AudioManager.cancel()
			queue_redraw()
		elif event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
			if sub_callback.is_valid():
				sub_callback.call(sub_options[sub_index])
		return
	if phase == "menu":
		if event.is_action_pressed("move_left"):
			menu_index = posmod(menu_index - 1, 4)
			AudioManager.cursor_move(); queue_redraw()
		elif event.is_action_pressed("move_right"):
			menu_index = posmod(menu_index + 1, 4)
			AudioManager.cursor_move(); queue_redraw()
		elif event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
			AudioManager.confirm()
			_start_player_action()

# ---------------- цикл ----------------

func _process(delta: float) -> void:
	shake = maxf(0.0, shake - delta)
	invuln = maxf(0.0, invuln - delta)
	if phase == "attack_bar":
		attack_pos += attack_dir * delta * attack_speed
		if attack_pos >= 1.0:
			attack_pos = 1.0; attack_dir = -1.0
		if attack_pos <= 0.0:
			attack_pos = 0.0; attack_dir = 1.0
	elif phase == "enemy_turn":
		enemy_attack_time += delta
		spawn_accum += delta
		while spawn_accum >= spawn_interval:
			spawn_accum -= spawn_interval
			_spawn_bullet()
		var mv := Vector2.ZERO
		if Input.is_action_pressed("move_left"): mv.x -= 1
		if Input.is_action_pressed("move_right"): mv.x += 1
		if Input.is_action_pressed("move_up"): mv.y -= 1
		if Input.is_action_pressed("move_down"): mv.y += 1
		if mv != Vector2.ZERO:
			soul.position += mv.normalized() * soul_speed * delta
		soul.position.x = clampf(soul.position.x, ARENA.position.x + 6, ARENA.end.x - 6)
		soul.position.y = clampf(soul.position.y, ARENA.position.y + 6, ARENA.end.y - 6)
		if invuln <= 0:
			for b in bullets:
				if not is_instance_valid(b):
					continue
				if b.position.distance_to(soul.position) < 9.0:
					var dmg := maxi(1, int(monster_data.get("atk", 5)) + randi_range(0, 3) - int(GameState.dfs / 2))
					GameState.hp = maxi(0, GameState.hp - dmg)
					AudioManager.hurt()
					invuln = 0.6
					shake = 0.3
					if GameState.hp <= 0:
						_lose()
						return
		var keep: Array[Node2D] = []
		for b in bullets:
			if not is_instance_valid(b):
				continue
			b.position += b.get_meta("vel") * delta
			b.set_meta("life", float(b.get_meta("life")) - delta)
			if float(b.get_meta("life")) <= 0.0 or not ARENA.grow(70.0).has_point(b.position):
				b.queue_free()
			else:
				keep.append(b)
		bullets = keep
		if enemy_attack_time >= pattern_duration:
			_end_enemy_turn()
	queue_redraw()

# ---------------- отрисовка ----------------

func _draw() -> void:
	var off := Vector2(randf_range(-shake, shake), randf_range(-shake, shake)) * 4.0
	draw_rect(Rect2(Vector2.ZERO, Vector2(640, 360)), Color(0, 0, 0), true)

	var tex: Texture2D = null
	var spr_path := str(monster_data.get("sprite", ""))
	if spr_path.begins_with("res://") and ResourceLoader.exists(spr_path):
		tex = load(spr_path)
	if tex:
		var center := Vector2(320, 88) + off
		var sz := tex.get_size()
		var scale_f := maxf(minf(120.0 / sz.x, 105.0 / sz.y), 2.0)
		draw_texture_rect(tex, Rect2(center - sz * scale_f / 2.0, sz * scale_f), false)

	var mname := str(monster_data.get("name", "?"))
	draw_string(_font, Vector2(320 - _font.get_string_width(mname) / 2.0 + off.x, 166), mname, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	var bar_w := 120.0
	var bx := 320.0 - bar_w / 2.0 + off.x
	draw_rect(Rect2(bx, 170, bar_w, 8), Color(0.35, 0.1, 0.1), true)
	draw_rect(Rect2(bx, 170, bar_w * float(m_hp) / float(maxi(m_max_hp, 1)), 8), Color(0.2, 0.9, 0.2), true)
	if mercy > 0:
		draw_rect(Rect2(bx, 180, bar_w, 4), Color(0.25, 0.25, 0.25), true)
		draw_rect(Rect2(bx, 180, bar_w * mercy / 100.0, 4), Color(1.0, 0.85, 0.2), true)

	var ab := ARENA
	ab.position += off
	draw_rect(ab, Color.WHITE, false, 3.0)

	if phase == "attack_bar":
		var track := Rect2(180 + off.x, 250, 280, 14)
		draw_rect(track, Color(0.2, 0.2, 0.2), true)
		draw_rect(Rect2(track.position + Vector2(track.size.x * 0.5 - 3, -4), Vector2(6, track.size.y + 8)), Color(1, 1, 0.4), true)
		var cursor_x := track.position.x + track.size.x * attack_pos
		draw_rect(Rect2(cursor_x - 2, track.position.y - 6, 4, track.size.y + 12), Color(1, 0.3, 0.3), true)
		draw_string(_font, Vector2(180, 285), "Z — стоп!", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.8, 0.8, 0.8))

	if phase == "menu" or phase == "submenu":
		var xs := [40.0, 190.0, 340.0, 490.0]
		for i in range(4):
			var selected := (i == menu_index and phase == "menu")
			var c := Color(1.0, 0.85, 0.2) if selected else Color.WHITE
			var r := Rect2(xs[i], 330, 130, 22)
			draw_rect(r, c, false, 2.0)
			draw_string(_font, Vector2(r.position.x + 10, r.position.y + 16), MENU_LABELS[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, c)
			if selected and ResourceLoader.exists("res://sprites/soul_red.png"):
				draw_texture(load("res://sprites/soul_red.png"), Vector2(xs[i] - 24, 332))

	if phase == "submenu":
		var y := 210.0
		for i in range(mini(sub_options.size(), 5)):
			var sel := i == sub_index
			draw_string(_font, Vector2(180, y), "> " if sel else "  ", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.YELLOW if sel else Color.GRAY)
			draw_string(_font, Vector2(196, y), str(sub_options[i].label), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE if not sel else Color.YELLOW)
			y += 20.0
		if sub_options.size() > 5:
			draw_string(_font, Vector2(196, y), "...ещё %d" % (sub_options.size() - 5), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.GRAY)

	var hud_y := 306.0
	draw_string(_font, Vector2(30, hud_y), "%s   LV %d" % [GameState.player_name, GameState.lv], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	draw_string(_font, Vector2(30, hud_y + 16), "HP", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	var hp_bg := Rect2(56, hud_y + 6, 100, 12)
	draw_rect(hp_bg, Color(0.4, 0.1, 0.1), true)
	draw_rect(Rect2(hp_bg.position, Vector2(hp_bg.size.x * clampf(float(GameState.hp) / GameState.max_hp, 0, 1), hp_bg.size.y)), Color(1.0, 0.85, 0.1), true)
	draw_string(_font, Vector2(164, hud_y + 16), "%d/%d" % [GameState.hp, GameState.max_hp], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	draw_string(_font, Vector2(280, hud_y + 16), "$%d" % GameState.gold, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.9, 0.9, 0.5))
	if GameState.kr > 0:
		draw_string(_font, Vector2(360, hud_y + 16), "KR %.1f" % GameState.kr, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.7, 0.3, 0.8))
