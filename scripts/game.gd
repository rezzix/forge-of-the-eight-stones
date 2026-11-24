extends Node3D
## ============================================================================
##  FORGE OF THE EIGHT STONES - Chapter 1
## ============================================================================
##  The "brain" of the game. It builds the round island, spawns the six temples
##  and bosses, remembers your stuff, and runs the Forge.
##
##  The content (biomes, bosses, colours) lives in scripts/world_data.gd.
##  The numbers you usually want to tweak are in the BALANCE block below.
## ============================================================================

const ORE_SCENE = preload("res://scenes/ore_node.tscn")
const WOOD_SCENE = preload("res://scenes/wood_node.tscn")
const ENEMY_SCENE = preload("res://scenes/enemy.tscn")
const BOSS_SCENE = preload("res://scenes/boss.tscn")
const PLAYER_SCENE = preload("res://scenes/player.tscn")
const HUD_SCRIPT = preload("res://scripts/hud.gd")
const TRADER_SCRIPT = preload("res://scripts/trader.gd")
const WOLF_SCRIPT = preload("res://scripts/wolf.gd")
const ANIMAL_SCRIPT = preload("res://scripts/animal.gd")
const ARROW_SCRIPT = preload("res://scripts/arrow.gd")
const VILLAGER_SCRIPT = preload("res://scripts/villager.gd")
const TREE_SCRIPT = preload("res://scripts/tree.gd")
const FARM_ANIMAL_SCRIPT = preload("res://scripts/farm_animal.gd")



## The HUD listens to this for the little "you got +1 stone" messages.
signal log_message(text: String)

# ---------------------------------------------------------------- BALANCE ---
const MAX_HEALTH := 100.0
const MAX_HUNGER := 100.0
const START_COINS := 30
const COINS_LOST_ON_KNOCKOUT := 15
const INTERACT_RANGE := 6.0
const SELL_STONE_PRICE := 25
const SELL_STONE_AMOUNT := 10
const INFUSE_COIN_COST := 25
const INFUSE_DAMAGE_BONUS := 7.0

## Weapons are built from a material and a shape, and the price comes from the
## LENGTH: a 0.45 m dagger needs 3 copper, a 2.1 m spear needs 11.
## Wood is the soft one (easy to find, weaker), iron is the strongest.
## "draw_mult" is the bonus a material gives to a weapon you draw yourself.
const WEAPON_METALS := [
	{"id": "wood", "name": "Wood", "base_damage": 10.0, "draw_mult": 0.8,
		"color": Color(0.72, 0.47, 0.24)},
	{"id": "hardwood", "name": "Hardwood", "base_damage": 14.0, "draw_mult": 1.1,
		"color": Color(0.55, 0.34, 0.18)},
	{"id": "copper", "name": "Copper", "base_damage": 12.0, "draw_mult": 1.0,
		"color": Color(0.95, 0.6, 0.28)},
	{"id": "iron", "name": "Iron", "base_damage": 18.0, "draw_mult": 1.5,
		"color": Color(0.85, 0.88, 0.96)},
	{"id": "uranium", "name": "Uranium", "base_damage": 24.0, "draw_mult": 1.8,
		"color": Color(0.55, 0.95, 0.3)},
	{"id": "sky_crystal", "name": "Sky Crystal", "base_damage": 30.0, "draw_mult": 2.0,
		"color": Color(0.45, 0.9, 1.0)},
]

const WEAPON_SHAPES := [
	{"id": "dagger", "name": "Dagger", "length": 0.45, "factor": 0.8, "swing": 0.22, "reach": 4.5},
	{"id": "sword", "name": "Sword", "length": 1.0, "factor": 1.0, "swing": 0.32, "reach": 6.0},
	{"id": "katana", "name": "Katana", "length": 1.3, "factor": 1.15, "swing": 0.38, "reach": 6.5},
	{"id": "spear", "name": "Spear", "length": 2.1, "factor": 1.45, "swing": 0.5, "reach": 8.5},
]

const SLOT_COUNT := 9        ## the bag has 9 slots
const STACK_LIMIT := 15      ## one slot holds at most 15 of one item

## The four armour pieces you can draw and wear.
const ARMOUR_PIECES := [
	{"id": "helmet", "name": "Helmet"},
	{"id": "chestplate", "name": "Chestplate"},
	{"id": "pants", "name": "Pants"},
	{"id": "boots", "name": "Boots"},
]

## What the wandering trader buys and sells.
const TRADER_OFFERS := [
	{"kind": "buy", "item": "wood", "amount": 10, "coins": 15},
	{"kind": "buy", "item": "copper", "amount": 5, "coins": 35},
	{"kind": "buy", "item": "iron", "amount": 5, "coins": 60},
	{"kind": "buy", "item": "berry", "amount": 3, "coins": 12},
	{"kind": "buy", "item": "potion_heal", "amount": 1, "coins": 25},
	{"kind": "buy", "item": "potion_speed", "amount": 1, "coins": 30},
	{"kind": "buy", "item": "wheat_seed", "amount": 2, "coins": 10},
	{"kind": "buy", "item": "carrot_seed", "amount": 2, "coins": 10},
	{"kind": "sell", "item": "stone", "amount": 10, "coins": 30},
]

const QUEST_BOARD_POS := Vector3(707, 0, -294)
const CAMPFIRE_POS := Vector3(11, 0, 11)
const FARM_PLOTS := [
	Vector3(20, 0, 20), Vector3(24, 0, 20),
	Vector3(20, 0, 24), Vector3(24, 0, 24),
]
const FARM_GROW_TIME := 25.0
const FARM_PEN_POS := Vector3(-24, 0, -14)
const FARM_CROPS := ["berry", "berry", "wheat", "carrot"]
const CROP_SEEDS := {"berry": "berry", "wheat": "wheat_seed", "carrot": "carrot_seed"}
const CROP_NAMES := {"berry": "berries", "wheat": "wheat", "carrot": "carrots"}
const CROP_COLORS := {
	"berry": Color(0.9, 0.22, 0.28),
	"wheat": Color(0.95, 0.82, 0.3),
	"carrot": Color(0.95, 0.48, 0.16),
}
const FISHING_POS := Vector3(-16, 0, 16)
const DIVE_SPOT := Vector3(400, 0, 200)
const DIVE_ORIGIN := Vector3(0, -12, 0)
const DIVE_ARRIVAL := Vector3(0, 1.2, 10)
const DIVE_EXIT_PAD := Vector3(0, 0, 18)
const FINAL_PORTAL_POS := Vector3(0, 0, -24)
const FINAL_ARENA_ORIGIN := Vector3(0, 110, 0)
const FINAL_ARRIVAL := Vector3(0, 1.2, 20)
const FINAL_EXIT_PAD := Vector3(0, 0, 26)
const SKY_PORTAL_POS := Vector3(22, 0, -18)
const SKY_ORIGIN := Vector3(0, 240, 0)
const SKY_ARRIVAL := Vector3(0, 1.2, 18)
const SKY_EXIT_PAD := Vector3(0, 0, 24)
const SKY_DRAGON_POS := Vector3(0, 0, -55)
const COOKING_RECIPES := [
	{"id": "cooked_meat", "name": "Cooked Meat", "need": "meat", "amount": 1,
		"desc": "Cooked meat: +70 food"},
	{"id": "berry_jam", "name": "Berry Jam", "need": "berry", "amount": 3,
		"desc": "Berry jam: +55 food and +10 health"},
	{"id": "cooked_fish", "name": "Cooked Fish", "need": "fish", "amount": 1,
		"desc": "Cooked fish: +65 food"},
	{"id": "bread", "name": "Bread", "need": "wheat", "amount": 3,
		"desc": "Bread: +80 food"},
	{"id": "carrot_soup", "name": "Carrot Soup", "need": "carrot", "amount": 3,
		"desc": "Carrot soup: +65 food and +10 health"},
]
const VILLAGE_QUESTS := [
	{"id": "village_fire", "name": "Stock the village fire",
		"item": "stone", "amount": 20, "coins": 80, "give": {"berry": 2}},
	{"id": "village_tools", "name": "Tools for the smith",
		"item": "iron", "amount": 5, "coins": 50, "give": {"potion_heal": 1}},
	{"id": "village_lamp", "name": "Wire for the lamp",
		"item": "copper", "amount": 3, "coins": 30, "give": {"potion_speed": 1}},
	{"id": "village_uranium", "name": "Strange green metal",
		"item": "uranium", "amount": 3, "coins": 150, "give": {"potion_heal": 2}},
	{"id": "village_feast", "name": "Meat for the feast",
		"item": "meat", "amount": 10, "coins": 100, "give": {"berry": 3}},
	{"id": "village_roof", "name": "Wood for the roof",
		"item": "wood", "amount": 10, "coins": 60, "give": {"potion_heal": 1}},
	{"id": "village_timber", "name": "Ancient timber",
		"item": "hardwood", "amount": 5, "coins": 200, "give": {"potion_speed": 2}},
]

const SAVE_PATH := "user://forge_save.json"
const TEST_SAVE_PATH := "user://forge_test_save.json"

const FORGE_POS := Vector3(0, 0, 0)
const START_POS := Vector3(0, 1.2, 40)
const SAFE_RADIUS := 30.0          ## monsters cannot enter this circle

# --- the cave ---------------------------------------------------------------
const CAVE_ENTRANCE := Vector3(120, 0, 130)
const CAVE_ORIGIN := Vector3(0, -60, 0)
const CAVE_RADIUS := 1150.0        ## as wide as the surface island
const CAVE_HEIGHT := 46.0
const CAVE_ARRIVAL := Vector3(120, 1.2, 130)
const CAVE_EXIT_PAD := Vector3(120, 0, 150)
# Kept for the old, unused cave builder below.
const CAVE_THUNDER_PORTAL := Vector3(0, 0, -18)
const CAVE_POISON_PORTAL := Vector3(16, 0, 0)

# The underground is one huge connected cave, cut into four pie slices.
const UNDERGROUND_BIOMES := [
	{"id": "normal", "name": "Normal Cave", "share": 40,
		"color": Color(0.28, 0.27, 0.25), "start": 0.0, "end": 144.0},
	{"id": "spiky", "name": "Spiky Cave", "share": 30,
		"color": Color(0.34, 0.23, 0.3), "start": 144.0, "end": 252.0},
	{"id": "ice", "name": "Ice Cave", "share": 15,
		"color": Color(0.2, 0.36, 0.54), "start": 252.0, "end": 306.0},
	{"id": "acid", "name": "Acid Cave", "share": 15,
		"color": Color(0.18, 0.36, 0.2), "start": 306.0, "end": 360.0},
]

## Where the Thunder Temple and the other underground landmarks sit.
const UNDERGROUND_BOUNDARY_DEGREES := [0.0, 144.0, 252.0, 306.0, 360.0]
const CAVE_FLAT_SPOTS := [
	Vector2(120, 130), Vector2(120, 150),
	Vector2(-700, 200), Vector2(100, -750), Vector2(650, -330),
	Vector2(-620, -340), Vector2(850, -450),
	Vector2(-100, -650), Vector2(-600, 100), Vector2(250, 450), Vector2(550, -230),
	Vector2(350, -950), Vector2(-500, -50), Vector2(950, -530), Vector2(300, 400),
]

const THUNDER_TEMPLE_POS := Vector3(-620, 0, -340)
const URANIUM_TEMPLE_POS := Vector3(850, 0, -450)
const SPIKY_CENTER := Vector3(-700, 0, 200)
const ICE_CENTER := Vector3(100, 0, -750)
const ACID_CENTER := Vector3(650, 0, -330)
const ACID_POOL_OFFSETS := [
	Vector3(-35, 0, -10), Vector3(25, 0, 20), Vector3(-5, 0, 45),
	Vector3(45, 0, -35), Vector3(-50, 0, 35),
]
const TREASURE_SPOTS := [
	{"id": "ice_vault", "pos": Vector3(350, 0, -950),
		"coins": 120, "items": {"potion_heal": 2, "potion_speed": 1}},
	{"id": "spiky_vault", "pos": Vector3(-500, 0, -50),
		"coins": 150, "items": {"potion_heal": 1, "iron": 5}},
	{"id": "acid_vault", "pos": Vector3(950, 0, -530),
		"coins": 180, "items": {"uranium": 6, "potion_heal": 2}},
	{"id": "normal_vault", "pos": Vector3(300, 0, 400),
		"coins": 200, "items": {"hardwood": 5, "potion_heal": 2}},
]

# --- the underground Thunder Temple ---------------------------------------
const THUNDER_ORIGIN := Vector3(0, -120, 0)
const THUNDER_RADIUS := 22.0
const THUNDER_HEIGHT := 13.0
const THUNDER_ARRIVAL := Vector3(0, 1.2, 12)
const THUNDER_EXIT_PAD := Vector3(0, 0, 17)

# --- the deep Poison Depths -----------------------------------------------
const POISON_ORIGIN := Vector3(0, -180, 0)
const POISON_RADIUS := 20.0
const POISON_HEIGHT := 12.0
const POISON_ARRIVAL := Vector3(0, 1.2, 10)
const POISON_EXIT_PAD := Vector3(0, 0, 15)
const POISON_POOL_OFFSETS := [
	Vector2(-8, -3), Vector2(7, 4), Vector2(-2, 9),
]

# --- day / night ------------------------------------------------------------
const DAY_LENGTH := 180.0          ## seconds for one full day + night
const NIGHT_EXTRA_MONSTERS := 3    ## per biome, on top of the normal ones
const DAY_SKY_TOP := Color(0.17, 0.33, 0.62)
const DAY_SKY_HORIZON := Color(0.72, 0.83, 0.92)
const NIGHT_SKY_TOP := Color(0.02, 0.03, 0.09)
const NIGHT_SKY_HORIZON := Color(0.07, 0.1, 0.2)
const SUNSET_SKY_TOP := Color(0.3, 0.18, 0.35)
const SUNSET_SKY_HORIZON := Color(0.95, 0.5, 0.3)

# ------------------------------------------------------------------ STATE ---
## 9 slots. Each slot is either null (empty) or {"item": "stone", "count": 12}.
var slots: Array = []
var coins := START_COINS
var health := MAX_HEALTH
var hunger := MAX_HUNGER
var hunger_warned := false
var pickaxe_name := "Wooden Pickaxe"
var sword_name := "Wooden Dagger"
var weapon_base_damage := 8.0
var mining_power := 1.0
var attack_power := 8.0
var crafted: Dictionary = {}
var infused: Dictionary = {}
var defeated_temples: Dictionary = {}
var quests_done: Dictionary = {}
var armour: Dictionary = {}        ## piece id -> {name, defense, color}

var player: CharacterBody3D
var hud
var bosses: Array = []
var chests: Array = []
var trader: Node3D = null
var wolf: Node3D = null
var wolf_tamed := false
var near_trader := false
var near_wolf := false
var near_tamed_wolf := false
var near_quest_board := false
var near_campfire := false
var near_farm_plot := -1
var near_fishing := false
var near_treasure := -1
var near_dive_spot := false
var near_dive_exit := false
var in_dive := false
var in_final := false
var breath := 100.0
var near_final_portal := false
var near_final_exit := false
var final_portal_light: OmniLight3D
var final_boss_node: Node3D = null
var final_boss_defeated := false
var ending_seen := false
var in_sky := false
var near_sky_portal := false
var near_sky_exit := false
var sky_portal_light: OmniLight3D
var sky_dragon: Node3D = null
var sky_dragon_defeated := false
var near_villager = null
var farm_state: Array = []
var farm_animals: Array = []
var near_farm_animal = null
var treasures: Array = []
var treasures_found: Dictionary = {}
var farm_plants: Array = []
var fishing_cooldown := 0.0
var villagers: Array = []
var near_chest := -1
var weapon_length := 1.0
var weapon_color := Color(0.85, 0.88, 0.96)
var game_ready := false
var recipes: Array = []
var near_forge := false
var near_cave_entrance := false
var near_cave_exit := false
var in_cave := false
var cave_bumps: Array = []
var in_thunder := false
var in_poison := false
var near_thunder_entrance := false
var near_thunder_exit := false
var near_poison_entrance := false
var near_poison_exit := false
var regen_delay := 0.0
var dot_time := 0.0
var dot_dps := 0.0
var dot_accum := 0.0

# time_of_day: 0.0 = midnight, 0.25 = sunrise, 0.5 = noon, 0.75 = sunset
var time_of_day := 0.34
var day_count := 1
var is_night := false
var night_monsters: Array = []
var sun: DirectionalLight3D
var world_env: WorldEnvironment
var sky_material: ProceduralSkyMaterial
var weather := "clear"
var weather_timer := 60.0
var weather_node: Node3D
var weather_particles: CPUParticles3D
var weather_darkness := 0.0
var music_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
var sfx_streams: Dictionary = {}
var sfx_index := 0


# ============================================================================
#  STARTUP
# ============================================================================
func _ready() -> void:
	randomize()
	_reset_slots()
	_setup_input()
	_build_recipes()
	_build_world()
	_spawn_player()
	_build_hud()
	_setup_day_night()
	_setup_weather()
	_setup_audio()

	if _is_test_run() or not load_game():
		add_item("wood", 6)   # enough to try a small wooden drawing right away
		add_item("berry", 2)
		add_item("potion_heal", 1)
		add_item("wheat_seed", 2)
		add_item("carrot_seed", 2)
		_log("Welcome! 1 = sword, 2 = pickaxe, 3 = shield. F eats, H heals, G gives speed.")
	else:
		_log("Welcome back! Your saved game is loaded.")
	game_ready = true


## If the game window loses focus (Alt+Tab, the Windows key, a popup...), give
## the mouse back. Then the cursor can never stay trapped inside the game.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()


## Keys are created in code so the Input Map stays empty and readable.
func _setup_input() -> void:
	var keys := {
		"move_forward": KEY_W,
		"move_back": KEY_S,
		"move_left": KEY_A,
		"move_right": KEY_D,
		"jump": KEY_SPACE,
		"sprint": KEY_SHIFT,
		"interact": KEY_E,
		"teleport": KEY_T,
		"eat": KEY_F,
		"heal": KEY_H,
		"speed_potion": KEY_G,
		"wolf_stay": KEY_K,
		"wolf_attack": KEY_L,
		"kick": KEY_V,
	}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var event := InputEventKey.new()
		event.physical_keycode = keys[action]
		InputMap.action_add_event(action, event)

	if not InputMap.has_action("use"):
		InputMap.add_action("use")
		var mouse := InputEventMouseButton.new()
		mouse.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("use", mouse)


func _build_recipes() -> void:
	recipes = [
		{"id": "stone_pickaxe", "name": "Stone Pickaxe", "cost": {"stone": 8},
			"desc": "Mine 2x faster"},
		{"id": "iron_pickaxe", "name": "Iron Pickaxe", "cost": {"iron": 8, "copper": 4},
			"desc": "Mine 3.5x faster"},
		{"id": "shield", "name": "Wooden Shield", "cost": {"stone": 12, "coins": 20},
			"desc": "Left hand: hold left click to block"},
	]

	# Weapons are priced by SIZE: the taller the weapon, the more metal it needs.
	# Same rule for every metal and every shape.
	for metal in WEAPON_METALS:
		for shape in WEAPON_SHAPES:
			var length: float = shape["length"]
			var damage := roundf(float(metal["base_damage"]) * float(shape["factor"]))
			var metal_cost := int(ceil(length * 5.0))
			var coin_cost := int(ceil(length * 8.0))
			recipes.append({
				"id": "weapon_%s_%s" % [String(metal["id"]), String(shape["id"])],
				"name": "%s %s" % [String(metal["name"]), String(shape["name"])],
				"cost": {metal["id"]: metal_cost, "coins": coin_cost},
				"desc": "%.2f m tall  ·  %d damage" % [length, int(damage)],
				"repeat": true,
				"weapon_name": "%s %s" % [String(metal["name"]), String(shape["name"])],
				"weapon_damage": damage,
				"weapon_swing": shape["swing"],
				"weapon_reach": shape["reach"],
				"weapon_length": length,
				"material": String(metal["id"]),
				"iron": String(metal["id"]) == "iron",
			})

	# One infusion recipe per temple: each magic stone makes the weapon stronger.
	for biome in WorldData.BIOMES:
		recipes.append({
			"id": "infuse_" + String(biome["id"]),
			"name": "Infuse: " + String(biome["element"]),
			"cost": {biome["stone"]: 1, "coins": INFUSE_COIN_COST},
			"desc": "+%d damage" % int(INFUSE_DAMAGE_BONUS),
			"needs": "iron_weapon",
			"stone_key": biome["stone"],
			"glow": biome["glow"],
		})

	# The underground Thunder Temple has its own stone.
	recipes.append({
		"id": "infuse_thunder",
		"name": "Infuse: Thunder",
		"cost": {WorldData.THUNDER["stone"]: 1, "coins": INFUSE_COIN_COST},
		"desc": "+%d damage · lightning chain" % int(INFUSE_DAMAGE_BONUS),
		"needs": "iron_weapon",
		"stone_key": WorldData.THUNDER["stone"],
		"glow": WorldData.THUNDER["glow"],
	})
	recipes.append({
		"id": "infuse_uranium",
		"name": "Infuse: Uranium",
		"cost": {WorldData.URANIUM["stone"]: 1, "coins": INFUSE_COIN_COST},
		"desc": "+%d damage · radiation" % int(INFUSE_DAMAGE_BONUS),
		"needs": "iron_weapon",
		"stone_key": WorldData.URANIUM["stone"],
		"glow": WorldData.URANIUM["glow"],
	})
	recipes.append({
		"id": "bow",
		"name": "Hunter's Bow",
		"cost": {"wood": 8, "iron": 4, "coins": 40},
		"desc": "Shoot arrows from far away",
	})

	recipes.append({
		"id": "sell_stone",
		"name": "Sell %d Stone" % SELL_STONE_AMOUNT,
		"cost": {"stone": SELL_STONE_AMOUNT},
		"desc": "Get %d coins" % SELL_STONE_PRICE,
		"repeat": true,
	})


func recipe_index(id: String) -> int:
	for i in recipes.size():
		if recipes[i]["id"] == id:
			return i
	return -1


# ============================================================================
#  WORLD
# ============================================================================
func _build_world() -> void:
	_add_sea()
	_add_island()
	_add_water()
	_add_biomes()
	_build_forge()
	_build_campfire()
	_build_farm()
	_build_farm_pen()
	_build_fishing()
	_build_final_portal()
	_build_final_arena()
	_build_sky_portal()
	_build_sky_islands()
	_build_safe_zone()
	_build_chests()
	_build_bridges()
	_build_cave_entrance()
	_build_cave()
	_build_dive()
	_build_temples()
	_build_village()
	_scatter_trees()
	_scatter_rocks()
	_scatter_grass()
	_spawn_ores()
	_spawn_wood()
	_spawn_enemies()
	_spawn_bosses()
	_spawn_animals()
	_build_trader()
	_spawn_wolf()


## The sea the island floats in (decoration only, no collision).
func _add_sea() -> void:
	var sea := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 420.0
	disc.bottom_radius = 420.0
	disc.height = 1.0
	disc.radial_segments = 96
	sea.mesh = disc
	sea.material_override = _material(Color(0.14, 0.33, 0.55))
	sea.position.y = -10.0
	add_child(sea)


## Water that fills the space between the biome islands.
func _add_water() -> void:
	var water := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = WorldData.WORLD_RADIUS - 0.5
	disc.bottom_radius = WorldData.WORLD_RADIUS - 0.5
	disc.height = 0.04
	disc.radial_segments = 96
	water.mesh = disc

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.18, 0.42, 0.68)
	mat.roughness = 0.45
	mat.metallic = 0.0
	mat.emission_enabled = true
	mat.emission = Color(0.04, 0.1, 0.22)
	mat.emission_energy_multiplier = 0.2
	water.material_override = mat
	water.position.y = -0.02
	water.name = "Water"
	add_child(water)


## The round island itself: one cylinder = one circle, nothing to fall off by
## accident (the player is also held inside by game._keep_player_on_island).
func _add_island() -> void:
	var body := StaticBody3D.new()
	body.name = "Island"
	add_child(body)

	var mesh := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = WorldData.WORLD_RADIUS
	disc.bottom_radius = WorldData.WORLD_RADIUS
	disc.height = 2.0
	disc.radial_segments = 96
	mesh.mesh = disc
	mesh.material_override = _material(Color(0.22, 0.47, 0.74))
	mesh.position.y = -1.0
	body.add_child(mesh)

	var shape := CollisionShape3D.new()
	shape.name = "IslandShape"
	var cylinder := CylinderShape3D.new()
	cylinder.radius = WorldData.WORLD_RADIUS
	cylinder.height = 2.0
	shape.shape = cylinder
	shape.position.y = -1.0
	body.add_child(shape)


func _add_biomes() -> void:
	for i in WorldData.BIOMES.size():
		var biome: Dictionary = WorldData.BIOMES[i]

		# A wobbly blob instead of a rectangle: the border is built from
		# random waves, so every biome has its own outline.
		var patch := MeshInstance3D.new()
		patch.mesh = _make_blob_mesh(biome)
		var mat := _material(biome["color"])
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		patch.material_override = mat
		patch.position = Vector3(biome["center"].x, 0.06 + i * 0.02, biome["center"].y)
		patch.name = "Biome_" + String(biome["name"])
		add_child(patch)

		var sign_label := Label3D.new()
		sign_label.text = biome["name"]
		sign_label.font_size = 13
		sign_label.outline_size = 3
		sign_label.fixed_size = true
		sign_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sign_label.modulate = Color(1, 1, 1, 0.85)
		sign_label.position = Vector3(biome["label"].x, 4.5, biome["label"].y)
		sign_label.visibility_range_end = 900.0
		sign_label.visibility_range_end_margin = 120.0
		sign_label.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		add_child(sign_label)


func _add_water_surface(biome: Dictionary) -> void:
	var water := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.98
	disc.bottom_radius = 0.98
	disc.height = 0.2
	disc.radial_segments = 48
	water.mesh = disc
	water.scale = Vector3(biome["size"].x, 1.0, biome["size"].y)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.55, 0.85, 0.72)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.4
	mat.metallic = 0.0
	mat.emission_enabled = true
	mat.emission = Color(0.08, 0.2, 0.38)
	mat.emission_energy_multiplier = 0.45
	water.material_override = mat
	water.position = Vector3(biome["center"].x, 0.18, biome["center"].y)
	add_child(water)
## Stone bridges over the water, from the Plains to each outer biome.
func _build_bridges() -> void:
	var plains: Dictionary = WorldData.BIOMES[0]
	for i in range(1, WorldData.BIOMES.size()):
		var biome: Dictionary = WorldData.BIOMES[i]
		var center: Vector2 = biome["center"]
		var direction := center.normalized()
		var angle := atan2(direction.y, direction.x)

		# Where each ellipse starts along that direction.
		var plains_edge := 1.0 / sqrt(
			pow(direction.x / plains["size"].x, 2) + pow(direction.y / plains["size"].y, 2)
		)
		var biome_edge: float = center.length() - 1.0 / sqrt(
			pow(direction.x / biome["size"].x, 2) + pow(direction.y / biome["size"].y, 2)
		)

		var bridge_start := plains_edge - 12.0
		var bridge_end := biome_edge + 12.0
		if bridge_end <= bridge_start:
			continue
		var length := bridge_end - bridge_start
		var middle_distance := (bridge_start + bridge_end) * 0.5

		var bridge := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(10.0, 0.16, length)
		bridge.mesh = box
		bridge.material_override = _material(Color(0.55, 0.52, 0.48))
		bridge.position = Vector3(direction.x * middle_distance, 0.02, direction.y * middle_distance)
		bridge.rotation.y = -angle + PI * 0.5
		add_child(bridge)

		# Low stone rails on both sides.
		for side in [-1.0, 1.0]:
			var rail := MeshInstance3D.new()
			var rail_box := BoxMesh.new()
			rail_box.size = Vector3(0.7, 0.8, length)
			rail.mesh = rail_box
			rail.material_override = _material(Color(0.45, 0.43, 0.4))
			var offset: Vector3 = Vector3(direction.y, 0.0, -direction.x) * side * 4.6
			rail.position = bridge.position + offset + Vector3(0, 0.45, 0)
			rail.rotation.y = -angle + PI * 0.5
			add_child(rail)
