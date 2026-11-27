class_name Fonts
## Shared fonts and small UI factories.

static var _hand: Font
static var _serif: Font
static var _symbols: Font


## Arrows and controller letters (← → Ⓐ Ⓧ ▾ ...) that Patrick Hand and Lora don't have. On the
## desktop the system would fill them in, but a browser (the web export) has no system fonts.
static func symbols() -> Font:
	if _symbols == null:
		_symbols = load("res://assets/fonts/FreeSans-symbols.ttf")
	return _symbols


## Gives every font (and the default theme font) the symbols as a fallback. Called once at start.
static func add_fallbacks() -> void:
	for f: Font in [hand(), serif(), ThemeDB.fallback_font]:
		if f and not f.fallbacks.has(symbols()):
			f.fallbacks = f.fallbacks + [symbols()]


## Hand-written font (younger narrator, titles).
static func hand() -> Font:
	if _hand == null:
		_hand = load("res://assets/fonts/PatrickHand-Regular.ttf")
	return _hand


## Book serif (older narrator).
static func serif() -> Font:
	if _serif == null:
		_serif = load("res://assets/fonts/Lora.ttf")
	return _serif


static func menu_button(text: String, size := 52) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_override("font", hand())
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", Color(0.93, 0.89, 0.8))
	b.add_theme_color_override("font_focus_color", Color(1.0, 0.85, 0.35))
	b.add_theme_color_override("font_hover_color", Color(1.0, 0.85, 0.35))
	b.add_theme_color_override("font_pressed_color", Color(1.0, 0.7, 0.2))
	b.add_theme_color_override("font_disabled_color", Color(0.5, 0.47, 0.42))
	var empty := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(s, empty)
	b.mouse_entered.connect(func(): b.grab_focus())
	return b
