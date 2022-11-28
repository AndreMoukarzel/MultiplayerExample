# Standard Lobby scene
# Players can connect to lobby with custumized information (player's name) and have to confirm
# readyness to server before all can proceed to the next game-state
#
# This scene exemplifies the behavior of players who are not their own multiplayer authorities, and
# therefore send all necessary information to server for synchronization
#
# Since the syncronization of the LobbyPlayer scenes is handled with MultiplayerSpawner, all we
# need to do is make sure the LobbyPlayer scenes are correctly instanced in the server instance
# and they will be automatically synchronized in all clients, greatly simplifying the process.
extends VSplitContainer


@export var ARENA_SCN: PackedScene
@export var PLAYER_SCN: PackedScene

var PLAYERS_INFO: Dictionary = {}


func _ready() -> void:
	_startup_cleanup()
	
	if multiplayer.is_server():
		var this_peer_id: int = multiplayer.get_unique_id()
		_create_player(this_peer_id) # Creates the host's LobbyPlayer object in 'Players' node
		# Adds host's info to global dictionary
		PLAYERS_INFO[this_peer_id] = {
			"name": Connection.self_data["name"],
			"color": Connection.self_data["color"],
			"ready": true
		}
		_update_local_info()
		_setup_server_player(%Players.get_node(str(this_peer_id)))
		
		# Connects signals handling player creation/removal on client connection/disconnection
		multiplayer.multiplayer_peer.connect("peer_connected",
			_create_player
		)
		multiplayer.multiplayer_peer.connect("peer_disconnected",
			_remove_player
		)
	else:
		%Start.text = "Ready" # 'Start' button is used to confirm readyness in clients, hence the text change
		rpc_id(1, "_send_info_to_server", multiplayer.get_unique_id(), Connection.self_data, false)
		
		multiplayer.connect("server_disconnected", _change_to_menu)


######################################### INTERNAL METHODS #########################################

func _startup_cleanup() -> void:
	# Cleans up dummy objects and text from scene. Those only exist to represent how the scene
	# should look in the editor
	%Info.text = ""
	for child in %Players.get_children():
		child.queue_free()


func _create_player(peer_id: int) -> void:
	# Called in server only
	# Creates the LobbyPlayer of specified ID. Because we use a MultiplayerSpawner to sync the
	# LobbyPlayer objects, adding the scene to the server instance already adds them to all clients'
	# instances
	var NewPlayer = PLAYER_SCN.instantiate()
	NewPlayer.name = str(peer_id)
	%Players.add_child(NewPlayer)
	NewPlayer.get_node("PlayerName").text = str(peer_id)
	
	NewPlayer.set_multiplayer_authority(peer_id)


func _remove_player(peer_id: int) -> void:
	# Called in server only
	# Removes the LobbyPlayer of specified ID. Because we use a MultiplayerSpawner to sync the
	# LobbyPlayer objects, removing the scene from the server instance already removes them from all
	# clients' instances
	%Players.get_node(str(peer_id)).queue_free()
	@warning_ignore(return_value_discarded)
	PLAYERS_INFO.erase(peer_id)


func _setup_server_player(PlayerObj) -> void:
	# Makes visual changes to the server host's LobbyPlayer unique to them
	
	# Hides Server's CheckBox, since the server is always considered ready
	PlayerObj.get_node("CheckBox").hide()
	# Makes tag that identify the host visible
	PlayerObj.get_node("HostTag").show()


func _update_local_info() -> void:
	# Updates local scene's LobbyPlayers' names and states based on global PLAYERS_INFO dictionary
	for peer_id in PLAYERS_INFO.keys():
		var PlayerObj = %Players.get_node(str(peer_id))
		var player_info: Dictionary = PLAYERS_INFO[peer_id]
		
		PlayerObj.get_node("PlayerName").text = player_info["name"]
		PlayerObj.get_node("TextureRect").modulate = player_info["color"]
		PlayerObj.get_node("CheckBox").button_pressed = player_info["ready"]
	
	_setup_server_player(%Players.get_node('1'))


func _change_to_menu() -> void:
	# Automatically called when 'server_disconnected' signal is detected. Returns to starting menu
	Connection.disconnect_from_server()
	var _val = get_tree().change_scene_to_file("res://log_in.tscn")


func _all_ready(verbose: bool = false) -> bool:
	for player in %Players.get_children():
			if not player.get_node("CheckBox").button_pressed:
				if verbose:
					print("Player " + player.get_node("PlayerName").text + " is not ready")
				return false
	return true


func _change_to_arena() -> void:
	for peer_id in PLAYERS_INFO.keys():
		var player_info: Dictionary = PLAYERS_INFO[peer_id]
		
		Connection.all_data[peer_id] = {
			"name": player_info["name"],
			"color": player_info["color"]
		}
	_change_client_to_arena.rpc()
	var _val = get_tree().change_scene_to_packed(ARENA_SCN)


########################################### RPC METHODS ###########################################

@rpc(any_peer)
func _send_info_to_server(asking_peer: int, player_data: Dictionary, ready_status: bool) -> void:
	# Called in client only
	# Updates new player's info in server and sends updated information to all connected clients
	PLAYERS_INFO[asking_peer] = {
		"name": player_data["name"],
		"color": player_data["color"],
		"ready": ready_status
	}
	_update_local_info()
	
	for peer_id in multiplayer.get_peers(): # Sends updated info to all clients
		_update_info_in_client.rpc_id(peer_id, PLAYERS_INFO)


@rpc
func _update_info_in_client(players_info: Dictionary) -> void:
	# Receives updated information dictionary from server
	PLAYERS_INFO = players_info
	_update_local_info()


@rpc
func _change_client_to_arena() -> void:
	var _val = get_tree().change_scene_to_packed(ARENA_SCN)

########################################## BUTTON SIGNALS ##########################################

func _on_start_pressed() -> void:
	if multiplayer.is_server():
		# On server, checks if all players are ready to proceed to the next gamestate
		if _all_ready():
			_change_to_arena()
	else:
		# On client, sends a change in the 'readyness' status to the server
		var peer_id: int = multiplayer.get_unique_id()
		var ReadyBox: CheckBox = %Players.get_node(str(peer_id)).get_node("CheckBox")
		
		@warning_ignore(return_value_discarded)
		rpc_id(1, "_send_info_to_server", peer_id, Connection.self_data, not ReadyBox.button_pressed)


func _on_quit_pressed() -> void:
	if multiplayer.is_server():
		# All peers will be disconnected using the 'server_disconnected' signal
		multiplayer.multiplayer_peer.disconnect("peer_connected", _create_player)
		multiplayer.multiplayer_peer.disconnect("peer_disconnected", _remove_player)
		Connection.shutdown_server()
	else:
		# The player's scene removal will be handed by the server using the 'peer_disconnected' signal
		Connection.disconnect_from_server()
	var _val = get_tree().change_scene_to_file("res://log_in.tscn")
