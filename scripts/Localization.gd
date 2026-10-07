extends RefCounted
## English source keys remain stable; translations are data, not gameplay IDs.
static var installed := false
static func install() -> void:
	if installed:
		return
	installed = true
	var table: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://localization/th.json"))
	var thai := Translation.new()
	thai.locale = "th"
	for source in table:
		thai.add_message(source, table[source])
	TranslationServer.add_translation(thai)
	TranslationServer.set_locale("en")
	# Web cannot access desktop system fonts. Ship Thai and Latin glyphs in the PCK.
	var font := preload("res://assets/fonts/NotoSansThai.ttf")
	ThemeDB.fallback_font = font
	ThemeDB.get_default_theme().default_font = font

static func toggle() -> void:
	TranslationServer.set_locale("en" if TranslationServer.get_locale().begins_with("th") else "th")
