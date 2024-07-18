@tool
extends EditorPlugin

const NavGridGizmoPlugin = preload("res://addons/astar3dnavgrid/Scripts/NavGridGizmo.gd")
const NavLinkGizmoPlugin = preload("res://addons/astar3dnavgrid/Scripts/NavGridLinkGizmo.gd")
var grid_gizmo_plugin = NavGridGizmoPlugin.new()
var link_gizmo_plugin = NavLinkGizmoPlugin.new()
var undo_redo = get_undo_redo()

func _enter_tree():
	# Initialization of the plugin goes here.
	grid_gizmo_plugin.undo_redo = undo_redo
	link_gizmo_plugin.undo_redo = undo_redo
	add_node_3d_gizmo_plugin(grid_gizmo_plugin)
	add_node_3d_gizmo_plugin(link_gizmo_plugin)
	pass


func _exit_tree():
	# Clean-up of the plugin goes here.
	remove_node_3d_gizmo_plugin(grid_gizmo_plugin)
	remove_node_3d_gizmo_plugin(link_gizmo_plugin)
	pass
