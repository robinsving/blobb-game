#!/bin/sh
# Starts Blobb. Re-imports first so new/renamed scripts (class_name) and assets are always picked up.
cd "$(dirname "$0")"
godot-flatpak --headless --path . --import >/dev/null 2>&1
exec godot-flatpak --path . "$@"
