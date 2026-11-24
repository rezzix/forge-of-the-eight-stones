extends CharacterBody3D
## ============================================================================
##  HUNTABLE ANIMALS
## ============================================================================
##  Rabbits and boars wander the surface. Hit one and it drops meat, which you
##  can eat with F. After a minute the animal comes back, so there is always
##  food on the island. They run away when you get close.
## ============================================================================

var game
var player: Node3D
@export var animal_kind := "rabbit"
var body_color := Color(0.8, 0.75, 0.68)
var max_hp := 12.0
var hp := 12.0
var meat_amount := 1
var home := Vector3.ZERO
var home_radius := 45.0
var alive := true
var last_hit_cooked := false
var gravity := 18.0
var wander_timer := 0.0
var wander_direction := Vector3.ZERO
var walk_phase := 0.0

var visual: Node3D
var shape: CollisionShape3D


func _ready() -> void:
	add_to_group("animal")
	add_to_group("enemy")
	add_to_group("interactable")
	gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 18.0))
	home = global_position

	match animal_kind:
		"boar":
			max_hp = 32.0
			meat_amount = 2
			body_color = Color(0.36, 0.27, 0.21)
		"deer":
			max_hp = 40.0
			meat_amount = 3
			body_color = Color(0.64, 0.46, 0.27)
		"fox":
			max_hp = 18.0
			meat_amount = 1
			body_color = Color(0.84, 0.44, 0.18)
		_:
			max_hp = 12.0
			meat_amount = 1
			body_color = Color(0.86, 0.8, 0.72)
	hp = max_hp
	_build_body()


func _physics_process(delta: float) -> void:
	if not alive:
		return
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
	if not is_on_floor():
		velocity.y -= gravity * delta

	var direction := Vector3.ZERO
	var speed := 2.2
	if player != null and global_position.distance_to(player.global_position) < 9.0:
		# Run away from the hunter.
		direction = global_position - player.global_position
		direction.y = 0.0
		direction = direction.normalized()
		match animal_kind:
			"rabbit": speed = 6.0
			"boar": speed = 4.0
			"deer": speed = 5.5
			"fox": speed = 7.5
			_: speed = 4.5
	else:
		var from_home := home - global_position
		from_home.y = 0.0
		if from_home.length() > home_radius:
			direction = from_home.normalized()
		else:
			wander_timer -= delta
			if wander_timer <= 0.0:
				wander_timer = randf_range(1.5, 4.0)
				wander_direction = Vector3(randf_range(-1, 1), 0.0, randf_range(-1, 1)).normalized()
			direction = wander_direction

	velocity.x = move_toward(velocity.x, direction.x * speed, 12.0 * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, 12.0 * delta)
	if direction.length() > 0.1:
		_face(direction, delta)
		walk_phase += delta * 11.0
	else:
		walk_phase = lerp(walk_phase, 0.0, 8.0 * delta)

	if visual != null:
		visual.position.y = absf(sin(walk_phase)) * 0.035
	move_and_slide()


func _face(direction: Vector3, delta: float) -> void:
	rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), 8.0 * delta)


func take_damage(amount: float, cooked := false) -> void:
	if not alive:
		return
	if cooked:
		last_hit_cooked = true
	hp -= amount
	_bounce()
	if hp <= 0.0:
		die()


func die() -> void:
	alive = false
	hp = 0.0
	if game != null:
		game.play_sound("coin")
		var drop := "cooked_meat" if last_hit_cooked else "meat"
		game.add_item(drop, meat_amount)
		game._log("+%d %s from the %s." % [
			meat_amount,
			"cooked meat" if last_hit_cooked else "meat",
			animal_kind
		])
	if visual != null:
		visual.visible = false
	if shape != null:
		shape.set_deferred("disabled", true)
	velocity = Vector3.ZERO

	# Come back later, so hunting does not empty the whole island.
	await get_tree().create_timer(60.0).timeout
	if not is_inside_tree():
		return
	hp = max_hp
	alive = true
	global_position = home
	if visual != null:
		visual.visible = true
	if shape != null:
		shape.set_deferred("disabled", false)


func _bounce() -> void:
	if visual == null:
		return
	var tween := create_tween()
	tween.tween_property(visual, "scale", Vector3(1.15, 0.82, 1.15), 0.06)
	tween.tween_property(visual, "scale", Vector3.ONE, 0.14)


