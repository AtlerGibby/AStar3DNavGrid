extends CharacterBody3D

## The NavGrid to query for path finding.
@export var ai_manager : NavGrid
## The Goal.
@export var targets : Node3D

var nav_agent : NavGridAgent
var current_step := 0
var my_path : PackedVector3Array
var space : PhysicsDirectSpaceState3D
var up_target : Vector3
var fwd_target : Vector3
var current_destination := 0
var timer_count_down := false

signal npc_test_signal


# Called when the node enters the scene tree for the first time.
func _ready():
	nav_agent = get_node("CollisionShape3D/NavGridAgent")
	nav_agent.on_path_received.connect(path_received)
	get_node("Timer").timeout.connect(self.get_destination)
	get_node("Timer").start(1)
	
	space = PhysicsServer3D.space_get_direct_state(get_world_3d().get_space())

func path_received(path : PackedVector3Array):
	my_path = path
	current_step = 0
	#for step in path:
	#	print(step)
	pass

func get_destination():
	timer_count_down = false
	nav_agent.subscribe_for_path(ai_manager, position, targets.get_child(current_destination).position)
	current_destination += 1
	if current_destination >= targets.get_child_count():
		current_destination = 0
	get_node("Timer").stop()


func _physics_process(delta):
	
	if ai_manager.type_of_navigation == 1:
		var parameters = PhysicsRayQueryParameters3D.new()
		parameters.collide_with_areas = false
		parameters.collide_with_bodies = true
		parameters.collision_mask = collision_mask
		parameters.to = basis.y * -2 + velocity + position
		parameters.from = position
		var result : Dictionary
		result = space.intersect_ray (parameters)
		
		fwd_target = lerp(fwd_target, position + velocity, delta * 5)
		if result.has("normal"):
			up_target = lerp(up_target, result.normal, delta * 5)
		
		if velocity != Vector3.ZERO:
			look_at(fwd_target, up_target)
		
		parameters.to = basis.y * -2 + position
		parameters.from = position
		result = space.intersect_ray (parameters)
		
		if result.has("position"):
			get_child(0).get_child(0).position.y = result.position.distance_to(global_position) * -1 + 1
	
	if my_path.is_empty() == false:
		if my_path[0] != Vector3(-999, -999, -999):
			if position.distance_to(my_path[current_step]) > 0.5:
				velocity = position.direction_to(my_path[current_step]) * 100 * delta
			elif current_step < len(my_path) - 1:
				current_step += 1
			else:
				velocity = Vector3.ZERO
				if timer_count_down == false:
					get_node("Timer").start(1)
					timer_count_down = true
				
	move_and_slide()
