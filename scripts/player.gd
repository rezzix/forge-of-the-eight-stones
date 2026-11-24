extends CharacterBody3D
## ============================================================================
##  THE PLAYER
## ============================================================================
##  Third-person controls:
##    - WASD moves you, relative to where the camera is looking
##    - Mouse orbits the camera, Shift runs, Space jumps
##    - Left click mines the ore / hits the monster you are aiming at
##
##  A short "ray" is fired from the middle of the screen every frame. Whatever
##  it touches becomes focus_node, so the game can show "mine this" prompts.
## ============================================================================

@export var walk_speed := 9.0
@export var run_speed := 15.0
@export var jump_force := 7.6
@export var mouse_sensitivity := 0.0025
@export var reach := 6.0          ## how far you can mine/hit
@export var swing_time := 0.32    ## seconds between two swings

var game                          ## set by game.gd before the player is added
var gravity := 18.0

var camera_pivot: Node3D
var spring_arm: SpringArm3D
var camera: Camera3D
var visuals: Node3D
var weapon: MeshInstance3D
var drawn_weapon: Node3D
var drawn_materials: Dictionary = {}   ## material id -> its 3D material
var drawn_cells: Dictionary = {}       ## the squares saved with a drawn weapon
var armour_meshes: Dictionary = {}     ## piece id -> the boxes you wear
var pickaxe: Node3D
var shield: Node3D
var bow: Node3D
var holder_left: Node3D
var holder_right: Node3D

# 0 = sword in the right hand, 1 = pickaxe in the left, 2 = shield in the left.
var active_hand := 0
var has_shield := false
var has_bow := false

var focus_node: Node3D = null
var swing_timer := 0.0
var slow_timer := 0.0
var speed_timer := 0.0
var kick_timer := 0.0

# Walk animation state.
var leg_pivots: Array[Node3D] = []
var arm_pivots: Array[Node3D] = []
var walk_phase := 0.0
var idle_phase := 0.0
var swim_phase := 0.0


func _ready() -> void:
	add_to_group("player")
	camera_pivot = $CameraPivot
	spring_arm = $CameraPivot/SpringArm3D
	camera = $CameraPivot/SpringArm3D/Camera3D
	visuals = $Visuals
	weapon = $Visuals/ArmPivotRight/ToolHolder/Weapon
	drawn_weapon = $Visuals/ArmPivotRight/ToolHolder/DrawnWeapon
	pickaxe = $Visuals/ArmPivotLeft/ToolHolder/Pickaxe
	shield = $Visuals/ArmPivotLeft/ToolHolder/Shield
	holder_left = $Visuals/ArmPivotLeft/ToolHolder
	holder_right = $Visuals/ArmPivotRight/ToolHolder
	leg_pivots = [$Visuals/LegPivotLeft, $Visuals/LegPivotRight]
	arm_pivots = [$Visuals/ArmPivotLeft, $Visuals/ArmPivotRight]
	_build_bow()
	_build_armour_meshes()
	_update_hands()

	gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 18.0))
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Mouse X turns the whole camera around the player.
		camera_pivot.rotate_y(-event.relative.x * mouse_sensitivity)
		# Mouse Y tilts the camera, but never upside down.
		spring_arm.rotation.x = clampf(
			spring_arm.rotation.x - event.relative.y * mouse_sensitivity, -1.35, 0.2
		)
	elif event is InputEventMouseButton and event.pressed:
		# Click the window to grab the mouse again after pressing Escape,
		# but never while a menu is open (you need the mouse for the slots).
		if game != null and game.hud != null and game.hud.menu_open():
			return
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and not _over_ui():
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _physics_process(delta: float) -> void:
	kick_timer = maxf(0.0, kick_timer - delta)
	if Input.is_action_just_pressed("kick") and not _menu_open():
		_kick()
	_move(delta)
	_update_focus()
	_handle_swing(delta)
	_animate(delta)


## A short kick for hunting animals without a weapon.
func _kick() -> void:
	if kick_timer > 0.0:
		return
	kick_timer = 0.8
	var target = null
	var best := 3.0
	for animal in get_tree().get_nodes_in_group("animal"):
		if animal == null or not is_instance_valid(animal):
			continue
		if "alive" in animal and not animal.alive:
			continue
		var d: float = animal.global_position.distance_to(global_position)
		if d < best:
			best = d
			target = animal
	if target != null:
		target.take_damage(6.0)
		if game != null:
			game.play_sound("hit")
			game._log("You kicked the %s!" % target.animal_kind)
		var tween := create_tween()
		tween.tween_property(leg_pivots[0], "rotation:x", -0.9, 0.08)
		tween.tween_property(leg_pivots[0], "rotation:x", 0.0, 0.16)


