extends Control

#goal for this script is that we can drag and drop into any other project
#thus it's saved weird, so that the script is in a folder with the scene
####TODO if we are drag n dropping, redo the back button function

var prevState = 4 #saves the previous menu state so we can return to it
signal onOpen

#set keybinds stuff here
func _ready() -> void:
	onOpen.emit()

func _on_open() -> void:
	$openKeybinds.text = "Open Keybinds"
	$keybinds.visible = false


#back button
func _on_back_button_button_down() -> void:
	self.get_parent().updateState.emit(prevState)
	

#keybinds button
func _on_open_keybinds_button_down() -> void:
	if $keybinds.visible:
		$openKeybinds.text = "Open Keybinds"
		$keybinds.visible = false
	else:
		$openKeybinds.text = "Close Keybinds"
		$keybinds.visible = true

#okay big old stacm of keyhbidbndas signals
#should readjust input maps for these
