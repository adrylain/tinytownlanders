extends Node3D

#this script just acts as data storage for each cube
#could also have location references to the top of each gridcube, so we can snap buildings to the top of the cube and whatnot
#most of my code comments are full blown diaries so I'll try to stop that habit

#functions to update collision and visibility
signal remove
signal add
#signal to get the indexes of neighboring map bits
signal getNeighbors
var neighborIdxArray = Array([9], TYPE_INT, "", null) #allows acess to indexes of neighboring cells
#signal for setting height
signal setHeight
#and adding building
signal addBuilding
#signal to look natural
signal addDecor

#bool needed for cellular automota map generation
var futureHeight = 0


#stored data -> saved to file(idx, buildingType, height, hasWater)
var buildingType = "null" #building type corresponding to this gridcubes
var idx = 0 #index within the massive list of gridcubes
#stored positional data
var mapCoord = Vector2(0,0)
var mapSize = Vector2(0,0)
var mapHeight = 0
var height = 0 #range from self to map height, in map grid form
var isTop = false #bools for if the is on the top/bottom/side layers
var isFloor = false
var isSide = false
var isVisible = true #and tracking visibility
var hasWater = false #if this is part of a river
var flowDirection = Vector4i(0,0,0,0) #flows from 1 to 2
#used for decorations
var decorIdx = 0
var coinFlip

#used for shape updates
signal changeCubeState
var sideTotal = 0 #total neighboring sides that connect via river
var sideOffset = 0 #0-3 int for 90 degree offsets to rotate the top mesh bu
var subCube = 0 #used to affect and update lower cubes than the top
var divisionToEdit = "topCase" #used to identify what part of the cube to update
var parentArray #used to duplicate the correct array from the parent
signal rotateVector #signal for testing rotated vector
var storageVector = Vector4i(0,0,0,0)
var outputVector = Vector4i(0,0,0,0)
var caseNum = 0
var mustRotate = false #if this particular update requires rotation of the cube
var baseOffset = Vector4(0,0,0,0) #used to compare the placeholder rotation to the intended rotation
#and river specific sttuff
var riverDirection1 = Vector4i(0,0,0,0)
var riverDirection2 = Vector4i(0,0,0,0)
var riverIdx = -1 #used to track number of rivers so they can overlap

#also we may have some edgecases invlving 2-tall cliffs. deal with those via relative height checks on neighbor updates

#we gotta get this subtraction part down and useful for a variety of reasons
#top and bottom versions 
#none through 4 open sides with open or closed centers. also ring
#and just make all of those 2 high as well
#so U,L,T,O, so O,U,L,I,1x1, all of those in height 2, with a 2x for each top

#ideally, we have a list of all possible meshes to add to a given cube
#meshes will need color varaiants
#and we can just pass those instances to a cube?

#have all possible cube variants, split top and bottom, and switch em out
#then just rotate whatever it is we need

#alright also we gotta do water
#for now - rivers cannot split and only go one at a time
#each top gridcube has a full sized water colored bit


func _on_remove():
	isVisible = false
	#self.visible = false
	for subNode in self.get_children():
		subNode.visible = false
	#$StaticBody3D.set_collision_layer_value(1, false)


func _on_add():
	isVisible = true
	#self.visible = true
	for subNode in self.get_children():
		subNode.visible = true
	$GPUParticles3D.visible = false
	#$GPUParticles3D2.visible = false
	riverDirection1 = Vector4i(0,0,0,0)
	riverDirection2 = Vector4i(0,0,0,0)
	riverIdx = -1
	#$StaticBody3D.set_collision_layer_value(1, true)


#set height of this cube on the map
func _on_set_height(idx):
	height = idx
	if height > mapHeight:
		height = mapHeight
	elif height < 0:
		height = 0
	
	self.position.y = 0 + $"..".cubeSize.y * height
	
	for subCube in $submeshes.get_child_count():
		$submeshes.get_child(subCube).visible = false
	
	for subCube in height + 1:
		$submeshes.get_child(subCube).visible = true
	
	#set top or bottom status
	if height == mapHeight:
		isTop = true
	elif height == 0:
		isFloor = true

##TODO TODO this is an importnat thing to do
#adds a building to at this point. name is a string for the building name
#call this from any script by using addBuilding.emit("buildingName")
#this needs to add a mesh (any placeholder for now) on top of this cube
#and replace that mesh with a different one when called again
#if buldingName = "null", remove the placeholder

