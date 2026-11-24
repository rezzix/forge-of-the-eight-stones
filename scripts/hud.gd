extends CanvasLayer
## ============================================================================
##  HUD (the on-screen information)
## ============================================================================
##  Built in code so there are no .tscn files to get lost in. Everything is
##  plain Controls: a panel with your stats, a goal line, the Forge menu and
##  a red flash when you get hit.
## ============================================================================

const MINIMAP_SCRIPT = preload("res://scripts/minimap.gd")
const CANVAS_SCRIPT = preload("res://scripts/weapon_canvas.gd")

var game                          ## set by game.gd before adding to the tree

var health_bar: ProgressBar
var hunger_bar: ProgressBar
var food_label: Label
var breath_bar: ProgressBar
var breath_label: Label
var consumables_label: Label
var time_label: Label
var coins_label: Label
var resources_label: Label
var stones_label: Label
var gear_label: Label
var armour_label: Label
var pet_label: Label
var hands_label: Label
var goal_label: Label
var prompt_label: Label
var log_label: Label
var forge_panel: PanelContainer
var forge_dim: ColorRect
var forge_list: VBoxContainer
var forge_title: Label
var inventory_panel: PanelContainer
var inv_buttons: Array = []
var design_panel: PanelContainer
var design_title: Label
var design_hint: Label
var design_tabs: Dictionary = {}      ## tab id -> Button
var design_slot := "weapon"           ## "weapon" or an armour piece id
var design_drawings: Dictionary = {}  ## tab id -> cells drawn there
var weapon_canvas: Control
var design_info: Label
var design_cost: Label
var forge_button: Button
var material_buttons: Array[Button] = []
var stone_row: HBoxContainer
var selected_stones: Dictionary = {}
var save_button: Button
var logout_button: Button
var shop_panel: PanelContainer
var shop_list: VBoxContainer
var shop_coins_label: Label
var quest_panel: PanelContainer
var quest_list: VBoxContainer
var cooking_panel: PanelContainer
var cooking_list: VBoxContainer
var pause_panel: PanelContainer
var pause_save_button: Button
var new_game_button: Button
var new_game_armed := false
var ending_panel: PanelContainer
var ending_message: Label
var chest_panel: PanelContainer
var chest_buttons: Array = []
var bag_buttons: Array = []
var open_chest := -1
var boss_panel: PanelContainer
var boss_bar: ProgressBar
var boss_name_label: Label
var minimap: Control
var flash_rect: ColorRect

var log_timer := 0.0


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_stats()
	_build_boss_bar()
	_build_prompt()
	_build_log()
	_build_minimap()
	_build_forge()
	_build_inventory()
	_build_design()
	_build_shop()
	_build_quests()
	_build_cooking()
	_build_pause()
	_build_ending()
	_build_chest()
	_build_flash()


func _process(delta: float) -> void:
	if game == null:
		return

	health_bar.value = game.health
	hunger_bar.value = game.hunger
	food_label.text = "Food: %d/100   (F to eat)" % int(game.hunger)
	food_label.add_theme_color_override("font_color",
		Color(1.0, 0.45, 0.35) if game.hunger < 20.0 else Color(0.95, 0.78, 0.45))
	breath_bar.visible = game.in_dive
	breath_label.visible = game.in_dive
	breath_bar.value = game.breath
	breath_label.text = "Breath: %d/100" % int(game.breath)
	consumables_label.text = "Meat %d · Cooked %d · Fish %d · Cooked Fish %d · Jam %d · Berries %d · Wheat %d · Carrot %d · Egg %d · Milk %d · Wool %d · Healing %d (H) · Speed %d (G)" % [
		game.count_item("meat"), game.count_item("cooked_meat"),
		game.count_item("fish"), game.count_item("cooked_fish"), game.count_item("berry_jam"),
		game.count_item("berry"), game.count_item("wheat"), game.count_item("carrot"),
		game.count_item("egg"), game.count_item("milk"), game.count_item("wool"),
		game.count_item("potion_heal"), game.count_item("potion_speed")
	]
	time_label.text = "%s   ·   %s" % [game.clock_text(), game.weather_name()]
	coins_label.text = "Coins: %d" % game.coins
	resources_label.text = "Stone %d · Wood %d · Hardwood %d · Copper %d · Iron %d · Uranium %d · Sky %d" % [
		game.count_item("stone"), game.count_item("wood"), game.count_item("hardwood"),
		game.count_item("copper"), game.count_item("iron"), game.count_item("uranium"),
		game.count_item("sky_crystal"),
	]
	stones_label.text = "Magic stones %d/%d   ·   Temples %d/%d" % [
		game.stone_count(), WorldData.TEMPLE_COUNT,
		game.temples_beaten(), WorldData.TEMPLE_COUNT,
	]
	if game.infused.size() >= 2:
		stones_label.text += "   ·   Mix: " + game.infused_names()
	gear_label.text = "Pickaxe: %s (x%.1f)    Weapon: %s — %d dmg%s" % [
		game.pickaxe_name, game.mining_power, game.sword_name, int(game.attack_power),
		(" (+%d from stones)" % int(game.infused.size() * 7)) if not game.infused.is_empty() else ""
	]
	if game.armour.is_empty():
		armour_label.text = "Armour: none — draw some at the Forge"
	else:
		armour_label.text = "Armour: %d%% less damage  (%d/4 pieces)" % [
			game.armour_total(), game.armour.size()
		]
	if game.wolf_tamed and game.wolf != null:
		pet_label.text = "Wolf: level %d  ·  %s  ·  K stay/follow  ·  L attack" % [
			game.wolf.level, "staying" if game.wolf.stay else "following"
		]
	else:
		pet_label.text = "Wolf: wild in the Forest  ·  press E near it to tame it"

	if game.player != null:
		var hands := [
			"1 %s" % game.sword_name,
			"2 %s" % game.pickaxe_name,
			"3 %s" % ("Shield" if game.player.has_shield else "shield (craft it)"),
		]
		var active := int(game.player.active_hand)
		hands[active] = "[ %s ]" % hands[active]
		hands_label.text = "Hands:  " + "   ".join(PackedStringArray(hands))
	goal_label.text = "GOAL: " + game.current_goal()
	prompt_label.text = game.current_prompt()

	if inventory_panel.visible:
		refresh_inventory()
	if chest_panel.visible:
		refresh_chest()

	_update_boss_bar()

	if log_timer > 0.0:
		log_timer -= delta
		log_label.modulate.a = clampf(log_timer, 0.0, 1.0)


