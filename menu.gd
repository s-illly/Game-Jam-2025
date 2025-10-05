extends Control


func _ready() -> void:
	$Rules.visible = false
	$Title.visible = true
	
func rules_button_pressed() -> void:
	get_tree().change_scene_to_file("res://node_3d.tscn")


func title_button_pressed() -> void:
	$Rules.visible = true
	$Title.visible = false
