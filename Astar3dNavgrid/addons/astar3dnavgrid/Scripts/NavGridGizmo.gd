@tool
extends EditorNode3DGizmoPlugin

const MyCustomNode3D = preload("res://addons/astar3dnavgrid/Scripts/NavGrid.gd")
var dragging = false
var start_pos = Vector3(0,0,0)
var mid = Vector3(0,0,0)
var undo_redo : EditorUndoRedoManager

var test_pos = Vector3(0,0,0)
var face_direction = Vector3(0,0,0)
var save_x := 1.0
var save_y := 1.0
var save_z := 1.0
var save_x2 := 1.0
var save_y2 := 1.0
var save_z2 := 1.0
var lock_x := false
var lock_y := false
var lock_z := false
var save_corner_1 := Vector3.ZERO
var save_corner_2 := Vector3.ZERO
var save_corner_3 := Vector3.ZERO
var save_corner_4 := Vector3.ZERO

var x_axis := Vector3.ZERO
var y_axis := Vector3.ZERO
var z_axis := Vector3.ZERO

var plane_a
var plane_b
var plane_c

func _init():
	create_material("main", Color.WHITE)
	create_handle_material("handles")


func _has_gizmo(node):
	return node is MyCustomNode3D


func _redraw(gizmo):
	gizmo.clear()

	var node3d = gizmo.get_node_3d()
	
	if node3d is MyCustomNode3D:
		
		var lines = PackedVector3Array()

		var rdb = Vector3(node3d.x_origin_offset, node3d.y_origin_offset, node3d.z_origin_offset) * node3d.voxel_grid_scale
		var rdf = Vector3(node3d.x_origin_offset, node3d.y_origin_offset, node3d.z_origin_offset + node3d.z_size) * node3d.voxel_grid_scale
		var ldb = Vector3(node3d.x_origin_offset + node3d.x_size, node3d.y_origin_offset, node3d.z_origin_offset) * node3d.voxel_grid_scale
		var ldf = Vector3(node3d.x_origin_offset + node3d.x_size, node3d.y_origin_offset, node3d.z_origin_offset + node3d.z_size) * node3d.voxel_grid_scale
		
		var rub = Vector3(node3d.x_origin_offset, node3d.y_origin_offset + node3d.y_size, node3d.z_origin_offset) * node3d.voxel_grid_scale
		var ruf = Vector3(node3d.x_origin_offset, node3d.y_origin_offset + node3d.y_size, node3d.z_origin_offset + node3d.z_size) * node3d.voxel_grid_scale
		var lub = Vector3(node3d.x_origin_offset + node3d.x_size, node3d.y_origin_offset + node3d.y_size, node3d.z_origin_offset) * node3d.voxel_grid_scale
		var luf = Vector3(node3d.x_origin_offset + node3d.x_size, node3d.y_origin_offset + node3d.y_size, node3d.z_origin_offset + node3d.z_size) * node3d.voxel_grid_scale
		
		var  local_scale = Vector3.ONE
		var  voxel_scale = Vector3.ONE
		if lock_x || lock_y || lock_z:
			var parent = node3d
			while parent is Node3D:
				local_scale *= parent.scale
				parent = parent.get_parent()
			voxel_scale = Vector3.ONE/(node3d.voxel_grid_scale)
			#voxel_scale *= local_scale
		
		if lock_y:
			rub = save_corner_1
			ruf = save_corner_2
			lub = save_corner_3
			luf = save_corner_4
			node3d.y_size = rub.distance_to(rdb) * voxel_scale.y
		if lock_x:
			ldb = save_corner_1
			ldf = save_corner_2
			lub = save_corner_3
			luf = save_corner_4
			node3d.x_size = ldb.distance_to(rdb) * voxel_scale.x
		if lock_z:
			rdf = save_corner_1
			ruf = save_corner_2
			ldf = save_corner_3
			luf = save_corner_4
			node3d.z_size = rdf.distance_to(rdb) * voxel_scale.z
		
		lines.push_back(rdb)
		lines.push_back(rdf)
		lines.push_back(rdb)
		lines.push_back(ldb)
		lines.push_back(rdf)
		lines.push_back(ldf)
		lines.push_back(ldb)
		lines.push_back(ldf)
		
		lines.push_back(rdb)
		lines.push_back(rub)
		lines.push_back(rdf)
		lines.push_back(ruf)
		lines.push_back(ldb)
		lines.push_back(lub)
		lines.push_back(ldf)
		lines.push_back(luf)
		
		lines.push_back(rub)
		lines.push_back(ruf)
		lines.push_back(rub)
		lines.push_back(lub)
		lines.push_back(ruf)
		lines.push_back(luf)
		lines.push_back(lub)
		lines.push_back(luf)


		var handles = PackedVector3Array()

		handles.push_back((rdb + rdf + ldb + ldf) / 4)
		handles.push_back((rub + ruf + lub + luf) / 4)
		handles.push_back((ldb + ldf + lub + luf) / 4)
		handles.push_back((rdb + rdf + rub + ruf) / 4)
		handles.push_back((rdb + rub + ldb + lub) / 4)
		handles.push_back((rdf + ruf + ldf + luf) / 4)
		
		#handles.push_back(test_pos)

		gizmo.add_lines(lines, get_material("main", gizmo), false)
		gizmo.add_handles(handles, get_material("handles", gizmo), [])


