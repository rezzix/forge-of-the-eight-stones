extends CharacterBody3D
## ============================================================================
##  BIOME MONSTER (cubes and triangles only)
## ============================================================================
##  Each biome has its own blocky monster shape:
##    rock     - stack of cubes (Plains)
##    spike    - a triangular pyramid (Savanna / Fire)
##    plant    - a cube stem with a triangular crown (Forest)
##    crystal  - a diamond of 8 triangles (Snowy Forest / Ice)
##    blob     - one fat cube (Lake / Water)
##    mushroom - a cube stem with a triangular cap (Mushroom Island / Poison)
##
##  Monsters are LEASHED TO THEIR BIOME: if one ends up outside its biome
##  shape, it stops chasing and walks back in. It can never follow you home.
## ============================================================================

@export var max_hp := 30.0
@export var move_speed := 4.6
@export var touch_damage := 8.0
@export var coin_reward := 10
@export var aggro_range := 20.0
@export var body_color := Color(0.45, 0.32, 0.28)
@export var form := "rock"
@export var poison_touch := false

## Set by the spawner: which biome this monster must stay inside.
var home_center := Vector2.ZERO
var home_size := Vector2(60, 60)
var has_home := false

var hp := 30.0
var game                      ## set by game.gd
var player: Node3D
var gravity := 18.0
var attack_timer := 0.0
var wander_timer := 0.0
var wander_direction := Vector3.ZERO
var visual: Node3D
var visual_base_scale := Vector3.ONE
var status_marker: MeshInstance3D

# Magic-stone effects that are ticking on this monster.
var burn_time := 0.0
var burn_dps := 0.0
var poison_time := 0.0
var poison_dps := 0.0
var slow_time := 0.0
var stun_time := 0.0
var dot_accum := 0.0


func _ready() -> void:
	add_to_group("enemy")
	add_to_group("interactable")
	hp = max_hp
	gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 18.0))
	_build_form()
	_build_status_marker()


# --------------------------------------------------------------- SHAPES ----
func _build_form() -> void:
	visual = Node3D.new()
	visual.name = "Visual"
	add_child(visual)

	var mat := Shapes.material(body_color)
	var eye_mat := Shapes.material(Color(1.0, 0.85, 0.35), true)

	match form:
		"spike":
			_add_part(Shapes.pyramid(1.25, 1.9), mat, Vector3.ZERO)
			_add_eyes(eye_mat, 0.13, 0.55, -0.44, 0.13)

		"blob":
			_add_part(Shapes.cube(Vector3(1.15, 0.95, 1.15)), mat, Vector3(0, 0.48, 0))
			_add_eyes(eye_mat, 0.22, 0.62, -0.58, 0.13)

		"crystal":
			_add_part(Shapes.octahedron(0.62, 1.7), mat, Vector3(0, 0.85, 0))
			_add_eyes(eye_mat, 0.16, 1.0, -0.38, 0.12)

		"plant":
			_add_part(Shapes.cube(Vector3(0.34, 1.2, 0.34)), mat, Vector3(0, 0.6, 0))
			_add_part(Shapes.pyramid(1.5, 0.9), mat, Vector3(0, 1.15, 0))
			_add_eyes(eye_mat, 0.1, 0.9, -0.18, 0.11)

		"mushroom":
			_add_part(Shapes.cube(Vector3(0.55, 1.0, 0.55)), mat, Vector3(0, 0.5, 0))
			_add_part(Shapes.pyramid(1.8, 0.75), mat, Vector3(0, 1.0, 0))
			_add_eyes(eye_mat, 0.13, 0.55, -0.29, 0.12)

		_:
			# rock: a big cube with a smaller tilted cube on top
			_add_part(Shapes.cube(Vector3(0.95, 0.9, 0.95)), mat, Vector3(0, 0.45, 0))
			_add_part(Shapes.cube(Vector3(0.55, 0.5, 0.55)), mat, Vector3(0.18, 0.95, 0.08), 0.5)
			_add_eyes(eye_mat, 0.17, 0.6, -0.49, 0.12)


func _add_part(mesh: Mesh, mat: Material, pos: Vector3, rot_y := 0.0) -> void:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = mat
	part.position = pos
	part.rotation.y = rot_y
	visual.add_child(part)


func _add_eyes(mat: Material, x: float, y: float, z: float, size: float) -> void:
	for side in [-1.0, 1.0]:
		var eye := Shapes.cube_node(Vector3(size, size, size * 0.5), mat)
		eye.position = Vector3(side * x, y, z)
		visual.add_child(eye)


