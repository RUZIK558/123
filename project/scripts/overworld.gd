extends Node2D
## Overworld — сцена исследования: игрок, NPC, объекты, выходы, случайные встречи.

const TILE := 16
const VIEW := Vector2(640, 360)

var location_id := ""
var loc_data: Dictionary = {}
var player: Node2D
var player_speed := 78.0
var facing := Vector2.DOWN
var interactables: Array[Node2D] = []   # узлы с meta "interact" = Callable
var dialogue_box: Node2D
var encounter_steps := 0.0
var next_encounter_dist := 90.0
var in_battle := false
var shop_open := false
var _theme_tiles := {}
var _font: Font
var _choice_state := {}
var _active_choice: Dictionary = {}
var _pending_boss: Dictionary = {}
var pending_after_events: Array = []
var shop_stock: Array = []
var shop_index := 0
var genocidal := false
var fade := 1.0

# головоломка-последовательность
var seq_puzzle: Dictionary = {}
var seq_progress: Array = []
var seq_fail_msg := ""
var _seq_sel := 0

func _ready() -> void:
	_font = load("res://fonts/main_font.ttf")
	location_id = GameState.current_location
	if location_id == "":
		location_id = "fall"
	loc_data = DataLoader.get_location(location_id)
	if loc_data.is_empty():
		push_error("Overworld: локация %s не найдена" % location_id)
		return
	GameState.mark_visited(location_id)
	genocidal = GameState.kill_count >= 5 and len(GameState.killed_monsters) >= 4

	dialogue_box = preload("res://scripts/dialogue_box.gd").new()
	add_child(dialogue_box)
	dialogue_box.dialogue_finished.connect(_on_dialogue_finished)

	player = Node2D.new()
	var spr := Sprite2D.new()
	spr.texture = load("res://sprites/player.png")
	spr.offset = Vector2(0, -8)
	player.add_child(spr)
	var start: Array = loc_data.get("start_pos", [160, 240])
	player.position = Vector2(start[0], start[1])
	add_child(player)

	_build_world()
	AudioManager.play_music(str(loc_data.get("music", "ruins")))

	if not GameState.get_flag("intro_done") and location_id == "fall":
		GameState.set_flag("intro_done")
		_show_dialogue(_intro_lines())
	elif loc_data.has("on_enter_dialogue"):
		_show_dialogue(WorldLogic.expand_dialogue(loc_data.on_enter_dialogue))

func _intro_lines() -> Array:
	var keys := ["intro_1", "intro_2", "intro_3", "intro_4", "intro_5", "intro_6", "intro_7"]
	var out: Array = []
	for k in keys:
		out.append(DialogueDB.get_line(k))
	return out

# ---------------- постройка мира ----------------