func _update_boss_bar() -> void:
	# Show the bar for the closest living boss, but only when it is near.
	var nearest = null
	var nearest_distance := 26.0
	if game.player != null:
		for boss in game.bosses:
			if boss == null or not is_instance_valid(boss) or boss.hp <= 0.0:
				continue
			var d: float = game.player.global_position.distance_to(boss.global_position)
			if d < nearest_distance:
				nearest = boss
				nearest_distance = d

	boss_panel.visible = nearest != null
	if nearest != null:
		boss_name_label.text = nearest.boss_name
		boss_bar.max_value = nearest.max_hp
		boss_bar.value = nearest.hp


# --------------------------------------------------------------- BUILDING ---
func _build_stats() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(16, 16)
	panel.custom_minimum_size = Vector2(400, 0)
	panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)

	var title := _label("FORGE OF THE EIGHT STONES", 18, Color(1.0, 0.82, 0.42))
	box.add_child(title)

	time_label = _label("Day 1  ·  08:00", 13, Color(0.75, 0.8, 0.92))
	box.add_child(time_label)

	health_bar = ProgressBar.new()
	health_bar.max_value = 100.0
	health_bar.value = 100.0
	health_bar.show_percentage = false
	health_bar.custom_minimum_size = Vector2(0, 18)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.15, 0.13, 0.14)
	back.set_corner_radius_all(6)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.86, 0.22, 0.26)
	fill.set_corner_radius_all(6)
	health_bar.add_theme_stylebox_override("background", back)
	health_bar.add_theme_stylebox_override("fill", fill)
	box.add_child(health_bar)

	hunger_bar = ProgressBar.new()
	hunger_bar.max_value = 100.0
	hunger_bar.value = 100.0
	hunger_bar.show_percentage = false
	hunger_bar.custom_minimum_size = Vector2(0, 12)
	var food_back := StyleBoxFlat.new()
	food_back.bg_color = Color(0.14, 0.13, 0.12)
	food_back.set_corner_radius_all(5)
	var food_fill := StyleBoxFlat.new()
	food_fill.bg_color = Color(0.85, 0.6, 0.2)
	food_fill.set_corner_radius_all(5)
	hunger_bar.add_theme_stylebox_override("background", food_back)
	hunger_bar.add_theme_stylebox_override("fill", food_fill)
	box.add_child(hunger_bar)

	food_label = _label("Food: 100/100", 12, Color(0.95, 0.78, 0.45))
	box.add_child(food_label)

	breath_bar = ProgressBar.new()
	breath_bar.max_value = 100.0
	breath_bar.value = 100.0
	breath_bar.show_percentage = false
	breath_bar.custom_minimum_size = Vector2(0, 12)
	breath_bar.visible = false
	var breath_back := StyleBoxFlat.new()
	breath_back.bg_color = Color(0.08, 0.14, 0.2)
	breath_back.set_corner_radius_all(5)
	var breath_fill := StyleBoxFlat.new()
	breath_fill.bg_color = Color(0.35, 0.75, 1.0)
	breath_fill.set_corner_radius_all(5)
	breath_bar.add_theme_stylebox_override("background", breath_back)
	breath_bar.add_theme_stylebox_override("fill", breath_fill)
	box.add_child(breath_bar)

	breath_label = _label("Breath: 100/100", 12, Color(0.55, 0.85, 1.0))
	breath_label.visible = false
	box.add_child(breath_label)

	consumables_label = _label("", 13, Color(0.9, 0.8, 0.95))
	consumables_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	consumables_label.custom_minimum_size = Vector2(400, 0)
	box.add_child(consumables_label)

	coins_label = _label("Coins: 0", 16, Color(1.0, 0.88, 0.55))
	box.add_child(coins_label)

	resources_label = _label("", 15, Color(0.86, 0.9, 1.0))
	resources_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	resources_label.custom_minimum_size = Vector2(400, 0)
	box.add_child(resources_label)

	stones_label = _label("", 15, Color(0.8, 0.7, 1.0))
	stones_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stones_label.custom_minimum_size = Vector2(400, 0)
	box.add_child(stones_label)

	gear_label = _label("", 14, Color(0.78, 0.86, 0.95))
	box.add_child(gear_label)

	armour_label = _label("", 14, Color(0.72, 0.92, 0.8))
	armour_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	armour_label.custom_minimum_size = Vector2(400, 0)
	box.add_child(armour_label)

	pet_label = _label("", 14, Color(0.85, 0.85, 0.95))
	pet_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pet_label.custom_minimum_size = Vector2(400, 0)
	box.add_child(pet_label)

	hands_label = _label("", 14, Color(0.95, 0.85, 0.6))
	box.add_child(hands_label)

	goal_label = _label("", 15, Color(0.65, 0.95, 0.7))
	goal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	goal_label.custom_minimum_size = Vector2(400, 0)
	box.add_child(goal_label)


