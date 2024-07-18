## The main components for handling AStar3D generating and pathing.
@icon("res://addons/astar3dnavgrid/Art/NavGridIcon.png")
extends Node3D
class_name NavGrid

## Size of the voxel grid in the X-Axis.
@export var x_size : int = 8
## Size of the voxel grid in the Y-Axis.
@export var y_size : int = 8
## Size of the voxel grid in the Z-Axis.
@export var z_size : int = 8

## Offset the voxel grid origin point in the X-Axis.
@export var x_origin_offset : float = -0.5
## Offset the voxel grid origin point in the Y-Axis.
@export var y_origin_offset : float = -0.5
## Offset the voxel grid origin point in the Z-Axis.
@export var z_origin_offset : float = -0.5

## A multiple from 0 to 2 of the collision shape size used for checking if a point in the navgrid is filled.
@export_range(0,2) var collision_check_error : float = 1

## Size of a single nav grid point.
@export_range(0,10) var voxel_grid_scale : float = 1

## Area to check above a grid cell; multiple of the voxel grid scale.
@export_range(0,10) var height_check : float = 2


## Array of all Nav Grid Links
@export var nav_grid_links : Array[NavGridLink]

## Executes c++ get_point_path calculations on multiple threads.
var nav_grid_path_finder : NavGridPathFinder


## Where to bake the nav grid. 
## FlOOR: for navigating on the ground, like a navmesh.
## ALL_SURFACES: for navigating on the floors, walls, and ceilings. 
## EMPTY_SPACE: for navigating through the air / empty space.
@export_enum("FLOOR", "ALL_SURFACES", "EMPTY_SPACE") var type_of_navigation: int = 0

## What Physics layers to look at when baking the nav grid.
@export_flags_3d_physics var grid_bake_physics_layer_mask = 1

## Enable visualization of nav grid points.
@export var enable_navgrid_visualization : bool
## Enable visualization of path points.
@export var enable_path_visualization : bool
## Size of cubes used to visualize empty navgrid points.
@export_range(0,1) var navgrid_visualization_empty_size : float = 0.01
## Size of cubes used to visualize filled or blocked navgrid points.
@export_range(0,1) var navgrid_visualization_filled_size : float = 0.15
## Size of cubes used to visualize paths.
@export_range(0,1) var path_visualization_size : float = 0.71
## Material used to visualize paths.
@export var path_visualization_mat : Material
## Material used to visualize the nav grid.
@export var navgrid_visualization_mat : Material

## Saves the nagrid data after generation.
@export var save_navgrid_data : bool
## Location to save the navgrid data.
@export var save_navgrid_data_path : String = "res://my_navgrid_data_res.tres"
## Use pregenerated navgrid data instead of creating new data.
@export var load_navgrid_data : NavGridData

## The thread for building the NavGrid when no data is given.
var thread_grid: Thread
## The thread for calculating a path if there isn't a [NavGridPathFinder].
var thread_path: Thread
## The AStar3D storing the NavGrid points and connections.
var global_astar : AStar3D
## Shows which points in the grid are occupied / non-accessible or empty / accessible.
var global_grid : PackedByteArray
## Do physiscs tests to see if a point in the nav grid is occupied by geomety when generating the NavGrid.
var space : PhysicsDirectSpaceState3D
## The box used for physiscs tests when generating the NavGrid.
var vox_test_shape = BoxShape3D.new()

## Check if the "on_grid_creation" signal has been emitted.
var grid_signal_emitted : bool = false
## Check if the "on_path_creation" signal has been emited.
var path_signal_emitted : bool = false
## Check if a path has been created.
var path_created_check : bool = false

## Tracks a [NavGridAgent] to update it when a path has been genrated.
class PathJob:
	var listener : NavGridAgent = null
	var result : PackedVector3Array
	

## Emitted when the NavGrid has been generated.
signal on_grid_creation()
## Emitted when a path has been created.
signal on_path_creation(path : PackedVector3Array)

## The most recently created path. Can be visualized with enable_path_visualization.
var created_path := PackedVector3Array()
## Queue of Vector3 Arrays "[start, end]", for calculating paths.
var path_creation_requests := Array(PackedVector3Array())
## Queue of [NavGridAgent] lsiteners. When a path creation job is done, the listeners are updated.
var path_creation_listeners := Array()
## Queue of finished path creation jobs. The queue is filled after a path has been calculated.
var path_creation_jobs := Array([])

