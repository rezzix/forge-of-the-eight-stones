class_name WorldData
extends RefCounted
## ============================================================================
##  WORLD CONTENT
## ============================================================================
##  Everything about the six biomes lives here: their colours, their shape,
##  their temple, their boss and their magic stone.
##
##  The island is 10x bigger than the first version, so all the positions and
##  sizes below are in the new metres. The biomes do not touch any more: there
##  is water between them (that is why the numbers leave gaps).
##
##  Want to add the 7th and 8th temple (Thunder and Poison caves)? Copy one
##  entry, change the numbers, and the game builds it automatically.
## ============================================================================

## The island is a circle. Distance from the centre, in metres.
const WORLD_RADIUS := 1150.0

## Radius the boss is allowed to move inside its temple.
const ARENA_RADIUS := 11.0

const STONE_KEYS := [
	"magic_rock", "magic_fire", "magic_plants",
	"magic_ice", "magic_water", "magic_poison", "magic_thunder", "magic_uranium",
]

## Six surface temples, the Thunder Temple and the Uranium Temple underground.
const TEMPLE_COUNT := 8

## The underground Thunder Temple. It is not a surface biome, so it lives here
## on its own and is built inside the cave network.
const THUNDER := {
	"id": "thunder",
	"name": "THUNDER CAVERN",
	"temple_name": "THUNDER TEMPLE",
	"element": "Thunder",
	"stone": "magic_thunder",
	"stone_name": "Thunder Magic Stone",
	"glow": Color(0.45, 0.82, 1.0),
	"color": Color(0.18, 0.25, 0.42),
	"boss": {
		"name": "STORM GOLEM", "hp": 180.0, "speed": 6.4, "damage": 16.0,
		"coins": 95, "scale": 1.05, "color": Color(0.31, 0.38, 0.58),
		"eye": Color(0.55, 0.9, 1.0), "ability": "shock",
		"tip": "Zaps you with lightning and slows you down.",
	},
}

## The eighth temple, hidden in the Acid Cave.
const URANIUM := {
	"id": "uranium",
	"name": "URANIUM TEMPLE",
	"temple_name": "URANIUM TEMPLE",
	"element": "Uranium",
	"stone": "magic_uranium",
	"stone_name": "Uranium Magic Stone",
	"glow": Color(0.55, 1.0, 0.3),
	"color": Color(0.2, 0.32, 0.16),
	"boss": {
		"name": "URANIUM GOLEM", "hp": 210.0, "speed": 6.0, "damage": 18.0,
		"coins": 110, "scale": 1.1, "color": Color(0.3, 0.46, 0.25),
		"eye": Color(0.6, 1.0, 0.3), "ability": "radiation",
		"tip": "Radiates poison and slows you down.",
	},
}