func _build_boss_bar() -> void:
	boss_panel = PanelContainer.new()
	boss_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	boss_panel.position = Vector2(-180, 14)
	boss_panel.custom_minimum_size = Vector2(360, 0)
	boss_panel.visible = false
	boss_panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(boss_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	boss_panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)

	var name_label := _label("ROCK GOLEM", 18, Color(1.0, 0.6, 0.4))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(name_label)
	boss_name_label = name_label

	boss_bar = ProgressBar.new()
	boss_bar.max_value = 160.0
	boss_bar.value = 160.0
	boss_bar.show_percentage = false
	boss_bar.custom_minimum_size = Vector2(0, 16)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.15, 0.13, 0.14)
	back.set_corner_radius_all(6)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.72, 0.35, 0.9)
	fill.set_corner_radius_all(6)
	boss_bar.add_theme_stylebox_override("background", back)
	boss_bar.add_theme_stylebox_override("fill", fill)
	box.add_child(boss_bar)


func _build_prompt() -> void:
	prompt_label = Label.new()
	prompt_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	prompt_label.offset_top = -58
	prompt_label.offset_bottom = -22
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_label.add_theme_font_size_override("font_size", 18)
	prompt_label.add_theme_color_override("font_color", Color(1, 1, 1))
	prompt_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	prompt_label.add_theme_constant_override("outline_size", 7)
	add_child(prompt_label)


func _build_log() -> void:
	log_label = Label.new()
	log_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	log_label.offset_left = 24
	log_label.offset_top = -272
	log_label.offset_right = 760
	log_label.offset_bottom = -234
	log_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	log_label.add_theme_font_size_override("font_size", 17)
	log_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.75))
	log_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	log_label.add_theme_constant_override("outline_size", 6)
	add_child(log_label)


func _build_minimap() -> void:
	minimap = MINIMAP_SCRIPT.new()
	minimap.game = game
	minimap.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	minimap.position = Vector2(16, -206)
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(minimap)


func _build_forge() -> void:
	# Darken the world behind the menu so the text is easy to read.
	forge_dim = ColorRect.new()
	forge_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	forge_dim.color = Color(0.02, 0.03, 0.05, 0.55)
	forge_dim.visible = false
	forge_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(forge_dim)

	# A CenterContainer keeps the menu perfectly in the middle of the screen.
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	forge_panel = PanelContainer.new()
	forge_panel.visible = false
	forge_panel.custom_minimum_size = Vector2(720, 0)
	forge_panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(forge_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	forge_panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	forge_title = _label("THE FORGE", 24, Color(1.0, 0.82, 0.42))
	box.add_child(forge_title)

	var subtitle := _label("Spend what you mined. Scroll for more recipes.", 14, Color(0.75, 0.8, 0.9))
	box.add_child(subtitle)

	# Open the drawing table: design a weapon or armour out of squares.
	var design_button := Button.new()
	design_button.text = "DRAW YOUR OWN GEAR  (weapon or armour)"
	design_button.custom_minimum_size = Vector2(0, 40)
	design_button.focus_mode = Control.FOCUS_NONE
	design_button.pressed.connect(open_design)
	box.add_child(design_button)

	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 8)
	box.add_child(tools)

	save_button = Button.new()
	save_button.text = "SAVE GAME"
	save_button.custom_minimum_size = Vector2(0, 34)
	save_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_button.focus_mode = Control.FOCUS_NONE
	save_button.pressed.connect(_save_from_menu)
	tools.add_child(save_button)

	logout_button = Button.new()
	logout_button.text = "LOG OUT (saves first)"
	logout_button.custom_minimum_size = Vector2(0, 34)
	logout_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	logout_button.focus_mode = Control.FOCUS_NONE
	logout_button.pressed.connect(func() -> void: game.logout())
	tools.add_child(logout_button)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 400)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)

	forge_list = VBoxContainer.new()
	forge_list.add_theme_constant_override("separation", 6)
	forge_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(forge_list)

	var hint := _label("Press E to close", 13, Color(0.6, 0.65, 0.75))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)


func _build_flash() -> void:
	flash_rect = ColorRect.new()
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.color = Color(0.9, 0.1, 0.1, 0.0)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash_rect)


# -------------------------------------------------------------- INVENTORY ---
func _build_inventory() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	inventory_panel = PanelContainer.new()
	inventory_panel.visible = false
	inventory_panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(inventory_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	inventory_panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	box.add_child(_label("YOUR BAG", 24, Color(1.0, 0.82, 0.42)))
	box.add_child(_label("9 slots  ·  15 items per slot", 14, Color(0.75, 0.8, 0.9)))

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	box.add_child(grid)

	for i in 9:
		var button := _slot_button()
		grid.add_child(button)
		inv_buttons.append(button)

	var hint := _label("Press  !  or  E  to close", 13, Color(0.62, 0.68, 0.8))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)


func _slot_button() -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(112, 86)
	button.add_theme_font_size_override("font_size", 14)
	button.focus_mode = Control.FOCUS_NONE
	return button


func _paint_slot(button: Button, slot) -> void:
	if slot == null:
		button.text = "—"
		button.add_theme_color_override("font_color", Color(0.42, 0.45, 0.52))
		return
	button.text = "%s\n×%d" % [game.item_label(String(slot["item"])), int(slot["count"])]
	button.add_theme_color_override("font_color", game.item_color(String(slot["item"])))


func toggle_inventory() -> void:
	var show := not inventory_panel.visible
	if show:
		close_menus()
	inventory_panel.visible = show
	_update_dim()
	if show:
		refresh_inventory()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func refresh_inventory() -> void:
	if game == null:
		return
	for i in inv_buttons.size():
		_paint_slot(inv_buttons[i], game.slots[i])