## Builds one flat polygon whose radius wobbles in a few random waves.
func _make_blob_mesh(biome: Dictionary) -> ArrayMesh:
	var points := biome_outline(biome)
	var center_x: float = biome["center"].x
	var center_z: float = biome["center"].y

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_normal(Vector3.UP)
	surface.add_vertex(Vector3.ZERO)

	for point in points:
		surface.set_normal(Vector3.UP)
		surface.add_vertex(Vector3(point.x - center_x, 0.0, point.y - center_z))

	var count := points.size()
	for i in count:
		var next := (i + 1) % count
		surface.add_index(0)
		surface.add_index(i + 1)
		surface.add_index(next + 1)

	return surface.commit()


## The same wobbly border in world coordinates. The minimap uses this too,
## so the map and the ground always have exactly the same shape.
func biome_outline(biome: Dictionary, segments := 72) -> PackedVector2Array:
	var points := PackedVector2Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(biome["id"]))
	var phase_a := rng.randf_range(0.0, TAU)
	var phase_b := rng.randf_range(0.0, TAU)
	var rx: float = biome["size"].x
	var rz: float = biome["size"].y
	var jitter: float = biome["jitter"]
	var center_x: float = biome["center"].x
	var center_z: float = biome["center"].y
	var coast := WorldData.WORLD_RADIUS - 1.0

	for i in segments:
		var angle := TAU * float(i) / float(segments)
		var wobble := 1.0 + jitter * (
			sin(angle * 3.0 + phase_a) * 0.6 + sin(angle * 7.0 + phase_b) * 0.4
		)
		wobble += rng.randf_range(-0.025, 0.025)

		# Position in world space, then pull it back to the coast if the biome
		# would spill into the sea.
		var world_x := center_x + cos(angle) * rx * wobble
		var world_z := center_z + sin(angle) * rz * wobble
		var distance := Vector2(world_x, world_z).length()
		if distance > coast:
			var pull := coast / distance
			world_x *= pull
			world_z *= pull
		points.append(Vector2(world_x, world_z))

	return points


func _build_forge() -> void:
	var forge := Node3D.new()
	forge.name = "Forge"
	forge.position = FORGE_POS
	add_child(forge)

	var floor_mesh := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 6.0
	disc.bottom_radius = 6.2
	disc.height = 0.08
	floor_mesh.mesh = disc
	floor_mesh.material_override = _material(Color(0.5, 0.48, 0.46))
	floor_mesh.position.y = 0.04
	forge.add_child(floor_mesh)

	for i in 6:
		var angle := TAU * float(i) / 6.0
		_add_pillar(forge, Vector3(cos(angle) * 5.0, 0, sin(angle) * 5.0), 0.4, 3.6, Color(0.42, 0.4, 0.38))

	var anvil := MeshInstance3D.new()
	var anvil_box := BoxMesh.new()
	anvil_box.size = Vector3(1.4, 0.5, 0.8)
	anvil.mesh = anvil_box
	anvil.material_override = _material(Color(0.22, 0.22, 0.24))
	anvil.position.y = 1.0
	forge.add_child(anvil)

	var base := MeshInstance3D.new()
	var base_box := BoxMesh.new()
	base_box.size = Vector3(0.7, 0.8, 0.7)
	base.mesh = base_box
	base.material_override = _material(Color(0.3, 0.28, 0.26))
	base.position.y = 0.4
	forge.add_child(base)

	var crystal := MeshInstance3D.new()
	crystal.mesh = Shapes.octahedron(0.5, 1.1)
	crystal.material_override = _glow_material(Color(1.0, 0.72, 0.25), 3.0)
	crystal.position.y = 2.6
	crystal.set_script(preload("res://scripts/spinner.gd"))
	forge.add_child(crystal)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.7, 0.35)
	light.light_energy = 4.0
	light.omni_range = 14.0
	light.position.y = 2.6
	forge.add_child(light)

	var beam := MeshInstance3D.new()
	beam.mesh = Shapes.cube(Vector3(0.22, 40.0, 0.22))
	beam.material_override = _glow_material(Color(1.0, 0.75, 0.3), 2.0)
	beam.position.y = 20.0
	forge.add_child(beam)

	_add_world_label("THE FORGE", FORGE_POS + Vector3(0, 5.5, 0), Color(1.0, 0.85, 0.45))


# ============================================================================
#  CHESTS (storage in the Forge)
# ============================================================================
func _build_chests() -> void:
	var spots := [Vector3(4.6, 0, 3.6), Vector3(-4.6, 0, 3.6)]
	for spot in spots:
		var chest := {"pos": spot, "slots": []}
		for i in SLOT_COUNT:
			chest["slots"].append(null)
		chests.append(chest)
		_build_chest_model(spot)


func _build_chest_model(pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = 0.3
	add_child(root)

	_add_box(root, Vector3(0, 0.35, 0), Vector3(1.3, 0.7, 0.9), Color(0.5, 0.33, 0.18))
	_add_box(root, Vector3(0, 0.8, 0), Vector3(1.34, 0.2, 0.94), Color(0.38, 0.24, 0.13))
	_add_box(root, Vector3(0, 0.62, 0.47), Vector3(0.18, 0.18, 0.08), Color(1.0, 0.82, 0.3))


func chest_count(chest_index: int, item: String) -> int:
	if chest_index < 0 or chest_index >= chests.size():
		return 0
	return _count_in(chests[chest_index]["slots"], item)


## Click in the chest screen: move one stack between the bag and a chest.
func move_chest_item(chest_index: int, slot_index: int, from_chest: bool) -> void:
	if chest_index < 0 or chest_index >= chests.size():
		return
	var chest_slots: Array = chests[chest_index]["slots"]

	if from_chest:
		var box_slot = chest_slots[slot_index]
		if box_slot == null:
			return
		var leftover := _add_to_slots(slots, String(box_slot["item"]), int(box_slot["count"]))
		if leftover <= 0:
			chest_slots[slot_index] = null
		else:
			box_slot["count"] = leftover
			_log("Your bag is full.")
	else:
		var bag_slot = slots[slot_index]
		if bag_slot == null:
			return
		var leftover := _add_to_slots(chest_slots, String(bag_slot["item"]), int(bag_slot["count"]))
		if leftover <= 0:
			slots[slot_index] = null
		else:
			bag_slot["count"] = leftover
			_log("That chest is full.")

	if hud != null:
		hud.refresh_chest()
		hud.refresh_inventory()


# ============================================================================
#  TEMPLES (one different style per biome)
# ============================================================================
# ============================================================================
#  SAFE ZONE (around the Forge)
# ============================================================================
func _build_campfire() -> void:
	var fire := Node3D.new()
	fire.position = CAMPFIRE_POS
	add_child(fire)

	for i in 8:
		var angle := TAU * float(i) / 8.0
		_add_box(
			fire,
			Vector3(cos(angle) * 1.3, 0.15, sin(angle) * 1.3),
			Vector3(0.55, 0.3, 0.55),
			Color(0.38, 0.36, 0.34)
		)

	for i in 3:
		var angle := TAU * float(i) / 3.0
		var log := _add_box(
			fire,
			Vector3(cos(angle) * 0.55, 0.28, sin(angle) * 0.55),
			Vector3(0.22, 0.22, 1.1),
			Color(0.42, 0.27, 0.14)
		)
		log.rotation.y = angle

	var flame := MeshInstance3D.new()
	flame.mesh = Shapes.pyramid(0.7, 1.2)
	flame.material_override = _glow_material(Color(1.0, 0.55, 0.15), 3.0)
	flame.position.y = 0.9
	flame.set_script(preload("res://scripts/spinner.gd"))
	fire.add_child(flame)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.55, 0.2)
	light.light_energy = 3.0
	light.omni_range = 12.0
	light.position.y = 1.5
	fire.add_child(light)
	_add_world_label("CAMPFIRE", CAMPFIRE_POS + Vector3(0, 3.0, 0), Color(1.0, 0.7, 0.35), 45.0)


func _build_farm() -> void:
	farm_state.clear()
	farm_plants.clear()
	for i in FARM_PLOTS.size():
		var pos: Vector3 = FARM_PLOTS[i]
		_add_box(
			self,
			pos + Vector3(0, 0.09, 0),
			Vector3(2.3, 0.18, 2.3),
			Color(0.38, 0.26, 0.15)
		)

		var plant := Node3D.new()
		plant.position = pos
		plant.visible = false
		add_child(plant)

		var stem := Shapes.cube_node(
			Vector3(0.5, 0.6, 0.5),
			Shapes.material(Color(0.28, 0.55, 0.25))
		)
		stem.position.y = 0.4
		plant.add_child(stem)
		var crop := String(FARM_CROPS[i])
		for j in 3:
			var berry := Shapes.cube_node(
				Vector3(0.16, 0.16, 0.16),
				Shapes.material(CROP_COLORS.get(crop, Color(0.9, 0.22, 0.28)))
			)
			berry.position = Vector3(
				cos(float(j) * TAU / 3.0) * 0.3, 0.75, sin(float(j) * TAU / 3.0) * 0.3
			)
			plant.add_child(berry)

		farm_plants.append(plant)
		farm_state.append({"state": "empty", "timer": 0.0})


func _build_farm_pen() -> void:
	var pen := Node3D.new()
	pen.name = "FarmPen"
	pen.position = FARM_PEN_POS
	add_child(pen)

	for x in [-6.0, 6.0]:
		for z in [-4.0, 4.0]:
			_add_box(pen, Vector3(x, 0.7, z), Vector3(0.22, 1.4, 0.22), Color(0.45, 0.3, 0.16))
	for x in [-3.0, 0.0, 3.0]:
		_add_box(pen, Vector3(x, 1.0, -4.0), Vector3(3.0, 0.12, 0.12), Color(0.5, 0.34, 0.18))
		_add_box(pen, Vector3(x, 1.0, 4.0), Vector3(3.0, 0.12, 0.12), Color(0.5, 0.34, 0.18))
	for z in [-2.0, 0.0, 2.0]:
		_add_box(pen, Vector3(-6.0, 1.0, z), Vector3(0.12, 0.12, 2.0), Color(0.5, 0.34, 0.18))
	_add_box(pen, Vector3(4.0, 1.5, -2.6), Vector3(3.8, 2.8, 2.6), Color(0.55, 0.38, 0.2))
	_add_box(pen, Vector3(4.0, 3.1, -2.6), Vector3(4.4, 0.3, 3.2), Color(0.35, 0.22, 0.13))
	_add_world_label("FARM", FARM_PEN_POS + Vector3(0, 3.8, 0), Color(0.9, 0.8, 0.5), 50.0)

	var animals := [
		["chicken", Vector3(-3, 0, -1)],
		["chicken", Vector3(-1, 0, 2)],
		["cow", Vector3(2, 0, 1)],
		["sheep", Vector3(4, 0, -1)],
	]
	for entry in animals:
		var animal = FARM_ANIMAL_SCRIPT.new()
		animal.game = self
		animal.kind = String(entry[0])
		animal.position = FARM_PEN_POS + (entry[1] as Vector3)
		add_child(animal)
		farm_animals.append(animal)


func _build_fishing() -> void:
	var pond := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 4.0
	disc.bottom_radius = 4.0
	disc.height = 0.08
	pond.mesh = disc
	pond.material_override = _glow_material(Color(0.25, 0.5, 0.75), 0.7)
	pond.position = FISHING_POS + Vector3(0, 0.06, 0)
	add_child(pond)

	for i in 3:
		_add_box(
			self,
			FISHING_POS + Vector3(-1.0 + float(i) * 1.0, 0.25, 3.8),
			Vector3(0.9, 0.18, 2.2),
			Color(0.42, 0.28, 0.15)
		)
	_add_world_label("FISHING", FISHING_POS + Vector3(0, 3.0, 0), Color(0.55, 0.8, 1.0), 45.0)


func _build_final_portal() -> void:
	var portal := Node3D.new()
	portal.name = "FinalPortal"
	portal.position = FINAL_PORTAL_POS
	add_child(portal)

	var disc := MeshInstance3D.new()
	var ring := CylinderMesh.new()
	ring.top_radius = 4.2
	ring.bottom_radius = 4.2
	ring.height = 0.12
	disc.mesh = ring
	disc.material_override = _material(Color(0.12, 0.1, 0.16))
	disc.position.y = 0.06
	portal.add_child(disc)

	for i in WorldData.STONE_KEYS.size():
		var angle := TAU * float(i) / float(WorldData.STONE_KEYS.size())
		var stone := MeshInstance3D.new()
		stone.mesh = Shapes.octahedron(0.32, 0.8)
		stone.material_override = _glow_material(item_color(String(WorldData.STONE_KEYS[i])), 2.0)
		stone.position = Vector3(cos(angle) * 3.2, 1.2, sin(angle) * 3.2)
		portal.add_child(stone)

	var core := MeshInstance3D.new()
	core.mesh = Shapes.octahedron(0.55, 1.5)
	core.material_override = _glow_material(Color(0.7, 0.8, 1.0), 2.2)
	core.position.y = 1.5
	portal.add_child(core)

	final_portal_light = OmniLight3D.new()
	final_portal_light.light_color = Color(0.6, 0.75, 1.0)
	final_portal_light.light_energy = 0.5
	final_portal_light.omni_range = 16.0
	final_portal_light.position.y = 2.0
	portal.add_child(final_portal_light)
	_add_world_label(
		"FINAL TRIAL",
		FINAL_PORTAL_POS + Vector3(0, 4.0, 0),
		Color(0.72, 0.82, 1.0), 60.0
	)


func _build_final_arena() -> void:
	var arena := Node3D.new()
	arena.name = "FinalArena"
	arena.position = FINAL_ARENA_ORIGIN
	add_child(arena)

	var floor_body := StaticBody3D.new()
	arena.add_child(floor_body)
	var floor_mesh := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 30.0
	disc.bottom_radius = 30.0
	disc.height = 2.0
	disc.radial_segments = 64
	floor_mesh.mesh = disc
	floor_mesh.material_override = _material(Color(0.22, 0.2, 0.26))
	floor_mesh.position.y = -1.0
	floor_body.add_child(floor_mesh)
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 30.0
	cylinder.height = 2.0
	shape.shape = cylinder
	shape.position.y = -1.0
	floor_body.add_child(shape)

	for i in 20:
		var angle := TAU * float(i) / 20.0
		var wall := StaticBody3D.new()
		wall.position = Vector3(cos(angle) * 30.0, 4.0, sin(angle) * 30.0)
		wall.rotation.y = -angle
		arena.add_child(wall)
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(1.0, 8.0, 9.6)
		mesh.mesh = box
		mesh.material_override = _material(Color(0.12, 0.1, 0.16))
		wall.add_child(mesh)
		var wall_shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = Vector3(1.0, 8.0, 9.6)
		wall_shape.shape = box_shape
		wall.add_child(wall_shape)

	for i in WorldData.STONE_KEYS.size():
		var angle := TAU * float(i) / float(WorldData.STONE_KEYS.size())
		var pillar := MeshInstance3D.new()
		pillar.mesh = Shapes.cube(Vector3(1.0, 9.0, 1.0))
		pillar.material_override = _material(Color(0.3, 0.28, 0.4))
		pillar.position = Vector3(cos(angle) * 22.0, 4.5, sin(angle) * 22.0)
		arena.add_child(pillar)
		var gem := MeshInstance3D.new()
		gem.mesh = Shapes.octahedron(0.5, 1.3)
		gem.material_override = _glow_material(item_color(String(WorldData.STONE_KEYS[i])), 2.5)
		gem.position = Vector3(cos(angle) * 22.0, 9.8, sin(angle) * 22.0)
		arena.add_child(gem)

	var light := OmniLight3D.new()
	light.light_color = Color(0.8, 0.7, 1.0)
	light.light_energy = 4.0
	light.omni_range = 60.0
	light.position.y = 12.0
	arena.add_child(light)

	var pad := MeshInstance3D.new()
	var pad_disc := CylinderMesh.new()
	pad_disc.top_radius = 2.4
	pad_disc.bottom_radius = 2.4
	pad_disc.height = 0.12
	pad.mesh = pad_disc
	pad.material_override = _glow_material(Color(1.0, 0.85, 0.4), 2.0)
	pad.position = FINAL_EXIT_PAD + Vector3(0, 0.07, 0)
	arena.add_child(pad)
	_add_world_label(
		"FINAL TRIAL",
		FINAL_ARENA_ORIGIN + FINAL_EXIT_PAD + Vector3(0, 4.0, 0),
		Color(0.75, 0.85, 1.0), 90.0
	)


func _build_sky_portal() -> void:
	var portal := Node3D.new()
	portal.name = "SkyPortal"
	portal.position = SKY_PORTAL_POS
	add_child(portal)

	var disc := MeshInstance3D.new()
	var ring := CylinderMesh.new()
	ring.top_radius = 3.4
	ring.bottom_radius = 3.4
	ring.height = 0.12
	disc.mesh = ring
	disc.material_override = _material(Color(0.12, 0.2, 0.3))
	disc.position.y = 0.06
	portal.add_child(disc)

	for i in 6:
		var angle := TAU * float(i) / 6.0
		var crystal := MeshInstance3D.new()
		crystal.mesh = Shapes.octahedron(0.3, 0.9)
		crystal.material_override = _glow_material(Color(0.45, 0.9, 1.0), 2.2)
		crystal.position = Vector3(cos(angle) * 2.6, 1.2, sin(angle) * 2.6)
		portal.add_child(crystal)

	sky_portal_light = OmniLight3D.new()
	sky_portal_light.light_color = Color(0.45, 0.9, 1.0)
	sky_portal_light.light_energy = 0.5
	sky_portal_light.omni_range = 15.0
	sky_portal_light.position.y = 2.0
	portal.add_child(sky_portal_light)
	_add_world_label(
		"DLC: SKY ISLANDS",
		SKY_PORTAL_POS + Vector3(0, 4.2, 0),
		Color(0.55, 0.9, 1.0), 60.0
	)


func _build_sky_islands() -> void:
	_sky_island(Vector3(0, 0, 0), 30.0, Color(0.55, 0.65, 0.75))
	_sky_island(Vector3(45, 0, 0), 16.0, Color(0.45, 0.55, 0.68))
	_sky_island(Vector3(-35, 0, -30), 14.0, Color(0.5, 0.58, 0.7))
	_sky_island(SKY_DRAGON_POS, 18.0, Color(0.4, 0.5, 0.64))

	_sky_bridge(Vector3(0, 0, 0), Vector3(45, 0, 0), 6.0)
	_sky_bridge(Vector3(0, 0, 0), Vector3(-35, 0, -30), 5.0)
	_sky_bridge(Vector3(0, 0, 0), SKY_DRAGON_POS, 5.0)

	# Sky crystals on the islands.
	var sky_ore_spots := [
		Vector3(38, 0, 5), Vector3(50, 0, -4), Vector3(42, 0, -8),
		Vector3(-30, 0, -24), Vector3(-40, 0, -32),
		Vector3(-8, 0, -50), Vector3(7, 0, -60), Vector3(0, 0, -48),
	]
	for spot in sky_ore_spots:
		var ore = ORE_SCENE.instantiate()
		ore.ore_type = "sky_crystal"
		ore.game = self
		ore.position = SKY_ORIGIN + (spot as Vector3)
		add_child(ore)

	# Cloud blocks and the Sky Temple.
	for i in 26:
		var cloud := MeshInstance3D.new()
		cloud.mesh = Shapes.cube(Vector3(
			randf_range(4.0, 12.0), randf_range(0.6, 1.8), randf_range(4.0, 12.0)
		))
		cloud.material_override = _material(Color(0.92, 0.96, 1.0))
		cloud.position = SKY_ORIGIN + Vector3(
			randf_range(-90, 90), randf_range(-8, 8), randf_range(-90, 90)
		)
		add_child(cloud)

	var temple_center: Vector3 = SKY_ORIGIN + SKY_DRAGON_POS
	for i in 8:
		var angle := TAU * float(i) / 8.0
		var pillar := MeshInstance3D.new()
		pillar.mesh = Shapes.cube(Vector3(1.0, 10.0, 1.0))
		pillar.material_override = _material(Color(0.35, 0.55, 0.75))
		pillar.position = temple_center + Vector3(cos(angle) * 10.0, 5.0, sin(angle) * 10.0)
		add_child(pillar)
		var gem := MeshInstance3D.new()
		gem.mesh = Shapes.octahedron(0.45, 1.2)
		gem.material_override = _glow_material(Color(0.5, 0.95, 1.0), 2.5)
		gem.position = temple_center + Vector3(cos(angle) * 10.0, 10.5, sin(angle) * 10.0)
		add_child(gem)
	_add_world_label("SKY TEMPLE", temple_center + Vector3(0, 6.0, 0), Color(0.6, 0.95, 1.0), 90.0)

	var pad := MeshInstance3D.new()
	var pad_disc := CylinderMesh.new()
	pad_disc.top_radius = 2.4
	pad_disc.bottom_radius = 2.4
	pad_disc.height = 0.12
	pad.mesh = pad_disc
	pad.material_override = _glow_material(Color(1.0, 0.85, 0.4), 2.0)
	pad.position = SKY_ORIGIN + SKY_EXIT_PAD + Vector3(0, 0.07, 0)
	add_child(pad)
	_add_world_label("SKY ISLANDS", SKY_ORIGIN + Vector3(0, 5.0, 12.0),
		Color(0.7, 0.9, 1.0), 100.0)

	var light := OmniLight3D.new()
	light.light_color = Color(0.7, 0.9, 1.0)
	light.light_energy = 3.0
	light.omni_range = 80.0
	light.position = SKY_ORIGIN + Vector3(0, 20, 0)
	add_child(light)


