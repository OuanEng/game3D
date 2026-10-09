class_name GameManager
extends Node
## Run state and shop authority. Bucket contents belong to Player; buying an
## upgrade changes its capacity without discarding the foam already carried.
signal progress_changed(collected: int, total: int)
signal game_ended(won: bool)
signal wallet_changed(credits: int)
signal upgrade_bought(id: String)
const UPGRADES := {
	"uv": {"name": "Balanced UV flashlight", "cost": 140, "description": "Brighter glows per level; only under thin foam. Never increases scan depth."},
	"detector": {"name": "Pearl sonar", "cost": 100, "description": "12-metre search range with directional guidance and soft pulses."},
	"scoop": {"name": "Heavy-duty scoop", "cost": 90, "description": "First level: radius 0.45 m, depth 0.14 m. Later levels expand both."},
	"bucket": {"name": "Portable foam bucket", "cost": 60, "description": "Replace your 12-litre hand carry with 80 litres of foam storage."},
	"auto_washer": {"name": "Washing conveyor", "cost": 240, "description": "E loads the belt or retrieves from the clean tray. Each level adds buffer space and 35% base washing speed."},
	"gloves": {"name": "Rapid digging gloves", "cost": 110, "description": "Reduce excavation cooldown."},
	"blower": {"name": "Industrial blower", "cost": 280, "description": "Slot 4: disperse a wide surface layer; no disposal income."},
	"vacuum": {"name": "Foam vacuum", "cost": 420, "description": "Slot 5: continuously transfer foam into your carry storage."},
	"boots": {"name": "Carry speed boots", "cost": 140, "description": "Faster movement and reduced load penalty."},
	"battery": {"name": "Flashlight battery", "cost": 110, "description": "Longer UV charge and brighter work light. Recharges while UV is off."},
	"grabber": {"name": "Magnetized grabber", "cost": 120, "description": "Extend pickup reach and widen aim assistance; walls still block it."},
	"delay": {"name": "Boss distraction", "cost": 300, "description": "Add two minutes to this shift."}
}
# Match Tools.Tool: the scoop is free; UV and detector must be purchased.
const TOOL_UPGRADES := ["", "uv", "detector", "blower", "vacuum"]
@export var starting_credits: int = 0
@export var pearl_reward: int = 25
var credits: int = 0
var owned: Dictionary = {}
var debug_used := false
var disposal_remainder := 0.0
var debug_infinite_bucket: bool = false
enum Mode { NORMAL, HARDCORE }
var mode: Mode = Mode.NORMAL
@export var hardcore_seconds: float = 600.0

func is_hardcore() -> bool:
	return mode == Mode.HARDCORE

func select_mode(value: Mode) -> void:
	# Select before the intro starts. Running shifts cannot change rules midway.
	if phase != Phase.INTRO:
		return
	mode = value
	owned.clear()
	debug_infinite_bucket = false
	remaining = hardcore_seconds if is_hardcore() else boss_arrival_seconds
enum Phase { INTRO, PLAYING, WON, LOST }
var phase: Phase = Phase.INTRO
@export var boss_arrival_seconds: float = 900.0
var remaining: float
var total: int = 0
var collected: int = 0
var running: bool = false
var registered: Array[Pearl] = []

func prepare(pearls: Array[Pearl]) -> void:
	# Prepare the HUD before the intro without starting the boss clock.
	registered = pearls.duplicate()
	total = registered.size()
	collected = 0
	credits = starting_credits
	owned.clear()
	debug_infinite_bucket = false
	remaining = hardcore_seconds if is_hardcore() else boss_arrival_seconds
	running = false
	phase = Phase.INTRO
	progress_changed.emit(collected, total)
	wallet_changed.emit(credits)

func get_upgrade_catalog() -> Dictionary:
	var catalog := UPGRADES.duplicate(true)
	for id in catalog:
		catalog[id]["name"] = tr(catalog[id]["name"])
		catalog[id]["description"] = tr(catalog[id]["description"])
		catalog[id]["cost"] = upgrade_price(id)
		catalog[id]["name"] += "  [%d/%d]" % [level(id), max_level(id)]
	return catalog

func level(id: String) -> int:
	if is_hardcore():
		return 0 # Also blocks stale ownership data from granting equipment effects.
	return int(owned.get(id, 0))

func max_level(id: String) -> int:
	return 1 if id in ["detector", "blower", "vacuum"] else 5

func upgrade_price(id: String) -> int:
	if not UPGRADES.has(id):
		return 0
	# Bounded levels prevent overflow. Each successive level costs 1.85x.
	return int(ceil(float(UPGRADES[id]["cost"]) * pow(1.85, level(id))))

func owns_upgrade(id: String) -> bool:
	return level(id) > 0

func owns_tool(index: int) -> bool:
	if index < 0 or index >= TOOL_UPGRADES.size():
		return false
	return index == 0 or owns_upgrade(TOOL_UPGRADES[index])

func buy_upgrade(id: String) -> bool:
	if is_hardcore():
		return false
	# The store UI is not trusted to enforce cost, phase, or duplicate-purchase rules.
	if not running or remaining <= 0.0 or not UPGRADES.has(id) or level(id) >= max_level(id):
		return false
	var cost: int = upgrade_price(id)
	if credits < cost:
		return false
	credits -= cost
	owned[id] = level(id) + 1
	if id == "delay":
		remaining += 120.0
	wallet_changed.emit(credits)
	upgrade_bought.emit(id)
	return true

func begin_search() -> void:
	# Both skip and natural animation completion enter through this one-shot gate.
	if phase != Phase.INTRO or total == 0:
		return
	phase = Phase.PLAYING
	running = true

func start(pearls: Array[Pearl]) -> void:
	prepare(pearls)
	begin_search()

func _physics_process(delta: float) -> void:
	if not running:
		return
	remaining = maxf(0.0, remaining - delta)
	if remaining <= 0.0:
		finish(false)

func collect(pearl: Pearl, slot: Vector3) -> bool:
	# Validate centrally: duplicate deposits and dirty pearls cannot increment the count.
	if not running or remaining <= 0.0 or pearl not in registered:
		return false
	if pearl.state != Pearl.State.HELD or pearl.residue > 0.0:
		return false
	pearl.display_at(slot)
	collected += 1
	credits += pearl_reward
	wallet_changed.emit(credits)
	progress_changed.emit(collected, total)
	if collected == total:
		finish(true)
	return true

func finish(won: bool) -> void:
	if not running:
		return
	running = false
	phase = Phase.WON if won else Phase.LOST
	game_ended.emit(won)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func reward_disposal(volume: float, material_kind: int) -> int:
	# Retain fractional earnings: splitting dumps cannot manufacture money.
	disposal_remainder += volume * [90.0, 120.0, 160.0, 90.0][material_kind]
	var payout := floori(disposal_remainder)
	disposal_remainder -= payout
	credits += payout
	wallet_changed.emit(credits)
	return payout
