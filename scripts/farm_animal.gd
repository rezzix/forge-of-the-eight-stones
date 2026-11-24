extends Node3D
## Friendly farm animals in the pen near the Forge. They wander a little and
## make eggs, milk or wool. Press E next to one when its gold marker appears.

var game
var kind := "chicken"
var produce_item := "egg"
var home := Vector3.ZERO
var target := Vector3.ZERO
var wander_timer := 0.0
var produce_timer := 20.0
var produce_ready := false
var bob_time := 0.0
var visual: Node3D
var marker: MeshInstance3D


func _ready() -> void:
	add_to_group("farm_animal")
	home = global_position
	match kind:
		"chicken": produce_item = "egg"; produce_timer = randf_range(12.0, 20.0)
		"cow": produce_item = "milk"; produce_timer = randf_range(20.0, 32.0)
		"sheep": produce_item = "wool"; produce_timer = randf_range(18.0, 28.0)
	_build_body()
	_pick_target()


func _process(delta: float) -> void:
	bob_time += delta
	produce_timer -= delta
	if produce_timer <= 0.0:
		produce_ready = true
		produce_timer = 0.0
	if marker != null:
		marker.visible = produce_ready
		if produce_ready:
			marker.position.y = 1.6 + sin(bob_time * 2.5) * 0.1
			marker.rotation.y += delta * 2.0

	var to_target := target - global_position
	to_target.y = 0.0
	wander_timer -= delta
	if wander_timer <= 0.0 or to_target.length() < 0.6:
		wander_timer = randf_range(3.0, 7.0)
		_pick_target()
	elif to_target.length() > 0.01:
		var direction := to_target.normalized()
		global_position += direction * minf(0.8 * delta, to_target.length())
		rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), 3.0 * delta)
	visual.position.y = absf(sin(bob_time * 4.0)) * 0.02


func _pick_target() -> void:
	target = home + Vector3(randf_range(-4.0, 4.0), 0.0, randf_range(-3.0, 3.0))


func collect() -> void:
	if game == null:
		return
	if not produce_ready:
		game._log("The %s is not ready yet." % kind)
		return
	game.add_item(produce_item, 1)
	game.play_sound("coin")
	game._log("You collected 1 %s from the %s." % [produce_item, kind])
	produce_ready = false
	produce_timer = randf_range(20.0, 35.0)


func _body_box(size: Vector3, mat: Material, pos: Vector3) -> MeshInstance3D:
	var node := Shapes.cube_node(size, mat)
	node.position = pos
	visual.add_child(node)
	return node


func _build_body() -> void:
	visual = Node3D.new()
	add_child(visual)

	var white := Shapes.material(Color(0.95, 0.94, 0.9))
	var dark := Shapes.material(Color(0.2, 0.2, 0.22))
	var pink := Shapes.material(Color(0.9, 0.55, 0.55))
	var orange := Shapes.material(Color(0.95, 0.55, 0.18))
	var eye := Shapes.material(Color(0.05, 0.05, 0.08))

	if kind == "chicken":
		_body_box(Vector3(0.42, 0.35, 0.5), white, Vector3(0, 0.4, 0))
		_body_box(Vector3(0.28, 0.3, 0.3), white, Vector3(0, 0.65, -0.28))
		_body_box(Vector3(0.12, 0.1, 0.16), orange, Vector3(0, 0.6, -0.48))
		_body_box(Vector3(0.12, 0.12, 0.1), pink, Vector3(0, 0.83, -0.24))
		for x in [-0.11, 0.11]:
			_body_box(Vector3(0.05, 0.05, 0.04), eye, Vector3(x, 0.69, -0.44))
		for x in [-0.12, 0.12]:
			_body_box(Vector3(0.06, 0.22, 0.06), orange, Vector3(x, 0.12, 0))
	elif kind == "cow":
		_body_box(Vector3(0.9, 0.6, 1.25), white, Vector3(0, 0.75, 0))
		_body_box(Vector3(0.3, 0.25, 0.2), dark, Vector3(-0.25, 0.95, -0.35))
		_body_box(Vector3(0.25, 0.2, 0.2), dark, Vector3(0.28, 0.7, 0.3))
		_body_box(Vector3(0.48, 0.45, 0.5), white, Vector3(0, 1.0, -0.75))
		_body_box(Vector3(0.32, 0.12, 0.2), pink, Vector3(0, 0.9, -1.02))
		for x in [-0.16, 0.16]:
			_body_box(Vector3(0.07, 0.07, 0.05), eye, Vector3(x, 1.08, -0.98))
			_body_box(Vector3(0.06, 0.2, 0.06), white, Vector3(x * 1.3, 1.28, -0.7))
		for x in [-0.3, 0.3]:
			for z in [-0.42, 0.42]:
				_body_box(Vector3(0.18, 0.5, 0.18), dark, Vector3(x, 0.28, z))
	else:
		_body_box(Vector3(1.0, 0.85, 1.1), white, Vector3(0, 0.75, 0))
		for i in 6:
			var fluff := Shapes.cube_node(
				Vector3(0.36, 0.3, 0.36),
				Shapes.material(Color(0.98, 0.98, 0.98))
			)
			fluff.position = Vector3(
				randf_range(-0.4, 0.4), 0.85 + randf_range(-0.2, 0.2), randf_range(-0.4, 0.4)
			)
			visual.add_child(fluff)
		_body_box(Vector3(0.38, 0.38, 0.42), dark, Vector3(0, 0.85, -0.68))
		for x in [-0.1, 0.1]:
			_body_box(Vector3(0.07, 0.07, 0.05), eye, Vector3(x, 0.9, -0.9))
			_body_box(Vector3(0.16, 0.1, 0.24), dark, Vector3(x * 1.8, 1.0, -0.62))
		for x in [-0.28, 0.28]:
			for z in [-0.35, 0.35]:
				_body_box(Vector3(0.16, 0.42, 0.16), dark, Vector3(x, 0.22, z))

	marker = MeshInstance3D.new()
	marker.mesh = Shapes.octahedron(0.15, 0.35)
	marker.material_override = Shapes.material(Color(1.0, 0.85, 0.3), true)
	marker.position.y = 1.6
	marker.visible = false
	add_child(marker)
