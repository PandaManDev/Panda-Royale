extends Node
## Free ENet multiplayer connection and basic player-state replication.

signal status_changed(message: String)
signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)
signal player_state_received(peer_id: int, world_position: Vector3, yaw: float)

const DEFAULT_PORT := 24560
const MAX_CLIENTS := 4

var peer: ENetMultiplayerPeer
var last_status := "Offline"
var _publish_timer := 0.0

func _ready() -> void:
    multiplayer.peer_connected.connect(_on_peer_connected)
    multiplayer.peer_disconnected.connect(_on_peer_disconnected)
    multiplayer.connected_to_server.connect(_on_connected_to_server)
    multiplayer.connection_failed.connect(_on_connection_failed)
    multiplayer.server_disconnected.connect(_on_server_disconnected)

func host_game(port: int = DEFAULT_PORT) -> Error:
    close_session()
    peer = ENetMultiplayerPeer.new()
    var error := peer.create_server(port, MAX_CLIENTS)
    if error != OK:
        peer = null
        _set_status("Could not host on port %d (error %d)." % [port, error])
        return error
    multiplayer.multiplayer_peer = peer
    _set_status("Hosting on port %d. Share your public IP and port with friends." % port)
    return OK

func join_game(address: String, port: int = DEFAULT_PORT) -> Error:
    var host := address.strip_edges()
    if host.is_empty():
        _set_status("Enter the host's IP address or hostname first.")
        return ERR_INVALID_PARAMETER
    close_session()
    peer = ENetMultiplayerPeer.new()
    var error := peer.create_client(host, port)
    if error != OK:
        peer = null
        _set_status("Could not start connection (error %d)." % error)
        return error
    multiplayer.multiplayer_peer = peer
    _set_status("Connecting to %s:%d..." % [host, port])
    return OK

func close_session() -> void:
    multiplayer.multiplayer_peer = null
    if peer:
        peer.close()
    peer = null
    _set_status("Offline")

func is_host() -> bool:
    return multiplayer.multiplayer_peer != null and multiplayer.is_server()

func publish_player_state(world_position: Vector3, yaw: float) -> void:
    if multiplayer.multiplayer_peer == null:
        return
    _publish_timer += get_process_delta_time()
    if _publish_timer < 0.05:
        return
    _publish_timer = 0.0
    if multiplayer.is_server():
        rpc("receive_player_state", multiplayer.get_unique_id(), world_position, yaw)
    else:
        rpc_id(1, "submit_player_state", world_position, yaw)

@rpc("any_peer", "unreliable")
func submit_player_state(world_position: Vector3, yaw: float) -> void:
    if not multiplayer.is_server():
        return
    var sender_id := multiplayer.get_remote_sender_id()
    rpc("receive_player_state", sender_id, world_position, yaw)

@rpc("authority", "call_local", "unreliable")
func receive_player_state(peer_id: int, world_position: Vector3, yaw: float) -> void:
    player_state_received.emit(peer_id, world_position, yaw)

func _on_peer_connected(id: int) -> void:
    peer_connected.emit(id)
    _set_status("Player %d connected." % id)

func _on_peer_disconnected(id: int) -> void:
    peer_disconnected.emit(id)
    _set_status("Player %d disconnected." % id)

func _on_connected_to_server() -> void:
    _set_status("Connected to host. Syncing player movement.")

func _on_connection_failed() -> void:
    _set_status("Connection failed. Check the address, port forwarding, and firewall.")

func _on_server_disconnected() -> void:
    _set_status("Host disconnected.")
    multiplayer.multiplayer_peer = null
    peer = null

func _set_status(message: String) -> void:
    last_status = message
    status_changed.emit(message)
