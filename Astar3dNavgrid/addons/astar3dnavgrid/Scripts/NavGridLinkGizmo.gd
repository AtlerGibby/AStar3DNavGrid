@tool
extends EditorNode3DGizmoPlugin

const MyCustomNode3D = preload("res://addons/astar3dnavgrid/Scripts/NavGridLink.gd")
var dragging = false
var start_pos = Vector3(0,0,0)
var undo_redo : EditorUndoRedoManager

func _init():
	create_material("main", Color.ORANGE)
	create_handle_material("handles")


func _has_gizmo(node):
	return node is MyCustomNode3D


func _redraw(gizmo):
	gizmo.clear()

	var node3d = gizmo.get_node_3d()
	
	if node3d is MyCustomNode3D:
		
		var lines = PackedVector3Array()

		lines.push_back(Vector3(0, 0, 0))
		lines.push_back(node3d.to_pos)

		var handles = PackedVector3Array()

		handles.push_back(Vector3(0, 0, 0))
		handles.push_back(node3d.to_pos)

		gizmo.add_lines(lines, get_material("main", gizmo), false)
		gizmo.add_handles(handles, get_material("handles", gizmo), [])


func _get_gizmo_name():
	return "NavGridLink"


func _get_handle_name(gizmo : EditorNode3DGizmo, handle_id : int, secondary : bool):
	return "NavGridLink Handle"

#func _get_handle_value(gizmo : EditorNode3DGizmo, handle_id : int, secondary : bool):
#	var w = 1234
#	return w

func _set_handle (gizmo : EditorNode3DGizmo, id : int, secondary : bool, camera : Camera3D, point : Vector2):
	var node3d = gizmo.get_node_3d()
	if dragging == false:
		start_pos = node3d.to_pos * node3d.transform.inverse()
		dragging = true
	var direction = camera.project_ray_normal(point)
	var distance = camera.position.distance_to(start_pos)
	node3d.to_pos = camera.project_position(point, distance) * node3d.transform
	gizmo.get_node_3d().update_gizmos()
	#pass

func _commit_handle( gizmo : EditorNode3DGizmo, handle_id : int, secondary : bool, restore : Variant, cancel : bool):
	if dragging:
		var node3d = gizmo.get_node_3d()
		undo_redo.create_action("Move NavLink Gizmo")
		undo_redo.add_do_property(node3d, "to_pos", node3d.to_pos)
		undo_redo.add_do_method(node3d, "update_gizmos")
		undo_redo.add_undo_property(node3d, "to_pos", start_pos * node3d.transform)
		undo_redo.add_undo_method(node3d, "update_gizmos")
		undo_redo.commit_action(false)
		dragging = false
	pass
# You should implement the rest of handle-related callbacks
# (_get_handle_name(), _get_handle_value(), _commit_handle(), ...).


#func get_name():
#	return "NavGridLink"
