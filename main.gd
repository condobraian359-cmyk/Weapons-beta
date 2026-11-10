extends Node3D

const PlayerScript = preload("res://scripts/player.gd")
const BotScript = preload("res://scripts/bot.gd")

var player
var hud_layer: CanvasLayer
var health_label: Label
var ammo_label: Label
var score_label: Label
var status_label: Label
var score := 0
var total_bots := 8
var started := false
var paused := false

func _ready():
    _build_world()
    _build_player()
    _build_bots()
    _build_hud()
    _show_menu()

func _build_world():
    var env = WorldEnvironment.new()
    var environment = Environment.new()
    environment.background_mode = Environment.BG_SKY
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.42, 0.46, 0.5)
    environment.ambient_light_energy = 0.65
    env.environment = environment
    add_child(env)

    var sun = DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-48, -32, 0)
    sun.light_energy = 1.15
    sun.shadow_enabled = true
    add_child(sun)

    _add_box("Ground", Vector3(0, -0.5, 0), Vector3(100, 1, 100), Color(0.23, 0.25, 0.23))
    # Calles y edificios de una sola zona urbana compacta.
    var buildings = [
        [Vector3(-18, 3, -15), Vector3(12, 7, 13)],
        [Vector3(17, 4, -18), Vector3(15, 9, 12)],
        [Vector3(-22, 2.5, 17), Vector3(10, 6, 15)],
        [Vector3(22, 3, 18), Vector3(13, 7, 13)],
        [Vector3(0, 2, -34), Vector3(18, 5, 9)],
        [Vector3(0, 2, 34), Vector3(20, 5, 8)]
    ]
    for item in buildings:
        _add_box("Building", item[0], item[1], Color(0.31, 0.32, 0.30))
    # Coberturas y restos urbanos.
    for i in range(18):
        var x = randf_range(-35, 35)
        var z = randf_range(-35, 35)
        if absf(x) < 7 and absf(z) < 7:
            continue
        _add_box("Cover", Vector3(x, 0.65, z), Vector3(randf_range(1.5, 3.5), 1.3, randf_range(1.5, 3.5)), Color(0.25, 0.27, 0.26))
    # Vehículos decorativos simplificados.
    for pos in [Vector3(-8, 0.65, 12), Vector3(12, 0.65, -5), Vector3(30, 0.65, 4)]:
        _add_box("Abandoned vehicle", pos, Vector3(4.2, 1.3, 2.1), Color(0.16, 0.20, 0.18))

func _add_box(label: String, pos: Vector3, size: Vector3, color: Color):
    var body = StaticBody3D.new()
    body.name = label
    body.position = pos
    var mesh_instance = MeshInstance3D.new()
    var mesh = BoxMesh.new()
    mesh.size = size
    mesh_instance.mesh = mesh
    var mat = StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.95
    mesh_instance.material_override = mat
    body.add_child(mesh_instance)
    var collision = CollisionShape3D.new()
    var shape = BoxShape3D.new()
    shape.size = size
    collision.shape = shape
    body.add_child(collision)
    add_child(body)

func _build_player():
    player = PlayerScript.new()
    player.position = Vector3(0, 0.2, 0)
    add_child(player)

func _build_bots():
    var positions = [
        Vector3(-24, 0.1, -4), Vector3(23, 0.1, -8),
        Vector3(-29, 0.1, 25), Vector3(29, 0.1, 25),
        Vector3(0, 0.1, -27), Vector3(0, 0.1, 27),
        Vector3(-35, 0.1, -30), Vector3(35, 0.1, -30)
    ]
    for p in positions:
        var bot = BotScript.new()
        bot.position = p
        bot.target = player
        add_child(bot)

func _build_hud():
    hud_layer = CanvasLayer.new()
    add_child(hud_layer)
    var root = Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    hud_layer.add_child(root)

    health_label = _label(root, "SALUD 100", Vector2(22, 18), 22)
    ammo_label = _label(root, "30 / 120", Vector2(1040, 18), 22)
    score_label = _label(root, "BAJAS 0", Vector2(22, 52), 18)
    status_label = _label(root, "OBJETIVO: despeja la zona", Vector2(22, 88), 18)

    _make_button(root, "▲", Vector2(92, -172), Vector2(68, 58), func(down): player.move_forward = down, true)
    _make_button(root, "▼", Vector2(92, -92), Vector2(68, 58), func(down): player.move_back = down, true)
    _make_button(root, "◀", Vector2(18, -92), Vector2(68, 58), func(down): player.move_left = down, true)
    _make_button(root, "▶", Vector2(166, -92), Vector2(68, 58), func(down): player.move_right = down, true)
    _make_button(root, "CORRER", Vector2(18, -242), Vector2(120, 54), func(down): player.sprinting = down, true)
    _make_button(root, "DISPARAR", Vector2(-178, -110), Vector2(150, 72), func(_down): player.shoot(), false)
    _make_button(root, "RECARGAR", Vector2(-178, -194), Vector2(150, 58), func(_down): player.reload_weapon(), false)
    _make_button(root, "SALTAR", Vector2(-178, -30), Vector2(130, 54), func(_down): _jump_player(), false)
    _make_button(root, "PAUSA", Vector2(-100, 18), Vector2(90, 48), func(_down): _toggle_pause(), false)

