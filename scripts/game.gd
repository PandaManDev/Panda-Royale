extends Node3D

const PLAYER_SCRIPT = preload("res://scripts/player.gd")
const BOT_SCRIPT = preload("res://scripts/bot.gd")
const PICKUP_SCRIPT = preload("res://scripts/pickup.gd")

var player
var bots: Array = []
var safe_radius := 95.0
var zone_timer := 0.0
var match_over := false
var hud: Control
var status_label: Label
var health_label: Label
var ammo_label: Label
var alive_label: Label
var zone_label: Label
var center_marker: MeshInstance3D
var zone_ring: MeshInstance3D
var world_env: WorldEnvironment
var game_started := false
var paused := false
var menu_layer: Control
var main_menu: PanelContainer
var pause_menu: PanelContainer
var settings_menu: PanelContainer
var settings_return_to_pause := false
var crosshair_label: Label

func _ready():
    randomize()
    _build_world()
    _build_zone_ring()
    _spawn_player()
    _spawn_bots(12)
    _build_hud()
    _build_menus()
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _process(delta):
    if match_over or not game_started or paused:
        return
    zone_timer += delta
    if zone_timer > 18.0:
        safe_radius = max(12.0, safe_radius - delta * 1.15)
    if zone_ring:
        zone_ring.position.y = 0.12
        zone_ring.scale = Vector3(safe_radius / 95.0, 1.0, safe_radius / 95.0)
    if player:
        var dist = Vector2(player.global_position.x, player.global_position.z).length()
        if dist > safe_radius:
            player.take_damage(7.0 * delta, false)
        _update_hud()
    bots = bots.filter(func(b): return is_instance_valid(b) and b.health > 0)
    if bots.size() == 0 and not match_over:
        _finish_match(true)
    if player and player.health <= 0:
        _finish_match(false)

func _unhandled_input(event):
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
        if game_started and not match_over:
            if settings_menu and settings_menu.visible:
                _close_settings()
            elif paused:
                _resume_game()
            else:
                _pause_game()
    if event is InputEventMouseButton and event.pressed and not match_over and game_started and not paused:
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _build_world():
    var env = Environment.new()
    env.background_mode = Environment.BG_SKY
    var sky = Sky.new()
    var sky_mat = ProceduralSkyMaterial.new()
    sky_mat.sky_top_color = Color(0.09, 0.18, 0.30)
    sky_mat.sky_horizon_color = Color(0.68, 0.76, 0.82)
    sky_mat.ground_bottom_color = Color(0.07, 0.09, 0.08)
    sky_mat.ground_horizon_color = Color(0.34, 0.40, 0.34)
    sky.sky_material = sky_mat
    env.sky = sky
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.58, 0.65, 0.72)
    env.ambient_light_energy = 0.7
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    world_env = WorldEnvironment.new()
    world_env.environment = env
    add_child(world_env)

    var sun = DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-48, -28, 0)
    sun.light_energy = 1.35
    sun.shadow_enabled = true
    add_child(sun)

    _make_box("Ground", Vector3(0, -1.0, 0), Vector3(220, 2, 220), Color(0.20, 0.29, 0.20), true)
    # Outer cliffs and landmark hills
    for i in range(18):
        var angle = TAU * float(i) / 18.0
        var r = randf_range(101, 112)
        var p = Vector3(cos(angle) * r, randf_range(4, 10), sin(angle) * r)
        _make_box("Rock Ridge", p, Vector3(randf_range(12, 22), randf_range(12, 24), randf_range(10, 18)), Color(0.22, 0.27, 0.27), true, randf_range(-0.5, 0.5))
    # Roads
    _make_box("North Road", Vector3(0, 0.02, -28), Vector3(220, 0.08, 8), Color(0.18, 0.19, 0.18), true)
    _make_box("East Road", Vector3(28, 0.025, 0), Vector3(8, 0.09, 220), Color(0.18, 0.19, 0.18), true)
    # POIs and cover
    var colors = [Color(0.42,0.31,0.23), Color(0.32,0.39,0.43), Color(0.45,0.43,0.34), Color(0.28,0.37,0.30)]
    for i in range(25):
        var p = _random_point(78)
        if Vector2(p.x, p.z).length() < 12:
            p.x += 22
        var w = randf_range(5.0, 10.0)
        var d = randf_range(5.0, 10.0)
        var h = randf_range(3.5, 7.5)
        _make_box("Abandoned Building", Vector3(p.x, h/2.0, p.z), Vector3(w,h,d), colors[randi() % colors.size()], true, randf_range(-0.15,0.15))
        _make_box("Roof", Vector3(p.x, h+0.18, p.z), Vector3(w+0.5,0.35,d+0.5), Color(0.17,0.19,0.20), true, randf_range(-0.15,0.15))
        if randf() < 0.65:
            var crate_pos = p + Vector3(randf_range(-8,8), 0.9, randf_range(-8,8))
            _make_box("Supply Crate", crate_pos, Vector3(1.8,1.8,1.8), Color(0.42,0.30,0.15), true)
    # Trees
    for i in range(110):
        var p = _random_point(94)
        if abs(p.x) < 7 or abs(p.z) < 7:
            continue
        var trunk = _make_box("Tree Trunk", Vector3(p.x, 1.5, p.z), Vector3(0.8,3.0,0.8), Color(0.25,0.17,0.10), true)
        var crown = _make_sphere("Pine Crown", Vector3(p.x, 4.0, p.z), 2.3, Color(0.10,0.23,0.15), false)
    # central radio tower landmark
    _make_box("Radio Tower Base", Vector3(0, 2, 0), Vector3(2,4,2), Color(0.23,0.26,0.27), true)
    for y in [4.0, 7.0, 10.0]:
        _make_box("Radio Tower Crossbar", Vector3(0,y,0), Vector3(5,0.25,0.25), Color(0.65,0.20,0.16), true)
        _make_box("Radio Tower Crossbar", Vector3(0,y,0), Vector3(0.25,0.25,5), Color(0.65,0.20,0.16), true)

