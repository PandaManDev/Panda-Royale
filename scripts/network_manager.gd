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
var _peer_last_position: Dictionary = {}
var _peer_last_state_time: Dictionary = {}
var _peer_last_packet_time: Dictionary = {}
var _peer_strikes: Dictionary = {}
const MAX_MOVE_SPEED := 18.0
const MOVE_ALLOWANCE := 2.5
const MAX_STATE_RATE := 35.0
const MAX_STRIKES := 5
signal anti_cheat_event(peer_id: int, reason: String, strikes: int)

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
    _peer_last_position.clear()
    _peer_last_state_time.clear()
    _peer_last_packet_time.clear()
    _peer_strikes.clear()
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
    if not _validate_player_state(sender_id, world_position, yaw):
        return
    rpc("receive_player_state", sender_id, world_position, yaw)

@rpc("authority", "call_local", "unreliable")
func receive_player_state(peer_id: int, world_position: Vector3, yaw: float) -> void:
    player_state_received.emit(peer_id, world_position, yaw)


func _validate_player_state(peer_id: int, world_position: Vector3, yaw: float) -> bool:
    # Server-side sanity checks for client movement snapshots. This is a useful
    # baseline, not a substitute for server-authoritative movement/combat.
    if not world_position.is_finite() or not is_finite(yaw):
        _flag_peer(peer_id, "non-finite movement data")
        return false

    var now := Time.get_ticks_msec() / 1000.0
    var previous_packet_time := float(_peer_last_packet_time.get(peer_id, 0.0))
    if previous_packet_time > 0.0:
        var packet_interval := now - previous_packet_time
        if packet_interval < 1.0 / MAX_STATE_RATE:
            _flag_peer(peer_id, "movement updates sent too quickly")
            return false
    _peer_last_packet_time[peer_id] = now

    if _peer_last_position.has(peer_id):
        var previous: Vector3 = _peer_last_position[peer_id]
        var previous_time := float(_peer_last_state_time.get(peer_id, now))
        var elapsed := max(0.0, now - previous_time)
        var allowed_distance := MAX_MOVE_SPEED * elapsed + MOVE_ALLOWANCE
        if world_position.distance_to(previous) > allowed_distance:
            _flag_peer(peer_id, "movement speed exceeded server limit")
            return false

    # Keep incoming snapshots inside the prototype island bounds.
    if absf(world_position.x) > 125.0 or absf(world_position.z) > 125.0 or world_position.y < -20.0 or world_position.y > 80.0:
        _flag_peer(peer_id, "position outside world bounds")
        return false

    _peer_last_position[peer_id] = world_position
    _peer_last_state_time[peer_id] = now
    return true

func _flag_peer(peer_id: int, reason: String) -> void:
    var strikes := int(_peer_strikes.get(peer_id, 0)) + 1
    _peer_strikes[peer_id] = strikes
    anti_cheat_event.emit(peer_id, reason, strikes)
    push_warning("[AntiCheat] Peer %d: %s (strike %d/%d)" % [peer_id, reason, strikes, MAX_STRIKES])
    if strikes >= MAX_STRIKES and multiplayer.is_server() and multiplayer.multiplayer_peer is ENetMultiplayerPeer:
        _set_status("Disconnected peer %d after repeated invalid movement." % peer_id)
        multiplayer.multiplayer_peer.disconnect_peer(peer_id)

func _on_peer_connected(id: int) -> void:
    _peer_last_state_time[id] = Time.get_ticks_msec() / 1000.0
    _peer_last_packet_time[id] = 0.0
    _peer_strikes[id] = 0
    peer_connected.emit(id)
    _set_status("Player %d connected." % id)

func _on_peer_disconnected(id: int) -> void:
    _peer_last_position.erase(id)
    _peer_last_state_time.erase(id)
    _peer_last_packet_time.erase(id)
    _peer_strikes.erase(id)
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