# ----------------------------------------------------------- DRAW A WEAPON ---
func _build_design() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	design_panel = PanelContainer.new()
	design_panel.visible = false
	design_panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(design_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	design_panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)

	design_title = _label("DRAW YOUR WEAPON", 22, Color(1.0, 0.82, 0.42))
	box.add_child(design_title)

	# Tabs: one for the weapon, one for each piece of armour.
	design_drawings = {"weapon": {}, "bow": {}}
	for piece in game.ARMOUR_PIECES:
		design_drawings[String(piece["id"])] = {}

	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 4)
	tab_row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(tab_row)

	var tab_group := ButtonGroup.new()
	design_tabs.clear()
	var tabs: Array = [{"id": "weapon", "name": "Weapon"}, {"id": "bow", "name": "Bow"}]
	for piece in game.ARMOUR_PIECES:
		tabs.append(piece)
	for tab in tabs:
		var tab_button := Button.new()
		tab_button.text = String(tab["name"])
		tab_button.toggle_mode = true
		tab_button.button_group = tab_group
		tab_button.custom_minimum_size = Vector2(96, 30)
		tab_button.add_theme_font_size_override("font_size", 12)
		tab_button.focus_mode = Control.FOCUS_NONE
		var tab_id := String(tab["id"])
		tab_button.pressed.connect(func() -> void: _select_design_tab(tab_id))
		tab_row.add_child(tab_button)
		design_tabs[tab_id] = tab_button

	design_hint = _label(
		"Click to paint, right click to erase. Bottom rows = handle, top rows = blade!",
		13, Color(0.75, 0.8, 0.9)
	)
	box.add_child(design_hint)

	weapon_canvas = CANVAS_SCRIPT.new()
	var colors := {}
	for material in game.WEAPON_METALS:
		colors[String(material["id"])] = material["color"]
	weapon_canvas.material_colors = colors
	weapon_canvas.changed.connect(_refresh_design)
	weapon_canvas.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(weapon_canvas)

	design_info = _label("", 14, Color(0.85, 0.9, 1.0))
	design_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(design_info)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	row.add_child(_label("Paint:", 12, Color(0.62, 0.68, 0.8)))

	# One paint button per material, built from the game's material list.
	var tips := {
		"wood": "Common and light, but soft: less damage.",
		"copper": "A good all-round metal.",
		"iron": "The strongest metal: 1.5x damage.",
	}
	var group := ButtonGroup.new()
	material_buttons.clear()
	for material in game.WEAPON_METALS:
		var button := Button.new()
		button.text = String(material["name"])
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size = Vector2(80, 36)
		button.add_theme_color_override("font_color", material["color"])
		var material_id := String(material["id"])
		button.pressed.connect(func() -> void: _select_brush(material_id))
		button.tooltip_text = String(tips.get(material_id, ""))
		row.add_child(button)
		material_buttons.append(button)
	_select_brush("wood")

	var clear_button := Button.new()
	clear_button.text = "Clear"
	clear_button.custom_minimum_size = Vector2(80, 36)
	clear_button.pressed.connect(func() -> void: weapon_canvas.clear_all())
	row.add_child(clear_button)

	stone_row = HBoxContainer.new()
	stone_row.add_theme_constant_override("separation", 6)
	stone_row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(stone_row)

	design_cost = _label("", 13, Color(0.85, 0.9, 1.0))
	design_cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	design_cost.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	design_cost.custom_minimum_size = Vector2(640, 0)
	box.add_child(design_cost)

	forge_button = Button.new()
	forge_button.text = "FORGE WEAPON"
	forge_button.custom_minimum_size = Vector2(280, 44)
	forge_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	forge_button.pressed.connect(_forge_drawing)
	box.add_child(forge_button)
	_refresh_stone_buttons()
	_select_design_tab("weapon")

	var hint := _label("Press E to go back to the Forge", 12, Color(0.62, 0.68, 0.8))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)


## Builds one button per magic stone you own (or already infused).
## Clicking an available stone adds it to the weapon you are drawing.
func _refresh_stone_buttons() -> void:
	if game == null or stone_row == null:
		return
	for child in stone_row.get_children():
		stone_row.remove_child(child)
		child.queue_free()

	stone_row.add_child(_label("Magic stones (+7):", 12, Color(0.72, 0.78, 0.9)))
	var stone_entries: Array = WorldData.BIOMES.duplicate()
	stone_entries.append(WorldData.THUNDER)
	stone_entries.append(WorldData.URANIUM)
	var shown := 0
	for entry in stone_entries:
		var stone_key := String(entry["stone"])
		var already_infused: bool = game.infused.has(stone_key)
		var have: int = game.count_item(stone_key)
		if not already_infused and have <= 0:
			continue
		shown += 1

		var button := Button.new()
		button.text = ("✓ " if already_infused else "") + String(entry["element"])
		button.toggle_mode = true
		button.button_pressed = already_infused or selected_stones.has(stone_key)
		button.disabled = already_infused
		button.custom_minimum_size = Vector2(62, 30)
		button.add_theme_font_size_override("font_size", 10)
		button.add_theme_color_override("font_color", entry["glow"])
		if already_infused:
			button.tooltip_text = "Already infused: its +7 damage is active."
		else:
			button.tooltip_text = "+7 damage on this weapon. Costs 25 coins."
			button.toggled.connect(func(on: bool) -> void: _set_stone(stone_key, on))
		stone_row.add_child(button)

	if shown == 0:
		stone_row.add_child(_label("none yet — beat a temple boss", 11, Color(0.6, 0.65, 0.75)))


