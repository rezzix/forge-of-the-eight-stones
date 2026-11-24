extends CharacterBody3D
## ============================================================================
##  TEMPLE BOSS (cubes and triangles only)
## ============================================================================
##  Every biome has its own boss. They all use this script and only change
##  their colours, size and one special ability:
##
##    none    - the Rock Golem: slow, very tough
##    burn    - sets you on fire (damage every second)
##    regen   - heals itself during the fight
##    slow    - your legs get heavy for a few seconds
##    push    - knocks you flying
##    poison  - damage every second, green version
##
##  THE LEASH: the boss remembers its temple (home). If it ever ends up more
##  than arena_radius away, it stops chasing and walks back inside. Bosses can
##  never leave their temple.
## ============================================================================

@export var boss_name := "ROCK GOLEM"
@export var max_hp := 160.0
@export var move_speed := 4.8
@export var touch_damage := 14.0
@export var coin_reward := 60
@export var ability := "none"
@export var stone_key := "magic_rock"
@export var stone_name := "Rock Magic Stone"
@export var biome_id := "rock"
@export var final_boss := false
@export var sky_boss := false
@export var body_color := Color(0.36, 0.31, 0.3)
@export var eye_color := Color(1.0, 0.45, 0.15)

var home := Vector3.ZERO
var arena_radius := 11.0

var hp := 160.0
var game                    ## set by game.gd before adding to the tree
var player: Node3D
var gravity := 18.0
var attack_timer := 0.0
var visual: Node3D
var visual_base_scale := Vector3.ONE
var returning_home := false
var status_marker: MeshInstance3D

# Magic-stone effects that are ticking on this boss.
var burn_time := 0.0
var burn_dps := 0.0
var poison_time := 0.0
var poison_dps := 0.0
var slow_time := 0.0
var stun_time := 0.0
var dot_accum := 0.0


func _ready() -> void:
	add_to_group("enemy")
	add_to_group("boss")
	add_to_group("interactable")
	hp = max_hp
	gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 18.0))
	_build_body()


# --------------------------------------------------------------- SHAPES ----
## A big blocky golem: cube legs, cube torso, cube head, two triangle horns.
func _build_body() -> void:
	visual = Node3D.new()
	visual.name = "Visual"
	add_child(visual)

	var mat := Shapes.material(body_color)
	var dark := Shapes.material(body_color.darkened(0.35))
	var eye_mat := Shapes.material(eye_color, true)

	_add_part(Shapes.cube(Vector3(0.5, 0.7, 0.55)), mat, Vector3(-0.42, 0.35, 0))
	_add_part(Shapes.cube(Vector3(0.5, 0.7, 0.55)), mat, Vector3(0.42, 0.35, 0))
	_add_part(Shapes.cube(Vector3(1.7, 1.9, 1.3)), mat, Vector3(0, 1.15, 0))
	_add_part(Shapes.cube(Vector3(0.45, 1.5, 0.45)), mat, Vector3(-1.05, 1.35, 0))
	_add_part(Shapes.cube(Vector3(0.45, 1.5, 0.45)), mat, Vector3(1.05, 1.35, 0))
	_add_part(Shapes.cube(Vector3(1.1, 0.95, 1.05)), mat, Vector3(0, 2.45, 0))
	_add_part(Shapes.pyramid(0.42, 0.8), dark, Vector3(-0.34, 2.9, 0))
	_add_part(Shapes.pyramid(0.42, 0.8), dark, Vector3(0.34, 2.9, 0))

	for side in [-1.0, 1.0]:
		var eye := Shapes.cube_node(Vector3(0.2, 0.2, 0.1), eye_mat)
		eye.position = Vector3(side * 0.26, 2.5, -0.55)
		visual.add_child(eye)

	# A glowing gem in the chest, in the boss's element colour.
	var gem := Shapes.cube_node(Vector3(0.26, 0.26, 0.1), eye_mat)
	gem.position = Vector3(0, 1.5, -0.66)
	visual.add_child(gem)

	status_marker = Shapes.cube_node(
		Vector3(0.26, 0.26, 0.26),
		Shapes.material(Color(1.0, 0.6, 0.2), true)
	)
	status_marker.position.y = 3.6
	status_marker.visible = false
	add_child(status_marker)


func _add_part(mesh: Mesh, mat: Material, pos: Vector3) -> void:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = mat
	part.position = pos
	visual.add_child(part)


