extends SceneTree
func _initialize() -> void:
	var font := load("res://assets/fonts/NotoSansThai.ttf") as FontFile
	font.allow_system_fallback = false
	var missing := ""
	for character in "Hidden in Foam ภาษาไทย กขคงจ เแโใไ ะาิีึืุูั่้๊๋์ 0123456789":
		if not font.has_char(character.unicode_at(0)):
			missing += character
	print("BUNDLED FONT missing glyphs: ", missing)
	quit(0 if missing.is_empty() else 1)
