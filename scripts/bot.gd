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
    add_child(head_mesh)

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
    if health <= 0 or not is_instance_valid(game) or not is_instance_valid(game.player) or game.match_over:
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

    if distance < 32 and attack_timer <= 0:
        attack_timer = rng.randf_range(0.75,1.35)
        # accuracy gets worse with range; keep bots challenging but fair
        var chance = clamp(0.72 - distance/55.0, 0.12, 0.62)
        if rng.randf() < chance:
            player.take_damage(rng.randf_range(5.0,10.0))

func receive_damage(amount: float):
    health -= amount
    if health <= 0:
        queue_free()
