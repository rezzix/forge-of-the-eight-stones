extends Node3D
## ============================================================================
##  THE WANDERING TRADER
## ============================================================================
##  A friendly blocky traveller with a big backpack. He picks a land spot,
##  walks there, rests for a moment, then picks another spot. Walk up to him
##  and press E to buy wood, copper or iron, or to sell stone.
## ============================================================================

const SPEED := 3.2

var game
var visual: Node3D
var marker: MeshInstance3D
var leg_pivots: Array[Node3D] = []
var target := Vector3.ZERO
var waiting := 0.0
var walk_phase := 0.0
var bob_time := 0.0


func _ready() -> void:
	add_to_group("trader")
	_build_body()

	if game != null:
		var spot: Vector2 = game.random_trader_point(Vector2(60, 60))
		global_position = Vector3(spot.x, 0.0, spot.y)
	_pick_target()


func _process(delta: float) -> void:
	bob_time += delta
	marker.rotation.y += delta * 2.2
	marker.position.y = 2.05 + sin(bob_time * 2.0) * 0.08

	if game == null:
		return

	# Stand still while the player is looking at the shop, so he does not walk
	# away in the middle of a trade.
	if game.hud != null and game.hud.shop_panel.visible:
		visual.position.y = lerp(visual.position.y, 0.0, 6.0 * delta)
		return

	if waiting > 0.0:
		waiting = maxf(0.0, waiting - delta)
		visual.position.y = lerp(visual.position.y, 0.0, 6.0 * delta)
		return

	var to_target := target - global_position
	to_target.y = 0.0
	if to_target.length() < 1.5:
		waiting = randf_range(2.0, 5.0)
		_pick_target()
		return

	var step := minf(SPEED * delta, to_target.length())
	global_position += to_target.normalized() * step
	rotation.y = lerp_angle(rotation.y, atan2(-to_target.x, -to_target.z), 4.0 * delta)

	# A little walk cycle for the legs, and a soft bounce for the body.
	walk_phase += delta * 8.0
	for i in leg_pivots.size():
		leg_pivots[i].rotation.x = sin(walk_phase + PI * float(i)) * 0.35
	visual.position.y = absf(sin(walk_phase)) * 0.04


func _pick_target() -> void:
	if game == null:
		return
	var here := Vector2(global_position.x, global_position.z)
	var spot: Vector2 = game.random_trader_point(here)
	target = Vector3(spot.x, 0.0, spot.y)


func _build_body() -> void:
	visual = Node3D.new()
	add_child(visual)

	var coat := Shapes.material(Color(0.36, 0.45, 0.28))
	var coat_dark := Shapes.material(Color(0.24, 0.3, 0.18))
	var skin := Shapes.material(Color(0.94, 0.78, 0.62))
	var leather := Shapes.material(Color(0.46, 0.3, 0.16))
	var eye := Shapes.material(Color(0.08, 0.08, 0.12))
	var gold := Shapes.material(Color(1.0, 0.8, 0.3), true)

	for i in 2:
		var pivot := Node3D.new()
		pivot.position = Vector3(-0.15 + 0.3 * float(i), 0.5, 0)
		visual.add_child(pivot)
		var leg := Shapes.cube_node(Vector3(0.18, 0.5, 0.2), coat_dark)
		leg.position = Vector3(0, -0.25, 0)
		pivot.add_child(leg)
		var boot := Shapes.cube_node(Vector3(0.2, 0.14, 0.28), leather)
		boot.position = Vector3(0, -0.5, -0.03)
		pivot.add_child(boot)
		leg_pivots.append(pivot)

	var body := Shapes.cube_node(Vector3(0.58, 0.7, 0.38), coat)
	body.position.y = 0.9
	visual.add_child(body)

	var belt := Shapes.cube_node(Vector3(0.6, 0.1, 0.4), leather)
	belt.position.y = 0.62
	visual.add_child(belt)

	var pack := Shapes.cube_node(Vector3(0.44, 0.55, 0.26), leather)
	pack.position = Vector3(0, 0.95, 0.3)
	visual.add_child(pack)

	var head := Shapes.cube_node(Vector3(0.42, 0.4, 0.4), skin)
	head.position.y = 1.45
	visual.add_child(head)

	var hat := Shapes.cube_node(Vector3(0.62, 0.08, 0.6), leather)
	hat.position.y = 1.68
	visual.add_child(hat)
	var hat_top := Shapes.cube_node(Vector3(0.4, 0.2, 0.38), leather)
	hat_top.position.y = 1.79
	visual.add_child(hat_top)

	for x in [-0.1, 0.1]:
		var e := Shapes.cube_node(Vector3(0.07, 0.07, 0.06), eye)
		e.position = Vector3(x, 1.47, -0.21)
		visual.add_child(e)

	marker = MeshInstance3D.new()
	marker.mesh = Shapes.octahedron(0.2, 0.5)
	marker.material_override = gold
	marker.position.y = 2.05
	add_child(marker)

	# The trader is solid: you cannot walk through him.
	var body_shape := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.7, 1.5, 0.5)
	collision.shape = box
	collision.position.y = 0.75
	body_shape.add_child(collision)
	add_child(body_shape)
