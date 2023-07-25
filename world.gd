extends Node3D



func _ready() -> void:
    $"CollisionBox".add_item("AABB")
    $"CollisionBox".add_item("Cylinder")
    $"CollisionBox".add_item("Capsule")
    $"CollisionBox".add_item("Gem")
    $"CollisionBox".add_item("Octogem")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
    $CharacterBody3D.do_stairs = $StairsSetting.button_pressed
    $CharacterBody3D.do_skipping_hack = $SkippingSetting.button_pressed
    $CharacterBody3D.third_person = $ThirdPerson.button_pressed
    
    $"FPS".text = "framerate: " + str(Engine.get_frames_per_second())
    $"Vel".text = str($CharacterBody3D.velocity)
    
    $CharacterBody3D/AABB.disabled = $CollisionBox.selected != 0
    $CharacterBody3D/Gem.disabled = $CollisionBox.selected != 3
    $CharacterBody3D/Octogem.disabled = $CollisionBox.selected != 4
    $CharacterBody3D/Cylinder.disabled = $CollisionBox.selected != 1
    $CharacterBody3D/Capsule.disabled = $CollisionBox.selected != 2
    
