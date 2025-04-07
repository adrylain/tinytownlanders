extends Node3D

#this script creates and manages a 3d grid of cubes
#based at the origin and increasing in the positive x,y,z
#should have a callable one here that, given an index, returns the neighboring cubes

@export var gridcube: PackedScene
@export var waterParticles: PackedScene

var cubeSize = Vector3(4,3,4)
var mapSize = Vector2i(18,18)
var mapHeight = 3
var mapCoord = Vector2i(0,0)
var currentMapCube #ndeo referecnce to the given map part we're doing stuff on

var idx

#getting neighbors of a specific index #array stored on each gridcube
signal getNeighbors
var mapIdx = 0 #index of the current voxel
var neighborIdxArray = Array([], TYPE_INT, "", null)

#general map generation
signal generateMap
signal smoothPass1 #smoothing function, needs 2 inputs for min and max, 0 < min < max < 9. 
signal roughPass1 #sets all parts to a random height
signal roughPass2 #adds random height to each, not as extreme
var totalNeighbors = 0
var totalNeighborsUp = 0
var currentHeight = 0
#perlin specific map generation
@export var noise_map = FastNoiseLite.new()
var rng
var midpoint
var ellipse_height
var perlin_height
var final_height

#signal that resets everything
signal reset

#color storage
signal colorPass
var div1
var div2
var color1Array = ["35335e", "40b36c", "ce502e", "e5e069", "623f59"]
var color2Array = ["4f4aa3", "a0d2d3", "b37540", "9f9c4a", "be90b2"]
var color3Array = ["c5b9d3", "628a8b", "776d6b", "5e5d46", "e7e6c9"]
var color4Array = ["448d7f", "30d7d9", "94a1be", "0b7080", "0b7080"]
var sky #reference tot the sky values
#references to meshes and materials for cube assignment
signal setColor
var colorSelect = 0 #int 0-4 for palette
#reference to a few materials
var material1 #top color 1
var material2 #top color 2
var material3 #cliff color
var material4 #and water color
var material5 #tree trunk
#reference arrays for all meshes we need to recolor
var topMeshArray = [] #top color 1
var topMeshArray2 = [] #top color 2
var topMeshArray3 = [] #top cliff color
var bottomMeshArray = [] #normal cliff color
var waterMeshArray = [] #and usual water values
var meshRef
var caseRef
#used for setting the states of rivers/water and updating cube shape accordingly
signal updateRivers
var neighborSides = Vector4i(0,0,0,0)
var neighborSides2 = Vector4i(0,0,0,0)

#input related stuff
var isCubeSelected = false #if the cursor is currently held over a cube
var selectedCubeIdx = 0 #idx of the hovered cube

func _ready():
	
	pass
	#the good ol double nested for loop
	
	mapCoord = Vector2(-1,-1)
	for sizeX in mapSize.x:
		mapCoord.y = -1
		mapCoord.x += 1
		for sizeY in mapSize.y:
			mapCoord.y += 1
			
			
			self.add_child(gridcube.instantiate()) #create a new instance of the "gridcube" scene
			#instancing a scene duplicates everything in that scene, such as the placeholder models and hitbox
			currentMapCube = self.get_child(-1) #get a reference to the most recently added child node
			
			currentMapCube.mapCoord = mapCoord
			currentMapCube.position.x += cubeSize.x * sizeX
			currentMapCube.position.z += cubeSize.z * sizeY

			
			idx = currentMapCube.get_index()
			#neighbor assignment
			currentMapCube.idx = idx #pass the index
			currentMapCube.mapSize = mapSize #and the map size
			currentMapCube.mapHeight = mapHeight #and the max height
			currentMapCube.getNeighbors.emit()
			

	#after generating the cubes, reset position so the origin is at the center
	self.position.x = -(mapSize.x * cubeSize.x * .5)
	self.position.z = -(mapSize.y * cubeSize.z * .5)

	#set the color an all the cubes
	#setColor.emit(2)


	#create new materials for updating
	material1 = StandardMaterial3D.new()
	material2 = StandardMaterial3D.new()
	material3 = StandardMaterial3D.new()
	material4 = StandardMaterial3D.new()
	material5 = StandardMaterial3D.new() #trunk color
	#then the signal for map generation
	generateMap.emit()


