class_name Ln
## Dialogue line constructors. A line is a Dictionary:
##   who:   "o" (older, wiser narrator) | "y" (younger, naive narrator)
##   en/sv: text per language
##   fx:    optional Callable, fired once the line has finished typing (scene changes)
##   hold:  optional extra seconds to wait after fx before the line can be dismissed
##   pre:   optional silence (seconds) before the line starts
##
## Usage:  Narrator.say([Ln.y("Tell me a story.", "Berätta en saga."), Ln.o(..., ..., fx)])


static func o(en: String, sv: String, fx := Callable(), extra := {}) -> Dictionary:
	return _make("o", en, sv, fx, extra)


static func y(en: String, sv: String, fx := Callable(), extra := {}) -> Dictionary:
	return _make("y", en, sv, fx, extra)


static func _make(who: String, en: String, sv: String, fx: Callable, extra: Dictionary) -> Dictionary:
	var d := {"who": who, "en": en, "sv": sv}
	if fx.is_valid():
		d["fx"] = fx
	d.merge(extra)
	return d