func _build_zone_ring():
    zone_ring = MeshInstance3D.new()
    var mesh = CylinderMesh.new()
    mesh.top_radius = 95.0
    mesh.bottom_radius = 95.0
    mesh.height = 0.18
    zone_ring.mesh = mesh
    var mat = StandardMaterial3D.new()
    mat.albedo_color = Color(0.12, 0.65, 1.0, 0.16)
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.emission_enabled = true
    mat.emission = Color(0.06, 0.42, 1.0)
    mat.emission_energy_multiplier = 0.7
    zone_ring.material_override = mat
    zone_ring.position.y = 0.12
    add_child(zone_ring)

func _spawn_player():
    player = CharacterBody3D.new()
    player.set_script(PLAYER_SCRIPT)
    player.name = "Player"
    player.position = Vector3(0, 2, 14)
    add_child(player)
    player.game = self

func _spawn_bots(count: int):
    for i in range(count):
        var bot = CharacterBody3D.new()
        bot.set_script(BOT_SCRIPT)
        bot.name = "Rival_%02d" % (i+1)
        var p = _random_point(76)
        if Vector2(p.x, p.z).length() < 15:
            p.x += 28
        bot.position = Vector3(p.x, 1.2, p.z)
        add_child(bot)
        bot.game = self
        bots.append(bot)
    # loot scattered around cover
    for i in range(26):
        var pickup = Area3D.new()
        pickup.set_script(PICKUP_SCRIPT)
        pickup.position = Vector3(_random_point(82).x, 0.9, _random_point(82).z)
        add_child(pickup)
        pickup.game = self

func _build_hud():
    hud = Control.new()
    hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(hud)

    var top = Label.new()
    top.text = "PANDA ROYALE   /   LAST ONE STANDING"
    top.position = Vector2(28, 22)
    top.add_theme_font_size_override("font_size", 22)
    top.add_theme_color_override("font_color", Color(0.93,0.96,1))
    hud.add_child(top)

    health_label = Label.new()
    health_label.position = Vector2(28, 620)
    health_label.add_theme_font_size_override("font_size", 22)
    health_label.add_theme_color_override("font_color", Color(0.45,1.0,0.63))
    hud.add_child(health_label)

    ammo_label = Label.new()
    ammo_label.position = Vector2(28, 655)
    ammo_label.add_theme_font_size_override("font_size", 18)
    ammo_label.add_theme_color_override("font_color", Color(0.93,0.96,1))
    hud.add_child(ammo_label)

    alive_label = Label.new()
    alive_label.position = Vector2(990, 24)
    alive_label.size = Vector2(260, 35)
    alive_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    alive_label.add_theme_font_size_override("font_size", 21)
    alive_label.add_theme_color_override("font_color", Color(1,0.82,0.35))
    hud.add_child(alive_label)

    zone_label = Label.new()
    zone_label.position = Vector2(990, 58)
    zone_label.size = Vector2(260, 30)
    zone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    zone_label.add_theme_font_size_override("font_size", 17)
    zone_label.add_theme_color_override("font_color", Color(0.45,0.78,1))
    hud.add_child(zone_label)

    status_label = Label.new()
    status_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    status_label.position += Vector2(-300, -85)
    status_label.size = Vector2(600, 170)
    status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    status_label.add_theme_font_size_override("font_size", 32)
    status_label.add_theme_color_override("font_color", Color(1,0.88,0.5))
    hud.add_child(status_label)

    var cross = Label.new()
    cross.text = "+"
    crosshair_label = cross
    cross.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    cross.position += Vector2(-10,-19)
    cross.add_theme_font_size_override("font_size", 30)
    cross.add_theme_color_override("font_color", Color(1,1,1,0.9))
    hud.add_child(cross)

    var controls = Label.new()
    controls.text = "WASD Move   •   Mouse Aim   •   LMB Fire   •   R Reload   •   Shift Sprint   •   Space Jump   •   Esc Unlock Mouse"
    controls.position = Vector2(330, 674)
    controls.add_theme_font_size_override("font_size", 14)
    controls.add_theme_color_override("font_color", Color(0.78,0.84,0.89))
    hud.add_child(controls)

