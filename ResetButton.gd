extends Button

var start_pos = Vector3()
func _ready() -> void:
    start_pos = $"../CharacterBody3D".global_position

func _on_pressed() -> void:
    $"../CharacterBody3D".global_position = start_pos
    $"../CharacterBody3D".velocity *= 0.0
    $"../CharacterBody3D/CameraHolder".rotation.y = 0.0
    $"../CharacterBody3D/CameraHolder".rotation.x = 0.0
    release_focus()