func _generate_map():
	
	#start by setting color meshes
	setColor.emit(randi_range(0,3))
	
	rng = RandomNumberGenerator.new()
	noise_map.seed = rng.randi_range(0, 500);
	
	#elipse 2x^2 + 2y^2 + z^2 = 12
	for mapCube in self.get_children():
		midpoint = int(mapCoord.x / 2)
		
		#Yes, I did this. Yes, it was painful. No, I don't care. You're welcome.
		ellipse_height = sqrt( 12 - (.25*((mapCube.mapCoord.x - midpoint)**2)) - (.25*((mapCube.mapCoord.y - midpoint)**2)) )
		if is_nan(ellipse_height):
			ellipse_height = 0
		ellipse_height = int(ellipse_height)
		
		perlin_height = noise_map.get_noise_2d(mapCube.mapCoord.x * 10,mapCube.mapCoord.y * 10)
		perlin_height = int(perlin_height * 5)
		
		final_height = ellipse_height - perlin_height
		#print(perlin_height)
		
		mapCube.setHeight.emit(final_height)
		#mapCube.setHeight.emit(ellipse_height)
		mapCube.add.emit()
		mapCube.hasWater = false
		
	
	roughPass2.emit()
	smoothPass1.emit(4,6)
	#smoothPass1.emit(4,6)
	#smoothPass1.emit(4,6)
	
	#ALWAYS CALL SET COLOR BEFORE COLOR PASS #it's called in ready
	#colorSelect = randi_range(0,4)
	colorPass.emit()
	
	updateRivers.emit()
	
	for mapCube in self.get_children():
		mapCube.addBuilding.emit("null")
	

func _smooth_pass_1(min, max):
	#smoothing function using cellular automota
	for mapIdx in self.get_child_count():
		totalNeighbors = 0
		totalNeighborsUp = 0
		currentMapCube = self.get_child(mapIdx)
		currentHeight = currentMapCube.height
		neighborIdxArray = currentMapCube.neighborIdxArray
		
		#check total visible neighbors
		#for the current layer, and the layer above
		for neighborIdx in 9:
			if not neighborIdxArray[neighborIdx] == -1:
				if self.get_child(neighborIdxArray[neighborIdx]).height >= currentHeight:
					totalNeighbors += 1
				if self.get_child(neighborIdxArray[neighborIdx]).height > currentHeight:
					totalNeighborsUp += 1
		
		#update cell based on visible neighbors
		#start by setting future state to current height
		currentMapCube.futureHeight = currentMapCube.height
		#then update future state based on current neighbors
		if totalNeighbors <= min: #if we currently have less than 4 neighbors, shrink
			currentMapCube.futureHeight -= 1
		if totalNeighborsUp >= max: #if the voxel above has more than 6, grow
			currentMapCube.futureHeight += 1
	
	
	#then set every voxel to it's assigned future state
	for mapCube in self.get_children():
		mapCube.setHeight.emit(mapCube.futureHeight)

func _rough_pass_1():
	for mapCube in self.get_children():
		mapCube.setHeight.emit(randi_range(0, mapHeight))

func _rough_pass_2():
	for mapCube in self.get_children():
		mapCube.setHeight.emit(mapCube.height + randi_range(0,1))