var local_up = Vector3.UP
var local_right = Vector3.RIGHT
var local_forward = Vector3.FORWARD
var local_scale = Vector3.ONE
var local_basis = Basis.IDENTITY

# Called when the node enters the scene tree for the first time.
func _ready():
	
	var parent = get_parent()
	
	for child in get_children():
		if child is NavGridPathFinder:
			nav_grid_path_finder = child
			break
	
	while parent is Node3D:
		local_scale *= scale
		parent = parent.get_parent()
	
	for child in get_children():
		child.scale = Vector3(1.0/local_scale.x, 1.0/local_scale.y, 1.0/local_scale.z)
		(child as Node3D).rotation -= rotation
	
	#voxel_grid_scale *= local_scale.x
	#local_scale = Vector3.ONE
	
	local_up = basis.y.normalized()
	local_right = basis.x.normalized()
	local_forward = basis.z.normalized()
	local_basis = Basis.IDENTITY
	
	space = PhysicsServer3D.space_get_direct_state(get_world_3d().get_space())
	#if type_of_navigation == 1:
	#print(local_scale * voxel_grid_scale)
	vox_test_shape.set_size(local_scale * voxel_grid_scale * collision_check_error)
	#else:
	#	vox_test_shape.set_size(Vector3(voxel_grid_scale, voxel_grid_scale * height_check, voxel_grid_scale))
	if load_navgrid_data == null:
		calculate_nav_grid()
	else:
		global_astar = AStar3D.new()
		for x in range(len(load_navgrid_data.astar_ids)):
			global_astar.add_point(load_navgrid_data.astar_ids[x], load_navgrid_data.astar_positions[x])
		for x in range(len(load_navgrid_data.astar_cons)):
			for id in load_navgrid_data.astar_cons[x]:
				global_astar.connect_points(load_navgrid_data.astar_ids[x], id, false)
			
		global_grid = load_navgrid_data.grid_save
		grid_signal_emitted = false
	#subscribe_for_path(null, Vector3.ZERO, Vector3(10,10,10))
	pass # Replace with function body.

## To query for a path, a [NavGridAgent] has to subscribe.
func subscribe_for_path (listener : NavGridAgent, start : Vector3, end : Vector3):
	path_creation_requests.append([start, end])
	path_creation_listeners.append(listener)
	pass