# ------------------------------------------------------------------ MOVING --
func _move(delta: float) -> void:
	var swimming := is_swimming()
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif Input.is_action_just_pressed("jump") and not swimming:
		velocity.y = jump_force

	# Input.get_vector gives -1..1 on both axes.
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	# Turning the input by the camera's direction = "walk where I'm looking".
	var direction := camera_pivot.global_basis * Vector3(input.x, 0.0, input.y)
	direction.y = 0.0

	var speed := run_speed if Input.is_action_pressed("sprint") else walk_speed
	if swimming:
		speed = walk_speed * (0.75 if Input.is_action_pressed("sprint") else 0.55)
	if slow_timer > 0.0:
		speed *= 0.5
		slow_timer = maxf(0.0, slow_timer - delta)
	if speed_timer > 0.0:
		speed *= 1.5
		speed_timer = maxf(0.0, speed_timer - delta)
	if direction.length() > 0.1:
		direction = direction.normalized()
		velocity.x = move_toward(velocity.x, direction.x * speed, 45.0 * delta)
		velocity.z = move_toward(velocity.z, direction.z * speed, 45.0 * delta)
		_turn_towards(direction, delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 55.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 55.0 * delta)

	move_and_slide()


func _turn_towards(direction: Vector3, delta: float) -> void:
	# The body smoothly turns to face the walking direction. The model's face
	# (eyes, weapon) points towards -Z, so we aim the -Z axis at the direction.
	# Shortest path, so it never spins the long way around.
	var target_angle := atan2(-direction.x, -direction.z)
	visuals.rotation.y = lerp_angle(visuals.rotation.y, target_angle, 12.0 * delta)


# ----------------------------------------------------------------- FOCUS ---
func _update_focus() -> void:
	# The ray starts at the camera (that's where the player aims) but it is long
	# enough to reach the ground in front of the player. Then we check the real
	# distance from the body, not from the camera, so mining range is fair.
	var from := camera.global_position
	var to := from + (-camera.global_basis.z) * (reach + 8.0)

	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	query.collide_with_areas = false

	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		focus_node = null
		return

	var collider = hit.get("collider")
	var hit_point: Vector3 = hit.get("position", Vector3.ZERO)
	var close_enough: bool = hit_point.distance_to(global_position) <= reach

	if close_enough and collider != null and collider.is_in_group("interactable"):
		focus_node = collider
	else:
		focus_node = null


# -------------------------------------------------------------------- HANDS --
func select_hand(index: int) -> void:
	if index == 2 and not has_shield:
		if game != null:
			game._log("You have no shield yet. Craft one at the Forge.")
		return
	active_hand = index
	_update_hands()


func set_has_shield(value: bool) -> void:
	has_shield = value


func set_bow(value: bool) -> void:
	has_bow = value
	_update_hands()


func set_bow_color(color: Color) -> void:
	if bow == null:
		return
	for child in bow.get_children():
		var mesh := child as MeshInstance3D
		if mesh == null:
			continue
		var mat := mesh.material_override as StandardMaterial3D
		if mat != null:
			mat.albedo_color = color


func _build_bow() -> void:
	bow = Node3D.new()
	holder_right.add_child(bow)

	var wood := Shapes.material(Color(0.5, 0.34, 0.18))
	var metal := Shapes.material(Color(0.78, 0.82, 0.9))

	var grip := Shapes.cube_node(Vector3(0.08, 0.28, 0.08), wood)
	bow.add_child(grip)

	var upper := Shapes.cube_node(Vector3(0.06, 0.55, 0.06), wood)
	upper.position = Vector3(0, 0.38, 0)
	upper.rotation.z = 0.22
	bow.add_child(upper)

	var lower := Shapes.cube_node(Vector3(0.06, 0.55, 0.06), wood)
	lower.position = Vector3(0, -0.38, 0)
	lower.rotation.z = -0.22
	bow.add_child(lower)

	var string := Shapes.cube_node(Vector3(0.015, 1.15, 0.015), metal)
	string.position = Vector3(0, 0, 0.06)
	bow.add_child(string)

	bow.visible = false


