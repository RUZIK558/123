extends Node
## GameState — глобальное состояние игры, инвентарь, флаги сюжета, сохранения.

signal state_changed

const SAVE_PATH := "user://lowertale_save.dat"
const METADATA_PATH := "user://lowertale_meta.dat"

enum Route { NEUTRAL, TRUE_PACIFIST, GENOCIDE }

# --- Боевые характеристики игрока ---
var player_name: String = "Chara"
var lv: int = 1
var hp: int = 20
var max_hp: int = 20
var atk: int = 10
var dfs: int = 0
var exp: int = 0
var gold: int = 0
var kr: float = 0.0   # Karmal Retribution — кармическая карма (для геноцида)

# --- Инвентарь: id -> count ---
var inventory: Dictionary = {}

# --- Сюжетные флаги ---
var flags: Dictionary = {}

# --- Статистика маршрута ---
var kill_count: int = 0
var spare_count: int = 0
var killed_monsters: Array = []      # id убитых монстров (уникальные)
var spared_monsters: Array = []      # id пощаженных (уникальные)
var pet_count: int = 0               # сколько раз погладили существ
var current_location: String = ""
var visited_locations: Array = []

# --- Настройки диалога ---
var text_speed: float = 0.035        # сек. на символ; меньше = быстрее
var dialogue_active: bool = false    # блокирует ввод мира, когда идёт диалог

func _ready() -> void:
	_init_default_flags()

func _init_default_flags() -> void:
	var defaults = [
		"intro_done", "met_glim", "glim_spared", "glim_defeated",
		"ember_met", "ember_forgiven", "ember_angry", "ember_purified",
		"cog_fixed", "cog_boss_done", "echo_saved", "echo_lost",
		"thorn_helped", "thorn_boss_done", "lumen_blessing",
		"hollow_truth_known", "hollow_spared", "hollow_defeated",
		"guardian_awakened", "secret_room_found", "artifact_found",
		"found_note_1", "found_note_2", "found_note_3", "found_note_4", "found_note_5",
		"found_note_6", "found_note_7", "found_note_8",
		"ruins_gate_open", "bazaar_visited", "puzzle_1_done", "puzzle_2_done",
		"puzzle_3_done", "bridge_broken", "used_rope", "memory_shard_1",
		"memory_shard_2", "memory_shard_3", "memory_shard_4",
	]
	for f in defaults:
		if not flags.has(f):
			flags[f] = false

# ================= Маршрут =================

func get_route() -> int:
	if kill_count > 0 and len(killed_monsters) >= 6:
		return Route.GENOCIDE
	if kill_count == 0 and spare_count >= 4:
		return Route.TRUE_PACIFIST
	return Route.NEUTRAL

func route_name_cn(r: int) -> String:
	match r:
		Route.NEUTRAL: return "Нейтральный"
		Route.TRUE_PACIFIST: return "Истинный пацифист"
		Route.GENOCIDE: return "Геноцид"
	return "?"

# ================= Инвентарь =================

func add_item(id: String, count: int = 1) -> void:
	inventory[id] = inventory.get(id, 0) + count
	state_changed.emit()

func remove_item(id: String, count: int = 1) -> bool:
	if inventory.get(id, 0) < count:
		return false
	inventory[id] -= count
	if inventory[id] <= 0:
		inventory.erase(id)
	state_changed.emit()
	return true

func has_item(id: String) -> bool:
	return inventory.get(id, 0) > 0

func item_count(id: String) -> int:
	return inventory.get(id, 0)

func heal(amount: int) -> void:
	hp = mini(hp + amount, max_hp)

func add_exp(xp: int) -> void:
	exp += xp
	while exp >= _exp_to_next():
		exp -= _exp_to_next()
		lv += 1
		max_hp += 4
		atk += 2
		hp = max_hp

func _exp_to_next() -> int:
	return 8 + lv * 6

# ================= Флаги =================

func set_flag(f: String, v: bool = true) -> void:
	flags[f] = v
	state_changed.emit()

