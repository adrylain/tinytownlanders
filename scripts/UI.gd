extends Control

#sorry this bit is a lotta gibberish
#4 states - main menu, pause menu, in-game. Minimalist on first 3, settings has keybinds
#we oughtta paper plot this
#screens - main, settings, pause, tips, new island generation
#do we need pause? zoom closer to the island as the game gets closer
#spam esc 3 times to zoom out and leave
#main1 - play/settings/credits/quit, main2 - load/new/back, pause - resume/save/settings/tips/back 
#pause goes up #main1/2 go further out #settings goes left? #states are handled by pivot position

#quitting from menu automatically saves map
#loading game checks for saved games
#as little as possible in game, multiple keybinds, up/down wasd movement or arrow keys
#during menus, camera rotates around the island, so we don't need a background

#all menu transitions happen smoothly, coming in from the side and fading back out
#and quite slowly

#import a hgih definition font for our own use
#transitions -> ingame results in a blur border disapearring
#settings comes from the right, others fold to the left like a page

#keybinds
#up down left right for both menu and ingame -> wasd/arrow keys
#back -> tab/esc
#placement -> e/enter
#next/prev should be scroll wheel
#tootltips are hover

#this would need, for gameplay -> select building as part of menu -> "placement mode" where you get wasd control
#so we should have a selection box #also a hold to move selection

##TODO TDOE TODO add a second save button from menu 2
##ALSO inport font

signal updateState
var menuState = 0 #0=ingame, 2=pause, 1=settings, 3=menu2 4=menu1
#var buildingArray = ["Mine","Foundry","Blast Furnace","Comms Array","Radioscope","Nuclear Plant","Refinery","Ocean Rig","Pumpjack","Rocket Silo"]
var buildingArray = ["Mine","Foundry","Blast Furnace","Comms Array","Radioscope","Nuclear Plant","Refinery","Oil Rig"]
signal advanceTurn
var isBuildingSelected = false
var selectedBuilding = 0 #1,2,or 3 based on most recently selected button
var building1 = "null"
var building2 = "null"
var building3 = "null"

var isClickInvalid = false #used to check for input validity
var isPlacementInvalid = false
var cubeToCheck

func _ready() -> void:
	menuState = 4 #set our state to main menu 2
	updateState.emit(menuState)
	advanceTurn.emit()

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("i"):
		pass
		#menuState += 1
		#print(pingpong(menuState, 4))
		#updateState.emit(pingpong(menuState, 4))
		advanceTurn.emit()
	
	if Input.is_action_just_pressed("m1"):
		isClickInvalid = false
		if Rect2($"../UI/inGame/buildingHotbar".global_position, $"../UI/inGame/buildingHotbar".size).has_point(get_viewport().get_mouse_position()):
			isClickInvalid = true
		
		if not isClickInvalid:
			if isBuildingSelected: #if we are holding a building
				if not $"../grid".isCubeSelected:#if not on a position
					isBuildingSelected = false
				else: #if we have just clicked on a position 
					#check placement valididty
					cubeToCheck = $"../grid".get_child($"../grid".selectedCubeIdx)
					isPlacementInvalid = false
					if cubeToCheck.hasWater:
						isPlacementInvalid = true
					#if cubeToCheck.height == 0:
					#	isPlacementInvalid = true
		
					if not isPlacementInvalid:
						if selectedBuilding == 1:
							$"../grid".get_child($"../grid".selectedCubeIdx).addBuilding.emit(building1)
						if selectedBuilding == 2:
							$"../grid".get_child($"../grid".selectedCubeIdx).addBuilding.emit(building2)
						if selectedBuilding == 3:
							$"../grid".get_child($"../grid".selectedCubeIdx).addBuilding.emit(building3)
						advanceTurn.emit()
		
		
		
	if Input.is_action_just_pressed("esc"):
		isBuildingSelected = false
		if menuState == 4: #close game
			self.get_tree().quit()
		elif menuState == 3: #go back
			self.updateState.emit(4)
		elif menuState == 2:
			self.updateState.emit(3)
		elif menuState == 1:
			self.updateState.emit($settings.prevState)
		elif menuState == 0:
			self.updateState.emit(2)
	



