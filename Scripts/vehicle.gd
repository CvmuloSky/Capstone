extends VehicleBody3D

# Constants and variables
const MAX_STEER = 0.8
const ENGINE_POWER = 1000
var normal_friction_slip = 1.0
var backwheeldrift = 0.8
var frontwheeldrift = 0.9 
var target_back_friction = normal_friction_slip
var target_front_friction = normal_friction_slip
var speed = 0
var finished = false
var start = false
var current_lap = 0
var checkpoints := []
var total_laps = 2
@onready var camera_pivot = $CameraPivot
@onready var camera_3d = $CameraPivot/Camera
@onready var reverse_camera = $CameraPivot/ReverseCamera
@onready var backLeft_wheel = $"Back Left"
@onready var frontRight_wheel = $"Front Right"
@onready var backRight_wheel = $"Back Right"
@onready var frontLeft_wheel = $"Front Left"
@onready var timer = $"../UI/timer"


var time_elapsed = 0
var look_at
var finish_camera_position = null
var finish_camera_rotation = null
var finish_camera_basis = null

var drift_trail_scene = preload("res://Scripts/drift_trail.gd")
var left_trail: Node3D = null
var right_trail: Node3D = null
var trail_update_timer: float = 0.0
const TRAIL_UPDATE_INTERVAL: float = 0.05  #

func _ready() -> void:
	checkpoints.resize(45)
	checkpoints.fill(false)
	add_to_group("player") 
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	look_at = global_position

func _physics_process(delta: float) -> void:
	speed = linear_velocity.length() * 3.6  
	
	if start and not finished:
		var steer_input = Input.get_axis("move_right", "move_left")
		var steer_target = steer_input * MAX_STEER * (1 - abs(steer_input) * 0.5)
		steering = move_toward(steering, steer_target, delta * 20 * 4)
		engine_force = Input.get_axis("move_forward", "move_backwards") * ENGINE_POWER

		if Input.is_action_pressed("brake"):
			brake = 20
		else:
			brake = 0
	else:
		if finished:
			#print(checkpoints)
			brake = 1000
	
	if not finished:
		camera_pivot.global_position = camera_pivot.global_position.lerp(global_position, delta * 20.0)
		camera_pivot.transform = camera_pivot.transform.interpolate_with(transform, delta * 5.0)
		look_at = look_at.lerp(global_position + linear_velocity, delta * 5.0)
	else:
		if finish_camera_position != null:
			camera_pivot.global_position = finish_camera_position
			
			if finish_camera_basis != null:
				camera_pivot.global_basis = finish_camera_basis
	
	if not finished:  
		_check_camera_switch()
		if Input.is_action_just_pressed("flip_vehicle"):
			_flip_vehicle()
		if Input.is_action_pressed("is_drifting"):
			_drift()
			_update_drift_trails(delta)
		else:
			_stop_drift()
			_clear_drift_trails()
	if not start:
		brake = 100000

	backLeft_wheel.wheel_friction_slip = lerp(backLeft_wheel.wheel_friction_slip, target_back_friction, delta * 10)
	backRight_wheel.wheel_friction_slip = lerp(backRight_wheel.wheel_friction_slip, target_back_friction, delta * 10)
	frontLeft_wheel.wheel_friction_slip = lerp(frontLeft_wheel.wheel_friction_slip, target_front_friction, delta * 10)
	frontRight_wheel.wheel_friction_slip = lerp(frontRight_wheel.wheel_friction_slip, target_front_friction, delta * 10)

	var surface_friction = 1.0 if not is_on_grass() else 0.7
	for wheel in [backLeft_wheel, backRight_wheel, frontLeft_wheel, frontRight_wheel]:
		wheel.wheel_friction_slip *= surface_friction

	var anti_roll_torque = -angular_velocity.z * 1000
	apply_torque(Vector3(0, 0, anti_roll_torque))

	time_elapsed += delta
	if (Input.is_action_just_pressed("move_forward") || Input.is_action_just_pressed("move_backwards") || Input.is_action_just_pressed("move_left") || Input.is_action_just_pressed("move_right")) && time_elapsed > 3:
		start = true

func _drift():
	backLeft_wheel.wheel_friction_slip = backwheeldrift
	backRight_wheel.wheel_friction_slip = backwheeldrift
	frontRight_wheel.wheel_friction_slip = frontwheeldrift
	frontLeft_wheel.wheel_friction_slip = frontwheeldrift
	
	if not left_trail:
		left_trail = drift_trail_scene.new()
		get_parent().add_child(left_trail)
	if not right_trail:
		right_trail = drift_trail_scene.new()
		get_parent().add_child(right_trail)

func _stop_drift():
	backLeft_wheel.wheel_friction_slip = normal_friction_slip
	backRight_wheel.wheel_friction_slip = normal_friction_slip
	frontRight_wheel.wheel_friction_slip = normal_friction_slip
	frontLeft_wheel.wheel_friction_slip = normal_friction_slip

func _clear_drift_trails():
	if left_trail:
		left_trail.queue_free()
		left_trail = null
	if right_trail:
		right_trail.queue_free()
		right_trail = null

func _update_drift_trails(delta: float) -> void:
	trail_update_timer += delta
	if trail_update_timer >= TRAIL_UPDATE_INTERVAL:
		trail_update_timer = 0.0
		
		if left_trail:
			left_trail.add_point(backLeft_wheel.global_position)
		if right_trail:
			right_trail.add_point(backRight_wheel.global_position)

func _fix_stuck():
	var transform = global_transform
	transform.origin.x += 5*reverse_camera.position
	transform.origin.y += 5
	transform.basis = Basis()
	global_transform = transform

func _check_camera_switch():
	if Input.is_action_just_pressed("perspective_change"):
		if camera_3d.current == true:
			reverse_camera.current = true
		else:
			camera_3d.current = true
func _flip_vehicle():
	if is_upside_down():
		var transform = global_transform
		transform.origin.y += 1.5
		transform.basis = Basis()
		global_transform = transform

func is_upside_down() -> bool:
	var up_vector = global_transform.basis.y.normalized()
	return up_vector.dot(Vector3(0, 1, 0)) < 0.5

func is_on_grass() -> bool:
	return false 

func _on_Player_body_entered(body):	
	var bodyName = body.getName()
	if bodyName == "Finishline":
		finished = true
		print("Finished!!!")

# Get the vehicle's speed
func _getSpeed() -> float:
	return linear_velocity.length()

# This function is called from the finish line script through the race_finished signal
func finish_race():
	finished = true
	# Store current camera position and rotation to keep it fixed
	finish_camera_position = camera_pivot.global_position
	finish_camera_rotation = camera_pivot.rotation
	finish_camera_basis = camera_pivot.global_basis
	print("Vehicle marked as finished!")
	timer.stop()
	# Show mouse cursor when race is finished
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func add_lap():
	current_lap += 1
	print("Lap completed! Current lap: ", current_lap, " / ", total_laps)
	if current_lap >= total_laps:
		finish_race()

func subtract_lap():
	current_lap -= 1
	print("Lap subtracted! Current lap: ", current_lap, " / ", total_laps)

func get_current_lap() -> int:
	return current_lap

func get_total_laps() -> int:
	return total_laps
	

func setCheckpoint(i: int) -> void:
	if i >= 0 and i < checkpoints.size():
		checkpoints[i-1] = true
		print(i-1)
	else:
		push_error("Checkpoint index out of bounds: " + str(i))