func _build_world() -> void:
	interactables.clear()
	var theme := str(loc_data.get("theme", "ruins"))
	_theme_tiles = {
		"floor": load("res://sprites/%s_floor.png" % theme),
		"wall": load("res://sprites/%s_wall.png" % theme),
	}
	for npc in _all_npcs():
		_make_sprite_node(npc.id, Vector2(npc.pos[0], npc.pos[1]), str(npc.sprite), _npc_callable(npc))
	for o in loc_data.get("objects", []):
		_make_object(o)
	if loc_data.has("pettable"):
		var pt: Dictionary = loc_data.pettable
		if not pt.has("requires_flag") or GameState.get_flag(str(pt.requires_flag)):
			_make_sprite_node(pt.id, Vector2(pt.pos[0], pt.pos[1]), str(pt.sprite), _pet_callable(pt))
	if loc_data.has("mini_event"):
		var me: Dictionary = loc_data.mini_event
		if not GameState.get_flag("mini_done_" + str(me.id)):
			_make_marker(me.id, Vector2(me.pos[0], me.pos[1]), Color(0.5, 0.8, 1.0), _choice_callable(me))
	if loc_data.has("boss"):
		var b: Dictionary = loc_data.boss
		if not GameState.get_flag(str(b.trigger_flag_not)):
			_make_sprite_node(b.id + "_vis", Vector2(b.pos[0], b.pos[1]), str(DataLoader.get_monster(b.id).get("sprite", "")), _boss_callable(b))
	if loc_data.has("shrine_object"):
		var sh: Dictionary = loc_data.shrine_object
		_make_marker(sh.id, Vector2(sh.pos[0], sh.pos[1]), Color(0.9, 0.7, 1.0), _shrine_callable(sh))
	if loc_data.has("puzzle"):
		var pz: Dictionary = loc_data.puzzle
		if not (pz.has("set_flag") and GameState.get_flag(str(pz.set_flag))):
			_make_marker("puzzle", Vector2(160, 120), Color(1.0, 0.6, 0.2), _puzzle_callable(pz))
	if loc_data.has("shop"):
		var sp: Dictionary = loc_data.shop
		_make_sprite_node(sp.npc, Vector2(160, 120), str(sp.sprite), _shop_callable(sp))
	for spt in loc_data.get("save_points", []):
		_make_save_point(Vector2(spt[0], spt[1]))
	for ex in loc_data.get("exits", []):
		_make_exit(ex)
	if loc_data.has("ending_trigger"):
		var et: Dictionary = loc_data.ending_trigger
		_make_marker("ending", Vector2(et.pos[0], et.pos[1]), Color(1, 1, 1), _ending_callable(et))

func _all_npcs() -> Array:
	var out: Array = []
	if loc_data.has("npcs"):
		for n in loc_data.npcs:
			out.append(n)
	if loc_data.has("npc"):
		out.append(loc_data.npc)
	var filtered: Array = []
	for n in out:
		if n.has("requires_flag") and not GameState.get_flag(str(n.requires_flag)):
			continue
		filtered.append(n)
	return filtered

func _make_sprite_node(id: String, pos: Vector2, tex_path: String, cb: Callable) -> void:
	var node := Node2D.new()
	node.name = id
	var spr := Sprite2D.new()
	if tex_path.begins_with("res://") and ResourceLoader.exists(tex_path):
		spr.texture = load(tex_path)
	node.add_child(spr)
	node.position = pos
	node.set_meta("interact", cb)
	add_child(node)
	interactables.append(node)

func _make_marker(id: String, pos: Vector2, color: Color, cb: Callable) -> void:
	var node := Node2D.new()
	node.name = id
	node.position = pos
	node.set_meta("interact", cb)
	node.set_meta("marker_color", color)
	add_child(node)
	interactables.append(node)

func _make_object(o: Dictionary) -> void:
	match str(o.get("type", "inspect")):
		"note":
			_make_marker(o.id, Vector2(o.pos[0], o.pos[1]), Color(0.95, 0.95, 0.7), _note_callable(o))
		"shard":
			if not GameState.get_flag(str(o.flag)):
				_make_marker(o.id, Vector2(o.pos[0], o.pos[1]), Color(0.8, 0.5, 1.0), _shard_pickup_callable(o))
		_:
			_make_marker(o.id, Vector2(o.pos[0], o.pos[1]), Color(0.6, 0.8, 0.9), _inspect_callable(o))

func _make_save_point(pos: Vector2) -> void:
	var node := Node2D.new()
	node.name = "save_point"
	var spr := Sprite2D.new()
	spr.texture = load("res://sprites/save_flower.png")
	node.add_child(spr)
	node.position = pos
	node.set_meta("interact", _save_callable())
	add_child(node)
	interactables.append(node)

func _make_exit(ex: Dictionary) -> void:
	var node := Node2D.new()
	node.name = "exit_%s" % str(ex.to)
	node.position = Vector2(ex.pos[0], ex.pos[1])
	node.set_meta("exit", ex)
	add_child(node)
	interactables.append(node)

# ---------------- коллбэки взаимодействия ----------------

