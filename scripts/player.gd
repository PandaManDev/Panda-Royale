extends CharacterBody3D

var game
var health := 100.0
var shield := 50.0
var ammo := 0
var reserve_ammo := 0
var has_weapon := false
var weapon_name := "Unarmed"
var weapon_rarity := "COMMON"
var weapon_damage := 34.0
var weapon_fire_interval := 0.105
var xp := 0
var level := 1
var wood := 100
var build_mode := false
var move_speed := 7.5
var sprint_speed := 11.0
var jump_velocity := 5.2
var gravity := 19.0
var mouse_sensitivity := 0.0018
var pitch := 0.0
var fire_cooldown := 0.0
var reload_time := 0.0
var camera: Camera3D
var weapon: MeshInstance3D
var muzzle_flash: OmniLight3D
var hit_label: Label
var rng = RandomNumberGenerator.new()

func _ready():
    rng.randomize()
    var capsule = CapsuleShape3D.new()
    capsule.radius = 0.42
    capsule.height = 1.8
    var collision = CollisionShape3D.new()
    collision.shape = capsule
    collision.position.y = 0.9
    add_child(collision)

    camera = Camera3D.new()
    camera.position = Vector3(0, 1.58, 0)
    camera.current = true
    camera.fov = 82
    add_child(camera)

    # visible first-person rifle made from simple original geometry
    weapon = MeshInstance3D.new()
    var gun = BoxMesh.new()
    gun.size = Vector3(0.22, 0.22, 0.82)
    weapon.mesh = gun
    var mat = StandardMaterial3D.new()
    mat.albedo_color = Color(0.10,0.13,0.15)
    mat.metallic = 0.72
    mat.roughness = 0.3
    weapon.material_override = mat
    weapon.visible = false
    weapon.position = Vector3(0.34, -0.28, -0.62)
    camera.add_child(weapon)

    var barrel = MeshInstance3D.new()
    var barrel_mesh = CylinderMesh.new()
    barrel_mesh.top_radius = 0.055
    barrel_mesh.bottom_radius = 0.055
    barrel_mesh.height = 0.45
    barrel.mesh = barrel_mesh
    barrel.rotation.x = PI/2
    barrel.position = Vector3(0.34, -0.25, -1.05)
    barrel.material_override = mat
    barrel.visible = false
    camera.add_child(barrel)

    muzzle_flash = OmniLight3D.new()
    muzzle_flash.light_color = Color(1,0.58,0.18)
    muzzle_flash.light_energy = 0.0
    muzzle_flash.omni_range = 4
    muzzle_flash.position = Vector3(0.34,-0.25,-1.25)
    camera.add_child(muzzle_flash)

func _unhandled_input(event):
    if not is_instance_valid(game) or not game.game_started or game.paused or game.match_over:
        return
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and health > 0:
        rotate_y(-event.relative.x * mouse_sensitivity)
        pitch = clamp(pitch - event.relative.y * mouse_sensitivity, -1.48, 1.48)
        camera.rotation.x = pitch
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        if build_mode:
            if is_instance_valid(game):
                game.place_build_wall(self)
        else:
            fire()
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_R:
            reload_weapon()
        elif event.keycode == KEY_B:
            build_mode = not build_mode
        elif event.keycode == KEY_E:
            if is_instance_valid(game):
                game.try_open_chest(self)

func _physics_process(delta):
    if not is_instance_valid(game) or not game.game_started or game.paused or game.match_over:
        return
    fire_cooldown = max(0.0, fire_cooldown - delta)
    muzzle_flash.light_energy = max(0.0, muzzle_flash.light_energy - delta * 18.0)
    if reload_time > 0:
        reload_time -= delta
        if reload_time <= 0:
            var amount = min(30-ammo, reserve_ammo)
            ammo += amount
            reserve_ammo -= amount

    if not is_on_floor():
        velocity.y -= gravity * delta
    else:
        if Input.is_key_pressed(KEY_SPACE):
            velocity.y = jump_velocity

    var input_dir = Vector2(
        float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
        float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
    ).normalized()
    var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
    var speed = sprint_speed if Input.is_key_pressed(KEY_SHIFT) else move_speed
    if direction:
        velocity.x = direction.x * speed
        velocity.z = direction.z * speed
    else:
        velocity.x = move_toward(velocity.x, 0, move_speed * 5.0 * delta)
        velocity.z = move_toward(velocity.z, 0, move_speed * 5.0 * delta)
    move_and_slide()

func fire():
    if not has_weapon:
        return
    if fire_cooldown > 0 or reload_time > 0 or ammo <= 0 or health <= 0:
        if ammo <= 0:
            reload_weapon()
        return
    ammo -= 1
    fire_cooldown = weapon_fire_interval
    muzzle_flash.light_energy = 4.5
    weapon.position.z = -0.50
    var tween = create_tween()
    tween.tween_property(weapon, "position:z", -0.62, 0.07)
    var from = camera.global_position
    var to = from + (-camera.global_transform.basis.z * 180.0)
    var query = PhysicsRayQueryParameters3D.create(from, to)
    query.exclude = [self]
    query.collide_with_areas = true
    var result = get_world_3d().direct_space_state.intersect_ray(query)
    if result:
        var hit = result.collider
        if hit and hit.get_parent() and hit.get_parent().has_method("receive_damage"):
            hit.get_parent().receive_damage(weapon_damage)
        elif hit.has_method("receive_damage"):
            hit.receive_damage(weapon_damage)
        elif hit is CharacterBody3D and hit != self and hit.has_meta("bot"):
            game.damage_bot(hit, weapon_damage)

func reload_weapon():
    if has_weapon and reload_time <= 0 and ammo < 30 and reserve_ammo > 0:
        reload_time = 1.35

func take_damage(amount: float, bypass_shield := false):
    if not bypass_shield and shield > 0:
        var absorbed = min(shield, amount)
        shield -= absorbed
        amount -= absorbed
    health -= amount
    if health < 0:
        health = 0

func add_loot(kind: String, rarity: String = "COMMON"):
    var loot_scale := 1.0
    match rarity:
        "RARE":
            loot_scale = 1.25
        "EPIC":
            loot_scale = 1.6
        "LEGENDARY":
            loot_scale = 2.0
    match kind:
        "health":
            health = min(100.0, health + 30.0 * loot_scale)
        "shield":
            shield = min(100.0, shield + 30.0 * loot_scale)
        "ammo":
            reserve_ammo += int(round(45.0 * loot_scale))
        "weapon":
            var damage_by_rarity := {"COMMON": 34.0, "RARE": 39.0, "EPIC": 45.0, "LEGENDARY": 52.0}
            var interval_by_rarity := {"COMMON": 0.105, "RARE": 0.10, "EPIC": 0.095, "LEGENDARY": 0.09}
            # A higher-tier rifle replaces a lower-tier rifle, never downgrades it.
            var rarity_rank := {"COMMON": 0, "RARE": 1, "EPIC": 2, "LEGENDARY": 3}
            if not has_weapon or int(rarity_rank.get(rarity, 0)) >= int(rarity_rank.get(weapon_rarity, 0)):
                weapon_rarity = rarity
                weapon_damage = float(damage_by_rarity.get(rarity, 34.0))
                weapon_fire_interval = float(interval_by_rarity.get(rarity, 0.105))
                weapon_name = "%s Ranger Rifle" % rarity.capitalize()
            has_weapon = true
            ammo = max(ammo, 30)
            reserve_ammo += int(round(60.0 * loot_scale))
            weapon.visible = true
            for child in camera.get_children():
                if child is MeshInstance3D and child != weapon:
                    child.visible = true