func _label(parent: Control, value: String, pos: Vector2, font_size: int) -> Label:
    var label = Label.new()
    label.text = value
    label.position = pos
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", Color(0.94, 0.95, 0.91))
    parent.add_child(label)
    return label

func _make_button(parent: Control, text_value: String, offset: Vector2, size: Vector2, callback: Callable, hold: bool):
    var button = Button.new()
    button.text = text_value
    button.size = size
    button.add_theme_font_size_override("font_size", 17)
    button.add_theme_color_override("font_color", Color.WHITE)
    button.add_theme_stylebox_override("normal", _button_style(Color(0.08, 0.12, 0.11, 0.78)))
    button.add_theme_stylebox_override("pressed", _button_style(Color(0.24, 0.34, 0.27, 0.95)))
    if offset.x < 0:
        button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
        button.position = offset - size
    else:
        button.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
        button.position = Vector2(offset.x, offset.y)
    parent.add_child(button)
    if hold:
        button.button_down.connect(func(): callback.call(true))
        button.button_up.connect(func(): callback.call(false))
    else:
        button.pressed.connect(func(): callback.call(true))
    return button


func _jump_player():
    if player.is_on_floor():
        player.velocity.y = player.jump_velocity

func _button_style(color: Color) -> StyleBoxFlat:
    var style = StyleBoxFlat.new()
    style.bg_color = color
    style.corner_radius_top_left = 10
    style.corner_radius_top_right = 10
    style.corner_radius_bottom_left = 10
    style.corner_radius_bottom_right = 10
    style.border_width_left = 1
    style.border_width_right = 1
    style.border_width_top = 1
    style.border_width_bottom = 1
    style.border_color = Color(0.65, 0.72, 0.66, 0.6)
    return style

func _show_menu():
    var panel = Panel.new()
    panel.name = "MenuPanel"
    panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    panel.add_theme_stylebox_override("panel", _button_style(Color(0.025, 0.04, 0.035, 0.96)))
    hud_layer.add_child(panel)
    var title = Label.new()
    title.text = "OPERATION: LAST FRONT"
    title.add_theme_font_size_override("font_size", 38)
    title.position = Vector2(70, 110)
    panel.add_child(title)
    var subtitle = Label.new()
    subtitle.text = "ZONA URBANA // OPERACIÓN INDIVIDUAL"
    subtitle.position = Vector2(75, 165)
    subtitle.add_theme_font_size_override("font_size", 18)
    panel.add_child(subtitle)
    var play = Button.new()
    play.text = "JUGAR"
    play.position = Vector2(75, 235)
    play.size = Vector2(240, 64)
    play.add_theme_font_size_override("font_size", 24)
    panel.add_child(play)
    play.pressed.connect(func():
        panel.queue_free()
        started = true
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if not OS.has_feature("mobile") else Input.MOUSE_MODE_VISIBLE
        update_status()
    )
    var note = Label.new()
    note.text = "Prototipo móvil: desliza para mirar y usa los controles táctiles."
    note.position = Vector2(75, 325)
    panel.add_child(note)

func update_status():
    if not is_instance_valid(health_label):
        return
    health_label.text = "SALUD " + str(player.health)
    ammo_label.text = str(player.ammo) + " / " + str(player.reserve_ammo)
    score_label.text = "BAJAS " + str(score)
    var remaining = get_tree().get_nodes_in_group("bots").size()
    status_label.text = "ENEMIGOS RESTANTES: " + str(remaining)

func bot_eliminated():
    score += 1
    update_status()
    if get_tree().get_nodes_in_group("bots").is_empty():
        status_label.text = "ZONA ASEGURADA // MISIÓN COMPLETADA"

func _toggle_pause():
    paused = not paused
    get_tree().paused = paused
    if paused:
        var pause_panel = Panel.new()
        pause_panel.name = "PausePanel"
        pause_panel.process_mode = Node.PROCESS_MODE_ALWAYS
        pause_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
        pause_panel.position = Vector2(-180, -100)
        pause_panel.size = Vector2(360, 200)
        pause_panel.add_theme_stylebox_override("panel", _button_style(Color(0.02, 0.04, 0.03, 0.96)))
        hud_layer.add_child(pause_panel)
        var resume = Button.new()
        resume.text = "CONTINUAR"
        resume.position = Vector2(60, 70)
        resume.size = Vector2(240, 55)
        pause_panel.add_child(resume)
        resume.pressed.connect(func():
            get_tree().paused = false
            paused = false
            pause_panel.queue_free()
        )
    else:
        get_tree().paused = false

func _notification(what):
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT and OS.has_feature("mobile"):
        pass
