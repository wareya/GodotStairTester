extends CharacterBody3D

func _ready() -> void:
    $"../CollisionBox".add_item("AABB")
    $"../CollisionBox".add_item("Cylinder")
    $"../CollisionBox".add_item("Capsule")
    $"../CollisionBox".add_item("Gem")
    $"../CollisionBox".add_item("Octogem")

const mouse_sens = 0.022 * 3.0

const unit_conversion = 64.0

const gravity = 800.0/unit_conversion
const jumpvel = 270.0/unit_conversion

const max_speed = 320.0/unit_conversion
const max_speed_air = 320.0/unit_conversion

const accel = 15.0
const accel_air = 2.0

func _input(event: InputEvent) -> void:
    if event is InputEventMouseMotion:
        if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
            $CameraHolder.rotation_degrees.y -= event.relative.x * mouse_sens
            $CameraHolder.rotation_degrees.x -= event.relative.y * mouse_sens
            $CameraHolder.rotation_degrees.x = clamp($CameraHolder.rotation_degrees.x, -90.0, 90.0)

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("m1") or event.is_action_pressed("m2"):
        if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
            Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
        else:
            Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

var wish_dir = Vector3()
var friction = 6.0

func _friction(_velocity : Vector3, delta : float) -> Vector3:
    _velocity *= pow(0.9, delta*60.0)
    if wish_dir == Vector3():
        _velocity = _velocity.move_toward(Vector3(), delta * max_speed)
    return _velocity

func handle_friction(delta):
    if is_on_floor():
        velocity = _friction(velocity, delta)

func handle_accel(delta):
    if wish_dir != Vector3():
        var actual_maxspeed = max_speed if is_on_floor() else max_speed_air
        var actual_accel = (accel if is_on_floor() else accel_air) * actual_maxspeed
        
        var floor_velocity = Vector3(velocity.x, 0, velocity.z)
        var speed_in_wish_dir = floor_velocity.dot(wish_dir.normalized())
        if speed_in_wish_dir < actual_maxspeed:
            var add_limit = actual_maxspeed - speed_in_wish_dir
            var add_amount = min(add_limit, actual_accel*delta)
            velocity += wish_dir.normalized() * add_amount

func handle_friction_and_accel(delta):
    handle_friction(delta)
    handle_accel(delta)

@export var do_camera_smoothing : bool = true
@export var do_stairs : bool = true
@export var do_skipping_hack : bool = false
@export var skipping_hack_distance : float = 0.08

# used to smooth out the camera when climbing stairs
var camera_offset_y = 0.0

func _process(delta: float) -> void:
    if $"../StairsSetting":
        do_stairs = $"../StairsSetting".button_pressed
    if $"../SkippingSetting":
        do_skipping_hack = $"../SkippingSetting".button_pressed
    
    $"../FPS".text = "framerate: " + str(Engine.get_frames_per_second())
    $"../Vel".text = str(velocity)
    
    $AABB.disabled = $"../CollisionBox".selected != 0
    $Gem.disabled = $"../CollisionBox".selected != 3
    $Octogem.disabled = $"../CollisionBox".selected != 4
    $Cylinder.disabled = $"../CollisionBox".selected != 1
    $Capsule.disabled = $"../CollisionBox".selected != 2
    
    if Input.is_action_pressed("jump") and is_on_floor():
        velocity.y = jumpvel
        floor_snap_length = 0.0
    elif is_on_floor():
        floor_snap_length = 0.5
    
    var input_dir := Input.get_vector("left", "right", "forward", "backward")
    wish_dir = Vector3(input_dir.x, 0, input_dir.y).rotated(Vector3.UP, $CameraHolder.global_rotation.y)
    if wish_dir.length_squared() > 1.0:
        wish_dir = wish_dir.normalized()
    
    handle_friction_and_accel(delta)
    
    var step_height = 0.5
    
    if not is_on_floor():
        velocity.y -= gravity * delta * 0.5
    
    # check for simple stairs; three steps
    var start_position = global_position
    var found_stairs = false
    var wall_test_travel = null
    var wall_collision = null
    if do_stairs and velocity.x != 0.0 and velocity.z != 0.0:
        # step 1: upwards trace
        var ceiling_collision = move_and_collide(step_height * Vector3.UP)
        var ceiling_travel_distance = step_height if not ceiling_collision else abs(ceiling_collision.get_travel().y)
        var ceiling_position = global_position
        # step 2: "check if there's a wall" trace
        wall_test_travel = velocity * delta
        wall_collision = move_and_collide(wall_test_travel)
        # step 3: downwards trace
        var floor_collision = move_and_collide(Vector3.DOWN * (ceiling_travel_distance + (step_height if is_on_floor() else 0.0)))
        if floor_collision and floor_collision.get_collision_count() > 0 and acos(floor_collision.get_normal(0).y) < floor_max_angle:
            found_stairs = true
        
        # NOTE: NOT NECESSARY
        # try again with a certain minimum horizontal step distance if there was no wall collision and the wall trace was close
        if do_skipping_hack and !found_stairs and is_on_floor() and !wall_collision and (wall_test_travel * Vector3(1,0,1)).length() < skipping_hack_distance:
            # go back to where we were at the end of the ceiling collision test
            global_position = ceiling_position
            # calculate a new path for the wall test: horizontal only, length of our fallback distance
            var floor_velocity = Vector3(velocity.x, 0.0, velocity.z)
            var factor = skipping_hack_distance / floor_velocity.length()
            
            # step 2, skipping hack version
            wall_test_travel = floor_velocity * factor
            wall_collision = move_and_collide(wall_test_travel, false, 0.0)
            
            # step 3, skipping hack version
            floor_collision = move_and_collide(Vector3.DOWN * (ceiling_travel_distance + (step_height if is_on_floor() else 0.0)))
            if floor_collision and floor_collision.get_collision_count() > 0 and acos(floor_collision.get_normal(0).y) < floor_max_angle:
                found_stairs = true
    
    # (this section is more complex than it needs to be, because of move_and_slide taking velocity and delta for granted)
    # if we found stairs, climb up them
    if found_stairs:
        # try to apply the remaining travel distance if we hit a wall
        if wall_collision and wall_test_travel.length_squared() > 0.0:
            var remaining_factor = wall_collision.get_remainder().length() / wall_test_travel.length()
            velocity *= remaining_factor
            move_and_slide()
            velocity /= remaining_factor
        # even if we didn't hit a wall, we still need to use move_and_slide to make is_on_floor() work properly
        else:
            var old_vel = velocity
            velocity = Vector3()
            move_and_slide()
            velocity = old_vel
    # no stairs, do "normal" non-stairs movement
    else:
        global_position = start_position
        move_and_slide()
    
    if not is_on_floor():
        velocity.y -= gravity * delta * 0.5
    
    # first/third-person adjustment
    $CameraHolder.position.y = 1.2 if $"../ThirdPerson".button_pressed else 1.5
    $CameraHolder/Camera3D.position.z = 1.5 if $"../ThirdPerson".button_pressed else 0.0
    
    if do_camera_smoothing:
        # NOT NEEDED: camera smoothing
        var stair_climb_distance = 0.0
        if found_stairs:
            stair_climb_distance = global_position.y - start_position.y
        camera_offset_y -= stair_climb_distance
        camera_offset_y = clamp(camera_offset_y, -step_height, step_height)
        camera_offset_y = move_toward(camera_offset_y, 0.0, delta * 3.0)
        
        $CameraHolder/Camera3D.position.y = 0.0
        $CameraHolder/Camera3D.position.x = 0.0
        $CameraHolder/Camera3D.global_position.y += camera_offset_y