func _sky_island(center: Vector3, radius: float, color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = SKY_ORIGIN + center
	add_child(body)
	var mesh := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius * 0.9
	disc.height = 2.0
	disc.radial_segments = 48
	mesh.mesh = disc
	mesh.material_override = _material(color)
	mesh.position.y = -1.0
	body.add_child(mesh)
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = radius
	cylinder.height = 2.0
	shape.shape = cylinder
	shape.position.y = -1.0
	body.add_child(shape)


func _sky_bridge(from: Vector3, to: Vector3, width: float) -> void:
	var delta := to - from
	var middle := (from + to) * 0.5
	var length := Vector2(delta.x, delta.z).length()
	var body := StaticBody3D.new()
	body.position = SKY_ORIGIN + middle
	body.rotation.y = -atan2(delta.z, delta.x)
	add_child(body)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(length, 0.3, width)
	mesh.mesh = box
	mesh.material_override = _material(Color(0.3, 0.42, 0.55))
	mesh.position.y = 0.15
	body.add_child(mesh)
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(length, 0.3, width)
	shape.shape = box_shape
	shape.position.y = 0.15
	body.add_child(shape)


func _build_safe_zone() -> void:
	# A glowing ring on the ground marks the border of the safe circle.
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = SAFE_RADIUS - 0.35
	torus.outer_radius = SAFE_RADIUS + 0.35
	torus.rings = 96
	torus.ring_segments = 8
	ring.mesh = torus
	ring.material_override = _glow_material(Color(0.45, 0.9, 1.0), 1.4)
	ring.position.y = 0.12
	add_child(ring)


func in_safe_zone() -> bool:
	if player == null:
		return false
	return player.global_position.distance_to(FORGE_POS) < SAFE_RADIUS


## On the surface, anywhere that is not a biome island is water.
func is_in_water(pos: Vector3) -> bool:
	if in_dive:
		return true
	if in_cave or pos.y < -5.0:
		return false
	return not _is_land(Vector2(pos.x, pos.z))


# ============================================================================
#  THE CAVE
# ============================================================================
func _build_cave_entrance() -> void:
	var root := Node3D.new()
	root.name = "CaveEntrance"
	root.position = CAVE_ENTRANCE
	# Turn the doorway so it looks towards the Forge.
	root.rotation.y = atan2(CAVE_ENTRANCE.x, CAVE_ENTRANCE.z)
	add_child(root)

	# The dark hole in the ground.
	var hole := MeshInstance3D.new()
	var hole_disc := CylinderMesh.new()
	hole_disc.top_radius = 3.0
	hole_disc.bottom_radius = 3.0
	hole_disc.height = 0.12
	hole_disc.radial_segments = 32
	hole.mesh = hole_disc
	var hole_mat := StandardMaterial3D.new()
	hole_mat.albedo_color = Color(0.02, 0.02, 0.03)
	hole_mat.roughness = 1.0
	hole.material_override = hole_mat
	hole.position.y = 0.07
	root.add_child(hole)

	# Stone doorway.
	_add_box(root, Vector3(-3.4, 2.4, 0), Vector3(2.0, 4.8, 2.0), Color(0.42, 0.41, 0.4))
	_add_box(root, Vector3(3.4, 2.4, 0), Vector3(2.0, 4.8, 2.0), Color(0.42, 0.41, 0.4))
	_add_box(root, Vector3(0, 5.2, 0), Vector3(8.8, 1.4, 2.2), Color(0.37, 0.36, 0.35))

	# A few rocks around it.
	for i in 7:
		var angle := TAU * float(i) / 7.0
		var rock := MeshInstance3D.new()
		rock.mesh = Shapes.cube(Vector3(1.3, 1.1, 1.3))
		rock.material_override = _material(Color(0.4, 0.39, 0.38))
		rock.position = Vector3(cos(angle) * 5.0, 0.3, sin(angle) * 5.0)
		rock.rotation.y = angle
		root.add_child(rock)

	_add_world_label("CAVE", CAVE_ENTRANCE + Vector3(0, 7.2, 0), Color(0.75, 0.82, 0.95), 400.0)


## The underground floor rolls up and down with extra little bumps, but stays
## flat where important things stand (entrance, temples, vaults, landmarks).
func _cave_floor_height(x: float, z: float) -> float:
	var height := sin(x * 0.006) * 2.0 + cos(z * 0.007) * 1.8 \
		+ sin((x + z) * 0.0035) * 1.4
	# Smaller rolling bumps on top of the big hills.
	height += sin(x * 0.021 + z * 0.017) * 0.9
	height += sin(x * 0.047 - z * 0.039) * 0.55
	height += cos(x * 0.091 + z * 0.073) * 0.3
	height += _cave_bump_height(x, z)
	for spot in CAVE_FLAT_SPOTS:
		var distance := Vector2(x, z).distance_to(spot)
		height *= smoothstep(30.0, 90.0, distance)
	return height


## How tall the extra rounded bumps are at this spot.
func _cave_bump_height(x: float, z: float) -> float:
	_ensure_cave_bumps()
	var extra := 0.0
	for bump in cave_bumps:
		var dx := x - float(bump["x"])
		var dz := z - float(bump["z"])
		var radius := float(bump["radius"])
		var distance := sqrt(dx * dx + dz * dz)
		if distance >= radius:
			continue
		var t := 1.0 - distance / radius
		extra += float(bump["height"]) * t * t * (3.0 - 2.0 * t)
	return extra


## Make a fixed list of little rounded bumps. Same seed = same cave every time.
func _ensure_cave_bumps() -> void:
	if not cave_bumps.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	var tries := 0
	while cave_bumps.size() < 26 and tries < 300:
		tries += 1
		var angle := rng.randf_range(0.0, TAU)
		var distance := rng.randf_range(180.0, CAVE_RADIUS - 120.0)
		var bx := cos(angle) * distance
		var bz := sin(angle) * distance
		var too_close := false
		for spot in CAVE_FLAT_SPOTS:
			if Vector2(bx, bz).distance_to(spot) < 110.0:
				too_close = true
				break
		if too_close:
			continue
		for other in cave_bumps:
			if Vector2(bx, bz).distance_to(
					Vector2(float(other["x"]), float(other["z"]))) < 90.0:
				too_close = true
				break
		if too_close:
			continue
		cave_bumps.append({
			"x": bx,
			"z": bz,
			"radius": rng.randf_range(45.0, 80.0),
			"height": rng.randf_range(1.2, 2.8),
		})


## The border between two underground biomes wiggles as it goes outward.
func _boundary_offset(boundary_index: int, radius: float) -> float:
	var phases := [0.3, 1.8, 3.2, 4.7, 0.3]
	var idx := boundary_index
	if idx >= 4:
		idx = 0
	var r := clampf(radius / CAVE_RADIUS, 0.0, 1.0)
	var fade := smoothstep(0.0, 0.1, r)
	return (sin(r * 5.2 + phases[idx]) * 7.0 + sin(r * 13.0 + phases[idx] * 2.0) * 3.0) * fade


## Which of the four underground pie slices contains this world position?
func underground_biome_at(pos: Vector3) -> String:
	var flat := Vector2(pos.x - CAVE_ORIGIN.x, pos.z - CAVE_ORIGIN.z)
	var radius := flat.length()
	var degrees := fposmod(rad_to_deg(atan2(flat.y, flat.x)), 360.0)
	var b0 := 0.0 + _boundary_offset(0, radius)
	var b1 := 144.0 + _boundary_offset(1, radius)
	var b2 := 252.0 + _boundary_offset(2, radius)
	var b3 := 306.0 + _boundary_offset(3, radius)
	var relative := fposmod(degrees - b0, 360.0)
	if relative < b1 - b0:
		return "normal"
	if relative < b2 - b0:
		return "spiky"
	if relative < b3 - b0:
		return "ice"
	return "acid"


func underground_biome_name(biome_id: String) -> String:
	for biome in UNDERGROUND_BIOMES:
		if String(biome["id"]) == biome_id:
			return String(biome["name"])
	return biome_id.capitalize()


## Builds the huge connected underground: four pie-slice biomes, no teleports.
func _build_cave() -> void:
	var cave := Node3D.new()
	cave.name = "Underground"
	cave.position = CAVE_ORIGIN
	add_child(cave)

	# A rolling, bumpy cave floor with real collision.
	_build_cave_terrain(cave)

	# Coloured pie slices: Normal 40%, Spiky 30%, Ice 15%, Acid 15%.
	for biome in UNDERGROUND_BIOMES:
		_add_underground_sector(cave, biome)

	# A dark roof so the sky does not shine on the underground.
	var ceiling := MeshInstance3D.new()
	var ceil_disc := CylinderMesh.new()
	ceil_disc.top_radius = CAVE_RADIUS
	ceil_disc.bottom_radius = CAVE_RADIUS
	ceil_disc.height = 1.0
	ceil_disc.radial_segments = 96
	ceiling.mesh = ceil_disc
	ceiling.material_override = _material(Color(0.05, 0.05, 0.07))
	ceiling.position.y = CAVE_HEIGHT
	cave.add_child(ceiling)

	# Boundary wall, in big blocks.
	for i in 64:
		var angle := TAU * float(i) / 64.0
		var wall := StaticBody3D.new()
		wall.position = Vector3(cos(angle) * CAVE_RADIUS, CAVE_HEIGHT * 0.5, sin(angle) * CAVE_RADIUS)
		wall.rotation.y = -angle
		cave.add_child(wall)

		var wall_mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(1.4, CAVE_HEIGHT, 114.0)
		wall_mesh.mesh = box
		wall_mesh.material_override = _material(Color(0.12, 0.12, 0.14))
		wall.add_child(wall_mesh)

		var wall_shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = Vector3(1.4, CAVE_HEIGHT, 114.0)
		wall_shape.shape = box_shape
		wall.add_child(wall_shape)

	_build_underground_normal(cave)
	_build_underground_spiky(cave)
	_build_underground_ice(cave)
	_build_underground_acid(cave)
	_build_underground_landmarks(cave)
	_build_underground_treasures(cave)
	_scatter_cave_formations(cave)
	_scatter_cave_variety(cave)

	# The way back up, right where you climb down.
	var pad := MeshInstance3D.new()
	var pad_disc := CylinderMesh.new()
	pad_disc.top_radius = 2.4
	pad_disc.bottom_radius = 2.4
	pad_disc.height = 0.12
	pad.mesh = pad_disc
	pad.material_override = _glow_material(Color(1.0, 0.85, 0.4), 2.2)
	var exit_h := _cave_floor_height(CAVE_EXIT_PAD.x, CAVE_EXIT_PAD.z)
	pad.position = Vector3(CAVE_EXIT_PAD.x, exit_h + 0.07, CAVE_EXIT_PAD.z)
	cave.add_child(pad)

	var pad_light := OmniLight3D.new()
	pad_light.light_color = Color(1.0, 0.85, 0.4)
	pad_light.light_energy = 3.0
	pad_light.omni_range = 12.0
	pad_light.position = Vector3(CAVE_EXIT_PAD.x, exit_h + 1.5, CAVE_EXIT_PAD.z)
	cave.add_child(pad_light)
	_add_world_label(
		"EXIT",
		CAVE_ORIGIN + Vector3(CAVE_EXIT_PAD.x, exit_h + 3.2, CAVE_EXIT_PAD.z),
		Color(1.0, 0.85, 0.4), 40.0
	)
	var arrival_h := _cave_floor_height(CAVE_ARRIVAL.x, CAVE_ARRIVAL.z)
	_add_world_label(
		"NORMAL CAVE",
		CAVE_ORIGIN + Vector3(CAVE_ARRIVAL.x, arrival_h + 4.2, CAVE_ARRIVAL.z),
		Color(0.8, 0.85, 0.95), 40.0
	)


func _add_underground_light(cave: Node3D, pos: Vector3, color: Color, reach: float) -> void:
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 2.2
	light.omni_range = reach
	light.position = pos
	cave.add_child(light)


func _build_cave_terrain(cave: Node3D) -> void:
	var steps := 128
	var step := (2.0 * CAVE_RADIUS) / float(steps)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in steps:
		for j in steps:
			var x0 := -CAVE_RADIUS + float(i) * step
			var x1 := x0 + step
			var z0 := -CAVE_RADIUS + float(j) * step
			var z1 := z0 + step
			var p00 := Vector3(x0, _cave_floor_height(x0, z0), z0)
			var p01 := Vector3(x0, _cave_floor_height(x0, z1), z1)
			var p10 := Vector3(x1, _cave_floor_height(x1, z0), z0)
			var p11 := Vector3(x1, _cave_floor_height(x1, z1), z1)
			_plane_triangle(st, p00, p11, p10)
			_plane_triangle(st, p00, p01, p11)
	st.generate_normals()
	var mesh := st.commit()

	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	var terrain_mat := _material(Color(0.18, 0.17, 0.16))
	terrain_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	visual.material_override = terrain_mat
	# Sits just under the coloured cave floor so only tiny cracks show it.
	visual.position.y = -0.35
	cave.add_child(visual)

	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var terrain_shape := mesh.create_trimesh_shape() as ConcavePolygonShape3D
	terrain_shape.backface_collision = true
	collision.shape = terrain_shape
	body.add_child(collision)
	cave.add_child(body)


func _add_underground_sector(cave: Node3D, biome: Dictionary) -> void:
	var start_base := float(biome["start"])
	var end_base := float(biome["end"])
	var start_idx: int = UNDERGROUND_BOUNDARY_DEGREES.find(start_base)
	var end_idx: int = start_idx + 1
	var rings := 64
	var segments := 64
	var points: Array = []

	for j in rings + 1:
		var radius := CAVE_RADIUS * float(j) / float(rings)
		var start_angle: float = start_base + _boundary_offset(start_idx, radius)
		var end_angle: float = end_base + _boundary_offset(end_idx, radius)
		var ring_points: Array = []
		for k in segments + 1:
			var angle := deg_to_rad(start_angle + (end_angle - start_angle) * float(k) / float(segments))
			var px := cos(angle) * radius
			var pz := sin(angle) * radius
			ring_points.append(Vector3(px, _cave_floor_height(px, pz), pz))
		points.append(ring_points)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center_point := Vector3(0.0, _cave_floor_height(0.0, 0.0), 0.0)
	for j in rings:
		for k in segments:
			var p00: Vector3 = points[j][k]
			var p01: Vector3 = points[j][k + 1]
			var p10: Vector3 = points[j + 1][k]
			var p11: Vector3 = points[j + 1][k + 1]
			if j == 0:
				_plane_triangle(st, center_point, p11, p10)
			else:
				_plane_triangle(st, p00, p11, p10)
				_plane_triangle(st, p00, p01, p11)

	st.generate_normals()
	var sector := MeshInstance3D.new()
	sector.mesh = st.commit()
	var mat := _material(biome["color"])
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	sector.material_override = mat
	sector.position.y = 0.04
	cave.add_child(sector)


func _plane_triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.set_normal(Vector3.UP); st.add_vertex(a)
	st.set_normal(Vector3.UP); st.add_vertex(b)
	st.set_normal(Vector3.UP); st.add_vertex(c)


func _build_underground_normal(cave: Node3D) -> void:
	_add_underground_light(cave, Vector3(350, 22, 350), Color(0.8, 0.78, 0.7), 420.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 811
	for i in 18:
		var angle := rng.randf_range(deg_to_rad(5.0), deg_to_rad(140.0))
		var distance := rng.randf_range(120.0, 1000.0)
		var ore_type := "stone"
		if i % 3 == 1:
			ore_type = "copper"
		elif i % 3 == 2:
			ore_type = "iron"
		var ox := cos(angle) * distance
		var oz := sin(angle) * distance
		var ore = ORE_SCENE.instantiate()
		ore.ore_type = ore_type
		ore.game = self
		ore.position = Vector3(ox, _cave_floor_height(ox, oz), oz)
		ore.rotation.y = rng.randf_range(0.0, TAU)
		cave.add_child(ore)

	for i in 4:
		var monster = ENEMY_SCENE.instantiate()
		monster.game = self
		monster.form = "rock" if i % 2 == 0 else "mushroom"
		monster.body_color = Color(0.35, 0.3, 0.34)
		monster.max_hp = 45.0
		monster.coin_reward = 18
		var angle := rng.randf_range(deg_to_rad(15.0), deg_to_rad(125.0))
		var distance := rng.randf_range(150.0, 800.0)
		monster.home_center = Vector2(CAVE_ORIGIN.x + 350.0, CAVE_ORIGIN.z + 350.0)
		monster.home_size = Vector2(620.0, 620.0)
		monster.has_home = true
		var mx := cos(angle) * distance
		var mz := sin(angle) * distance
		monster.position = CAVE_ORIGIN + Vector3(
			mx, _cave_floor_height(mx, mz) + 1.0, mz
		)
		add_child(monster)


func _build_underground_spiky(cave: Node3D) -> void:
	_add_underground_light(cave, SPIKY_CENTER + Vector3(0, 22, 0), Color(0.8, 0.5, 0.75), 420.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 812
	for i in 36:
		var angle := rng.randf_range(deg_to_rad(150.0), deg_to_rad(248.0))
		var distance := rng.randf_range(150.0, 1000.0)
		var spike := MeshInstance3D.new()
		spike.mesh = Shapes.pyramid(rng.randf_range(2.0, 5.0), rng.randf_range(4.0, 10.0))
		spike.material_override = _material(Color(0.33, 0.23, 0.3))
		var sx := cos(angle) * distance
		var sz := sin(angle) * distance
		spike.position = Vector3(sx, _cave_floor_height(sx, sz), sz)
		cave.add_child(spike)

	for i in 5:
		var monster = ENEMY_SCENE.instantiate()
		monster.game = self
		monster.form = "spike"
		monster.body_color = Color(0.44, 0.25, 0.36)
		monster.max_hp = 55.0
		monster.coin_reward = 22
		monster.home_center = Vector2(CAVE_ORIGIN.x + SPIKY_CENTER.x, CAVE_ORIGIN.z + SPIKY_CENTER.z)
		monster.home_size = Vector2(420.0, 420.0)
		monster.has_home = true
		var mx := SPIKY_CENTER.x + rng.randf_range(-160.0, 160.0)
		var mz := SPIKY_CENTER.z + rng.randf_range(-160.0, 160.0)
		monster.position = CAVE_ORIGIN + Vector3(
			mx, _cave_floor_height(mx, mz) + 1.0, mz
		)
		add_child(monster)

	# The Thunder Temple: an open arena you can walk to.
	var temple_h := _cave_floor_height(THUNDER_TEMPLE_POS.x, THUNDER_TEMPLE_POS.z)
	var temple := Node3D.new()
	temple.position = Vector3(THUNDER_TEMPLE_POS.x, temple_h, THUNDER_TEMPLE_POS.z)
	cave.add_child(temple)
	var temple_floor := MeshInstance3D.new()
	var temple_disc := CylinderMesh.new()
	temple_disc.top_radius = 14.0
	temple_disc.bottom_radius = 14.2
	temple_disc.height = 0.08
	temple_floor.mesh = temple_disc
	temple_floor.material_override = _material(Color(0.18, 0.23, 0.36))
	temple_floor.position.y = 0.06
	temple.add_child(temple_floor)
	for i in 6:
		var angle := TAU * float(i) / 6.0
		_add_box(
			temple,
			Vector3(cos(angle) * 10.0, 4.0, sin(angle) * 10.0),
			Vector3(0.8, 8.0, 0.8),
			Color(0.27, 0.33, 0.5)
		)
		var crystal := MeshInstance3D.new()
		crystal.mesh = Shapes.octahedron(0.5, 1.3)
		crystal.material_override = _glow_material(WorldData.THUNDER["glow"], 2.8)
		crystal.position = Vector3(cos(angle) * 10.0, 8.6, sin(angle) * 10.0)
		temple.add_child(crystal)
	var temple_light := OmniLight3D.new()
	temple_light.light_color = WorldData.THUNDER["glow"]
	temple_light.light_energy = 4.0
	temple_light.omni_range = 30.0
	temple_light.position.y = 6.0
	temple.add_child(temple_light)
	_add_world_label(
		"THUNDER TEMPLE",
		CAVE_ORIGIN + THUNDER_TEMPLE_POS + Vector3(0, 5.0, 0),
		WorldData.THUNDER["glow"], 120.0
	)

	var data: Dictionary = WorldData.THUNDER["boss"]
	var boss = BOSS_SCENE.instantiate()
	boss.boss_name = String(data["name"])
	boss.max_hp = float(data["hp"])
	boss.move_speed = float(data["speed"])
	boss.touch_damage = float(data["damage"])
	boss.coin_reward = int(data["coins"])
	boss.ability = String(data["ability"])
	boss.body_color = data["color"]
	boss.eye_color = data["eye"]
	boss.stone_key = String(WorldData.THUNDER["stone"])
	boss.stone_name = String(WorldData.THUNDER["stone_name"])
	boss.biome_id = "thunder"
	boss.game = self
	boss.home = CAVE_ORIGIN + Vector3(
		THUNDER_TEMPLE_POS.x, temple_h, THUNDER_TEMPLE_POS.z
	)
	boss.arena_radius = 10.0
	boss.scale = Vector3.ONE * float(data["scale"])
	boss.position = boss.home + Vector3(0, 1.0, 0)
	add_child(boss)
	bosses.append(boss)


func _build_underground_ice(cave: Node3D) -> void:
	_add_underground_light(cave, ICE_CENTER + Vector3(0, 22, 0), Color(0.55, 0.8, 1.0), 420.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 813
	for i in 22:
		var angle := rng.randf_range(deg_to_rad(255.0), deg_to_rad(303.0))
		var distance := rng.randf_range(150.0, 1000.0)
		var crystal := MeshInstance3D.new()
		crystal.mesh = Shapes.octahedron(rng.randf_range(0.6, 2.2), rng.randf_range(2.0, 6.0))
		crystal.material_override = _glow_material(Color(0.55, 0.85, 1.0), 1.8)
		var cx := cos(angle) * distance
		var cz := sin(angle) * distance
		crystal.position = Vector3(cx, _cave_floor_height(cx, cz), cz)
		cave.add_child(crystal)

	for i in 4:
		var monster = ENEMY_SCENE.instantiate()
		monster.game = self
		monster.form = "crystal"
		monster.body_color = Color(0.45, 0.68, 0.85)
		monster.max_hp = 50.0
		monster.coin_reward = 20
		monster.home_center = Vector2(CAVE_ORIGIN.x + ICE_CENTER.x, CAVE_ORIGIN.z + ICE_CENTER.z)
		monster.home_size = Vector2(320.0, 320.0)
		monster.has_home = true
		var mx := ICE_CENTER.x + rng.randf_range(-120.0, 120.0)
		var mz := ICE_CENTER.z + rng.randf_range(-120.0, 120.0)
		monster.position = CAVE_ORIGIN + Vector3(
			mx, _cave_floor_height(mx, mz) + 1.0, mz
		)
		add_child(monster)


func _build_underground_acid(cave: Node3D) -> void:
	_add_underground_light(cave, ACID_CENTER + Vector3(0, 22, 0), Color(0.55, 1.0, 0.4), 420.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 814
	for i in 5:
		var offset: Vector3 = ACID_POOL_OFFSETS[i]
		var pool := MeshInstance3D.new()
		var pool_disc := CylinderMesh.new()
		pool_disc.top_radius = 3.8
		pool_disc.bottom_radius = 3.8
		pool_disc.height = 0.08
		pool.mesh = pool_disc
		pool.material_override = _glow_material(Color(0.4, 1.0, 0.3), 2.0)
		var px := ACID_CENTER.x + offset.x
		var pz := ACID_CENTER.z + offset.z
		pool.position = Vector3(px, _cave_floor_height(px, pz) + 0.06, pz)
		cave.add_child(pool)

	for i in 10:
		var angle := rng.randf_range(deg_to_rad(310.0), deg_to_rad(358.0))
		var distance := rng.randf_range(150.0, 950.0)
		var mushroom := MeshInstance3D.new()
		mushroom.mesh = Shapes.pyramid(rng.randf_range(2.0, 4.5), rng.randf_range(1.5, 3.5))
		mushroom.material_override = _glow_material(Color(0.5, 1.0, 0.35), 1.6)
		var mx := cos(angle) * distance
		var mz := sin(angle) * distance
		mushroom.position = Vector3(mx, _cave_floor_height(mx, mz) + 0.4, mz)
		cave.add_child(mushroom)

	# Uranium lives only in the acid cave.
	for i in 6:
		var angle := rng.randf_range(deg_to_rad(312.0), deg_to_rad(356.0))
		var distance := rng.randf_range(250.0, 900.0)
		var ore = ORE_SCENE.instantiate()
		ore.ore_type = "uranium"
		ore.game = self
		var ox := cos(angle) * distance
		var oz := sin(angle) * distance
		ore.position = Vector3(ox, _cave_floor_height(ox, oz), oz)
		ore.rotation.y = rng.randf_range(0.0, TAU)
		cave.add_child(ore)

	for i in 5:
		var monster = ENEMY_SCENE.instantiate()
		monster.game = self
		monster.form = "mushroom"
		monster.body_color = Color(0.38, 0.62, 0.3)
		monster.max_hp = 55.0
		monster.coin_reward = 22
		monster.poison_touch = true
		monster.home_center = Vector2(CAVE_ORIGIN.x + ACID_CENTER.x, CAVE_ORIGIN.z + ACID_CENTER.z)
		monster.home_size = Vector2(360.0, 360.0)
		monster.has_home = true
		var mx := ACID_CENTER.x + rng.randf_range(-140.0, 140.0)
		var mz := ACID_CENTER.z + rng.randf_range(-140.0, 140.0)
		monster.position = CAVE_ORIGIN + Vector3(
			mx, _cave_floor_height(mx, mz) + 1.0, mz
		)
		add_child(monster)

	# The hidden Uranium Temple, deep in the Acid Cave.
	var temple_h := _cave_floor_height(URANIUM_TEMPLE_POS.x, URANIUM_TEMPLE_POS.z)
	var temple := Node3D.new()
	temple.position = Vector3(URANIUM_TEMPLE_POS.x, temple_h, URANIUM_TEMPLE_POS.z)
	cave.add_child(temple)
	var temple_floor := MeshInstance3D.new()
	var temple_disc := CylinderMesh.new()
	temple_disc.top_radius = 12.0
	temple_disc.bottom_radius = 12.2
	temple_disc.height = 0.08
	temple_floor.mesh = temple_disc
	temple_floor.material_override = _material(Color(0.17, 0.3, 0.15))
	temple_floor.position.y = 0.06
	temple.add_child(temple_floor)
	for i in 6:
		var angle := TAU * float(i) / 6.0
		_add_box(
			temple,
			Vector3(cos(angle) * 8.5, 3.5, sin(angle) * 8.5),
			Vector3(0.7, 7.0, 0.7),
			Color(0.25, 0.42, 0.2)
		)
		var crystal := MeshInstance3D.new()
		crystal.mesh = Shapes.octahedron(0.45, 1.2)
		crystal.material_override = _glow_material(WorldData.URANIUM["glow"], 2.8)
		crystal.position = Vector3(cos(angle) * 8.5, 7.8, sin(angle) * 8.5)
		temple.add_child(crystal)
	var temple_light := OmniLight3D.new()
	temple_light.light_color = WorldData.URANIUM["glow"]
	temple_light.light_energy = 3.6
	temple_light.omni_range = 26.0
	temple_light.position.y = 5.0
	temple.add_child(temple_light)
	_add_world_label(
		"URANIUM TEMPLE",
		CAVE_ORIGIN + URANIUM_TEMPLE_POS + Vector3(0, 4.5, 0),
		WorldData.URANIUM["glow"], 110.0
	)

	var uranium_data: Dictionary = WorldData.URANIUM["boss"]
	var golem = BOSS_SCENE.instantiate()
	golem.boss_name = String(uranium_data["name"])
	golem.max_hp = float(uranium_data["hp"])
	golem.move_speed = float(uranium_data["speed"])
	golem.touch_damage = float(uranium_data["damage"])
	golem.coin_reward = int(uranium_data["coins"])
	golem.ability = String(uranium_data["ability"])
	golem.body_color = uranium_data["color"]
	golem.eye_color = uranium_data["eye"]
	golem.stone_key = String(WorldData.URANIUM["stone"])
	golem.stone_name = String(WorldData.URANIUM["stone_name"])
	golem.biome_id = "uranium"
	golem.game = self
	golem.home = CAVE_ORIGIN + Vector3(
		URANIUM_TEMPLE_POS.x, temple_h, URANIUM_TEMPLE_POS.z
	)
	golem.arena_radius = 9.0
	golem.scale = Vector3.ONE * float(uranium_data["scale"])
	golem.position = golem.home + Vector3(0, 1.0, 0)
	add_child(golem)
	bosses.append(golem)


func _build_underground_landmarks(cave: Node3D) -> void:
	# A crystal lake in the Ice Cave.
	var lake := Node3D.new()
	lake.name = "CrystalLake"
	var lake_x := ICE_CENTER.x - 200.0
	var lake_z := ICE_CENTER.z + 100.0
	lake.position = Vector3(lake_x, _cave_floor_height(lake_x, lake_z), lake_z)
	lake.add_to_group("underground_landmark")
	cave.add_child(lake)
	var lake_mesh := MeshInstance3D.new()
	var lake_disc := CylinderMesh.new()
	lake_disc.top_radius = 11.0
	lake_disc.bottom_radius = 11.0
	lake_disc.height = 0.08
	lake_mesh.mesh = lake_disc
	lake_mesh.material_override = _glow_material(Color(0.35, 0.7, 1.0), 1.2)
	lake_mesh.position.y = 0.08
	lake.add_child(lake_mesh)
	for i in 6:
		var angle := TAU * float(i) / 6.0
		var cryst := MeshInstance3D.new()
		cryst.mesh = Shapes.octahedron(0.5, 1.5)
		cryst.material_override = _glow_material(Color(0.6, 0.9, 1.0), 1.6)
		cryst.position = Vector3(cos(angle) * 12.0, 0.7, sin(angle) * 12.0)
		lake.add_child(cryst)

	# A lava fissure in the Spiky Cave.
	var lava := Node3D.new()
	lava.name = "LavaFissure"
	var lava_x := SPIKY_CENTER.x + 100.0
	var lava_z := SPIKY_CENTER.z - 100.0
	lava.position = Vector3(lava_x, _cave_floor_height(lava_x, lava_z), lava_z)
	lava.add_to_group("underground_landmark")
	cave.add_child(lava)
	for i in 3:
		var crack := MeshInstance3D.new()
		crack.mesh = Shapes.cube(Vector3(3.0, 0.08, 13.0))
		crack.material_override = _glow_material(Color(1.0, 0.35, 0.1), 2.2)
		crack.position = Vector3(float(i - 1) * 4.0, 0.08, 0)
		crack.rotation.y = 0.3
		lava.add_child(crack)
	var lava_light := OmniLight3D.new()
	lava_light.light_color = Color(1.0, 0.35, 0.1)
	lava_light.light_energy = 2.5
	lava_light.omni_range = 18.0
	lava_light.position.y = 2.0
	lava.add_child(lava_light)

	# Broken ruins in the Normal Cave.
	var ruins := Node3D.new()
	ruins.name = "AncientRuins"
	ruins.position = Vector3(250, _cave_floor_height(250, 450), 450)
	ruins.add_to_group("underground_landmark")
	cave.add_child(ruins)
	for i in 4:
		var angle := TAU * float(i) / 4.0
		_add_box(
			ruins,
			Vector3(cos(angle) * 6.0, 3.0, sin(angle) * 6.0),
			Vector3(1.0, 6.0, 1.0),
			Color(0.35, 0.33, 0.3)
		)
	_add_box(ruins, Vector3(0, 6.2, 0), Vector3(13.5, 0.8, 1.2), Color(0.33, 0.31, 0.29))
	_add_world_label("ANCIENT RUINS", CAVE_ORIGIN + ruins.position + Vector3(0, 8.0, 0),
		Color(0.85, 0.8, 0.6), 70.0)

	# A bubbling acid geyser in the Acid Cave.
	var geyser := Node3D.new()
	geyser.name = "AcidGeyser"
	var geyser_x := ACID_CENTER.x - 100.0
	var geyser_z := ACID_CENTER.z + 100.0
	geyser.position = Vector3(geyser_x, _cave_floor_height(geyser_x, geyser_z), geyser_z)
	geyser.add_to_group("underground_landmark")
	cave.add_child(geyser)
	var geyser_mesh := MeshInstance3D.new()
	var geyser_cone := CylinderMesh.new()
	geyser_cone.top_radius = 0.3
	geyser_cone.bottom_radius = 3.2
	geyser_cone.height = 3.0
	geyser_cone.radial_segments = 8
	geyser_mesh.mesh = geyser_cone
	geyser_mesh.material_override = _glow_material(Color(0.45, 1.0, 0.3), 1.8)
	geyser_mesh.position.y = 1.5
	geyser.add_child(geyser_mesh)


func _build_underground_treasures(cave: Node3D) -> void:
	treasures.clear()
	for data in TREASURE_SPOTS:
		var pos: Vector3 = data["pos"]
		var ground := _cave_floor_height(pos.x, pos.z)
		var vault := Node3D.new()
		vault.position = Vector3(pos.x, ground, pos.z)
		cave.add_child(vault)

		var floor_mesh := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = 6.0
		disc.bottom_radius = 6.2
		disc.height = 0.12
		floor_mesh.mesh = disc
		floor_mesh.material_override = _material(Color(0.2, 0.18, 0.16))
		floor_mesh.position.y = 0.06
		vault.add_child(floor_mesh)

		for i in 4:
			var angle := TAU * float(i) / 4.0 + PI / 4.0
			_add_box(
				vault,
				Vector3(cos(angle) * 4.5, 3.0, sin(angle) * 4.5),
				Vector3(0.7, 6.0, 0.7),
				Color(0.3, 0.28, 0.25)
			)
		var roof := MeshInstance3D.new()
		var roof_disc := CylinderMesh.new()
		roof_disc.top_radius = 6.0
		roof_disc.bottom_radius = 6.0
		roof_disc.height = 0.5
		roof.mesh = roof_disc
		roof.material_override = _material(Color(0.08, 0.08, 0.1))
		roof.position.y = 7.0
		vault.add_child(roof)

		var chest := Node3D.new()
		chest.position.y = 0.15
		vault.add_child(chest)
		_add_box(chest, Vector3(0, 0.45, 0), Vector3(1.5, 0.9, 1.1), Color(0.5, 0.32, 0.16))
		var lid := _add_box(chest, Vector3(0, 1.0, 0), Vector3(1.6, 0.3, 1.2), Color(0.36, 0.22, 0.11))
		_add_box(chest, Vector3(0, 0.6, 0.57), Vector3(0.2, 0.22, 0.08), Color(1.0, 0.82, 0.3))

		var marker := MeshInstance3D.new()
		marker.mesh = Shapes.octahedron(0.18, 0.45)
		marker.material_override = _glow_material(Color(1.0, 0.85, 0.35), 2.6)
		marker.position.y = 2.1
		chest.add_child(marker)

		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.8, 0.4)
		light.light_energy = 2.2
		light.omni_range = 10.0
		light.position.y = 2.5
		vault.add_child(light)

		treasures.append({
			"id": String(data["id"]),
			"pos": CAVE_ORIGIN + Vector3(pos.x, ground, pos.z),
			"found": false,
			"coins": int(data["coins"]),
			"items": data["items"],
			"lid": lid,
			"marker": marker,
		})


func _build_dive() -> void:
	# The dive spot, in the water.
	var spot := MeshInstance3D.new()
	var spot_disc := CylinderMesh.new()
	spot_disc.top_radius = 3.6
	spot_disc.bottom_radius = 3.6
	spot_disc.height = 0.08
	spot.mesh = spot_disc
	spot.material_override = _glow_material(Color(0.3, 0.7, 1.0), 1.6)
	spot.position = DIVE_SPOT + Vector3(0, 0.08, 0)
	add_child(spot)
	_add_world_label("DIVE", DIVE_SPOT + Vector3(0, 3.0, 0), Color(0.55, 0.85, 1.0), 60.0)

	# The sunken grotto under the water.
	var room := Node3D.new()
	room.name = "SunkenGrotto"
	room.position = DIVE_ORIGIN
	add_child(room)

	var floor_body := StaticBody3D.new()
	room.add_child(floor_body)
	var floor_mesh := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 22.0
	disc.bottom_radius = 22.0
	disc.height = 2.0
	disc.radial_segments = 56
	floor_mesh.mesh = disc
	floor_mesh.material_override = _material(Color(0.08, 0.2, 0.28))
	floor_mesh.position.y = -1.0
	floor_body.add_child(floor_mesh)
	var floor_shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 22.0
	cylinder.height = 2.0
	floor_shape.shape = cylinder
	floor_shape.position.y = -1.0
	floor_body.add_child(floor_shape)

	var ceiling := MeshInstance3D.new()
	var ceil_disc := CylinderMesh.new()
	ceil_disc.top_radius = 22.0
	ceil_disc.bottom_radius = 22.0
	ceil_disc.height = 0.6
	ceil_disc.radial_segments = 56
	ceiling.mesh = ceil_disc
	ceiling.material_override = _material(Color(0.04, 0.1, 0.18))
	ceiling.position.y = 10.0
	room.add_child(ceiling)

	for i in 18:
		var angle := TAU * float(i) / 18.0
		var wall := StaticBody3D.new()
		wall.position = Vector3(cos(angle) * 22.0, 5.0, sin(angle) * 22.0)
		wall.rotation.y = -angle
		room.add_child(wall)
		var wall_mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(1.0, 10.0, 7.8)
		wall_mesh.mesh = box
		wall_mesh.material_override = _material(Color(0.08, 0.22, 0.3))
		wall.add_child(wall_mesh)
		var wall_shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = Vector3(1.0, 10.0, 7.8)
		wall_shape.shape = box_shape
		wall.add_child(wall_shape)

	for i in 10:
		var angle := TAU * float(i) / 10.0
		var coral := MeshInstance3D.new()
		coral.mesh = Shapes.octahedron(0.5, 1.8)
		coral.material_override = _glow_material(Color(0.3, 0.9, 0.85), 1.5)
		coral.position = Vector3(cos(angle) * 15.0, 0.8, sin(angle) * 15.0)
		room.add_child(coral)

	for i in 8:
		var fish := MeshInstance3D.new()
		fish.mesh = Shapes.cube(Vector3(0.4, 0.25, 0.7))
		fish.material_override = _material(Color(1.0, 0.65, 0.25))
		fish.position = Vector3(randf_range(-12, 12), randf_range(2, 7), randf_range(-12, 12))
		fish.rotation.y = randf_range(0.0, TAU)
		room.add_child(fish)

	var light := OmniLight3D.new()
	light.light_color = Color(0.4, 0.8, 1.0)
	light.light_energy = 3.0
	light.omni_range = 40.0
	light.position.y = 6.0
	room.add_child(light)

	# The sunken chest.
	var chest := Node3D.new()
	chest.position = Vector3(0, 0.15, -8)
	room.add_child(chest)
	_add_box(chest, Vector3(0, 0.45, 0), Vector3(1.5, 0.9, 1.1), Color(0.4, 0.3, 0.16))
	var lid := _add_box(chest, Vector3(0, 1.0, 0), Vector3(1.6, 0.3, 1.2), Color(0.28, 0.2, 0.1))
	_add_box(chest, Vector3(0, 0.6, 0.57), Vector3(0.2, 0.22, 0.08), Color(1.0, 0.82, 0.3))
	var marker := MeshInstance3D.new()
	marker.mesh = Shapes.octahedron(0.18, 0.45)
	marker.material_override = _glow_material(Color(1.0, 0.85, 0.35), 2.4)
	marker.position.y = 2.1
	chest.add_child(marker)

	var pad := MeshInstance3D.new()
	var pad_disc := CylinderMesh.new()
	pad_disc.top_radius = 2.2
	pad_disc.bottom_radius = 2.2
	pad_disc.height = 0.12
	pad.mesh = pad_disc
	pad.material_override = _glow_material(Color(1.0, 0.85, 0.4), 2.0)
	pad.position = DIVE_EXIT_PAD + Vector3(0, 0.07, 0)
	room.add_child(pad)
	_add_world_label(
		"SUNKEN GROTTO",
		DIVE_ORIGIN + Vector3(0, 5.0, 14.0),
		Color(0.55, 0.9, 1.0), 45.0
	)

	# Add the sunken chest to the treasure list.
	treasures.append({
		"id": "sunken_vault",
		"pos": DIVE_ORIGIN + Vector3(0, 0, -8),
		"found": false,
		"coins": 250,
		"items": {"fish": 4, "potion_heal": 2, "uranium": 3},
		"lid": lid,
		"marker": marker,
	})


func _scatter_cave_formations(cave: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 515151
	for i in 130:
		var angle := rng.randf_range(0.0, TAU)
		var distance := rng.randf_range(90.0, 1080.0)
		var pos := Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)
		var biome_id := underground_biome_at(CAVE_ORIGIN + pos)
		var color := Color(0.35, 0.33, 0.31)
		match biome_id:
			"spiky": color = Color(0.36, 0.25, 0.34)
			"ice": color = Color(0.4, 0.6, 0.78)
			"acid": color = Color(0.3, 0.5, 0.26)
		var shape := MeshInstance3D.new()
		var kind := i % 3
		if kind == 0:
			shape.mesh = Shapes.cube(Vector3(
				rng.randf_range(0.8, 3.0), rng.randf_range(0.6, 4.5), rng.randf_range(0.8, 3.0)
			))
		elif kind == 1:
			shape.mesh = Shapes.pyramid(rng.randf_range(1.0, 3.0), rng.randf_range(2.0, 7.0))
		else:
			shape.mesh = Shapes.octahedron(rng.randf_range(0.5, 1.8), rng.randf_range(1.5, 5.0))
		shape.material_override = _material(color)
		shape.position = Vector3(pos.x, _cave_floor_height(pos.x, pos.z) + 0.5, pos.z)
		shape.rotation.y = rng.randf_range(0.0, TAU)
		shape.add_to_group("cave_formation")
		cave.add_child(shape)


func _scatter_cave_variety(cave: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 818181

	# Little rock mountains made from a few stacked blocks.
	for i in 18:
		var angle := rng.randf_range(0.0, TAU)
		var distance := rng.randf_range(140.0, 1030.0)
		var pos := Vector3(cos(angle) * distance, 0, sin(angle) * distance)
		var biome_id := underground_biome_at(CAVE_ORIGIN + pos)
		var color := Color(0.35, 0.33, 0.31)
		if biome_id == "spiky":
			color = Color(0.35, 0.24, 0.33)
		elif biome_id == "ice":
			color = Color(0.4, 0.58, 0.76)
		elif biome_id == "acid":
			color = Color(0.3, 0.48, 0.25)
		var mound := Node3D.new()
		mound.position = Vector3(pos.x, _cave_floor_height(pos.x, pos.z), pos.z)
		mound.add_to_group("cave_formation")
		cave.add_child(mound)
		var levels := rng.randi_range(3, 5)
		for j in levels:
			var size := Vector3(
				rng.randf_range(6.0, 14.0) - float(j) * 2.0,
				rng.randf_range(2.0, 4.5),
				rng.randf_range(6.0, 14.0) - float(j) * 2.0
			)
			size.x = maxf(size.x, 2.0)
			size.z = maxf(size.z, 2.0)
			var rock := MeshInstance3D.new()
			rock.mesh = Shapes.cube(size)
			rock.material_override = _material(color.darkened(float(j) * 0.04))
			rock.position.y = 1.2 + float(j) * 2.2
			rock.rotation.y = rng.randf_range(-0.3, 0.3)
			mound.add_child(rock)

	# Stalactites hanging from the roof.
	for i in 16:
		var angle := rng.randf_range(0.0, TAU)
		var distance := rng.randf_range(120.0, 1000.0)
		var spike := MeshInstance3D.new()
		spike.mesh = Shapes.pyramid(rng.randf_range(1.2, 3.5), rng.randf_range(4.0, 11.0))
		spike.material_override = _material(Color(0.3, 0.28, 0.32))
		spike.position = Vector3(cos(angle) * distance, CAVE_HEIGHT - 1.0, sin(angle) * distance)
		spike.rotation.x = PI
		spike.add_to_group("cave_formation")
		cave.add_child(spike)

	# Glowing crystal clusters.
	for i in 14:
		var angle := rng.randf_range(0.0, TAU)
		var distance := rng.randf_range(120.0, 1000.0)
		var cluster := Node3D.new()
		var cluster_x := cos(angle) * distance
		var cluster_z := sin(angle) * distance
		cluster.position = Vector3(
			cluster_x, _cave_floor_height(cluster_x, cluster_z), cluster_z
		)
		cluster.add_to_group("cave_formation")
		cave.add_child(cluster)
		for j in 3:
			var gem := MeshInstance3D.new()
			gem.mesh = Shapes.octahedron(rng.randf_range(0.25, 0.7), rng.randf_range(0.8, 2.4))
			gem.material_override = _glow_material(Color(0.45, 0.85, 1.0), 1.4)
			gem.position = Vector3(rng.randf_range(-1.0, 1.0), 0.6, rng.randf_range(-1.0, 1.0))
			cluster.add_child(gem)


func _build_cave_old() -> void:
	var cave := Node3D.new()
	cave.name = "Cave"
	cave.position = CAVE_ORIGIN
	add_child(cave)

	# Floor (solid).
	var floor_body := StaticBody3D.new()
	cave.add_child(floor_body)

	var floor_mesh := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = CAVE_RADIUS
	disc.bottom_radius = CAVE_RADIUS
	disc.height = 2.0
	disc.radial_segments = 64
	floor_mesh.mesh = disc
	floor_mesh.material_override = _material(Color(0.24, 0.22, 0.21))
	floor_mesh.position.y = -1.0
	floor_body.add_child(floor_mesh)

	var floor_shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = CAVE_RADIUS
	cylinder.height = 2.0
	floor_shape.shape = cylinder
	floor_shape.position.y = -1.0
	floor_body.add_child(floor_shape)

	# Ceiling (no collision, it only hides the sky).
	var ceiling := MeshInstance3D.new()
	var ceil_disc := CylinderMesh.new()
	ceil_disc.top_radius = CAVE_RADIUS
	ceil_disc.bottom_radius = CAVE_RADIUS
	ceil_disc.height = 1.0
	ceil_disc.radial_segments = 64
	ceiling.mesh = ceil_disc
	ceiling.material_override = _material(Color(0.16, 0.15, 0.15))
	ceiling.position.y = CAVE_HEIGHT
	cave.add_child(ceiling)

	# Rock wall, made of 24 blocks in a circle.
	for i in 24:
		var angle := TAU * float(i) / 24.0
		var wall := StaticBody3D.new()
		wall.position = Vector3(cos(angle) * CAVE_RADIUS, CAVE_HEIGHT * 0.5, sin(angle) * CAVE_RADIUS)
		wall.rotation.y = -angle
		cave.add_child(wall)

		var wall_mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(1.4, CAVE_HEIGHT, 6.4)
		wall_mesh.mesh = box
		wall_mesh.material_override = _material(Color(0.27, 0.24, 0.23))
		wall.add_child(wall_mesh)

		var wall_shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = Vector3(1.4, CAVE_HEIGHT, 6.4)
		wall_shape.shape = box_shape
		wall.add_child(wall_shape)

	# Stalagmites (pointy rocks) around the edge.
	var rng := RandomNumberGenerator.new()
	rng.seed = 31337
	for i in 14:
		var angle := rng.randf_range(0.0, TAU)
		var distance := rng.randf_range(14.0, 22.0)
		var spike := MeshInstance3D.new()
		var height := rng.randf_range(2.0, 4.5)
		spike.mesh = Shapes.pyramid(rng.randf_range(1.0, 2.2), height)
		spike.material_override = _material(Color(0.33, 0.3, 0.28))
		spike.position = Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)
		cave.add_child(spike)

	# Glowing crystals for light.
	for i in 5:
		var angle := TAU * float(i) / 5.0 + 0.3
		var gem := MeshInstance3D.new()
		gem.mesh = Shapes.octahedron(0.6, 1.4)
		gem.material_override = _glow_material(Color(0.5, 0.8, 1.0), 2.5)
		gem.position = Vector3(cos(angle) * 21.0, 1.0, sin(angle) * 21.0)
		cave.add_child(gem)

		var light := OmniLight3D.new()
		light.light_color = Color(0.45, 0.7, 1.0)
		light.light_energy = 2.5
		light.omni_range = 16.0
		light.position = gem.position + Vector3(0, 1.5, 0)
		cave.add_child(light)

	# The way back up.
	var pad := MeshInstance3D.new()
	var pad_disc := CylinderMesh.new()
	pad_disc.top_radius = 2.0
	pad_disc.bottom_radius = 2.0
	pad_disc.height = 0.12
	pad.mesh = pad_disc
	pad.material_override = _glow_material(Color(1.0, 0.85, 0.4), 2.0)
	pad.position = CAVE_EXIT_PAD + Vector3(0, 0.07, 0)
	cave.add_child(pad)

	var pad_light := OmniLight3D.new()
	pad_light.light_color = Color(1.0, 0.8, 0.4)
	pad_light.light_energy = 3.0
	pad_light.omni_range = 10.0
	pad_light.position = CAVE_EXIT_PAD + Vector3(0, 1.5, 0)
	cave.add_child(pad_light)

	_add_world_label("EXIT", CAVE_ORIGIN + CAVE_EXIT_PAD + Vector3(0, 3.2, 0), Color(1.0, 0.85, 0.4), 50.0)

	# The blue pad at the back of the cave leads to the Thunder Temple.
	var thunder_pad := MeshInstance3D.new()
	var thunder_disc := CylinderMesh.new()
	thunder_disc.top_radius = 2.4
	thunder_disc.bottom_radius = 2.4
	thunder_disc.height = 0.12
	thunder_pad.mesh = thunder_disc
	thunder_pad.material_override = _glow_material(WorldData.THUNDER["glow"], 2.5)
	thunder_pad.position = CAVE_THUNDER_PORTAL + Vector3(0, 0.07, 0)
	cave.add_child(thunder_pad)

	var thunder_light := OmniLight3D.new()
	thunder_light.light_color = WorldData.THUNDER["glow"]
	thunder_light.light_energy = 3.2
	thunder_light.omni_range = 12.0
	thunder_light.position = CAVE_THUNDER_PORTAL + Vector3(0, 1.6, 0)
	cave.add_child(thunder_light)
	_add_world_label(
		"THUNDER TEMPLE",
		CAVE_ORIGIN + CAVE_THUNDER_PORTAL + Vector3(0, 3.4, 0),
		WorldData.THUNDER["glow"], 45.0
	)

	# The green pad leads to the Poison Depths.
	var poison_pad := MeshInstance3D.new()
	var poison_disc := CylinderMesh.new()
	poison_disc.top_radius = 2.2
	poison_disc.bottom_radius = 2.2
	poison_disc.height = 0.12
	poison_pad.mesh = poison_disc
	poison_pad.material_override = _glow_material(Color(0.45, 0.95, 0.35), 2.5)
	poison_pad.position = CAVE_POISON_PORTAL + Vector3(0, 0.07, 0)
	cave.add_child(poison_pad)

	var poison_light := OmniLight3D.new()
	poison_light.light_color = Color(0.5, 1.0, 0.4)
	poison_light.light_energy = 3.0
	poison_light.omni_range = 11.0
	poison_light.position = CAVE_POISON_PORTAL + Vector3(0, 1.5, 0)
	cave.add_child(poison_light)
	_add_world_label(
		"POISON DEPTHS",
		CAVE_ORIGIN + CAVE_POISON_PORTAL + Vector3(0, 3.2, 0),
		Color(0.5, 1.0, 0.4), 45.0
	)

	# Cave ore: more iron down here than on the surface.
	for i in 20:
		var angle := rng.randf_range(0.0, TAU)
		var distance := rng.randf_range(6.0, 22.0)
		var ore_type := "iron"
		if i % 3 == 0:
			ore_type = "stone"
		elif i % 3 == 1:
			ore_type = "copper"
		var ore = ORE_SCENE.instantiate()
		ore.ore_type = ore_type
		ore.game = self
		ore.position = CAVE_ORIGIN + Vector3(cos(angle) * distance, 0, sin(angle) * distance)
		ore.rotation.y = rng.randf_range(0.0, TAU)
		add_child(ore)

	# Cave monsters, leashed to the cave.
	for i in 4:
		var monster = ENEMY_SCENE.instantiate()
		monster.game = self
		monster.form = "rock"
		monster.body_color = Color(0.35, 0.3, 0.34)
		monster.max_hp = 45.0
		monster.coin_reward = 18
		monster.home_center = Vector2(0, 0)
		monster.home_size = Vector2(CAVE_RADIUS - 3.0, CAVE_RADIUS - 3.0)
		monster.has_home = true
		monster.position = CAVE_ORIGIN + Vector3(rng.randf_range(-18, 18), 1.0, rng.randf_range(-18, 18))
		add_child(monster)


func _build_thunder_temple() -> void:
	var room := Node3D.new()
	room.name = "ThunderTemple"
	room.position = THUNDER_ORIGIN
	add_child(room)

	# Floor.
	var floor_body := StaticBody3D.new()
	room.add_child(floor_body)
	var floor_mesh := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = THUNDER_RADIUS
	disc.bottom_radius = THUNDER_RADIUS
	disc.height = 2.0
	disc.radial_segments = 64
	floor_mesh.mesh = disc
	floor_mesh.material_override = _material(Color(0.16, 0.18, 0.28))
	floor_mesh.position.y = -1.0
	floor_body.add_child(floor_mesh)

	var floor_shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = THUNDER_RADIUS
	cylinder.height = 2.0
	floor_shape.shape = cylinder
	floor_shape.position.y = -1.0
	floor_body.add_child(floor_shape)

	# Ceiling.
	var ceiling := MeshInstance3D.new()
	var ceil_disc := CylinderMesh.new()
	ceil_disc.top_radius = THUNDER_RADIUS
	ceil_disc.bottom_radius = THUNDER_RADIUS
	ceil_disc.height = 1.0
	ceil_disc.radial_segments = 64
	ceiling.mesh = ceil_disc
	ceiling.material_override = _material(Color(0.1, 0.12, 0.2))
	ceiling.position.y = THUNDER_HEIGHT
	room.add_child(ceiling)

	# Stone walls.
	for i in 22:
		var angle := TAU * float(i) / 22.0
		var wall := StaticBody3D.new()
		wall.position = Vector3(cos(angle) * THUNDER_RADIUS, THUNDER_HEIGHT * 0.5, sin(angle) * THUNDER_RADIUS)
		wall.rotation.y = -angle
		room.add_child(wall)

		var wall_mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(1.4, THUNDER_HEIGHT, 6.6)
		wall_mesh.mesh = box
		wall_mesh.material_override = _material(Color(0.2, 0.23, 0.34))
		wall.add_child(wall_mesh)

		var wall_shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = Vector3(1.4, THUNDER_HEIGHT, 6.6)
		wall_shape.shape = box_shape
		wall.add_child(wall_shape)

	# Electric pillars around the arena.
	for i in 4:
		var angle := TAU * float(i) / 4.0 + 0.4
		var at := Vector3(cos(angle) * 12.0, 0, sin(angle) * 12.0)
		_add_box(room, at + Vector3(0, 4.0, 0), Vector3(0.8, 8.0, 0.8), Color(0.24, 0.28, 0.42))

		var crystal := MeshInstance3D.new()
		crystal.mesh = Shapes.octahedron(0.55, 1.4)
		crystal.material_override = _glow_material(WorldData.THUNDER["glow"], 3.0)
		crystal.position = at + Vector3(0, 8.6, 0)
		room.add_child(crystal)

		var light := OmniLight3D.new()
		light.light_color = WorldData.THUNDER["glow"]
		light.light_energy = 2.8
		light.omni_range = 14.0
		light.position = at + Vector3(0, 5.0, 0)
		room.add_child(light)

	# A few glowing crystals on the floor.
	for i in 6:
		var angle := TAU * float(i) / 6.0 + 0.2
		var gem := MeshInstance3D.new()
		gem.mesh = Shapes.octahedron(0.5, 1.2)
		gem.material_override = _glow_material(WorldData.THUNDER["glow"], 2.4)
		gem.position = Vector3(cos(angle) * 18.0, 0.7, sin(angle) * 18.0)
		room.add_child(gem)

	# The way back to the crystal cave.
	var pad := MeshInstance3D.new()
	var pad_disc := CylinderMesh.new()
	pad_disc.top_radius = 2.2
	pad_disc.bottom_radius = 2.2
	pad_disc.height = 0.12
	pad.mesh = pad_disc
	pad.material_override = _glow_material(Color(0.5, 1.0, 0.7), 2.2)
	pad.position = THUNDER_EXIT_PAD + Vector3(0, 0.07, 0)
	room.add_child(pad)

	var pad_light := OmniLight3D.new()
	pad_light.light_color = Color(0.5, 1.0, 0.7)
	pad_light.light_energy = 3.0
	pad_light.omni_range = 10.0
	pad_light.position = THUNDER_EXIT_PAD + Vector3(0, 1.5, 0)
	room.add_child(pad_light)
	_add_world_label(
		"THUNDER TEMPLE",
		THUNDER_ORIGIN + THUNDER_EXIT_PAD + Vector3(0, 3.5, 0),
		WorldData.THUNDER["glow"], 42.0
	)

	# The Storm Golem.
	var data: Dictionary = WorldData.THUNDER["boss"]
	var boss = BOSS_SCENE.instantiate()
	boss.boss_name = String(data["name"])
	boss.max_hp = float(data["hp"])
	boss.move_speed = float(data["speed"])
	boss.touch_damage = float(data["damage"])
	boss.coin_reward = int(data["coins"])
	boss.ability = String(data["ability"])
	boss.body_color = data["color"]
	boss.eye_color = data["eye"]
	boss.stone_key = String(WorldData.THUNDER["stone"])
	boss.stone_name = String(WorldData.THUNDER["stone_name"])
	boss.biome_id = "thunder"
	boss.game = self
	boss.home = THUNDER_ORIGIN
	boss.arena_radius = 10.0
	boss.scale = Vector3.ONE * float(data["scale"])
	boss.position = THUNDER_ORIGIN + Vector3(0, 1.0, 0)
	add_child(boss)
	bosses.append(boss)


func _build_poison_depths() -> void:
	var room := Node3D.new()
	room.name = "PoisonDepths"
	room.position = POISON_ORIGIN
	add_child(room)

	# Floor.
	var floor_body := StaticBody3D.new()
	room.add_child(floor_body)
	var floor_mesh := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = POISON_RADIUS
	disc.bottom_radius = POISON_RADIUS
	disc.height = 2.0
	disc.radial_segments = 56
	floor_mesh.mesh = disc
	floor_mesh.material_override = _material(Color(0.12, 0.2, 0.12))
	floor_mesh.position.y = -1.0
	floor_body.add_child(floor_mesh)

	var floor_shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = POISON_RADIUS
	cylinder.height = 2.0
	floor_shape.shape = cylinder
	floor_shape.position.y = -1.0
	floor_body.add_child(floor_shape)

	# Ceiling.
	var ceiling := MeshInstance3D.new()
	var ceil_disc := CylinderMesh.new()
	ceil_disc.top_radius = POISON_RADIUS
	ceil_disc.bottom_radius = POISON_RADIUS
	ceil_disc.height = 1.0
	ceil_disc.radial_segments = 56
	ceiling.mesh = ceil_disc
	ceiling.material_override = _material(Color(0.08, 0.12, 0.09))
	ceiling.position.y = POISON_HEIGHT
	room.add_child(ceiling)

	# Mossy stone walls.
	for i in 20:
		var angle := TAU * float(i) / 20.0
		var wall := StaticBody3D.new()
		wall.position = Vector3(cos(angle) * POISON_RADIUS, POISON_HEIGHT * 0.5, sin(angle) * POISON_RADIUS)
		wall.rotation.y = -angle
		room.add_child(wall)

		var wall_mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(1.4, POISON_HEIGHT, 6.5)
		wall_mesh.mesh = box
		wall_mesh.material_override = _material(Color(0.2, 0.3, 0.2))
		wall.add_child(wall_mesh)

		var wall_shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = Vector3(1.4, POISON_HEIGHT, 6.5)
		wall_shape.shape = box_shape
		wall.add_child(wall_shape)

	# Glowing mushrooms around the edge.
	for i in 8:
		var angle := TAU * float(i) / 8.0 + 0.2
		var stem := MeshInstance3D.new()
		stem.mesh = Shapes.cube(Vector3(0.35, 1.4, 0.35))
		stem.material_override = _material(Color(0.45, 0.55, 0.35))
		stem.position = Vector3(cos(angle) * 16.5, 0.7, sin(angle) * 16.5)
		room.add_child(stem)

		var cap := MeshInstance3D.new()
		cap.mesh = Shapes.pyramid(2.2, 1.1)
		cap.material_override = _glow_material(Color(0.55, 1.0, 0.4), 1.6)
		cap.position = stem.position + Vector3(0, 1.3, 0)
		room.add_child(cap)

	var light := OmniLight3D.new()
	light.light_color = Color(0.45, 0.9, 0.35)
	light.light_energy = 3.0
	light.omni_range = 34.0
	light.position = Vector3(0, 4.0, 0)
	room.add_child(light)

	# Poison pools: glowing green discs that hurt if you stand in them.
	for offset in POISON_POOL_OFFSETS:
		var pool := MeshInstance3D.new()
		var pool_disc := CylinderMesh.new()
		pool_disc.top_radius = 2.4
		pool_disc.bottom_radius = 2.4
		pool_disc.height = 0.08
		pool.mesh = pool_disc
		pool.material_override = _glow_material(Color(0.35, 0.9, 0.25), 1.8)
		pool.position = Vector3(offset.x, 0.05, offset.y)
		room.add_child(pool)

	# Some ore between the pools.
	for i in 5:
		var angle := TAU * float(i) / 5.0 + 0.5
		var ore = ORE_SCENE.instantiate()
		ore.ore_type = "iron" if i % 2 == 0 else "copper"
		ore.game = self
		ore.position = POISON_ORIGIN + Vector3(cos(angle) * 12.0, 0, sin(angle) * 12.0)
		ore.rotation.y = randf_range(0.0, TAU)
		add_child(ore)

	# Poisonous cave monsters.
	var rng := RandomNumberGenerator.new()
	rng.seed = 707
	for i in 5:
		var monster = ENEMY_SCENE.instantiate()
		monster.game = self
		monster.form = "mushroom"
		monster.body_color = Color(0.38, 0.62, 0.3)
		monster.max_hp = 55.0
		monster.coin_reward = 22
		monster.poison_touch = true
		monster.home_center = Vector2(0, 0)
		monster.home_size = Vector2(POISON_RADIUS - 3.0, POISON_RADIUS - 3.0)
		monster.has_home = true
		monster.position = POISON_ORIGIN + Vector3(rng.randf_range(-14, 14), 1.0, rng.randf_range(-14, 14))
		add_child(monster)

	# The way back to the crystal cave.
	var pad := MeshInstance3D.new()
	var pad_disc := CylinderMesh.new()
	pad_disc.top_radius = 2.2
	pad_disc.bottom_radius = 2.2
	pad_disc.height = 0.12
	pad.mesh = pad_disc
	pad.material_override = _glow_material(Color(1.0, 0.85, 0.4), 2.2)
	pad.position = POISON_EXIT_PAD + Vector3(0, 0.07, 0)
	room.add_child(pad)

	var pad_light := OmniLight3D.new()
	pad_light.light_color = Color(1.0, 0.85, 0.4)
	pad_light.light_energy = 3.0
	pad_light.omni_range = 10.0
	pad_light.position = POISON_EXIT_PAD + Vector3(0, 1.5, 0)
	room.add_child(pad_light)
	_add_world_label(
		"POISON DEPTHS",
		POISON_ORIGIN + POISON_EXIT_PAD + Vector3(0, 3.4, 0),
		Color(0.6, 1.0, 0.45), 42.0
	)


func sky_portal_open() -> bool:
	return final_boss_defeated


func enter_sky() -> void:
	if not sky_portal_open():
		_log("The Sky Portal is sealed. Beat the Eight-Stone Guardian first!")
		return
	player.global_position = SKY_ORIGIN + SKY_ARRIVAL
	player.velocity = Vector3.ZERO
	in_sky = true
	in_cave = false
	in_dive = false
	in_final = false
	breath = 100.0
	_spawn_sky_dragon()
	play_sound("roar")
	_log("Welcome to the Sky Islands DLC!")


func leave_sky() -> void:
	player.global_position = SKY_PORTAL_POS + Vector3(0, 1.2, 4.0)
	player.velocity = Vector3.ZERO
	in_sky = false
	_log("You return from the Sky Islands.")


func _spawn_sky_dragon() -> void:
	if sky_dragon_defeated:
		return
	if sky_dragon != null and is_instance_valid(sky_dragon):
		return
	var dragon = BOSS_SCENE.instantiate()
	dragon.boss_name = "SKY DRAGON"
	dragon.max_hp = 520.0
	dragon.move_speed = 7.2
	dragon.touch_damage = 22.0
	dragon.coin_reward = 260
	dragon.ability = "final"
	dragon.body_color = Color(0.35, 0.55, 0.72)
	dragon.eye_color = Color(0.6, 1.0, 1.0)
	dragon.sky_boss = true
	dragon.biome_id = "sky"
	dragon.stone_key = ""
	dragon.stone_name = ""
	dragon.game = self
	dragon.home = SKY_ORIGIN + SKY_DRAGON_POS
	dragon.arena_radius = 16.0
	dragon.scale = Vector3.ONE * 1.5
	dragon.position = dragon.home + Vector3(0, 1.0, 0)
	add_child(dragon)
	bosses.append(dragon)
	sky_dragon = dragon


func on_sky_boss_defeated() -> void:
	sky_dragon_defeated = true
	add_item("sky_crystal", 6)
	save_game()
	play_sound("quest")
	_log("The Sky Dragon is defeated! DLC: Sky Islands complete!")
	if hud != null:
		hud.show_dlc_ending()


func final_portal_open() -> bool:
	return not final_boss_defeated and infused.size() >= WorldData.STONE_KEYS.size()


func enter_final() -> void:
	if not final_portal_open():
		_log("The final portal is sealed. Infuse all eight magic stones first!")
		return
	player.global_position = FINAL_ARENA_ORIGIN + FINAL_ARRIVAL
	player.velocity = Vector3.ZERO
	in_final = true
	in_cave = false
	in_dive = false
	in_sky = false
	breath = 100.0
	_spawn_final_boss()
	play_sound("roar")
	_log("The Eight-Stone Guardian awakens! This is the final trial.")


func leave_final() -> void:
	player.global_position = FINAL_PORTAL_POS + Vector3(0, 1.2, 4.0)
	player.velocity = Vector3.ZERO
	in_final = false
	_log("You step back through the final portal.")


func _spawn_final_boss() -> void:
	if final_boss_defeated:
		return
	if final_boss_node != null and is_instance_valid(final_boss_node):
		return
	var boss = BOSS_SCENE.instantiate()
	boss.boss_name = "THE EIGHT-STONE GUARDIAN"
	boss.max_hp = 700.0
	boss.move_speed = 6.8
	boss.touch_damage = 24.0
	boss.coin_reward = 300
	boss.ability = "final"
	boss.body_color = Color(0.28, 0.24, 0.3)
	boss.eye_color = Color(1.0, 0.85, 0.4)
	boss.final_boss = true
	boss.biome_id = "final"
	boss.stone_key = ""
	boss.stone_name = ""
	boss.game = self
	boss.home = FINAL_ARENA_ORIGIN
	boss.arena_radius = 16.0
	boss.scale = Vector3.ONE * 1.6
	boss.position = boss.home + Vector3(0, 1.0, 0)
	add_child(boss)
	bosses.append(boss)
	final_boss_node = boss


func on_final_boss_defeated() -> void:
	final_boss_defeated = true
	ending_seen = true
	save_game()
	play_sound("quest")
	_log("The Eight-Stone Guardian is defeated! The island is safe.")
	if hud != null:
		hud.show_ending()


func enter_dive() -> void:
	player.global_position = DIVE_ORIGIN + DIVE_ARRIVAL
	player.velocity = Vector3.ZERO
	in_dive = true
	in_cave = false
	in_final = false
	in_sky = false
	breath = 100.0
	dot_time = 0.0
	play_sound("coin")
	_log("You dive into the Sunken Grotto. Watch your breath!")


func leave_dive() -> void:
	player.global_position = DIVE_SPOT + Vector3(0, 1.2, 3.0)
	player.velocity = Vector3.ZERO
	in_dive = false
	breath = 100.0
	_log("You surface in the lake, gasping for air.")


func enter_cave() -> void:
	var arrival_h := _cave_floor_height(CAVE_ARRIVAL.x, CAVE_ARRIVAL.z)
	player.global_position = CAVE_ORIGIN + Vector3(
		CAVE_ARRIVAL.x, arrival_h + 1.2, CAVE_ARRIVAL.z
	)
	player.velocity = Vector3.ZERO
	in_cave = true
	in_thunder = false
	in_poison = false
	in_dive = false
	in_final = false
	in_sky = false
	breath = 100.0
	dot_time = 0.0
	_log("You climb down into the cave. Watch out for monsters!")


func leave_cave() -> void:
	player.global_position = CAVE_ENTRANCE + Vector3(0, 1.5, 5.0)
	player.velocity = Vector3.ZERO
	in_cave = false
	in_thunder = false
	in_poison = false
	in_dive = false
	in_final = false
	breath = 100.0
	_log("You climb back out into the daylight.")


func enter_thunder() -> void:
	player.global_position = THUNDER_ORIGIN + THUNDER_ARRIVAL
	player.velocity = Vector3.ZERO
	in_cave = true
	in_thunder = true
	in_poison = false
	dot_time = 0.0
	_log("The Thunder Temple crackles with blue lightning!")


func leave_thunder() -> void:
	player.global_position = CAVE_ORIGIN + CAVE_THUNDER_PORTAL + Vector3(0, 1.2, 4.0)
	player.velocity = Vector3.ZERO
	in_cave = true
	in_thunder = false
	in_poison = false
	_log("You step back into the crystal cave.")


func enter_poison() -> void:
	player.global_position = POISON_ORIGIN + POISON_ARRIVAL
	player.velocity = Vector3.ZERO
	in_cave = true
	in_thunder = false
	in_poison = true
	dot_time = 0.0
	_log("You climb down into the Poison Depths. Mind the green pools!")


func leave_poison() -> void:
	player.global_position = CAVE_ORIGIN + CAVE_POISON_PORTAL + Vector3(0, 1.2, 4.0)
	player.velocity = Vector3.ZERO
	in_cave = true
	in_thunder = false
	in_poison = false
	_log("You climb back up into the crystal cave.")


func _add_box(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var box_node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	box_node.mesh = mesh
	box_node.material_override = _material(color)
	box_node.position = pos
	parent.add_child(box_node)
	return box_node


func _build_temples() -> void:
	for biome in WorldData.BIOMES:
		var temple := Node3D.new()
		temple.name = "Temple_" + String(biome["id"])
		temple.position = Vector3(biome["temple_pos"].x, 0, biome["temple_pos"].y)
		add_child(temple)

		var floor_mesh := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = 10.0
		disc.bottom_radius = 10.2
		disc.height = 0.08
		floor_mesh.mesh = disc
		floor_mesh.material_override = _material(biome["floor"])
		floor_mesh.position.y = 0.04
		temple.add_child(floor_mesh)

		match String(biome["style"]):
			"pillars":
				_temple_pillars(temple, biome)
			"obelisks":
				_temple_obelisks(temple, biome)
			"trunks":
				_temple_trunks(temple, biome)
			"crystals":
				_temple_crystals(temple, biome)
			"fountain":
				_temple_fountain(temple, biome)
			"mushrooms":
				_temple_mushrooms(temple, biome)

		# Every temple glows in its own colour so you can recognise it at night.
		var light := OmniLight3D.new()
		light.light_color = biome["glow"]
		light.light_energy = 4.0
		light.omni_range = 16.0
		light.position.y = 3.5
		temple.add_child(light)

		_add_world_label(
			String(biome["temple_name"]),
			temple.position + Vector3(0, 9.0, 0),
			biome["glow"],
			500.0
		)


func _temple_pillars(temple: Node3D, biome: Dictionary) -> void:
	for i in 8:
		var angle := TAU * float(i) / 8.0
		_add_pillar(temple, Vector3(cos(angle) * 8.5, 0, sin(angle) * 8.5), 0.6, 5.0, biome["pillar"])
	_add_float_gem(temple, Vector3(0, 2.2, 0), biome["glow"], 0.5)


func _temple_obelisks(temple: Node3D, biome: Dictionary) -> void:
	for i in 6:
		var angle := TAU * float(i) / 6.0
		var obelisk := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(1.3, 7.0, 1.3)
		obelisk.mesh = box
		obelisk.material_override = _material(biome["pillar"])
		obelisk.position = Vector3(cos(angle) * 7.5, 3.5, sin(angle) * 7.5)
		obelisk.rotation.y = angle
		temple.add_child(obelisk)

	# Four braziers with fire on top.
	for i in 4:
		var angle := TAU * float(i) / 4.0 + 0.4
		_add_pillar(temple, Vector3(cos(angle) * 5.0, 0, sin(angle) * 5.0), 0.3, 1.2, biome["pillar"])
		_add_float_gem(temple, Vector3(cos(angle) * 5.0, 1.8, sin(angle) * 5.0), biome["glow"], 0.35)
	_add_float_gem(temple, Vector3(0, 2.4, 0), biome["glow"], 0.6)


func _temple_trunks(temple: Node3D, biome: Dictionary) -> void:
	for i in 9:
		var angle := TAU * float(i) / 9.0
		var at := Vector3(cos(angle) * 8.0, 0, sin(angle) * 8.0)
		_add_pillar(temple, at, 0.7, 5.5, biome["pillar"])

		# A triangular leaf crown.
		var canopy := MeshInstance3D.new()
		canopy.mesh = Shapes.pyramid(4.4, 3.4)
		canopy.material_override = _material(biome["glow"])
		canopy.position = at + Vector3(0, 6.2, 0)
		temple.add_child(canopy)
	_add_float_gem(temple, Vector3(0, 2.0, 0), biome["glow"], 0.45)


func _temple_crystals(temple: Node3D, biome: Dictionary) -> void:
	for i in 9:
		var angle := TAU * float(i) / 9.0
		var crystal := MeshInstance3D.new()
		var height := randf_range(5.0, 8.0)
		crystal.mesh = Shapes.pyramid(1.6, height)
		crystal.material_override = _glow_material(biome["pillar"], 0.6)
		crystal.position = Vector3(cos(angle) * 8.0, 0, sin(angle) * 8.0)
		crystal.rotation.z = randf_range(-0.1, 0.1)
		temple.add_child(crystal)
	_add_float_gem(temple, Vector3(0, 2.6, 0), biome["glow"], 0.55)


func _temple_fountain(temple: Node3D, biome: Dictionary) -> void:
	for i in 8:
		var angle := TAU * float(i) / 8.0
		_add_pillar(temple, Vector3(cos(angle) * 8.5, 0, sin(angle) * 8.5), 0.5, 4.0, biome["pillar"])

	var pool := MeshInstance3D.new()
	var pool_disc := CylinderMesh.new()
	pool_disc.top_radius = 6.0
	pool_disc.bottom_radius = 6.0
	pool_disc.height = 0.3
	pool.mesh = pool_disc
	pool.material_override = _material(biome["glow"])
	pool.position.y = 0.2
	temple.add_child(pool)

	_add_float_gem(temple, Vector3(0, 3.0, 0), biome["glow"], 0.6)


func _temple_mushrooms(temple: Node3D, biome: Dictionary) -> void:
	for i in 6:
		var angle := TAU * float(i) / 6.0
		var at := Vector3(cos(angle) * 7.0, 0, sin(angle) * 7.0)
		_add_pillar(temple, at, 0.45, 3.2, biome["pillar"])

		# A triangular mushroom cap.
		var cap := MeshInstance3D.new()
		cap.mesh = Shapes.pyramid(4.0, 1.6)
		cap.material_override = _glow_material(biome["glow"], 0.5)
		cap.position = at + Vector3(0, 3.1, 0)
		temple.add_child(cap)
	_add_float_gem(temple, Vector3(0, 1.8, 0), biome["glow"], 0.4)


func _add_pillar(parent: Node3D, pos: Vector3, radius: float, height: float, color: Color) -> void:
	# A square stone column (cubes only, no round pillars).
	var pillar := MeshInstance3D.new()
	pillar.mesh = Shapes.cube(Vector3(radius * 2.0, height, radius * 2.0))
	pillar.material_override = _material(color)
	pillar.position = pos + Vector3(0, height * 0.5, 0)
	parent.add_child(pillar)


func _add_float_gem(parent: Node3D, pos: Vector3, color: Color, size: float) -> void:
	# Diamonds are made of 8 triangles.
	var gem := MeshInstance3D.new()
	gem.mesh = Shapes.octahedron(size, size * 2.2)
	gem.material_override = _glow_material(color, 2.5)
	gem.position = pos
	gem.set_script(preload("res://scripts/spinner.gd"))
	parent.add_child(gem)


func _build_trader() -> void:
	trader = TRADER_SCRIPT.new()
	trader.game = self
	add_child(trader)


func _spawn_wolf() -> void:
	wolf = WOLF_SCRIPT.new()
	wolf.game = self
	var spot := Vector2(70, -700)   # the Forest
	if not _is_land(spot):
		for i in 20:
			var p := Vector2(randf_range(-140.0, 140.0), -700.0 + randf_range(-90.0, 90.0))
			if _is_land(p):
				spot = p
				break
	wolf.position = Vector3(spot.x, 0.0, spot.y)
	add_child(wolf)


func talk_to_villager(villager) -> void:
	if villager == null or not is_instance_valid(villager):
		return
	villager.face_player()
	_log("%s: %s" % [villager.villager_name, villager.next_line()])


func tame_wolf() -> void:
	if wolf == null or wolf_tamed:
		return
	wolf_tamed = true
	wolf.set_tamed(true)
	play_sound("quest")
	_log("You tamed the wolf! It will follow you and bite monsters.")


func feed_wolf() -> void:
	if not wolf_tamed or wolf == null:
		return
	if wolf.level >= 5:
		_log("Your wolf is fully trained (level 5).")
		return
	if count_item("meat") <= 0:
		_log("Your wolf is hungry! Hunt an animal for meat.")
		return
	remove_item("meat", 1)
	wolf.set_level(wolf.level + 1)
	play_sound("quest")
	_log("Your wolf is now level %d! Its bite is stronger." % wolf.level)


func toggle_wolf_stay() -> void:
	if not wolf_tamed or wolf == null:
		_log("Tame the forest wolf first.")
		return
	wolf.set_stay(not wolf.stay)
	_log("Your wolf will %s." % ("stay here" if wolf.stay else "follow you"))


func command_wolf_attack() -> void:
	if not wolf_tamed or wolf == null:
		_log("Tame the forest wolf first.")
		return

	var target: Node3D = null
	if player != null and player.focus_node != null and is_instance_valid(player.focus_node):
		if player.focus_node.is_in_group("enemy") or player.focus_node.is_in_group("boss"):
			target = player.focus_node
	if target == null and player != null:
		var best := 30.0
		for enemy in get_tree().get_nodes_in_group("enemy"):
			if enemy == null or not is_instance_valid(enemy):
				continue
			if "hp" in enemy and float(enemy.hp) <= 0.0:
				continue
			var d: float = enemy.global_position.distance_to(player.global_position)
			if d < best:
				best = d
				target = enemy
	if target == null:
		_log("No monster nearby for your wolf to attack.")
		return
	wolf.set_stay(false)
	wolf.forced_target = target
	_log("Your wolf charges at the %s!" % target.name)


func random_trader_point(near: Vector2) -> Vector2:
	# A land spot a short walk away, never inside the Forge safe ring or the cave.
	for i in 40:
		var p := near + Vector2(randf_range(-160.0, 160.0), randf_range(-160.0, 160.0))
		if p.length() > WorldData.WORLD_RADIUS - 40.0:
			continue
		if not _is_land(p):
			continue
		if p.distance_to(Vector2(FORGE_POS.x, FORGE_POS.z)) < SAFE_RADIUS + 15.0:
			continue
		if p.distance_to(Vector2(CAVE_ENTRANCE.x, CAVE_ENTRANCE.z)) < 30.0:
			continue

		# Keep the walk on dry land: sample the path so he never walks on water.
		var dry := true
		for t in [0.25, 0.5, 0.75]:
			if not _is_land(near.lerp(p, t)):
				dry = false
				break
		if not dry:
			continue
		return p
	return near


func _build_village() -> void:
	## A few simple huts in the Savanna. Merchants move in later.
	var huts := [Vector3(700, 0, -300), Vector3(780, 0, 280), Vector3(540, 0, -80)]
	for hut_pos in huts:
		var hut := Node3D.new()
		hut.position = hut_pos
		hut.rotation.y = randf_range(-0.4, 0.4)
		add_child(hut)

		var walls := MeshInstance3D.new()
		var wall_box := BoxMesh.new()
		wall_box.size = Vector3(5.0, 3.0, 5.0)
		walls.mesh = wall_box
		walls.material_override = _material(Color(0.86, 0.77, 0.55))
		walls.position.y = 1.5
		hut.add_child(walls)

		var roof := MeshInstance3D.new()
		roof.mesh = Shapes.pyramid(8.4, 2.6)
		roof.material_override = _material(Color(0.55, 0.35, 0.22))
		roof.position.y = 3.0
		hut.add_child(roof)

	# The village quest board.
	var board := Node3D.new()
	board.position = QUEST_BOARD_POS
	board.rotation.y = -0.6
	add_child(board)
	_add_box(board, Vector3(-0.9, 1.2, 0), Vector3(0.16, 2.4, 0.16), Color(0.38, 0.25, 0.14))
	_add_box(board, Vector3(0.9, 1.2, 0), Vector3(0.16, 2.4, 0.16), Color(0.38, 0.25, 0.14))
	_add_box(board, Vector3(0, 2.1, 0), Vector3(2.2, 1.2, 0.18), Color(0.62, 0.44, 0.24))

	var quest_marker := MeshInstance3D.new()
	quest_marker.mesh = Shapes.cube(Vector3(0.22, 0.5, 0.22))
	quest_marker.material_override = _glow_material(Color(1.0, 0.9, 0.35), 2.8)
	quest_marker.position = Vector3(0, 3.15, 0)
	board.add_child(quest_marker)

	_add_villager(Vector3(690, 0, -292), "Mira the Baker", Color(0.78, 0.55, 0.38), [
		"Try the campfire: cooked meat fills you up much more.",
		"The wolf loves meat. Feed it and it gets stronger.",
		"Berries are nice, but a warm meal is better.",
	])
	_add_villager(Vector3(790, 0, 270), "Tomas the Smith", Color(0.48, 0.42, 0.36), [
		"A Hunter's Bow needs 8 wood and 4 iron. Then you can shoot from far away.",
		"Uranium makes a green glow. The village pays well for it.",
		"Wear all four armour pieces and you feel much safer.",
	])
	_add_villager(Vector3(545, 0, -72), "Lina the Scout", Color(0.32, 0.52, 0.34), [
		"The underground is huge now. Walk between the four caves.",
		"The Acid Cave has uranium. Mind the green pools.",
		"The Uranium Golem lives deep in the Acid Cave.",
	])


func _add_villager(pos: Vector3, villager_name: String, color: Color, lines: Array) -> void:
	var villager = VILLAGER_SCRIPT.new()
	villager.game = self
	villager.villager_name = villager_name
	villager.body_color = color
	villager.lines = lines
	villager.position = pos
	add_child(villager)
	villagers.append(villager)


func _scatter_trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261114
	for biome in WorldData.BIOMES:
		var count := 0
		match String(biome["id"]):
			"plants": count = 170
			"ice": count = 95
			"rock": count = 28
			"poison": count = 25
		for i in count:
			var p := _random_in_biome(rng, biome)
			if Vector3(p.x, 0, p.y).distance_to(FORGE_POS) < 45.0:
				continue
			if Vector2(p.x - CAVE_ENTRANCE.x, p.y - CAVE_ENTRANCE.z).length() < 30.0:
				continue
			# Never plant a tree in a place that belongs to another biome
			# (for example a plains tree standing in the lake).
			if String(_biome_at(p)["id"]) != String(biome["id"]):
				continue
			if not _is_land(p):
				continue
			var leaf: Color = Color(0.2, 0.5, 0.24)
			var tree_type := "oak"
			match String(biome["id"]):
				"plants":
					tree_type = "pine"
					leaf = Color(0.16, 0.4, 0.2)
				"ice":
					tree_type = "icy"
					leaf = Color(0.78, 0.87, 0.93)
				"poison":
					tree_type = "ancient"
					leaf = Color(0.48, 0.3, 0.56)
			_add_tree(Vector3(p.x, 0, p.y), leaf, tree_type)


func _add_tree(pos: Vector3, leaf_color: Color, tree_type := "oak") -> void:
	var tree := StaticBody3D.new()
	tree.set_script(TREE_SCRIPT)
	tree.game = self
	tree.tree_type = tree_type
	tree.position = pos

	var trunk_color := Color(0.34, 0.23, 0.15)
	match tree_type:
		"pine":
			tree.wood_amount = 5
			tree.max_hp = 4.0
		"icy":
			tree.wood_amount = 4
			tree.max_hp = 3.0
			trunk_color = Color(0.5, 0.55, 0.6)
		"ancient":
			tree.wood_item = "hardwood"
			tree.wood_amount = 2
			tree.max_hp = 5.0
			trunk_color = Color(0.25, 0.17, 0.2)

	var trunk := MeshInstance3D.new()
	trunk.name = "Trunk"
	trunk.mesh = Shapes.cube(Vector3(0.5, 2.4, 0.5))
	trunk.material_override = _material(trunk_color)
	trunk.position.y = 1.2
	tree.add_child(trunk)

	var leaves := MeshInstance3D.new()
	leaves.name = "Leaves"
	leaves.mesh = Shapes.pyramid(2.8, 2.9)
	leaves.material_override = _material(leaf_color)
	leaves.position.y = 2.3
	tree.add_child(leaves)

	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(0.6, 2.4, 0.6)
	shape.shape = box_shape
	shape.position.y = 1.2
	tree.add_child(shape)
	add_child(tree)


func _scatter_rocks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var transforms: Array = []
	for i in 320:
		var p := _random_on_island(rng, 0.95)
		if not _is_land(p):
			continue
		if Vector3(p.x, 0, p.y).distance_to(FORGE_POS) < 40.0:
			continue
		if Vector2(p.x - CAVE_ENTRANCE.x, p.y - CAVE_ENTRANCE.z).length() < 30.0:
			continue
		var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(
			Vector3(rng.randf_range(0.6, 1.4), rng.randf_range(0.4, 0.9), rng.randf_range(0.6, 1.4))
		)
		transforms.append(Transform3D(basis, Vector3(p.x, 0.35, p.y)))

	var rock_mesh := Shapes.cube(Vector3(1.2, 1.2, 1.2))
	_add_multimesh(rock_mesh, _material(Color(0.45, 0.44, 0.43)), transforms)


func _scatter_grass() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	var buckets := {}
	for i in 1800:
		var p := _random_on_island(rng, 0.95)
		if not _is_land(p):
			continue
		if Vector3(p.x, 0, p.y).distance_to(FORGE_POS) < SAFE_RADIUS + 8.0:
			continue
		if Vector2(p.x - CAVE_ENTRANCE.x, p.y - CAVE_ENTRANCE.z).length() < 30.0:
			continue
		var biome := _biome_at(p)
		var biome_id := String(biome["id"])
		if biome_id == "water" or biome_id == "ice":
			continue  # no grass on water or snow
		var key := "green"
		if biome_id == "fire":
			key = "dry"
		elif biome_id == "poison":
			key = "purple"
		if not buckets.has(key):
			buckets[key] = []
		var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU))
		buckets[key].append(Transform3D(basis, Vector3(p.x, 0.35, p.y)))

	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.22
	cone.height = 0.7
	var colors := {
		"green": Color(0.3, 0.52, 0.26),
		"dry": Color(0.5, 0.52, 0.24),
		"purple": Color(0.42, 0.3, 0.46),
	}
	for key in buckets:
		_add_multimesh(cone, _material(colors[key]), buckets[key])


## One MultiMesh = hundreds of little objects for the price of one draw call.
func _add_multimesh(mesh: Mesh, mat: Material, transforms: Array) -> void:
	if transforms.is_empty():
		return
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for i in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])
	var node := MultiMeshInstance3D.new()
	node.multimesh = multimesh
	node.material_override = mat
	add_child(node)


func _spawn_ores() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for biome in WorldData.BIOMES:
		var ore_type := "stone"
		var count := 0
		match String(biome["id"]):
			"rock":
				ore_type = "stone"
				count = 50
			"fire":
				ore_type = "copper"
				count = 45
			"plants":
				ore_type = "iron"
				count = 45
			"ice":
				ore_type = "iron"
				count = 30
			"water":
				ore_type = "copper"
				count = 0
			"poison":
				ore_type = "stone"
				count = 8
		for i in count:
			var p := _random_in_biome(rng, biome)
			if Vector3(p.x, 0, p.y).distance_to(FORGE_POS) < SAFE_RADIUS + 10.0:
				continue
			if Vector2(p.x - CAVE_ENTRANCE.x, p.y - CAVE_ENTRANCE.z).length() < 30.0:
				continue
			if p.distance_to(biome["temple_pos"]) < 16.0:
				continue
			var ore = ORE_SCENE.instantiate()
			ore.ore_type = ore_type
			ore.game = self
			ore.position = Vector3(p.x, 0, p.y)
			ore.rotation.y = rng.randf_range(0.0, TAU)
			add_child(ore)


## Wood comes from log piles. A few sit right next to the Forge so you can try
## a wooden weapon immediately, and the forests are full of them.
func _spawn_wood() -> void:
	var near_forge := [
		Vector3(7, 0, 34), Vector3(-12, 0, 27),
		Vector3(15, 0, 19), Vector3(-17, 0, 8),
	]
	for spot in near_forge:
		_add_wood(spot)

	var rng := RandomNumberGenerator.new()
	rng.seed = 31337
	for biome in WorldData.BIOMES:
		var count := 0
		match String(biome["id"]):
			"plants": count = 40
			"ice": count = 12
			"rock": count = 16
			"fire": count = 8
		for i in count:
			var p := _random_in_biome(rng, biome)
			if not _is_land(p):
				continue
			if String(_biome_at(p)["id"]) != String(biome["id"]):
				continue
			if Vector3(p.x, 0, p.y).distance_to(FORGE_POS) < SAFE_RADIUS + 6.0:
				continue
			if Vector2(p.x - CAVE_ENTRANCE.x, p.y - CAVE_ENTRANCE.z).length() < 30.0:
				continue
			if p.distance_to(biome["temple_pos"]) < 16.0:
				continue
			_add_wood(Vector3(p.x, 0, p.y))


func _add_wood(pos: Vector3) -> void:
	var wood = WOOD_SCENE.instantiate()
	wood.game = self
	wood.position = pos
	wood.rotation.y = randf_range(0.0, TAU)
	add_child(wood)


func _spawn_animals() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9182
	var jobs := [
		{"biome": WorldData.BIOMES[0], "kind": "rabbit", "count": 5},
		{"biome": WorldData.BIOMES[2], "kind": "rabbit", "count": 5},
		{"biome": WorldData.BIOMES[0], "kind": "boar", "count": 3},
		{"biome": WorldData.BIOMES[1], "kind": "boar", "count": 3},
		{"biome": WorldData.BIOMES[2], "kind": "boar", "count": 3},
		{"biome": WorldData.BIOMES[2], "kind": "deer", "count": 4},
		{"biome": WorldData.BIOMES[0], "kind": "deer", "count": 3},
		{"biome": WorldData.BIOMES[2], "kind": "fox", "count": 4},
		{"biome": WorldData.BIOMES[0], "kind": "fox", "count": 2},
	]
	for job in jobs:
		var biome: Dictionary = job["biome"]
		for i in int(job["count"]):
			var p := _random_in_biome(rng, biome)
			if not _is_land(p):
				continue
			if Vector3(p.x, 0, p.y).distance_to(FORGE_POS) < SAFE_RADIUS + 12.0:
				continue
			if Vector2(p.x - CAVE_ENTRANCE.x, p.y - CAVE_ENTRANCE.z).length() < 30.0:
				continue
			if p.distance_to(biome["temple_pos"]) < 15.0:
				continue
			var animal = ANIMAL_SCRIPT.new()
			animal.game = self
			animal.animal_kind = String(job["kind"])
			animal.position = Vector3(p.x, 0.2, p.y)
			add_child(animal)


func _spawn_enemies() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for biome in WorldData.BIOMES:
		var count := 4
		if String(biome["id"]) == "poison":
			count = 2
		for i in count:
			var p := Vector2.ZERO
			var tries := 0
			while tries < 20:
				tries += 1
				p = _random_in_biome(rng, biome)
				if p.distance_to(biome["temple_pos"]) > 20.0:
					break
			_make_enemy(biome, Vector3(p.x, 1.0, p.y))


## Creates one monster that belongs to `biome` and cannot leave it.
func _make_enemy(biome: Dictionary, pos: Vector3, night_boost := false) -> Node3D:
	var enemy = ENEMY_SCENE.instantiate()
	enemy.game = self
	enemy.form = String(biome["form"])
	enemy.body_color = biome["mob"]
	enemy.home_center = biome["center"]
	enemy.home_size = biome["size"]
	enemy.has_home = true
	if night_boost:
		enemy.max_hp = float(enemy.max_hp) * 1.6
		enemy.coin_reward = int(enemy.coin_reward) * 2
		enemy.move_speed = float(enemy.move_speed) * 1.15
		enemy.body_color = (biome["mob"] as Color).darkened(0.25)
	enemy.position = pos
	add_child(enemy)
	return enemy


# ============================================================================
#  DAY / NIGHT
# ============================================================================
func _setup_audio() -> void:
	_build_sound_bank()

	music_player = AudioStreamPlayer.new()
	music_player.stream = sfx_streams["music"]
	music_player.volume_db = -22.0
	music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(music_player)
	music_player.finished.connect(func() -> void: music_player.play())
	music_player.play()

	for i in 8:
		var player := AudioStreamPlayer.new()
		player.volume_db = -6.0
		add_child(player)
		sfx_players.append(player)


func play_sound(sound_name: String) -> void:
	if not sfx_streams.has(sound_name) or sfx_players.is_empty():
		return
	var player: AudioStreamPlayer = sfx_players[sfx_index % sfx_players.size()]
	sfx_index += 1
	player.stream = sfx_streams[sound_name]
	player.play()


## Tiny hand-made sound effects, so the game has audio without any extra files.
func _build_sound_bank() -> void:
	var RATE := 22050.0
	sfx_streams["hit"] = _wav_stream(_mix_samples(
		_tone_samples(120.0, 0.16, 0.55, RATE),
		_noise_samples(0.16, 0.35, RATE), 1.0
	))
	sfx_streams["mine"] = _wav_stream(_mix_samples(
		_tone_samples(880.0, 0.12, 0.35, RATE),
		_tone_samples(1500.0, 0.08, 0.25, RATE), 0.8
	))
	sfx_streams["eat"] = _wav_stream(_concat_samples(
		_tone_samples(300.0, 0.08, 0.3, RATE),
		_tone_samples(460.0, 0.10, 0.3, RATE)
	))
	sfx_streams["coin"] = _wav_stream(_concat_samples(
		_tone_samples(900.0, 0.09, 0.3, RATE),
		_tone_samples(1250.0, 0.13, 0.3, RATE)
	))
	sfx_streams["quest"] = _wav_stream(_concat_samples(
		_concat_samples(
			_tone_samples(523.0, 0.12, 0.3, RATE),
			_tone_samples(659.0, 0.12, 0.3, RATE)
		),
		_tone_samples(784.0, 0.2, 0.35, RATE)
	))
	sfx_streams["bow"] = _wav_stream(_mix_samples(
		_noise_samples(0.22, 0.4, RATE),
		_tone_samples(240.0, 0.22, 0.15, RATE), 0.8
	))
	sfx_streams["roar"] = _wav_stream(_mix_samples(
		_tone_samples(78.0, 0.7, 0.45, RATE),
		_noise_samples(0.7, 0.25, RATE), 1.0
	))
	sfx_streams["music"] = _wav_stream(_music_samples(RATE))


func _tone_samples(freq: float, duration: float, volume: float, rate: float) -> PackedFloat32Array:
	var count := int(rate * duration)
	var out := PackedFloat32Array()
	out.resize(count)
	for i in count:
		var t := float(i) / rate
		var envelope := minf(1.0, t / 0.012) * exp(-3.2 * t / duration)
		out[i] = sin(TAU * freq * t) * volume * envelope
	return out


func _noise_samples(duration: float, volume: float, rate: float) -> PackedFloat32Array:
	var count := int(rate * duration)
	var out := PackedFloat32Array()
	out.resize(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in count:
		var t := float(i) / rate
		out[i] = (rng.randf_range(-1.0, 1.0)) * volume * exp(-5.0 * t / duration)
	return out


func _concat_samples(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.append_array(a)
	out.append_array(b)
	return out


func _mix_samples(a: PackedFloat32Array, b: PackedFloat32Array, gain: float) -> PackedFloat32Array:
	var count := maxi(a.size(), b.size())
	var out := PackedFloat32Array()
	out.resize(count)
	for i in count:
		var value := 0.0
		if i < a.size():
			value += a[i]
		if i < b.size():
			value += b[i] * gain
		out[i] = value
	return out


func _music_samples(rate: float) -> PackedFloat32Array:
	var seconds := 12.0
	var out := PackedFloat32Array()
	out.resize(int(rate * seconds))
	var notes := [523.25, 659.25, 783.99, 659.25, 587.33, 698.46, 880.0, 698.46]
	var bass := [130.81, 146.83, 164.81, 196.0]
	for k in 40:
		var freq: float = notes[k % notes.size()]
		var start := int(float(k) * 0.3 * rate)
		var count := int(0.3 * rate)
		for i in count:
			var index := start + i
			if index >= out.size():
				break
			var t := float(i) / rate
			var envelope := minf(1.0, t / 0.02) * exp(-2.4 * t / 0.3)
			out[index] += sin(TAU * freq * t) * 0.10 * envelope
	for k in 10:
		var freq: float = bass[k % bass.size()]
		var start := int(float(k) * 1.2 * rate)
		var count := int(1.2 * rate)
		for i in count:
			var index := start + i
			if index >= out.size():
				break
			var t := float(i) / rate
			var envelope := minf(1.0, t / 0.02) * exp(-2.0 * t / 1.2)
			out[index] += sin(TAU * freq * t) * 0.07 * envelope
	return out


func _wav_stream(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		var value := int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, value)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.stereo = false
	stream.data = data
	return stream


func _setup_weather() -> void:
	weather_node = Node3D.new()
	add_child(weather_node)

	weather_particles = CPUParticles3D.new()
	weather_particles.amount = 600
	weather_particles.lifetime = 1.4
	weather_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	weather_particles.emission_box_extents = Vector3(45, 1, 45)
	weather_particles.direction = Vector3(0, -1, 0)
	weather_particles.spread = 5.0
	weather_particles.gravity = Vector3(0, -18, 0)
	weather_particles.initial_velocity_min = 12.0
	weather_particles.initial_velocity_max = 18.0
	weather_particles.scale_amount_min = 0.7
	weather_particles.scale_amount_max = 1.2
	weather_particles.mesh = Shapes.cube(Vector3(0.035, 0.45, 0.035))
	weather_particles.emitting = false
	weather_particles.visible = false
	weather_node.add_child(weather_particles)
	set_weather("clear")


func set_weather(new_weather: String) -> void:
	weather = new_weather
	weather_timer = randf_range(50.0, 100.0)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	weather_darkness = 0.0

	match weather:
		"rain":
			mat.albedo_color = Color(0.55, 0.72, 1.0)
			mat.emission_enabled = true
			mat.emission = Color(0.3, 0.45, 0.8)
			weather_particles.amount = 650
			weather_particles.lifetime = 1.4
			weather_particles.gravity = Vector3(0, -20, 0)
			weather_particles.initial_velocity_min = 15.0
			weather_particles.initial_velocity_max = 22.0
			weather_particles.scale_amount_min = 0.7
			weather_particles.scale_amount_max = 1.1
			weather_darkness = 0.12
		"storm":
			mat.albedo_color = Color(0.4, 0.55, 0.85)
			mat.emission_enabled = true
			mat.emission = Color(0.2, 0.3, 0.6)
			weather_particles.amount = 900
			weather_particles.lifetime = 1.2
			weather_particles.gravity = Vector3(0, -26, 0)
			weather_particles.initial_velocity_min = 22.0
			weather_particles.initial_velocity_max = 30.0
			weather_particles.scale_amount_min = 0.9
			weather_particles.scale_amount_max = 1.4
			weather_darkness = 0.35
		"snow":
			mat.albedo_color = Color(1.0, 1.0, 1.0)
			mat.emission_enabled = true
			mat.emission = Color(0.65, 0.75, 0.9)
			weather_particles.amount = 450
			weather_particles.lifetime = 3.5
			weather_particles.gravity = Vector3(0, -3, 0)
			weather_particles.initial_velocity_min = 2.0
			weather_particles.initial_velocity_max = 5.0
			weather_particles.scale_amount_min = 1.2
			weather_particles.scale_amount_max = 2.0
			weather_darkness = 0.08
		_:
			weather_darkness = 0.0

	weather_particles.material_override = mat
	weather_particles.visible = weather != "clear"
	if weather != "clear":
		weather_particles.restart()
		weather_particles.emitting = true
	else:
		weather_particles.emitting = false
	if game_ready:
		_log("Weather: %s." % weather_name())


func weather_name() -> String:
	match weather:
		"rain": return "Rain"
		"storm": return "Storm"
		"snow": return "Snow"
		_: return "Clear"


func _setup_day_night() -> void:
	sun = get_node_or_null("Sun")
	world_env = get_node_or_null("WorldEnvironment")
	if world_env != null and world_env.environment != null:
		var sky := world_env.environment.sky
		if sky != null and sky.sky_material is ProceduralSkyMaterial:
			sky_material = sky.sky_material
	_update_time_of_day()


func _update_time_of_day() -> void:
	# sun_height is +1 at noon, 0 at sunrise/sunset, -1 at midnight.
	var sun_height := sin((time_of_day - 0.25) * TAU)
	var daylight := clampf(sun_height, 0.0, 1.0)
	var sunset := clampf(1.0 - absf(sun_height) * 2.5, 0.0, 1.0)

	if sky_material != null:
		var top := NIGHT_SKY_TOP.lerp(DAY_SKY_TOP, smoothstep(0.0, 0.35, sun_height))
		top = top.lerp(SUNSET_SKY_TOP, sunset * 0.8)
		var horizon := NIGHT_SKY_HORIZON.lerp(DAY_SKY_HORIZON, smoothstep(0.0, 0.3, sun_height))
		horizon = horizon.lerp(SUNSET_SKY_HORIZON, sunset * 0.8)
		sky_material.sky_top_color = top
		sky_material.sky_horizon_color = horizon
		sky_material.ground_horizon_color = horizon
		sky_material.ground_bottom_color = horizon.darkened(0.45)

	if world_env != null and world_env.environment != null:
		var env := world_env.environment
		env.ambient_light_energy = 0.42 + 0.4 * daylight
		env.fog_density = 0.0004 + 0.0008 * (1.0 - daylight)
		if sky_material != null:
			env.fog_light_color = sky_material.sky_horizon_color

	if sun != null:
		sun.light_energy = 0.18 + 1.1 * daylight
		var warm := Color(1.0, 0.62, 0.35)
		var noon := Color(1.0, 0.97, 0.9)
		var moon := Color(0.55, 0.66, 1.0)
		var color := warm.lerp(noon, smoothstep(0.0, 0.5, sun_height))
		color = color.lerp(moon, 1.0 - smoothstep(-0.1, 0.2, sun_height))
		sun.light_color = color
		# Keep the light above the world both day and night (sun, then moon).
		sun.rotation_degrees = Vector3(-18.0 - 70.0 * absf(sun_height), -35.0, 0.0)

	# Night = the sun is below the horizon.
	var night_now := sun_height < -0.02
	if night_now != is_night:
		_set_night(night_now)


func _set_night(night: bool) -> void:
	is_night = night
	if is_night:
		_spawn_night_monsters()
		_log("Night falls! %d extra monsters crawl out of the dark." % night_monsters.size())
	else:
		_clear_night_monsters()
		_log("The sun rises. The night monsters retreat.")


func _spawn_night_monsters() -> void:
	_clear_night_monsters()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for biome in WorldData.BIOMES:
		for i in NIGHT_EXTRA_MONSTERS:
			var p := _random_in_biome(rng, biome)
			if Vector3(p.x, 0, p.y).distance_to(FORGE_POS) < 80.0:
				continue
			# Do not pop a monster right on top of the player.
			if player != null and Vector3(p.x, 0, p.y).distance_to(player.global_position) < 40.0:
				continue
			night_monsters.append(_make_enemy(biome, Vector3(p.x, 1.0, p.y), true))


func _clear_night_monsters() -> void:
	for monster in night_monsters:
		if is_instance_valid(monster):
			monster.queue_free()
	night_monsters.clear()


func clock_text() -> String:
	var total_minutes := int(time_of_day * 24.0 * 60.0)
	var hours := int(total_minutes / 60.0) % 24
	var minutes := total_minutes % 60
	return "Day %d  ·  %02d:%02d" % [day_count, hours, minutes]


func _spawn_bosses() -> void:
	for biome in WorldData.BIOMES:
		var data: Dictionary = biome["boss"]
		var boss = BOSS_SCENE.instantiate()
		boss.boss_name = String(data["name"])
		boss.max_hp = float(data["hp"])
		boss.move_speed = float(data["speed"])
		boss.touch_damage = float(data["damage"])
		boss.coin_reward = int(data["coins"])
		boss.ability = String(data["ability"])
		boss.body_color = data["color"]
		boss.eye_color = data["eye"]
		boss.stone_key = String(biome["stone"])
		boss.stone_name = String(biome["stone_name"])
		boss.biome_id = String(biome["id"])
		boss.game = self
		boss.home = Vector3(biome["temple_pos"].x, 0, biome["temple_pos"].y)
		boss.arena_radius = WorldData.ARENA_RADIUS
		boss.scale = Vector3.ONE * float(data["scale"])
		boss.position = boss.home + Vector3(0, 2.0, 0)
		add_child(boss)
		bosses.append(boss)


# ============================================================================
#  PLAYER + HUD
# ============================================================================
func _spawn_player() -> void:
	player = PLAYER_SCENE.instantiate()
	player.game = self
	player.position = START_POS
	add_child(player)


func _build_hud() -> void:
	hud = HUD_SCRIPT.new()
	hud.game = self
	add_child(hud)


# ============================================================================
#  EVERY FRAME
# ============================================================================
func _process(delta: float) -> void:
	if player == null:
		return

	in_cave = player.global_position.y < -20.0
	near_forge = not in_cave and not in_dive and not in_final and not in_sky and player.global_position.distance_to(FORGE_POS) < INTERACT_RANGE
	near_dive_spot = not in_cave and not in_dive and not in_final and not in_sky and Vector2(
		player.global_position.x - DIVE_SPOT.x,
		player.global_position.z - DIVE_SPOT.z
	).length() < 6.0
	near_dive_exit = in_dive and Vector2(
		player.global_position.x - DIVE_EXIT_PAD.x,
		player.global_position.z - DIVE_EXIT_PAD.z
	).length() < 4.5
	near_final_portal = not in_cave and not in_dive and not in_final and not in_sky and Vector2(
		player.global_position.x - FINAL_PORTAL_POS.x,
		player.global_position.z - FINAL_PORTAL_POS.z
	).length() < 5.0
	near_final_exit = in_final and Vector2(
		player.global_position.x - FINAL_EXIT_PAD.x,
		player.global_position.z - FINAL_EXIT_PAD.z
	).length() < 5.0
	near_sky_portal = not in_cave and not in_dive and not in_final and not in_sky and Vector2(
		player.global_position.x - SKY_PORTAL_POS.x,
		player.global_position.z - SKY_PORTAL_POS.z
	).length() < 5.0
	near_sky_exit = in_sky and Vector2(
		player.global_position.x - SKY_EXIT_PAD.x,
		player.global_position.z - SKY_EXIT_PAD.z
	).length() < 5.0
	if final_portal_light != null:
		final_portal_light.light_energy = 4.0 if final_portal_open() else 0.5
	if sky_portal_light != null:
		sky_portal_light.light_energy = 3.5 if sky_portal_open() else 0.5
	if in_sky and player.global_position.y < SKY_ORIGIN.y - 25.0:
		player.global_position = SKY_ORIGIN + SKY_ARRIVAL
		player.velocity = Vector3.ZERO
		_log("The clouds catch you and carry you back to the island.")

	if in_dive:
		breath = maxf(0.0, breath - 6.0 * delta)
		if breath <= 0.0:
			health = maxf(0.0, health - 4.0 * delta)
			if health <= 0.0:
				_knock_out()
	else:
		breath = minf(100.0, breath + 25.0 * delta)
	near_cave_entrance = not in_cave and not in_dive and not in_final and Vector2(
		player.global_position.x - CAVE_ENTRANCE.x,
		player.global_position.z - CAVE_ENTRANCE.z
	).length() < 7.0
	near_cave_exit = in_cave and Vector2(
		player.global_position.x - CAVE_EXIT_PAD.x,
		player.global_position.z - CAVE_EXIT_PAD.z
	).length() < 4.5

	# Standing in an acid pool in the Acid Cave stings you.
	if in_cave and underground_biome_at(player.global_position) == "acid":
		for offset in ACID_POOL_OFFSETS:
			var pool_pos: Vector3 = CAVE_ORIGIN + ACID_CENTER + offset
			if Vector2(
				player.global_position.x - pool_pos.x,
				player.global_position.z - pool_pos.z
			).length() < 4.0:
				apply_dot(1.2, 2.0)

	# Which chest is close enough to open?
	near_chest = -1
	if not in_cave and not in_dive and not in_final and not in_sky:
		var closest_chest := 3.2
		for i in chests.size():
			var chest_pos: Vector3 = chests[i]["pos"]
			var distance := Vector2(
				player.global_position.x - chest_pos.x,
				player.global_position.z - chest_pos.z
			).length()
			if distance < closest_chest:
				closest_chest = distance
				near_chest = i

	near_trader = false
	if trader != null and is_instance_valid(trader) and not in_cave and not in_dive and not in_final and not in_sky:
		near_trader = Vector2(
			player.global_position.x - trader.global_position.x,
			player.global_position.z - trader.global_position.z
		).length() < 5.5

	near_wolf = false
	near_tamed_wolf = false
	if wolf != null and is_instance_valid(wolf) and not in_cave and not in_dive and not in_final and not in_sky:
		var wolf_distance := Vector2(
			player.global_position.x - wolf.global_position.x,
			player.global_position.z - wolf.global_position.z
		).length()
		if wolf_tamed:
			near_tamed_wolf = wolf_distance < 4.5
		else:
			near_wolf = wolf_distance < 6.0

	near_quest_board = false
	if not in_cave and not in_dive and not in_final and not in_sky:
		near_quest_board = Vector2(
			player.global_position.x - QUEST_BOARD_POS.x,
			player.global_position.z - QUEST_BOARD_POS.z
		).length() < 5.0

	near_campfire = false
	near_farm_plot = -1
	near_fishing = false
	if not in_cave and not in_dive and not in_final and not in_sky:
		near_campfire = Vector2(
			player.global_position.x - CAMPFIRE_POS.x,
			player.global_position.z - CAMPFIRE_POS.z
		).length() < 5.0

		var closest_plot := 3.8
		for i in FARM_PLOTS.size():
			var plot_pos: Vector3 = FARM_PLOTS[i]
			var d := Vector2(
				player.global_position.x - plot_pos.x,
				player.global_position.z - plot_pos.z
			).length()
			if d < closest_plot:
				closest_plot = d
				near_farm_plot = i

		near_fishing = Vector2(
			player.global_position.x - FISHING_POS.x,
			player.global_position.z - FISHING_POS.z
		).length() < 5.5
		fishing_cooldown = maxf(0.0, fishing_cooldown - delta)

	near_farm_animal = null
	if not in_cave and not in_dive and not in_final:
		var closest_animal := 3.8
		for animal in farm_animals:
			if animal == null or not is_instance_valid(animal):
				continue
			var d := Vector2(
				player.global_position.x - animal.global_position.x,
				player.global_position.z - animal.global_position.z
			).length()
			if d < closest_animal:
				closest_animal = d
				near_farm_animal = animal

	_update_farm(delta)

	near_treasure = -1
	if in_cave or in_dive:
		var closest_treasure := 4.5
		for i in treasures.size():
			var treasure: Dictionary = treasures[i]
			if bool(treasure["found"]):
				continue
			var treasure_pos: Vector3 = treasure["pos"]
			var d := Vector2(
				player.global_position.x - treasure_pos.x,
				player.global_position.z - treasure_pos.z
			).length()
			if d < closest_treasure:
				closest_treasure = d
				near_treasure = i

	near_villager = null
	if not in_cave and not in_dive and not in_final and not in_sky:
		var closest_villager := 4.5
		for villager in villagers:
			if villager == null or not is_instance_valid(villager):
				continue
			var d := Vector2(
				player.global_position.x - villager.global_position.x,
				player.global_position.z - villager.global_position.z
			).length()
			if d < closest_villager:
				closest_villager = d
				near_villager = villager

	if hud.forge_panel.visible:
		if not near_forge or Input.is_action_just_pressed("ui_cancel"):
			hud.toggle_forge()
	if hud.design_panel.visible:
		if not near_forge or Input.is_action_just_pressed("ui_cancel"):
			hud.close_design()
	if hud.shop_panel.visible:
		if not near_trader or Input.is_action_just_pressed("ui_cancel"):
			hud.close_shop()
	if hud.quest_panel.visible:
		if not near_quest_board or Input.is_action_just_pressed("ui_cancel"):
			hud.close_quests()
	if hud.cooking_panel.visible:
		if not near_campfire or Input.is_action_just_pressed("ui_cancel"):
			hud.close_cooking()
	if hud.chest_panel.visible:
		if near_chest != hud.open_chest or Input.is_action_just_pressed("ui_cancel"):
			hud.close_chest()

	if Input.is_action_just_pressed("interact"):
		if hud.shop_panel.visible:
			hud.close_shop()
		elif hud.quest_panel.visible:
			hud.close_quests()
		elif hud.cooking_panel.visible:
			hud.close_cooking()
		elif hud.design_panel.visible:
			hud.close_design()
		elif hud.inventory_panel.visible:
			hud.toggle_inventory()
		elif near_chest >= 0:
			hud.toggle_chest(near_chest)
		elif near_forge:
			hud.toggle_forge()
		elif near_trader:
			hud.toggle_shop()
		elif near_villager != null:
			talk_to_villager(near_villager)
		elif near_wolf:
			tame_wolf()
		elif near_tamed_wolf:
			feed_wolf()
		elif near_campfire:
			hud.toggle_cooking()
		elif near_farm_plot >= 0:
			use_farm_plot(near_farm_plot)
		elif near_fishing:
			fish()
		elif near_farm_animal != null:
			near_farm_animal.collect()
		elif near_treasure >= 0:
			collect_treasure(near_treasure)
		elif near_sky_portal:
			if sky_portal_open():
				enter_sky()
			else:
				_log("The Sky Portal is sealed. Beat the Eight-Stone Guardian first!")
		elif near_sky_exit:
			leave_sky()
		elif near_final_portal:
			if final_portal_open():
				enter_final()
			else:
				_log("The final portal is sealed. Infuse all eight magic stones first!")
		elif near_final_exit:
			leave_final()
		elif near_dive_exit:
			leave_dive()
		elif near_dive_spot:
			enter_dive()
		elif near_quest_board:
			hud.toggle_quests()
		elif near_cave_entrance:
			enter_cave()
		elif near_cave_exit:
			leave_cave()

	if Input.is_action_just_pressed("teleport"):
		teleport_to_forge()

	# --- day / night ------------------------------------------------------
	time_of_day += delta / DAY_LENGTH
	if time_of_day >= 1.0:
		time_of_day -= 1.0
		day_count += 1
	_update_time_of_day()

	# Weather: clear, rain, storm or snow. It follows you above ground.
	weather_timer -= delta
	if weather_timer <= 0.0:
		var choices := ["clear", "rain", "storm", "snow"]
		set_weather(choices[randi() % choices.size()])
	if weather_node != null and player != null:
		weather_node.global_position = player.global_position + Vector3(0, 26, 0)
		weather_node.visible = not in_cave and not in_dive and not in_final and not in_sky
	if weather_particles != null:
		weather_particles.emitting = not in_cave and not in_dive and not in_final and not in_sky and weather != "clear"
	if weather_darkness > 0.0:
		if sun != null:
			sun.light_energy *= 1.0 - weather_darkness
		if world_env != null and world_env.environment != null:
			world_env.environment.fog_density += weather_darkness * 0.0015

	# Food bar: running makes you hungrier. At zero food you stop healing.
	var hunger_drain := 0.22
	if Input.is_action_pressed("sprint"):
		hunger_drain = 0.38
	hunger = maxf(0.0, hunger - hunger_drain * delta)
	if hunger <= 0.0:
		if not hunger_warned:
			hunger_warned = true
			_log("You are very hungry! Eat berries (F) or buy food from the trader.")
	else:
		hunger_warned = false

	regen_delay = maxf(0.0, regen_delay - delta)
	if regen_delay <= 0.0 and health < MAX_HEALTH and dot_time <= 0.0 and hunger > 0.0:
		health = minf(MAX_HEALTH, health + 3.0 * delta)

	if hud != null and not hud.menu_open():
		if Input.is_action_just_pressed("eat"):
			eat_food()
		if Input.is_action_just_pressed("heal"):
			drink_heal_potion()
		if Input.is_action_just_pressed("speed_potion"):
			drink_speed_potion()
		if Input.is_action_just_pressed("wolf_stay"):
			toggle_wolf_stay()
		if Input.is_action_just_pressed("wolf_attack"):
			command_wolf_attack()

	if dot_time > 0.0:
		dot_time -= delta
		dot_accum += delta
		if dot_accum >= 1.0:
			dot_accum -= 1.0
			damage_player(dot_dps, false)

	_keep_player_on_island()


## The island is round, so the player must not walk off the edge.
func _keep_player_on_island() -> void:
	var flat := Vector2(player.global_position.x, player.global_position.z)
	var limit := WorldData.WORLD_RADIUS - 1.5
	if flat.length() > limit:
		var fixed := flat.normalized() * limit
		player.global_position = Vector3(fixed.x, player.global_position.y, fixed.y)
		player.velocity.x = 0.0
		player.velocity.z = 0.0


## Keys that are typed rather than mapped: "!" opens the bag (any keyboard
## layout), and "I" works too as a backup.
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key := event as InputEventKey
	var typed := ""
	if key.unicode > 0:
		typed = String.chr(key.unicode)
	if typed == "!" or typed == "i" or typed == "I" or (key.physical_keycode == KEY_1 and key.shift_pressed):
		if hud != null:
			hud.toggle_inventory()
		get_viewport().set_input_as_handled()
		return

	# 1 / 2 / 3 choose which hand you use.
	if player == null:
		return
	if typed == "1":
		player.select_hand(0)
		get_viewport().set_input_as_handled()
	elif typed == "2":
		player.select_hand(1)
		get_viewport().set_input_as_handled()
	elif typed == "3":
		player.select_hand(2)
		get_viewport().set_input_as_handled()


# ============================================================================
#  PLAYER ACTIONS
# ============================================================================
func shoot_arrow(origin: Vector3, direction: Vector3, damage: float) -> void:
	if direction.length() < 0.01:
		return
	var arrow = ARROW_SCRIPT.new()
	arrow.game = self
	arrow.damage = damage
	arrow.velocity = direction.normalized() * 55.0
	if player != null:
		arrow.shooter_rid = player.get_rid()
	add_child(arrow)
	arrow.global_position = origin
	arrow.look_at(origin + direction.normalized() * 2.0, Vector3.UP)


func teleport_to_forge() -> void:
	player.global_position = FORGE_POS + Vector3(0, 1.4, 7.0)
	player.velocity = Vector3.ZERO
	in_cave = false
	in_thunder = false
	in_poison = false
	in_dive = false
	in_final = false
	in_sky = false
	breath = 100.0
	_log("Whoosh! You teleported to the Forge.")


func eat_food() -> void:
	if hunger >= MAX_HUNGER:
		_log("You are not hungry yet.")
		return
	if count_item("bread") > 0:
		remove_item("bread", 1)
		play_sound("eat")
		hunger = minf(MAX_HUNGER, hunger + 80.0)
		_log("You ate bread. Food: %d/100." % int(hunger))
		return
	if count_item("cooked_meat") > 0:
		remove_item("cooked_meat", 1)
		play_sound("eat")
		hunger = minf(MAX_HUNGER, hunger + 70.0)
		_log("You ate cooked meat. Food: %d/100." % int(hunger))
		return
	if count_item("carrot_soup") > 0:
		remove_item("carrot_soup", 1)
		play_sound("eat")
		hunger = minf(MAX_HUNGER, hunger + 65.0)
		health = minf(MAX_HEALTH, health + 10.0)
		_log("You ate carrot soup. Food: %d/100." % int(hunger))
		return
	if count_item("cooked_fish") > 0:
		remove_item("cooked_fish", 1)
		hunger = minf(MAX_HUNGER, hunger + 65.0)
		_log("You ate cooked fish. Food: %d/100." % int(hunger))
		return
	if count_item("berry_jam") > 0:
		remove_item("berry_jam", 1)
		hunger = minf(MAX_HUNGER, hunger + 55.0)
		health = minf(MAX_HEALTH, health + 10.0)
		_log("You ate berry jam. Food: %d/100." % int(hunger))
		return
	if count_item("meat") > 0:
		remove_item("meat", 1)
		hunger = minf(MAX_HUNGER, hunger + 50.0)
		_log("You ate meat. Food: %d/100." % int(hunger))
		return
	if count_item("fish") > 0:
		remove_item("fish", 1)
		hunger = minf(MAX_HUNGER, hunger + 40.0)
		_log("You ate fish. Food: %d/100." % int(hunger))
		return
	if count_item("egg") > 0:
		remove_item("egg", 1)
		hunger = minf(MAX_HUNGER, hunger + 20.0)
		_log("You ate an egg. Food: %d/100." % int(hunger))
		return
	if count_item("milk") > 0:
		remove_item("milk", 1)
		hunger = minf(MAX_HUNGER, hunger + 25.0)
		_log("You drank milk. Food: %d/100." % int(hunger))
		return
	if count_item("berry") <= 0:
		_log("No food left! Hunt an animal or buy berries from the trader.")
		return
	remove_item("berry", 1)
	hunger = minf(MAX_HUNGER, hunger + 35.0)
	_log("You ate a berry. Food: %d/100." % int(hunger))


func _update_farm(delta: float) -> void:
	for i in farm_state.size():
		var plot: Dictionary = farm_state[i]
		if String(plot["state"]) == "growing":
			plot["timer"] = maxf(0.0, float(plot["timer"]) - delta)
			if float(plot["timer"]) <= 0.0:
				plot["state"] = "ready"
				_update_farm_visual(i)


func _update_farm_visual(index: int) -> void:
	if index < 0 or index >= farm_plants.size():
		return
	var plot: Dictionary = farm_state[index]
	var plant: Node3D = farm_plants[index]
	if String(plot["state"]) == "empty":
		plant.visible = false
	else:
		plant.visible = true
		if String(plot["state"]) == "growing":
			var growth := 1.0 - float(plot["timer"]) / FARM_GROW_TIME
			plant.scale = Vector3.ONE * clampf(0.35 + growth * 0.65, 0.35, 1.0)
		else:
			plant.scale = Vector3.ONE


func use_farm_plot(index: int) -> void:
	if index < 0 or index >= farm_state.size():
		return
	var plot: Dictionary = farm_state[index]
	var state := String(plot["state"])

	var crop := String(FARM_CROPS[index])
	var seed_item := String(CROP_SEEDS.get(crop, crop))
	if state == "empty":
		if count_item(seed_item) <= 0:
			_log("Plant %s! You need %s to start this plot." % [
				CROP_NAMES.get(crop, crop), item_label(seed_item).to_lower()
			])
			return
		remove_item(seed_item, 1)
		plot["state"] = "growing"
		plot["timer"] = FARM_GROW_TIME
		play_sound("mine")
		_update_farm_visual(index)
		_log("You planted %s. It will grow in %d seconds." % [
			CROP_NAMES.get(crop, crop), int(FARM_GROW_TIME)
		])
	elif state == "ready":
		add_item(crop, 3)
		plot["state"] = "empty"
		plot["timer"] = 0.0
		play_sound("coin")
		_update_farm_visual(index)
		_log("You harvested 3 %s!" % CROP_NAMES.get(crop, crop))
	else:
		_log("Still growing: %d seconds left." % int(ceil(float(plot["timer"]))))


func fish() -> void:
	if fishing_cooldown > 0.0:
		_log("Wait for the water to settle...")
		return
	fishing_cooldown = 2.0
	add_item("fish", 1)
	play_sound("coin")
	_log("You caught a fish!")


func collect_treasure(index: int) -> void:
	if index < 0 or index >= treasures.size():
		return
	var treasure: Dictionary = treasures[index]
	if bool(treasure["found"]):
		return
	treasure["found"] = true
	treasures_found[String(treasure["id"])] = true
	add_coins(int(treasure["coins"]))
	var loot: Dictionary = treasure["items"]
	for item in loot:
		add_item(String(item), int(loot[item]))
	_open_treasure_visual(treasure)
	play_sound("quest")
	_log("Secret vault! You found %d coins and hidden supplies." % int(treasure["coins"]))


func _open_treasure_visual(treasure: Dictionary) -> void:
	var lid = treasure.get("lid")
	if lid is Node3D:
		(lid as Node3D).rotation.x = -0.9
		(lid as Node3D).position.y += 0.25
	var marker = treasure.get("marker")
	if marker is Node3D:
		(marker as Node3D).visible = false


func cook(index: int) -> void:
	if index < 0 or index >= COOKING_RECIPES.size():
		return
	var recipe: Dictionary = COOKING_RECIPES[index]
	if count_item(String(recipe["need"])) < int(recipe["amount"]):
		_log("You need %d %s for that." % [
			int(recipe["amount"]), item_label(String(recipe["need"])).to_lower()
		])
		return
	remove_item(String(recipe["need"]), int(recipe["amount"]))
	add_item(String(recipe["id"]), 1)
	play_sound("eat")
	_log("Cooked %s. %s" % [String(recipe["name"]).to_lower(), String(recipe["desc"])])
	if hud != null:
		hud.refresh_cooking()


func drink_heal_potion() -> void:
	if count_item("potion_heal") <= 0:
		_log("No healing potions! The wandering trader sells them.")
		return
	if health >= MAX_HEALTH:
		_log("You are already at full health.")
		return
	remove_item("potion_heal", 1)
	play_sound("eat")
	health = minf(MAX_HEALTH, health + 40.0)
	regen_delay = 0.0
	_log("You drank a healing potion! Health: %d/100." % int(health))


func drink_speed_potion() -> void:
	if count_item("potion_speed") <= 0:
		_log("No speed potions! The wandering trader sells them.")
		return
	remove_item("potion_speed", 1)
	play_sound("eat")
	if player != null:
		player.apply_speed(10.0)
	_log("Speed potion! You run faster for 10 seconds.")


func damage_player(amount: float, flash := true) -> void:
	if health <= 0.0:
		return
	# The Forge is a safe zone: nothing can hurt you inside the ring.
	if in_safe_zone():
		dot_time = 0.0
		return
	# A shield in hand, with left click held, blocks most of the hit.
	if player != null and player.is_blocking():
		amount *= 0.4
	# Your armour makes every piece of damage a little smaller.
	var armour_reduction := clampf(float(armour_total()) / 100.0, 0.0, 0.6)
	amount *= 1.0 - armour_reduction
	health = maxf(0.0, health - amount)
	regen_delay = 6.0
	if flash:
		hud.flash_damage()
	if health <= 0.0:
		_knock_out()


func _knock_out() -> void:
	health = MAX_HEALTH
	dot_time = 0.0
	coins = maxi(0, coins - COINS_LOST_ON_KNOCKOUT)
	teleport_to_forge()
	_log("You were knocked out. The Forge healed you (-%d coins)." % COINS_LOST_ON_KNOCKOUT)


## Burning / poison: damage every second for a while.
func apply_dot(seconds: float, damage_per_second: float) -> void:
	dot_time = maxf(dot_time, seconds)
	dot_dps = damage_per_second
	dot_accum = 0.0
	regen_delay = 6.0


func add_item(item: String, amount: int) -> int:
	var leftover := _add_to_slots(slots, item, amount)
	if leftover > 0:
		_log("Your bag is full! %d %s did not fit." % [leftover, item_label(item)])
	return leftover


func add_coins(amount: int) -> void:
	coins += amount


func count_item(item: String) -> int:
	return _count_in(slots, item)


func remove_item(item: String, amount: int) -> bool:
	return _remove_from(slots, item, amount)


# ============================================================================
#  SLOT HELPERS (works for the bag and for chests)
# ============================================================================
func _reset_slots() -> void:
	slots.clear()
	for i in SLOT_COUNT:
		slots.append(null)


## Adds items into existing stacks first, then empty slots.
## Returns how many did NOT fit.
func _add_to_slots(target: Array, item: String, amount: int) -> int:
	var remaining := amount
	for slot in target:
		if slot != null and String(slot["item"]) == item and int(slot["count"]) < STACK_LIMIT:
			var put := mini(STACK_LIMIT - int(slot["count"]), remaining)
			slot["count"] = int(slot["count"]) + put
			remaining -= put
			if remaining <= 0:
				return 0
	for i in target.size():
		if target[i] == null:
			var put := mini(STACK_LIMIT, remaining)
			target[i] = {"item": item, "count": put}
			remaining -= put
			if remaining <= 0:
				return 0
	return remaining


func _count_in(target: Array, item: String) -> int:
	var total := 0
	for slot in target:
		if slot != null and String(slot["item"]) == item:
			total += int(slot["count"])
	return total


func _remove_from(target: Array, item: String, amount: int) -> bool:
	if _count_in(target, item) < amount:
		return false
	var left := amount
	for i in target.size():
		var slot = target[i]
		if slot != null and String(slot["item"]) == item:
			var take := mini(int(slot["count"]), left)
			slot["count"] = int(slot["count"]) - take
			left -= take
			if int(slot["count"]) <= 0:
				target[i] = null
			if left <= 0:
				break
	return true


func item_label(item: String) -> String:
	match item:
		"stone": return "Stone"
		"wood": return "Wood"
		"hardwood": return "Hardwood"
		"copper": return "Copper"
		"iron": return "Iron"
		"wheat": return "Wheat"
		"carrot": return "Carrot"
		"wheat_seed": return "Wheat Seeds"
		"carrot_seed": return "Carrot Seeds"
		"egg": return "Egg"
		"milk": return "Milk"
		"wool": return "Wool"
		"bread": return "Bread"
		"carrot_soup": return "Carrot Soup"
		"sky_crystal": return "Sky Crystal"
		"berry": return "Berries"
		"meat": return "Meat"
		"cooked_meat": return "Cooked Meat"
		"berry_jam": return "Berry Jam"
		"fish": return "Fish"
		"cooked_fish": return "Cooked Fish"
		"uranium": return "Uranium"
		"potion_heal": return "Healing Potion"
		"potion_speed": return "Speed Potion"
	for biome in WorldData.BIOMES:
		if String(biome["stone"]) == item:
			return "%s Stone" % String(biome["element"])
	if String(WorldData.THUNDER["stone"]) == item:
		return "Thunder Stone"
	if String(WorldData.URANIUM["stone"]) == item:
		return "Uranium Stone"
	return item


func item_color(item: String) -> Color:
	match item:
		"stone": return Color(0.8, 0.8, 0.84)
		"wood": return Color(0.72, 0.47, 0.24)
		"hardwood": return Color(0.55, 0.34, 0.18)
		"copper": return Color(0.95, 0.62, 0.34)
		"wheat": return Color(0.95, 0.82, 0.3)
		"carrot": return Color(0.95, 0.48, 0.16)
		"wheat_seed": return Color(0.8, 0.7, 0.3)
		"carrot_seed": return Color(0.9, 0.45, 0.2)
		"egg": return Color(0.95, 0.9, 0.75)
		"milk": return Color(0.95, 0.95, 1.0)
		"wool": return Color(0.9, 0.9, 0.92)
		"bread": return Color(0.85, 0.6, 0.28)
		"carrot_soup": return Color(0.95, 0.55, 0.22)
		"sky_crystal": return Color(0.45, 0.9, 1.0)
		"iron": return Color(0.84, 0.88, 0.96)
		"berry": return Color(0.9, 0.25, 0.3)
		"meat": return Color(0.82, 0.42, 0.32)
		"cooked_meat": return Color(0.95, 0.62, 0.3)
		"berry_jam": return Color(0.85, 0.25, 0.45)
		"fish": return Color(0.55, 0.78, 0.95)
		"cooked_fish": return Color(0.95, 0.82, 0.55)
		"uranium": return Color(0.55, 0.95, 0.3)
		"potion_heal": return Color(0.95, 0.35, 0.45)
		"potion_speed": return Color(0.45, 0.9, 1.0)
	for biome in WorldData.BIOMES:
		if String(biome["stone"]) == item:
			return biome["glow"]
	if String(WorldData.THUNDER["stone"]) == item:
		return WorldData.THUNDER["glow"]
	if String(WorldData.URANIUM["stone"]) == item:
		return WorldData.URANIUM["glow"]
	return Color.WHITE


func stone_count() -> int:
	var total := 0
	for key in WorldData.STONE_KEYS:
		total += count_item(String(key))
	return total


func temples_beaten() -> int:
	return defeated_temples.size()


## Called by a boss when it dies.
func on_boss_defeated(biome_id: String, stone_key: String, stone_name: String) -> void:
	defeated_temples[biome_id] = true
	add_item(stone_key, 1)
	_log("%s defeated! You got the %s." % [biome_id.capitalize(), stone_name])


# ============================================================================
#  THE FORGE (crafting)
# ============================================================================
func can_afford(recipe: Dictionary) -> bool:
	var needed: String = recipe.get("needs", "")
	if needed != "" and not crafted.has(needed):
		return false
	if not recipe.get("repeat", false) and crafted.has(recipe["id"]):
		return false
	for item in recipe["cost"]:
		if String(item) == "coins":
			if coins < int(recipe["cost"][item]):
				return false
		elif count_item(String(item)) < int(recipe["cost"][item]):
			return false
	return true


func recipe_cost_text(recipe: Dictionary) -> String:
	var parts := PackedStringArray()
	for item in recipe["cost"]:
		parts.append("%d %s" % [int(recipe["cost"][item]), _pretty_item(item)])
	return ", ".join(parts)


## Finds one material in WEAPON_METALS ("wood", "copper" or "iron").
func material_data(id: String) -> Dictionary:
	for material in WEAPON_METALS:
		if String(material["id"]) == id:
			return material
	return {}


func material_color(id: String) -> Color:
	var material := material_data(id)
	return material.get("color", Color.WHITE) as Color


# ============================================================================
#  DRAWING YOUR OWN WEAPON
# ============================================================================
const DRAW_CELL_METERS := 0.09


## Works out the price and the power of a drawing from its SIZE and MATERIALS.
## Every square stores the material it is painted with, so a weapon can have a
## wooden handle and an iron blade.
func weapon_plan(cells: Dictionary) -> Dictionary:
	if cells.is_empty():
		return {}

	var min_row := 9999
	var max_row := -1
	var per_row := {}
	var counts := {}
	for cell in cells:
		min_row = mini(min_row, int(cell.y))
		max_row = maxi(max_row, int(cell.y))
		per_row[cell.y] = int(per_row.get(cell.y, 0)) + 1
		var material_id := _cell_material(cells[cell])
		counts[material_id] = int(counts.get(material_id, 0)) + 1

	var thickness := 0
	for row in per_row:
		thickness = maxi(thickness, int(per_row[row]))

	var rows := max_row - min_row + 1
	var filled := cells.size()

	# Price: every material is paid separately (half a square each).
	var costs := {}
	var total_metal := 0
	for material_id in counts:
		var need := maxi(1, ceili(float(counts[material_id]) * 0.5))
		costs[material_id] = need
		total_metal += need

	# Damage: each square adds its own material's strength, so more iron = harder.
	var strength := 0.0
	for material_id in counts:
		var material := material_data(String(material_id))
		strength += float(counts[material_id]) * float(material.get("draw_mult", 1.0))
	var base_damage := 5.0 + float(rows) * 1.0 + float(thickness) * 1.2

	return {
		"filled": filled,
		"rows": rows,
		"thickness": thickness,
		"height_m": float(rows) * DRAW_CELL_METERS,
		"thickness_m": float(thickness) * DRAW_CELL_METERS,
		"counts": counts,
		"materials": costs,
		"metal": total_metal,
		"coins": maxi(3, ceili(float(filled) * 0.8)),
		"damage": roundi(base_damage * strength / float(filled)),
		"reach": 3.0 + float(rows) * 0.28,
		"swing": 0.18 + float(rows) * 0.022,
	}


## One square can be painted with a material name. Old drawings stored "true",
## which we treat as copper so nothing from before breaks.
func _cell_material(value) -> String:
	if value is String:
		return String(value)
	if value is StringName:
		return String(value)
	return "copper"


func forge_drawn_weapon(cells: Dictionary, stones: Array = []) -> bool:
	var plan := weapon_plan(cells)
	if plan.is_empty():
		_log("Draw something first!")
		return false

	var costs: Dictionary = plan["materials"]
	var coin_cost := int(plan["coins"]) + stones.size() * INFUSE_COIN_COST

	for material_id in costs:
		var need := int(costs[material_id])
		if count_item(String(material_id)) < need:
			_log("You need %d %s for that weapon (you have %d)." % [
				need, item_label(String(material_id)).to_lower(),
				count_item(String(material_id))
			])
			return false

	for stone_key in stones:
		if count_item(String(stone_key)) < 1:
			_log("You need the %s for that weapon." % item_label(String(stone_key)))
			return false

	if coins < coin_cost:
		_log("You need %d coins for that weapon (you have %d)." % [coin_cost, coins])
		return false

	for material_id in costs:
		remove_item(String(material_id), int(costs[material_id]))
	for stone_key in stones:
		remove_item(String(stone_key), 1)
		_infuse_stone(String(stone_key))
	coins -= coin_cost

	weapon_base_damage = float(plan["damage"])
	sword_name = _drawn_weapon_name(plan["counts"])
	player.swing_time = float(plan["swing"])
	player.reach = float(plan["reach"])
	weapon_length = float(plan["height_m"])
	weapon_color = Color.WHITE
	player.set_bow(false)
	player.build_drawn_weapon(cells)

	# A weapon that is at least half iron counts as an iron weapon, so it can
	# take magic stones. A tiny iron tip is not enough.
	var iron_cells := int(plan["counts"].get("iron", 0))
	if iron_cells * 2 >= int(plan["filled"]):
		crafted["iron_weapon"] = true
	_refresh_attack()
	if not infused.is_empty():
		player.set_weapon_color(_infused_glow())

	var stone_names := PackedStringArray()
	for stone_key in stones:
		stone_names.append(WorldData.element_of(String(stone_key)))
	var extra := ""
	if not stone_names.is_empty():
		extra = "  The %s magic glows in it!" % " + ".join(stone_names)

	_log("Forged a %s: %.2f m tall, %.2f m thick, %d damage.%s" % [
		sword_name.trim_prefix("Drawn ").trim_suffix(" Blade").to_lower(),
		float(plan["height_m"]), float(plan["thickness_m"]), int(attack_power), extra
	])
	return true


## Adds one magic stone to the permanent set of infusions.
func _infuse_stone(stone_key: String) -> void:
	infused[stone_key] = true
	for biome in WorldData.BIOMES:
		if String(biome["stone"]) == stone_key:
			crafted["infuse_" + String(biome["id"])] = true
	if String(WorldData.THUNDER["stone"]) == stone_key:
		crafted["infuse_thunder"] = true
	if String(WorldData.URANIUM["stone"]) == stone_key:
		crafted["infuse_uranium"] = true


## The glow of every magic stone you own, mixed together.
func _infused_glow() -> Color:
	var total := Color(0, 0, 0, 0)
	var count := 0
	for biome in WorldData.BIOMES:
		if infused.has(String(biome["stone"])):
			total += biome["glow"] as Color
			count += 1
	if infused.has(String(WorldData.THUNDER["stone"])):
		total += WorldData.THUNDER["glow"] as Color
		count += 1
	if infused.has(String(WorldData.URANIUM["stone"])):
		total += WorldData.URANIUM["glow"] as Color
		count += 1
	if count == 0:
		return Color.WHITE
	return Color(total.r / count, total.g / count, total.b / count)


func forge_drawn_bow(cells: Dictionary, stones: Array = []) -> bool:
	var plan := weapon_plan(cells)
	if plan.is_empty():
		_log("Draw something first!")
		return false

	var costs: Dictionary = plan["materials"]
	var coin_cost := int(plan["coins"]) + stones.size() * INFUSE_COIN_COST
	for material_id in costs:
		if count_item(String(material_id)) < int(costs[material_id]):
			_log("You need %d %s for that bow (you have %d)." % [
				int(costs[material_id]), item_label(String(material_id)).to_lower(),
				count_item(String(material_id))
			])
			return false
	for stone_key in stones:
		if count_item(String(stone_key)) < 1:
			_log("You need the %s for that bow." % item_label(String(stone_key)))
			return false
	if coins < coin_cost:
		_log("You need %d coins for that bow (you have %d)." % [coin_cost, coins])
		return false

	for material_id in costs:
		remove_item(String(material_id), int(costs[material_id]))
	for stone_key in stones:
		remove_item(String(stone_key), 1)
		_infuse_stone(String(stone_key))
	coins -= coin_cost

	weapon_base_damage = float(plan["damage"])
	sword_name = "Drawn Bow"
	weapon_length = float(plan["height_m"])
	weapon_color = Color(0.5, 0.34, 0.18)
	crafted["bow"] = true
	var bow_material := _dominant_material(plan["counts"])
	player.clear_drawn_weapon()
	player.set_bow(true)
	player.set_bow_color(bow_material.get("color", Color(0.5, 0.34, 0.18)))
	player.swing_time = 0.45
	player.reach = 12.0
	_refresh_attack()
	_log("Forged a drawn bow: %d damage. Left click shoots arrows!" % int(attack_power))
	return true


## Names a mixed weapon after the materials you used, biggest part first:
## "Drawn Iron & Wood Blade".
func _drawn_weapon_name(counts: Dictionary) -> String:
	var entries: Array = []
	for material in WEAPON_METALS:
		var material_id := String(material["id"])
		var cells := int(counts.get(material_id, 0))
		if cells > 0:
			entries.append({
				"name": String(material["name"]),
				"cells": cells,
			})
	entries.sort_custom(func(a, b) -> bool: return int(a["cells"]) > int(b["cells"]))

	var names: Array[String] = []
	for entry in entries:
		names.append(String(entry["name"]))

	var part := "Unknown"
	match names.size():
		1:
			part = names[0]
		2:
			part = "%s & %s" % names
		3:
			part = "%s, %s & %s" % names
	return "Drawn %s Blade" % part


func craft(recipe_index: int) -> void:
	var recipe: Dictionary = recipes[recipe_index]
	if not can_afford(recipe):
		_log("You don't have the materials for that yet.")
		return

	for item in recipe["cost"]:
		if String(item) == "coins":
			coins -= int(recipe["cost"][item])
		else:
			remove_item(String(item), int(recipe["cost"][item]))

	crafted[recipe["id"]] = true
	_apply_craft(recipe)
	play_sound("quest")
	hud.refresh_forge()


func _apply_craft(recipe: Dictionary) -> void:
	var id := String(recipe["id"])

	if id.begins_with("infuse_"):
		var key: String = recipe["stone_key"]
		_infuse_stone(key)
		_refresh_attack()
		player.set_weapon_color(_infused_glow())
		_log("Your weapon absorbs the %s magic! Damage is now %d." % [
			WorldData.element_of(key), int(attack_power)
		])
		return

	if id.begins_with("weapon_"):
		sword_name = String(recipe["weapon_name"])
		weapon_base_damage = float(recipe["weapon_damage"])
		player.swing_time = float(recipe["weapon_swing"])
		player.reach = float(recipe["weapon_reach"])
		player.set_bow(false)
		player.clear_drawn_weapon()
		weapon_length = float(recipe["weapon_length"])
		weapon_color = material_color(String(recipe["material"]))
		player.set_weapon_length(weapon_length)
		player.set_weapon_color(weapon_color)
		if bool(recipe["iron"]):
			crafted["iron_weapon"] = true
		_refresh_attack()
		_log("Crafted a %s (%.1f m): %d damage." % [
			String(recipe["weapon_name"]), float(recipe["weapon_length"]), int(attack_power)
		])
		return

	match id:
		"stone_pickaxe":
			pickaxe_name = "Stone Pickaxe"
			mining_power = 2.0
			player.set_weapon_color(Color(0.6, 0.6, 0.62))
			_log("Crafted a Stone Pickaxe! Mining is twice as fast.")
		"iron_pickaxe":
			pickaxe_name = "Iron Pickaxe"
			mining_power = 3.5
			player.set_weapon_color(Color(0.78, 0.8, 0.85))
			_log("Crafted an Iron Pickaxe! You break rocks super fast now.")
		"shield":
			player.set_has_shield(true)
			_log("Crafted a shield! Press 3 to hold it, then hold left click to block.")
		"bow":
			sword_name = "Hunter's Bow"
			weapon_base_damage = 20.0
			weapon_length = 1.0
			weapon_color = Color(0.5, 0.34, 0.18)
			player.clear_drawn_weapon()
			player.set_bow(true)
			player.set_bow_color(Color(0.5, 0.34, 0.18))
			player.swing_time = 0.45
			player.reach = 12.0
			_refresh_attack()
			_log("Crafted a Hunter's Bow! Left click shoots arrows from far away.")
		"sell_stone":
			add_coins(SELL_STONE_PRICE)
			_log("Sold %d stone for %d coins." % [SELL_STONE_AMOUNT, SELL_STONE_PRICE])


## Every infused stone adds +7 damage to whatever weapon you hold.
func _refresh_attack() -> void:
	attack_power = weapon_base_damage + INFUSE_DAMAGE_BONUS * float(infused.size())


## Each magic stone gives your hits a different battle trick. Mixing stones
## means several tricks happen at the same time.
func apply_weapon_effects(target) -> void:
	if target == null or not is_instance_valid(target) or player == null:
		return
	if "hp" in target and float(target.hp) <= 0.0:
		return  # it already died from the hit

	if infused.has("magic_fire") and target.has_method("apply_burn"):
		target.apply_burn(2.5, 4.0)
	if infused.has("magic_ice") and target.has_method("apply_slow"):
		target.apply_slow(2.5)
	if infused.has("magic_water") and target.has_method("knockback"):
		target.knockback(target.global_position - player.global_position, 1.6)
	if infused.has("magic_poison") and target.has_method("apply_poison"):
		target.apply_poison(4.0, 2.0)
	if infused.has("magic_rock") and target.has_method("apply_stun"):
		target.apply_stun(1.0)
	if infused.has("magic_plants"):
		health = minf(MAX_HEALTH, health + 2.0)
	if infused.has("magic_uranium"):
		if target.has_method("apply_poison"):
			target.apply_poison(5.0, 4.0)
		if target.has_method("apply_slow"):
			target.apply_slow(1.5)
	if infused.has("magic_thunder"):
		if target.has_method("apply_stun"):
			target.apply_stun(0.8)
		# A little lightning chain to two monsters nearby.
		var zapped := 0
		for enemy in get_tree().get_nodes_in_group("enemy"):
			if enemy == target or not is_instance_valid(enemy):
				continue
			if "hp" in enemy and float(enemy.hp) <= 0.0:
				continue
			if enemy.global_position.distance_to(target.global_position) < 7.0:
				enemy.take_damage(attack_power * 0.3)
				zapped += 1
				if zapped >= 2:
					break


func infused_names() -> String:
	var names := PackedStringArray()
	for stone_key in WorldData.STONE_KEYS:
		if infused.has(String(stone_key)):
			names.append(WorldData.element_of(String(stone_key)))
	return " + ".join(names)


# ============================================================================
#  ARMOUR YOU DRAW YOURSELF
# ============================================================================
func armour_piece_name(piece_id: String) -> String:
	for piece in ARMOUR_PIECES:
		if String(piece["id"]) == piece_id:
			return String(piece["name"])
	return piece_id.capitalize()


## Each armour piece protects a little. The cap keeps four pieces balanced.
func armour_defense(plan: Dictionary) -> int:
	if plan.is_empty():
		return 0
	return mini(12, maxi(2, roundi(float(plan["damage"]) * 0.3)))


func armour_total() -> int:
	var total := 0
	for piece_id in armour:
		total += int(armour[piece_id].get("defense", 0))
	return total


func forge_armour_piece(piece_id: String, cells: Dictionary) -> bool:
	if not _is_armour_piece(piece_id):
		_log("That is not an armour piece.")
		return false

	var plan := weapon_plan(cells)
	if plan.is_empty():
		_log("Draw something first!")
		return false

	var costs: Dictionary = plan["materials"]
	var coin_cost := int(plan["coins"])
	for material_id in costs:
		var need := int(costs[material_id])
		if count_item(String(material_id)) < need:
			_log("You need %d %s for that armour (you have %d)." % [
				need, item_label(String(material_id)).to_lower(),
				count_item(String(material_id))
			])
			return false
	if coins < coin_cost:
		_log("You need %d coins for that armour (you have %d)." % [coin_cost, coins])
		return false

	for material_id in costs:
		remove_item(String(material_id), int(costs[material_id]))
	coins -= coin_cost

	var defense := armour_defense(plan)
	var material := _dominant_material(plan["counts"])
	var color: Color = material.get("color", Color(0.8, 0.8, 0.85))
	var piece_name := armour_piece_name(piece_id)
	var item_name := "Drawn %s %s" % [String(material["name"]), piece_name]
	armour[piece_id] = {"name": item_name, "defense": defense, "color": color}
	if player != null:
		player.set_armour_piece(piece_id, color)

	_log("Forged a %s! Defence is now +%d%%." % [item_name, armour_total()])
	return true


func _is_armour_piece(piece_id: String) -> bool:
	for piece in ARMOUR_PIECES:
		if String(piece["id"]) == piece_id:
			return true
	return false


func _dominant_material(counts: Dictionary) -> Dictionary:
	var best := material_data("wood")
	var best_count := -1
	for material in WEAPON_METALS:
		var cells := int(counts.get(String(material["id"]), 0))
		if cells > best_count:
			best_count = cells
			best = material
	return best


# ============================================================================
#  THE WANDERING TRADER
# ============================================================================
func free_space(item: String) -> int:
	var space := 0
	for slot in slots:
		if slot == null:
			space += STACK_LIMIT
		elif String(slot["item"]) == item:
			space += STACK_LIMIT - int(slot["count"])
	return space


func trader_can_offer(offer: Dictionary) -> bool:
	var item := String(offer["item"])
	if String(offer["kind"]) == "buy":
		return coins >= int(offer["coins"]) and free_space(item) >= int(offer["amount"])
	return count_item(item) >= int(offer["amount"])


func trader_trade(index: int) -> void:
	if index < 0 or index >= TRADER_OFFERS.size():
		return
	var offer: Dictionary = TRADER_OFFERS[index]
	if not trader_can_offer(offer):
		_log("You can't do that trade right now.")
		return

	var item := String(offer["item"])
	var amount := int(offer["amount"])
	if String(offer["kind"]) == "buy":
		coins -= int(offer["coins"])
		add_item(item, amount)
		_log("Bought %d %s for %d coins." % [
			amount, item_label(item).to_lower(), int(offer["coins"])
		])
	else:
		remove_item(item, amount)
		add_coins(int(offer["coins"]))
		_log("Sold %d %s for %d coins." % [
			amount, item_label(item).to_lower(), int(offer["coins"])
		])
	if hud != null:
		hud.refresh_shop()


# ============================================================================
#  VILLAGE QUESTS
# ============================================================================
func quest_can_do(quest: Dictionary) -> bool:
	if quests_done.has(String(quest["id"])):
		return false
	return count_item(String(quest["item"])) >= int(quest["amount"])


func do_quest(index: int) -> void:
	if index < 0 or index >= VILLAGE_QUESTS.size():
		return
	var quest: Dictionary = VILLAGE_QUESTS[index]
	if quests_done.has(String(quest["id"])):
		_log("That quest is already done. Thank you!")
		return
	if count_item(String(quest["item"])) < int(quest["amount"]):
		_log("You need %d %s for that quest." % [
			int(quest["amount"]), item_label(String(quest["item"])).to_lower()
		])
		return

	remove_item(String(quest["item"]), int(quest["amount"]))
	quests_done[String(quest["id"])] = true
	add_coins(int(quest["coins"]))
	var reward := PackedStringArray()
	for item in quest["give"]:
		add_item(String(item), int(quest["give"][item]))
		reward.append("%d %s" % [int(quest["give"][item]), item_label(String(item)).to_lower()])
	play_sound("quest")
	_log("Quest complete! %d coins%s" % [
		int(quest["coins"]),
		(" and " + ", ".join(reward)) if not reward.is_empty() else ""
	])
	if hud != null:
		hud.refresh_quests()


# ============================================================================
#  SAVE / LOAD / LOG OUT
# ============================================================================
func _is_test_run() -> bool:
	if OS.has_feature("headless"):
		return true
	# The smoke test and screenshot tool put the game under a test scene.
	var parent := get_parent()
	if parent != null and String(parent.scene_file_path).contains("tests/"):
		return true
	var scene := get_tree().current_scene
	return scene != null and String(scene.scene_file_path).contains("tests/")


func save_path() -> String:
	return TEST_SAVE_PATH if _is_test_run() else SAVE_PATH


func save_game() -> void:
	if not game_ready:
		return
	var chest_data: Array = []
	for chest in chests:
		chest_data.append(_slots_to_data(chest["slots"]))

	var data := {
		"version": 1,
		"coins": coins,
		"health": health,
		"hunger": hunger,
		"day_count": day_count,
		"time_of_day": time_of_day,
		"weather": weather,
		"weather_timer": weather_timer,
		"slots": _slots_to_data(slots),
		"chests": chest_data,
		"crafted": crafted,
		"infused": infused,
		"defeated_temples": defeated_temples,
		"quests_done": quests_done,
		"final_boss_defeated": final_boss_defeated,
		"sky_dragon_defeated": sky_dragon_defeated,
		"ending_seen": ending_seen,
		"farm": farm_state,
		"treasures_found": treasures_found,
		"wolf_tamed": wolf_tamed,
		"wolf_level": wolf.level if wolf != null else 1,
		"wolf_stay": wolf.stay if wolf != null else false,
		"pickaxe_name": pickaxe_name,
		"sword_name": sword_name,
		"weapon_base_damage": weapon_base_damage,
		"mining_power": mining_power,
		"weapon_length": weapon_length,
		"weapon_color": _color_to_data(weapon_color),
		"has_shield": player != null and player.has_shield,
		"has_bow": player != null and player.has_bow,
		"armour": _armour_to_data(),
		"drawn_cells": _cells_to_data(player.drawn_cells) if player != null else [],
		"drawn_swing": player.swing_time if player != null else 0.32,
		"drawn_reach": player.reach if player != null else 6.0,
	}

	var file := FileAccess.open(save_path(), FileAccess.WRITE)
	if file == null:
		_log("Could not save the game.")
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	_log("Game saved.")


func load_game() -> bool:
	var path := save_path()
	if not FileAccess.file_exists(path):
		return false

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Dictionary):
		return false
	var data: Dictionary = parsed

	coins = int(data.get("coins", START_COINS))
	health = clampf(float(data.get("health", MAX_HEALTH)), 1.0, MAX_HEALTH)
	hunger = clampf(float(data.get("hunger", MAX_HUNGER)), 0.0, MAX_HUNGER)
	day_count = maxi(1, int(data.get("day_count", 1)))
	time_of_day = clampf(float(data.get("time_of_day", 0.34)), 0.0, 0.999)
	slots = _slots_from_data(data.get("slots", []))
	crafted = data.get("crafted", {})
	infused = data.get("infused", {})
	defeated_temples = data.get("defeated_temples", {})
	quests_done = data.get("quests_done", {})
	final_boss_defeated = bool(data.get("final_boss_defeated", false))
	sky_dragon_defeated = bool(data.get("sky_dragon_defeated", false))
	ending_seen = bool(data.get("ending_seen", false))
	wolf_tamed = bool(data.get("wolf_tamed", false))
	var saved_farm = data.get("farm", [])
	if saved_farm is Array:
		for i in mini(farm_state.size(), saved_farm.size()):
			var plot = saved_farm[i]
			if plot is Dictionary:
				farm_state[i]["state"] = String(plot.get("state", "empty"))
				farm_state[i]["timer"] = float(plot.get("timer", 0.0))
				_update_farm_visual(i)

	treasures_found = data.get("treasures_found", {})
	for treasure in treasures:
		if treasures_found.has(String(treasure["id"])):
			treasure["found"] = true
			_open_treasure_visual(treasure)
	pickaxe_name = String(data.get("pickaxe_name", pickaxe_name))
	sword_name = String(data.get("sword_name", sword_name))
	weapon_base_damage = float(data.get("weapon_base_damage", weapon_base_damage))
	mining_power = float(data.get("mining_power", mining_power))
	weapon_length = float(data.get("weapon_length", weapon_length))
	weapon_color = _color_from_data(data.get("weapon_color"), weapon_color)

	var chest_data = data.get("chests", [])
	if chest_data is Array:
		for i in mini(chests.size(), chest_data.size()):
			chests[i]["slots"] = _slots_from_data(chest_data[i])

	if player != null:
		player.set_has_shield(bool(data.get("has_shield", false)))

		var drawn_cells := _cells_from_data(data.get("drawn_cells", []))
		if drawn_cells.is_empty():
			player.clear_drawn_weapon()
			player.set_weapon_length(weapon_length)
			player.set_weapon_color(weapon_color)
		else:
			player.build_drawn_weapon(drawn_cells)
		player.swing_time = float(data.get("drawn_swing", player.swing_time))
		player.reach = float(data.get("drawn_reach", player.reach))

		armour.clear()
		player.clear_armour()
		var saved_armour = data.get("armour", {})
		if saved_armour is Dictionary:
			for piece in ARMOUR_PIECES:
				var piece_id := String(piece["id"])
				if not saved_armour.has(piece_id):
					continue
				var entry = saved_armour[piece_id]
				if not (entry is Dictionary):
					continue
				var color := _color_from_data(entry.get("color"), Color(0.8, 0.8, 0.85))
				armour[piece_id] = {
					"name": String(entry.get("name", "Armour")),
					"defense": int(entry.get("defense", 0)),
					"color": color,
				}
				player.set_armour_piece(piece_id, color)

		player.set_bow(bool(data.get("has_bow", false)))
		if not infused.is_empty():
			player.set_weapon_color(_infused_glow())
		_refresh_attack()

		player.global_position = FORGE_POS + Vector3(0, 1.4, 7.0)
		player.velocity = Vector3.ZERO
		in_cave = false
		in_thunder = false
		in_poison = false
		in_dive = false
		in_final = false
		in_sky = false
		breath = 100.0
		if wolf != null:
			wolf.set_tamed(wolf_tamed)
			wolf.set_level(int(data.get("wolf_level", 1)))
			wolf.set_stay(bool(data.get("wolf_stay", false)))
			if wolf_tamed:
				wolf.global_position = FORGE_POS + Vector3(2.5, 0.0, 3.0)

	for boss in bosses:
		if is_instance_valid(boss) and defeated_temples.has(String(boss.biome_id)):
			boss.queue_free()

	_update_time_of_day()
	set_weather(String(data.get("weather", "clear")))
	weather_timer = float(data.get("weather_timer", 60.0))
	return true


func logout() -> void:
	save_game()
	get_tree().quit()


func start_new_game() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path()))
	get_tree().paused = false
	get_tree().reload_current_scene()


