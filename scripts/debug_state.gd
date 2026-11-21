class_name DebugState
## Read-only state snapshots for checking the game from outside (gda: `gda game call /root/<Level>
## debug_state`). Each level declares `const GDA_CALLABLE := ["debug_state"]` and returns a
## Dictionary built here, so the values are plain JSON (no Vector2i keys or objects).
## Nothing here changes the game; it is never called during play.


## The common part for every level: player, narration, control lock.
static func base(player: Node2D) -> Dictionary:
	var d := {"busy": Narrator.busy, "locked": Game.control_locked, "fast": Game.fast}
	d.merge(Narrator.debug_state())
	if is_instance_valid(player):
		d["player"] = player.position
		if player is CharacterBody2D:
			d["on_floor"] = (player as CharacterBody2D).is_on_floor()
			d["velocity"] = (player as CharacterBody2D).velocity
	return json(d)


## A side-view level: base plus the tile column and the story beats already played.
static func side(player: Node2D, tile: float, fired: Dictionary, extra := {}) -> Dictionary:
	var d := base(player)
	if is_instance_valid(player):
		d["col"] = floori(player.position.x / tile)
	d["fired"] = fired.keys().map(func(k): return str(k))
	d.merge(json(extra), true)
	return d


## Makes a value JSON-friendly: vectors become [x, y], dictionary keys strings, objects names.
static func json(v: Variant) -> Variant:
	match typeof(v):
		TYPE_VECTOR2, TYPE_VECTOR2I:
			return [v.x, v.y]
		TYPE_DICTIONARY:
			var out := {}
			for k in v:
				var key: String = "%d,%d" % [k.x, k.y] if typeof(k) in [TYPE_VECTOR2, TYPE_VECTOR2I] else str(k)
				out[key] = json(v[k])
			return out
		TYPE_ARRAY:
			return (v as Array).map(func(x): return json(x))
		TYPE_OBJECT:
			return str(v)
	return v