#this generates rivers and updates cubes to make them work
#updates the shape of each child mesh based on neighboring water states #uses cellular automota to do so
func _update_rivers():
	#generate rivers via directionality, start in the middle and work outwards
	#pick an initial direction
	var direction1vector = Vector2(0,0) #initial general river direction
	var direction2vector = Vector2(0,0)
	var currentIdx = 0 #current and next idx are all for river generation
	var currentCoord = Vector2(0,0)
	var nextIdx = 0
	var testCube #idk whatever
	var currentHeight = 0
	var invalidTargetCount = 0 #used to count and check if the river has no possible paths
	var validTargetArray = [0,0,0,0]
	var validTargetArray2 = []
	var previousDir = 0
	var riverCount = 2
	
	
	for riverIdx in riverCount:
		direction1vector = Vector2(randi_range(-1,1), randi_range(-1,1))
		#if direction1vector == Vector2(0,0): #correct for a still river
		#	direction1vector = Vector2(-1,-1)
		#convert from x,y coords to child idx by ((x * mapSize.x) + y)
		currentCoord = Vector2(int(mapSize.x/2),int(mapSize.y/2))
		currentCoord += direction1vector * 2
		self.get_child((currentCoord.x * mapSize.x) + currentCoord.y).hasWater = true
		self.get_child((currentCoord.x * mapSize.x) + currentCoord.y).riverIdx = riverIdx
		#this loop picks the next spot on the river, checks validity, updates
		#must always have a current coord (current river endpoint) set at the start
	
		while true:
		#for count in 100:
			#start by getting data from the cube
			currentIdx = (currentCoord.x * mapSize.x) + currentCoord.y
			currentMapCube = self.get_child(currentIdx)
			currentHeight = currentMapCube.height
			
			#set next point - we only have one of four options
			#must be down if possible, never up
			validTargetArray = [-1,-1,-1,-1,-1,-1]
			testCube = get_child(self.get_child(currentIdx).neighborIdxArray[1])
			if testCube.height > currentMapCube.height:
				validTargetArray[0] = -1
			elif testCube.hasWater:
				if testCube.riverIdx == riverIdx:
					validTargetArray[0] = -1
			elif testCube.height <= (currentMapCube.height - 2):
				validTargetArray[0] = -1
			else:
				validTargetArray[0] = testCube.idx
			testCube = get_child(self.get_child(currentIdx).neighborIdxArray[2])
			if testCube.height > currentMapCube.height:
				validTargetArray[1] = -1
			elif testCube.hasWater:
				if testCube.riverIdx == riverIdx:
					validTargetArray[1] = -1
			elif testCube.height <= (currentMapCube.height - 2):
				validTargetArray[1] = -1
			else:
				validTargetArray[1] = testCube.idx
			testCube = get_child(self.get_child(currentIdx).neighborIdxArray[3])
			if testCube.height > currentMapCube.height:
				validTargetArray[2] = -1
			elif testCube.hasWater:
				if testCube.riverIdx == riverIdx:
					validTargetArray[2] = -1
			elif testCube.height <= (currentMapCube.height - 2):
				validTargetArray[2] = -1
			else:
				validTargetArray[2] = testCube.idx
			testCube = get_child(self.get_child(currentIdx).neighborIdxArray[4])
			if testCube.height > currentMapCube.height:
				validTargetArray[3] = -1
			elif testCube.hasWater:
				if testCube.riverIdx == riverIdx:
					validTargetArray[3] = -1
			elif testCube.height <= (currentMapCube.height - 2):
				validTargetArray[3] = -1
			else:
				validTargetArray[3] = testCube.idx
			
			if validTargetArray[previousDir] == -1:
				validTargetArray[4] = -1
				validTargetArray[5] = -1
			else:
				validTargetArray[4] = validTargetArray[previousDir]
				validTargetArray[5] = validTargetArray[previousDir]
			
			
			
			validTargetArray2.clear()
			#print(validTargetArray)
			for mapIdx in validTargetArray:
				if not mapIdx == -1: #if we get a valid location
					validTargetArray2.append(mapIdx)
			
			if not validTargetArray2.size() == 0: #if there is a valid spot to move to
				nextIdx = validTargetArray2[randi_range(0, validTargetArray2.size()-1)]
			
			
			
				
				if nextIdx == currentIdx + mapSize.x:
					self.get_child(nextIdx).riverDirection1.x = 1
					self.get_child(currentIdx).riverDirection2.x = 1
					previousDir = 2
				if nextIdx == currentIdx - mapSize.x:
					self.get_child(nextIdx).riverDirection1.y = 1
					self.get_child(currentIdx).riverDirection2.y = 1
					previousDir = 3
				if nextIdx == currentIdx + 1:
					self.get_child(nextIdx).riverDirection1.z = 1
					self.get_child(currentIdx).riverDirection2.z = 1
					previousDir = 0
				if nextIdx == currentIdx - 1:
					self.get_child(nextIdx).riverDirection1.w = 1
					self.get_child(currentIdx).riverDirection2.w = 1
					previousDir = 1
				
				#update selected river idx for the next loop
				currentCoord = self.get_child(nextIdx).mapCoord
				self.get_child(nextIdx).hasWater = true
				
				#check if we've hit a new river, stop if so
				if not self.get_child(nextIdx).riverIdx == -1:
					if not self.get_child(nextIdx).riverIdx == riverIdx:
						print("hit an existing river, stopped")
						break
				
				self.get_child(nextIdx).riverIdx = riverIdx
				
				
				if self.get_child(nextIdx).height == 0:
					#print("ended in ocean")
					self.get_child(nextIdx).get_node("GPUParticles3D").visible = false
					break
			
			else: #if there is not a valid sopt, break
				#print("no valid target point")
				break
			
	
	
	#then update cube shape
	for mapCube in self.get_children(): #+x -x +y -x neighbors are array[3,4,1,2]
		neighborSides = Vector4i(0,0,0,0)
		if mapCube.hasWater:
			mapCube.get_node("submeshes").get_node("mesh1").get_node("waterCase").get_child(0).mesh = waterMeshArray[0]
			
			mapCube.get_node("GPUParticles3D").visible = true
			if mapCube.riverDirection2.x == 1:
				mapCube.get_node("GPUParticles3D").rotation_degrees.y = 0
			if mapCube.riverDirection2.y == 1:
				mapCube.get_node("GPUParticles3D").rotation_degrees.y = 180
			if mapCube.riverDirection2.z == 1:
				mapCube.get_node("GPUParticles3D").rotation_degrees.y = 270
			if mapCube.riverDirection2.w == 1:
				mapCube.get_node("GPUParticles3D").rotation_degrees.y = 90
			
			
			#if self.get_child(mapCube.neighborIdxArray[3]).hasWater:
			if (mapCube.riverDirection1.y == 1) or (mapCube.riverDirection2.x == 1):
				neighborSides.x = 1
				if get_child(mapCube.neighborIdxArray[3]).height == mapCube.height - 1:
					neighborSides2 = Vector4i(1,0,0,0)
					mapCube.changeCubeState.emit(neighborSides2, 0, 0)
					mapCube.changeCubeState.emit(neighborSides2, 1, 1)
					mapCube.get_node("submeshes").get_node("mesh1").get_node("waterCase").get_child(0).mesh = waterMeshArray[1]
					mapCube.get_node("submeshes").get_node("mesh1").get_node("waterCase").get_child(0).rotation_degrees.y = 0
			#if self.get_child(mapCube.neighborIdxArray[4]).hasWater:
			if (mapCube.riverDirection1.x == 1) or (mapCube.riverDirection2.y == 1):
				neighborSides.y = 1
				if get_child(mapCube.neighborIdxArray[4]).height == mapCube.height - 1:
					neighborSides2 = Vector4i(0,1,0,0)
					mapCube.changeCubeState.emit(neighborSides2, 0, 0)
					mapCube.changeCubeState.emit(neighborSides2, 1, 1)
					mapCube.get_node("submeshes").get_node("mesh1").get_node("waterCase").get_child(0).mesh = waterMeshArray[1]
					mapCube.get_node("submeshes").get_node("mesh1").get_node("waterCase").get_child(0).rotation_degrees.y = 180
			#if self.get_child(mapCube.neighborIdxArray[1]).hasWater:
			if (mapCube.riverDirection1.w == 1) or (mapCube.riverDirection2.z == 1):
				neighborSides.z = 1
				if get_child(mapCube.neighborIdxArray[1]).height == mapCube.height - 1:
					neighborSides2 = Vector4i(0,0,1,0)
					mapCube.changeCubeState.emit(neighborSides2, 0, 0)
					mapCube.changeCubeState.emit(neighborSides2, 1, 1)
					mapCube.get_node("submeshes").get_node("mesh1").get_node("waterCase").get_child(0).mesh = waterMeshArray[1]
					mapCube.get_node("submeshes").get_node("mesh1").get_node("waterCase").get_child(0).rotation_degrees.y = 270
			#if self.get_child(mapCube.neighborIdxArray[2]).hasWater:
			if (mapCube.riverDirection1.z == 1) or (mapCube.riverDirection2.w == 1):
				neighborSides.w = 1
				if get_child(mapCube.neighborIdxArray[2]).height == mapCube.height - 1:
					neighborSides2 = Vector4i(0,0,0,1)
					mapCube.changeCubeState.emit(neighborSides2, 0, 0)
					mapCube.changeCubeState.emit(neighborSides2, 1, 1)
					mapCube.get_node("submeshes").get_node("mesh1").get_node("waterCase").get_child(0).mesh = waterMeshArray[1]
					mapCube.get_node("submeshes").get_node("mesh1").get_node("waterCase").get_child(0).rotation_degrees.y = 90
			if neighborSides == Vector4i(0,0,0,0):
				neighborSides = Vector4i(5,0,0,0)
			
			mapCube.changeCubeState.emit(neighborSides, 1, 0)
			
	