## INTERNAL FUNCTION: generates the NavGrid.
func generate_grid():
	
	#debug_m.transform = all_shapes[0].global_transform
	var grid_array := PackedByteArray()
	grid_array.resize(x_size * y_size * z_size)
	
	#var origin_offset_vec := Vector3(x_origin_offset * local_scale.x, y_origin_offset * local_scale.y, z_origin_offset * local_scale.z)
	var origin_offset_vec := Vector3(x_origin_offset, y_origin_offset, z_origin_offset)
	
	var tmp_Arr := PackedVector3Array()
	tmp_Arr.append(Vector3(0, 0, -1) * voxel_grid_scale)
	tmp_Arr.append(Vector3(0, 0, 1) * voxel_grid_scale)
	tmp_Arr.append(Vector3(0, -1, 0) * voxel_grid_scale)
	tmp_Arr.append(Vector3(0, 1, 0) * voxel_grid_scale)
	tmp_Arr.append(Vector3(-1, 0, 0) * voxel_grid_scale)
	tmp_Arr.append(Vector3(1, 0, 0) * voxel_grid_scale)
	tmp_Arr.append(Vector3(0, -1, -1) * voxel_grid_scale)
	tmp_Arr.append(Vector3(0, 1, -1) * voxel_grid_scale)
	tmp_Arr.append(Vector3(-1, 0, -1) * voxel_grid_scale)
	tmp_Arr.append(Vector3(1, 0, -1) * voxel_grid_scale)
	tmp_Arr.append(Vector3(0, -1, 1) * voxel_grid_scale)
	tmp_Arr.append(Vector3(0, 1, 1) * voxel_grid_scale)
	tmp_Arr.append(Vector3(-1, 0, 1) * voxel_grid_scale)
	tmp_Arr.append(Vector3(1, 0, 1) * voxel_grid_scale)
	tmp_Arr.append(Vector3(-1, -1, 0) * voxel_grid_scale)
	tmp_Arr.append(Vector3(-1, 1, 0) * voxel_grid_scale)
	tmp_Arr.append(Vector3(1, -1, 0) * voxel_grid_scale)
	tmp_Arr.append(Vector3(1, 1, 0) * voxel_grid_scale)
	tmp_Arr.append(Vector3(-1, -1, -1) * voxel_grid_scale)
	tmp_Arr.append(Vector3(-1, -1, 1) * voxel_grid_scale)
	tmp_Arr.append(Vector3(-1, 1, -1) * voxel_grid_scale)
	tmp_Arr.append(Vector3(1, -1, -1) * voxel_grid_scale)
	tmp_Arr.append(Vector3(-1, 1, 1) * voxel_grid_scale)
	tmp_Arr.append(Vector3(1, -1, 1) * voxel_grid_scale)
	tmp_Arr.append(Vector3(1, 1, -1) * voxel_grid_scale)
	tmp_Arr.append(Vector3(1, 1, 1) * voxel_grid_scale)
	
	
	for i in range(x_size * y_size * z_size):
		var x_pos = i % x_size
		var y_pos = int(float(i) / x_size) % y_size
		var z_pos = int(float(i) / (x_size * y_size)) % z_size
		
		
		#var vox_pos : Vector3 = (local_up * y_pos) + (local_right * x_pos) + (local_forward * z_pos)
		#vox_pos += origin_offset_vec
		var vox_pos : Vector3 = (local_up * (y_pos + origin_offset_vec.y)) + (local_right * (x_pos + origin_offset_vec.x)) + (local_forward * (z_pos + origin_offset_vec.z))
		vox_pos *= local_scale
		vox_pos *= voxel_grid_scale
		vox_pos += global_transform.origin
		
		#var space : PhysicsDirectSpaceState3D = PhysicsServer3D.space_get_direct_state(get_world_3d().get_space())
		#var parameters = PhysicsPointQueryParameters3D.new()
		var parameters = PhysicsShapeQueryParameters3D.new()
		
		#if type_of_navigation == 1:
		parameters.transform = Transform3D(local_basis, vox_pos)
		#else:
		#	parameters.transform = Transform3D(Basis.IDENTITY, vox_pos - (Vector3.UP * ((height_check - 1)/2) ))
		parameters.shape = vox_test_shape
		#parameters.shape_rid = box_2.get_rid()
		parameters.collide_with_areas = false
		parameters.collide_with_bodies = true
		parameters.collision_mask = grid_bake_physics_layer_mask
		#var result : Array[Dictionary] = space.intersect_point(parameters) 
		
		var result : Array[Dictionary] = space.intersect_shape(parameters)
		#print(result)
		
		if len(result) > 0:
			grid_array[i] = 1
		else:
			# check height
			var parameters2 = PhysicsRayQueryParameters3D.new()
			parameters2.collide_with_areas = false
			parameters2.collide_with_bodies = true
			parameters2.collision_mask = grid_bake_physics_layer_mask
			parameters2.from = vox_pos
			var result2 : Dictionary
			
			if type_of_navigation == 0:
				parameters2.to = vox_pos + local_up * height_check * voxel_grid_scale * local_scale.y
				result2 = space.intersect_ray (parameters2)
				if len(result2) > 0:
					grid_array[i] = 1
			
			if type_of_navigation == 1:
				var hit_normal = Vector3.ZERO
				var hit_count = 0
				for arr in tmp_Arr:
					var arr_adjusted = local_up * arr.y + local_right * arr.x + local_forward * arr.z
					parameters2.to = (arr_adjusted * local_scale.y) * height_check + vox_pos
					result2 = space.intersect_ray (parameters2)
					if len(result2) > 1:
						hit_normal = result2["normal"]
						hit_count += 1
				hit_normal /= hit_count
				parameters2.to = vox_pos + hit_normal * voxel_grid_scale * height_check * local_scale.y
				result2 = space.intersect_ray (parameters2)
				if len(result2) > 0:
					grid_array[i] = 1
	
	var astar = AStar3D.new()
	var current_id := 0
	
	for i in range(len(grid_array)):
		var x_pos = i % x_size
		var y_pos = int(float(i) / x_size) % y_size
		var z_pos = int(float(i) / (x_size * y_size)) % z_size
		
		#var pos : Vector3 = (local_up * y_pos * local_scale.y) + (local_right * x_pos * local_scale.x) + (local_forward * z_pos * local_scale.z)
		#var pos : Vector3 = (local_up * y_pos) + (local_right * x_pos) + (local_forward * z_pos)
		#pos += origin_offset_vec
		var pos : Vector3 = (local_up * (y_pos + origin_offset_vec.y)) + (local_right * (x_pos + origin_offset_vec.x)) + (local_forward * (z_pos + origin_offset_vec.z))
		pos *= local_scale
		pos *= voxel_grid_scale
		pos += global_transform.origin
		var new_point := false
		
		if grid_array[i] == 0:
			if type_of_navigation == 0:
				if y_pos > 0:
					if grid_array[i - x_size] == 1:
						astar.add_point(current_id, pos)
						new_point = true
			if type_of_navigation == 1:
				var left_space := false
				var down_space := false
				var back_space := false
				var right_space := false
				var up_space := false
				var front_space := false
				if x_pos > 0:
					left_space = true
					if grid_array[i - 1] == 1:
						astar.add_point(current_id, pos)
						new_point = true
				if x_pos < x_size - 1 && !new_point:
					right_space = true
					if grid_array[i + 1] == 1:
						astar.add_point(current_id, pos)
						new_point = true
				if y_pos > 0  && !new_point:
					down_space = true
					if grid_array[i - x_size] == 1:
						astar.add_point(current_id, pos)
						new_point = true
				if y_pos < y_size - 1  && !new_point:
					up_space = true
					if grid_array[i + x_size] == 1:
						astar.add_point(current_id, pos)
						new_point = true
				if z_pos > 0  && !new_point:
					back_space = true
					if grid_array[i - x_size * y_size] == 1:
						astar.add_point(current_id, pos)
						new_point = true
				if z_pos < z_size - 1  && !new_point:
					front_space = true
					if grid_array[i + x_size * y_size] == 1:
						astar.add_point(current_id, pos)
						new_point = true
				if left_space && right_space && up_space && down_space && front_space && back_space:
					if grid_array[i - x_size + 1] == 1 || grid_array[i + x_size + 1] == 1 || grid_array[i - x_size - 1] == 1 || grid_array[i + x_size - 1] == 1:
						astar.add_point(current_id, pos)
						new_point = true
					if grid_array[i - x_size * y_size + 1] == 1 || grid_array[i + x_size * y_size + 1] == 1 || grid_array[i - x_size * y_size - 1] == 1 || grid_array[i + x_size * y_size - 1] == 1:
						astar.add_point(current_id, pos)
						new_point = true
					if grid_array[i - x_size * y_size + x_size] == 1 || grid_array[i + x_size * y_size + x_size] == 1 || grid_array[i - x_size * y_size - x_size] == 1 || grid_array[i + x_size * y_size - x_size] == 1:
						astar.add_point(current_id, pos)
						new_point = true
					if grid_array[i - x_size * y_size + x_size + 1] == 1 || grid_array[i + x_size * y_size + x_size + 1] == 1 || grid_array[i - x_size * y_size + x_size - 1] == 1 || grid_array[i + x_size * y_size + x_size - 1] == 1:
						astar.add_point(current_id, pos)
						new_point = true
					if grid_array[i - x_size * y_size - x_size + 1] == 1 || grid_array[i + x_size * y_size - x_size + 1] == 1 || grid_array[i - x_size * y_size - x_size - 1] == 1 || grid_array[i + x_size * y_size - x_size - 1] == 1:
						astar.add_point(current_id, pos)
						new_point = true
			if type_of_navigation == 2:
				if grid_array[i] == 0:
					astar.add_point(current_id, pos)
					new_point = true
				
			if new_point:
				for arr in tmp_Arr:
					var arr_adjusted = local_up * arr.y + local_right * arr.x + local_forward * arr.z
					var id_check = astar.get_closest_point(pos + (arr_adjusted * local_scale.y))
					var smallest = min(min(local_scale.x, local_scale.y), local_scale.z)
					#print(smallest)
					if astar.get_point_position(id_check).distance_to(pos + (arr_adjusted * local_scale.y)) < (voxel_grid_scale * smallest) / 2:
						astar.connect_points(current_id, id_check, true)
				current_id += 1
		
	
	for link in nav_grid_links:
		#print(link.start)
		#print(link.end)
		var point_a := astar.get_closest_point(link.start)
		var point_b := astar.get_closest_point(link.end)
		if point_a != -1 and point_b != -1 and point_a != point_b:
			if link.directionality == 0: # Bi-directional
				astar.connect_points(point_a, point_b, true)
			if link.directionality == 1: # start > end
				astar.connect_points(point_a, point_b, false)
			if link.directionality == 1: # end > start
				astar.connect_points(point_b, point_a, false)
			#print("LINK " + str(point_a) + " - " + str(point_b) )
	
	
	global_grid = grid_array
	global_astar = astar