func open_design() -> void:
	forge_panel.visible = false
	design_panel.visible = true
	selected_stones.clear()
	_select_design_tab(design_slot)
	_refresh_stone_buttons()
	_update_dim()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close_design() -> void:
	design_panel.visible = false
	forge_panel.visible = true
	_update_dim()
	refresh_forge()


## Switches the drawing table between the weapon and the four armour pieces.
func _select_design_tab(tab_id: String) -> void:
	if weapon_canvas == null or design_tabs.is_empty():
		return
	if design_drawings.has(design_slot):
		design_drawings[design_slot] = weapon_canvas.cells
	design_slot = tab_id
	if not design_drawings.has(tab_id):
		design_drawings[tab_id] = {}
	weapon_canvas.cells = design_drawings[tab_id]
	weapon_canvas.queue_redraw()

	for id in design_tabs:
		design_tabs[id].button_pressed = (id == tab_id)

	var is_weapon := tab_id == "weapon" or tab_id == "bow"
	var is_bow := tab_id == "bow"
	if design_title != null:
		if tab_id == "weapon":
			design_title.text = "DRAW YOUR WEAPON"
		elif is_bow:
			design_title.text = "DRAW YOUR BOW"
		else:
			design_title.text = "DRAW YOUR %s" % game.armour_piece_name(tab_id).to_upper()
	if design_hint != null:
		if tab_id == "weapon":
			design_hint.text = "Click to paint, right click to erase. Bottom rows = handle, top rows = blade!"
		elif is_bow:
			design_hint.text = "Click to paint your bow. Bigger and greener means more power."
		else:
			design_hint.text = "Click to paint your %s. Bigger drawings protect more, but cost more." % game.armour_piece_name(tab_id).to_lower()
	if stone_row != null:
		stone_row.visible = is_weapon
	_refresh_design()


func _refresh_design() -> void:
	if game == null or weapon_canvas == null:
		return
	var plan: Dictionary = game.weapon_plan(weapon_canvas.cells)
	var is_weapon := design_slot == "weapon" or design_slot == "bow"
	var is_bow := design_slot == "bow"

	if plan.is_empty():
		if design_slot == "weapon":
			design_info.text = "Draw your weapon — one square is 9 cm."
			design_cost.text = "Paint the handle wood and the blade iron, if you like!"
			forge_button.text = "FORGE WEAPON"
		elif is_bow:
			design_info.text = "Draw your bow — one square is 9 cm."
			design_cost.text = "Paint a bow with wood, iron or glowing uranium."
			forge_button.text = "FORGE BOW"
		else:
			design_info.text = "Draw your %s — one square is 9 cm." % game.armour_piece_name(design_slot).to_lower()
			design_cost.text = "Wood is soft, copper is balanced, iron protects best."
			forge_button.text = "FORGE ARMOUR"
		design_cost.add_theme_color_override("font_color", Color(0.62, 0.68, 0.8))
		forge_button.disabled = true
		return

	var stone_bonus: int = 0
	var total_damage: int = int(plan["damage"])
	if is_weapon:
		stone_bonus = (game.infused.size() + selected_stones.size()) \
			* int(game.INFUSE_DAMAGE_BONUS)
		total_damage += stone_bonus

	design_info.text = "%.2f m tall  ·  %.2f m thick  ·  %d squares" % [
		float(plan["height_m"]), float(plan["thickness_m"]), int(plan["filled"])
	]
	if is_weapon:
		if stone_bonus > 0:
			design_info.text += "  ·  %d + %d magic = %d damage" % [
				int(plan["damage"]), stone_bonus, total_damage
			]
	else:
		design_info.text += "  ·  +%d%% defence" % game.armour_defense(plan)

	var costs: Dictionary = plan["materials"]
	var parts := PackedStringArray()
	var can_afford := true

	for material in game.WEAPON_METALS:
		var material_id := String(material["id"])
		var need := int(costs.get(material_id, 0))
		if need <= 0:
			continue
		var have: int = game.count_item(material_id)
		if have < need:
			parts.append("%d %s (you have %d)" % [
				need, String(material["name"]).to_lower(), have
			])
			can_afford = false
		else:
			parts.append("%d %s" % [need, String(material["name"]).to_lower()])

	var stone_fee: int = 0
	if is_weapon and not selected_stones.is_empty():
		var missing := 0
		for stone_key in selected_stones:
			if game.count_item(String(stone_key)) < 1:
				missing += 1
		var stone_word := "magic stone" if selected_stones.size() == 1 else "magic stones"
		var stone_text := "%d %s" % [selected_stones.size(), stone_word]
		if missing > 0:
			stone_text += " (missing %d)" % missing
			can_afford = false
		parts.append(stone_text)
		stone_fee = selected_stones.size() * int(game.INFUSE_COIN_COST)

	var coin_cost: int = int(plan["coins"]) + stone_fee
	if game.coins < coin_cost:
		parts.append("%d coins (you have %d)" % [coin_cost, game.coins])
		can_afford = false
	else:
		parts.append("%d coins" % coin_cost)

	design_cost.text = "Need " + ", ".join(parts)
	design_cost.add_theme_color_override("font_color",
		Color(0.65, 0.95, 0.65) if can_afford else Color(1.0, 0.55, 0.45))

	if design_slot == "weapon":
		forge_button.text = "FORGE WEAPON — %d damage" % total_damage
	elif is_bow:
		forge_button.text = "FORGE BOW — %d damage" % total_damage
	else:
		forge_button.text = "FORGE %s — +%d%% defence" % [
			game.armour_piece_name(design_slot).to_upper(), game.armour_defense(plan)
		]
	forge_button.disabled = not can_afford


## Adds or removes a magic stone from the weapon being drawn.
func _set_stone(stone_key: String, on: bool) -> void:
	if on:
		selected_stones[stone_key] = true
	else:
		selected_stones.erase(stone_key)
	_refresh_design()