func _update_hands() -> void:
	if pickaxe != null:
		pickaxe.visible = active_hand == 1
	if shield != null:
		shield.visible = active_hand == 2
	if bow != null:
		bow.visible = active_hand == 0 and has_bow
	# The sword (or your drawn weapon) is in the right hand.
	var has_drawing := drawn_weapon != null and drawn_weapon.get_child_count() > 0
	if weapon != null:
		weapon.visible = active_hand == 0 and not has_drawing and not has_bow
	if drawn_weapon != null:
		drawn_weapon.visible = active_hand == 0 and has_drawing and not has_bow


## Builds the 3D weapon from the squares the player drew. Every square keeps
## the material it was painted with, so the blade can be iron while the handle
## is wood. One square = 9 cm, so a 14-square-tall drawing is 1.26 m long.
func build_drawn_weapon(cells: Dictionary) -> void:
	for child in drawn_weapon.get_children():
		drawn_weapon.remove_child(child)
		child.queue_free()
	drawn_materials.clear()

	drawn_cells = cells.duplicate(true)

	var block := 0.09
	for cell in cells:
		var material_id := _cell_material(cells[cell])
		var mat: StandardMaterial3D = drawn_materials.get(material_id)
		if mat == null:
			var color := Color(0.85, 0.55, 0.3)
			if game != null:
				color = game.material_color(material_id)
			mat = StandardMaterial3D.new()
			mat.albedo_color = color
			mat.roughness = 0.45
			mat.emission_enabled = true
			mat.emission = color * 0.4
			mat.emission_energy_multiplier = 0.6
			drawn_materials[material_id] = mat

		var part := MeshInstance3D.new()
		part.mesh = Shapes.cube(Vector3(block * 0.96, block * 0.96, block * 0.6))
		part.material_override = mat
		part.position = Vector3((cell.x - 4.0) * block, (cell.y + 0.5) * block, 0.0)
		drawn_weapon.add_child(part)

	_update_hands()


func _cell_material(value) -> String:
	if value is String:
		return String(value)
	if value is StringName:
		return String(value)
	return "copper"


## Goes back to the normal sword after you forge a regular weapon.
func clear_drawn_weapon() -> void:
	for child in drawn_weapon.get_children():
		drawn_weapon.remove_child(child)
		child.queue_free()
	drawn_materials.clear()
	drawn_cells.clear()
	_update_hands()


# --------------------------------------------------------------- ARMOUR ---
## Simple boxes sitting on the head, chest and legs. They move with the legs
## because the pants and boots are children of the leg pivots.
func _build_armour_meshes() -> void:
	var gray := Color(0.8, 0.8, 0.85)

	var helmet := Shapes.cube_node(Vector3(0.52, 0.18, 0.5), Shapes.material(gray))
	helmet.position = Vector3(0, 1.84, 0)
	visuals.add_child(helmet)
	var crest := Shapes.cube_node(Vector3(0.1, 0.14, 0.36), Shapes.material(gray))
	crest.position = Vector3(0, 1.96, 0.04)
	visuals.add_child(crest)
	armour_meshes["helmet"] = [helmet, crest]

	var chest := Shapes.cube_node(Vector3(0.68, 0.5, 0.46), Shapes.material(gray))
	chest.position = Vector3(0, 1.12, 0)
	visuals.add_child(chest)
	armour_meshes["chestplate"] = [chest]

	var pants: Array = []
	var boots: Array = []
	for i in leg_pivots.size():
		var pant := Shapes.cube_node(Vector3(0.26, 0.3, 0.3), Shapes.material(gray))
		pant.position = Vector3(0, -0.12, 0)
		leg_pivots[i].add_child(pant)
		pants.append(pant)

		var boot := Shapes.cube_node(Vector3(0.26, 0.16, 0.34), Shapes.material(gray))
		boot.position = Vector3(0, -0.57, -0.02)
		leg_pivots[i].add_child(boot)
		boots.append(boot)
	armour_meshes["pants"] = pants
	armour_meshes["boots"] = boots

	clear_armour()


func set_armour_piece(piece_id: String, color: Color) -> void:
	if not armour_meshes.has(piece_id):
		return
	for node in armour_meshes[piece_id]:
		var mesh := node as MeshInstance3D
		mesh.visible = true
		var mat := mesh.material_override as StandardMaterial3D
		if mat == null:
			mat = StandardMaterial3D.new()
			mesh.material_override = mat
		mat.albedo_color = color
		mat.roughness = 0.55
		mat.metallic = 0.15


func clear_armour() -> void:
	for piece_id in armour_meshes:
		for node in armour_meshes[piece_id]:
			(node as MeshInstance3D).visible = false