func _slots_to_data(source: Array) -> Array:
	var out: Array = []
	for slot in source:
		if slot == null:
			out.append(null)
		else:
			out.append({"item": String(slot["item"]), "count": int(slot["count"])})
	return out


func _slots_from_data(data) -> Array:
	var out: Array = []
	if data is Array:
		for entry in data:
			if entry is Dictionary and entry.has("item"):
				out.append({"item": String(entry["item"]), "count": int(entry["count"])})
			else:
				out.append(null)
	while out.size() < SLOT_COUNT:
		out.append(null)
	if out.size() > SLOT_COUNT:
		out.resize(SLOT_COUNT)
	return out


func _cells_to_data(cells: Dictionary) -> Array:
	var out: Array = []
	for cell in cells:
		out.append([int(cell.x), int(cell.y), _cell_material(cells[cell])])
	return out


func _cells_from_data(data) -> Dictionary:
	var cells := {}
	if data is Array:
		for entry in data:
			if entry is Array and entry.size() >= 2:
				var material_id := "copper"
				if entry.size() >= 3:
					material_id = String(entry[2])
				cells[Vector2i(int(entry[0]), int(entry[1]))] = material_id
	return cells


func _color_to_data(color: Color) -> Array:
	return [color.r, color.g, color.b, color.a]


