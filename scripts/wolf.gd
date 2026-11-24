extends Node3D
## ============================================================================
##  THE FOREST WOLF
## ============================================================================
##  A blocky wolf living in the Forest. Walk up and press E to tame it.
##  After that it follows you, bites nearby monsters, and never gets lost
##  (if you get too far away it catches up).
## ============================================================================

const FOLLOW_SPEED := 6.0
const BITE_DAMAGE := 5.0
const BITE_RANGE := 2.4

var game
var player: Node3D
var tamed := false
var level := 1
var stay := false
var forced_target: Node3D = null
var home := Vector3.ZERO
var target := Vector3.ZERO
var wander_timer := 0.0
var attack_timer := 0.0
var walk_phase := 0.0
var bob_time := 0.0

var visual: Node3D
var marker: MeshInstance3D
var collar: MeshInstance3D
var leg_pivots: Array[Node3D] = []


func _ready() -> void:
	add_to_group("wolf")
	home = global_position
	_build_body()
	_pick_wander_target()


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")

	bob_time += delta
	if marker != null and marker.visible:
		marker.rotation.y += delta * 2.0
		marker.position.y = 1.6 + sin(bob_time * 2.5) * 0.08
	attack_timer = maxf(0.0, attack_timer - delta)

	if tamed and game != null and game.in_cave:
		# Wait outside while the player is underground.
		_animate(delta, false)
		return

	if tamed and player != null:
		_follow_and_fight(delta)
	else:
		_wander(delta)


func set_tamed(value: bool) -> void:
	tamed = value
	if collar != null:
		collar.visible = tamed
	if marker != null:
		marker.visible = not tamed
	if tamed:
		home = global_position
		_pick_wander_target()
	set_level(level)


func set_level(value: int) -> void:
	level = clampi(value, 1, 5)
	if visual != null:
		visual.scale = Vector3.ONE * (1.0 + 0.06 * float(level - 1))


func set_stay(value: bool) -> void:
	stay = value
	if not stay:
		forced_target = null


func _follow_and_fight(delta: float) -> void:
	var enemy: Node3D = null
	if forced_target != null and is_instance_valid(forced_target):
		if not ("hp" in forced_target) or float(forced_target.hp) > 0.0:
			enemy = forced_target
		else:
			forced_target = null
	if enemy == null and not stay:
		enemy = _nearest_enemy()

	if enemy != null:
		var to_enemy: Vector3 = enemy.global_position - global_position
		to_enemy.y = 0.0
		if to_enemy.length() > BITE_RANGE:
			_move_towards(enemy.global_position, FOLLOW_SPEED, delta)
		else:
			_face(to_enemy, delta)
			if attack_timer <= 0.0:
				attack_timer = 0.8
				enemy.take_damage(BITE_DAMAGE + float(level - 1) * 2.0)
		_animate(delta, true)
		return

	if stay:
		_animate(delta, false)
		return
	if player == null:
		return
	var wanted := player.global_position + Vector3(2.2, 0.0, 2.2)
	var to_player := wanted - global_position
	to_player.y = 0.0
	if to_player.length() > 35.0:
		global_position = wanted
	elif to_player.length() > 2.0:
		_move_towards(wanted, FOLLOW_SPEED, delta)
	_animate(delta, to_player.length() > 2.0)


func _nearest_enemy() -> Node3D:
	var best: Node3D = null
	var best_distance := 16.0
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy == null or not is_instance_valid(enemy):
			continue
		if "hp" in enemy and float(enemy.hp) <= 0.0:
			continue
		var d: float = enemy.global_position.distance_to(global_position)
		if d < best_distance:
			best = enemy
			best_distance = d
	return best


func _wander(delta: float) -> void:
	wander_timer -= delta
	var to_target := target - global_position
	to_target.y = 0.0
	if wander_timer <= 0.0 or to_target.length() < 1.2:
		wander_timer = randf_range(3.0, 6.0)
		_pick_wander_target()
		_animate(delta, false)
		return
	_move_towards(target, 2.0, delta)
	_animate(delta, true)


