extends CharacterBody3D

var game
var health := 100.0
var speed := 3.8
var gravity := 19.0
var attack_timer := 0.0
var strafe_timer := 0.0
var strafe_dir := 1.0
var player
var body_mesh: MeshInstance3D
var head_mesh: MeshInstance3D
var rng = RandomNumberGenerator.new()

func _ready():
    rng.randomize()
    set_meta("bot", true)
    var shape = CapsuleShape3D.new()
    shape.radius = 0.48
    shape.height = 1.9
    var col = CollisionShape3D.new()
    col.shape = shape
    col.position.y = 0.95
    add_child(col)

    body_mesh = MeshInstance3D.new()
    var capsule = CapsuleMesh.new()
    capsule.radius = 0.47
    capsule.height = 1.75
    body_mesh.mesh = capsule
    var mat = StandardMaterial3D.new()
    mat.albedo_color = [Color(0.55,0.20,0.16), Color(0.17,0.32,0.48), Color(0.54,0.42,0.18), Color(0.22,0.39,0.28)][rng.randi_range(0,3)]
    mat.roughness = 0.72
    body_mesh.material_override = mat
    body_mesh.position.y = 0.92
    add_child(body_mesh)

    head_mesh = MeshInstance3D.new()
    var sphere = SphereMesh.new()
    sphere.radius = 0.32
    sphere.height = 0.64
    head_mesh.mesh = sphere
    var headmat = StandardMaterial3D.new()
    headmat.albedo_color = Color(0.72,0.59,0.46)
    head_mesh.material_override = headmat
    head_mesh.position.y = 2.02
    head_mesh.scale = Vector3(0.95, 1.05, 0.95)
    add_child(head_mesh)
    var accent = StandardMaterial3D.new()
    accent.albedo_color = mat.albedo_color.lightened(0.22)
    var dark = StandardMaterial3D.new()
    dark.albedo_color = Color(0.075, 0.085, 0.10)
    for side in [-1.0, 1.0]:
        var arm = MeshInstance3D.new()
        var arm_mesh = CapsuleMesh.new()
        arm_mesh.radius = 0.14
        arm_mesh.height = 0.86
        arm.mesh = arm_mesh
        arm.material_override = accent
        arm.position = Vector3(side * 0.43, 1.05, 0)
        add_child(arm)
        var leg = MeshInstance3D.new()
        var leg_mesh = CapsuleMesh.new()
        leg_mesh.radius = 0.17
        leg_mesh.height = 0.82
        leg.mesh = leg_mesh
        leg.material_override = dark
        leg.position = Vector3(side * 0.19, 0.42, 0)
        add_child(leg)
        var boot = MeshInstance3D.new()
        var boot_mesh = BoxMesh.new()
        boot_mesh.size = Vector3(0.32, 0.18, 0.43)
        boot.mesh = boot_mesh
        boot.material_override = dark
        boot.position = Vector3(side * 0.19, 0.11, -0.08)
        add_child(boot)

    # dark tactical vest
    var vest = MeshInstance3D.new()
    var vestbox = BoxMesh.new()
    vestbox.size = Vector3(0.72,0.65,0.48)
    vest.mesh = vestbox
    var vestmat = StandardMaterial3D.new()
    vestmat.albedo_color = Color(0.09,0.12,0.13)
    vest.material_override = vestmat
    vest.position = Vector3(0,1.02,0)
    add_child(vest)

func _physics_process(delta):
    if health <= 0 or not is_instance_valid(game) or not is_instance_valid(game.player) or game.match_over or not game.game_started or game.paused:
        return
    player = game.player
    var target = player.global_position
    var offset = target - global_position
    var flat = Vector3(offset.x,0,offset.z)
    var distance = flat.length()
    attack_timer -= delta
    strafe_timer -= delta
    if strafe_timer <= 0:
        strafe_timer = rng.randf_range(1.2,3.0)
        strafe_dir = -1.0 if rng.randf() < 0.5 else 1.0

    if distance > 10:
        var dir = flat.normalized()
        velocity.x = dir.x * speed
        velocity.z = dir.z * speed
        look_at(Vector3(target.x, global_position.y, target.z), Vector3.UP)
    elif distance > 3.0:
        var dir = (flat.normalized() * 0.2 + Vector3(-flat.z,0,flat.x).normalized() * strafe_dir).normalized()
        velocity.x = dir.x * speed * 0.7
        velocity.z = dir.z * speed * 0.7
        look_at(Vector3(target.x, global_position.y, target.z), Vector3.UP)
    else:
        velocity.x = move_toward(velocity.x,0,12*delta)
        velocity.z = move_toward(velocity.z,0,12*delta)
        look_at(Vector3(target.x, global_position.y, target.z), Vector3.UP)

    if not is_on_floor():
        velocity.y -= gravity * delta
    move_and_slide()

    # Bots should not shoot through solid buildings or terrain. Cast from the
    # upper body toward the player and attack only if the player is visible.
    if distance < 32.0 and attack_timer <= 0.0:
        attack_timer = rng.randf_range(0.8, 1.4)
        var sight_from := global_position + Vector3.UP * 1.45
        var sight_to := player.global_position + Vector3.UP * 1.1
        var sight_query := PhysicsRayQueryParameters3D.create(sight_from, sight_to)
        sight_query.exclude = [self]
        sight_query.collide_with_areas = false
        var sight_hit := get_world_3d().direct_space_state.intersect_ray(sight_query)
        var can_see_player := sight_hit.is_empty() or sight_hit.get("collider") == player
        if can_see_player:
            # Accuracy falls with distance, keeping bots readable and fair.
            var chance := clamp(0.62 - distance / 58.0, 0.08, 0.52)
            if rng.randf() < chance:
                player.take_damage(rng.randf_range(4.0, 8.0))

func receive_damage(amount: float):
    health -= amount
    if health <= 0:
        queue_free()