## INTERNAL FUNCTION: generates cubes at navigatable parts of the NavGrid.
func debug_navigatable_region(grid_array : PackedByteArray):
	
	var mmi = get_node("MultiMeshInstance3D")
	var origin_offset_vec := Vector3(x_origin_offset, y_origin_offset, z_origin_offset)
	#origin_offset_vec *= voxel_grid_scale
	#origin_offset_vec *= local_scale
	#origin_offset_vec *= Vector3(1.0/local_scale.x, 1.0/local_scale.y, 1.0/local_scale.z)
	#var origin_offset_vec := Vector3(x_origin_offset * local_scale.x, y_origin_offset * local_scale.y, z_origin_offset * local_scale.z)
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var box = BoxMesh.new()
	box.size = Vector3.ONE * navgrid_visualization_filled_size
	mm.mesh = box
	mm.instance_count = x_size * y_size * z_size
	
	for i in range(grid_array.size()):
		var x_pos = i % x_size
		var y_pos = int(float(i) / x_size) % y_size
		var z_pos = int(float(i) / (x_size * y_size)) % z_size
		
		#var vox_pos : Vector3 = (local_up * y_pos * local_scale.y) + (local_right * x_pos * local_scale.x) + (local_forward * z_pos * local_scale.z)
		#var vox_pos : Vector3 = (local_up * y_pos) + (local_right * x_pos) + (local_forward * z_pos)
		#vox_pos += origin_offset_vec
		var vox_pos : Vector3 = (local_up * (y_pos + origin_offset_vec.y)) + (local_right * (x_pos + origin_offset_vec.x)) + (local_forward * (z_pos + origin_offset_vec.z))
		vox_pos *= local_scale
		vox_pos *= voxel_grid_scale
		#vox_pos += global_transform.origin
		#var vox_pos := Vector3(x_pos, y_pos, z_pos) * voxel_grid_scale + origin_offset_vec
		
		if type_of_navigation == 2:
			if grid_array[i] == 0:
				mm.set_instance_transform(i, Transform3D(local_basis, vox_pos))
			else:
				mm.set_instance_transform(i, Transform3D(local_basis, vox_pos).scaled_local(Vector3.ONE * (1/navgrid_visualization_filled_size) * navgrid_visualization_empty_size))
		else:
			if grid_array[i] == 1:
				mm.set_instance_transform(i, Transform3D(local_basis, vox_pos))
			else:
				mm.set_instance_transform(i, Transform3D(local_basis, vox_pos).scaled_local(Vector3.ONE * (1/navgrid_visualization_filled_size) * navgrid_visualization_empty_size))
			
	mmi.multimesh = mm
	
	pass

