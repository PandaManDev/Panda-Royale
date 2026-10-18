extends Node
## Optional GodotSteam bridge. The game remains playable without Steam installed.
## Requires the GodotSteam GDExtension matching Godot 4.7 and a valid Steam App ID.

signal status_changed(message: String)

const DEFAULT_APP_ID := 480 # Steam Spacewar test app only; replace before any public release.
var steam: Object
var steam_available := false
var steam_initialized := false
var lobby_id: int = 0
var status := "Steam integration is not installed."

var _injected_buttons: Dictionary = {}
var _scan_timer := 0.0

func _ready() -> void:
    _try_initialize_steam()

func _process(delta: float) -> void:
    _scan_timer += delta
    if _scan_timer >= 0.5:
        _scan_timer = 0.0
        _inject_party_buttons()

func _try_initialize_steam() -> void:
    if not Engine.has_singleton("Steam"):
        _set_status("Steam invite support unavailable: add the GodotSteam GDExtension and configure your Steam App ID.")
        return

    steam = Engine.get_singleton("Steam")
    steam_available = steam != null
    if not steam_available:
        _set_status("Steam API could not be loaded.")
        return

    # GodotSteam versions expose slightly different initialization methods.
    var init_result: Variant = null
    if steam.has_method("steamInitEx"):
        init_result = steam.call("steamInitEx")
        steam_initialized = _steam_init_succeeded(init_result)
    elif steam.has_method("steamInit"):
        init_result = steam.call("steamInit")
        steam_initialized = _steam_init_succeeded(init_result)
    else:
        _set_status("GodotSteam loaded, but its initialization API is not recognized.")
        return

    if not steam_initialized:
        _set_status("Steam initialization failed. Launch Steam, configure the App ID, and restart Panda Royale.")
        return

    if steam.has_signal("lobby_created") and not steam.is_connected("lobby_created", _on_lobby_created):
        steam.connect("lobby_created", _on_lobby_created)
    if steam.has_signal("lobby_join_requested") and not steam.is_connected("lobby_join_requested", _on_lobby_join_requested):
        steam.connect("lobby_join_requested", _on_lobby_join_requested)
    _set_status("Steam is ready. Create a lobby to invite friends.")
    
func _steam_init_succeeded(result: Variant) -> bool:
    if result is Dictionary:
        if result.has("status"):
            return int(result["status"]) == 0
        if result.has("success"):
            return bool(result["success"])
    if result is bool:
        return result
    if result is int:
        return result == 0
    # Some plugin versions return no value on success; confirm the Steam client is running.
    if steam and steam.has_method("isSteamRunning"):
        return bool(steam.call("isSteamRunning"))
    return false

func create_lobby_and_invite() -> void:
    if not steam_initialized:
        _set_status("Steam is not ready. Install the GodotSteam plugin, launch Steam, and restart the game.")
        return
    if lobby_id > 0:
        open_invite_overlay()
        return
    if not steam.has_method("createLobby"):
        _set_status("This GodotSteam build does not expose createLobby().")
        return
    # GodotSteam lobby type: 1 = friends-only; 4 members suits a small party.
    steam.call("createLobby", 1, 4)
    _set_status("Creating a Steam friends-only lobby...")

func open_invite_overlay() -> void:
    if not steam_initialized:
        _set_status("Steam is not ready. Open Steam and restart Panda Royale.")
        return
    if lobby_id <= 0:
        create_lobby_and_invite()
        return
    if steam.has_method("activateGameOverlayInviteDialog"):
        steam.call("activateGameOverlayInviteDialog", lobby_id)
        _set_status("Opened Steam's invite overlay.")
    else:
        _set_status("This GodotSteam build does not expose the invite overlay API.")

func _on_lobby_created(connect_result: int, created_lobby_id: int) -> void:
    # Steam result 1 means success in Steamworks.
    if connect_result != 1 or created_lobby_id <= 0:
        _set_status("Steam lobby creation failed (result %d)." % connect_result)
        return
    lobby_id = created_lobby_id
    if steam.has_method("setLobbyJoinable"):
        steam.call("setLobbyJoinable", lobby_id, true)
    if steam.has_method("setLobbyData"):
        steam.call("setLobbyData", lobby_id, "name", "Panda Royale Party")
    _set_status("Steam lobby ready. Opening the invite overlay...")
    open_invite_overlay()

func _on_lobby_join_requested(lobby: Variant, _friend: Variant = 0) -> void:
    var requested_lobby_id := int(lobby)
    if steam and steam.has_method("joinLobby") and requested_lobby_id > 0:
        steam.call("joinLobby", requested_lobby_id)
        _set_status("Joining Steam lobby %d..." % requested_lobby_id)

func _inject_party_buttons() -> void:
    var scene := get_tree().current_scene
    if scene == null:
        return
    var host_buttons := scene.find_children("*", "Button", true, false)
    for node in host_buttons:
        var button := node as Button
        if button == null or not is_instance_valid(button):
            continue
        if button.text != "HOST PARTY":
            continue
        var parent := button.get_parent()
        if parent == null:
            continue
        var key := str(parent.get_instance_id())
        if _injected_buttons.has(key) and is_instance_valid(_injected_buttons[key]):
            continue
        var steam_button := Button.new()
        steam_button.name = "SteamInviteButton"
        steam_button.text = "INVITE VIA STEAM"
        steam_button.tooltip_text = "Create a Steam lobby and open the Steam friends invite overlay."
        steam_button.custom_minimum_size = Vector2(360, 48)
        steam_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
        steam_button.pressed.connect(create_lobby_and_invite)
        parent.add_child(steam_button)
        _injected_buttons[key] = steam_button

func _set_status(message: String) -> void:
    status = message
    status_changed.emit(message)
    print("[SteamManager] ", message)
