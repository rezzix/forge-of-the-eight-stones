extends Node
## Dev helper: opens the game, takes screenshots from a few spots, closes itself.
## Run with: godot --path . res://tests/screenshot.tscn

func _ready() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame

	# --- daytime scenes ----------------------------------------------------
	main.time_of_day = 0.38
	main._update_time_of_day()
	await _stand(main, Vector3(0, 0, 14), 0.0)
	await _save("shot1_forge")

	# --- walking animation --------------------------------------------------
	main.player.global_position = Vector3(0, 1.2, 34)
	main.player.velocity = Vector3.ZERO
	main.player.camera_pivot.rotation.y = 0.0
	Input.action_press("move_forward")
	for i in 16:
		await get_tree().process_frame
	await _save("shot_walk")

	Input.action_press("jump")
	await get_tree().physics_frame
	Input.action_release("jump")
	for i in 7:
		await get_tree().process_frame
	await _save("shot_jump")
	Input.action_release("move_forward")

	# --- hands: sword, pickaxe, shield --------------------------------------
	main.player.global_position = Vector3(0, 1.2, 34)
	main.player.velocity = Vector3.ZERO
	main.player.camera_pivot.rotation.y = PI
	main.player.spring_arm.spring_length = 2.8
	main.player.spring_arm.rotation.x = -0.12
	for i in 12:
		await get_tree().process_frame
	await _save("shot_hand_sword")

	main.player.select_hand(1)
	for i in 12:
		await get_tree().process_frame
	await _save("shot_hand_pickaxe")

	main.player.set_has_shield(true)
	main.player.select_hand(2)
	for i in 12:
		await get_tree().process_frame
	await _save("shot_hand_shield")

	main.player.set_has_shield(false)
	main.player.select_hand(0)
	main.player.camera_pivot.rotation.y = 0.0
	main.player.spring_arm.spring_length = 5.6
	main.player.spring_arm.rotation.x = -0.3

	# --- a tall weapon: bigger price, longer blade --------------------------
	main.add_item("copper", 20)
	main.coins = 200
	main.craft(main.recipe_index("weapon_copper_spear"))
	main.player.global_position = Vector3(0, 1.2, 34)
	main.player.velocity = Vector3.ZERO
	main.player.camera_pivot.rotation.y = PI * 0.5
	main.player.spring_arm.spring_length = 4.2
	main.player.spring_arm.rotation.x = -0.18
	for i in 14:
		await get_tree().process_frame
	await _save("shot_spear")
	main.player.camera_pivot.rotation.y = 0.0
	main.player.spring_arm.spring_length = 5.6
	main.player.spring_arm.rotation.x = -0.3

	# --- every monster shape ----------------------------------------------
	for entry in [["fire", "spike"], ["plants", "plant"], ["poison", "mushroom"], ["water", "blob"], ["ice", "crystal"]]:
		var monster = _find_form(entry[1])
		if monster == null:
			continue
		await _stand_near(main, monster.global_position)
		await _save("shot_mob_" + String(entry[0]))

	# --- the boss -----------------------------------------------------------
	for boss in main.bosses:
		if boss.biome_id == "rock":
			await _stand_near(main, boss.global_position)
			await _save("shot_boss")
			break

	# --- night --------------------------------------------------------------
	main.time_of_day = 0.02
	main._update_time_of_day()
	await _stand(main, Vector3(0, 0, 14), 0.0)
	await _save("shot_night")

	# --- aerial map (day) ---------------------------------------------------
	main.time_of_day = 0.45
	main._update_time_of_day()
	main.world_env.environment.fog_density = 0.00002
	main.player.camera.near = 20.0
	main.player.global_position = Vector3(0, 2, 0)
	main.player.spring_arm.spring_length = 1600.0
	main.player.spring_arm.rotation.x = -1.45
	main.player.camera_pivot.rotation.y = 0.0
	for i in 20:
		await get_tree().process_frame
	await _save("shot_map")
	main.player.spring_arm.spring_length = 5.6
	main.player.spring_arm.rotation.x = -0.3
	main.player.camera.near = 0.05

	# --- cave entrance on the surface --------------------------------------
	await _stand_near(main, main.CAVE_ENTRANCE + Vector3(0, 1.0, 0))
	await _save("shot_cave_entrance")

	# --- water channel + bridge to the Savanna -----------------------------
	await _stand(main, Vector3(470, 1.5, 0), -PI / 2.0)
	await _save("shot_channel")

	# --- safe zone and cave ------------------------------------------------
	main.time_of_day = 0.4
	main._update_time_of_day()
	await _stand(main, Vector3(0, 1.5, 45), 0.0)
	await _save("shot_safe_zone")

	main.enter_cave()
	await _stand(main, main.CAVE_ORIGIN + main.CAVE_ARRIVAL, 3.0)
	await _save("shot_cave")
	main.leave_cave()

	# --- forge menu ---------------------------------------------------------
	main.player.global_position = Vector3(0, 1.2, 4)
	main.add_item("stone", 12)
	main.add_item("copper", 9)
	main.add_item("iron", 9)
	main.add_item("magic_fire", 1)
	main.crafted["iron_weapon"] = true
	for i in 10:
		await get_tree().process_frame
	main.hud.toggle_forge()
	await get_tree().process_frame
	await _save("shot_forge_menu")
	main.hud.toggle_forge()

	# --- drawing table -------------------------------------------------------
	main.add_item("copper", 40)
	main.coins = 200
	main.hud.toggle_forge()
	main.hud.open_design()
	var canvas = main.hud.weapon_canvas
	for y in 13:
		canvas.cells[Vector2i(4, y)] = "wood" if y < 3 else "iron"
	for x in range(3, 6):
		canvas.cells[Vector2i(x, 1)] = "wood"
	canvas.cells[Vector2i(3, 0)] = "wood"
	canvas.cells[Vector2i(5, 0)] = "wood"
	canvas.queue_redraw()
	canvas.changed.emit()
	await get_tree().process_frame
	await _save("shot_design")

	# Forge it, then show the weapon in hand.
	main.hud._forge_drawing()
	main.hud.close_menus()
	main.player.global_position = Vector3(0, 1.2, 34)
	main.player.velocity = Vector3.ZERO
	main.player.camera_pivot.rotation.y = PI * 0.5
	main.player.spring_arm.spring_length = 4.2
	main.player.spring_arm.rotation.x = -0.18
	for i in 16:
		await get_tree().process_frame
	await _save("shot_drawn_weapon")
	main.player.camera_pivot.rotation.y = 0.0
	main.player.spring_arm.spring_length = 5.6
	main.player.spring_arm.rotation.x = -0.3

	# --- the bag screen -----------------------------------------------------
	main.hud.toggle_inventory()
	await get_tree().process_frame
	await _save("shot_bag")
	main.hud.toggle_inventory()

	# --- a chest -------------------------------------------------------------
	main.move_chest_item(0, 0, false)
	main.player.global_position = Vector3(4.6, 1.2, 6.4)
	main.hud.toggle_chest(0)
	await get_tree().process_frame
	await _save("shot_chest")

	get_tree().quit()


func _stand(main, pos: Vector3, yaw: float) -> void:
	main.player.global_position = pos
	main.player.velocity = Vector3.ZERO
	main.player.camera_pivot.rotation.y = yaw
	for i in 15:
		await get_tree().process_frame


func _stand_near(main, target: Vector3) -> void:
	# Stand a little to the side so the monster is not hidden behind you.
	var pos: Vector3 = target + Vector3(2.5, 1.2, 6.5)
	main.player.global_position = pos
	main.player.velocity = Vector3.ZERO
	var to_target: Vector3 = (target - pos)
	main.player.camera_pivot.rotation.y = atan2(-to_target.x, -to_target.z) + 0.3
	for i in 20:
		await get_tree().process_frame


func _find_form(form_name: String):
	for monster in get_tree().get_nodes_in_group("enemy"):
		if "form" in monster and String(monster.form) == form_name:
			return monster
	return null


func _save(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/%s.png" % shot_name)
	print("saved ", shot_name)