func _get_gizmo_name():
	return "NavGrid"


func _get_handle_name(gizmo : EditorNode3DGizmo, handle_id : int, secondary : bool):
	return "NavGrid Handle"

func _get_handle_value(gizmo : EditorNode3DGizmo, handle_id : int, secondary : bool):
	return handle_id

func _set_handle (gizmo : EditorNode3DGizmo, id : int, secondary : bool, camera : Camera3D, point : Vector2):
	var node3d = gizmo.get_node_3d()
	
	var rdb = Vector3(node3d.x_origin_offset, node3d.y_origin_offset, node3d.z_origin_offset) * node3d.voxel_grid_scale
	var rdf = Vector3(node3d.x_origin_offset, node3d.y_origin_offset, node3d.z_origin_offset + node3d.z_size) * node3d.voxel_grid_scale
	var ldb = Vector3(node3d.x_origin_offset + node3d.x_size, node3d.y_origin_offset, node3d.z_origin_offset) * node3d.voxel_grid_scale
	var ldf = Vector3(node3d.x_origin_offset + node3d.x_size, node3d.y_origin_offset, node3d.z_origin_offset + node3d.z_size) * node3d.voxel_grid_scale
	
	var rub = Vector3(node3d.x_origin_offset, node3d.y_origin_offset + node3d.y_size, node3d.z_origin_offset) * node3d.voxel_grid_scale
	var ruf = Vector3(node3d.x_origin_offset, node3d.y_origin_offset + node3d.y_size, node3d.z_origin_offset + node3d.z_size) * node3d.voxel_grid_scale
	var lub = Vector3(node3d.x_origin_offset + node3d.x_size, node3d.y_origin_offset + node3d.y_size, node3d.z_origin_offset) * node3d.voxel_grid_scale
	var luf = Vector3(node3d.x_origin_offset + node3d.x_size, node3d.y_origin_offset + node3d.y_size, node3d.z_origin_offset + node3d.z_size) * node3d.voxel_grid_scale
	
	if dragging == false:
		
		if id == 0: # bottom
			start_pos = (rdb + rdf + ldb + ldf) / 4
			face_direction = node3d.basis.y
		if id == 1: # top
			start_pos = (rub + ruf + lub + luf) / 4
			face_direction = node3d.basis.y
		if id == 2: # x positive (left)
			start_pos = (ldb + ldf + lub + luf) / 4
			face_direction = node3d.basis.x
		if id == 3: # x negative (right)
			start_pos = (rdb + rdf + rub + ruf) / 4
			face_direction = node3d.basis.x
		if id == 4: # back
			start_pos = (rdb + rub + ldb + lub) / 4
			face_direction = node3d.basis.z
		if id == 5: # front
			start_pos = (rdf + ruf + ldf + luf) / 4
			face_direction = node3d.basis.z
	
		mid = (rdb + rdf + ldb + ldf + rub + ruf + lub + luf) / 8	
		mid *= node3d.transform.inverse()
		start_pos *= node3d.transform.inverse()
		
		
		x_axis = ((ldb + ldf + lub + luf) / 4) * node3d.transform.inverse()
		y_axis = ((rub + ruf + lub + luf) / 4) * node3d.transform.inverse()
		z_axis = ((rdf + ruf + ldf + luf) / 4) * node3d.transform.inverse()
		x_axis -= mid
		y_axis -= mid
		z_axis -= mid
		x_axis = -x_axis.normalized()
		y_axis = -y_axis.normalized()
		z_axis = -z_axis.normalized()
		
		save_x = node3d.x_size
		save_y = node3d.y_size
		save_z = node3d.z_size
		save_x2 = node3d.x_origin_offset
		save_y2 = node3d.y_origin_offset
		save_z2 = node3d.z_origin_offset
		
		if id == 0: # bottom
			save_corner_1 = rub
			save_corner_2 = ruf
			save_corner_3 = lub
			save_corner_4 = luf
		if id == 3: # x negative (right)
			save_corner_1 = ldb
			save_corner_2 = ldf
			save_corner_3 = lub
			save_corner_4 = luf
		if id == 4: # back
			save_corner_1 = rdf
			save_corner_2 = ruf
			save_corner_3 = ldf
			save_corner_4 = luf
	
	
	var direction = camera.project_ray_normal(point)
	var distance = camera.position.distance_to(start_pos)

	var to_pos = camera.project_position(point, distance) * node3d.transform
	if id == 0 || id == 1:
		plane_a = Plane(x_axis, mid)
		plane_b = Plane(z_axis, mid)
	if id == 2 || id == 3:
		plane_a = Plane(y_axis, mid)
		plane_b = Plane(z_axis, mid)
	if id == 4 || id == 5:
		plane_a = Plane(x_axis, mid)
		plane_b = Plane(y_axis, mid)
		
	if abs(plane_a.normal).dot(Vector3.UP) > 0.5 or abs(plane_b.normal).dot(Vector3.UP) > 0.5:
		plane_c = Plane(direction.cross(camera.basis.y), camera.position)
	else:
		plane_c = Plane(direction.cross(camera.basis.x), camera.position)
	var intersection = plane_a.intersect_3(plane_b, plane_c)
	
	if typeof(intersection) != TYPE_NIL:
		if intersection != null && is_nan((intersection + node3d.position).x) == false && is_nan((intersection + node3d.position).y) == false && is_nan((intersection + node3d.position).z) == false:
			test_pos = intersection * node3d.transform
	
	var  local_scale = Vector3.ONE
	var parent = node3d
	while parent is Node3D:
		local_scale *= parent.scale
		parent = parent.get_parent()
		
	var  voxel_scale = Vector3.ONE/(node3d.voxel_grid_scale * local_scale * local_scale)
	
	if intersection != null && is_nan((intersection + node3d.position).x) == false && is_nan((intersection + node3d.position).y) == false && is_nan((intersection + node3d.position).z) == false:
		if id == 0: # bottom
			node3d.y_origin_offset = clamp(test_pos.y, -2147483646, save_y + save_y2 - 1) * voxel_scale.y
			lock_y = true
		if id == 1: # top
			node3d.y_size = clamp(test_pos.y - save_y2 * (1/voxel_scale.y), 1, 2147483647) * voxel_scale.y
		if id == 2: # x positive (left)
			node3d.x_size = clamp(test_pos.x - save_x2 * (1/voxel_scale.x), 1, 2147483647) * voxel_scale.x
		if id == 3: # x negative (right)
			node3d.x_origin_offset = clamp(test_pos.x, -2147483646, save_x + save_x2 - 1) * voxel_scale.x
			lock_x = true
		if id == 4: # back
			node3d.z_origin_offset = clamp(test_pos.z, -2147483646, save_z + save_z2 - 1) * voxel_scale.z
			lock_z = true
		if id == 5: # front
			node3d.z_size = clamp(test_pos.z - save_z2 * (1/voxel_scale.z), 1, 2147483647) * voxel_scale.z
	
	if dragging == false:
		dragging = true
	
	gizmo.get_node_3d().update_gizmos()