## Picks which material the next click paints with.
func _select_brush(material_id: String) -> void:
	if weapon_canvas != null:
		weapon_canvas.brush = material_id
	for i in material_buttons.size():
		var material: Dictionary = game.WEAPON_METALS[i]
		material_buttons[i].button_pressed = String(material["id"]) == material_id


func _forge_drawing() -> void:
	var built := false
	if design_slot == "weapon":
		built = game.forge_drawn_weapon(weapon_canvas.cells, selected_stones.keys())
	elif design_slot == "bow":
		built = game.forge_drawn_bow(weapon_canvas.cells, selected_stones.keys())
	else:
		built = game.forge_armour_piece(design_slot, weapon_canvas.cells)
	if built:
		selected_stones.clear()
		close_design()


# ------------------------------------------------------------------ SHOP ---
func _build_shop() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	shop_panel = PanelContainer.new()
	shop_panel.visible = false
	shop_panel.custom_minimum_size = Vector2(560, 0)
	shop_panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(shop_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	shop_panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	box.add_child(_label("THE WANDERING TRADER", 24, Color(1.0, 0.82, 0.42)))
	box.add_child(_label(
		"A traveller with a heavy backpack. Prices are fair... mostly.",
		13, Color(0.75, 0.8, 0.9)
	))
	shop_coins_label = _label("", 15, Color(1.0, 0.88, 0.55))
	box.add_child(shop_coins_label)

	shop_list = VBoxContainer.new()
	shop_list.add_theme_constant_override("separation", 8)
	box.add_child(shop_list)

	var hint := _label("Press E to close", 13, Color(0.62, 0.68, 0.8))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)


func toggle_shop() -> void:
	if not shop_panel.visible:
		close_menus()
	shop_panel.visible = not shop_panel.visible
	_update_dim()
	if shop_panel.visible:
		refresh_shop()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func close_shop() -> void:
	shop_panel.visible = false
	_update_dim()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func refresh_shop() -> void:
	if game == null or shop_list == null:
		return
	shop_coins_label.text = "You have %d coins" % game.coins

	for child in shop_list.get_children():
		shop_list.remove_child(child)
		child.queue_free()

	for i in game.TRADER_OFFERS.size():
		var offer: Dictionary = game.TRADER_OFFERS[i]
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 44)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.focus_mode = Control.FOCUS_NONE
		var item: String = game.item_label(String(offer["item"])).to_lower()
		var amount: int = int(offer["amount"])
		if String(offer["kind"]) == "buy":
			button.text = "  Buy %d %s   —   %d coins" % [amount, item, int(offer["coins"])]
		else:
			button.text = "  Sell %d %s   —   +%d coins" % [amount, item, int(offer["coins"])]
		button.disabled = not game.trader_can_offer(offer)
		var index: int = i
		button.pressed.connect(func() -> void: game.trader_trade(index))
		shop_list.add_child(button)


# ---------------------------------------------------------------- QUESTS ---
func _build_quests() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	quest_panel = PanelContainer.new()
	quest_panel.visible = false
	quest_panel.custom_minimum_size = Vector2(640, 0)
	quest_panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(quest_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	quest_panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	box.add_child(_label("VILLAGE QUESTS", 24, Color(1.0, 0.82, 0.42)))
	box.add_child(_label("The villagers need a hand. Bring them what they ask for.", 13, Color(0.75, 0.8, 0.9)))

	quest_list = VBoxContainer.new()
	quest_list.add_theme_constant_override("separation", 8)
	box.add_child(quest_list)

	var hint := _label("Press E to close", 13, Color(0.62, 0.68, 0.8))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)


func toggle_quests() -> void:
	if not quest_panel.visible:
		close_menus()
	quest_panel.visible = not quest_panel.visible
	_update_dim()
	if quest_panel.visible:
		refresh_quests()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func close_quests() -> void:
	quest_panel.visible = false
	_update_dim()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func refresh_quests() -> void:
	if game == null or quest_list == null:
		return
	for child in quest_list.get_children():
		quest_list.remove_child(child)
		child.queue_free()

	for i in game.VILLAGE_QUESTS.size():
		var quest: Dictionary = game.VILLAGE_QUESTS[i]
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 52)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.focus_mode = Control.FOCUS_NONE
		var reward := PackedStringArray()
		for item in quest["give"]:
			reward.append("%d %s" % [int(quest["give"][item]), game.item_label(String(item)).to_lower()])
		var done: bool = game.quests_done.has(String(quest["id"]))
		button.text = "  %s   —   %d %s  →  %d coins%s%s" % [
			String(quest["name"]), int(quest["amount"]),
			game.item_label(String(quest["item"])).to_lower(),
			int(quest["coins"]),
			(" + " + ", ".join(reward)) if not reward.is_empty() else "",
			"   ✓ DONE" if done else "",
		]
		button.disabled = not game.quest_can_do(quest)
		var index: int = i
		button.pressed.connect(func() -> void: game.do_quest(index))
		quest_list.add_child(button)


# -------------------------------------------------------------- CAMPFIRE ---
func _build_cooking() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	cooking_panel = PanelContainer.new()
	cooking_panel.visible = false
	cooking_panel.custom_minimum_size = Vector2(560, 0)
	cooking_panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(cooking_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	cooking_panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	box.add_child(_label("THE CAMPFIRE", 24, Color(1.0, 0.72, 0.35)))
	box.add_child(_label("Cook what you hunted and gathered. Warm food fills you up.", 13, Color(0.8, 0.82, 0.9)))

	cooking_list = VBoxContainer.new()
	cooking_list.add_theme_constant_override("separation", 8)
	box.add_child(cooking_list)

	var hint := _label("Press E to close", 13, Color(0.62, 0.68, 0.8))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)


