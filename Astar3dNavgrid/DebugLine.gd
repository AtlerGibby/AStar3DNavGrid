extends MeshInstance3D

class_name DebugLine

var im_mesh : ImmediateMesh

@export var end : Vector3  = Vector3(0,1,0)
@export var line_Color : Color  = Color.WHITE
var start : Vector3

# Called when the node enters the scene tree for the first time.
func _ready():
	start = position
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	im_mesh = ImmediateMesh.new()
	im_mesh.clear_surfaces()
	im_mesh.surface_begin(PrimitiveMesh.PRIMITIVE_LINES)
	im_mesh.surface_set_color (line_Color)
	im_mesh.surface_add_vertex(Vector3.ZERO) 
	im_mesh.surface_add_vertex((end - self.global_position))
	im_mesh.surface_end()
	self.mesh = im_mesh
	pass