func _update_hud():
    if not player:
        return
    health_label.text = "♥  %d HP     ◆  %d SHIELD" % [int(player.health), int(player.shield)]
    ammo_label.text = "AMMO  %02d / %03d" % [player.ammo, player.reserve_ammo]
    alive_label.text = "ALIVE  %02d" % (bots.size() + (1 if player.health > 0 else 0))
    zone_label.text = "SAFE ZONE  %d m" % int(safe_radius)
    if zone_timer < 18:
        status_label.text = "SAFE ZONE SHRINKS IN %02d" % int(18-zone_timer)
    else:
        status_label.text = ""

func _finish_match(won: bool):
    match_over = true
    paused = false
    if menu_layer:
        menu_layer.visible = false
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    status_label.text = "VICTORY ROYALE!\nYou are the last one standing." if won else "ELIMINATED\nBetter luck next drop."
    status_label.add_theme_color_override("font_color", Color(1,0.82,0.30) if won else Color(1,0.35,0.32))
    var restart = Button.new()
    restart.text = "PLAY AGAIN"
    restart.position = Vector2(545, 470)
    restart.size = Vector2(190, 54)
    restart.add_theme_font_size_override("font_size", 20)
    restart.pressed.connect(func(): get_tree().reload_current_scene())
    hud.add_child(restart)

func damage_bot(bot, amount):
    if is_instance_valid(bot):
        bot.health -= amount
        if bot.health <= 0:
            bot.queue_free()
            # drop a little ammo/health pickup
            var pickup = Area3D.new()
            pickup.set_script(PICKUP_SCRIPT)
            pickup.position = bot.global_position + Vector3(0,0.8,0)
            add_child(pickup)
            pickup.game = self


