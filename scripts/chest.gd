extends Area3D
var opened := false
var lid_mesh: MeshInstance3D
func _ready():
    name = "TreasureChest"
    var collision = CollisionShape3D.new()
    var shape = BoxShape3D.new()
    shape.size = Vector3(1.7, 1.2, 1.4)
    collision.shape = shape
    collision.position.y = 0.6
    add_child(collision)
    var wood = StandardMaterial3D.new()
    wood.albedo_color = Color(0.30, 0.15, 0.075)
    var gold = StandardMaterial3D.new()
    gold.albedo_color = Color(1.0, 0.65, 0.12)
    gold.metallic = 0.65
    gold.emission_enabled = true
    gold.emission = Color(0.38, 0.15, 0.015)
    var body_mesh = MeshInstance3D.new()
    var body = BoxMesh.new()
    body.size = Vector3(1.35, 0.72, 1.05)
    body_mesh.mesh = body
    body_mesh.material_override = wood
    body_mesh.position.y = 0.48
    add_child(body_mesh)
    lid_mesh = MeshInstance3D.new()
    var lid = BoxMesh.new()
    lid.size = Vector3(1.42, 0.22, 1.12)
    lid_mesh.mesh = lid
    lid_mesh.material_override = gold
    lid_mesh.position = Vector3(0, 0.96, 0)
    add_child(lid_mesh)
    var band = MeshInstance3D.new()
    var band_mesh = BoxMesh.new()
    band_mesh.size = Vector3(0.18, 0.82, 1.14)
    band.mesh = band_mesh
    band.material_override = gold
    band.position.y = 0.56
    add_child(band)
    var prompt = Label3D.new()
    prompt.text = "CHEST • PRESS E"
    prompt.font_size = 36
    prompt.pixel_size = 0.006
    prompt.position.y = 1.7
    prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    add_child(prompt)
func open_for_player(opener):
    if opened or not is_instance_valid(opener) or global_position.distance_to(opener.global_position) > 3.2:
        return
    opened = true
    lid_mesh.rotation.x = -0.85
    var reward = ["weapon", "ammo", "health", "shield"][randi() % 4]
    opener.add_loot(reward)
    if reward in ["weapon", "ammo"]:
        opener.add_loot("ammo")
    queue_free()
