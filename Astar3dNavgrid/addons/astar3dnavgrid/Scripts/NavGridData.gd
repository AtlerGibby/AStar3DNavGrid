## Stores pregenerated AStar3D data for [NavGrid].
@icon("res://addons/astar3dnavgrid/Art/AStarIcon.png")
extends Resource
class_name NavGridData

@export var astar_ids : PackedInt64Array
@export var astar_cons : Array[PackedInt64Array]
@export var astar_positions : PackedVector3Array
@export var grid_save : PackedByteArray
