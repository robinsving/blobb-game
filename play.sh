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
  *) cat <<'HELP'
Starta Blobb direkt i en scen:   ./play.sh SCEN [VAR] [--fast]

  forest     skogen          VAR = kolumn (17 hoppet, 62 bananen, 98 kvällen)
  clearing   gläntan         VAR = rum 1-3 (3 = bananen)
  pond       dammen          VAR = kolumn (43 fiskarna, 64 virveln)
  mill       kvarnen         VAR = rum 1-3
  city       stan            VAR = kolumn (39 kanalen, 84 stupröret)
  roofs      taken           VAR = rum 1-3
  chase      jakten          VAR = taktslag (60 mitten, 104 slutet)
  dream      drömmen         VAR = kolumn (60 ankan, 106 slutet, 114 berget)
  climb      klättringen     VAR = del 0-4 (4 = toppen)
  climbtest  testbanan för studs och sving

  t.ex.  ./play.sh roofs 2     ./play.sh city 39 --fast     ./play.sh climb 4
  --fast = texten går fram av sig själv.  F1 på startskärmen ger samma val i en meny.
HELP
     exit 1 ;;
esac
shift
w=""
case "$1" in ''|-*) ;; *) w="--warp=$1"; shift ;; esac
godot-flatpak --headless --path . --import >/dev/null 2>&1
exec godot-flatpak --path . -- --scene=res://chapters/$s.tscn $w "$@"