func toggle_cooking() -> void:
	if not cooking_panel.visible:
		close_menus()
	cooking_panel.visible = not cooking_panel.visible
	_update_dim()
	if cooking_panel.visible:
		refresh_cooking()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func close_cooking() -> void:
	cooking_panel.visible = false
	_update_dim()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func refresh_cooking() -> void:
	if game == null or cooking_list == null:
		return
	for child in cooking_list.get_children():
		cooking_list.remove_child(child)
		child.queue_free()

	for i in game.COOKING_RECIPES.size():
		var recipe: Dictionary = game.COOKING_RECIPES[i]
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 48)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.focus_mode = Control.FOCUS_NONE
		button.text = "  %s   —   %d %s   →   %s" % [
			String(recipe["name"]), int(recipe["amount"]),
			game.item_label(String(recipe["need"])).to_lower(),
			String(recipe["desc"]),
		]
		button.disabled = game.count_item(String(recipe["need"])) < int(recipe["amount"])
		var index: int = i
		button.pressed.connect(func() -> void: game.cook(index))
		cooking_list.add_child(button)


# ------------------------------------------------------------------ PAUSE ---
func _build_pause() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	pause_panel = PanelContainer.new()
	pause_panel.visible = false
	pause_panel.custom_minimum_size = Vector2(520, 0)
	pause_panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(pause_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	pause_panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)
	box.add_child(_label("PAUSED", 28, Color(1.0, 0.82, 0.42)))
	box.add_child(_label(
		"WASD move · Shift run · Space jump\nLeft click use · 1/2/3 hands · E interact\nF eat · H heal · G speed · V kick · K/L wolf\nT teleport",
		13, Color(0.78, 0.83, 0.92)
	))

	var resume := Button.new()
	resume.text = "RESUME"
	resume.custom_minimum_size = Vector2(0, 42)
	resume.focus_mode = Control.FOCUS_NONE
	resume.pressed.connect(close_pause)
	box.add_child(resume)

	pause_save_button = Button.new()
	pause_save_button.text = "SAVE GAME"
	pause_save_button.custom_minimum_size = Vector2(0, 38)
	pause_save_button.focus_mode = Control.FOCUS_NONE
	pause_save_button.pressed.connect(_pause_save)
	box.add_child(pause_save_button)

	var logout := Button.new()
	logout.text = "LOG OUT (saves first)"
	logout.custom_minimum_size = Vector2(0, 38)
	logout.focus_mode = Control.FOCUS_NONE
	logout.pressed.connect(func() -> void: game.logout())
	box.add_child(logout)

	new_game_button = Button.new()
	new_game_button.text = "NEW GAME"
	new_game_button.custom_minimum_size = Vector2(0, 38)
	new_game_button.focus_mode = Control.FOCUS_NONE
	new_game_button.pressed.connect(_new_game_pressed)
	box.add_child(new_game_button)

	var hint := _label("Esc or RESUME to keep playing", 12, Color(0.62, 0.68, 0.8))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)


func open_pause() -> void:
	if pause_panel == null or pause_panel.visible or menu_open():
		return
	pause_panel.visible = true
	new_game_armed = false
	new_game_button.text = "NEW GAME"
	get_tree().paused = true
	_update_dim()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close_pause() -> void:
	if pause_panel == null:
		return
	pause_panel.visible = false
	get_tree().paused = false
	new_game_armed = false
	_update_dim()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _pause_save() -> void:
	game.save_game()
	pause_save_button.text = "SAVED!"
	await get_tree().create_timer(1.2, true).timeout
	if is_instance_valid(pause_save_button):
		pause_save_button.text = "SAVE GAME"


func _new_game_pressed() -> void:
	if not new_game_armed:
		new_game_armed = true
		new_game_button.text = "CLICK AGAIN TO ERASE SAVE"
		return
	new_game_armed = false
	game.start_new_game()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if pause_panel != null and pause_panel.visible:
			close_pause()
			get_viewport().set_input_as_handled()
		elif not menu_open():
			open_pause()
			get_viewport().set_input_as_handled()


# ----------------------------------------------------------------- ENDING ---
func _build_ending() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	ending_panel = PanelContainer.new()
	ending_panel.visible = false
	ending_panel.custom_minimum_size = Vector2(620, 0)
	ending_panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(ending_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	ending_panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)
	box.add_child(_label("THE EIGHT STONES", 34, Color(1.0, 0.85, 0.4)))
	ending_message = _label("", 16, Color(0.85, 0.9, 1.0))
	ending_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ending_message.custom_minimum_size = Vector2(560, 0)
	box.add_child(ending_message)

	var keep := Button.new()
	keep.text = "KEEP PLAYING"
	keep.custom_minimum_size = Vector2(0, 44)
	keep.focus_mode = Control.FOCUS_NONE
	keep.pressed.connect(close_ending)
	box.add_child(keep)

	var new_game := Button.new()
	new_game.text = "NEW GAME"
	new_game.custom_minimum_size = Vector2(0, 40)
	new_game.focus_mode = Control.FOCUS_NONE
	new_game.pressed.connect(func() -> void: game.start_new_game())
	box.add_child(new_game)


func show_ending() -> void:
	ending_message.text = "The Eight-Stone Guardian is defeated.\n\nThe island is safe, the Forge is warm, and all eight magic stones shine.\n\nA Sky Portal now glimmers at the Forge...\n\nThank you for playing Forge of the Eight Stones!"
	_show_ending_panel()