func _build_menus():
    menu_layer = Control.new()
    menu_layer.name = "MenuLayer"
    menu_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    menu_layer.mouse_filter = Control.MOUSE_FILTER_STOP
    menu_layer.process_mode = Node.PROCESS_MODE_ALWAYS
    hud.add_child(menu_layer)

    main_menu = _create_menu_panel("MainMenu", Vector2(560, 560))
    menu_layer.add_child(main_menu)
    var main_box = _menu_box(main_menu)
    _menu_label(main_box, "PANDA ROYALE", 38, Color(0.78, 0.91, 1.0), true)
    _menu_label(main_box, "DROP IN. LOOT UP. BE THE LAST PANDA STANDING.", 12, Color(0.68, 0.76, 0.86), false)
    _menu_spacer(main_box, 8)
    _menu_label(main_box, "SEASON ZERO  •  ISLAND TEST BUILD", 13, Color(0.35, 0.82, 1.0), true)
    _menu_spacer(main_box, 14)
    _menu_button(main_box, "PLAY", _start_match, true)
    _menu_button(main_box, "SETTINGS", _open_settings, false)
    _menu_button(main_box, "HOW TO PLAY", _show_controls, false)
    _menu_button(main_box, "QUIT GAME", _quit_game, false)
    _menu_spacer(main_box, 8)
    _menu_label(main_box, "WASD MOVE  •  SHIFT SPRINT  •  SPACE JUMP  •  MOUSE AIM", 11, Color(0.63, 0.70, 0.78), false)

    pause_menu = _create_menu_panel("PauseMenu", Vector2(480, 420))
    menu_layer.add_child(pause_menu)
    var pause_box = _menu_box(pause_menu)
    _menu_label(pause_box, "MATCH PAUSED", 32, Color(0.85, 0.94, 1.0), true)
    _menu_label(pause_box, "Take a breath. The island can wait.", 13, Color(0.68, 0.76, 0.86), false)
    _menu_spacer(pause_box, 12)
    _menu_button(pause_box, "RESUME MATCH", _resume_game, true)
    _menu_button(pause_box, "SETTINGS", _open_settings_from_pause, false)
    _menu_button(pause_box, "RESTART MATCH", _restart_match, false)
    _menu_button(pause_box, "MAIN MENU", _return_to_main_menu, false)
    pause_menu.visible = false

    settings_menu = _create_menu_panel("SettingsMenu", Vector2(560, 520))
    menu_layer.add_child(settings_menu)
    var settings_box = _menu_box(settings_menu)
    _menu_label(settings_box, "GAME SETTINGS", 32, Color(0.85, 0.94, 1.0), true)
    _menu_label(settings_box, "Tune your aim and your view.", 13, Color(0.68, 0.76, 0.86), false)
    _menu_spacer(settings_box, 8)

    var sensitivity_title = Label.new()
    sensitivity_title.text = "MOUSE SENSITIVITY"
    sensitivity_title.add_theme_font_size_override("font_size", 13)
    sensitivity_title.add_theme_color_override("font_color", Color(0.78, 0.86, 0.94))
    settings_box.add_child(sensitivity_title)
    var sensitivity = HSlider.new()
    sensitivity.min_value = 0.0008
    sensitivity.max_value = 0.004
    sensitivity.step = 0.0001
    sensitivity.value = player.mouse_sensitivity
    sensitivity.custom_minimum_size = Vector2(360, 28)
    sensitivity.value_changed.connect(_set_sensitivity)
    settings_box.add_child(sensitivity)

    var fov_title = Label.new()
    fov_title.text = "FIELD OF VIEW"
    fov_title.add_theme_font_size_override("font_size", 13)
    fov_title.add_theme_color_override("font_color", Color(0.78, 0.86, 0.94))
    settings_box.add_child(fov_title)
    var fov_slider = HSlider.new()
    fov_slider.min_value = 70
    fov_slider.max_value = 105
    fov_slider.step = 1
    fov_slider.value = player.camera.fov
    fov_slider.custom_minimum_size = Vector2(360, 28)
    fov_slider.value_changed.connect(_set_fov)
    settings_box.add_child(fov_slider)

    var crosshair_toggle = CheckButton.new()
    crosshair_toggle.text = "Show crosshair"
    crosshair_toggle.button_pressed = true
    crosshair_toggle.add_theme_color_override("font_color", Color(0.85, 0.91, 0.98))
    crosshair_toggle.toggled.connect(_set_crosshair_visible)
    settings_box.add_child(crosshair_toggle)
    _menu_spacer(settings_box, 8)
    _menu_button(settings_box, "BACK", _close_settings, true)
    settings_menu.visible = false

func _create_menu_panel(panel_name: String, panel_size: Vector2) -> PanelContainer:
    var panel = PanelContainer.new()
    panel.name = panel_name
    panel.anchor_left = 0.5
    panel.anchor_top = 0.5
    panel.anchor_right = 0.5
    panel.anchor_bottom = 0.5
    panel.offset_left = -panel_size.x / 2.0
    panel.offset_top = -panel_size.y / 2.0
    panel.offset_right = panel_size.x / 2.0
    panel.offset_bottom = panel_size.y / 2.0
    panel.add_theme_stylebox_override("panel", _panel_style())
    panel.add_theme_constant_override("panel", 28)
    return panel

func _panel_style() -> StyleBoxFlat:
    var style = StyleBoxFlat.new()
    style.bg_color = Color(0.035, 0.055, 0.09, 0.97)
    style.border_color = Color(0.20, 0.65, 0.95, 0.95)
    style.set_border_width_all(2)
    style.set_corner_radius_all(12)
    style.content_margin_left = 26
    style.content_margin_right = 26
    style.content_margin_top = 22
    style.content_margin_bottom = 22
    return style

func _menu_box(panel: PanelContainer) -> VBoxContainer:
    var box = VBoxContainer.new()
    box.alignment = BoxContainer.ALIGNMENT_CENTER
    box.add_theme_constant_override("separation", 10)
    panel.add_child(box)
    return box

func _menu_label(parent: Node, text_value: String, font_size: int, color: Color, centered: bool):
    var label = Label.new()
    label.text = text_value
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", color)
    parent.add_child(label)

