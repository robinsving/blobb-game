extends SceneTree
## The save point (Continue): saving and loading, a side-view checkpoint saving its column, a
## puzzle room saving its number, finished chapters moving Continue on, and the crash marker.
## Leaves the player's own save as it was.
## Run: godot-flatpak --headless --path . --script res://tests/test_save.gd

var failures := 0
var _backup := {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game: Node = root.get_node("Game")
	for p in [game.SAVE_PATH, game.SESSION_PATH]:
		_backup[p] = FileAccess.get_file_as_bytes(p) if FileAccess.file_exists(p) else null
	game.testing = false

	# saving and loading
	game.progress_scene = "res://chapters/ch2/mill.tscn"
	game.progress_at = 2
	game.save()
	_check(not FileAccess.file_exists(game.SAVE_PATH + ".tmp"), "the temporary save file is renamed over the save")
	game.progress_scene = ""
	game.progress_at = -1
	game._load()
	_check(game.progress_scene == "res://chapters/ch2/mill.tscn" and game.progress_at == 2, "the save point loads back")

	# a side-view checkpoint saves its column (not the first one: the intro would be skipped)
	game.go("res://chapters/ch2/pond.tscn")
	await _until(func() -> bool: return root.has_node("Pond"))
	_check(game.progress_scene == "res://chapters/ch2/pond.tscn" and game.progress_at == -1, "a new scene is the save point, from its start")
	var player: Node2D = root.get_node("Pond/Player")
	player.teleport(Vector2(67 * 64 + 32, 900))
	await _frames(10)
	_check(game.progress_at == 67, "walking into the checkpoint at column 67 saves it (got %d)" % game.progress_at)

	# a puzzle room saves its number
	await _until(func() -> bool: return not game._transitioning)
	game.start_at("res://chapters/ch2/mill.tscn", 2)
	await _until(func() -> bool: return root.has_node("Mill"))
	_check(game.progress_scene == "res://chapters/ch2/mill.tscn" and game.progress_at == 2, "the mill's room 2 is the save point")

	# finishing a chapter moves Continue on to the next one; after the last, nothing is left
	game.unlock_chapter(3)
	_check(game.progress_scene == "res://chapters/ch3/city.tscn" and game.progress_at == -1, "after chapter 2, Continue starts chapter 3")
	game.unlock_chapter(6)
	_check(game.progress_scene == "", "after the last chapter there is nothing to continue")

	# the crash marker: there while running, gone after a clean quit
	game._start_session()
	_check(FileAccess.file_exists(game.SESSION_PATH), "the session marker exists while the game runs")
	game.crashed_last_time = false
	game._start_session()
	_check(game.crashed_last_time, "a marker left behind is read as a crash")

	for p in _backup:
		if _backup[p] == null:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
		else:
			FileAccess.open(p, FileAccess.WRITE).store_buffer(_backup[p])
	print("FAILED: %d" % failures if failures else "ALL TESTS PASSED")
	for n in root.get_children():
		if n.name in ["Pond", "Mill"]:
			n.free()  # so nothing is reported leaked at exit
	game._music.stop()
	game._music.stream = null
	await create_timer(0.3).timeout  # the audio thread lets go of the stopped stream on its next mix
	quit(1 if failures else 0)


func _until(cond: Callable) -> void:
	for i in 1200:
		if cond.call():
			return
		await physics_frame
	_check(false, "timed out waiting")


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
		print("FAIL: ", msg)