func _pick_wander_target() -> void:
	target = home + Vector3(randf_range(-25.0, 25.0), 0.0, randf_range(-25.0, 25.0))


func _move_towards(where: Vector3, speed: float, delta: float) -> void:
	var direction := where - global_position
	direction.y = 0.0
	if direction.length() < 0.01:
		return
	direction = direction.normalized()
	global_position += direction * minf(speed * delta, direction.length())
	_face(direction, delta)


func _face(direction: Vector3, delta: float) -> void:
	rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), 7.0 * delta)


func _animate(delta: float, moving: bool) -> void:
	if moving:
		walk_phase += delta * 10.0
		for i in leg_pivots.size():
			leg_pivots[i].rotation.x = sin(walk_phase + PI * float(i)) * 0.45
		visual.position.y = absf(sin(walk_phase)) * 0.04
	else:
		for pivot in leg_pivots:
			pivot.rotation.x = lerp(pivot.rotation.x, 0.0, 8.0 * delta)
		visual.position.y = lerp(visual.position.y, 0.0, 8.0 * delta)


func _build_body() -> void:
	visual = Node3D.new()
	add_child(visual)

	var fur := Shapes.material(Color(0.42, 0.43, 0.47))
	var fur_dark := Shapes.material(Color(0.29, 0.3, 0.34))
	var skin := Shapes.material(Color(0.2, 0.2, 0.22))
	var eye := Shapes.material(Color(1.0, 0.82, 0.25), true)

	var body := Shapes.cube_node(Vector3(0.62, 0.42, 1.05), fur)
	body.position.y = 0.48
	visual.add_child(body)

	var chest := Shapes.cube_node(Vector3(0.64, 0.46, 0.35), fur_dark)
	chest.position = Vector3(0, 0.5, -0.42)
	visual.add_child(chest)

	var head := Shapes.cube_node(Vector3(0.42, 0.38, 0.42), fur)
	head.position = Vector3(0, 0.66, -0.7)
	visual.add_child(head)

	var snout := Shapes.cube_node(Vector3(0.24, 0.18, 0.22), fur_dark)
	snout.position = Vector3(0, 0.58, -0.94)
	visual.add_child(snout)

	for x in [-0.13, 0.13]:
		var e := Shapes.cube_node(Vector3(0.07, 0.07, 0.05), eye)
		e.position = Vector3(x, 0.71, -0.9)
		visual.add_child(e)

		# Pointy ears are little triangles (pyramids).
		var ear := MeshInstance3D.new()
		ear.mesh = Shapes.pyramid(0.18, 0.24)
		ear.material_override = fur_dark
		ear.position = Vector3(x, 0.84, -0.62)
		visual.add_child(ear)

	# Four legs on pivots so they can trot.
	var spots := [
		Vector3(-0.2, 0.34, -0.34), Vector3(0.2, 0.34, -0.34),
		Vector3(-0.2, 0.34, 0.34), Vector3(0.2, 0.34, 0.34),
	]
	for spot in spots:
		var pivot := Node3D.new()
		pivot.position = spot
		visual.add_child(pivot)
		var leg := Shapes.cube_node(Vector3(0.15, 0.34, 0.16), fur_dark)
		leg.position.y = -0.17
		pivot.add_child(leg)
		leg_pivots.append(pivot)

	var tail := Shapes.cube_node(Vector3(0.14, 0.14, 0.45), fur)
	tail.position = Vector3(0, 0.58, 0.58)
	tail.rotation.x = -0.5
	visual.add_child(tail)

	collar = Shapes.cube_node(Vector3(0.44, 0.08, 0.44), Shapes.material(Color(0.85, 0.2, 0.2)))
	collar.position = Vector3(0, 0.5, -0.62)
	collar.visible = false
	visual.add_child(collar)

	# A gold marker over the untamed wolf, so you can spot it in the forest.
	marker = MeshInstance3D.new()
	marker.mesh = Shapes.octahedron(0.18, 0.42)
	marker.material_override = Shapes.material(Color(1.0, 0.82, 0.3), true)
	marker.position.y = 1.6
	add_child(marker)