## INTERNAL FUNCTION: generates cubes at each point of the most recently created path.
func debug_navigation_path(astar : AStar3D):
	
	var box_2 = BoxMesh.new()
	box_2.size = Vector3.ONE * path_visualization_size
	
	var a_s_path := created_path #PackedVector3Array()

	#var point_a := astar.get_point_position(astar.get_closest_point(Vector3.ZERO))
	#var point_b := astar.get_point_position(astar.get_closest_point(Vector3(10,10,10)))
	#a_s_path = get_point_path(astar, point_a, point_b, true)
	
	if len(a_s_path) > 0:
		var mmi2 = get_node("MultiMeshInstance3D2")
		var mm2 = MultiMesh.new()
		mm2.transform_format = MultiMesh.TRANSFORM_3D
		var box2 = BoxMesh.new()
		box2.size = Vector3(1,1,1)
		mm2.mesh = box_2
		mm2.instance_count = len(a_s_path)
		for i in range(mm2.instance_count):
			mm2.set_instance_transform(i, Transform3D(local_basis, a_s_path[i] - global_position))
		mmi2.multimesh = mm2
	else:
		print("Attempting to visualize an empty A* path.")
		
	created_path = a_s_path
	
	pass


## INTERNAL FUNCTION: calls generate_grid function in a seperate thread.
func calculate_nav_grid():
	
	grid_signal_emitted = false
	global_astar = null
	global_grid.clear()
	thread_grid = Thread.new()
	thread_grid.start(generate_grid.bind())
	#thread.wait_to_finish()
	#generate_grid()
	
	pass