#dont be afraid to mess around with the position.xyz of the mesh
#also update the builingType sting on this cube
func _on_add_building(buildingName):
	#clear buildings
	for existingDecor in $decor1.get_children():
		existingDecor.free()
	for existingDecor in $decor2.get_children():
		existingDecor.free()
	for existingBuilding in $building.get_children():
		existingBuilding.free()
	
	#add building models
	$building.add_child($"../../placeholders/buildings".get_node(buildingName).duplicate())
	$building.get_child(0).position = Vector3(0,0,0)
	$building.visible = true
	if buildingName == "null":
		addDecor.emit()
	elif buildingName == "Mine":
		changeCubeState.emit(Vector4i(5,0,0,0), 1, 0)
		changeCubeState.emit(Vector4i(5,0,0,0), 0, 0)
		if $"..".get_child(neighborIdxArray[1]).height == height + 1:
			if not $"..".get_child(neighborIdxArray[1]).hasWater:
				$"..".get_child(neighborIdxArray[1]).changeCubeState.emit(Vector4i(0,0,0,1), 0, 0)
		if $"..".get_child(neighborIdxArray[2]).height == height + 1:
			if not $"..".get_child(neighborIdxArray[2]).hasWater:
				$"..".get_child(neighborIdxArray[2]).changeCubeState.emit(Vector4i(0,0,1,0), 0, 0)
		if $"..".get_child(neighborIdxArray[3]).height == height + 1:
			if not $"..".get_child(neighborIdxArray[3]).hasWater:
				$"..".get_child(neighborIdxArray[3]).changeCubeState.emit(Vector4i(0,1,0,0), 0, 0)
		if $"..".get_child(neighborIdxArray[4]).height == height + 1:
			if not $"..".get_child(neighborIdxArray[4]).hasWater:
				$"..".get_child(neighborIdxArray[4]).changeCubeState.emit(Vector4i(1,0,0,0), 0, 0)
	

func _on_add_decor():
	pass #$"../../placeholders/decor2/tree"
	
	if not self.hasWater:
		decorIdx = randi_range(0,6) ##TODO this size and and value is used in a bunch of spots here
		coinFlip = randi_range(0,1)
		if decorIdx <= 2:
			if not height == 1:
				$decor1.add_child($"../../placeholders/decor2/tree".duplicate())
				$decor1.get_child(0).position.x = randf_range(0,2)
				$decor1.rotation_degrees.y = randi_range(0,359)
				
				$decor2.add_child($"../../placeholders/decor2/tree".duplicate())
				$decor2.get_child(0).position.x = randf_range(0,2)
				$decor2.rotation_degrees.y = $decor1.rotation_degrees.y + (30 * decorIdx)
				
		elif decorIdx == 3:
			if coinFlip == 0:
				$decor1.add_child($"../../placeholders/decor2/rock1".duplicate())
				$decor1.get_child(0).position.x = randf_range(0,1)
				$decor1.rotation_degrees.y = randi_range(0,359)
			else:
				$decor1.add_child($"../../placeholders/decor2/rock2".duplicate())
				$decor1.get_child(0).position.x = randf_range(0,1)
				$decor1.rotation_degrees.y = randi_range(0,359)
		elif decorIdx == 4:
			pass
		elif decorIdx == 5:
			pass
		elif decorIdx == 6:
			pass


