extends Node3D
## A simple flying arrow. It raycasts along its path so fast arrows cannot skip
## through a monster, then damages the first enemy it touches.

var game
var damage := 10.0
var velocity := Vector3.ZERO
var life := 4.0
var shooter_rid := RID()


func _ready() -> void:
	add_to_group("arrow")
	var wood := Shapes.material(Color(0.5, 0.34, 0.18))
	var metal := Shapes.material(Color(0.78, 0.82, 0.9), true)

	var shaft := Shapes.cube_node(Vector3(0.05, 0.05, 0.75), wood)
	shaft.position.z = 0.05
	add_child(shaft)

	var tip := Shapes.cube_node(Vector3(0.1, 0.1, 0.18), metal)
	tip.position.z = -0.4
	add_child(tip)

	# Two little feather boxes at the back.
	for x in [-0.08, 0.08]:
		var feather := Shapes.cube_node(Vector3(0.12, 0.02, 0.18), metal)
		feather.position = Vector3(x, 0, 0.38)
		add_child(feather)


func _physics_process(delta: float) -> void:
	var from := global_position
	var to := from + velocity * delta
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [shooter_rid]
	query.collide_with_areas = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)

	if not hit.is_empty():
		var collider = hit.get("collider")
		if collider != null and collider.is_in_group("enemy"):
			if collider.is_in_group("animal"):
				collider.take_damage(damage, game != null and game.infused.has("magic_fire"))
			else:
				collider.take_damage(damage)
			if game != null:
				game.apply_weapon_effects(collider)
		queue_free()
		return

	global_position = to
	life -= delta
	if life <= 0.0:
		queue_free()