## INTERNAL FUNCTION: calls the get_point_path or get_point_path_finder function in a seperate thread.
func calculate_nav_path(points : PackedVector3Array, listener : NavGridAgent):
	
	path_signal_emitted = false
	path_created_check = false
	if global_astar != null && global_grid.is_empty() == false && grid_signal_emitted:
		thread_path = Thread.new()
		var point_a_index = global_astar.get_closest_point(points[0])
		var point_b_index = global_astar.get_closest_point(points[1])
		var point_a := listener.position
		var point_b := listener.position
		if point_a_index != -1 and point_b_index != -1 and point_a_index != point_b_index:
			point_a = global_astar.get_point_position(point_a_index)
			point_b = global_astar.get_point_position(point_b_index)
		#debug_line_a.global_position = point_a
		#debug_line_a.end = point_b
		#debug_line_a.line_Color = Color.ORANGE_RED
		
		var p_job = PathJob.new()
		p_job.listener = listener
		path_creation_jobs.append(p_job)
		
		if nav_grid_path_finder != null:
			thread_path.start(get_point_path_finder.bind(global_astar, point_a_index, point_b_index, listener))
		else:
			thread_path.start(get_point_path.bind(global_astar, point_a, point_b, listener, true))
		
		path_creation_requests.pop_front()
		path_creation_listeners.pop_front()
	
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	
	#print(global_grid)
	if(global_grid.is_empty() == false && grid_signal_emitted == false):
		if save_navgrid_data && load_navgrid_data == null:
			var my_res = NavGridData.new()
			var astar_ids := global_astar.get_point_ids()
			var astar_cons : Array[PackedInt64Array]
			var astar_positions := PackedVector3Array()
			for id in astar_ids:
				astar_positions.append(global_astar.get_point_position(id))
				astar_cons.append(global_astar.get_point_connections(id))
			my_res.astar_ids = astar_ids
			my_res.astar_cons = astar_cons
			my_res.astar_positions = astar_positions
			my_res.grid_save = global_grid
			ResourceSaver.save(my_res, save_navgrid_data_path)
		if enable_navgrid_visualization:
			debug_navigatable_region(global_grid)
		grid_signal_emitted = true
		on_grid_creation.emit()
	
	if(global_astar != null && created_path.is_empty() == false && path_created_check && path_signal_emitted == false):
		if enable_path_visualization:
			debug_navigation_path(global_astar)
		path_signal_emitted = true
		on_path_creation.emit(created_path)
	
	if global_astar != null && global_grid.is_empty() == false:
		
		while path_creation_requests.is_empty() == false:
			calculate_nav_path(path_creation_requests[0], path_creation_listeners[0])
			
		while path_creation_jobs.is_empty() == false:
			
			var job : PathJob = path_creation_jobs[0]
			if job.result.is_empty() == false:
				if(job.result == PackedVector3Array([Vector3(-999,-999,-999)])):
					path_creation_jobs.pop_front()
				if(job.listener != null):
					#for x in range(len(job.result)):
						#job.result[x] += global_transform.origin
					job.listener.recieve_path(job.result)
				path_creation_jobs.pop_front()
			
		#calculate_nav_path(path_creation_requests[0], path_creation_listeners[0])
	
	pass