## size    = half width / half depth of the biome island (metres)
## jitter  = how wavy its border is (0 = perfect oval, 0.2 = very wavy)
## style   = which temple decoration to build
const BIOMES := [
	{
		"id": "rock",
		"name": "PLAINS",
		"color": Color(0.34, 0.6, 0.3),
		"center": Vector2(0, 0),
		"size": Vector2(380, 380),
		"jitter": 0.09,
		"label": Vector2(150, 250),
		"temple_pos": Vector2(-150, 150),
		"temple_name": "ROCK TEMPLE",
		"style": "pillars",
		"floor": Color(0.4, 0.38, 0.38),
		"pillar": Color(0.48, 0.46, 0.45),
		"glow": Color(0.62, 0.42, 0.95),
		"mob": Color(0.45, 0.32, 0.28),
		"form": "rock",
		"element": "Rock",
		"stone": "magic_rock",
		"stone_name": "Rock Magic Stone",
		"boss": {
			"name": "ROCK GOLEM", "hp": 160.0, "speed": 4.8, "damage": 14.0,
			"coins": 60, "scale": 1.0, "color": Color(0.36, 0.31, 0.3),
			"eye": Color(1.0, 0.45, 0.15), "ability": "none",
			"tip": "Slow but very tough.",
		},
	},
	{
		"id": "fire",
		"name": "SAVANNA",
		"color": Color(0.72, 0.62, 0.28),
		"center": Vector2(760, 0),
		"size": Vector2(300, 430),
		"jitter": 0.14,
		"label": Vector2(760, -300),
		"temple_pos": Vector2(760, 0),
		"temple_name": "FIRE TEMPLE",
		"style": "obelisks",
		"floor": Color(0.28, 0.2, 0.18),
		"pillar": Color(0.22, 0.16, 0.15),
		"glow": Color(1.0, 0.5, 0.15),
		"mob": Color(0.5, 0.26, 0.18),
		"form": "spike",
		"element": "Fire",
		"stone": "magic_fire",
		"stone_name": "Fire Magic Stone",
		"boss": {
			"name": "EMBER GOLEM", "hp": 130.0, "speed": 6.3, "damage": 16.0,
			"coins": 70, "scale": 0.95, "color": Color(0.55, 0.25, 0.18),
			"eye": Color(1.0, 0.7, 0.1), "ability": "burn",
			"tip": "Fast, and it sets you on fire.",
		},
	},
	{
		"id": "plants",
		"name": "FOREST",
		"color": Color(0.2, 0.42, 0.2),
		"center": Vector2(0, -760),
		"size": Vector2(420, 280),
		"jitter": 0.16,
		"label": Vector2(-260, -720),
		"temple_pos": Vector2(0, -760),
		"temple_name": "PLANTS TEMPLE",
		"style": "trunks",
		"floor": Color(0.22, 0.3, 0.18),
		"pillar": Color(0.32, 0.24, 0.14),
		"glow": Color(0.45, 0.9, 0.4),
		"mob": Color(0.24, 0.4, 0.2),
		"form": "plant",
		"element": "Plants",
		"stone": "magic_plants",
		"stone_name": "Plants Magic Stone",
		"boss": {
			"name": "VINE BEAST", "hp": 175.0, "speed": 4.3, "damage": 12.0,
			"coins": 70, "scale": 1.05, "color": Color(0.2, 0.45, 0.25),
			"eye": Color(0.6, 1.0, 0.4), "ability": "regen",
			"tip": "Heals itself while it fights.",
		},
	},
	{
		"id": "ice",
		"name": "SNOWY FOREST",
		"color": Color(0.85, 0.9, 0.94),
		"center": Vector2(-760, 0),
		"size": Vector2(300, 420),
		"jitter": 0.15,
		"label": Vector2(-700, -300),
		"temple_pos": Vector2(-760, 0),
		"temple_name": "ICE TEMPLE",
		"style": "crystals",
		"floor": Color(0.72, 0.82, 0.9),
		"pillar": Color(0.6, 0.8, 0.95),
		"glow": Color(0.55, 0.85, 1.0),
		"mob": Color(0.55, 0.68, 0.78),
		"form": "crystal",
		"element": "Ice",
		"stone": "magic_ice",
		"stone_name": "Ice Magic Stone",
		"boss": {
			"name": "FROST GOLEM", "hp": 200.0, "speed": 3.9, "damage": 15.0,
			"coins": 70, "scale": 1.3, "color": Color(0.65, 0.8, 0.92),
			"eye": Color(0.5, 0.9, 1.0), "ability": "slow",
			"tip": "Very tough, and its touch slows you down.",
		},
	},
	{
		"id": "water",
		"name": "LAKE",
		"color": Color(0.2, 0.44, 0.72),
		"center": Vector2(0, 760),
		"size": Vector2(380, 300),
		"jitter": 0.13,
		"label": Vector2(260, 700),
		"temple_pos": Vector2(0, 760),
		"temple_name": "WATER TEMPLE",
		"style": "fountain",
		"floor": Color(0.2, 0.35, 0.5),
		"pillar": Color(0.35, 0.55, 0.75),
		"glow": Color(0.3, 0.65, 1.0),
		"mob": Color(0.25, 0.42, 0.6),
		"form": "blob",
		"element": "Water",
		"stone": "magic_water",
		"stone_name": "Water Magic Stone",
		"boss": {
			"name": "TIDE SERPENT", "hp": 120.0, "speed": 7.0, "damage": 13.0,
			"coins": 70, "scale": 0.9, "color": Color(0.2, 0.45, 0.7),
			"eye": Color(0.5, 0.95, 1.0), "ability": "push",
			"tip": "Very fast, and it knocks you away.",
		},
	},
	{
		"id": "poison",
		"name": "MUSHROOM ISLAND",
		"color": Color(0.5, 0.28, 0.48),
		"center": Vector2(-660, 660),
		"size": Vector2(180, 180),
		"jitter": 0.2,
		"label": Vector2(-760, 740),
		"temple_pos": Vector2(-660, 660),
		"temple_name": "POISON TEMPLE",
		"style": "mushrooms",
		"floor": Color(0.42, 0.24, 0.44),
		"pillar": Color(0.82, 0.76, 0.68),
		"glow": Color(0.8, 0.45, 1.0),
		"mob": Color(0.45, 0.28, 0.5),
		"form": "mushroom",
		"element": "Poison",
		"stone": "magic_poison",
		"stone_name": "Poison Magic Stone",
		"boss": {
			"name": "SPORE BEAST", "hp": 150.0, "speed": 5.5, "damage": 12.0,
			"coins": 70, "scale": 1.0, "color": Color(0.45, 0.25, 0.55),
			"eye": Color(0.9, 0.55, 1.0), "ability": "poison",
			"tip": "Poisons you with every hit.",
		},
	},
]


## "magic_fire" -> "Fire". Used to name the infused sword.
static func element_of(stone_key: String) -> String:
	for biome in BIOMES:
		if biome["stone"] == stone_key:
			return String(biome["element"])
	if String(THUNDER["stone"]) == stone_key:
		return String(THUNDER["element"])
	if String(URANIUM["stone"]) == stone_key:
		return String(URANIUM["element"])
	return "Magic"