func _npc_callable(npc: Dictionary) -> Callable:
	return func():
		var src: Array = npc.get("dialogue", [])
		var lines: Array = WorldLogic.expand_dialogue(src)
		WorldLogic.apply_pending_effects(src)
		if lines.is_empty():
			lines = ["* %s молчит. Очень загадочно." % npc.id]
		_show_dialogue(lines)

func _pet_callable(pt: Dictionary) -> Callable:
	return func():
		GameState.pet_count += 1
		var src: Array = pt.get("pet_lines", ["* Приятно."])
		var lines: Array = WorldLogic.expand_dialogue(src)
		WorldLogic.apply_pending_effects(src)
		_show_dialogue(lines)

func _inspect_callable(o: Dictionary) -> Callable:
	return func():
		_show_dialogue(WorldLogic.expand_dialogue(o.get("dialogue", ["* Ничего особенного."])))

func _note_callable(o: Dictionary) -> Callable:
	return func():
		var nid := str(o.note_id)
		if GameState.get_flag("found_" + nid):
			_show_dialogue(["* Ты уже читал(а) эту записку.", DataLoader.content["notes"].get(nid, "")])
		else:
			GameState.set_flag("found_" + nid)
			_show_dialogue(["* Найдена запись (%d/8)." % GameState.notes_found(), DataLoader.content["notes"].get(nid, "")])

func _shard_pickup_callable(o: Dictionary) -> Callable:
	return func():
		GameState.set_flag(str(o.flag))
		AudioManager.pickup()
		_show_dialogue(WorldLogic.expand_dialogue(o.get("dialogue", ["* Осколок памяти!"])))

func _shrine_callable(sh: Dictionary) -> Callable:
	return func():
		var need := int(sh.get("requires_shards", 4))
		var have := GameState.memory_shards_found()
		if have >= need:
			var src: Array = sh.get("success", [])
			var lines: Array = WorldLogic.expand_dialogue(src)
			WorldLogic.apply_pending_effects(src)
			_show_dialogue(lines)
		else:
			_show_dialogue(["* Алтарь ждёт осколки памяти.\n* У тебя %d из %d." % [have, need]])

func _puzzle_callable(pz: Dictionary) -> Callable:
	return func():
		match str(pz.get("type", "")):
			"bridge":
				if GameState.has_item("rope"):
					GameState.remove_item("rope")
					if pz.has("set_flag"):
						GameState.set_flag(str(pz.set_flag))
					AudioManager.confirm()
					_show_dialogue([str(pz.get("success_msg", "* Готово!"))])
					_build_world()
				else:
					_show_dialogue([str(pz.get("blocked_msg", "* Нужно что-то ещё."))])
			"sequence":
				_start_sequence_puzzle(pz)
			_:
				_show_dialogue(["* Загадка сломана. Даже шутка."])

func _start_sequence_puzzle(pz: Dictionary) -> void:
	seq_puzzle = pz
	seq_progress = []
	seq_fail_msg = ""
	_seq_sel = 0
	_show_dialogue([str(pz.get("hint", "* Выбери порядок рычагов."))])

func _try_seq_lever(i: int) -> void:
	var target: Array = seq_puzzle.get("target", [])
	if seq_progress.size() < target.size() and int(target[seq_progress.size()]) == i:
		seq_progress.append(i)
		AudioManager.cursor_move()
		if seq_progress.size() == target.size():
			var msg := str(seq_puzzle.get("success_msg", "* Что-то щёлкнуло."))
			GameState.set_flag("cog_fixed")
			AudioManager.confirm()
			seq_puzzle = {}
			_show_dialogue([msg])
			_build_world()
	else:
		seq_progress = []
		seq_fail_msg = str(seq_puzzle.get("fail_msg", "* Не то. Рычаги обиженно молчат."))
		AudioManager.cancel()
		queue_redraw()

