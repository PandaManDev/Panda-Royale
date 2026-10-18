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

func _ready():
    randomize()
    _build_world()
    _build_zone_ring()
    _spawn_player()
    _spawn_bots(12)
    _build_hud()
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _process(delta):
    if match_over:
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
    if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
        if not match_over:
            Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    if event is InputEventMouseButton and event.pressed and not match_over:
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
