## Used to interface with [NavGrid] for subscribing to paths.
@icon("res://addons/astar3dnavgrid/Art/NavGridAgentIcon.png")
extends Node3D
class_name NavGridAgent

## The current path is updated after a subscribed path is recieved.
var current_path : PackedVector3Array

## Emitted when a path subscribed for has been received.
signal on_path_received(path : PackedVector3Array)


## Queues this [NavGridAgent] to receive a path between 2 points from a NavGrid.
func subscribe_for_path(manager : NavGrid, start : Vector3, end : Vector3):
	manager.subscribe_for_path(self, start, end)

## Function for recieving a path from a [NavGrid].
func recieve_path(path : PackedVector3Array):
	current_path = path
	on_path_received.emit(path)