func _boss_callable(b: Dictionary) -> Callable:
	return func():
		var pre: Array = WorldLogic.expand_dialogue(b.get("pre_dialogue", []))
		if pre.is_empty():
			_start_boss(b)
		else:
			_pending_boss = b
			_show_dialogue(pre)

func _start_boss(b: Dictionary) -> void:
	in_battle = true
	_spawn_battle([str(b.id)], true, b.get("after", []))

func _save_callable() -> Callable:
	return func():
		GameState.save_game(0)
		GameState.hp = GameState.max_hp
		AudioManager.save_chime()
		_show_dialogue([DialogueDB.get_line("save_point")])

func _shop_callable(_sp: Dictionary) -> Callable:
	return func():
		shop_open = true
		shop_stock = _sp.get("stock", [])
		shop_index = 0
		_show_dialogue(["ВРЕН: «Дёшево! Сердечно!»\n* Стрелки — выбор, Z — купить, ESC — уйти."])

func _ending_callable(_et: Dictionary) -> Callable:
	return func():
		_trigger_ending()

func _choice_callable(me: Dictionary) -> Callable:
	return func():
		_choice_state = {"prompt": WorldLogic.expand_dialogue(me.get("prompt", [])), "options": me.get("options", []), "idx": 0, "id": me.id}
		_show_dialogue(_choice_state.prompt)

# ---------------- диалог и продолжения ----------------

func _show_dialogue(lines: Array) -> void:
	dialogue_box.start(lines)

func _on_dialogue_finished() -> void:
	if not _choice_state.is_empty():
		_active_choice = _choice_state.duplicate(true)
		_choice_state = {}
		queue_redraw()
		return
	if not _pending_boss.is_empty():
		var b := _pending_boss
		_pending_boss = {}
		_start_boss(b)
		return

# ---------------- бой ----------------

func _spawn_battle(ids: Array, is_boss: bool, after: Array) -> void:
	pending_after_events = after
	var bs := preload("res://scripts/battle_screen.gd").new()
	bs.setup(ids[0], DataLoader.get_monster(ids[0]))
	add_child(bs)
	bs.battle_ended.connect(_on_battle_ended.bind(is_boss))

func _on_battle_ended(result: String, _mid: String, is_boss: bool) -> void:
	in_battle = false
	for c in get_children():
		if c.get_script() != null and str(c.get_script().resource_path).ends_with("battle_screen.gd"):
			c.queue_free()
	if is_boss:
		if result == "fled":
			_show_dialogue(["* С босса не сбегают... но ты попытался(ась)."])
		else:
			_apply_after_events()
	_build_world()

func _apply_after_events() -> void:
	var texts: Array = []
	for entry in pending_after_events:
		if typeof(entry) == TYPE_STRING:
			texts.append(str(entry))
		elif typeof(entry) == TYPE_DICTIONARY:
			var r := WorldLogic.resolve_effect(entry)
			if r.text != "":
				texts.append(r.text)
	pending_after_events = []
	if not texts.is_empty():
		_show_dialogue(texts)

# ---------------- переходы ----------------

func _goto(loc_id: String) -> void:
	GameState.current_location = loc_id
	GameState.save_game(0)
	get_tree().change_scene_to_file("res://scenes/overworld.tscn")

func _trigger_ending() -> void:
	var route := GameState.get_route()
	var ending_lines: Array = []
	if route == GameState.Route.GENOCIDE:
		ending_lines = DataLoader.content["endings"]["genocide"]["lines"]
	elif route == GameState.Route.TRUE_PACIFIST and GameState.get_flag("hollow_truth_known") and GameState.memory_shards_found() >= 4 and GameState.get_flag("guardian_done"):
		ending_lines = DataLoader.content["endings"]["true_pacifist"]["lines"]
	else:
		ending_lines = DataLoader.content["endings"]["neutral"]["lines"]
	var es := preload("res://scripts/ending_screen.gd").new()
	es.lines = ending_lines
	es.route_name = ["NEUTRAL", "TRUE PACIFIST", "GENOCIDE"][route]
	get_tree().root.add_child(es)
	GameState.delete_save(0)
	set_process(false)
	hide()

