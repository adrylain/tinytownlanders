extends Camera3D

@export var cameraSpeed: float = 30.0
@export var cameraRotateSpeed: float = 0.005

var rotating: bool = false

#signal for main menu/pause camera mode, where no input happens and the camera rotates around the island
signal setMenuMode #signal to set menu state. called by UI
var menuMode = false #if we are currently in a menu
signal endMenuMode

#also a transition, 20 frames or so, where we lerpf to the pivot point position
#and the point pivots towards us
var menuTransition = false #bool for if we are transitioning
var menuTransitionTimer = 0 #frame counter for time in transition
var gameTransition = false #used
var transitionLength = 60 #frame counter for transitions. causes jerk when below 45
var rotationSpeed2 = .1 #odd bit used to slow down rotation speed

func _process(delta):
	if not menuMode: #dont accept input in menu mode
		
		var move_vector = Vector3.ZERO

		var forward = -global_transform.basis.z
		var right = global_transform.basis.x
		forward.y = 0
		right.y = 0
		forward = forward.normalized()
		right = right.normalized()

		if Input.is_key_pressed(KEY_W):
			move_vector += forward * cameraSpeed * delta
		if Input.is_key_pressed(KEY_S):
			move_vector -= forward * cameraSpeed * delta
		if Input.is_key_pressed(KEY_D):
			move_vector += right * cameraSpeed * delta
		if Input.is_key_pressed(KEY_A):
			move_vector -= right * cameraSpeed * delta

		global_transform.origin += move_vector

		if Input.is_key_pressed(KEY_Q):
			rotation.y += cameraRotateSpeed * 4
		if Input.is_key_pressed(KEY_E):
			rotation.y -= cameraRotateSpeed * 4
	
		if gameTransition:
			menuTransitionTimer -= 1
			if menuTransitionTimer <= 0: #end transition state at time = 0
				gameTransition = false
			else:
				global_position.x = lerpf(global_position.x, $"../camPivot/pnt".global_position.x, .08)
				global_position.y = lerpf(global_position.y, $"../camPivot/pnt".global_position.y, .08)
				global_position.z = lerpf(global_position.z, $"../camPivot/pnt".global_position.z, .08)
				rotation.y = lerpf(rotation.y, $"../camPivot".rotation.y, .08)
				#also still rotate the pivot bit
				rotationSpeed2 = lerpf(rotationSpeed2, 0, .08)
				$"../camPivot".rotation.y += rotationSpeed2  * delta
	
	else: #when not accepting input
		if menuTransition: #if we are still in the transition, do that
			menuTransitionTimer -= 1
			if menuTransitionTimer <= 0: #end transition state at time = 0
				menuTransition = false
				$"../camPivot/pnt".global_position = self.global_position
			else:
				#keep in mind pivot is at origin so pnt position is global #also we are always at y +20
				global_position.x = lerpf(global_position.x, $"../camPivot/pnt".global_position.x, .08)
				global_position.y = lerpf(global_position.y, $"../camPivot/pnt".global_position.y, .08)
				global_position.z = lerpf(global_position.z, $"../camPivot/pnt".global_position.z, .08)
				rotation.y = lerpf(rotation.y, $"../camPivot".rotation.y, .08)
				#also still rotate the pivot bit
				$"../camPivot".rotation.y += .1 * delta
	
		else: #when not transitioning, rotate normally
			$"../camPivot".rotation.y += .1 * delta
			rotation.y += .1 * delta
			global_position = $"../camPivot/pnt".global_position
		

func _input(event):
	if not menuMode: #dont accept input when in menu mode
		
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_RIGHT:
				rotating = event.pressed

		if rotating and event is InputEventMouseMotion:
			var mouse_delta = event.relative
			global_transform.basis = global_transform.basis.rotated(Vector3.UP, -mouse_delta.x * cameraRotateSpeed)

#for use when the main menu is active
#locks the cameras position and rotation to the pivot
func _set_menu_mode() -> void:
	
	menuMode = true
	menuTransition = true
	menuTransitionTimer = transitionLength
	#when setting menu mode, rotate the pivot correctly
	$"../camPivot".rotation.y = Vector2(1,0).angle_to(Vector2(global_position.x, global_position.z))

func _end_menu_mode() -> void:
	
	menuMode = false
	menuTransitionTimer = transitionLength
	gameTransition = true
	rotationSpeed2 = .1
	$"../camPivot".rotation.y = Vector2(1,0).angle_to(Vector2(global_position.x, global_position.z))
