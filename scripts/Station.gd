class_name Station
extends StaticBody3D
enum Kind { WASH, DISPLAY }
@export var kind: Kind = Kind.WASH
var washing_item: Pearl
var belt_anchor: Marker3D
var washer_art: Node3D
var basin_art: Node3D
var manual_flow_remaining := 0.0
var waiting: Array[Pearl] = []
var clean_items: Array[Pearl] = []

func _ready() -> void:
	belt_anchor = Marker3D.new()
	belt_anchor.position = Vector3(0, 0.22, 0)
	add_child(belt_anchor)
	collision_layer = 16
	collision_mask = 0
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	# Extend the interaction target beyond the decorative rim so the second
	# and later deposits cannot be blocked by furniture when aiming from front.
	shape.size = Vector3(1.35, 0.5, 1.25)
	collider.position.y = 0.15
	collider.shape = shape
	add_child(collider)
	if kind == Kind.WASH:
		basin_art = preload("res://scripts/WashBasin.gd").new()
		basin_art.name = "ManualWashBasin"
		add_child(basin_art)
		washer_art = preload("res://scripts/WasherArt.gd").new()
		washer_art.name = "ConveyorWithWaterJets"
		add_child(washer_art)
		var art = preload("res://scripts/ToolArt.gd")
		art.box(washer_art, Vector3(0, 0.13, 0.43), Vector3(1.25, 0.05, 0.43), art.mat(Color(0.32, 0.40, 0.42), 0.7))
		art.box(washer_art, Vector3(0, 0.20, 0.65), Vector3(1.25, 0.12, 0.03), art.mat(Color(0.32, 0.40, 0.42), 0.7))

func slot(index: int) -> Vector3:
	return global_position + Vector3(-0.45 + (index % 4) * 0.3, 0.18, -0.2 + (index / 4) * 0.35)

func buffer_capacity() -> int:
	return 2 + get_parent().manager.level("auto_washer")

func queue_count() -> int:
	return waiting.size() + (1 if is_instance_valid(washing_item) else 0)

func accept_item(item: Pearl) -> bool:
	# Reject without changing ownership: the player can always keep or throw it.
	if not get_parent().manager.running or kind != Kind.WASH or not get_parent().manager.owns_upgrade("auto_washer") or not is_instance_valid(item):
		return false
	if item.state != Pearl.State.HELD or item == washing_item or item in waiting or item in clean_items:
		return false
	if item.residue > 0.0 and queue_count() >= buffer_capacity():
		return false
	var anchor := Marker3D.new()
	add_child(anchor)
	item.holder = anchor
	if item.residue <= 0.0:
		clean_items.append(item)
	else:
		waiting.append(item)
	start_next()
	arrange_items()
	return true

func arrange_items() -> void:
	for i in range(waiting.size()):
		waiting[i].holder.position = Vector3(-0.45 + (i % 4) * 0.28, 0.30 + (i / 4) * 0.20, -0.35)
	# Tray grows in stacked rows; finished items never block the washing belt.
	for i in range(clean_items.size()):
		clean_items[i].holder.position = Vector3(-0.45 + (i % 4) * 0.30, 0.26 + (i / 8) * 0.22, 0.31 + ((i / 4) % 2) * 0.21)

func take_clean(hand: Node3D) -> Pearl:
	if clean_items.is_empty():
		return null
	var item: Pearl = clean_items.pop_front()
	item.holder.queue_free()
	item.state = Pearl.State.EXPOSED
	item.pick_up(hand)
	arrange_items()
	return item

func _physics_process(delta: float) -> void:
	var running: bool = get_parent().manager.running
	if basin_art != null:
		basin_art.visible = not get_parent().manager.owns_upgrade("auto_washer")
		basin_art.update_water(delta, running and manual_flow_remaining > 0)
		manual_flow_remaining = maxf(0.0, manual_flow_remaining - delta)
	if washer_art != null:
		washer_art.visible = get_parent().manager.owns_upgrade("auto_washer")
		washer_art.update_washing(delta, is_instance_valid(washing_item) and washing_item.residue > 0.0 and get_parent().manager.running)
	if not running:
		return # Ended shifts do not advance cleaning or move another queued item.
	if is_instance_valid(washing_item):
		washing_item.wash(delta * 0.67 * (1.0 + 0.35 * (get_parent().manager.level("auto_washer") - 1)))
		belt_anchor.position.x = -0.35 + (1.0 - washing_item.residue) * 0.7
		if washing_item.residue <= 0.0:
			var tray_anchor := Marker3D.new()
			add_child(tray_anchor)
			washing_item.holder = tray_anchor
			clean_items.append(washing_item)
			washing_item = null
			arrange_items()
	start_next()

func start_next() -> void:
	if washing_item == null and not waiting.is_empty():
		washing_item = waiting.pop_front()
		washing_item.holder.queue_free()
		washing_item.holder = belt_anchor
		belt_anchor.position.x = -0.35
		arrange_items()
