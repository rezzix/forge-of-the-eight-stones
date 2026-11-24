extends Node
## Headless smoke test. Run it with:
##   godot --headless --path . res://tests/smoke_test.tscn
## It builds the real game, pokes it, and reports PASS/FAIL for the core loop.

var failures := 0


func _ready() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame

	var game = main

	_check(game.player != null, "player spawned")
	_check(game.hud != null, "hud built")
	_check(game.hud.save_button != null and game.hud.logout_button != null,
		"the Forge has save and log out buttons")
	_check(game.trader != null and is_instance_valid(game.trader),
		"the wandering trader exists")
	if game.trader != null:
		_check(game.trader.is_in_group("trader"), "the trader is tagged as a trader")
	_check(get_tree().get_nodes_in_group("ore").size() >= 20, "ores spawned (%d)" % get_tree().get_nodes_in_group("ore").size())
	var wood_nodes := 0
	for node in get_tree().get_nodes_in_group("ore"):
		if "ore_type" in node and String(node.ore_type) == "wood":
			wood_nodes += 1
	_check(wood_nodes >= 20, "wood log piles spawned (%d)" % wood_nodes)
	_check(game.count_item("wood") == 6, "you start with 6 wood")
	_check(get_tree().get_nodes_in_group("boss").size() == 8, "eight bosses (%d)" % get_tree().get_nodes_in_group("boss").size())
	_check(get_tree().get_nodes_in_group("enemy").size() >= 10, "monsters spawned (%d)" % get_tree().get_nodes_in_group("enemy").size())
	_check(game.hunger > 90.0, "the food bar starts full")
	_check(game.hunger < 100.0, "food goes down over time")
	_check(game.hud.hunger_bar != null, "the HUD shows a food bar")
	_check(game.count_item("berry") == 2, "you start with berries")
	_check(game.count_item("potion_heal") == 1, "you start with a healing potion")
	_check(game.wolf != null and is_instance_valid(game.wolf), "the forest wolf exists")
	_check(not game.wolf_tamed, "the wolf starts wild")
	_check(get_tree().get_nodes_in_group("animal").size() >= 6, "animals live on the island")
	var animal_kinds := {}
	for animal in get_tree().get_nodes_in_group("animal"):
		if "animal_kind" in animal:
			animal_kinds[String(animal.animal_kind)] = true
	_check(animal_kinds.has("deer") and animal_kinds.has("fox"),
		"wild deer and foxes live on the island")
	_check(game.recipe_index("infuse_thunder") >= 0, "the Thunder stone can be infused")
	_check(game.recipe_index("infuse_uranium") >= 0, "the Uranium stone can be infused")
	var thunder_boss = null
	var uranium_boss = null
	for b in game.bosses:
		if String(b.biome_id) == "thunder":
			thunder_boss = b
		elif String(b.biome_id) == "uranium":
			uranium_boss = b
	_check(thunder_boss != null, "the Storm Golem waits in the Thunder Temple")
	_check(uranium_boss != null, "the Uranium Golem waits in the Acid Cave")
	_check(get_tree().get_nodes_in_group("villager").size() >= 3, "villagers live in the Savanna")
	_check(game.hud.pet_label != null, "the HUD shows your wolf")
	_check(game.sfx_streams.size() >= 8, "the game has sound effects")
	_check(game.music_player != null and game.music_player.stream != null, "the game has music")

	# --- food, berries and potions -----------------------------------------
	game.hunger = 40.0
	game.eat_food()
	_check(game.hunger > 40.0, "eating a berry fills the food bar")
	_check(game.count_item("berry") == 1, "eating uses one berry")

	game.health = 40.0
	game.drink_heal_potion()
	_check(game.health > 40.0, "a healing potion heals you")
	_check(game.count_item("potion_heal") == 0, "the healing potion is used up")

	game.add_item("potion_speed", 1)
	game.drink_speed_potion()
	_check(game.player.speed_timer > 0.0, "a speed potion makes you faster")
	game.player.speed_timer = 0.0
	game.health = 100.0
	game.hunger = 100.0

	game.set_weather("rain")
	_check(game.weather == "rain", "weather can change")
	_check(game.weather_particles.emitting, "rain particles are falling")
	game.set_weather("clear")
	_check(not game.weather_particles.emitting, "the rain stops")

	# --- hunting animals for meat ------------------------------------------
	var test_animal = get_tree().get_nodes_in_group("animal")[0]
	var meat_before: int = game.count_item("meat")
	test_animal.take_damage(9999.0)
	await get_tree().process_frame
	_check(game.count_item("meat") > meat_before, "hunting an animal gives meat")
	_check(not test_animal.alive, "the hunted animal is gone for now")
	var meat_after_hunt: int = game.count_item("meat")
	game.hunger = 20.0
	game.eat_food()
	_check(game.hunger > 20.0, "eating meat fills the food bar")
	_check(game.count_item("meat") == meat_after_hunt - 1, "eating meat uses one meat")

	var kick_animal = null
	for animal in get_tree().get_nodes_in_group("animal"):
		if "alive" in animal and animal.alive:
			kick_animal = animal
			break
	if kick_animal != null:
		game.player.global_position = kick_animal.global_position + Vector3(0, 1.2, 1)
		var animal_hp: float = kick_animal.hp
		game.player._kick()
		await get_tree().process_frame
		_check(kick_animal.hp < animal_hp, "you can kick an animal")

	var fire_animal = null
	for animal in get_tree().get_nodes_in_group("animal"):
		if "alive" in animal and animal.alive:
			fire_animal = animal
			break
	if fire_animal != null:
		var cooked_before: int = game.count_item("cooked_meat")
		game.infused["magic_fire"] = true
		fire_animal.take_damage(9999.0, true)
		await get_tree().process_frame
		_check(game.count_item("cooked_meat") > cooked_before,
			"a fire-stone kill drops cooked meat")
		game.infused.erase("magic_fire")
		game._refresh_attack()

	# --- round island ------------------------------------------------------
	var island: StaticBody3D = get_tree().get_first_node_in_group("player").get_parent().get_node_or_null("Island")
	if island == null:
		# The island is not in a group; find it by name under the main node.
		island = main.get_node_or_null("Island")
	_check(island != null, "island exists")
	if island != null:
		var shape = island.get_node("IslandShape").shape
		_check(shape is CylinderShape3D, "island collision is a cylinder (round map)")
		_check(is_equal_approx(shape.radius, WorldData.WORLD_RADIUS), "island radius matches WorldData")

	var patches := 0
	var blob_vertices := 0
	for child in main.get_children():
		if child is MeshInstance3D and String(child.name).begins_with("Biome_"):
			patches += 1
			blob_vertices = child.mesh.surface_get_array_len(0)
	_check(patches == 6, "six biome blobs (%d)" % patches)
	_check(blob_vertices > 60, "biome borders are wavy meshes (%d vertices)" % blob_vertices)

	# --- physics: land, walk, jump -----------------------------------------
	for i in 30:
		await get_tree().physics_frame
	_check(game.player.is_on_floor(), "player stands on the ground")

	var start_pos: Vector3 = game.player.global_position
	Input.action_press("move_forward")
	for i in 25:
		await get_tree().physics_frame
	Input.action_release("move_forward")
	_check(game.player.global_position.distance_to(start_pos) > 1.5, "player walks with W")

	Input.action_press("jump")
	await get_tree().physics_frame
	Input.action_release("jump")
	await get_tree().physics_frame
	_check(game.player.velocity.y > 0.5, "player jumps")

	# --- swimming -----------------------------------------------------------
	_check(game.is_in_water(Vector3(400, 0, 200)), "the lake is water")
	game.player.global_position = Vector3(400, 0.5, 200)
	for i in 20:
		await get_tree().physics_frame
	_check(game.player.is_swimming(), "the player swims in water")
	_check(game.player.visuals.rotation.x < -0.5, "the player floats forward while swimming")
	game.player.global_position = game.START_POS
	for i in 5:
		await get_tree().physics_frame
	_check(not game.player.is_swimming(), "the player walks again on land")

	# --- chopping trees for wood -------------------------------------------
	_check(get_tree().get_nodes_in_group("tree").size() >= 50, "trees can be chopped")
	var test_tree = get_tree().get_nodes_in_group("tree")[0]
	var tree_wood: int = game.count_item("wood")
	test_tree.hit(999.0)
	await get_tree().process_frame
	_check(game.count_item("wood") > tree_wood, "chopping a tree gives wood")
	_check(not test_tree.alive, "the chopped tree is gone for now")

	var ancient_tree = null
	for tree in get_tree().get_nodes_in_group("tree"):
		if "tree_type" in tree and String(tree.tree_type) == "ancient":
			ancient_tree = tree
			break
	if ancient_tree != null:
		var hardwood_before: int = game.count_item("hardwood")
		ancient_tree.hit(999.0)
		await get_tree().process_frame
		_check(game.count_item("hardwood") > hardwood_before, "ancient trees give hardwood")

	# --- diving --------------------------------------------------------------
	game.player.global_position = game.DIVE_SPOT + Vector3(0, 1.2, 0)
	await get_tree().physics_frame
	_check(game.near_dive_spot, "the dive spot is in the lake")
	game.enter_dive()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(game.in_dive and game.player.global_position.y < 0, "you can dive underwater")
	_check(game.player.is_swimming(), "you swim in the Sunken Grotto")
	_check(game.hud.breath_bar.visible, "the breath bar appears underwater")

	var sunken_index := -1
	for i in game.treasures.size():
		if String(game.treasures[i]["id"]) == "sunken_vault":
			sunken_index = i
	if sunken_index >= 0:
		for i in game.SLOT_COUNT:
			game.slots[i] = null
		game.player.global_position = game.treasures[sunken_index]["pos"] + Vector3(0, 1.2, 1)
		await get_tree().process_frame
		_check(game.near_treasure == sunken_index, "the sunken chest can be found")
		game.collect_treasure(sunken_index)
		_check(game.treasures_found.has("sunken_vault"), "the sunken chest gives treasure")
	game.leave_dive()
	_check(not game.in_dive, "you can surface from the dive")
	game.player.global_position = game.START_POS

	# --- the character faces the way it walks ------------------------------
	var facing: Vector3 = game.player.visuals.global_basis * Vector3(0, 0, -1)
	_check(facing.dot(Vector3(0, 0, -1)) > 0.7, "character faces where it walks")

	# --- walk animation ----------------------------------------------------
	var leg: Node3D = game.player.leg_pivots[0]
	Input.action_press("move_forward")
	var biggest_swing := 0.0
	for i in 30:
		await get_tree().physics_frame
		biggest_swing = maxf(biggest_swing, absf(leg.rotation.x))
	Input.action_release("move_forward")
	_check(biggest_swing > 0.1, "legs swing while walking (%.2f rad)" % biggest_swing)

	for i in 45:
		await get_tree().physics_frame
	_check(absf(leg.rotation.x) < 0.1, "legs rest when standing still")

	# --- minimap -----------------------------------------------------------
	_check(game.hud.minimap != null, "minimap exists")
	if game.hud.minimap != null:
		_check(game.hud.minimap.size.x >= 150.0, "minimap has a real size")
		_check(game.hud.minimap.is_visible_in_tree(), "minimap is visible")

	# --- monsters have different forms -------------------------------------
	var forms := {}
	for monster in get_tree().get_nodes_in_group("enemy"):
		if "form" in monster:
			forms[monster.form] = true
	_check(forms.size() >= 5, "monsters have different forms (%d)" % forms.size())

	# --- blocky style: cubes and triangles only ----------------------------
	var smooth_parts := 0
	var blocky_parts := 0
	for child in game.player.visuals.find_children("*", "MeshInstance3D", true, false):
		if child.mesh is BoxMesh or child.mesh is ArrayMesh:
			blocky_parts += 1
		else:
			smooth_parts += 1
	_check(smooth_parts == 0 and blocky_parts >= 6, "player is built from cubes and triangles")

	var smooth_monster := 0
	for monster in get_tree().get_nodes_in_group("enemy"):
		if "visual" in monster and monster.visual != null:
			for child in monster.visual.get_children():
				if child is MeshInstance3D and not (child.mesh is BoxMesh or child.mesh is ArrayMesh):
					smooth_monster += 1
	_check(smooth_monster == 0, "monsters and bosses are built from cubes and triangles")

	# --- the round edge keeps the player in --------------------------------
	game.player.global_position = Vector3(3000, 4, 0)
	for i in 3:
		await get_tree().process_frame
	_check(absf(game.player.global_position.x) < WorldData.WORLD_RADIUS, "player cannot leave the island")

	# --- mining gives resources -------------------------------------------
	var ore = get_tree().get_nodes_in_group("ore")[0]
	var before: int = game.count_item(ore.ore_type)
	ore.hit(999.0)
	await get_tree().process_frame
	_check(game.count_item(ore.ore_type) > before, "mining gives %s" % ore.ore_type)

	# --- crafting ----------------------------------------------------------
	game.remove_item("stone", game.count_item("stone"))
	game.remove_item("copper", game.count_item("copper"))
	game.remove_item("iron", game.count_item("iron"))
	game.add_item("stone", 30)
	game.add_item("copper", 30)
	game.add_item("iron", 30)
	game.coins = 200
	game.craft(game.recipe_index("stone_pickaxe"))
	_check(game.pickaxe_name == "Stone Pickaxe", "stone pickaxe crafted")
	_check(game.count_item("stone") == 22, "stone cost paid")

	game.craft(game.recipe_index("weapon_iron_sword"))
	_check(game.sword_name == "Iron Sword", "iron sword crafted")
	_check(is_equal_approx(game.attack_power, 18.0), "iron sword damage is 18")

	# --- infusion is locked until you own a magic stone --------------------
	game.craft(game.recipe_index("infuse_rock"))
	_check(game.infused.is_empty(), "infusion blocked without magic stone")

	# --- boss leash: it never leaves its temple ----------------------------
	var rock_boss = null
	for b in game.bosses:
		if b.biome_id == "rock":
			rock_boss = b
	_check(rock_boss != null, "rock boss found")
	if rock_boss != null:
		rock_boss.global_position = rock_boss.home + Vector3(14, 1, 0)
		for i in 140:
			await get_tree().physics_frame
		var home_distance: float = rock_boss.global_position.distance_to(rock_boss.home)
		_check(home_distance <= WorldData.ARENA_RADIUS + 0.5, "boss walks back inside its temple (%.1fm)" % home_distance)

	# --- boss drops its stone and counts as defeated -----------------------
	game.remove_item("magic_rock", game.count_item("magic_rock"))
	game.remove_item("copper", game.count_item("copper"))  # make room in the bag
	var coins_before: int = game.coins
	rock_boss.take_damage(9999.0)
	await get_tree().process_frame
	_check(game.count_item("magic_rock") == 1, "rock boss drops its magic stone")
	_check(game.defeated_temples.has("rock"), "temple counted as beaten")
	_check(game.coins > coins_before, "boss drops coins")
	_check(game.bosses.size() == 8, "boss list stays complete")

	# --- infusion now works and adds damage --------------------------------
	game.craft(game.recipe_index("infuse_rock"))
	_check(game.infused.size() == 1, "sword infused with the rock stone")
	_check(is_equal_approx(game.attack_power, 25.0), "infusion adds 7 damage")
	_check(game.sword_name == "Iron Sword", "the weapon keeps its name when infused")
	_check(not game.can_afford(game.recipes[game.recipe_index("infuse_rock")]), "same stone cannot be infused twice")

	# --- magic stone powers, and mixing them --------------------------------
	var effect_monster = null
	for monster in get_tree().get_nodes_in_group("enemy"):
		if "form" in monster:
			effect_monster = monster
			break
	if effect_monster != null:
		game.infused["magic_fire"] = true
		game.apply_weapon_effects(effect_monster)
		_check(effect_monster.burn_time > 0.0, "the Fire stone sets monsters burning")
		game.infused["magic_ice"] = true
		game.apply_weapon_effects(effect_monster)
		_check(effect_monster.slow_time > 0.0, "the Ice stone slows monsters")
		game.infused["magic_uranium"] = true
		game.apply_weapon_effects(effect_monster)
		_check(effect_monster.poison_time > 0.0, "the Uranium stone poisons monsters")
		_check(game.infused_names().contains("Fire") and game.infused_names().contains("Ice"),
			"magic stones can be mixed")
		game.infused.erase("magic_fire")
		game.infused.erase("magic_ice")
		game.infused.erase("magic_uranium")
		game._refresh_attack()

	# --- weapons are priced by size ----------------------------------------
	var dagger_recipe: Dictionary = game.recipes[game.recipe_index("weapon_copper_dagger")]
	var spear_recipe: Dictionary = game.recipes[game.recipe_index("weapon_copper_spear")]
	_check(int(spear_recipe["cost"]["copper"]) > int(dagger_recipe["cost"]["copper"]),
		"a spear costs more metal than a dagger (%d vs %d)" % [
			int(spear_recipe["cost"]["copper"]), int(dagger_recipe["cost"]["copper"])])
	_check(int(spear_recipe["cost"]["coins"]) > int(dagger_recipe["cost"]["coins"]),
		"a spear also costs more coins")
	_check(float(spear_recipe["weapon_damage"]) > float(dagger_recipe["weapon_damage"]),
		"a spear hits harder than a dagger")

	# --- wood is a real weapon material -----------------------------------
	var wood_sword_index: int = game.recipe_index("weapon_wood_sword")
	var copper_sword_index: int = game.recipe_index("weapon_copper_sword")
	_check(wood_sword_index >= 0, "the forge sells wooden weapons")
	if wood_sword_index >= 0 and copper_sword_index >= 0:
		_check(float(game.recipes[wood_sword_index]["weapon_damage"])
			< float(game.recipes[copper_sword_index]["weapon_damage"]),
			"wood hits softer than copper")
	_check(game.item_label("wood") == "Wood", "wood has a name in the bag")

	game.add_item("copper", 30)
	game.coins = 200
	game.craft(game.recipe_index("weapon_copper_spear"))
	_check(game.sword_name == "Copper Spear", "the copper spear is in hand")
	_check(game.player.reach > 8.0, "the spear reaches further (%.1f m)" % game.player.reach)
	_check(game.player.swing_time > 0.4, "the spear swings slower")

	# --- selling -----------------------------------------------------------
	var sell_coins: int = game.coins
	game.remove_item("stone", game.count_item("stone"))
	game.add_item("stone", 10)
	game.craft(game.recipe_index("sell_stone"))
	_check(game.coins > sell_coins, "selling stone pays coins")

	# --- the wandering trader ----------------------------------------------
	for i in game.SLOT_COUNT:
		game.slots[i] = null
	game.coins = 100
	_check(game.trader_can_offer(game.TRADER_OFFERS[0]), "the trader can sell wood")
	game.trader_trade(0)
	_check(game.count_item("wood") == 10, "buying wood from the trader works")
	_check(game.coins == 85, "the trader takes 15 coins for wood")

	game.add_item("stone", 10)
	var trader_coins: int = game.coins
	game.trader_trade(game.TRADER_OFFERS.size() - 1)
	_check(game.count_item("stone") == 0, "the trader buys stone")
	_check(game.coins == trader_coins + 30, "selling stone pays trader coins")

	game.player.global_position = game.trader.global_position + Vector3(0, 1.2, 0)
	await get_tree().process_frame
	_check(game.near_trader, "you can walk up to the trader")
	game.hud.toggle_shop()
	_check(game.hud.shop_panel.visible, "the trader shop opens")
	game.hud.close_shop()
	_check(not game.hud.shop_panel.visible, "the trader shop closes")

	# --- forge menu builds every recipe ------------------------------------
	game.hud.toggle_forge()
	_check(game.hud.forge_panel.visible, "forge menu opens")
	_check(game.hud.forge_list.get_child_count() == game.recipes.size(), "forge menu lists all recipes")
	game.hud.toggle_forge()

	# --- monster biome leash ------------------------------------------------
	var fire_monster = null
	for monster in get_tree().get_nodes_in_group("enemy"):
		if "form" in monster and monster.form == "spike" and monster.global_position.y > -20.0:
			fire_monster = monster
			break
	_check(fire_monster != null, "fire biome monster found")
	if fire_monster != null:
		# Drop it just outside the Savanna, on the Plains side.
		fire_monster.global_position = Vector3(450, 1, 0)
		for i in 300:
			await get_tree().physics_frame
		_check(not fire_monster._outside_biome(), "monster walked back into its biome")

	# --- day and night ------------------------------------------------------
	game.time_of_day = 0.05  # deep night
	game._update_time_of_day()
	_check(game.is_night, "night detected")
	_check(game.night_monsters.size() > 0, "night spawns extra monsters (%d)" % game.night_monsters.size())
	_check(game.sun.light_energy < 0.4, "the sun is dimmed at night")

	var day_enemies: int = get_tree().get_nodes_in_group("enemy").size()
	game.time_of_day = 0.5  # noon
	game._update_time_of_day()
	await get_tree().process_frame
	_check(not game.is_night, "day detected")
	_check(game.night_monsters.is_empty(), "night monsters go away at dawn")
	_check(game.sun.light_energy > 0.8, "the sun is bright at noon")
	_check(get_tree().get_nodes_in_group("enemy").size() < day_enemies, "fewer monsters during the day")

	# --- safe zone ----------------------------------------------------------
	game.player.global_position = game.FORGE_POS + Vector3(0, 1.2, 2)
	game.player.velocity = Vector3.ZERO
	for i in 3:
		await get_tree().process_frame
	_check(game.in_safe_zone(), "the Forge is a safe zone")
	var safe_health: float = game.health
	game.damage_player(25.0)
	_check(is_equal_approx(game.health, safe_health), "no damage inside the safe zone")

	# --- monsters are pushed out of the safe zone ---------------------------
	var plain_monster = null
	for monster in get_tree().get_nodes_in_group("enemy"):
		if "form" in monster and monster.home_center == Vector2.ZERO:
			plain_monster = monster
			break
	_check(plain_monster != null, "plains monster found")
	if plain_monster != null:
		plain_monster.global_position = game.FORGE_POS + Vector3(0, 1.2, 3)
		for i in 340:
			await get_tree().physics_frame
		var from_forge: float = plain_monster.global_position.distance_to(game.FORGE_POS)
		_check(from_forge >= game.SAFE_RADIUS - 1.0, "monster pushed out of the safe zone (%.1fm)" % from_forge)

	# --- the huge connected underground -------------------------------------
	game.enter_cave()
	for i in 2:
		await get_tree().process_frame
	_check(game.in_cave, "player can enter the cave")
	_check(game.player.global_position.y < -20.0, "the cave is underground")
	for i in 40:
		await get_tree().physics_frame
	_check(game.player.is_on_floor(), "the cave floor is solid")
	_check(game.player.global_position.y > game.CAVE_ORIGIN.y - 8.0,
		"the player does not fall through the cave floor")
	_check(is_equal_approx(game.CAVE_RADIUS, WorldData.WORLD_RADIUS),
		"the underground is as wide as the surface")
	_check(game.underground_biome_at(game.player.global_position) == "normal",
		"the entrance is in the Normal Cave")
	_check(game.underground_biome_at(game.CAVE_ORIGIN + game.SPIKY_CENTER) == "spiky",
		"the Spiky Cave is in the west")
	_check(game.underground_biome_at(game.CAVE_ORIGIN + game.ICE_CENTER) == "ice",
		"the Ice Cave is in the south")
	_check(game.underground_biome_at(game.CAVE_ORIGIN + game.ACID_CENTER) == "acid",
		"the Acid Cave is in the east")
	_check(absf(game._boundary_offset(1, 600.0)) > 0.1, "the cave borders are wavy")
	_check(absf(game._cave_floor_height(800.0, 500.0)) > 0.1,
		"the cave floor is bumpy, not straight")
	_check(game.cave_bumps.size() >= 12, "the cave floor has extra rounded bumps")
	var test_bump: Dictionary = game.cave_bumps[0]
	var bump_extra: float = game._cave_bump_height(
		float(test_bump["x"]), float(test_bump["z"]))
	_check(bump_extra > 0.5, "the extra cave bumps rise up")

	# Even on a bumpy slope, the floor must catch the player.
	var bumpy_h: float = game._cave_floor_height(800.0, 500.0)
	game.player.global_position = game.CAVE_ORIGIN + Vector3(800.0, bumpy_h + 3.0, 500.0)
	game.player.velocity = Vector3.ZERO
	for i in 40:
		await get_tree().physics_frame
	_check(game.player.is_on_floor(), "the bumpy cave floor is solid too")
	_check(absf(game.player.global_position.y - (game.CAVE_ORIGIN.y + bumpy_h)) < 3.0,
		"the player stands on the bumpy cave floor")

	var shares := {}
	for biome in game.UNDERGROUND_BIOMES:
		shares[String(biome["id"])] = int(biome["share"])
	_check(shares["normal"] == 40 and shares["spiky"] == 30
		and shares["ice"] == 15 and shares["acid"] == 15,
		"the cave shares are 40 / 30 / 15 / 15")
	_check(get_tree().get_nodes_in_group("underground_landmark").size() >= 4,
		"the underground has land features")
	_check(get_tree().get_nodes_in_group("cave_formation").size() >= 150,
		"the caves have random formations and little mountains")
	_check(game.treasures.size() >= 4, "the underground has secret vaults")

	var uranium_count := 0
	for uranium_rock in get_tree().get_nodes_in_group("ore"):
		if "ore_type" in uranium_rock and String(uranium_rock.ore_type) == "uranium":
			uranium_count += 1
	_check(uranium_count >= 3, "the Acid Cave has uranium (%d rocks)" % uranium_count)

	var poison_monster = null
	for monster in get_tree().get_nodes_in_group("enemy"):
		if "poison_touch" in monster and bool(monster.poison_touch):
			poison_monster = monster
			break
	_check(poison_monster != null, "the Acid Cave has poisonous monsters")

	var exit_floor: float = game._cave_floor_height(game.CAVE_EXIT_PAD.x, game.CAVE_EXIT_PAD.z)
	game.player.global_position = game.CAVE_ORIGIN + Vector3(
		game.CAVE_EXIT_PAD.x, exit_floor + 1.2, game.CAVE_EXIT_PAD.z
	)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(game.near_cave_exit, "the gold pad leaves the underground")

	game.remove_item("copper", game.count_item("copper"))
	game.remove_item("wood", game.count_item("wood"))
	var thunder = null
	for b in game.bosses:
		if not is_instance_valid(b):
			continue
		if String(b.biome_id) == "thunder":
			thunder = b
	if thunder != null:
		thunder.take_damage(9999.0)
		await get_tree().process_frame
		_check(game.defeated_temples.has("thunder"), "the Storm Golem is defeated")
		_check(game.count_item("magic_thunder") == 1, "the Storm Golem drops the Thunder stone")

	game.remove_item("iron", game.count_item("iron"))
	var uranium_golem = null
	for b in game.bosses:
		if not is_instance_valid(b):
			continue
		if String(b.biome_id) == "uranium":
			uranium_golem = b
	if uranium_golem != null:
		uranium_golem.take_damage(9999.0)
		await get_tree().process_frame
		_check(game.defeated_temples.has("uranium"), "the Uranium Golem is defeated")
		_check(game.count_item("magic_uranium") == 1, "the Uranium Golem drops the Uranium stone")

	game.leave_cave()
	for i in 2:
		await get_tree().process_frame
	_check(not game.in_cave, "player can leave the cave")

	var smooth := 0
	for node in main.find_children("*", "MeshInstance3D", true, false):
		if node.mesh is SphereMesh or node.mesh is CapsuleMesh:
			smooth += 1
	_check(smooth == 0, "no smooth spheres left in the world (%d)" % smooth)

	# --- the bag: 9 slots, 15 per slot -------------------------------------
	_check(game.slots.size() == 9, "the bag has 9 slots")
	for i in game.SLOT_COUNT:
		game.slots[i] = null
	_check(game.add_item("stone", 20) == 0, "20 stone fit in the bag")
	_check(int(game.slots[0]["count"]) == 15 and int(game.slots[1]["count"]) == 5, "15 per slot, then a new slot")
	var overflow: int = game.add_item("stone", 200)
	_check(overflow > 0, "a full bag refuses extra items (%d left over)" % overflow)
	_check(game.count_item("stone") == 135, "the bag holds 9 x 15 = 135")

	# --- chests in the forge ------------------------------------------------
	_check(game.chests.size() >= 2, "chests exist in the forge (%d)" % game.chests.size())
	for i in game.SLOT_COUNT:
		game.slots[i] = null
	game.add_item("iron", 10)
	game.move_chest_item(0, 0, false)
	_check(game.count_item("iron") == 0, "a stack moves out of the bag")
	_check(game.chest_count(0, "iron") == 10, "the chest keeps the stack")
	game.move_chest_item(0, 0, true)
	_check(game.count_item("iron") == 10, "the stack comes back from the chest")
	_check(game.chest_count(0, "iron") == 0, "the chest is empty again")

	# --- bag screen ----------------------------------------------------------
	game.hud.toggle_inventory()
	_check(game.hud.inventory_panel.visible, "the bag screen opens")
	_check(game.hud.inv_buttons.size() == 9, "the bag screen shows 9 slots")
	game.hud.toggle_inventory()
	_check(not game.hud.inventory_panel.visible, "the bag screen closes")

	# --- the "!" key ---------------------------------------------------------
	var bang := InputEventKey.new()
	bang.pressed = true
	bang.unicode = 33  # "!"
	game._unhandled_input(bang)
	_check(game.hud.inventory_panel.visible, "the ! key opens the bag")
	game._unhandled_input(bang)
	_check(not game.hud.inventory_panel.visible, "the ! key closes the bag")

	# --- hands: sword, pickaxe, shield --------------------------------------
	_check(game.player.active_hand == 0, "the sword starts in the right hand")
	_check(not game.player.pickaxe.visible, "the pickaxe is not in hand at the start")

	var key_two := InputEventKey.new()
	key_two.pressed = true
	key_two.unicode = 50  # "2"
	game._unhandled_input(key_two)
	_check(game.player.active_hand == 1, "key 2 takes the pickaxe")
	_check(game.player.pickaxe.visible, "the pickaxe appears in the left hand")

	var key_one := InputEventKey.new()
	key_one.pressed = true
	key_one.unicode = 49  # "1"
	game._unhandled_input(key_one)
	_check(game.player.active_hand == 0, "key 1 takes the sword")

	# A sword barely scratches rock, the pickaxe really mines.
	var test_ore = null
	for ore_node in get_tree().get_nodes_in_group("ore"):
		if "alive" in ore_node and ore_node.alive:
			test_ore = ore_node
			break
	if test_ore != null:
		test_ore.hp = 100.0
		test_ore.max_hp = 100.0
		game.player.focus_node = test_ore
		game.player.select_hand(0)
		game.player.swing_timer = 0.0
		Input.action_press("use")
		game.player._handle_swing(0.0)
		Input.action_release("use")
		var sword_hit: float = 100.0 - test_ore.hp

		game.player.select_hand(1)
		game.player.swing_timer = 0.0
		Input.action_press("use")
		game.player._handle_swing(0.0)
		Input.action_release("use")
		var pick_hit: float = 100.0 - sword_hit - test_ore.hp
		_check(pick_hit > sword_hit * 3.0, "the pickaxe mines much faster than a sword (%.1f vs %.1f)" % [pick_hit, sword_hit])

	# A sword is good enough to chop wood (no pickaxe needed at the start).
	var wood_target = null
	for ore_node in get_tree().get_nodes_in_group("ore"):
		if "ore_type" in ore_node and String(ore_node.ore_type) == "wood":
			wood_target = ore_node
			break
	if wood_target != null:
		wood_target.hp = 10.0
		wood_target.max_hp = 10.0
		game.player.focus_node = wood_target
		game.player.select_hand(0)
		game.player.swing_timer = 0.0
		Input.action_press("use")
		game.player._handle_swing(0.0)
		Input.action_release("use")
		_check(10.0 - wood_target.hp >= 1.0, "a sword can chop wood")

	# --- the shield ----------------------------------------------------------
	game.remove_item("stone", game.count_item("stone"))
	for i in game.SLOT_COUNT:
		game.slots[i] = null
	game.add_item("stone", 20)
	game.coins = 100
	game.craft(game.recipe_index("shield"))
	_check(game.player.has_shield, "the shield is crafted")

	var key_three := InputEventKey.new()
	key_three.pressed = true
	key_three.unicode = 51  # "3"
	game._unhandled_input(key_three)
	_check(game.player.active_hand == 2, "key 3 takes the shield")
	_check(game.player.shield.visible, "the shield appears in the left hand")

	game.player.global_position = Vector3(200, 2, 0)
	await get_tree().process_frame
	Input.action_press("use")
	var blocked_health: float = game.health
	game.damage_player(20.0)
	var taken: float = blocked_health - game.health
	Input.action_release("use")
	_check(taken < 20.0 and taken > 0.0, "the shield blocks part of the damage (%.0f of 20)" % taken)
	game.player.select_hand(0)

	# --- drawing your own weapon --------------------------------------------
	var small_drawing := {}
	for y in 3:
		small_drawing[Vector2i(4, y)] = "copper"

	var big_drawing := {}
	for y in 12:
		for x in range(3, 6):
			big_drawing[Vector2i(x, y)] = "copper"

	var small_plan: Dictionary = game.weapon_plan(small_drawing)
	var big_plan: Dictionary = game.weapon_plan(big_drawing)
	_check(int(big_plan["metal"]) > int(small_plan["metal"]),
		"a taller drawing needs more metal (%d vs %d)" % [
			int(big_plan["metal"]), int(small_plan["metal"])])
	_check(int(big_plan["coins"]) > int(small_plan["coins"]), "a thicker drawing costs more coins")
	_check(int(big_plan["damage"]) > int(small_plan["damage"]), "a bigger drawing hits harder")
	_check(is_equal_approx(float(big_plan["height_m"]), 1.08), "height comes from the drawing (1.08 m)")

	for i in game.SLOT_COUNT:
		game.slots[i] = null
	game.add_item("copper", 40)
	game.coins = 200
	_check(game.forge_drawn_weapon(big_drawing), "the drawing is forged")
	_check(game.player.drawn_weapon.get_child_count() == 36, "the weapon is built from 36 blocks")
	_check(game.sword_name == "Drawn Copper Blade", "the drawn weapon has a name")
	_check(game.player.reach > 6.0, "the drawn weapon has its own reach (%.1f m)" % game.player.reach)
	_check(game.hud.material_buttons.size() == game.WEAPON_METALS.size(),
		"the drawing table offers every material (%d)" % game.hud.material_buttons.size())
	_check(game.hud.forge_button != null, "the drawing table has one forge button")

	# The same drawing painted in wood: cheaper metal, softer hits.
	var wood_drawing := {}
	for cell in big_drawing:
		wood_drawing[cell] = "wood"
	var wood_plan: Dictionary = game.weapon_plan(wood_drawing)
	for i in game.SLOT_COUNT:
		game.slots[i] = null
	game.add_item("wood", 40)
	game.coins = 200
	var copper_damage: int = int(game.attack_power)
	_check(game.forge_drawn_weapon(wood_drawing), "the wood drawing is forged")
	_check(game.sword_name == "Drawn Wood Blade", "the wooden drawn weapon has a name")
	_check(int(game.attack_power) < copper_damage,
		"wood hits softer than copper (%d vs %d)" % [int(game.attack_power), copper_damage])

	# A mixed drawing: wooden handle (bottom 3 rows), iron blade (top 9 rows).
	var mixed_drawing := {}
	for y in 12:
		for x in range(3, 6):
			mixed_drawing[Vector2i(x, y)] = "wood" if y < 3 else "iron"
	var mixed_plan: Dictionary = game.weapon_plan(mixed_drawing)
	_check(int(mixed_plan["materials"]["wood"]) == 5, "9 wooden squares cost 5 wood")
	_check(int(mixed_plan["materials"]["iron"]) == 14, "27 iron squares cost 14 iron")
	_check(int(mixed_plan["damage"]) > int(wood_plan["damage"]),
		"an iron blade hits harder than a wooden one")
	_check(int(mixed_plan["damage"]) > int(big_plan["damage"]),
		"mostly iron hits harder than all copper (%d vs %d)" % [
			int(mixed_plan["damage"]), int(big_plan["damage"])])

	for i in game.SLOT_COUNT:
		game.slots[i] = null
	game.add_item("wood", 10)
	game.add_item("iron", 20)
	game.coins = 200
	var wood_before: int = game.count_item("wood")
	var iron_before: int = game.count_item("iron")
	_check(game.forge_drawn_weapon(mixed_drawing), "a wood-and-iron drawing is forged")
	_check(game.sword_name == "Drawn Iron & Wood Blade", "the mixed weapon is named after both materials")
	_check(wood_before - game.count_item("wood") == 5, "the wooden handle costs 5 wood")
	_check(iron_before - game.count_item("iron") == 14, "the iron blade costs 14 iron")
	var block_colors := {}
	for part in game.player.drawn_weapon.get_children():
		block_colors[part.material_override.albedo_color] = true
	_check(block_colors.size() == 2, "the blade and the handle keep different materials")

	# --- a magic stone can be added while drawing --------------------------
	for i in game.SLOT_COUNT:
		game.slots[i] = null
	game.add_item("copper", 40)
	game.add_item("magic_fire", 1)
	game.coins = 200
	var fire_plan: Dictionary = game.weapon_plan(big_drawing)
	var coins_before_stone: int = game.coins
	var stone_damage := int(fire_plan["damage"])
	_check(game.forge_drawn_weapon(big_drawing, ["magic_fire"]),
		"a drawing can take a magic stone")
	_check(game.infused.has("magic_fire"), "the magic stone is infused into the weapon")
	_check(game.crafted.has("infuse_fire"), "the stone is marked as used")
	_check(game.count_item("magic_fire") == 0, "the magic stone is used up")
	_check(int(game.attack_power) == stone_damage + game.infused.size() * int(game.INFUSE_DAMAGE_BONUS),
		"the stone adds its +7 damage (%d total)" % int(game.attack_power))
	_check(game.coins == coins_before_stone - int(fire_plan["coins"]) - int(game.INFUSE_COIN_COST),
		"the stone also costs 25 coins (%d left)" % game.coins)
	var glow: Color = game._infused_glow()
	var first_block: StandardMaterial3D = game.player.drawn_materials.values()[0]
	_check(first_block.emission.is_equal_approx(glow), "the magic stone makes the weapon glow")

	# The palette chooses what a click paints, and every square remembers it.
	var canvas = game.hud.weapon_canvas
	canvas.cells.clear()
	game.hud._select_brush("iron")
	_check(canvas.brush == "iron", "the palette picks the paint material")
	_check(game.hud.material_buttons[3].button_pressed, "the chosen paint button stays pressed")
	var px := 4 * int(canvas.CELL) + 2
	var py := 10 * int(canvas.CELL) + 2
	canvas._paint(Vector2(px, py), true)
	_check(String(canvas.cells.get(Vector2i(4, 3), "")) == "iron",
		"a painted square keeps its material")
	canvas.cells.clear()

	for i in game.SLOT_COUNT:
		game.slots[i] = null
	game.add_item("magic_water", 1)
	game.hud.open_design()
	_check(game.hud.design_panel.visible, "the drawing table opens")
	_check(game.hud.selected_stones.is_empty(), "new stones start unselected")
	_check(game.hud.stone_row.get_child_count() >= 4,
		"the drawing table shows your magic stones (%d)" % game.hud.stone_row.get_child_count())
	game.hud._set_stone("magic_water", true)
	_check(game.hud.selected_stones.has("magic_water"), "a stone can be picked for the weapon")
	game.hud.close_design()
	_check(not game.hud.design_panel.visible, "the drawing table closes")
	game.hud.close_menus()

	# --- armour drawn piece by piece ---------------------------------------
	var armour_drawing := {}
	for y in 4:
		for x in range(3, 5):
			armour_drawing[Vector2i(x, y)] = "wood" if y < 2 else "iron"
	var armour_plan: Dictionary = game.weapon_plan(armour_drawing)
	var defence: int = game.armour_defense(armour_plan)
	_check(defence > 0, "a drawn armour piece has defence (%d%%)" % defence)

	for i in game.SLOT_COUNT:
		game.slots[i] = null
	game.add_item("wood", 10)
	game.add_item("iron", 10)
	game.coins = 100
	_check(game.forge_armour_piece("helmet", armour_drawing), "a helmet can be forged")
	_check(game.armour.has("helmet"), "the helmet is worn")
	_check(game.armour_total() == defence, "the helmet adds its defence")
	_check(game.player.armour_meshes["helmet"][0].visible, "the helmet shows on the character")

	game.player.global_position = Vector3(200, 2, 0)
	game.player.select_hand(0)
	game.health = 100.0
	game.damage_player(20.0)
	var taken_with_armour: float = 100.0 - game.health
	_check(taken_with_armour < 20.0 and taken_with_armour > 0.0,
		"armour reduces damage (%.1f of 20)" % taken_with_armour)

	game.hud.open_design()
	game.hud._select_design_tab("helmet")
	_check(game.hud.design_slot == "helmet", "the armour tab opens")
	_check(not game.hud.stone_row.visible, "magic stones are hidden for armour")
	game.hud._select_design_tab("weapon")
	_check(game.hud.stone_row.visible, "magic stones come back for the weapon")

	game.hud.weapon_canvas.cells = {Vector2i(4, 4): "iron"}
	game.hud._select_design_tab("pants")
	_check(game.hud.weapon_canvas.cells.is_empty(), "each armour piece has its own drawing")
	game.hud._select_design_tab("weapon")
	_check(game.hud.weapon_canvas.cells.has(Vector2i(4, 4)), "the weapon drawing is kept")
	game.hud.close_design()
	game.hud.close_menus()

	# --- taming the forest wolf --------------------------------------------
	game.player.global_position = game.wolf.global_position + Vector3(0, 1.2, 0)
	await get_tree().process_frame
	_check(game.near_wolf, "you can find the wolf in the Forest")
	game.tame_wolf()
	_check(game.wolf_tamed, "the wolf is tamed")
	_check(game.wolf.tamed, "the wolf knows it is tamed")
	_check(game.wolf.collar.visible, "the tamed wolf wears a collar")

	game.add_item("meat", 2)
	var wolf_level: int = game.wolf.level
	game.feed_wolf()
	_check(game.wolf.level == wolf_level + 1, "feeding the wolf trains it")
	game.toggle_wolf_stay()
	_check(game.wolf.stay, "the wolf can stay")
	game.toggle_wolf_stay()
	_check(not game.wolf.stay, "the wolf can follow again")

	game.player.global_position = Vector3(60, 2, 0)
	for i in 30:
		await get_tree().physics_frame
	game.player.select_hand(0)
	for i in 25:
		await get_tree().physics_frame
	_check(game.player.arm_pivots[1].rotation.x > 0.1, "the sword arm raises forward")
	_check(game.player.weapon.global_basis.y.dot(Vector3.UP) > 0.95, "the sword is held straight up")
	game.player.select_hand(1)
	for i in 25:
		await get_tree().physics_frame
	_check(game.player.arm_pivots[0].rotation.x > 0.1, "the pickaxe arm raises forward")
	_check(game.player.pickaxe.global_basis.y.dot(Vector3.UP) > 0.95, "the pickaxe is held straight up")

	# --- damage and teleport -----------------------------------------------
	game.player.global_position = Vector3(60, 2, 60)
	await get_tree().process_frame
	var health_before: float = game.health
	game.damage_player(20.0)
	_check(game.health < health_before, "player takes damage outside the safe zone")

	game.player.global_position = Vector3(60, 2, 60)
	game.teleport_to_forge()
	_check(game.player.global_position.distance_to(game.FORGE_POS) < 10.0, "teleport to forge")

	# --- village life --------------------------------------------------------
	var villager = game.villagers[0]
	game.player.global_position = villager.global_position + Vector3(0, 1.2, 1)
	await get_tree().process_frame
	_check(game.near_villager == villager, "you can talk to a villager")
	game.talk_to_villager(villager)
	_check(game.hud.log_label.text.contains("Mira"), "villagers say hello")

	# --- village quests ------------------------------------------------------
	game.player.global_position = game.QUEST_BOARD_POS + Vector3(0, 1.2, 2)
	await get_tree().process_frame
	_check(game.near_quest_board, "you can find the village quest board")
	game.hud.toggle_quests()
	_check(game.hud.quest_panel.visible, "the village quest panel opens")
	game.hud.close_quests()
	_check(not game.hud.quest_panel.visible, "the village quest panel closes")

	for i in game.SLOT_COUNT:
		game.slots[i] = null
	game.add_item("stone", 20)
	game.coins = 0
	_check(game.quest_can_do(game.VILLAGE_QUESTS[0]), "the village quest accepts 20 stone")
	game.do_quest(0)
	_check(game.coins == 80, "the village quest pays coins")
	_check(game.count_item("berry") == 2, "the village quest gives berries")
	_check(game.quests_done.has("village_fire"), "the village quest is marked done")
	var quest_coins: int = game.coins
	game.do_quest(0)
	_check(game.coins == quest_coins, "a village quest cannot be done twice")

	game.add_item("uranium", 3)
	var uranium_coins: int = game.coins
	game.do_quest(3)
	_check(game.quests_done.has("village_uranium"), "the uranium quest can be done")
	_check(game.coins == uranium_coins + 150, "the uranium quest pays 150 coins")

	game.add_item("meat", 10)
	var feast_coins: int = game.coins
	game.do_quest(4)
	_check(game.quests_done.has("village_feast"), "the meat feast quest can be done")
	_check(game.coins == feast_coins + 100, "the meat feast quest pays 100 coins")

	# --- campfire cooking ---------------------------------------------------
	game.player.global_position = game.CAMPFIRE_POS + Vector3(0, 1.2, 2)
	await get_tree().process_frame
	_check(game.near_campfire, "the campfire is at the Forge")
	game.hud.toggle_cooking()
	_check(game.hud.cooking_panel.visible, "the cooking panel opens")
	game.hud.close_cooking()
	_check(not game.hud.cooking_panel.visible, "the cooking panel closes")

	for i in game.SLOT_COUNT:
		game.slots[i] = null
	game.add_item("meat", 2)
	game.cook(0)
	_check(game.count_item("cooked_meat") == 1, "meat can be cooked")
	game.add_item("berry", 3)
	game.cook(1)
	_check(game.count_item("berry_jam") == 1, "berries can be made into jam")
	game.hunger = 20.0
	game.eat_food()
	_check(game.hunger > 50.0, "cooked meat fills the food bar")

	# --- farming ------------------------------------------------------------
	game.player.global_position = game.FARM_PLOTS[0] + Vector3(0, 1.2, 1)
	await get_tree().process_frame
	_check(game.near_farm_plot == 0, "the farm is at the Forge")
	for i in game.SLOT_COUNT:
		game.slots[i] = null
	game.add_item("berry", 1)
	game.use_farm_plot(0)
	_check(String(game.farm_state[0]["state"]) == "growing", "a berry can be planted")
	game.farm_state[0]["timer"] = 0.0
	game._update_farm(0.1)
	game.use_farm_plot(0)
	_check(game.count_item("berry") == 3, "the farm harvests berries")

	game.player.global_position = game.FARM_PLOTS[2] + Vector3(0, 1.2, 1)
	await get_tree().process_frame
	game.add_item("wheat_seed", 1)
	game.use_farm_plot(2)
	game.farm_state[2]["timer"] = 0.0
	game._update_farm(0.1)
	game.use_farm_plot(2)
	_check(game.count_item("wheat") == 3, "the farm grows wheat")

	game.player.global_position = game.FARM_PLOTS[3] + Vector3(0, 1.2, 1)
	await get_tree().process_frame
	game.add_item("carrot_seed", 1)
	game.use_farm_plot(3)
	game.farm_state[3]["timer"] = 0.0
	game._update_farm(0.1)
	game.use_farm_plot(3)
	_check(game.count_item("carrot") == 3, "the farm grows carrots")

	_check(get_tree().get_nodes_in_group("farm_animal").size() >= 4,
		"the farm pen has animals")
	for animal in game.farm_animals:
		animal.produce_ready = true
	var farm_animal = game.farm_animals[0]
	game.player.global_position = farm_animal.global_position + Vector3(0, 1.2, 0.2)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(game.near_farm_animal != null, "you can visit a farm animal")
	if game.near_farm_animal != null:
		var nearby = game.near_farm_animal
		var produce_before: int = game.count_item(nearby.produce_item)
		nearby.collect()
		_check(game.count_item(nearby.produce_item) > produce_before,
			"farm animals give food or wool")

	game.cook(3)
	_check(game.count_item("bread") == 1, "wheat can be baked into bread")
	game.cook(4)
	_check(game.count_item("carrot_soup") == 1, "carrots can be made into soup")

	# --- fishing ------------------------------------------------------------
	game.player.global_position = game.FISHING_POS + Vector3(0, 1.2, 4)
	await get_tree().process_frame
	_check(game.near_fishing, "the fishing pond is at the Forge")
	game.fishing_cooldown = 0.0
	game.fish()
	_check(game.count_item("fish") == 1, "fishing catches a fish")
	game.cook(2)
	_check(game.count_item("cooked_fish") == 1, "fish can be cooked")

	# --- secret underground vault ------------------------------------------
	var acid_vault: Dictionary = game.treasures[2]
	game.player.global_position = acid_vault["pos"] + Vector3(0, 1.2, 1)
	await get_tree().process_frame
	_check(game.near_treasure == 2, "a secret vault can be found")
	for i in game.SLOT_COUNT:
		game.slots[i] = null
	var vault_uranium: int = game.count_item("uranium")
	var vault_coins: int = game.coins
	game.collect_treasure(2)
	_check(game.count_item("uranium") > vault_uranium, "the secret vault has uranium")
	_check(game.coins > vault_coins, "the secret vault has coins")
	_check(game.treasures_found.has("acid_vault"), "the secret vault is marked found")

	# --- save and load -------------------------------------------------------
	var save_file: String = game.save_path()
	_check(save_file.ends_with("forge_test_save.json"), "tests use their own save file")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_file))
	for i in game.SLOT_COUNT:
		game.slots[i] = null
	game.add_item("magic_water", 2)
	game.add_item("magic_thunder", 1)
	game.add_item("magic_uranium", 1)
	game.hunger = 44.0
	game.coins = 123
	game.set_weather("snow")
	game.wolf.set_level(3)
	game.wolf.set_stay(true)
	game.farm_state[0]["state"] = "growing"
	game.farm_state[0]["timer"] = 10.0
	game._update_farm_visual(0)
	game.save_game()
	_check(FileAccess.file_exists(save_file), "the game writes a save file")

	var saved_attack: int = int(game.attack_power)
	game.coins = 1
	for i in game.SLOT_COUNT:
		game.slots[i] = null
	_check(game.load_game(), "the saved game loads")
	_check(game.coins == 123, "coins come back after loading")
	_check(game.count_item("magic_water") == 2, "items come back after loading")
	_check(game.armour.has("helmet"), "armour comes back after loading")
	_check(int(game.attack_power) == saved_attack, "weapon damage comes back after loading")
	_check(game.player.drawn_weapon.get_child_count() == 36, "the drawn weapon comes back after loading")
	_check(is_equal_approx(game.hunger, 44.0), "the food bar comes back after loading")
	_check(game.count_item("magic_thunder") == 1, "the Thunder stone comes back after loading")
	_check(game.quests_done.has("village_fire"), "village quests come back after loading")
	_check(game.wolf_tamed and game.wolf.tamed, "the tamed wolf comes back after loading")
	_check(game.wolf.level == 3, "wolf training comes back after loading")
	_check(game.wolf.stay, "the wolf stay command comes back after loading")
	_check(game.weather == "snow", "weather comes back after loading")
	_check(game.count_item("magic_uranium") == 1, "the Uranium stone comes back after loading")
	_check(String(game.farm_state[0]["state"]) == "growing", "the farm comes back after loading")
	_check(game.treasures_found.has("acid_vault"), "the secret vault comes back after loading")
	_check(game.defeated_temples.has("thunder"), "the Thunder Temple stays beaten after loading")
	_check(game.defeated_temples.has("uranium"), "the Uranium Temple stays beaten after loading")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_file))

	# --- the bow -------------------------------------------------------------
	for i in game.SLOT_COUNT:
		game.slots[i] = null
	game.add_item("wood", 10)
	game.add_item("iron", 5)
	game.coins = 100
	game.craft(game.recipe_index("bow"))
	_check(game.player.has_bow, "the Hunter's Bow is crafted")
	_check(game.sword_name == "Hunter's Bow", "the bow is in your hands")
	game.shoot_arrow(Vector3(0, 60, 0), Vector3(0, 0, -1), game.attack_power)
	await get_tree().process_frame
	_check(get_tree().get_nodes_in_group("arrow").size() > 0, "the bow shoots arrows")

	# --- draw your own bow ---------------------------------------------------
	game.hud.open_design()
	game.hud._select_design_tab("bow")
	_check(game.hud.design_slot == "bow", "the bow tab opens")
	_check(game.hud.stone_row.visible, "magic stones work on bows")
	game.hud.close_design()
	game.hud.close_menus()

	for i in game.SLOT_COUNT:
		game.slots[i] = null
	game.add_item("wood", 30)
	game.coins = 200
	var bow_cells := {}
	for y in 6:
		bow_cells[Vector2i(4, y)] = "wood"
	_check(game.forge_drawn_bow(bow_cells), "a bow can be drawn and forged")
	_check(game.player.has_bow and game.sword_name == "Drawn Bow",
		"the drawn bow is in your hands")

	# --- uranium sword and armour -------------------------------------------
	_check(game.WEAPON_METALS.size() == 6, "uranium is a drawing material")
	for i in game.SLOT_COUNT:
		game.slots[i] = null
	game.add_item("uranium", 30)
	game.coins = 300
	game.craft(game.recipe_index("weapon_uranium_sword"))
	_check(game.sword_name == "Uranium Sword", "a uranium sword can be forged")
	_check(is_equal_approx(game.weapon_base_damage, 24.0), "uranium is stronger than iron")

	var uranium_armour := {}
	for y in 4:
		for x in range(3, 5):
			uranium_armour[Vector2i(x, y)] = "uranium"
	for i in game.SLOT_COUNT:
		game.slots[i] = null
	game.add_item("uranium", 20)
	game.coins = 100
	_check(game.forge_armour_piece("chestplate", uranium_armour),
		"uranium armour can be drawn")
	_check(game.player.armour_meshes["chestplate"][0].visible,
		"the uranium chestplate is on your character")

	# --- pause menu ----------------------------------------------------------
	game.hud.open_pause()
	_check(game.hud.pause_panel.visible, "the pause menu opens")
	_check(get_tree().paused, "the game pauses")
	game.hud.close_pause()
	_check(not get_tree().paused, "the game resumes")

	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	game.hud._unhandled_input(escape)
	_check(game.hud.pause_panel.visible, "Escape opens the pause menu")
	game.hud._unhandled_input(escape)
	_check(not game.hud.pause_panel.visible and not get_tree().paused,
		"Escape closes the pause menu")

	# --- the final trial -----------------------------------------------------
	for stone_key in WorldData.STONE_KEYS:
		game.infused[String(stone_key)] = true
	game._refresh_attack()
	_check(game.final_portal_open(), "the final portal opens with all eight stones")
	game.enter_final()
	_check(game.in_final, "you can enter the final trial")
	_check(game.final_boss_node != null, "the Eight-Stone Guardian appears")
	game.final_boss_node.take_damage(99999.0)
	_check(game.final_boss_defeated, "the Eight-Stone Guardian is defeated")
	_check(game.hud.ending_panel.visible, "the ending screen appears")
	_check(get_tree().paused, "the ending pauses the game")
	game.hud.close_ending()
	_check(not get_tree().paused, "you can keep playing after the ending")

	# --- DLC: Sky Islands ---------------------------------------------------
	_check(game.sky_portal_open(), "the Sky Portal opens after the final boss")
	game.enter_sky()
	_check(game.in_sky, "you can enter the Sky Islands")
	_check(game.sky_dragon != null, "the Sky Dragon appears")
	var sky_before: int = game.count_item("sky_crystal")
	game.sky_dragon.take_damage(99999.0)
	_check(game.sky_dragon_defeated, "the Sky Dragon is defeated")
	_check(game.count_item("sky_crystal") >= sky_before + 6,
		"the Sky Dragon drops sky crystals")
	_check(game.hud.ending_panel.visible, "the DLC ending screen appears")
	game.hud.close_ending()
	_check(not get_tree().paused, "you can keep playing after the DLC")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.save_path()))

	print("")
	if failures == 0:
		print("SMOKE TEST: ALL PASSED")
		get_tree().quit(0)
	else:
		print("SMOKE TEST: %d FAILED" % failures)
		get_tree().quit(1)


func _check(condition: bool, what: String) -> void:
	if condition:
		print("  PASS  ", what)
	else:
		failures += 1
		printerr("  FAIL  ", what)
