extends CharacterBody3D

var target: Node3D
var health := 100
var speed := 2.1
var attack_timer := 1.2
var alive := true
var body_mesh: MeshInstance3D

func _ready():
    add_to_group("bots")
    var shape_node = CollisionShape3D.new()
    var shape = CapsuleShape3D.new()
    shape.radius = 0.34
    shape.height = 1.65
    shape_node.shape = shape
    shape_node.position.y = 0.83
    add_child(shape_node)

    body_mesh = MeshInstance3D.new()
    var mesh = CapsuleMesh.new()
    mesh.radius = 0.34
    mesh.height = 1.65
    body_mesh.mesh = mesh
    body_mesh.position.y = 0.83
    var mat = StandardMaterial3D.new()
    mat.albedo_color = Color(0.22, 0.29, 0.24)
    body_mesh.material_override = mat
    add_child(body_mesh)

func _physics_process(delta):
    if not alive or not is_instance_valid(target):
        return
    attack_timer -= delta
    var offset = target.global_position - global_position
    offset.y = 0
    var distance = offset.length()
    if distance > 7.0:
        var dir = offset.normalized()
        velocity.x = dir.x * speed
        velocity.z = dir.z * speed
        look_at(Vector3(target.global_position.x, global_position.y, target.global_position.z))
    else:
        velocity.x = move_toward(velocity.x, 0, 7.0 * delta)
        velocity.z = move_toward(velocity.z, 0, 7.0 * delta)
        if attack_timer <= 0:
            attack_timer = 1.8
            if distance < 18.0 and has_line_of_sight():
                target.take_damage(7)
    move_and_slide()

func has_line_of_sight() -> bool:
    var space = get_world_3d().direct_space_state
    var start = global_position + Vector3.UP * 1.2
    var finish = target.global_position + Vector3.UP * 1.2
    var query = PhysicsRayQueryParameters3D.create(start, finish)
    query.exclude = [self]
    var result = space.intersect_ray(query)
    return result.is_empty() or result.collider == target

func take_hit(amount: int):
    if not alive:
        return
    health -= amount
    if health <= 0:
        alive = false
        queue_free()
        var game = get_tree().current_scene
        if game and game.has_method("bot_eliminated"):
            game.bot_eliminated()
