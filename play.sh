#!/bin/sh
# Starts Blobb straight in a scene, for testing. Same as the test menu (F1 on the title screen).
#   ./play.sh SCENE [WHERE] [more flags]
#   SCENE: forest, clearing, pond, mill, city, roofs, chase, dream, climb, climbtest
#   WHERE: a column (forest, pond, city, dream), a room (clearing, mill, roofs),
#          a beat (chase) or a section 0-4 (climb)
#   e.g.  ./play.sh roofs 2      ./play.sh city 39 --fast      ./play.sh climb 4
cd "$(dirname "$0")"
case "$1" in
  forest) s=ch1/forest ;; clearing) s=ch1/clearing ;; pond) s=ch2/pond ;; mill) s=ch2/mill ;;
  city) s=ch3/city ;; roofs) s=ch3/roofs ;; chase) s=ch3/chase ;; dream) s=ch4/dream ;;
  climb) s=ch5/climb ;; climbtest) s=ch5/climb_test ;;
  *) sed -n '3,8p' "$0"; exit 1 ;;
esac
shift
w=""
case "$1" in ''|-*) ;; *) w="--warp=$1"; shift ;; esac
godot-flatpak --headless --path . --import >/dev/null 2>&1
exec godot-flatpak --path . -- --scene=res://chapters/$s.tscn $w "$@"