#okay list of building specific rules:
#mines get +1 for nearby cliff face(adjacent neighbor with hight > self.height) and +(maxHeight - height) (bonus for being low)
#comms towers get +1 per height, +1 for lower neightbor with (height < self.height), lose all points
#	if neighboring a cell tower or a radioscope, or if it shares a row/collumn with one
#radioscopes get (total number of scopes) ^ 2. but they lose all points if they
#	share a row/column with another radioscope/tower or have ANY neighbors(including rivers). EX. 1st scored is worth 1, 2nd is worth 4, 3rd is worth 9
#foundries get +1 per nearby blast furnace, +1 per nearby river, +1 per mine
#furnaces get +2 per factory and +1 per mine

#also, implement a score queue
#this is simple -> make an array. when scoring, every simgle time you add or subtract from the total,
#add a vector2 to the array containing (index of what caused the score, score adder)
#so, if a furnace(index 22) scores +2 because of a foundry(index 23) and a +1 from a mine(index 42)
#you add [(23, 2),(42,1)] #this lets us show the player exactly how much they scored and why, in a cool way

signal scoreMap
func _on_grid_score_map():
	var score = 0
	
	for mapCube in self.get_children():
		
		var dirty_industry = false
		var polluting = false

		match mapCube.buildingType:
			"Foundry":
				score += 1
				dirty_industry = true
			"Mine":
				score += 1
				dirty_industry = true
			"Blast Furnace":
				score += 1
				dirty_industry = true
			"Telecomm Tower":
				score += 1
			"Oil Refinery":
				score += 1
				dirty_industry = true
			"Radio Telescope":
				score += 1
			"Oil Rig":
				score += 1
			"Pumpjack":
				score += 1
			"Rocket Silo":
				score += 1
			"Nuclear Plant":
				score += 1
			_:
				print("EMPTY!")
				
		if dirty_industry:
			for i in mapCube.neighborIdxArray:
					if self.get_child(i).hasWater or self.get_child(i).height == 0:
						polluting = true
		if polluting:
			score -= 1

	return score

	# some function that scores 
	# loop through all the cubes and make rules for scoring based on number of buildings and adjacent cubes
	# add building function that updates the building type
	# default building type is null

