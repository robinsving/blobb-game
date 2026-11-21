class_name StoryGate
extends Node
## Blobb runs at full speed while the narrators talk; instead, he stops just short of the next
## story column until the scene being told is finished (so the player can't outrun the story).
## Attach one to a side-view level with a TRIGGERS table of {column: "scene"}:
##   StoryGate.attach(self, player, TRIGGERS, _fired, TILE)
## `fired` is the level's own dictionary of scenes already played (shared, not copied).

const MARGIN := 96.0  # stop this far before the trigger column (Blobb is ~116 px wide)

var player: CharacterBody2D
var triggers: Dictionary
var fired: Dictionary
var tile := 64.0
## Optional (the dream): Blobb's walking speed (PlayerSide.speed_mul) and, while a scene is told,
## a gradual slow-down over the last `slow_over` pixels before the stop, down to `slow_min` of that,
## so he strolls into the next beat instead of stopping dead.
var walk := 1.0
var slow_over := 0.0
var slow_min := 0.2


static func attach(level: Node, who: CharacterBody2D, trig: Dictionary, done: Dictionary, tile_size: float) -> StoryGate:
	var g := StoryGate.new()
	g.player = who
	g.triggers = trig
	g.fired = done
	g.tile = tile_size
	g.process_physics_priority = 10  # after the player has moved
	level.add_child(g)
	return g


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(player):
		return
	if not Narrator.busy:
		if slow_over > 0.0:
			player.speed_mul = walk
		return
	var gate := -1
	for col in triggers:
		if not fired.has(triggers[col]) and (gate < 0 or col < gate):
			gate = col
	if gate < 0 or player.position.x > gate * tile:
		return  # nothing ahead (or already past it, after a warp)
	var stop := gate * tile - MARGIN
	if slow_over > 0.0:
		player.speed_mul = walk * clampf((stop - player.position.x) / slow_over, slow_min, 1.0)
	if player.position.x > stop:
		player.position.x = stop
		player.velocity.x = minf(player.velocity.x, 0.0)
