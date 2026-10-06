class_name GameManager
extends Node
## Run state and shop authority. Bucket contents belong to Player; buying an
## upgrade changes its capacity without discarding the foam already carried.
signal progress_changed(collected: int, total: int)
signal game_ended(won: bool)
signal wallet_changed(credits: int)
signal upgrade_bought(id: String)
const UPGRADES := {
	"uv": {"name": "UV flashlight", "cost": 25, "description": "Reveal blue-green glints below a thin layer of foam in the beam."},
	"detector": {"name": "Pearl sonar", "cost": 20, "description": "Follow faster beeps as you approach remaining pearls."},
	"scoop": {"name": "Wide excavation scoop", "cost": 35, "description": "Scoop radius 0.48 to 0.75 m; depth 0.18 to 0.30 m per click."},
	"bucket": {"name": "Large portable foam bucket", "cost": 40, "description": "Capacity 0.22 to 0.50 cubic metres (220 to 500 foam litres)."},
	"auto_washer": {"name": "Portable auto-washer", "cost": 50, "description": "Rinse the held pearl automatically while you walk."}
}
# Match Tools.Tool: the scoop is free; UV and detector must be purchased.
const TOOL_UPGRADES := ["", "uv", "detector"]
@export var starting_credits: int = 60
@export var pearl_reward: int = 25
var credits: int = 0
var owned: Dictionary = {}
enum Phase { INTRO, PLAYING, WON, LOST }
var phase: Phase = Phase.INTRO
@export var boss_arrival_seconds: float = 300.0
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
	remaining = boss_arrival_seconds
	running = false
	phase = Phase.INTRO
	progress_changed.emit(collected, total)
	wallet_changed.emit(credits)

func get_upgrade_catalog() -> Dictionary:
	return UPGRADES.duplicate(true)

func owns_upgrade(id: String) -> bool:
	return owned.get(id, false)

func owns_tool(index: int) -> bool:
	if index < 0 or index >= TOOL_UPGRADES.size():
		return false
	return index == 0 or owns_upgrade(TOOL_UPGRADES[index])

func buy_upgrade(id: String) -> bool:
	# The store UI is not trusted to enforce cost, phase, or duplicate-purchase rules.
	if not running or remaining <= 0.0 or not UPGRADES.has(id) or owns_upgrade(id):
		return false
	var cost: int = UPGRADES[id]["cost"]
	if credits < cost:
		return false
	credits -= cost
	owned[id] = true
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
