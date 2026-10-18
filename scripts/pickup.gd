extends Area3D

var game
var kind := "ammo"
var bob_time := 0.0
var mesh_node: MeshInstance3D

func _ready():
    var choices = ["health","shield","ammo"]
    kind = choices[randi() % choices.size()]
    var shape = SphereShape3D.new()
    shape.radius = 1.35
    var collision = CollisionShape3D.new()
    collision.shape = shape
    add_child(collision)

    mesh_node = MeshInstance3D.new()
    var mesh = BoxMesh.new()
    mesh.size = Vector3(0.7,0.7,0.7)
    mesh_node.mesh = mesh
    var mat = StandardMaterial3D.new()
    if kind == "health":
        mat.albedo_color = Color(0.16,0.9,0.38)
        mat.emission_enabled = true
        mat.emission = Color(0.04,0.35,0.10)
    elif kind == "shield":
        mat.albedo_color = Color(0.12,0.55,1.0)
        mat.emission_enabled = true
        mat.emission = Color(0.02,0.18,0.5)
    else:
        mat.albedo_color = Color(1.0,0.68,0.12)
        mat.emission_enabled = true
        mat.emission = Color(0.45,0.2,0.01)
    mesh_node.material_override = mat
    add_child(mesh_node)

    var label = Label3D.new()
    label.text = kind.to_upper()
    label.font_size = 48
    label.pixel_size = 0.005
    label.position.y = 0.8
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.modulate = Color(1,1,1)
    add_child(label)

    body_entered.connect(_on_body_entered)

func _process(delta):
    bob_time += delta
    if mesh_node:
        mesh_node.rotation.y += delta * 1.1
        mesh_node.position.y = sin(bob_time*2.4)*0.12

func _on_body_entered(body):
    if body and body.has_method("add_loot"):
        body.add_loot(kind)
        queue_free()