func _color_from_data(data, fallback := Color.WHITE) -> Color:
	if data is Array and data.size() >= 3:
		var alpha := 1.0
		if data.size() >= 4:
			alpha = float(data[3])
		return Color(float(data[0]), float(data[1]), float(data[2]), alpha)
	return fallback


func _armour_to_data() -> Dictionary:
	var out := {}
	for piece_id in armour:
		var entry: Dictionary = armour[piece_id]
		var color: Color = entry.get("color", Color.WHITE)
		out[piece_id] = {
			"name": String(entry.get("name", "Armour")),
			"defense": int(entry.get("defense", 0)),
			"color": _color_to_data(color),
		}
	return out


# ============================================================================
#  TEXT HELPERS (shown in the HUD)
# ============================================================================
func current_goal() -> String:
	if not crafted.has("stone_pickaxe"):
		var missing: int = 8 - count_item("stone")
		if missing > 0:
			return "Mine %d more stone (left click the grey rocks)" % missing
		return "Press T to go to the Forge, then press E to craft a Stone Pickaxe"

	if not crafted.has("iron_weapon"):
		if count_item("copper") < 3 or count_item("iron") < 5:
			return "Mine copper (orange) and iron (silver) ore, then sell spare stone for coins"
		return "Craft an iron weapon at the Forge (bigger weapon = more metal)"

	var waiting := stone_count() - infused.size()
	if waiting > 0:
		return "Press T, then E at the Forge to infuse a magic stone (%d waiting)" % waiting

	if temples_beaten() < WorldData.TEMPLE_COUNT:
		for biome in WorldData.BIOMES:
			if not defeated_temples.has(biome["id"]):
				return "Temples beaten %d/%d — find the %s in the %s" % [
					temples_beaten(), WorldData.TEMPLE_COUNT,
					String(biome["temple_name"]), String(biome["name"])
				]
		if not defeated_temples.has("thunder"):
			return "Walk into the Spiky Cave underground and find the Thunder Temple"
		if not defeated_temples.has("uranium"):
			return "Find the Uranium Temple deep in the Acid Cave"

	if not final_boss_defeated:
		return "All eight stones are infused! Enter the final portal at the Forge"
	if not sky_dragon_defeated:
		return "A Sky Portal opened at the Forge — explore the Sky Islands DLC"
	return "DLC: Sky Islands complete! You are the master of the Eight Stones."