func _menu_spacer(parent: Node, pixels: float):
    var spacer = Control.new()
    spacer.custom_minimum_size = Vector2(1, pixels)
    parent.add_child(spacer)

func _menu_button(parent: Node, label_text: String, action: Callable, primary: bool):
    var button = Button.new()
    button.text = label_text
    button.custom_minimum_size = Vector2(360, 48)
    button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    button.add_theme_font_size_override("font_size", 16)
    button.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0))
    var normal = StyleBoxFlat.new()
    normal.bg_color = Color(0.06, 0.42, 0.68, 1.0) if primary else Color(0.10, 0.15, 0.22, 1.0)
    normal.border_color = Color(0.22, 0.78, 1.0, 1.0) if primary else Color(0.25, 0.36, 0.48, 1.0)
    normal.set_border_width_all(1)
    normal.set_corner_radius_all(7)
    var hover = normal.duplicate()
    hover.bg_color = Color(0.08, 0.56, 0.84, 1.0) if primary else Color(0.16, 0.25, 0.36, 1.0)
    button.add_theme_stylebox_override("normal", normal)
    button.add_theme_stylebox_override("hover", hover)
    button.add_theme_stylebox_override("pressed", hover)
    button.pressed.connect(action)
    parent.add_child(button)

func _start_match():
    game_started = true
    paused = false
    main_menu.visible = false
    pause_menu.visible = false
    settings_menu.visible = false
    menu_layer.visible = false
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _pause_game():
    if not game_started or match_over:
        return
    paused = true
    pause_menu.visible = true
    menu_layer.visible = true
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _resume_game():
    paused = false
    pause_menu.visible = false
    settings_menu.visible = false
    menu_layer.visible = false
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _restart_match():
    get_tree().reload_current_scene()

func _return_to_main_menu():
    get_tree().reload_current_scene()

func _open_settings():
    settings_return_to_pause = false
    main_menu.visible = false
    pause_menu.visible = false
    settings_menu.visible = true

func _open_settings_from_pause():
    settings_return_to_pause = true
    pause_menu.visible = false
    settings_menu.visible = true

func _close_settings():
    settings_menu.visible = false
    if game_started and settings_return_to_pause:
        pause_menu.visible = true
    elif game_started:
        _resume_game()
    else:
        main_menu.visible = true

func _set_sensitivity(value: float):
    if player:
        player.mouse_sensitivity = value

func _set_fov(value: float):
    if player and player.camera:
        player.camera.fov = value

func _set_crosshair_visible(value: bool):
    if crosshair_label:
        crosshair_label.visible = value

func _show_controls():
    var dialog = AcceptDialog.new()
    dialog.title = "HOW TO PLAY"
    dialog.dialog_text = "WASD: move     Mouse: aim     Left Click: fire\nR: reload     Shift: sprint     Space: jump\nEsc: pause or resume     Find loot to restore health, shield, and ammo.\nStay inside the glowing safe zone as it shrinks."
    dialog.process_mode = Node.PROCESS_MODE_ALWAYS
    menu_layer.add_child(dialog)
    dialog.popup_centered(Vector2i(520, 250))

func _quit_game():
    get_tree().quit()

func _make_box(label, pos, size, color, collision := true, yaw := 0.0):
    var body = StaticBody3D.new() if collision else Node3D.new()
    body.name = label
    body.position = pos
    body.rotation.y = yaw
    var mesh = MeshInstance3D.new()
    var box = BoxMesh.new()
    box.size = size
    mesh.mesh = box
    var mat = StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.88
    mesh.material_override = mat
    body.add_child(mesh)
    if collision:
        var shape = CollisionShape3D.new()
        var box_shape = BoxShape3D.new()
        box_shape.size = size
        shape.shape = box_shape
        body.add_child(shape)
    add_child(body)
    return body

func _make_sphere(label, pos, radius, color, collision := false):
    var node = StaticBody3D.new() if collision else Node3D.new()
    node.name = label
    node.position = pos
    var mesh = MeshInstance3D.new()
    var sphere = SphereMesh.new()
    sphere.radius = radius
    sphere.height = radius * 2.0
    mesh.mesh = sphere
    var mat = StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.95
    mesh.material_override = mat
    node.add_child(mesh)
    if collision:
        var shape = CollisionShape3D.new()
        var s = SphereShape3D.new()
        s.radius = radius
        shape.shape = s
        node.add_child(shape)
    add_child(node)
    return node

func _random_point(radius: float) -> Vector3:
    var angle = randf() * TAU
    var r = sqrt(randf()) * radius
    return Vector3(cos(angle)*r, 0, sin(angle)*r)
