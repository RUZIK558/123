extends Node
## DataLoader — грузит игровой контент из JSON-файла, используя прямой доступ к
## файловой системе. Это позволяет проекту запускаться БЕЗ предварительного
## импорта ассетов в .godot-кэш: достаточно открыть папку `project/` в Godot 4
## и нажать Run (F5).

const DATA_PATH := "res://data/content.json"

var content: Dictionary = {}
var loaded := false
var last_error := ""

func _ready() -> void:
	load_content()

func load_content() -> bool:
	content = {}
	loaded = false
	last_error = ""

	# 1) Пробуем res:// через FileAccess (работает и в редакторе, и в экспорте)
	var text := _read_res_file(DATA_PATH)

	# 2) Запасной вариант: вычисляем абсолютный путь рядом со скриптом
	if text == "":
		var script_dir := (get_script() as Script).resource_path.get_base_dir()
		var abs_candidate := script_dir.path_join(".." ).path_join("data/content.json")
		text = _read_any_file(abs_candidate)
	if text == "":
		var cwd_candidate := OS.get_executable_path().get_base_dir().path_join("data/content.json")
		text = _read_any_file(cwd_candidate)
	if text == "":
		text = _read_any_file("data/content.json") # относительно рабочей директории

	if text == "":
		last_error = "Не удалось найти data/content.json"
		push_warning("DataLoader: " + last_error)
		return false

	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		last_error = "content.json повреждён (не словарь)"
		push_error("DataLoader: " + last_error)
		return false

	content = parsed
	loaded = true
	print("DataLoader: контент загружен, локаций: %d, монстров: %d" % [
		content.get("locations", {}).size(),
		content.get("monsters", {}).size(),
	])
	return true

func _read_res_file(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f:
		var s := f.get_as_text()
		f.close()
		return s
	return ""

func _read_any_file(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	return _read_res_file(path)

# ---------- Удобные геттеры ----------

func get_monster(id: String) -> Dictionary:
	return content.get("monsters", {}).get(id, {})

func get_all_monsters() -> Dictionary:
	return content.get("monsters", {})

func get_item(id: String) -> Dictionary:
	return content.get("items", {}).get(id, {})

func get_all_items() -> Dictionary:
	return content.get("items", {})

func get_location(id: String) -> Dictionary:
	return content.get("locations", {}).get(id, {})

func get_act(id: String) -> Dictionary:
	return content.get("acts", {}).get(id, {})

func get_flavor(id: String) -> Dictionary:
	return content.get("flavor_events", {}).get(id, {})

func get_ending(id: String) -> Dictionary:
	return content.get("endings", {}).get(id, {})

func get_dialogue(key: String) -> Array:
	return content.get("dialogues", {}).get(key, [])