func current_prompt() -> String:
	if hud != null and hud.menu_open():
		return "Click what you need, or press E to close"
	if near_chest >= 0:
		return "Press E to open the chest"
	if near_forge:
		return "Press E to use the Forge"
	if near_trader:
		return "Press E to trade with the wandering trader"
	if near_villager != null:
		return "Press E to talk to %s" % near_villager.villager_name
	if near_wolf:
		return "Press E to tame the forest wolf"
	if near_tamed_wolf:
		return "Press E to feed your wolf 1 meat  ·  K stay/follow  ·  L attack"
	if near_campfire:
		return "Press E to cook at the campfire"
	if near_farm_plot >= 0:
		var plot: Dictionary = farm_state[near_farm_plot]
		var crop_name: String = CROP_NAMES.get(String(FARM_CROPS[near_farm_plot]), "crop")
		if String(plot["state"]) == "empty":
			return "Press E to plant %s" % crop_name
		if String(plot["state"]) == "growing":
			return "The %s are growing... %d seconds" % [
				crop_name, int(ceil(float(plot["timer"])))
			]
		return "Press E to harvest the %s" % crop_name
	if near_fishing:
		return "Press E to fish"
	if near_farm_animal != null:
		return "Press E to collect from the %s" % near_farm_animal.kind
	if near_treasure >= 0:
		return "Press E to open the hidden chest"
	if near_sky_portal:
		if sky_portal_open():
			return "Press E to fly to the Sky Islands DLC"
		return "The Sky Portal is sealed — beat the Eight-Stone Guardian"
	if near_sky_exit:
		return "Press E to return to the Forge"
	if in_sky:
		return "DLC: SKY ISLANDS  ·  explore the floating islands"
	if near_final_portal:
		if final_boss_defeated:
			return "The final portal is quiet — the island is safe"
		if final_portal_open():
			return "Press E to enter the final trial"
		return "The final portal is sealed — infuse all eight magic stones"
	if near_final_exit:
		return "Press E to leave the final trial"
	if in_final:
		return "FINAL TRIAL  ·  defeat the Eight-Stone Guardian"
	if near_dive_exit:
		return "Press E to surface"
	if in_dive:
		return "UNDERWATER  ·  breath %d/100  ·  find the sunken chest" % int(breath)
	if near_dive_spot:
		return "Press E to dive into the Sunken Grotto"
	if near_quest_board:
		return "Press E to read the village quest board"
	if near_cave_entrance:
		return "Press E to go down into the cave"
	if near_cave_exit:
		return "Press E to climb back up"
	if player != null and is_in_water(player.global_position):
		return "Swimming  ·  hold Shift to swim faster"
	if in_safe_zone():
		return "SAFE ZONE — nothing can hurt you here"
	if player != null and player.focus_node != null:
		if player.focus_node.is_in_group("ore"):
			var is_wood: bool = "ore_type" in player.focus_node \
				and String(player.focus_node.ore_type) == "wood"
			if is_wood:
				return "Hold LEFT CLICK to chop %s (your sword works)" % player.focus_node.display_name()
			if player.active_hand == 1:
				return "Hold LEFT CLICK to mine %s" % player.focus_node.display_name()
			return "Press 2 to hold your pickaxe and mine"
		if player.focus_node.is_in_group("tree"):
			return "Hold LEFT CLICK to chop the tree for wood"
		if player.focus_node.is_in_group("enemy") or player.focus_node.is_in_group("boss"):
			if player.active_hand == 0:
				return "LEFT CLICK to attack"
			if player.active_hand == 1:
				return "A pickaxe hits weakly — press 1 for your sword"
			return "Shield up: hold LEFT CLICK to block"
	if in_cave:
		return "%s  ·  walk between caves  ·  gold pad = exit" % underground_biome_name(
			underground_biome_at(player.global_position)
		)
	return "WASD move  ·  1 sword  ·  2 pickaxe  ·  3 shield  ·  T teleport"


