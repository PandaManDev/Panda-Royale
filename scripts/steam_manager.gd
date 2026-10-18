extends Node
## Optional GodotSteam bridge. Steam invites require a compatible GodotSteam GDExtension.
## Without that extension, the button reports the missing setup in the party panel.

signal status_changed(message: String)

var steam: Object
var steam_available := false
var steam_initialized := false
var lobby_id: int = 0
var status := "Steam integration is not installed."

func _ready() -> void:
    _try_initialize_steam()

func _try_initialize_steam() -> void:
    if not Engine.has_singleton("Steam"):
        _set_status("Steam isn't configured. The GodotSteam GDExtension is missing.")
        return
    steam = Engine.get_singleton("Steam")
    steam_available = steam != null
    if not steam_available:
        _set_status("GodotSteam was detected but the Steam API could not be loaded.")
        return
    var init_result: Variant = null
    # App ID 480 is Valve's Spacewar test app. Replace it with Panda Royale's
    # own Steamworks App ID before publishing. GDExtension builds commonly use
    # steamInitEx(app_id, retrieve_stats); older builds may expose steamInit.
    if steam.has_method("steamInitEx"):
        init_result = steam.call("steamInitEx", 480, true)
        steam_initialized = _steam_init_succeeded(init_result)
    elif steam.has_method("steamInit"):
        init_result = steam.call("steamInit", true, 480)
        steam_initialized = _steam_init_succeeded(init_result)
    else:
        _set_status("The installed GodotSteam version has no recognized init method.")
        return
    if not steam_initialized:
        _set_status("Steam initialization failed. Check that Steam is running, steam_appid.txt contains 480 for local testing, and the installed GodotSteam API matches this project.")
        return
    if steam.has_signal("lobby_created") and not steam.is_connected("lobby_created", _on_lobby_created):
        steam.connect("lobby_created", _on_lobby_created)
    if steam.has_signal("lobby_join_requested") and not steam.is_connected("lobby_join_requested", _on_lobby_join_requested):
        steam.connect("lobby_join_requested", _on_lobby_join_requested)
    _set_status("Steam is ready. You can create a friends-only lobby.")

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
    if steam and steam.has_method("isSteamRunning"):
        return bool(steam.call("isSteamRunning"))
    return false

func create_lobby_and_invite() -> void:
    if not steam_initialized:
        _set_status("Steam invites can't open yet: install/configure GodotSteam and its App ID first.")
        return
    if lobby_id > 0:
        open_invite_overlay()
        return
    if not steam.has_method("createLobby"):
        _set_status("Your GodotSteam build doesn't expose createLobby().")
        return
    steam.call("createLobby", 1, 4)
    _set_status("Requesting a Steam friends-only lobby...")

func open_invite_overlay() -> void:
    if not steam_initialized:
        _set_status("Steam isn't ready. Install/configure GodotSteam and restart the game.")
        return
    if lobby_id <= 0:
        create_lobby_and_invite()
        return
    if steam.has_method("activateGameOverlayInviteDialog"):
        steam.call("activateGameOverlayInviteDialog", lobby_id)
        _set_status("Requested Steam's invite overlay.")
    else:
        _set_status("This GodotSteam build doesn't expose activateGameOverlayInviteDialog().")

func _on_lobby_created(connect_result: int, created_lobby_id: int) -> void:
    if connect_result != 1 or created_lobby_id <= 0:
        _set_status("Steam lobby creation failed (result %d)." % connect_result)
        return
    lobby_id = created_lobby_id
    if steam.has_method("setLobbyJoinable"):
        steam.call("setLobbyJoinable", lobby_id, true)
    if steam.has_method("setLobbyData"):
        steam.call("setLobbyData", lobby_id, "name", "Panda Royale Party")
    _set_status("Steam lobby created. Opening the invite overlay...")
    open_invite_overlay()

func _on_lobby_join_requested(lobby: Variant, _friend: Variant = 0) -> void:
    var requested_lobby_id := int(lobby)
    if steam and steam.has_method("joinLobby") and requested_lobby_id > 0:
        steam.call("joinLobby", requested_lobby_id)
        _set_status("Accepted Steam invite %d. Lobby joining is requested, but gameplay networking still needs connecting." % requested_lobby_id)

func _set_status(message: String) -> void:
    status = message
    status_changed.emit(message)
    print("[SteamManager] ", message)
