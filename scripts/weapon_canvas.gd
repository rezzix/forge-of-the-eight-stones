extends Control
## ============================================================================
##  WEAPON DRAWING GRID
## ============================================================================
##  A small pixel canvas: click (or hold and drag) to draw a weapon, right click
##  to erase. The game reads `cells` and works out the price from the size.
##
##  Cells are stored as Vector2i(x, y) with y = 0 at the BOTTOM of the drawing.
## ============================================================================

signal changed

const COLS := 9
const ROWS := 14
const CELL := 24.0

var cells: Dictionary = {}
## Which material the next click paints. The HUD changes this from the palette.
var brush := "wood"
## Material id -> colour, so the grid shows wood brown and iron silver.
var material_colors: Dictionary = {}


func _ready() -> void:
	custom_minimum_size = Vector2(COLS * CELL, ROWS * CELL)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _draw() -> void:
	var size := Vector2(COLS * CELL, ROWS * CELL)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.07, 0.09, 0.13))

	for x in COLS + 1:
		draw_line(Vector2(x * CELL, 0), Vector2(x * CELL, size.y), Color(1, 1, 1, 0.08), 1.0)
	for y in ROWS + 1:
		draw_line(Vector2(0, y * CELL), Vector2(size.x, y * CELL), Color(1, 1, 1, 0.08), 1.0)

	for cell in cells:
		var rect := Rect2(
			cell.x * CELL + 2.0,
			(ROWS - 1 - cell.y) * CELL + 2.0,
			CELL - 4.0,
			CELL - 4.0
		)
		var material_id := _cell_material(cells[cell])
		var color: Color = material_colors.get(material_id, Color(0.86, 0.88, 0.96))
		draw_rect(rect, color)
		draw_rect(rect, Color(0, 0, 0, 0.35), false, 1.0)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_paint(event.position, event.button_index == MOUSE_BUTTON_LEFT)
	elif event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_paint(event.position, true)
		elif event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			_paint(event.position, false)


func _paint(pos: Vector2, filled: bool) -> void:
	var x := int(pos.x / CELL)
	var y := ROWS - 1 - int(pos.y / CELL)
	if x < 0 or x >= COLS or y < 0 or y >= ROWS:
		return
	var cell := Vector2i(x, y)
	if filled:
		cells[cell] = brush
	else:
		cells.erase(cell)
	queue_redraw()
	changed.emit()


func _cell_material(value) -> String:
	if value is String:
		return String(value)
	if value is StringName:
		return String(value)
	return "copper"


func clear_all() -> void:
	cells.clear()
	queue_redraw()
	changed.emit()
