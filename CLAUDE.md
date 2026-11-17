# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

**Blobb** is a story-driven puzzle game in Godot 4.7 (GDScript, GL Compatibility renderer, 1920×1080 canvas). Blobb is based on a child's crayon drawing (`assets/drawing.jpeg`). Two unseen narrators tell the story, and what they say changes the scene live: style, colours, objects, even mechanics. A line can grow branches, shrink a monster, or decide that crates float. Read `docs/story.md` before writing any dialogue. It holds the narrative rules (no family words, tone progression, hidden hospital setting) and the plan for chapters 2–4.

## Commands

Godot runs through flatpak: `godot-flatpak` (wraps `flatpak run org.godotengine.Godot`, with host filesystem access).

```sh
godot-flatpak --headless --path . --import                       # (re)import assets after adding/changing files in assets/
./run.sh                                                         # play (re-imports first, so new class_name scripts are known)
godot-flatpak --path .                                           # play without re-importing (can fail with "Parse error" if a new class_name script was added since the last import)
godot-flatpak --path . -- --scene=res://chapters/ch1/forest.tscn # jump straight into a scene
godot-flatpak --headless --path . --script res://tests/test_sokoban.gd   # puzzle rule tests (prints ALL TESTS PASSED / exit 1 on failure)
godot-flatpak --headless --path . --script res://tests/test_story.gd     # validates every chapters/*/story.txt (run after editing dialogue)
godot-flatpak --headless --path . --script res://tests/test_flow.gd      # ch2 mill-puzzle rules; checks each room's shortest solution (room 3 only with the "backwards" rule)
godot-flatpak --path . -- --scene=res://chapters/ch2/pond.tscn           # chapter 2 (millpond, then chapters/ch2/mill.tscn)
godot-flatpak --headless --path . --script res://tests/test_beams.gd     # ch3 rooftop light-bridge rules; checks each room's shortest solution
godot-flatpak --path . -- --scene=res://chapters/ch3/city.tscn           # chapter 3 (town, then roofs.tscn, then chase.tscn)
godot-flatpak -e --path .                                        # editor
```

Debug user args (after `--`, parsed in `autoload/game.gd`): `--fast` (narration auto-advances quickly), `--lang=sv`, `--warp=COL` (forest, pond and city: skip the intro and start at a tile column; roofs: start at room N; chase: start at beat N), `--autoplay` (bots: the forest one runs right and jumps gaps, the pond one swims right at mid-depth, in the mill and on the roofs the rooms solve themselves, and the chase bot jumps and dodges), `--moves=RRUL…|DDR…` (clearing: auto-play box moves, one string per room), `--shots=DIR` (save a screenshot every 2 s), `--quit-after-secs=N`.

Visual check without a window (llvmpipe under xvfb). The screenshot dir must be outside `/tmp`, because the flatpak sandbox has a private `/tmp`. Use `build/` (gitignored):

```sh
xvfb-run -a -s "-screen 0 1920x1080x24" godot-flatpak --path . --resolution 1920x1080 -- \
  --scene=res://chapters/ch1/forest.tscn --fast --autoplay --warp=60 --shots=$PWD/build/shots --quit-after-secs=40
python3 tools/contact_sheet.py build/sheet.png build/shots/*.png
```

An `ERROR: Condition "!is_inside_tree()"` line when using `--scene=` is harmless: the title scene is replaced mid-frame.

Python asset tools in `tools/` need numpy/scipy/pillow (use a venv; the system Python has only Pillow):
- `key_frames.py` (missing from the repo; the strips it made are committed): keys the black background out of `assets/animations/*/` frames and builds `assets/sprites/blobb_{idle,running,jumping}.png` (321×305 frames). Jump frames after 7 are excluded because they have a baked-in paper background.
- `key_superjump.py`: keys the beige-paper jump frames 24–32 into `assets/sprites/blobb_superjump.png` (the stretched, flying Blobb), colour-matched to the other strips.
- `cut_drawing.py`: cuts the figures out of the original drawing into `assets/sprites/drawn_*.png` (see "Blobb's forms" in `docs/story.md`). Pass a path to also write a preview sheet.
- `key_banana.py`: cuts out the banana creature. `make_tiled_bg.py`: mirror-tiles backgrounds into `assets/backgrounds/`.
- `gen_audio.py`: synthesises ch1's SFX and `music_forest.ogg` into `assets/audio/`. `gen_audio_ch2.py` adds ch2's (whistle, drip, bubble, turn, flow, gurgle, `music_pool.ogg`) without touching ch1's. `gen_audio_ch3.py` adds ch3's (kick, hat, crank, lamp_on, coo, flap, `music_city.ogg`).
- `solve_flow.py`: BFS solver for the ch2 mill rooms. It mirrors `scripts/flow_room.gd`, so keep the two in sync. Run it after editing `chapters/ch2/flow_rooms.gd`, then update `SHORTEST` in `tests/test_flow.gd`.
- `solve_beams.py`: BFS solver for the ch3 rooftop rooms. It mirrors `scripts/beam_room.gd`, so keep the two in sync. Run it after editing `chapters/ch3/beam_rooms.gd`, then update `SHORTEST` in `tests/test_beams.gd`. Its docstring explains the jump model (how far Blobb can jump, in cells) and the gap rule that keeps it honest.
- `solve_sokoban.py`: BFS solver. Run it after editing any top-down room to prove it's solvable. Update the solutions in `tests/test_sokoban.gd` to match.

## Architecture

