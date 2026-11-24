extends Node3D
## A friendly blocky villager. Walk close and press E to hear a tip or a bit of
## village gossip. They wander a few steps around their home.

var game
var villager_name := "Villager"
var lines: Array = []
var body_color := Color(0.7, 0.55, 0.35)
var home := Vector3.ZERO
var target := Vector3.ZERO
var wander_timer := 0.0
var line_index := 0
var visual: Node3D
var walk_phase := 0.0


func _ready() -> void:
	add_to_group("villager")
	home = global_position
	_build_body()
	_pick_target()


func _process(delta: float) -> void:
	wander_timer -= delta
	var to_target := target - global_position
	to_target.y = 0.0
	if wander_timer <= 0.0 or to_target.length() < 0.8:
		wander_timer = randf_range(3.0, 7.0)
		_pick_target()
	else:
		var direction := to_target.normalized()
		global_position += direction * minf(1.2 * delta, to_target.length())
		rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), 4.0 * delta)
		walk_phase += delta * 6.0
	visual.position.y = absf(sin(walk_phase)) * 0.025


func _pick_target() -> void:
	target = home + Vector3(randf_range(-4.0, 4.0), 0.0, randf_range(-4.0, 4.0))


func face_player() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var direction: Vector3 = player.global_position - global_position
	direction.y = 0.0
	if direction.length() > 0.01:
		rotation.y = atan2(-direction.x, -direction.z)


func next_line() -> String:
	if lines.is_empty():
		return "Nice weather today, isn't it?"
	var line: String = String(lines[line_index % lines.size()])
	line_index += 1
	return line


func _build_body() -> void:
	visual = Node3D.new()
	add_child(visual)

	var cloth := Shapes.material(body_color)
	var cloth_dark := Shapes.material(body_color.darkened(0.3))
	var skin := Shapes.material(Color(0.94, 0.78, 0.62))
	var eye := Shapes.material(Color(0.08, 0.08, 0.12))

	for x in [-0.15, 0.15]:
		var leg := Shapes.cube_node(Vector3(0.17, 0.55, 0.2), cloth_dark)
		leg.position = Vector3(x, 0.28, 0)
		visual.add_child(leg)

	var body := Shapes.cube_node(Vector3(0.55, 0.65, 0.36), cloth)
	body.position.y = 0.88
	visual.add_child(body)

	var belt := Shapes.cube_node(Vector3(0.57, 0.08, 0.38), cloth_dark)
	belt.position.y = 0.6
	visual.add_child(belt)

	var head := Shapes.cube_node(Vector3(0.42, 0.4, 0.4), skin)
	head.position.y = 1.42
	visual.add_child(head)

	var hat := Shapes.cube_node(Vector3(0.48, 0.12, 0.46), cloth_dark)
	hat.position.y = 1.64
	visual.add_child(hat)

	for x in [-0.1, 0.1]:
		var e := Shapes.cube_node(Vector3(0.07, 0.07, 0.05), eye)
		e.position = Vector3(x, 1.45, -0.21)
		visual.add_child(e)

	for x in [-0.37, 0.37]:
		var arm := Shapes.cube_node(Vector3(0.14, 0.6, 0.16), cloth)
		arm.position = Vector3(x, 0.9, 0)
		visual.add_child(arm)
