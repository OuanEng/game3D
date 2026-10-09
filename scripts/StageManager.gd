extends Node
## Stage data, career checkpoint, tutorial and timed events have one owner.
## Career is committed on successful normal shifts, including F3 testing runs.
const STAGES := [
	{"title":"Packaging Warehouse", "material":0, "radii":Vector2(2.4,2.0), "height":1.1, "items":3, "seconds":900.0, "hardcore":480.0, "reward":60, "bonus":200, "hard":true},
	{"title":"Rustic Salt Barn", "material":1, "radii":Vector2(5.2,4.5), "height":2.6, "items":5, "seconds":960.0, "hardcore":600.0, "reward":100, "bonus":350, "hard":false},
	{"title":"Construction Site Yard", "material":2, "radii":Vector2(6.2,5.0), "height":3.3, "items":6, "seconds":1080.0, "hardcore":600.0, "reward":140, "bonus":500, "hard":false},
	{"title":"Industrial Mega Depot", "material":3, "radii":Vector2(7.0,5.5), "height":4.5, "items":8, "seconds":900.0, "hardcore":600.0, "reward":180, "bonus":700, "hard":true}
]
const TUTORIAL := ["Tutorial: click the small pile to dig.", "Tutorial: take the foam to the waste bin and press Q.", "Tutorial: buy a bucket at the supply desk with E.", "Tutorial: expose a round item and press E to pick it up.", "Tutorial: hold E at the blue station to wash it.", "Tutorial: press E at the velvet box to return it.", "Tutorial complete: recover the remaining items."]
static var selected_stage := 0
static var pending_mode := -1
var world: Node3D
var unlocked := 0
var debug_all_stages := false
var bank := 0
var equipment: Dictionary = {}
var save_path := "user://career.cfg"
var persistence_enabled := true
var tutorial_step := 0
var event_message := ""
var event_remaining := 0.0
var event_elapsed := 0.0
var next_event := 65.0
var outage_lights: Array[Light3D] = []
var dug := false
var dumped := false
var grant_given := false
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	persistence_enabled = not "--script" in OS.get_cmdline_args()
	rng.randomize()
	var file := ConfigFile.new()
	if persistence_enabled and file.load(save_path) == OK:
		unlocked = clampi(file.get_value("career", "unlocked", 0), 0, 3)
		debug_all_stages = bool(file.get_value("career", "debug_all_stages", false))
		bank = maxi(0, int(file.get_value("career", "cash", 0)))
		var saved: Variant = file.get_value("career", "equipment", {})
		if saved is Dictionary:
			equipment = saved
	selected_stage = clampi(selected_stage, 0, 3)

func data() -> Dictionary:
	return STAGES[selected_stage]

func configure(pile: FoamMesh) -> void:
	pile.mound_radii = data().radii
	pile.mound_height = data().height
	pile.pearl_count = data().items
	pile.material_kind = data().material
	pile.shallow_targets = selected_stage == 0

func begin() -> void:
	world.manager.boss_arrival_seconds = data().seconds
	world.manager.hardcore_seconds = data().hardcore
	world.manager.remaining = data().hardcore if world.manager.is_hardcore() else data().seconds
	world.manager.pearl_reward = data().reward
	if not world.manager.is_hardcore():
		world.manager.credits = bank
		for id in equipment:
			if GameManager.UPGRADES.has(id) and id != "delay":
				world.manager.owned[id] = clampi(int(equipment[id]), 0, world.manager.max_level(id))
		for id in ["bucket", "scoop", "gloves"]:
			world.player.tools._refresh_art(id)
	else:
		# Hands-only variant buries targets shallowly, rather than requiring tools.
		for item in world.pearls:
			item.global_position.y = maxf(0.20, world.foam_mesh.sample_height(item.global_position) - 0.15)
			item.home = item.global_position
	world.manager.wallet_changed.emit(world.manager.credits)

func can_enter(index: int, hardcore: bool) -> bool:
	if index < 0 or index > unlocked or index >= STAGES.size():
		return false
	if debug_all_stages:
		return true # Test any stage without equipment prerequisites.
	if hardcore:
		return STAGES[index].hard
	return index != 2 or int(equipment.get("scoop", 0)) >= 2 or int(equipment.get("vacuum", 0)) >= 1

func launch(index: int, mode: GameManager.Mode) -> void:
	if not can_enter(index, mode == GameManager.Mode.HARDCORE):
		return
	selected_stage = index
	pending_mode = mode
	get_tree().paused = false
	get_tree().reload_current_scene()

func complete(won: bool) -> void:
	end_event()
	if not won or world.manager.is_hardcore():
		return
	unlocked = maxi(unlocked, mini(3, selected_stage + 1))
	bank = world.manager.credits + int(data().bonus)
	equipment = world.manager.owned.duplicate()
	equipment.erase("delay")
	save_career()

func unlock_all_stages() -> void:
	unlocked = STAGES.size() - 1
	debug_all_stages = true
	save_career() # Persist immediately; no shift completion needed.

func save_career() -> void:
	if persistence_enabled:
		var file := ConfigFile.new()
		file.set_value("career", "unlocked", unlocked)
		file.set_value("career", "debug_all_stages", debug_all_stages)
		file.set_value("career", "cash", bank)
		file.set_value("career", "equipment", equipment)
		file.save(save_path)

func note_dig() -> void:
	dug = true
func note_dump() -> void:
	dumped = true
	if selected_stage == 0 and not grant_given and not world.manager.is_hardcore():
		grant_given = true
		world.manager.credits += 60
		world.manager.wallet_changed.emit(world.manager.credits)

func tutorial_text() -> String:
	if selected_stage != 0:
		return ""
	return tr(TUTORIAL[tutorial_step])

func _physics_process(delta: float) -> void:
	if not world.manager.running:
		return
	if selected_stage == 0:
		match tutorial_step:
			0:
				if dug:
					tutorial_step = 1
			1:
				if dumped:
					tutorial_step = 3 if world.manager.is_hardcore() else 2
			2:
				if world.manager.owns_upgrade("bucket"):
					tutorial_step = 3
			3:
				if world.player.held != null:
					tutorial_step = 4
			4:
				if world.player.held != null and world.player.held.residue <= 0.0 or world.manager.collected > 0:
					tutorial_step = 5
			5:
				if world.manager.collected > 0:
					tutorial_step = 6
		return
	if event_remaining > 0:
		event_remaining -= delta
		if event_remaining <= 0:
			end_event()
		return
	event_elapsed += delta
	if event_elapsed >= next_event:
		event_elapsed = 0.0
		next_event = rng.randf_range(35, 55) if selected_stage == 3 else rng.randf_range(65, 95)
		trigger_event(rng.randi_range(0, 2))

func trigger_event(kind: int) -> void:
	end_event()
	event_remaining = 12.0 if kind == 0 else 8.0
	event_message = ["Power outage! Use your work light (F7).", "Radio: the supervisor is checking the loading dock.", "Emergency drill: keep searching and stay calm."][kind]
	world.audio.one_shot("radio" if kind == 1 else "alarm")
	if kind == 0:
		for lamp in world.find_children("*", "Light3D", true, false):
			if not world.player.is_ancestor_of(lamp) and lamp.visible:
				outage_lights.append(lamp)
				lamp.hide()

func end_event() -> void:
	for lamp in outage_lights:
		if is_instance_valid(lamp):
			lamp.show()
	outage_lights.clear()
	event_remaining = 0.0
	event_message = ""
