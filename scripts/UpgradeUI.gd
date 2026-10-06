class_name UpgradeUI
extends CanvasLayer
## Modal supply terminal. The boss clock keeps running while browsing.
## The manager is the single authority for funds, prices, and ownership.
signal closed

var is_open: bool = false
var _player: Player
var _manager: GameManager
var _wallet: Label
var _message: Label
var _rows: VBoxContainer
var _close_button: Button
var _buttons: Dictionary = {}

func _ready() -> void:
	layer = 20
	_build_panel()
	hide()

func open_store(player: Player, manager: GameManager) -> void:
	if is_open or not manager.running:
		return
	_disconnect_manager()
	_player = player
	_manager = manager
	_manager.wallet_changed.connect(_on_wallet_changed)
	_manager.game_ended.connect(_on_game_ended)
	is_open = true
	_player.store_open = true
	_player.velocity.x = 0.0
	_player.velocity.z = 0.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_message.text = "Each returned pearl earns %d credits. Dump a full bucket at FOAM WASTE. The boss clock keeps running." % _manager.pearl_reward
	_message.modulate = Color(0.73, 0.81, 0.79)
	_build_catalog()
	_refresh()
	show()
	_close_button.grab_focus()

func close_store() -> void:
	if not is_open:
		return
	is_open = false
	hide()
	if is_instance_valid(_player):
		_player.store_open = false
	# Losing or winning dismisses the shop without hiding the result-screen cursor.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if is_instance_valid(_manager) and _manager.running else Input.MOUSE_MODE_VISIBLE
	_disconnect_manager()
	closed.emit()

func _input(event: InputEvent) -> void:
	if is_open and event.is_action_pressed("ui_cancel"):
		close_store()
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if is_open and is_instance_valid(_manager):
		var seconds := int(ceil(_manager.remaining))
		_wallet.text = "AVAILABLE CREDIT   %d     |     BOSS ARRIVES   %02d:%02d" % [_manager.credits, seconds / 60, seconds % 60]

func _disconnect_manager() -> void:
	if not is_instance_valid(_manager):
		return
	if _manager.wallet_changed.is_connected(_on_wallet_changed):
		_manager.wallet_changed.disconnect(_on_wallet_changed)
	if _manager.game_ended.is_connected(_on_game_ended):
		_manager.game_ended.disconnect(_on_game_ended)

func _on_game_ended(_won: bool) -> void:
	close_store()

func _on_wallet_changed(_credits: int) -> void:
	_refresh()

func _buy(id: String) -> void:
	if not is_open or not is_instance_valid(_manager):
		return
	var item: Dictionary = _manager.get_upgrade_catalog().get(id, {})
	if _manager.buy_upgrade(id):
		_message.text = "%s unlocked. Select 1 / SCOOP, 2 / UV, 3 / DETECTOR or use the mouse wheel." % String(item.get("name", id))
		if id in ["scoop", "bucket", "auto_washer"]:
			_message.text = "%s installed. This upgrade works automatically." % String(item.get("name", id))
		_message.modulate = Color(0.43, 0.95, 0.69)
	else:
		_message.text = "Purchase unavailable. Check your credits and owned upgrades."
		_message.modulate = Color(1.0, 0.66, 0.43)
	_refresh()

func _refresh() -> void:
	if not is_instance_valid(_manager):
		return
	_wallet.text = "AVAILABLE CREDIT   %d" % _manager.credits
	var catalog: Dictionary = _manager.get_upgrade_catalog()
	for id in _buttons:
		var button: Button = _buttons[id]
		var item: Dictionary = catalog[id]
		var cost := int(item["cost"])
		var owned := _manager.owns_upgrade(id)
		button.disabled = owned or _manager.credits < cost or not _manager.running
		button.text = "OWNED" if owned else "BUY / %d" % cost
		if owned:
			button.tooltip_text = "Already available in your loadout."
		elif _manager.credits < cost:
			button.text = "NEED %d MORE" % (cost - _manager.credits)
			button.tooltip_text = "Return more clean pearls to earn credits."
		else:
			button.tooltip_text = "Buy this upgrade for %d credits." % cost

func _build_catalog() -> void:
	# Rebuilding only on open keeps each button tied to the active manager.
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	_buttons.clear()
	var catalog: Dictionary = _manager.get_upgrade_catalog()
	for key in catalog:
		var id := String(key)
		var item: Dictionary = catalog[id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 20)
		row.custom_minimum_size.y = 58.0
		_rows.add_child(row)
		var description := VBoxContainer.new()
		description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(description)
		var title := Label.new()
		title.text = String(item["name"])
		title.add_theme_font_size_override("font_size", 19)
		description.add_child(title)
		var detail := Label.new()
		detail.text = String(item["description"])
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.add_theme_font_size_override("font_size", 14)
		detail.modulate = Color(0.74, 0.8, 0.79)
		description.add_child(detail)
		var button := Button.new()
		button.custom_minimum_size = Vector2(170, 42)
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		button.pressed.connect(_buy.bind(id))
		row.add_child(button)
		_buttons[id] = button

func _build_panel() -> void:
	var veil := ColorRect.new()
	veil.color = Color(0.01, 0.025, 0.025, 0.9)
	add_child(veil)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel := PanelContainer.new()
	veil.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -460
	panel.offset_right = 460
	panel.offset_top = -312
	panel.offset_bottom = 312
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.065, 0.095, 0.085)
	style.border_color = Color(0.22, 0.44, 0.34)
	style.set_border_width_all(2)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	var title := Label.new()
	title.text = "NIGHT SHIFT / SUPPLY TERMINAL"
	title.add_theme_font_size_override("font_size", 26)
	column.add_child(title)
	_wallet = Label.new()
	_wallet.add_theme_font_size_override("font_size", 20)
	_wallet.modulate = Color(0.5, 0.95, 0.71)
	column.add_child(_wallet)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = 360
	column.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 9)
	scroll.add_child(_rows)
	_message = Label.new()
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.custom_minimum_size.y = 42
	column.add_child(_message)
	_close_button = Button.new()
	_close_button.text = "RETURN TO SEARCH / ESC"
	_close_button.custom_minimum_size.y = 42
	_close_button.pressed.connect(close_store)
	column.add_child(_close_button)