func _commit_handle( gizmo : EditorNode3DGizmo, handle_id : int, secondary : bool, restore : Variant, cancel : bool):
	if dragging:
		var node3d = gizmo.get_node_3d()
		undo_redo.create_action("Move NavGrid Gizmo")
		undo_redo.add_do_property(node3d, "x_origin_offset", node3d.x_origin_offset)
		undo_redo.add_do_property(node3d, "y_origin_offset", node3d.y_origin_offset)
		undo_redo.add_do_property(node3d, "z_origin_offset", node3d.z_origin_offset)
		undo_redo.add_do_property(node3d, "x_size", node3d.x_size)
		undo_redo.add_do_property(node3d, "y_size", node3d.x_size)
		undo_redo.add_do_property(node3d, "z_size", node3d.x_size)
		undo_redo.add_do_method(node3d, "update_gizmos")
		undo_redo.add_undo_property(node3d, "x_origin_offset", save_x2)
		undo_redo.add_undo_property(node3d, "y_origin_offset", save_y2)
		undo_redo.add_undo_property(node3d, "z_origin_offset", save_z2)
		undo_redo.add_undo_property(node3d, "x_size", save_x)
		undo_redo.add_undo_property(node3d, "y_size", save_y)
		undo_redo.add_undo_property(node3d, "z_size", save_z)
		undo_redo.add_undo_method(node3d, "update_gizmos")
		undo_redo.commit_action(false)
		lock_x = false
		lock_y = false
		lock_z = false
		dragging = false
	pass
