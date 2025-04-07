extends Node2D
var rotationSpeed = 180
var timer = 0
func _process(delta):
	$SubViewport/Node3D/buildings.rotation_degrees.y += rotationSpeed * delta
	timer += 1
	if timer == 61:
		get_tree().quit()