#called when a building is placed, set out 3 new buildings to select
#building rules - silos should not appear before turn 5, mines and factories should be 50% more common
func _on_advance_turn():
	#$inGame/buildingHotbar/building1
	building1 = buildingArray[randi_range(0, buildingArray.size() - 1)]
	building2 = buildingArray[randi_range(0, buildingArray.size() - 1)]
	building3 = buildingArray[randi_range(0, buildingArray.size() - 1)]
	for buttonIdx in 3:
		for button in $inGame/buildingHotbar.get_child(buttonIdx + 2).get_children():
			for nodeThing in button.get_children():
				nodeThing.free()
	$inGame/buildingHotbar/building1.text = building1
	$inGame/buildingHotbar/building1.add_child($buildingSprites.get_node(building1).duplicate())
	$inGame/buildingHotbar/building1.get_child(0).play()
	$inGame/buildingHotbar/building2.text = building2
	$inGame/buildingHotbar/building2.add_child($buildingSprites.get_node(building2).duplicate())
	$inGame/buildingHotbar/building2.get_child(0).play()
	$inGame/buildingHotbar/building3.text = building3
	$inGame/buildingHotbar/building3.add_child($buildingSprites.get_node(building3).duplicate())
	$inGame/buildingHotbar/building3.get_child(0).play()





#determines what part of the menu we are in, also calls the camera to move
func _update_state(idx):
	#print(idx)
	#start by making the whole UI invisible, enable whatever we just selected, start camera transition
	for subMenu in self.get_children():
		subMenu.visible = false
	
	if idx == 4: #main menu 1
		pass
		$main.visible = true
		$"../camPivot/pnt".position = Vector3(-50, 80, 150)
		$"../Camera3D".setMenuMode.emit()
		$main/playButton.grab_focus()
	
	elif idx == 3: #main menu 2
		pass
		$main2.visible = true
		$"../camPivot/pnt".position = Vector3(-40, 40, 100)
		$"../Camera3D".setMenuMode.emit()
		$main2/resumeButton.grab_focus()
	
	elif idx == 1: #settings menu
		pass
		$settings.visible = true
		$settings.prevState = menuState
		$"../camPivot/pnt".position = Vector3(20, 20, 40)
		$"../Camera3D".setMenuMode.emit()
		$settings/backButton.grab_focus()
		$settings.onOpen.emit()
	
	elif idx == 2: #pause menu
		pass
		$pause.visible = true
		$"../camPivot/pnt".position = Vector3(-10, 20, 50)
		$"../Camera3D".setMenuMode.emit()
		$pause/resumeButton.grab_focus()
	
	elif idx == 0: #ingame, menu off
		$inGame.visible = true
		$"../camPivot/pnt".position = Vector3(0, 25, 40)
		$"../Camera3D".endMenuMode.emit()
	
	#menu state updated at the end
	menuState = idx
	

#big old stack of button stuff

#play the game/progress forward in the menu
func _on_play_button_button_down() -> void:
	self.updateState.emit(3)

#open settings, tell it to return to pause
func _on_settings_button_button_down() -> void:
	self.updateState.emit(1)
	$settings.prevState = 4

##TODO TODO close the fucking game
func _on_quit_button_button_down() -> void:
	self.get_tree().quit()

#needs doing but not as  improtant. creadits are fgor finished games
func _on_credits_button_button_down() -> void:
	pass # Replace with function body.

#resume the most recent map, which is a fresh map by default
func _on_resume_button_button_down2() -> void:
	self.updateState.emit(0)

#TODO #load from file
func _on_load_button_button_down() -> void:
	pass # Replace with function body.

#start a new game, should reset the current map
func _on_new_button_button_down() -> void:
	for node in $"../grid".get_children():
		node.free()
	$"../grid".reset.emit()

func _on_back_button_button_down() -> void:
	self.updateState.emit(4)

func _on_resume_button_button_down() -> void:
	self.updateState.emit(0)

#open settings, tell it to return to pause
func _on_settings_button_button_down2() -> void:
	self.updateState.emit(1)
	$settings.prevState = 2

#TODO save map to file
func _on_save_button_button_down() -> void:
	print("this but works kinda")
	var save_file = FileAccess.open("user://savegame.save", FileAccess.WRITE)
	var save_nodes = $"../grid".get_tree().get_nodes_in_group("Tiles")
	for node in save_nodes:
		# Check the node is an instanced scene so it can be instanced again during load.
		if node.scene_file_path.is_empty():
			print("persistent node '%s' is not an instanced scene, skipped" % node.name)
			continue

		# Check the node has a save function.
		if !node.has_method("save"):
			print("persistent node '%s' is missing a save() function, skipped" % node.name)
			continue

		# Call the node's save function.
		var node_data = node.call("save")

		# JSON provides a static method to serialized JSON string.
		var json_string = JSON.stringify(node_data)

		# Store the save dictionary as a new line in the save file.
		save_file.store_line(json_string)

#back button from paused, actually goes to load/new map
func _on_back_button_2_button_down() -> void:
	self.updateState.emit(3)


func _on_building_1_button_down() -> void:
	pass # Replace with function body.
	isBuildingSelected = true
	selectedBuilding = 1

func _on_building_2_button_down() -> void:
	pass # Replace with function body.
	isBuildingSelected = true
	selectedBuilding = 2

func _on_building_3_button_down() -> void:
	pass # Replace with function body.
	isBuildingSelected = true
	selectedBuilding = 3