func get_flag(f: String) -> bool:
	return flags.get(f, false)

func mark_visited(loc_id: String) -> void:
	current_location = loc_id
	if not loc_id in visited_locations:
		visited_locations.append(loc_id)

func memory_shards_found() -> int:
	var c := 0
	for i in range(1, 5):
		if get_flag("memory_shard_%d" % i):
			c += 1
	return c

func notes_found() -> int:
	var c := 0
	for i in range(1, 9):
		if get_flag("found_note_%d" % i):
			c += 1
	return c

# ================= Сохранение =================

func save_game(slot: int = 0) -> bool:
	var data := {
		"player_name": player_name,
		"lv": lv, "hp": hp, "max_hp": max_hp, "atk": atk, "dfs": dfs,
		"exp": exp, "gold": gold, "kr": kr,
		"inventory": inventory, "flags": flags,
		"kill_count": kill_count, "spare_count": spare_count,
		"killed_monsters": killed_monsters, "spared_monsters": spared_monsters,
		"pet_count": pet_count,
		"current_location": current_location,
		"visited_locations": visited_locations,
		"text_speed": text_speed,
		"timestamp": Time.get_datetime_string_from_system(),
	}
	var path := SAVE_PATH if slot == 0 else "user://lowertale_save_%d.dat" % slot
	var f := FileAccess.open(path, FileAccess.WRITE)
	if not f:
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	_write_metadata(slot, data)
	print("GameState: игра сохранена в слот %d" % slot)
	return true

func load_game(slot: int = 0) -> bool:
	var path := SAVE_PATH if slot == 0 else "user://lowertale_save_%d.dat" % slot
	if not FileAccess.file_exists(path):
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	var txt := f.get_as_text()
	f.close()
	var data = JSON.parse_string(txt)
	if typeof(data) != TYPE_DICTIONARY:
		return false
	player_name = data.get("player_name", "Chara")
	lv = data.get("lv", 1); hp = data.get("hp", 20); max_hp = data.get("max_hp", 20)
	atk = data.get("atk", 10); dfs = data.get("dfs", 0)
	exp = data.get("exp", 0); gold = data.get("gold", 0); kr = data.get("kr", 0.0)
	inventory = data.get("inventory", {})
	flags = data.get("flags", {})
	kill_count = data.get("kill_count", 0)
	spare_count = data.get("spare_count", 0)
	killed_monsters = data.get("killed_monsters", [])
	spared_monsters = data.get("spared_monsters", [])
	pet_count = data.get("pet_count", 0)
	current_location = data.get("current_location", "")
	visited_locations = data.get("visited_locations", [])
	text_speed = data.get("text_speed", 0.035)
	_init_default_flags()
	state_changed.emit()
	print("GameState: загрузка из слота %d" % slot)
	return true

func has_save(slot: int = 0) -> bool:
	var path := SAVE_PATH if slot == 0 else "user://lowertale_save_%d.dat" % slot
	return FileAccess.file_exists(path)

func delete_save(slot: int = 0) -> void:
	var path := SAVE_PATH if slot == 0 else "user://lowertale_save_%d.dat" % slot
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _write_metadata(slot: int, data: Dictionary) -> void:
	var meta := {
		"slot": slot,
		"location": data.get("current_location", ""),
		"lv": data.get("lv", 1),
		"route": route_name_cn(get_route()),
		"time": data.get("timestamp", ""),
	}
	var f := FileAccess.open(METADATA_PATH if slot == 0 else ("user://lowertale_meta_%d.dat" % slot), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(meta))
		f.close()

func reset_for_new_game() -> void:
	lv = 1; hp = 20; max_hp = 20; atk = 10; dfs = 0; exp = 0; gold = 0; kr = 0.0
	inventory = {}
	flags = {}
	_init_default_flags()
	kill_count = 0; spare_count = 0
	killed_monsters = []; spared_monsters = []
	pet_count = 0; current_location = ""; visited_locations = []
	state_changed.emit()
