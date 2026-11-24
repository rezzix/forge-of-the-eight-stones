extends StaticBody3D
## ============================================================================
##  ORE NODE
## ============================================================================
##  A rock you can mine. Every hit removes some "hp". When hp reaches 0 the rock
##  gives you materials, disappears, and comes back a little later so the world
##  never runs out of things to mine.
## ============================================================================

@export_enum("stone", "copper", "iron", "wood", "uranium", "sky_crystal") var ore_type := "stone"

var game                      ## set by game.gd
var hp := 4.0
var max_hp := 4.0
var alive := true

var mesh: MeshInstance3D
var top: MeshInstance3D
var shape: CollisionShape3D
var marker: MeshInstance3D
var bob_time := 0.0

## hp       = how many hits it takes
## amount   = materials you get when it breaks
## respawn  = seconds before it grows back
const ORE_DATA := {
	"stone": {
		"name": "Stone", "hp": 4.0, "amount": 3, "respawn": 12.0,
		"color": Color(0.62, 0.62, 0.64), "glow": Color(0, 0, 0),
		"spark": Color(0.85, 0.85, 0.9),
	},
	"copper": {
		"name": "Copper Ore", "hp": 6.0, "amount": 2, "respawn": 15.0,
		"color": Color(0.82, 0.47, 0.26), "glow": Color(0.35, 0.12, 0.0),
		"spark": Color(1.0, 0.55, 0.2),
	},
	"iron": {
		"name": "Iron Ore", "hp": 9.0, "amount": 2, "respawn": 18.0,
		"color": Color(0.76, 0.79, 0.83), "glow": Color(0.1, 0.12, 0.15),
		"spark": Color(0.7, 0.85, 1.0),
	},
	"wood": {
		"name": "Wood", "hp": 3.0, "amount": 4, "respawn": 10.0,
		"color": Color(0.55, 0.36, 0.2), "glow": Color(0, 0, 0),
		"spark": Color(1.0, 0.78, 0.45),
	},
	"uranium": {
		"name": "Uranium", "hp": 14.0, "amount": 1, "respawn": 60.0,
		"color": Color(0.45, 0.8, 0.25), "glow": Color(0.18, 0.45, 0.08),
		"spark": Color(0.7, 1.0, 0.4),
	},
	"sky_crystal": {
		"name": "Sky Crystal", "hp": 16.0, "amount": 1, "respawn": 75.0,
		"color": Color(0.45, 0.85, 1.0), "glow": Color(0.2, 0.5, 0.8),
		"spark": Color(0.7, 0.95, 1.0),
	},
}


func _ready() -> void:
	add_to_group("ore")
	add_to_group("interactable")

	mesh = $Mesh
	shape = $CollisionShape3D
	marker = $Marker

	var data: Dictionary = ORE_DATA[ore_type]
	hp = data["hp"]
	max_hp = hp

	var mat := StandardMaterial3D.new()
	mat.albedo_color = data["color"]
	mat.roughness = 0.9
	mat.emission_enabled = true
	mat.emission = data["glow"]
	mat.emission_energy_multiplier = 1.3
	mesh.material_override = mat
	top = get_node_or_null("Top")
	if top != null:
		top.material_override = mat

	# A floating sparkle above the rock: "this thing can be mined".
	var spark_mat := StandardMaterial3D.new()
	spark_mat.albedo_color = data["spark"]
	spark_mat.emission_enabled = true
	spark_mat.emission = data["spark"]
	spark_mat.emission_energy_multiplier = 3.0
	spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker.material_override = spark_mat

	# A little random size so the world doesn't look copy-pasted.
	var s := randf_range(0.85, 1.25)
	mesh.scale = Vector3(s, s * randf_range(0.8, 1.1), s)
	rotation.y = randf_range(0.0, TAU)
	bob_time = randf_range(0.0, TAU)


func _process(delta: float) -> void:
	# Make the sparkle bob and spin so it catches the eye.
	bob_time += delta
	marker.position.y = 2.0 + sin(bob_time * 2.2) * 0.12
	marker.rotation.y += delta * 1.6


func display_name() -> String:
	return String(ORE_DATA[ore_type]["name"])


## Called by the player every time they swing while looking at this rock.
func hit(power: float) -> void:
	if not alive:
		return

	hp -= power
	_chip()

	if hp <= 0.0:
		_break_apart()


func _chip() -> void:
	# Squash the rock a little on every hit so it feels solid.
	var tween := create_tween()
	tween.tween_property(mesh, "scale", mesh.scale * Vector3(1.12, 0.86, 1.12), 0.05)
	tween.tween_property(mesh, "scale", mesh.scale, 0.1)


func _break_apart() -> void:
	alive = false
	var data: Dictionary = ORE_DATA[ore_type]
	game.add_item(ore_type, int(data["amount"]))
	game._log("+%d %s" % [int(data["amount"]), display_name()])

	mesh.visible = false
	if top != null:
		top.visible = false
	marker.visible = false
	shape.set_deferred("disabled", true)

	await get_tree().create_timer(float(data["respawn"])).timeout

	hp = max_hp
	alive = true
	mesh.visible = true
	if top != null:
		top.visible = true
	marker.visible = true
	shape.set_deferred("disabled", false)
