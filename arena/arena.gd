extends Node2D


signal all_connected


@export var PLAYER_SCN: PackedScene

var CONNECTED_PLAYERS: Array = [1]
var PLAYERS_INFO: Dictionary = {}


func _ready() -> void:
	if multiplayer.is_server():
		PLAYERS_INFO = Connection.all_data
		
		# Awaits for all players from lobby to be connected
		await all_connected
		
		var i: int = 1
		for player_id in PLAYERS_INFO.keys():
			_create_player(
				player_id,
				PLAYERS_INFO[player_id]["name"],
				PLAYERS_INFO[player_id]["color"],
				$StartingPositions.get_node("Pos" + str(i)).position
			)
			i += 1
		
		# Updates name and color of Players in clients' instances
		_update_info_in_client.rpc(PLAYERS_INFO)
		
		# Connects signals handling player creation/removal on client connection/disconnection
#		@warning_ignore(return_value_discarded)
#		multiplayer.multiplayer_peer.connect("peer_connected",
#			_create_player
#		)
		@warning_ignore(return_value_discarded)
		multiplayer.multiplayer_peer.connect("peer_disconnected",
			_remove_player
		)
		
		await get_tree().create_timer(.5).timeout
		# We wait to change authority so MultiplayerSynchronizer can have time to sync the players
		# initial state
		for peer_id in PLAYERS_INFO.keys():
			var PlayerObj = %Players.get_node(str(peer_id))
			if peer_id != 1:
				PlayerObj.set_multiplayer_authority(peer_id) # Change players' authority localy
				PlayerObj.give_authority.rpc_id(peer_id, peer_id) # Change players' authority on their own instance
			else:
				PlayerObj.UNLOCKED = true
	else:
		@warning_ignore(return_value_discarded)
		rpc_id(1, "_confirm_connection", multiplayer.get_unique_id())
	
	@warning_ignore(return_value_discarded)
	multiplayer.multiplayer_peer.connect("server_disconnected", _change_to_menu)


######################################### INTERNAL METHODS #########################################


func _create_player(peer_id: int, player_name: String, player_color: Color, start_position: Vector2) -> void:
	# Called in server only
	# Creates the LobbyPlayer of specified ID. Because we use a MultiplayerSpawner to sync the
	# LobbyPlayer objects, adding the scene to the server instance already adds them to all clients'
	# instances
	var NewPlayer = PLAYER_SCN.instantiate()
	NewPlayer.name = str(peer_id)
	%Players.add_child(NewPlayer)
	NewPlayer.get_node("PlayerName").text = str(player_name)
	NewPlayer.get_node("Sprite2D").modulate = player_color
	NewPlayer.position = start_position
	
	#NewPlayer.set_multiplayer_authority(peer_id)


func _remove_player(peer_id: int) -> void:
	# Called in server only
	# Removes the LobbyPlayer of specified ID. Because we use a MultiplayerSpawner to sync the
	# LobbyPlayer objects, removing the scene from the server instance already removes them from all
	# clients' instances
	%Players.get_node(str(peer_id)).queue_free()
	@warning_ignore(return_value_discarded)
	PLAYERS_INFO.erase(peer_id)
	@warning_ignore(return_value_discarded)
	CONNECTED_PLAYERS.erase(peer_id)


func _update_local_info() -> void:
	# Updates local scene's LobbyPlayers' names and states based on global PLAYERS_INFO dictionary
	for peer_id in PLAYERS_INFO.keys():
		var PlayerObj = %Players.get_node(str(peer_id))
		var player_info: Dictionary = PLAYERS_INFO[peer_id]
		
		PlayerObj.get_node("PlayerName").text = player_info["name"]
		PlayerObj.get_node("Sprite2D").modulate = player_info["color"]


func _change_to_menu() -> void:
	# Automatically called when 'server_disconnected' signal is detected. Returns to starting menu
	Connection.disconnect_from_server()
	var _val = get_tree().change_scene_to_file("res://log_in.tscn")


########################################### RPC METHODS ###########################################

@rpc
func _update_info_in_client(players_info: Dictionary) -> void:
	# Receives updated information dictionary from server
	PLAYERS_INFO = players_info
	_update_local_info()


@rpc(any_peer)
func _confirm_connection(asking_peer: int) -> void:
	# Called in client only
	# Confirms to server that player has already connected to this scene, and emmits a signal if all
	# players from lobby are already connected
	#
	# Needed to make sure no player is not prematurely created before their instance can transition
	# between the lobby and arena scenes
	CONNECTED_PLAYERS.append(asking_peer)
	
	for peer_id in PLAYERS_INFO.keys():
		if peer_id not in CONNECTED_PLAYERS:
			return
	emit_signal("all_connected")