# ANode represents each point in the NavGrid; we use the A* algorithm to find a path on it.
class ANode:
	var parent : ANode
	var position : Vector3
	var g := 0
	var h := 0
	var f := 0
	var id := 0
	func _init(par, pos, i):
		parent = par
		position = pos
		id = i

# Heap class for optimizing the A* algorithm.
class MinHeap: 
	var maxsize := 0 
	var size := 0
	var heap := Array([])
	var FRONT := 1
	
	func _init(max):
		maxsize = max
		heap.resize(max + 1)
		#heap[0] = -2147483646 
  
	func get_parent(pos): 
		return max(1, floor(float(pos)/2))
  
	func get_left(pos): 
		return 2 * pos 

	func get_right(pos): 
		return (2 * pos) + 1

	func is_leaf(pos): 
		return pos*2 > size 

	func swap(fpos, spos): 
		var temp = heap[fpos]
		heap[fpos] = heap[spos]
		heap[spos] = temp 

	func min_heapify(pos): 
		# If not a leaf node and pos > left and pos > right
		if not self.is_leaf(pos): 
			if (gt(pos, get_left(pos)) > 0 or gt(pos, get_right(pos)) > 0): 
				if gt(get_right(pos), get_left(pos)) > 0: 
					swap(pos, get_left(pos)) 
					min_heapify(get_left(pos)) 
				else: 
					swap(pos, get_right(pos)) 
					min_heapify(get_right(pos)) 
  
	func insert(element : ANode): 
		if size >= maxsize: 
			return
		size += 1
		heap[size] = element 
		var current = size 
		if heap[get_parent(current)] is ANode && heap[current] is ANode:
			while gt(get_parent(current), current) > 0:
				swap(current, get_parent(current)) 
				current = get_parent(current)
  
	func min_heap(): 
		for pos in range(floor(float(size)/2), 0, -1): 
			min_heapify(pos) 

	func contains(element):
		return heap.has(element)

	func gt(fpos, spos):
		if heap[fpos].f > heap[spos].f:
			return 1
		if heap[fpos].f <= heap[spos].f:
			return 0
  
	func pop(): 
		if heap[FRONT] == null:
			for x in range(len(heap)):
				print(heap[x])
		var popped = heap[FRONT] 
		heap[FRONT] = heap[size] 
		size-= 1
		min_heapify(FRONT) 
		return popped 


## INTERNAL FUNCTION: get point path in c++ using [NavGridPathFinder] if it is available.
func get_point_path_finder(astar : AStar3D, start_point : int, end_point : int, listener : NavGridAgent):
	var res = nav_grid_path_finder.get_point_path_cpp(astar, start_point, end_point)
	path_created_check = true
	created_path = res
	update_job(listener, res)