- **Autoloads.** `Game` (`autoload/game.gd`) handles language, the input map (registered in code, not in project.godot), `go()` scene transitions with fades, `sfx()`/`music()`, the pause menu, save data (`user://save.cfg`) and debug args. `Narrator` (`autoload/narrator.gd`) is the dialogue layer.
- **Dialogue lives in plain-text scripts.** Each chapter has `chapters/<ch>/story.txt`, which reads like a play: `=== scene ===` blocks, `O:`/`Y:` lines, an optional indented `sv:` line under each (falls back to English), `@effect` lines, `@pause`/`@hold`, and `#` stage directions. The format is documented in that file's header and in `scripts/story_script.gd`. Level code only decides *when* a scene plays (`await story.play("name", self)`). Each `@foo arg` calls `fx_foo(arg)` on the level, so the level scripts hold the `fx_*` methods. `tests/test_story.gd` checks that every effect has an `fx_` method, and every scene the code plays (including the `TRIGGERS` table and `fail_1..4`) exists. When exporting, add `*.txt` to the export filter's non-resource files. `story.play` calls `Narrator.say(lines, blocking)`. Blocking scenes set `Game.control_locked` and wait for the `advance` input; `(ambient)` scenes auto-advance while the player keeps control. Calls queue up. `Narrator.clear()` (called by `Game.go`) bumps a generation counter so stale or queued lines from the previous scene never play. UI strings live in `Game.UI` and are read with `Game.t(key)`.
- **Player scripts must respect `Game.control_locked`**, which is set by blocking narration, cutscenes and retells.
- **Levels are built in code.** Each `.tscn` is a bare root node with a script. The script builds terrain, collisions, triggers and actors from const data tables (e.g. `GROUND`/`TRIGGERS` in `chapters/ch1/forest.gd`, ASCII rooms in `chapters/ch1/rooms.gd`). Story beats fire from trigger columns via `_beat(name)`.
- **Look changes.** `StyleFX` (`scripts/style_fx.gd` + `shaders/style_fx.gdshader`) is a full-screen post-process CanvasLayer. Each level adds one, with presets `paper`, `crayon`, `dark`, `mono`, `real` and `plain`, plus `tint()`, `white()` and `rewind_pulse()`. Blobb's own colour comes from `BlobbSprite.set_tint()` (`shaders/blobb.gdshader`). His canonical colour is `BlobbSprite.GREEN` at `GREEN_AMOUNT`.
- **CanvasLayer order matters.** World at 0, StyleFX 40, Game fade 55, Narrator 60, pause 90, chapter cards 101. The fade sits *below* the narrator so lines can play over black.
- **Failure is a "retell".** There is no death. The younger narrator objects ("He didn't fall!"), StyleFX warbles, and the player is reset to the last checkpoint (`_fail()` in forest).
- **Top-down puzzles.** `SokobanGrid` (`scripts/sokoban_grid.gd`) holds the pure rules (undo, water → bridge only when `crates_float`, gate opens when all plates are covered) and is mirrored by `tools/solve_sokoban.py`. Keep the two in sync. `scripts/clearing_board.gd` only renders.
- **Chapter 2.** It's set outdoors: a millpond, then the old mill's channel. `PlayerSwim` (`scripts/player_swim.gd`) has three modes: LAND on the bank, SINK (heavy, hops along the bottom) and SWIM (unlocked by the story). Each frame the level sets `player.flow` for currents, spring lifts and the whirlpool's pull. The mill puzzle is `FlowRoom` (`scripts/flow_room.gd`), which holds the pure rules:
  - Spouts send streams that bend off boards.
  - The duck moves one cell per tick along a stream, or floats up when no stream reaches it.
  - Blobb uses wheels (spouts on/off, and backwards once the story allows it) and levers (flip boards) from behind a fence.
  - It includes a BFS solver.

  Rooms are in `chapters/ch2/flow_rooms.gd`, and `chapters/ch2/mill.gd` only renders and handles input. Retells in every level use `Retell.scribble()/clear()` (`scripts/retell.gd`).
- **Chapter 3.** Outdoors at night, three scenes:
  - `chapters/ch3/city.gd`: a poster title page, then a side-view street (PlayerSide). Lamps come on, Blobb turns gold and back to green, a banana sweeper, the dash form over a canal, a drainpipe up.
  - `chapters/ch3/roofs.gd`: the light-bridge puzzle. `BeamRoom` (`scripts/beam_room.gd`) holds the pure rules plus a BFS solver: cranks turn rooftop lamps, and every beam becomes something to stand on (one-way collision; diagonal beams are 45° ramps, vertical beams are ladders of rungs). Rooms are in `chapters/ch3/beam_rooms.gd`.
  - `chapters/ch3/chase.gd`: an isometric rooftop chase drawn entirely in code (faux-3D Blobb, roofs, chimneys, birds, the hospital). One beat clock drives everything: Blobb's distance is the beat, so gaps arrive on the beat. The drum (kick and hat) crossfades into the monitor beep, then speeds up. Only Y speaks there (`LINES`, by beat).
- **Listening speed.** While ambient narration plays, Blobb moves at `Game.LISTENING_SPEED` (40%), so the player can't race past what's being said. Player scripts multiply their speed by `Game.move_scale()`.
- **Generated art.** Requested from the ComfyUI Claude session (a peer session named `comfyui-*`; find it with ListAgents) (ComfyUI image generation) and saved to `assets/gen/<chapter>/`. Code always checks `ResourceLoader.exists()` and falls back to existing or procedurally drawn art, so the game runs without them. After new files arrive, run the import command.