#function that takes stored meshes from .blend and makes them into useable and modifyable meshes
#first recolors all placeholders
#takes all placeholder meshes and creates an array of useable ones
func _set_color(palletteIdx):
	#recolor all placeholders first
	#then make arrays of nodes to duplicate
	
	#set new materials
	material1.albedo_color = color1Array[palletteIdx]
	material2.albedo_color = color2Array[palletteIdx]
	material3.albedo_color = color3Array[palletteIdx]
	material4.albedo_color = color4Array[palletteIdx]
	material5.albedo_color = "6b5642" #"674b30"
	
	
	#mesh1 = $"../placeholders/top/case1/flat".get_child(0).mesh.duplicate()
	#mesh2 = $"../placeholders/top/case1/flat".get_child(0).mesh.duplicate()
	#mesh3 = $"../placeholders/top/case1/flat".get_child(0).mesh.duplicate()
	#mesh4 = $"../placeholders/bottom/case1/flatT".get_child(0).mesh.duplicate()
	
	
	#recolor every mesh
	#start with normal top
	for meshCase in $"../placeholders/top".get_children(): #on each case
		meshRef = meshCase.get_child(0).get_child(0).mesh.duplicate()
		meshRef.surface_set_material(0, material1)
		topMeshArray.append(meshRef)
	#then alternate top
	for meshCase in $"../placeholders/top2".get_children(): #on each case
		meshRef = meshCase.get_child(0).get_child(0).mesh.duplicate()
		meshRef.surface_set_material(0, material2)
		topMeshArray2.append(meshRef)
	#and cliff top
	for meshCase in $"../placeholders/top3".get_children(): #on each case
		meshRef = meshCase.get_child(0).get_child(0).mesh.duplicate()
		meshRef.surface_set_material(0, material3)
		topMeshArray3.append(meshRef)
	#then cliff bottom
	for meshCase in $"../placeholders/bottom".get_children(): #on each case
		meshRef = meshCase.get_child(0).get_child(0).mesh.duplicate()
		meshRef.surface_set_material(0, material3)
		bottomMeshArray.append(meshRef)
	#and finally water cases
	for meshCase in $"../placeholders/water".get_children(): #on each case
		meshRef = meshCase.get_child(0).get_child(0).mesh.duplicate()
		meshRef.surface_set_material(0, material4)
		waterMeshArray.append(meshRef)
	
	#decor remeshing
	$"../placeholders/decor2/tree".mesh.surface_set_material(0, material1)
	$"../placeholders/decor2/tree/trunk".mesh.surface_set_material(0, material5)
	$"../placeholders/decor2/grass1".mesh.surface_set_material(0, material1)
	$"../placeholders/decor2/grass2".mesh.surface_set_material(0, material1)
	$"../placeholders/decor2/rock1".mesh.surface_set_material(0, material3)
	$"../placeholders/decor2/rock2".mesh.surface_set_material(0, material3)
	
	#this is all ocean mesh stuff
	$"../ocean/plane".mesh.size = Vector2(mapSize.x * cubeSize.x * 2, mapSize.y * cubeSize.z * 2)
	$"../ocean/plane".mesh.subdivide_depth = mapSize.y
	$"../ocean/plane".mesh.subdivide_width = mapSize.x
	$"../ocean/plane".mesh.surface_get_material(0).set_shader_parameter("mainColor", Color(color4Array[palletteIdx]))
	
	
	
	#also set sky color to this, so that it blends naturally into the sea
	sky = $"../WorldEnvironment".environment.sky.sky_material
	sky.sky_horizon_color = color4Array[palletteIdx]
	sky.ground_horizon_color = color4Array[palletteIdx]