# ---------------- ввод ----------------

func _unhandled_input(event: InputEvent) -> void:
	if not _active_choice.is_empty():
		if event.is_action_pressed("move_up"):
			_active_choice.idx = posmod(int(_active_choice.idx) - 1, _active_choice.options.size())
			AudioManager.cursor_move(); queue_redraw()
		elif event.is_action_pressed("move_down"):
			_active_choice.idx = posmod(int(_active_choice.idx) + 1, _active_choice.options.size())
			AudioManager.cursor_move(); queue_redraw()
		elif event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
			var opt: Dictionary = _active_choice.options[int(_active_choice.idx)]
			GameState.set_flag("mini_done_" + str(_active_choice.id))
			var res_src: Array = opt.get("result", [])
			var res: Array = WorldLogic.expand_dialogue(res_src)
			WorldLogic.apply_pending_effects(res_src)
			_active_choice = {}
			_show_dialogue(res)
			queue_redraw()
		return
	if not seq_puzzle.is_empty():
		if event.is_action_pressed("move_left"):
			_seq_sel = posmod(_seq_sel - 1, 4); AudioManager.cursor_move(); queue_redraw()
		elif event.is_action_pressed("move_right"):
			_seq_sel = posmod(_seq_sel + 1, 4); AudioManager.cursor_move(); queue_redraw()
		elif event.is_action_pressed("ui_cancel"):
			seq_puzzle = {}; queue_redraw()
		elif event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
			_try_seq_lever(_seq_sel)
			queue_redraw()
		return
	if shop_open:
		if event.is_action_pressed("ui_cancel"):
			shop_open = false
			AudioManager.cancel(); queue_redraw()
		elif event.is_action_pressed("move_up"):
			shop_index = posmod(shop_index - 1, shop_stock.size())
			AudioManager.cursor_move(); queue_redraw()
		elif event.is_action_pressed("move_down"):
			shop_index = posmod(shop_index + 1, shop_stock.size())
			AudioManager.cursor_move(); queue_redraw()
		elif event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
			_try_buy()
		return
	if GameState.dialogue_active or in_battle:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		_try_interact()

func _try_buy() -> void:
	if shop_stock.is_empty():
		return
	var iid := str(shop_stock[shop_index])
	var it: Dictionary = DataLoader.get_item(iid)
	var price := _price_of(iid)
	if GameState.gold >= price:
		GameState.gold -= price
		GameState.add_item(iid)
		AudioManager.pickup()
		_show_dialogue(["* Куплено: %s за %d G." % [it.get("name", iid), price]])
	else:
		AudioManager.cancel()
		_show_dialogue(["* Не хватает GOLD. ВРЕН сочувственно цокает."])

func _price_of(iid: String) -> int:
	match iid:
		"cider": return 12
		"mushroom_pie": return 20
		"star_candy": return 8
		"donut": return 10
		"ramen": return 30
		"butter": return 6
		"rope": return 15
	return 10

func _try_interact() -> void:
	var probe := player.position + facing * 14.0
	var best: Node2D = null
	var best_d := 26.0
	for n in interactables:
		if not is_instance_valid(n):
			continue
		if n.has_meta("exit"):
			if n.position.distance_to(player.position) < 14.0:
				_take_exit(n.get_meta("exit"))
				return
			continue
		var d: float = n.position.distance_to(probe)
		if d < best_d:
			best_d = d
			best = n
	if best and best.has_meta("interact"):
		AudioManager.confirm()
		best.get_meta("interact").call()

