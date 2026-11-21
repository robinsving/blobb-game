#!/bin/sh
# Runs gda (github.com/aigengame/godot-agent) against Blobb: live checks of the running game.
#   tools/gda.sh start SCENE    # e.g. res://chapters/ch3/roofs.tscn (windowed, on a private Xvfb)
#   tools/gda.sh state          # the level's debug_state() as JSON (see scripts/debug_state.gd)
#   tools/gda.sh shot FILE      # screenshot (use build/, not /tmp: the flatpak has its own /tmp)
#   tools/gda.sh stop           # stop the game AND remove gda's harness from the project
#   tools/gda.sh ANY GDA ARGS   # anything else is passed to gda, e.g. input tap --action use
# Setup (once): uv tool install --python 3.13 "gda[mcp]", and ~/.local/bin/godot-gda: the
# godot-flatpak wrapper plus --filesystem=xdg-run/gda (so the game can reach gda's socket).
# `start` adds addons/gda_harness/ and a GdaHarness autoload to project.godot; `stop` takes
# both out again. Never commit them (addons/gda_harness/ is gitignored; check project.godot).
set -e
cd "$(dirname "$0")/.."
export PATH="$HOME/.local/bin:$PATH"
export GDA_GODOT="${GDA_GODOT:-$HOME/.local/bin/godot-gda}" GDA_PROJECT="$PWD"
export DISPLAY="${GDA_DISPLAY:-:97}"
cmd="$1"; [ $# -gt 0 ] && shift
case "$cmd" in
  start)
    pgrep -f "Xvfb $DISPLAY" >/dev/null || { Xvfb "$DISPLAY" -screen 0 1920x1080x24 >/dev/null 2>&1 & sleep 1; }
    godot-flatpak --headless --path . --import >/dev/null 2>&1 || true
    gda daemon start --windowed --scene "${1:-res://scenes/title.tscn}" --json >/dev/null
    exec gda daemon wait-ready --json ;;
  state)
    root=$(gda game tree --max-depth 0 --json | python3 -c "import json,sys;print(json.load(sys.stdin)['root']['path'])")
    exec gda game call "$root" --method debug_state --json ;;
  shot)
    exec gda screen capture --output "$(realpath -m "${1:-build/gda.png}")" --json ;;
  stop)
    gda daemon stop --json >/dev/null 2>&1 || true
    gda daemon uninstall --json >/dev/null 2>&1 || true
    rmdir addons 2>/dev/null || true
    pkill -f "Xvfb $DISPLAY" 2>/dev/null || true
    git diff --quiet project.godot || echo "warning: project.godot still differs from git" >&2 ;;
  "") sed -n '2,11p' "$0" ;;
  *) exec gda "$cmd" "$@" ;;
esac