func _build_body() -> void:
	visual = Node3D.new()
	add_child(visual)

	var fur := Shapes.material(body_color)
	var dark := Shapes.material(body_color.darkened(0.3))
	var eye := Shapes.material(Color(0.08, 0.08, 0.1))

	if animal_kind == "deer":
		_body_box(Vector3(0.7, 0.55, 1.25), fur, Vector3(0, 0.72, 0))
		_body_box(Vector3(0.45, 0.45, 0.55), fur, Vector3(0, 0.95, -0.75))
		_body_box(Vector3(0.3, 0.2, 0.22), dark, Vector3(0, 0.86, -1.04))
		for x in [-0.16, 0.16]:
			_body_box(Vector3(0.08, 0.08, 0.05), eye, Vector3(x, 0.99, -1.03))
			var ear := MeshInstance3D.new()
			ear.mesh = Shapes.pyramid(0.16, 0.28)
			ear.material_override = dark
			ear.position = Vector3(x, 1.15, -0.68)
			visual.add_child(ear)
			var antler := MeshInstance3D.new()
			antler.mesh = Shapes.pyramid(0.18, 0.55)
			antler.material_override = Shapes.material(Color(0.75, 0.68, 0.5))
			antler.position = Vector3(x * 1.4, 1.3, -0.7)
			antler.rotation.z = x * 2.0
			visual.add_child(antler)
		for x in [-0.23, 0.23]:
			for z in [-0.42, 0.42]:
				_body_box(Vector3(0.16, 0.5, 0.16), dark, Vector3(x, 0.25, z))
		_body_box(Vector3(0.12, 0.12, 0.3), dark, Vector3(0, 0.75, 0.7))
	elif animal_kind == "fox":
		_body_box(Vector3(0.55, 0.4, 0.95), fur, Vector3(0, 0.48, 0))
		_body_box(Vector3(0.4, 0.35, 0.4), fur, Vector3(0, 0.65, -0.6))
		_body_box(Vector3(0.22, 0.16, 0.2), dark, Vector3(0, 0.58, -0.86))
		for x in [-0.11, 0.11]:
			_body_box(Vector3(0.07, 0.07, 0.05), eye, Vector3(x, 0.7, -0.82))
			var ear := MeshInstance3D.new()
			ear.mesh = Shapes.pyramid(0.16, 0.3)
			ear.material_override = dark
			ear.position = Vector3(x, 0.85, -0.56)
			visual.add_child(ear)
		for x in [-0.18, 0.18]:
			for z in [-0.3, 0.3]:
				_body_box(Vector3(0.13, 0.32, 0.14), dark, Vector3(x, 0.18, z))
		var tail := _body_box(Vector3(0.18, 0.18, 0.6), fur, Vector3(0, 0.55, 0.62))
		tail.rotation.x = -0.35
	elif animal_kind == "boar":
		_body_box(Vector3(0.85, 0.55, 1.25), fur, Vector3(0, 0.62, 0))
		_body_box(Vector3(0.58, 0.5, 0.5), fur, Vector3(0, 0.7, -0.72))
		_body_box(Vector3(0.3, 0.22, 0.24), dark, Vector3(0, 0.58, -1.02))
		for x in [-0.18, 0.18]:
			_body_box(Vector3(0.06, 0.22, 0.06), Shapes.material(Color(0.92, 0.9, 0.8)), Vector3(x, 0.5, -1.08))
			_body_box(Vector3(0.08, 0.08, 0.06), eye, Vector3(x, 0.78, -0.96))
		# Pointy ears.
		for x in [-0.2, 0.2]:
			var ear := MeshInstance3D.new()
			ear.mesh = Shapes.pyramid(0.2, 0.28)
			ear.material_override = dark
			ear.position = Vector3(x, 0.92, -0.62)
			visual.add_child(ear)
		# Four legs.
		for x in [-0.28, 0.28]:
			for z in [-0.42, 0.42]:
				_body_box(Vector3(0.16, 0.35, 0.16), dark, Vector3(x, 0.2, z))
		var tail := _body_box(Vector3(0.08, 0.08, 0.3), dark, Vector3(0, 0.7, 0.68))
		tail.rotation.x = -0.4
	else:
		_body_box(Vector3(0.42, 0.34, 0.62), fur, Vector3(0, 0.32, 0))
		_body_box(Vector3(0.32, 0.32, 0.32), fur, Vector3(0, 0.52, -0.4))
		# Long rabbit ears.
		for x in [-0.1, 0.1]:
			_body_box(Vector3(0.07, 0.34, 0.07), dark, Vector3(x, 0.83, -0.38))
		for x in [-0.09, 0.09]:
			_body_box(Vector3(0.06, 0.06, 0.05), eye, Vector3(x, 0.55, -0.58))
		_body_box(Vector3(0.16, 0.16, 0.1), dark, Vector3(0, 0.4, 0.34))
		for x in [-0.13, 0.13]:
			for z in [-0.2, 0.2]:
				_body_box(Vector3(0.1, 0.16, 0.12), fur, Vector3(x, 0.12, z))

	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	match animal_kind:
		"boar":
			box.size = Vector3(1.0, 0.9, 1.5)
			collision.position.y = 0.55
		"deer":
			box.size = Vector3(0.9, 1.2, 1.6)
			collision.position.y = 0.6
		"fox":
			box.size = Vector3(0.65, 0.7, 1.2)
			collision.position.y = 0.4
		_:
			box.size = Vector3(0.55, 0.55, 0.8)
			collision.position.y = 0.3
	collision.shape = box
	add_child(collision)
	shape = collision


func _body_box(size: Vector3, mat: Material, pos: Vector3) -> MeshInstance3D:
	var node := Shapes.cube_node(size, mat)
	node.position = pos
	visual.add_child(node)
	return node
