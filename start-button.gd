extends Button

func _ready() -> void:
	$"../Title".visible = true
	$"../Rules".visible = false
	
	
func _on_pressed() -> void:
	$"../Title".visible = false
	$"../Rules".visible = true
