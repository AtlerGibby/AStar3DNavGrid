extends Camera3D

@export_range(0.0, 1.0) var sensitivity: float = 0.25
@export_range(0.0, 100.0) var speed: float = 20

# Mouse state
var _mouse_position = Vector2(0.0, 0.0)
var _total_pitch = 0.0
var forward = 0
var backward = 0
var left = 0
var right = 0
var up = 0
var down = 0
var extra_speed = 0
var move = Vector3.ZERO

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	

	move = Vector3((right as float) - (left as float),
	(up as float) - (down as float),
	(backward as float) - (forward as float))
	move = move.normalized()
	translate(move * delta * speed * (2 * ((extra_speed as float) + 1)))

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		_mouse_position *= sensitivity
		var yaw = _mouse_position.x
		var pitch = _mouse_position.y
		_mouse_position = Vector2(0, 0)
		
		# Prevents looking up/down too far
		pitch = clamp(pitch, -90 - _total_pitch, 90 - _total_pitch)
		_total_pitch += pitch

		rotate_y(deg_to_rad(-yaw))
		rotate_object_local(Vector3(1,0,0), deg_to_rad(-pitch))
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	pass



func _input(event):
	
	if event is InputEventKey:
		match event.keycode:
			KEY_W:
				forward = event.pressed
			KEY_S:
				backward = event.pressed
			KEY_A:
				left = event.pressed
			KEY_D:
				right = event.pressed
			KEY_SPACE:
				up = event.pressed
			KEY_CTRL:
				down = event.pressed
			KEY_SHIFT:
				extra_speed = event.pressed

	# Receives mouse motion
	if event is InputEventMouseMotion:
		_mouse_position = event.relative
