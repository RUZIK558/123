extends Node
## Bootstrap — страховка от «чёрного экрана»: если главная сцена не загрузилась,
## принудительно загружает титульный экран. Также включает растягивание окна на весь размер.

func _ready() -> void:
	# Растягивание канваса на всё окно (на случай, если настройки проекта не применились)
	var root := get_tree().root
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.content_scale_size = Vector2i(640, 360)

	await get_tree().process_frame
	if get_tree().current_scene == null:
		push_warning("Bootstrap: сцена не загрузилась — принудительная загрузка title_screen")
		get_tree().change_scene_to_file("res://scenes/title_screen.tscn")