#this function serves to update the states of each part of the cube
#sides is a vector4 for which parts are connected to the center +x-x+y-y #4 xjunction 0 flat 5hole
#division is top or bottom 1 or 0 #and height is the affected cube from 0 down
#1-flat 2-straight 3-curve 4-Tjunction 5-allOpen 6-Ujunction 7-hole
func _on_change_cube_state(sides, division, subHeight):
	
	#get child and division to edit, then the parent array
	subCube = $submeshes.get_child(subHeight)
	if division == 1:
		divisionToEdit = "topCase"
		if not subHeight == 0: #cliff color top
			parentArray = $"..".topMeshArray3
		else:
			if height == 1: #color 2 top
				parentArray = $"..".topMeshArray2
			else: #color 1 top
				parentArray = $"..".topMeshArray
	else:
		divisionToEdit = "bottomCase"
		parentArray = $"..".bottomMeshArray
	#the get total neighbors with water
	sideTotal = sides.x + sides.y + sides.z + sides.w
	
	
	#then case. can also add side offsets if we want
	if sideTotal == 0:
		pass #case1
		subCube.get_node(divisionToEdit).get_child(0).mesh = parentArray[0]
		caseNum = 1
	elif sideTotal == 2:
		if ((sides.x + sides.y) == 2) or ((sides.z + sides.w) == 2):
			pass #case2
			subCube.get_node(divisionToEdit).get_child(0).mesh = parentArray[1]
			caseNum = 2
		else:
			pass #case3
			subCube.get_node(divisionToEdit).get_child(0).mesh = parentArray[2]
			caseNum = 3
	elif sideTotal == 1:
		pass #case6
		subCube.get_node(divisionToEdit).get_child(0).mesh = parentArray[5]
		caseNum = 6
	elif sideTotal == 3:
		pass #case4
		subCube.get_node(divisionToEdit).get_child(0).mesh = parentArray[3]
		caseNum = 4
	elif sideTotal == 4:
		pass #case5
		subCube.get_node(divisionToEdit).get_child(0).mesh = parentArray[4]
		caseNum = 5
	elif sideTotal == 5:
		pass #case7
		subCube.get_node(divisionToEdit).get_child(0).mesh = parentArray[6]
		caseNum = 7

	#now for side rotational offset #only needed in cases 2,3,4, and 6
	mustRotate = false
	if caseNum == 2:
		baseOffset = Vector4i(0,0,1,1)
		mustRotate = true
	elif caseNum == 3:
		baseOffset = Vector4i(0,1,0,1)
		mustRotate = true
	elif caseNum == 4:
		baseOffset = Vector4i(1,0,1,1)
		mustRotate = true
	elif caseNum == 6:
		baseOffset = Vector4i(0,0,0,1)
		mustRotate = true
	
	sideOffset = 0
	if mustRotate:
		if sides == baseOffset:
			sideOffset = 0
		rotateVector.emit(baseOffset)
		if sides == outputVector:
			sideOffset = 1
		rotateVector.emit(outputVector)
		if sides == outputVector:
			sideOffset = 2
		rotateVector.emit(outputVector)
		if sides == outputVector:
			sideOffset = 3

	
	#then rotate to match the correct sides
	subCube.get_node(divisionToEdit).get_child(0).rotation_degrees.y = 90 * sideOffset


#get the indexes of all neighboring cubes. called on startup, makes an array for the indexes of all neighboring cubes
func _on_get_neighbors() -> void:
	
	neighborIdxArray.resize(9)
	
	neighborIdxArray[0] = idx
	neighborIdxArray[1] = idx + 1
	neighborIdxArray[2] = idx - 1
	neighborIdxArray[3] = idx + mapSize.x
	neighborIdxArray[4] = idx - mapSize.x
	neighborIdxArray[5] = idx + mapSize.x + 1
	neighborIdxArray[6] = idx + mapSize.x - 1
	neighborIdxArray[7] = idx - mapSize.x + 1
	neighborIdxArray[8] = idx - mapSize.x - 1
	
	if mapCoord.x == mapSize.x - 1: #if we are at the max x value
		neighborIdxArray[3] = -1
		neighborIdxArray[5] = -1
		neighborIdxArray[6] = -1
		isSide = true
	elif mapCoord.x == 0: #if we are at the min x value
		neighborIdxArray[4] = -1
		neighborIdxArray[7] = -1
		neighborIdxArray[8] = -1
		isSide = true
	if mapCoord.y == mapSize.y - 1: #if we are at the max y value
		neighborIdxArray[1] = -1
		neighborIdxArray[5] = -1
		neighborIdxArray[7] = -1
		isSide = true
	elif mapCoord.y == 0: #if we are at the min y value
		neighborIdxArray[2] = -1
		neighborIdxArray[6] = -1
		neighborIdxArray[8] = -1
		isSide = true


func _on_rotate_vector(inputVector):
	#keep in mind +x -x +y -y -> to rotate, +y -y -x +x
	storageVector = inputVector

	outputVector.x = storageVector.z
	outputVector.y = storageVector.w
	outputVector.z = storageVector.y
	outputVector.w = storageVector.x
		