#function that applies colors to the grid, adds an ocean, populates meshes, etc.
#makes the map look like an island instead of a pile of blocks
func _color_pass():
	pass
	
	for mapCube in self.get_children():
		for submesh in mapCube.get_node("submeshes").get_children(): #iterate on all sub meshes
			if submesh.name == "mesh1": #top cube gets special color
				if mapCube.height == 1:
					submesh.get_node("topCase").get_child(0).mesh = topMeshArray2[0]
				else:
					submesh.get_node("topCase").get_child(0).mesh = topMeshArray[0]
				#bottom is always cliff color
				submesh.get_node("bottomCase").get_child(0).mesh = bottomMeshArray[0]
			else: #for all other cubes, cliff color
				submesh.get_node("topCase").get_child(0).mesh = topMeshArray3[0]
				submesh.get_node("bottomCase").get_child(0).mesh = bottomMeshArray[0]
		
		
		#makes stuff invisible so it won't interfere with the ocean
		if mapCube.height == 0 :
			mapCube.remove.emit()
	

#everything here and below is for getting inputs
func _process(delta): #reset and information functions
	
	#if Input.is_action_just_pressed("i"):
	#	#self.get_child(0).changeCubeState.emit(Vector4i(0,1,1,1), 1, 0)
	#	updateRivers.emit()
	#	#$"../UI".advanceTurn.emit()
	
	if Input.is_action_just_pressed("r"):
		#colorSelect = wrapi(colorSelect + 1, 0, 5)
		#for node in self.get_children():
		#	node.free()
		#reset.emit()
		generateMap.emit()



	#gets click input
	#if Input.is_action_just_pressed("m1"):
	#	if Rect2($"../UI/inGame/buildingHotbar".global_position, $"../UI/inGame/buildingHotbar".size).has_point(get_viewport().get_mouse_position()):
	#		$"../UI".isBuildingSelected = false
	#	else:
	#		#if we're not clicking on a UI button
	#		if $"../Camera3D/raycast".is_colliding():
	#			#$"../Camera3D/raycast".get_collider().get_parent() reference to the clicked cube script
	#			$"../Camera3D/raycast".get_collider().get_parent().hasWater = true

	#updates the position of the indicator sprite
	if $"../UI".menuState == 0: #only if ingame
		if $"../Camera3D/raycast".is_colliding():
			$"../Camera3D/raycast/indicator".global_position = $"../Camera3D/raycast".get_collider().get_parent().global_position
			$"../Camera3D/raycast/indicator".global_position.y += 3
			$"../Camera3D/raycast/indicator".visible = true
			isCubeSelected = true
			selectedCubeIdx =  $"../Camera3D/raycast".get_collider().get_parent().idx
		else:
			$"../Camera3D/raycast/indicator".visible = false
			isCubeSelected = false


func _input(event): #mouse movement click inputs
	#for placing the indicator of where we are clicking
	if event is InputEventMouseMotion:
		
		$"../Camera3D/raycast".global_rotation = Vector3(0,0,0)
		$"../Camera3D/raycast".target_position = $"../Camera3D/raycast".global_position - $"../Camera3D".project_position(event.position, -200)