func _pretty_item(item: String) -> String:
	match item:
		"stone": return "stone"
		"wood": return "wood"
		"hardwood": return "hardwood"
		"copper": return "copper"
		"iron": return "iron"
		"wheat": return "wheat"
		"carrot": return "carrots"
		"wheat_seed": return "wheat seeds"
		"carrot_seed": return "carrot seeds"
		"egg": return "egg"
		"milk": return "milk"
		"wool": return "wool"
		"bread": return "bread"
		"carrot_soup": return "carrot soup"
		"sky_crystal": return "sky crystal"
		"berry": return "berries"
		"meat": return "meat"
		"cooked_meat": return "cooked meat"
		"berry_jam": return "berry jam"
		"fish": return "fish"
		"cooked_fish": return "cooked fish"
		"uranium": return "uranium"
		"potion_heal": return "healing potion"
		"potion_speed": return "speed potion"
		"coins": return "coins"
	for biome in WorldData.BIOMES:
		if String(biome["stone"]) == item:
			return "%s stone" % String(biome["element"]).to_lower()
	if String(WorldData.THUNDER["stone"]) == item:
		return "thunder stone"
	if String(WorldData.URANIUM["stone"]) == item:
		return "uranium stone"
	if item.begins_with("magic_"):
		return "magic stone"
	return item