## The shield only protects while you hold left click with it in hand
## (and no menu is open).
func is_blocking() -> bool:
	return active_hand == 2 and Input.is_action_pressed("use") and not _menu_open()


# ------------------------------------------------------------- MINE / HIT --
func _handle_swing(delta: float) -> void:
	swing_timer = maxf(0.0, swing_timer - delta)
	if swing_timer > 0.0:
		return
	if not Input.is_action_pressed("use"):
		return
	if _menu_open():
		return  # a menu is open, don't swing
	if has_bow and active_hand == 0:
		swing_timer = maxf(swing_time, 0.45)
		_shoot_bow()
		return
	if focus_node == null:
		swing_timer = swing_time
		return

	swing_timer = swing_time
	if active_hand != 2:
		_swing_animation()

	if focus_node.is_in_group("ore"):
		if game != null:
			game.play_sound("mine")
		var is_wood: bool = "ore_type" in focus_node \
			and String(focus_node.ore_type) == "wood"
		if active_hand == 1:
			focus_node.hit(game.mining_power)
		elif is_wood:
			# A sword is fine for chopping wood (both hands work).
			focus_node.hit(1.0)
		else:
			# A sword barely scratches a rock.
			focus_node.hit(0.5)
			if game != null:
				game._log("Press 2 to hold your pickaxe and mine properly.")
	elif focus_node.is_in_group("tree"):
		if game != null:
			game.play_sound("mine")
		focus_node.hit(1.0)
	elif focus_node.is_in_group("enemy"):
		var cooked_food: bool = game != null and game.infused.has("magic_fire")
		if active_hand == 0:
			if focus_node.is_in_group("animal"):
				focus_node.take_damage(game.attack_power, cooked_food)
			else:
				focus_node.take_damage(game.attack_power)
		elif active_hand == 1:
			if focus_node.is_in_group("animal"):
				focus_node.take_damage(game.attack_power * 0.5, cooked_food)
			else:
				focus_node.take_damage(game.attack_power * 0.5)
		if game != null:
			game.play_sound("hit")
			game.apply_weapon_effects(focus_node)


func _shoot_bow() -> void:
	if game == null or camera == null:
		return
	var origin := camera.global_position + (-camera.global_basis.z) * 1.0
	var direction := -camera.global_basis.z
	game.shoot_arrow(origin, direction, game.attack_power)
	game.play_sound("bow")


func _swing_animation() -> void:
	# Swing whichever tool is in the active hand.
	var tool: Node3D = null
	if active_hand == 0:
		tool = drawn_weapon if drawn_weapon.get_child_count() > 0 else weapon
	elif active_hand == 1:
		tool = pickaxe
	else:
		return
	if tool == null:
		return
	# A forward chop: up, then down, then back to straight.
	var tween := create_tween()
	tween.tween_property(tool, "rotation:x", 0.6, 0.06)
	tween.tween_property(tool, "rotation:x", -0.5, 0.08)
	tween.tween_property(tool, "rotation:x", 0.0, 0.15)


# --------------------------------------------------------------- ANIMATION --
## A hand-made walk cycle, because our character is just boxes on pivots.
## The legs and arms swing in opposite pairs, the body bobs, and the faster
## you go the bigger and quicker the swing.
func is_swimming() -> bool:
	return game != null and game.is_in_water(global_position)


