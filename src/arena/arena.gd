# Players are sent to this scene as "contestants" if they were connected in the lobby scene
# beforehand and the server initiated the transition. Peers that connect after the scene is started
# will be instanced as spectators and can watch other players but will not have a player scene
#
# This scene exemplifies the behavior of players who ARE their own multiplayer authorities, and
# therefore all necessary information is synced by the MultiplayerSynchronizer nodes.
extends Node2D


signal all_connected


@export var PLAYER_SCN: PackedScene

var CONNECTED_PLAYERS: Array = [1]
var PLAYERS_INFO: Dictionary = {}


func _ready() -> void:
	if multiplayer.is_server():
		PLAYERS_INFO = Connection.all_data
		
		# Connects signals handling player removal on client disconnection
		multiplayer.multiplayer_peer.connect("peer_disconnected",
			_remove_player
		)
		
		# Awaits for all players from lobby to be connected
		if len(PLAYERS_INFO.keys()) > 1: # Waits only if there are more players than the host
			await all_connected
		
		# Creates all players in positions preset in StartingPositions node
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
		
		# Anounces the readiness of the arena to all Players
		_arena_is_ready.rpc()
		
		await get_tree().create_timer(.4).timeout
		# We wait to change authority so MultiplayerSynchronizer can have time to sync the players'
		# initial position
		_give_players_authority()
	else:
		rpc_id(1, "_confirm_connection", multiplayer.get_unique_id())
		
		multiplayer.connect("server_disconnected", _change_to_menu)
	
	_on_chat_box_inactive()


######################################### INTERNAL METHODS #########################################


func _create_player(peer_id: int, player_name: String, player_color: Color, start_position: Vector2) -> void:
	# Called in server only
	# Creates the ArenaPlayer of specified ID. Because we use a MultiplayerSpawner to sync the
	# ArenaPlayer objects, adding the scene to the server instance already adds them to all clients'
	# instances
	var NewPlayer = PLAYER_SCN.instantiate()
	NewPlayer.name = str(peer_id)
	%Players.add_child(NewPlayer)
	NewPlayer.get_node("PlayerName").text = str(player_name)
	NewPlayer.get_node("Sprite2D").modulate = player_color
	NewPlayer.position = start_position


func _remove_player(peer_id: int) -> void:
	# Called in server only
	# Removes the ArenaPlayer of specified ID. Because we use a MultiplayerSpawner to sync the
	# ArenaPlayer objects, removing the scene from the server instance already removes them from all
	# clients' instances
	#
	# If the player connected to the scene after the Arena had started, he is only an spectator and
	# therefore will not have an associated ArenaPlayer instance
	var found: bool = PLAYERS_INFO.erase(peer_id)
	if found: # Peer is a Player, and not an spectator
		%Players.get_node(str(peer_id)).queue_free()
	CONNECTED_PLAYERS.erase(peer_id)


func _update_local_info() -> void:
	# Updates local scene's ArenaPlayer' names and states based on global PLAYERS_INFO dictionary
	for peer_id in PLAYERS_INFO.keys():
		var PlayerObj = %Players.get_node(str(peer_id))
		var player_info: Dictionary = PLAYERS_INFO[peer_id]
		
		PlayerObj.get_node("PlayerName").text = player_info["name"]
		PlayerObj.get_node("Sprite2D").modulate = player_info["color"]


func _change_to_menu() -> void:
	# Automatically called when 'server_disconnected' signal is detected. Returns to starting menu
	Connection.disconnect_from_server()
	var _val = get_tree().change_scene_to_file("res://log_in.tscn")


func _give_players_authority() -> void:
	# Called on server only
	# Give each peer in PLAYERS_INFO authority over their associated ArenaPlayer instance and
	# unlocks them, allowing them to move themselves
	for peer_id in PLAYERS_INFO.keys():
		var PlayerObj = %Players.get_node(str(peer_id))
		if peer_id != 1:
			PlayerObj.set_multiplayer_authority(peer_id) # Change players' authority localy
			PlayerObj.give_authority.rpc_id(peer_id, peer_id) # Change players' authority on their own instance
		else:
			PlayerObj.UNLOCKED = true # Allows the host's ArenaPlayer to move too!


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


@rpc(call_local)
func _arena_is_ready() -> void:
	%FgAnim.play("fadeout")
	%ChatBox.WRITER_NAME = PLAYERS_INFO[multiplayer.get_unique_id()]["name"]


@rpc(any_peer)
func _send_message(peer_name: String, message: String) -> void:
	# Sends a message to all other players
	%ChatBox.add_new_message(peer_name, message)

########################################### CHAT SIGNALS ###########################################


func _on_chat_box_active():
	# If the current player interacts with ChatBox, makes it more opaque
	var twn = get_tree().create_tween()
	twn.tween_property(%ChatBox, "modulate", Color(1, 1, 1, 1), .6)


func _on_chat_box_inactive():
	# If the current player has not interacted with ChatBox for a while, makes it more transparent
	var twn = get_tree().create_tween()
	twn.tween_property(%ChatBox, "modulate", Color(1, 1, 1, .6), .6)


func _on_chat_box_text_submited(text):
	# When entering a message, also send the message to all other peers
	var peer_name: String = PLAYERS_INFO[multiplayer.get_unique_id()]["name"]
	_send_message.rpc(peer_name, text)
