## Connects two different locations in a [NavGrid].
@icon("res://addons/astar3dnavgrid/Art/NavGridLinkIcon.png")
extends Node3D
class_name NavGridLink

## The end point of this NavGridLink, local to this node.
@export var to_pos := Vector3(0, 2, 0)

## The directionality of this link. 
## BI_DIRECTIONAL: Can go both ways.
## START_TO_END: only start to end. 
## END_TO_START: only end to start.
@export_enum("BI_DIRECTIONAL", "START_TO_END", "END_TO_START") var directionality: int = 0

## transform.orgin 
var start := Vector3.ZERO
## to_pos * transform.inverse()
var end := Vector3.ZERO

# Called when the node enters the scene tree for the first time.
func _ready():
	start = transform.origin
	end = to_pos * transform.inverse()