func _take_exit(ex: Dictionary) -> void:
	if ex.has("requires_flag") and not GameState.get_flag(str(ex.requires_flag)):
		if ex.has("blocked_msg"):
			_show_dialogue([str(ex.blocked_msg)])
		return
	if ex.has("requires_flag_not") and GameState.get_flag(str(ex.requires_flag_not)):
		return
	_goto(str(ex.to))

# ---------------- цикл ----------------

func _process(delta: float) -> void:
	fade = maxf(0.0, fade - delta * 2.0)
	if in_battle or GameState.dialogue_active or shop_open or not _active_choice.is_empty() or not seq_puzzle.is_empty():
		queue_redraw()
		return
	var mv := Vector2.ZERO
	if Input.is_action_pressed("move_left"): mv.x -= 1; facing = Vector2.LEFT
	if Input.is_action_pressed("move_right"): mv.x += 1; facing = Vector2.RIGHT
	if Input.is_action_pressed("move_up"): mv.y -= 1; facing = Vector2.UP
	if Input.is_action_pressed("move_down"): mv.y += 1; facing = Vector2.DOWN
	if mv != Vector2.ZERO:
		var old := player.position
		player.position += mv.normalized() * player_speed * delta
		player.position = clampv(player.position)
		encounter_steps += old.distance_to(player.position)
		if encounter_steps > next_encounter_dist and loc_data.has("encounters"):
			encounter_steps = 0.0
			next_encounter_dist = randf_range(70.0, 130.0)
			_roll_encounter()
	queue_redraw()

func clampv(p: Vector2) -> Vector2:
	var vs := maxf_size(get_viewport_rect().size, VIEW)
	var ox := maxf((vs.x - VIEW.x) * 0.5, 0.0)
	return Vector2(clampf(p.x, 14 + ox, vs.x - 14 - ox), clampf(p.y, 20, vs.y - 14))

func _roll_encounter() -> void:
	var encs: Array = loc_data.get("encounters", [])
	if encs.is_empty():
		return
	var e: Dictionary = encs[randi() % encs.size()]
	var chance := float(e.get("chance", 0.4))
	if genocidal:
		chance = minf(chance + 0.25, 0.85)
	if randf() > chance:
		return
	var pool: Array = e.get("monsters", [])
	var pick: String = str(pool[randi() % pool.size()])
	in_battle = true
	_spawn_battle([pick], false, [])

# ---------------- отрисовка ----------------

