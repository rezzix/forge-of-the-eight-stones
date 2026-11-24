extends StaticBody3D
## A blocky tree you can chop for wood. It takes three hits, then falls and
## grows back after a little while.

var game
var tree_type := "oak"
var wood_item := "wood"
var hp := 3.0
var max_hp := 3.0
var alive := true
var wood_amount := 4
var trunk: MeshInstance3D
var leaves: MeshInstance3D
var shape: CollisionShape3D


func _ready() -> void:
	add_to_group("tree")
	add_to_group("interactable")
	hp = max_hp
	trunk = get_node_or_null("Trunk")
	leaves = get_node_or_null("Leaves")
	shape = get_node_or_null("Shape")


func hit(power: float) -> void:
	if not alive:
		return
	hp -= power
	_chip()
	if hp <= 0.0:
		_fall()


func _chip() -> void:
	if trunk == null or leaves == null:
		return
	var tween := create_tween()
	tween.tween_property(trunk, "scale", Vector3(1.1, 0.9, 1.1), 0.06)
	tween.tween_property(trunk, "scale", Vector3.ONE, 0.12)
	tween.tween_property(leaves, "rotation:z", 0.08, 0.06)
	tween.tween_property(leaves, "rotation:z", 0.0, 0.12)


func _fall() -> void:
	alive = false
	hp = 0.0
	if game != null:
		game.add_item(wood_item, wood_amount)
		game.play_sound("mine")
		game._log("+%d %s from the %s tree." % [wood_amount, wood_item, tree_type])
	if trunk != null:
		trunk.visible = false
	if leaves != null:
		leaves.visible = false
	if shape != null:
		shape.set_deferred("disabled", true)

	await get_tree().create_timer(35.0).timeout
	if not is_inside_tree():
		return
	hp = max_hp
	alive = true
	if trunk != null:
		trunk.visible = true
	if leaves != null:
		leaves.visible = true
	if shape != null:
		shape.set_deferred("disabled", false)