func show_dlc_ending() -> void:
	ending_message.text = "DLC: SKY ISLANDS COMPLETE!\n\nThe Sky Dragon is defeated. You have mastered the Eight Stones and the floating islands.\n\nThank you for playing the Sky Islands DLC!"
	_show_ending_panel()


func _show_ending_panel() -> void:
	ending_panel.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_update_dim()


func close_ending() -> void:
	ending_panel.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_update_dim()


# ------------------------------------------------------------------ CHEST ---
func _build_chest() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	chest_panel = PanelContainer.new()
	chest_panel.visible = false
	chest_panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(chest_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	chest_panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	box.add_child(_label("THE CHEST", 24, Color(1.0, 0.82, 0.42)))
	box.add_child(_label("Click an item to move it between the chest and your bag.",
		14, Color(0.75, 0.8, 0.9)))

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 26)
	box.add_child(columns)

	# Left: the chest. Right: your bag.
	var chest_column := VBoxContainer.new()
	chest_column.add_theme_constant_override("separation", 6)
	columns.add_child(chest_column)
	chest_column.add_child(_label("CHEST", 16, Color(0.9, 0.85, 0.7)))

	var chest_grid := GridContainer.new()
	chest_grid.columns = 3
	chest_grid.add_theme_constant_override("h_separation", 6)
	chest_grid.add_theme_constant_override("v_separation", 6)
	chest_column.add_child(chest_grid)

	var bag_column := VBoxContainer.new()
	bag_column.add_theme_constant_override("separation", 6)
	columns.add_child(bag_column)
	bag_column.add_child(_label("YOUR BAG", 16, Color(0.9, 0.85, 0.7)))

	var bag_grid := GridContainer.new()
	bag_grid.columns = 3
	bag_grid.add_theme_constant_override("h_separation", 6)
	bag_grid.add_theme_constant_override("v_separation", 6)
	bag_column.add_child(bag_grid)

	for i in 9:
		var index: int = i
		var chest_button := _slot_button()
		chest_button.custom_minimum_size = Vector2(96, 74)
		chest_button.pressed.connect(func() -> void: game.move_chest_item(open_chest, index, true))
		chest_grid.add_child(chest_button)
		chest_buttons.append(chest_button)

		var bag_button := _slot_button()
		bag_button.custom_minimum_size = Vector2(96, 74)
		bag_button.pressed.connect(func() -> void: game.move_chest_item(open_chest, index, false))
		bag_grid.add_child(bag_button)
		bag_buttons.append(bag_button)

	var hint := _label("Press E to close", 13, Color(0.62, 0.68, 0.8))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)


func toggle_chest(index: int) -> void:
	if chest_panel.visible and open_chest == index:
		close_chest()
		return
	close_menus()
	open_chest = index
	chest_panel.visible = true
	_update_dim()
	refresh_chest()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close_chest() -> void:
	chest_panel.visible = false
	open_chest = -1
	_update_dim()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func refresh_chest() -> void:
	if game == null or open_chest < 0 or open_chest >= game.chests.size():
		return
	var chest_slots: Array = game.chests[open_chest]["slots"]
	for i in chest_buttons.size():
		_paint_slot(chest_buttons[i], chest_slots[i])
	for i in bag_buttons.size():
		_paint_slot(bag_buttons[i], game.slots[i])


func close_menus() -> void:
	forge_panel.visible = false
	inventory_panel.visible = false
	chest_panel.visible = false
	if design_panel != null:
		design_panel.visible = false
	if shop_panel != null:
		shop_panel.visible = false
	if quest_panel != null:
		quest_panel.visible = false
	if cooking_panel != null:
		cooking_panel.visible = false
	open_chest = -1


func menu_open() -> bool:
	return forge_panel.visible or inventory_panel.visible or chest_panel.visible \
		or (design_panel != null and design_panel.visible) \
		or (shop_panel != null and shop_panel.visible) \
		or (quest_panel != null and quest_panel.visible) \
		or (cooking_panel != null and cooking_panel.visible) \
		or (pause_panel != null and pause_panel.visible) \
		or (ending_panel != null and ending_panel.visible)


func _update_dim() -> void:
	forge_dim.visible = menu_open()


# ------------------------------------------------------------------ FORGE ---
func _save_from_menu() -> void:
	game.save_game()
	if save_button == null:
		return
	save_button.text = "SAVED!"
	await get_tree().create_timer(1.2).timeout
	if is_instance_valid(save_button):
		save_button.text = "SAVE GAME"


func toggle_forge() -> void:
	if not forge_panel.visible:
		close_menus()
	forge_panel.visible = not forge_panel.visible
	_update_dim()
	if forge_panel.visible:
		refresh_forge()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func refresh_forge() -> void:
	if game == null:
		return

	for child in forge_list.get_children():
		forge_list.remove_child(child)
		child.queue_free()

	for i in game.recipes.size():
		var recipe: Dictionary = game.recipes[i]
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 46)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text = "  %s   —   %s   (%s)" % [
			recipe["name"],
			game.recipe_cost_text(recipe),
			recipe["desc"],
		]
		button.disabled = not game.can_afford(recipe)
		var index: int = i
		button.pressed.connect(func() -> void: game.craft(index))
		forge_list.add_child(button)


# ------------------------------------------------------------------- TEXT ---
func log(text: String) -> void:
	log_label.text = text
	log_timer = 4.0
	log_label.modulate.a = 1.0


## Red flash when a monster hits you.
func flash_damage() -> void:
	var tween := create_tween()
	tween.tween_property(flash_rect, "color:a", 0.28, 0.06)
	tween.tween_property(flash_rect, "color:a", 0.0, 0.3)


# ---------------------------------------------------------------- HELPERS ---
func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.08, 0.11, 0.88)
	style.border_color = Color(0.95, 0.72, 0.3, 0.85)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	return style