func _animate(delta: float) -> void:
	var flat_speed := Vector2(velocity.x, velocity.z).length()
	if is_swimming():
		_animate_swim(delta, flat_speed)
		return
	var on_floor := is_on_floor()
	var moving := on_floor and flat_speed > 0.6

	if not on_floor:
		# Jump / fall: tuck the legs and lift the arms forward.
		_pose(leg_pivots[0], -0.55, delta, 10.0)
		_pose(leg_pivots[1], -0.35, delta, 10.0)
		_pose(arm_pivots[0], 0.9, delta, 10.0)
		_pose(arm_pivots[1], 0.9, delta, 10.0)
		visuals.position.y = lerp(visuals.position.y, 0.0, 12.0 * delta)
		visuals.rotation.x = lerp(visuals.rotation.x, 0.0, 10.0 * delta)
	elif moving:
		# Faster = bigger steps and a faster cycle.
		var blend := clampf(flat_speed / run_speed, 0.0, 1.0)
		walk_phase += delta * (7.0 + flat_speed * 0.9)
		var swing := 0.85 * blend
		var s := sin(walk_phase)

		leg_pivots[0].rotation.x = s * swing
		leg_pivots[1].rotation.x = -s * swing
		if active_hand == 0:
			# Sword hand stays up in front, the free left arm swings.
			arm_pivots[0].rotation.x = -s * swing * 0.9
			arm_pivots[1].rotation.x = lerp(arm_pivots[1].rotation.x, 0.6, 10.0 * delta)
		else:
			# Pickaxe or shield stays up in front, in the left hand.
			arm_pivots[0].rotation.x = lerp(arm_pivots[0].rotation.x, 1.05, 10.0 * delta)
			arm_pivots[1].rotation.x = s * swing * 0.9

		# Two little bounces per step, and lean forward a bit.
		visuals.position.y = absf(s) * 0.06 * blend
		visuals.rotation.x = lerp(visuals.rotation.x, -0.1 * blend, 8.0 * delta)
	else:
		# Standing still: breathe, arms hanging.
		idle_phase += delta * 1.8
		var breathe := sin(idle_phase) * 0.05
		_pose(leg_pivots[0], 0.0, delta, 8.0)
		_pose(leg_pivots[1], 0.0, delta, 8.0)
		if active_hand == 0:
			_pose(arm_pivots[0], breathe, delta, 8.0)
			_pose(arm_pivots[1], 0.6, delta, 8.0)
		else:
			_pose(arm_pivots[0], 1.05, delta, 8.0)
			_pose(arm_pivots[1], -breathe, delta, 8.0)
		visuals.position.y = lerp(visuals.position.y, 0.0, 10.0 * delta)
		visuals.rotation.x = lerp(visuals.rotation.x, 0.0, 8.0 * delta)

	# Whatever the arm does, the tool keeps pointing straight up.
	_align_holders()


## In water the body floats forward and the arms and legs paddle.
func _animate_swim(delta: float, flat_speed: float) -> void:
	swim_phase += delta * (5.0 + flat_speed * 0.3)
	visuals.rotation.x = lerp(visuals.rotation.x, -1.0, 8.0 * delta)
	visuals.position.y = 0.3 + sin(swim_phase * 2.0) * 0.06
	leg_pivots[0].rotation.x = sin(swim_phase) * 0.55
	leg_pivots[1].rotation.x = -sin(swim_phase) * 0.55
	arm_pivots[0].rotation.x = 1.15 + sin(swim_phase) * 0.35
	arm_pivots[1].rotation.x = 1.15 - sin(swim_phase) * 0.35
	_align_holders()


## The arm swings, but the hand stays vertical, so the tool is held straight.
func _align_holders() -> void:
	if holder_right != null:
		holder_right.rotation.x = -arm_pivots[1].rotation.x
	if holder_left != null:
		holder_left.rotation.x = -arm_pivots[0].rotation.x


func _pose(pivot: Node3D, target: float, delta: float, sharpness: float) -> void:
	pivot.rotation.x = lerp(pivot.rotation.x, target, sharpness * delta)


# --------------------------------------------------------------- TAKE HIT --
func take_damage(amount: float) -> void:
	if game != null:
		game.damage_player(amount)


## Ice boss: your legs get heavy.
func apply_slow(seconds: float) -> void:
	slow_timer = maxf(slow_timer, seconds)


## Speed potion: run faster for a few seconds.
func apply_speed(seconds: float) -> void:
	speed_timer = maxf(speed_timer, seconds)


## Water boss: shove the player away.
func push(direction: Vector3, force: float) -> void:
	velocity += direction.normalized() * force
	velocity.y = maxf(velocity.y, 3.0)


## The weapon mesh grows with the weapon's size (a spear is much longer than a dagger).
func set_weapon_length(meters: float) -> void:
	weapon.scale = Vector3(1.0, clampf(meters / 0.9, 0.5, 3.0), 1.0)


func set_weapon_color(color: Color) -> void:
	var mat := weapon.material_override as StandardMaterial3D
	if mat == null:
		mat = StandardMaterial3D.new()
		weapon.material_override = mat
	mat.albedo_color = color
	# Better gear glows a little, so upgrades feel good.
	if color.r > 0.9 and color.g > 0.6:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 1.4
	else:
		mat.emission_enabled = false

	# Keep the wood/iron colours of a drawn weapon, and add the magic glow on top.
	for entry in drawn_materials.values():
		var drawn := entry as StandardMaterial3D
		drawn.emission_enabled = true
		drawn.emission = color
		drawn.emission_energy_multiplier = 1.2


func _over_ui() -> bool:
	var control := get_viewport().gui_get_hovered_control()
	return control != null


func _menu_open() -> bool:
	return game != null and game.hud != null and game.hud.menu_open()
