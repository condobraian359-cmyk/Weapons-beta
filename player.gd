extends CharacterBody3D

@export var walk_speed := 4.2
@export var sprint_speed := 6.0
@export var jump_velocity := 4.5
@export var mouse_sensitivity := 0.0022

var move_forward := false
var move_back := false
var move_left := false
var move_right := false
var sprinting := false
var health := 100
var ammo := 30
var reserve_ammo := 120
var fire_cooldown := 0.0
var reloading := false
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var camera: Camera3D
var muzzle: Marker3D
var hud

func _ready():
    name = "Player"
    var collision = CollisionShape3D.new()
    var capsule = CapsuleShape3D.new()
    capsule.radius = 0.38
    capsule.height = 1.8
    collision.shape = capsule
    collision.position.y = 0.9
    add_child(collision)

    camera = Camera3D.new()
    camera.position = Vector3(0, 1.58, 0)
    camera.fov = 78
    add_child(camera)
    camera.current = true

    muzzle = Marker3D.new()
    muzzle.position = Vector3(0.22, -0.18, -0.65)
    camera.add_child(muzzle)

func _unhandled_input(event):
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        rotate_y(-event.relative.x * mouse_sensitivity)
        camera.rotate_x(-event.relative.y * mouse_sensitivity)
        camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-82), deg_to_rad(82))
    elif event is InputEventScreenDrag:
        # En móvil, arrastrar el lado derecho de la pantalla para mirar.
        if event.position.x > get_viewport().get_visible_rect().size.x * 0.35:
            rotate_y(-event.relative.x * mouse_sensitivity * 1.7)
            camera.rotate_x(-event.relative.y * mouse_sensitivity * 1.7)
            camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-82), deg_to_rad(82))

func _physics_process(delta):
    fire_cooldown = maxf(0.0, fire_cooldown - delta)
    if not is_on_floor():
        velocity.y -= gravity * delta
    elif Input.is_action_just_pressed("jump"):
        velocity.y = jump_velocity

    var input_dir = Vector2.ZERO
    input_dir.y -= float(move_forward or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))
    input_dir.y += float(move_back or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN))
    input_dir.x -= float(move_left or Input.is_key_pressed(KEY_A))
    input_dir.x += float(move_right or Input.is_key_pressed(KEY_D))
    if input_dir.length() > 1.0:
        input_dir = input_dir.normalized()

    var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
    var speed = sprint_speed if (sprinting or Input.is_key_pressed(KEY_SHIFT)) else walk_speed
    if direction:
        velocity.x = direction.x * speed
        velocity.z = direction.z * speed
    else:
        velocity.x = move_toward(velocity.x, 0, walk_speed * 5.0 * delta)
        velocity.z = move_toward(velocity.z, 0, walk_speed * 5.0 * delta)
    move_and_slide()

    if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
        shoot()

func shoot():
    if fire_cooldown > 0 or reloading:
        return
    if ammo <= 0:
        reload_weapon()
        return
    ammo -= 1
    fire_cooldown = 0.12
    var space = get_world_3d().direct_space_state
    var from = camera.global_position
    var to = from + (-camera.global_transform.basis.z * 90.0)
    var query = PhysicsRayQueryParameters3D.create(from, to)
    query.exclude = [self]
    var hit = space.intersect_ray(query)
    if hit and hit.collider and hit.collider.is_in_group("bots"):
        hit.collider.take_hit(34)
    if hud:
        hud.update_status()

func reload_weapon():
    if reloading or ammo == 30 or reserve_ammo <= 0:
        return
    reloading = true
    await get_tree().create_timer(1.35).timeout
    var needed = 30 - ammo
    var loaded = mini(needed, reserve_ammo)
    ammo += loaded
    reserve_ammo -= loaded
    reloading = false
    if hud:
        hud.update_status()

func take_damage(amount: int):
    health = maxi(0, health - amount)
    if hud:
        hud.update_status()
    if health <= 0:
        if hud:
            hud.show_game_over()