func _draw() -> void:
	var vs := maxf_size(get_viewport_rect().size, VIEW)
	var floor_tex: Texture2D = _theme_tiles.get("floor")
	var wall_tex: Texture2D = _theme_tiles.get("wall")
	for y in range(int(vs.y / TILE) + 1):
		for x in range(int(vs.x / TILE) + 1):
			var is_border := x <= 0 or y <= 0 or (x + 1) * TILE >= vs.x or (y + 1) * TILE >= vs.y
			var tex := wall_tex if is_border else floor_tex
			if tex:
				draw_texture_rect(tex, Rect2(x * TILE, y * TILE, TILE, TILE), false)
	if str(loc_data.get("theme", "")) == "ice":
		var wt: Texture2D = load("res://sprites/water.png")
		for i in range(6):
			draw_texture_rect(wt, Rect2(200 + i * 16, 60 + (i % 2) * 16, 16, 16), false)

	for n in interactables:
		if not is_instance_valid(n):
			continue
		if n.has_meta("marker_color"):
			var c: Color = n.get_meta("marker_color")
			var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 240.0)
			draw_circle(n.position, 5.0 * pulse, c)
			draw_circle(n.position, 2.0, Color.WHITE)
		if n.has_meta("exit"):
			var ex: Dictionary = n.get_meta("exit")
			var blocked := (ex.has("requires_flag") and not GameState.get_flag(str(ex.requires_flag)))
			var col := Color(1, 1, 1, 0.7 + 0.3 * sin(Time.get_ticks_msec() / 300.0))
			if blocked:
				col = Color(0.6, 0.3, 0.3, 0.8)
			draw_string(_font, n.position + Vector2(-14, 4), str(ex.get("label", "->")), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, col)
			draw_rect(Rect2(n.position - Vector2(12, 6), Vector2(24, 12)), col, false, 1.0)

	draw_rect(Rect2(0, 0, vs.x, 14), Color(0, 0, 0, 0.6), true)
	draw_string(_font, Vector2(8, 11), str(loc_data.get("name", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.9, 0.9, 0.9))
	draw_string(_font, Vector2(vs.x - 230, 11), "LV%d HP%d/%d $%d ОСК:%d" % [GameState.lv, GameState.hp, GameState.max_hp, GameState.gold, GameState.memory_shards_found()], HORIZONTAL_ALIGNMENT_RIGHT, 222, 10, Color(1, 0.9, 0.5))

	if shop_open and not shop_stock.is_empty():
		var rect := Rect2(vs.x - 270, 40, 250, 30 + shop_stock.size() * 18)
		draw_rect(rect, Color(0, 0, 0, 0.94), true)
		draw_rect(rect, Color.WHITE, false, 2.0)
		draw_string(_font, Vector2(rect.position.x + 10, rect.position.y + 18), "ВРЕН: ТОВАРЫ (G: %d)" % GameState.gold, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 0.85, 0.2))
		for i in range(shop_stock.size()):
			var iid := str(shop_stock[i])
			var it: Dictionary = DataLoader.get_item(iid)
			var sel := i == shop_index
			draw_string(_font, Vector2(rect.position.x + 12, rect.position.y + 38 + i * 18), ("♥ " if sel else "   ") + "%s  %dG" % [it.get("name", iid), _price_of(iid)], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.YELLOW if sel else Color.WHITE)

	if not _active_choice.is_empty():
		var rect := Rect2(180, 250, 280, 24 + _active_choice.options.size() * 18)
		draw_rect(rect, Color(0, 0, 0, 0.94), true)
		draw_rect(rect, Color.WHITE, false, 2.0)
		for i in range(_active_choice.options.size()):
			var sel := i == int(_active_choice.idx)
			draw_string(_font, Vector2(rect.position.x + 12, rect.position.y + 20 + i * 18), ("♥ " if sel else "  ") + str(_active_choice.options[i].label), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 0.4, 0.4) if sel else Color.WHITE)

	if not seq_puzzle.is_empty():
		var rect := Rect2(120, 240, 400, 80)
		draw_rect(rect, Color(0, 0, 0, 0.94), true)
		draw_rect(rect, Color.WHITE, false, 2.0)
		draw_string(_font, Vector2(rect.position.x + 12, rect.position.y + 20), "РЫЧАГИ: ←→ выбор, Z — тянуть, ESC — уйти", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.8, 0.8, 0.8))
		var labels: Array = seq_puzzle.get("labels", ["A", "B", "C", "D"])
		var colors := [Color(0.9, 0.2, 0.2), Color(0.2, 0.4, 0.9), Color(0.95, 0.85, 0.2), Color(0.2, 0.8, 0.3)]
		for i in range(labels.size()):
			var sel := i == _seq_sel
			var done := i in seq_progress
			var cx := rect.position.x + 40 + i * 90
			draw_rect(Rect2(cx, rect.position.y + 34, 60, 26), colors[i] if not sel else colors[i].lightened(0.3), true)
			draw_rect(Rect2(cx, rect.position.y + 34, 60, 26), Color.WHITE if sel else Color.GRAY, false, 2.0)
			if done:
				draw_string(_font, Vector2(cx + 20, rect.position.y + 51), "OK", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.BLACK)
			else:
				draw_string(_font, Vector2(cx + 8, rect.position.y + 51), str(labels[i]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
		if seq_fail_msg != "":
			draw_string(_font, Vector2(rect.position.x + 12, rect.position.y + 74), seq_fail_msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 0.4, 0.4))

	if fade > 0.02:
		draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, fade), true)