func _build_status_marker() -> void:
	status_marker = Shapes.cube_node(
		Vector3(0.16, 0.16, 0.16),
		Shapes.material(Color(1.0, 0.6, 0.2), true)
	)
	status_marker.position.y = 2.2
	status_marker.visible = false
	add_child(status_marker)


# --------------------------------------------------------------- MOVING ----
func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")

	_tick_status(delta)
	if hp <= 0.0:
		return

	if not is_on_floor():
		velocity.y -= gravity * delta

	# A stunned monster cannot move or bite.
	if stun_time > 0.0:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	# --- NEVER ENTER THE FORGE SAFE ZONE ---------------------------------
	if _handle_safe_zone(delta):
		move_and_slide()
		return

	# --- THE BIOME LEASH -------------------------------------------------
	if has_home and _outside_biome():
		var back := Vector3(home_center.x - global_position.x, 0.0, home_center.y - global_position.z)
		if back.length() > 0.1:
			back = back.normalized()
			velocity.x = back.x * _current_speed()
			velocity.z = back.z * _current_speed()
			_face(back, delta)
		move_and_slide()
		return

	var to_player := Vector3.ZERO
	if player != null:
		to_player = player.global_position - global_position
		to_player.y = 0.0

	if player != null and to_player.length() < aggro_range:
		_chase(to_player, delta)
	else:
		_wander(delta)

	_handle_safe_zone(delta)
	move_and_slide()


func _outside_biome() -> bool:
	var dx := (global_position.x - home_center.x) / maxf(home_size.x, 1.0)
	var dz := (global_position.z - home_center.y) / maxf(home_size.y, 1.0)
	return dx * dx + dz * dz > 0.95


## Monsters are not allowed inside the Forge safe circle.
func _handle_safe_zone(delta: float) -> bool:
	if game == null:
		return false
	var safe_center := Vector2(game.FORGE_POS.x, game.FORGE_POS.z)
	var flat := Vector2(global_position.x, global_position.z)
	var away := flat - safe_center
	var distance := away.length()

	# Already inside? Walk straight back out.
	if distance < game.SAFE_RADIUS:
		var out := away.normalized() if distance > 0.05 else Vector2(1, 0)
		velocity.x = out.x * _current_speed() * 1.5
		velocity.z = out.y * _current_speed() * 1.5
		return true

	# About to step in? Stop at the border.
	var next := flat + Vector2(velocity.x, velocity.z) * delta
	if next.distance_to(safe_center) < game.SAFE_RADIUS:
		velocity.x = 0.0
		velocity.z = 0.0
	return false


func _chase(to_player: Vector3, delta: float) -> void:
	var distance := to_player.length()
	var direction := to_player.normalized()
	velocity.x = direction.x * _current_speed()
	velocity.z = direction.z * _current_speed()
	_face(direction, delta)

	attack_timer = maxf(0.0, attack_timer - delta)
	if distance < 2.2 and attack_timer <= 0.0:
		attack_timer = 1.2
		player.take_damage(touch_damage)
		if poison_touch and game != null:
			game.apply_dot(2.0, 2.0)
		_bounce()


func _wander(delta: float) -> void:
	wander_timer -= delta
	if wander_timer <= 0.0:
		wander_timer = randf_range(2.0, 5.0)
		wander_direction = Vector3(randf_range(-1, 1), 0.0, randf_range(-1, 1)).normalized()

	var wander_speed := 2.2 * (0.5 if slow_time > 0.0 else 1.0)
	velocity.x = move_toward(velocity.x, wander_direction.x * wander_speed, 6.0 * delta)
	velocity.z = move_toward(velocity.z, wander_direction.z * wander_speed, 6.0 * delta)
	if wander_direction.length() > 0.1:
		_face(wander_direction, delta)


func _face(direction: Vector3, delta: float) -> void:
	# The monster's eyes are on its -Z side, so face -Z at the direction.
	rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), 8.0 * delta)


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


# --------------------------------------------------------------- DAMAGE ----
func take_damage(amount: float) -> void:
	hp -= amount
	_bounce()
	if hp <= 0.0:
		die()


func _bounce() -> void:
	if visual == null:
		return
	var tween := create_tween()
	tween.tween_property(visual, "scale", visual_base_scale * Vector3(1.18, 0.8, 1.18), 0.06)
	tween.tween_property(visual, "scale", visual_base_scale, 0.14)


func die() -> void:
	game.add_coins(coin_reward)
	game.play_sound("coin")
	game._log("Monster defeated! +%d coins" % coin_reward)
	queue_free()
