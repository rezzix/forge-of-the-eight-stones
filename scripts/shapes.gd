class_name Shapes
extends RefCounted
## ============================================================================
##  SHAPE LIBRARY (cubes and triangles only)
## ============================================================================
##  Small helpers that build the blocky character pieces:
##
##    cube_node()  -> a box
##    pyramid()    -> 6 triangles (4 sides + a square base)
##    octahedron() -> 8 triangles (a diamond)
##
##  Every triangle gets an outward-facing normal by hand, so the flat shading
##  looks right even though the shapes are very simple.
## ============================================================================

static func material(color: Color, glowing := false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if glowing:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 2.2
	return mat


static func cube(size: Vector3) -> BoxMesh:
	var box := BoxMesh.new()
	box.size = size
	return box


static func cube_node(size: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = cube(size)
	node.material_override = mat
	return node


## A square pyramid: base on the ground, point at `height`.
static func pyramid(base: float, height: float) -> ArrayMesh:
	var half := base * 0.5
	var apex := Vector3(0, height, 0)
	var b0 := Vector3(-half, 0, -half)
	var b1 := Vector3(half, 0, -half)
	var b2 := Vector3(half, 0, half)
	var b3 := Vector3(-half, 0, half)
	var middle := Vector3(0, height * 0.35, 0)

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	_triangle(surface, apex, b0, b1, middle)
	_triangle(surface, apex, b1, b2, middle)
	_triangle(surface, apex, b2, b3, middle)
	_triangle(surface, apex, b3, b0, middle)
	_triangle(surface, b0, b1, b2, middle)
	_triangle(surface, b0, b2, b3, middle)
	return surface.commit()


## A diamond: point up, point down, four corners in the middle.
static func octahedron(radius: float, height: float) -> ArrayMesh:
	var top := Vector3(0, height * 0.5, 0)
	var bottom := Vector3(0, -height * 0.5, 0)
	var p0 := Vector3(radius, 0, 0)
	var p1 := Vector3(0, 0, radius)
	var p2 := Vector3(-radius, 0, 0)
	var p3 := Vector3(0, 0, -radius)
	var middle := Vector3.ZERO

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	_triangle(surface, top, p0, p1, middle)
	_triangle(surface, top, p1, p2, middle)
	_triangle(surface, top, p2, p3, middle)
	_triangle(surface, top, p3, p0, middle)
	_triangle(surface, bottom, p1, p0, middle)
	_triangle(surface, bottom, p2, p1, middle)
	_triangle(surface, bottom, p3, p2, middle)
	_triangle(surface, bottom, p0, p3, middle)
	return surface.commit()


static func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, center: Vector3) -> void:
	var normal := (b - a).cross(c - a).normalized()
	var middle := (a + b + c) / 3.0
	if normal.dot(middle - center) < 0.0:
		normal = -normal  # always point outwards
	surface.set_normal(normal)
	surface.add_vertex(a)
	surface.set_normal(normal)
	surface.add_vertex(b)
	surface.set_normal(normal)
	surface.add_vertex(c)