## INTERNAL FUNCTION: get point path in gdscript.
func get_point_path(astar : AStar3D, start_pos : Vector3, end_pos : Vector3, listener : NavGridAgent, heap_optimization : bool):
	# Sebastian Lague A* playlist: https://www.youtube.com/playlist?list=PLFt_AvWsXl0cq5Umv3pMC9SPnKjfp9eGW
	# A* Algorithm: https://medium.com/@nicholas.w.swift/easy-a-star-pathfinding-7e6689c7f7b2
	# A* Algorithm + Min Heap: https://yuminlee2.medium.com/a-search-algorithm-42c1a13fcf9f
	# Min Heap: https://www.geeksforgeeks.org/min-heap-in-python/
	
	# Create start and end node)
	var start_node = ANode.new(null, start_pos, astar.get_closest_point(start_pos))
	var end_node = ANode.new(null, end_pos, astar.get_closest_point(end_pos))
	
	var open_list = Array([])
	var closed_list = Array([])
	
	# Add the start node
	open_list.append(start_node)
	
	#print("astar LOOP")
	
	if heap_optimization:
		
		var open_list_heap = MinHeap.new(x_size * y_size * z_size)
		open_list_heap.insert(start_node)
		open_list_heap.insert(start_node)
		var broke = false
		
		while open_list_heap.heap.is_empty() == false:
			#print(open_list_heap.size)

			var current_node = open_list_heap.pop()
			if current_node is int:
				break
			closed_list.append(current_node.position)
			
			# check if current is the target node
			if current_node.id == end_node.id: #current_node.position == end_node.position:
				var path := PackedVector3Array([]) 
				var current = current_node
				while current != null:
					path.append(current.position)
					current = current.parent
				path.reverse()
				path_created_check = true
				created_path = path
				update_job(listener, path)
				return
				#return path
				#break

			var children = Array()
			var point_arr = astar.get_point_connections(astar.get_closest_point(current_node.position))
			
			#print(current_node.position)
			for point_index in point_arr: # Adjacent squares
				#new_position = astar.get_point_position(point_index)
				
				# Get node position
				var node_position = astar.get_point_position(point_index) #new_position
				
				# Create new node
				var new_node = ANode.new(current_node, node_position, point_index)

				# Append
				children.append(new_node)

			# Loop through children
			for child in children:
				var check_x = false
				
				if check_x == false:
					# Create the f, g, and h values
					child.g = current_node.g + child.position.distance_to(current_node.position)
					child.h = child.position.distance_to(end_node.position) #((child.position[0] - end_node.position[0]) ** 2) + ((child.position[1] - end_node.position[1]) ** 2)
					child.f = child.g + child.h

					# Child is already in the open list
					for open_node in open_list_heap.heap:
						if open_node is ANode:
							#if (child.position.distance_to(open_node.position) < ((local_scale.y * voxel_grid_scale)/2) and child.g > open_node.g ):
							if child.id == open_node.id:
								check_x = true
								break

					if check_x == false:
						# Add the child to the open list
						if closed_list.has(child.position) == false:
							open_list_heap.insert(child)
						
			
		path_created_check = true
		created_path = PackedVector3Array([])
		update_job(listener, PackedVector3Array([Vector3(-999,-999,-999)]))
		return
		#return PackedVector3Array([])


	# Loop until you find the end
	while len(open_list) > 0:
		# Get the current node
		var current_node = open_list[0]
		var current_index = 0
		for index in range(len(open_list)):
			var item = open_list[index]
			if item.f < current_node.f:
				current_node = item
				current_index = index

		# Pop current off open list, add to closed list
		open_list.pop_at(current_index)
		closed_list.append(current_node)

		# Found the goal
		if current_node.position == end_node.position:
			var path := PackedVector3Array([]) 
			var current = current_node
			while current != null:
				path.append(current.position)
				current = current.parent
			path.reverse()
			path_created_check = true
			created_path = path
			update_job(listener, path)
			return
			#return path # Return reversed path


		# Generate children
		var children = Array()
		#for new_position in tmp_Arr: # Adjacent squares
		
		var point_arr = astar.get_point_connections(astar.get_closest_point(current_node.position))
		#var new_position := Vector3()
		
		for point_index in point_arr: # Adjacent squares
			#new_position = astar.get_point_position(point_index)

			# Get node position
			var node_position = astar.get_point_position(point_index) #new_position #current_node.position + new_position

			# Create new node
			var new_node = ANode.new(current_node, node_position, point_index)

			# Append
			children.append(new_node)

		# Loop through children
		for child in children:
			
			var check_x = false
			# Child is on the closed list
			for closed_child in closed_list:
				if child == closed_child:
					check_x = true
					break
			
			if check_x == false:
				# Create the f, g, and h values
				child.g = current_node.g + child.position.distance_to(current_node.position)
				child.h = child.position.distance_to(end_node.position) #((child.position[0] - end_node.position[0]) ** 2) + ((child.position[1] - end_node.position[1]) ** 2)
				child.f = child.g + child.h

				# Child is already in the open list
				for open_node in open_list:
					if child == open_node and child.g > open_node.g:
						check_x = true
						break

				if check_x == false:
					# Add the child to the open list
					open_list.append(child)
		
		# Error checking
		if closed_list.size() > (x_size * y_size * z_size * 10):
			break
			
	path_created_check = true
	created_path = PackedVector3Array([])
	update_job(listener, PackedVector3Array([Vector3(-999,-999,-999)]))
	return

## INTERNAL FUNCTION: called when a path has been calculated.
func update_job(listener : NavGridAgent, result : PackedVector3Array):
	for x in range(len(path_creation_jobs)):
		if path_creation_jobs[x].listener == listener:
			path_creation_jobs[x].result = result