# --------------------------------------------------------------- MOVING ----
func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")

	_tick_status(delta)
	if hp <= 0.0:
		return

	if not is_on_floor():
		velocity.y -= gravity * delta

	if stun_time > 0.0:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	# --- THE LEASH -------------------------------------------------------
	var from_home := Vector3(global_position.x - home.x, 0.0, global_position.z - home.z)
	returning_home = from_home.length() > arena_radius

	if returning_home:
		var back := (-from_home).normalized()
		velocity.x = back.x * _current_speed()
		velocity.z = back.z * _current_speed()
		_face(back, delta)
		move_and_slide()
		return

	# --- NORMAL FIGHTING -------------------------------------------------
	var to_player := Vector3.ZERO
	if player != null:
		to_player = player.global_position - global_position
		to_player.y = 0.0

	if player != null and to_player.length() < 32.0:
		_chase(to_player, delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)

	# Plants boss slowly heals while it fights.
	if ability == "regen" and hp < max_hp:
		hp = minf(max_hp, hp + 4.0 * delta)

	move_and_slide()


func _chase(to_player: Vector3, delta: float) -> void:
	var distance := to_player.length()
	var direction := to_player.normalized()
	velocity.x = direction.x * _current_speed()
	velocity.z = direction.z * _current_speed()
	_face(direction, delta)

	attack_timer = maxf(0.0, attack_timer - delta)
	if distance < 3.0 and attack_timer <= 0.0:
		attack_timer = 1.3
		player.take_damage(touch_damage)
		_use_ability(direction)
		_bounce()


func _use_ability(direction: Vector3) -> void:
	match ability:
		"burn":
			# Quick and painful.
			game.apply_dot(2.5, 6.0)
		"poison":
			# Slower, but it lasts longer.
			game.apply_dot(4.5, 3.0)
		"slow":
			player.apply_slow(2.5)
		"push":
			player.push(direction, 14.0)
		"shock":
			# Thunder: a zap that hurts and makes your legs heavy.
			player.apply_slow(1.5)
			game.apply_dot(1.2, 5.0)
		"radiation":
			# Uranium: poison and heavy legs.
			player.apply_slow(1.5)
			game.apply_dot(3.5, 3.0)
		"final":
			# The Eight-Stone Guardian uses every element at once.
			player.apply_slow(1.5)
			game.apply_dot(2.5, 4.0)
			player.push(direction, 9.0)


func _face(direction: Vector3, delta: float) -> void:
	# The boss's eyes are on its -Z side, so face -Z at the direction.
	rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), 6.0 * delta)


func _current_speed() -> float:
	return move_speed * (0.5 if slow_time > 0.0 else 1.0)


# ------------------------------------------------------ MAGIC STONE HITS --
func _tick_status(delta: float) -> void:
	slow_time = maxf(0.0, slow_time - delta)
	stun_time = maxf(0.0, stun_time - delta)
	_update_status_marker(delta)

	var dps := 0.0
	if burn_time > 0.0:
		burn_time = maxf(0.0, burn_time - delta)
		dps += burn_dps
	if poison_time > 0.0:
		poison_time = maxf(0.0, poison_time - delta)
		dps += poison_dps

	if dps > 0.0:
		dot_accum += delta
		if dot_accum >= 0.5:
			var tick_damage := dps * dot_accum
			dot_accum = 0.0
			take_damage(tick_damage)


func _update_status_marker(delta: float) -> void:
	if status_marker == null:
		return
	var color := Color(0, 0, 0, 0)
	if burn_time > 0.0:
		color = Color(1.0, 0.45, 0.15)
	elif poison_time > 0.0:
		color = Color(0.4, 0.9, 0.3)
	elif stun_time > 0.0:
		color = Color(1.0, 0.95, 0.3)
	elif slow_time > 0.0:
		color = Color(0.4, 0.8, 1.0)

	status_marker.visible = color.a > 0.0
	if status_marker.visible:
		status_marker.rotation.y += delta * 2.0
		var mat := status_marker.material_override as StandardMaterial3D
		mat.albedo_color = color
		mat.emission = color


func apply_burn(seconds: float, dps: float) -> void:
	burn_time = maxf(burn_time, seconds)
	burn_dps = maxf(burn_dps, dps)


func apply_poison(seconds: float, dps: float) -> void:
	poison_time = maxf(poison_time, seconds)
	poison_dps = maxf(poison_dps, dps)


func apply_slow(seconds: float) -> void:
	slow_time = maxf(slow_time, seconds)


func apply_stun(seconds: float) -> void:
	stun_time = maxf(stun_time, seconds)


func knockback(direction: Vector3, force: float) -> void:
	if direction.length() < 0.01:
		return
	global_position += direction.normalized() * force


func take_damage(amount: float) -> void:
	hp -= amount
	_bounce()
	if hp <= 0.0:
		die()


func _bounce() -> void:
	if visual == null:
		return
	var tween := create_tween()
	tween.tween_property(visual, "scale", visual_base_scale * Vector3(1.1, 0.88, 1.1), 0.07)
	tween.tween_property(visual, "scale", visual_base_scale, 0.16)


func die() -> void:
	game.add_coins(coin_reward)
	game.play_sound("roar")
	if final_boss:
		game.on_final_boss_defeated()
	elif sky_boss:
		game.on_sky_boss_defeated()
	else:
		game.on_boss_defeated(biome_id, stone_key, stone_name)
	queue_free()
