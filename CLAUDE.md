# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

**Blobb** is a story-driven puzzle game in Godot 4.7 (GDScript, GL Compatibility renderer, 1920×1080 canvas). Blobb is based on a child's crayon drawing (`assets/drawing.jpeg`). Two unseen narrators tell the story, and what they say changes the scene live: style, colours, objects, even mechanics. A line can grow branches, shrink a monster, or decide that crates float. Read `docs/story.md` before writing any dialogue. It holds the narrative rules (no family words, tone progression, hidden hospital setting) and the plan for chapters 2–4.

## Commands

Godot runs through flatpak: `godot-flatpak` (wraps `flatpak run org.godotengine.Godot`, with host filesystem access).

```sh
godot-flatpak --headless --path . --import                       # (re)import assets after adding/changing files in assets/
godot-flatpak --path .                                           # play from the title screen
godot-flatpak --path . -- --scene=res://chapters/ch1/forest.tscn # jump straight into a scene
godot-flatpak --headless --path . --script res://tests/test_sokoban.gd   # puzzle rule tests (prints ALL TESTS PASSED / exit 1 on failure)
godot-flatpak --headless --path . --script res://tests/test_story.gd     # validates every chapters/*/story.txt (run after editing dialogue)
godot-flatpak -e --path .                                        # editor
```

Debug user args (after `--`, parsed in `autoload/game.gd`): `--fast` (narration auto-advances quickly), `--lang=sv`, `--warp=COL` (forest: skip the intro and start at a tile column), `--autoplay` (crude platformer bot that runs right and jumps gaps), `--moves=RRUL…|DDR…` (clearing: auto-play box moves, one string per room), `--shots=DIR` (save a screenshot every 2 s), `--quit-after-secs=N`.

Visual check without a window (llvmpipe under xvfb). The screenshot dir must be outside `/tmp`, because the flatpak sandbox has a private `/tmp`. Use `build/` (gitignored):

```sh
xvfb-run -a -s "-screen 0 1920x1080x24" godot-flatpak --path . --resolution 1920x1080 -- \
  --scene=res://chapters/ch1/forest.tscn --fast --autoplay --warp=60 --shots=$PWD/build/shots --quit-after-secs=40
python3 tools/contact_sheet.py build/sheet.png build/shots/*.png
```

An `ERROR: Condition "!is_inside_tree()"` line when using `--scene=` is harmless: the title scene is replaced mid-frame.

Python asset tools in `tools/` need numpy/scipy/pillow (use a venv; the system Python has only Pillow):
- `key_frames.py`: keys the black background out of `assets/animations/*/` frames and builds `assets/sprites/blobb_{idle,running,jumping}.png` (321×305 frames). Jump frames after 7 are excluded because they have a baked-in paper background.
- `key_banana.py`: cuts out the banana creature. `make_tiled_bg.py`: mirror-tiles backgrounds into `assets/backgrounds/`.
- `gen_audio.py`: synthesises all SFX and `music_forest.ogg` into `assets/audio/`.
- `solve_sokoban.py`: BFS solver. Run it after editing any top-down room to prove it's solvable. Update the solutions in `tests/test_sokoban.gd` to match.

## Architecture

- **Autoloads.** `Game` (`autoload/game.gd`) handles language, the input map (registered in code, not in project.godot), `go()` scene transitions with fades, `sfx()`/`music()`, the pause menu, save data (`user://save.cfg`) and debug args. `Narrator` (`autoload/narrator.gd`) is the dialogue layer.
- **Dialogue lives in plain-text scripts.** Each chapter has `chapters/<ch>/story.txt`, which reads like a play: `=== scene ===` blocks, `O:`/`Y:` lines, an indented `sv:` line under each, `@effect` lines, `@pause`/`@hold`, and `#` stage directions. The format is documented in that file's header and in `scripts/story_script.gd`. Level code only decides *when* a scene plays (`await story.play("name", self)`). Each `@foo arg` calls `fx_foo(arg)` on the level, so the level scripts hold the `fx_*` methods. `tests/test_story.gd` checks that every line has Swedish, every effect has an `fx_` method, and every scene the code plays (including the `TRIGGERS` table and `fail_1..4`) exists. When exporting, add `*.txt` to the export filter's non-resource files. `story.play` calls `Narrator.say(lines, blocking)`. Blocking scenes set `Game.control_locked` and wait for the `advance` input; `(ambient)` scenes auto-advance while the player keeps control. Calls queue up. `Narrator.clear()` (called by `Game.go`) bumps a generation counter so stale or queued lines from the previous scene never play. UI strings live in `Game.UI` and are read with `Game.t(key)`.
- **Player scripts must respect `Game.control_locked`**, which is set by blocking narration, cutscenes and retells.
- **Levels are built in code.** Each `.tscn` is a bare root node with a script. The script builds terrain, collisions, triggers and actors from const data tables (e.g. `GROUND`/`TRIGGERS` in `chapters/ch1/forest.gd`, ASCII rooms in `chapters/ch1/rooms.gd`). Story beats fire from trigger columns via `_beat(name)`.
- **Look changes.** `StyleFX` (`scripts/style_fx.gd` + `shaders/style_fx.gdshader`) is a full-screen post-process CanvasLayer. Each level adds one, with presets `paper`, `crayon`, `dark`, `mono`, `real` and `plain`, plus `tint()`, `white()` and `rewind_pulse()`. Blobb's own colour comes from `BlobbSprite.set_tint()` (`shaders/blobb.gdshader`). His canonical colour is `BlobbSprite.GREEN` at `GREEN_AMOUNT`.
- **CanvasLayer order matters.** World at 0, StyleFX 40, Game fade 55, Narrator 60, pause 90, chapter cards 101. The fade sits *below* the narrator so lines can play over black.
- **Failure is a "retell".** There is no death. The younger narrator objects ("He didn't fall!"), StyleFX warbles, and the player is reset to the last checkpoint (`_fail()` in forest).
- **Top-down puzzles.** `SokobanGrid` (`scripts/sokoban_grid.gd`) holds the pure rules (undo, water → bridge only when `crates_float`, gate opens when all plates are covered) and is mirrored by `tools/solve_sokoban.py`. Keep the two in sync. `scripts/clearing_board.gd` only renders.
- **Generated art.** Requested from the `comfyui-0a` Claude session (ComfyUI image generation) and saved to `assets/gen/<chapter>/`. Code always checks `ResourceLoader.exists()` and falls back to existing or procedurally drawn art, so the game runs without them. After new files arrive, run the import command.