func _log(text: String) -> void:
	log_message.emit(text)
	if hud != null:
		hud.log(text)


# ============================================================================
#  SMALL UTILITIES
# ============================================================================
func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.95
	return mat


func _glow_material(color: Color, energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	return mat


func _add_world_label(text: String, pos: Vector3, color: Color, max_distance := 900.0) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 16
	label.outline_size = 3
	label.fixed_size = true
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = color
	label.position = pos
	label.visibility_range_end = max_distance
	label.visibility_range_end_margin = 20.0
	label.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(label)


## Which biome is this point in? Later entries win, so small biomes
## (Mushroom Island) sit on top of big neighbours.
func _biome_at(p: Vector2) -> Dictionary:
	var result: Dictionary = WorldData.BIOMES[0]
	for i in range(WorldData.BIOMES.size() - 1, -1, -1):
		var biome: Dictionary = WorldData.BIOMES[i]
		var dx: float = (p.x - biome["center"].x) / maxf(float(biome["size"].x), 1.0)
		var dz: float = (p.y - biome["center"].y) / maxf(float(biome["size"].y), 1.0)
		if Vector2(dx, dz).length() <= 1.0:
			return biome
	return result


## Is this point on a biome island? (Water is not land.)
func _is_land(p: Vector2) -> bool:
	for biome in WorldData.BIOMES:
		if String(biome["id"]) == "water":
			continue
		var dx: float = (p.x - biome["center"].x) / maxf(float(biome["size"].x), 1.0)
		var dz: float = (p.y - biome["center"].y) / maxf(float(biome["size"].y), 1.0)
		if dx * dx + dz * dz <= 1.0:
			return true
	return false


## A random point inside a biome's blob (square-root keeps it even).
func _random_in_biome(rng: RandomNumberGenerator, biome: Dictionary) -> Vector2:
	var angle := rng.randf_range(0.0, TAU)
	var radius := sqrt(rng.randf()) * 0.82
	return Vector2(
		biome["center"].x + cos(angle) * biome["size"].x * radius,
		biome["center"].y + sin(angle) * biome["size"].y * radius
	)


## A random point inside the round island.
func _random_on_island(rng: RandomNumberGenerator, spread: float) -> Vector2:
	var angle := rng.randf_range(0.0, TAU)
	var radius := sqrt(rng.randf()) * WorldData.WORLD_RADIUS * spread
	return Vector2(cos(angle) * radius, sin(angle) * radius)
