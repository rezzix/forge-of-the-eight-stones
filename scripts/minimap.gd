extends Control
## ============================================================================
##  MINIMAP (bottom-left corner)
## ============================================================================
##  Drawn by hand with 2D drawing commands, using the exact same biome shapes
##  as the 3D world (game.biome_outline), so the map can never drift out of
##  sync with the island.
##
##  What you see:
##    - the round island and its six biomes
##    - a gold dot for the Forge
##    - a coloured diamond for each temple
##    - red dots for living bosses
##    - a white arrow: you, pointing where you face
## ============================================================================

var game

const MAP_SIZE := 190.0
const MAP_RADIUS := 86.0


func _ready() -> void:
	custom_minimum_size = Vector2(MAP_SIZE, MAP_SIZE)
	size = Vector2(MAP_SIZE, MAP_SIZE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if game == null:
		return

	var middle := Vector2(MAP_SIZE, MAP_SIZE) * 0.5
	var zoom := MAP_RADIUS / WorldData.WORLD_RADIUS

	# Sea + island background.
	draw_circle(middle, MAP_RADIUS + 5.0, Color(0.08, 0.16, 0.28, 0.92))
	draw_circle(middle, MAP_RADIUS, Color(0.34, 0.6, 0.3))

	# Biome shapes (same wobbly outlines as the real world).
	for biome in WorldData.BIOMES:
		var outline: PackedVector2Array = game.biome_outline(biome, 56)
		var points := PackedVector2Array()
		for point in outline:
			points.append(middle + point * zoom)
		draw_colored_polygon(points, biome["color"])

	# Temples.
	for biome in WorldData.BIOMES:
		var temple: Vector2 = middle + Vector2(biome["temple_pos"].x, biome["temple_pos"].y) * zoom
		var d := 5.0
		var diamond := PackedVector2Array([
			temple + Vector2(0, -d), temple + Vector2(d, 0),
			temple + Vector2(0, d), temple + Vector2(-d, 0),
		])
		draw_colored_polygon(diamond, biome["glow"])
		var outline := PackedVector2Array([diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]])
		draw_polyline(outline, Color(0, 0, 0, 0.55), 1.0)

	# The Forge.
	draw_circle(middle, 4.5, Color(1.0, 0.8, 0.35))
	draw_arc(middle, 7.0, 0.0, TAU, 20, Color(1.0, 0.8, 0.35, 0.45), 1.5)

	# The wandering trader: an orange dot that moves on the map.
	if game.trader != null and is_instance_valid(game.trader) and not game.in_cave:
		var merchant: Vector2 = middle + Vector2(
			game.trader.global_position.x, game.trader.global_position.z
		) * zoom
		draw_circle(merchant, 4.5, Color(1.0, 0.55, 0.15))
		draw_arc(merchant, 7.0, 0.0, TAU, 18, Color(1.0, 0.78, 0.35, 0.6), 1.5)

	# The forest wolf, before you tame it.
	if game.wolf != null and is_instance_valid(game.wolf) and not game.wolf_tamed and not game.in_cave:
		var wolf_at: Vector2 = middle + Vector2(
			game.wolf.global_position.x, game.wolf.global_position.z
		) * zoom
		draw_circle(wolf_at, 3.8, Color(0.82, 0.84, 0.88))
		draw_arc(wolf_at, 6.0, 0.0, TAU, 16, Color(0.9, 0.9, 0.95, 0.55), 1.2)

	# The village quest board.
	var quest_at: Vector2 = middle + Vector2(game.QUEST_BOARD_POS.x, game.QUEST_BOARD_POS.z) * zoom
	draw_circle(quest_at, 3.5, Color(1.0, 0.9, 0.35))
	draw_arc(quest_at, 5.5, 0.0, TAU, 14, Color(1.0, 0.9, 0.5, 0.55), 1.0)

	# Cave entrance.
	var cave_point: Vector2 = middle + Vector2(game.CAVE_ENTRANCE.x, game.CAVE_ENTRANCE.z) * zoom
	draw_circle(cave_point, 4.0, Color(0.06, 0.06, 0.08))
	draw_arc(cave_point, 4.0, 0.0, TAU, 14, Color(0.8, 0.86, 1.0), 1.2)

	# Living bosses: a red ring around their temple.
	for boss in game.bosses:
		if boss == null or not is_instance_valid(boss) or boss.hp <= 0.0:
			continue
		if String(boss.biome_id) == "thunder" or String(boss.biome_id) == "uranium" \
			or String(boss.biome_id) == "final" or String(boss.biome_id) == "sky":
			continue  # underground / final / sky bosses are not on the surface map
		var at: Vector2 = middle + Vector2(boss.global_position.x, boss.global_position.z) * zoom
		draw_arc(at, 7.0, 0.0, TAU, 20, Color(1.0, 0.25, 0.25), 2.0)

	# You.
	if game.player != null:
		var marker_world := Vector2(game.player.global_position.x, game.player.global_position.z)
		if game.in_cave:
			# The underground is one huge pizza of four cave biomes.
			draw_circle(middle, MAP_RADIUS, Color(0.03, 0.03, 0.05, 0.95))
			for biome in game.UNDERGROUND_BIOMES:
				var points := PackedVector2Array()
				var start_base := float(biome["start"])
				var end_base := float(biome["end"])
				var start_idx: int = game.UNDERGROUND_BOUNDARY_DEGREES.find(start_base)
				var end_idx: int = start_idx + 1

				# Wavy start edge, then the outer rim, then the wavy end edge.
				for j in 9:
					var r := MAP_RADIUS * float(j) / 8.0
					var world_r := r / zoom
					var angle := deg_to_rad(start_base + game._boundary_offset(start_idx, world_r))
					points.append(middle + Vector2(cos(angle), sin(angle)) * r)
				var rim_start: float = start_base + game._boundary_offset(start_idx, WorldData.WORLD_RADIUS)
				var rim_end: float = end_base + game._boundary_offset(end_idx, WorldData.WORLD_RADIUS)
				for i in 41:
					var angle := deg_to_rad(rim_start + (rim_end - rim_start) * float(i) / 40.0)
					points.append(middle + Vector2(cos(angle), sin(angle)) * MAP_RADIUS)
				for j in range(8, -1, -1):
					var r := MAP_RADIUS * float(j) / 8.0
					var world_r := r / zoom
					var angle := deg_to_rad(end_base + game._boundary_offset(end_idx, world_r))
					points.append(middle + Vector2(cos(angle), sin(angle)) * r)
				draw_colored_polygon(points, biome["color"])

			# The gold exit pad at the entrance.
			var exit_at: Vector2 = middle + Vector2(game.CAVE_EXIT_PAD.x, game.CAVE_EXIT_PAD.z) * zoom
			draw_circle(exit_at, 4.0, Color(1.0, 0.85, 0.4))
			draw_arc(exit_at, 6.5, 0.0, TAU, 16, Color(1.0, 0.85, 0.4, 0.5), 1.5)

			# Underground bosses, if they are still alive.
			for boss in game.bosses:
				if boss == null or not is_instance_valid(boss) or boss.hp <= 0.0:
					continue
				var boss_id := String(boss.biome_id)
				if boss_id != "thunder" and boss_id != "uranium":
					continue
				var at: Vector2 = middle + Vector2(boss.global_position.x, boss.global_position.z) * zoom
				var ring := Color(1.0, 0.25, 0.25) if boss_id == "thunder" else Color(0.55, 1.0, 0.3)
				draw_arc(at, 7.0, 0.0, TAU, 20, ring, 2.0)
		elif game.in_dive:
			draw_circle(middle, MAP_RADIUS, Color(0.03, 0.1, 0.2, 0.96))
			for treasure in game.treasures:
				if String(treasure["id"]) == "sunken_vault":
					var t_pos: Vector3 = treasure["pos"]
					var chest: Vector2 = middle + Vector2(t_pos.x, t_pos.z) * zoom
					draw_circle(chest, 4.5, Color(1.0, 0.85, 0.4))
		elif game.in_sky:
			draw_circle(middle, MAP_RADIUS, Color(0.16, 0.3, 0.48, 0.96))
			for spot in [Vector2(0, 0), Vector2(45, 0), Vector2(-35, -30), Vector2(0, -55)]:
				draw_circle(middle + spot * zoom, 4.0, Color(0.7, 0.85, 0.95))

		var me: Vector2 = middle + marker_world * zoom
		var forward_3d: Vector3 = game.player.visuals.global_basis * Vector3(0, 0, -1)
		var forward := Vector2(forward_3d.x, forward_3d.z).normalized()
		var side := Vector2(-forward.y, forward.x)
		var arrow := PackedVector2Array([
			me + forward * 8.0,
			me - forward * 5.0 + side * 5.0,
			me - forward * 5.0 - side * 5.0,
		])
		draw_colored_polygon(arrow, Color(1, 1, 1))
		var arrow_outline := PackedVector2Array([arrow[0], arrow[1], arrow[2], arrow[0]])
		draw_polyline(arrow_outline, Color(0.08, 0.08, 0.15), 1.4)

	# Ring around the map.
	draw_arc(middle, MAP_RADIUS + 2.5, 0.0, TAU, 72, Color(0.85, 0.9, 1.0, 0.75), 2.0)
