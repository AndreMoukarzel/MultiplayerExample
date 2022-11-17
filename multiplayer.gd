extends Node


var NETWORK = ENetMultiplayerPeer.new()
var PORT = 9999

var self_data = {}
var is_host: bool = false
var connected_peer_ids = []


func start_server(player_data):
	self_data = player_data
	is_host = true
	var error = NETWORK.create_server(PORT)
	if error == 0: # No error
		multiplayer.multiplayer_peer = NETWORK
		
		@warning_ignore(return_value_discarded)
		NETWORK.connect("peer_connected", _peer_connected)
		@warning_ignore(return_value_discarded)
		NETWORK.connect("peer_disconnected", _peer_disconnected)
	
	return error


func connect_to_server(address, player_data):
	self_data = player_data
	@warning_ignore(return_value_discarded)
	NETWORK.create_client(address, PORT)
	multiplayer.multiplayer_peer = NETWORK
	
	@warning_ignore(return_value_discarded)
	NETWORK.connect("connection_failed", _on_connection_failed)
	@warning_ignore(return_value_discarded)
	NETWORK.connect("connection_succeeded", _on_connection_succeeded)
	
	return NETWORK


func shutdown_server():
	is_host = false
	multiplayer.multiplayer_peer.close_connection()
	multiplayer.multiplayer_peer = null
	
	NETWORK.disconnect("peer_connected", _peer_connected)
	NETWORK.disconnect("peer_disconnected", _peer_disconnected)
	
	NETWORK = ENetMultiplayerPeer.new()


func disconnect_from_server():
	multiplayer.multiplayer_peer.close_connection()
	multiplayer.multiplayer_peer = null
	
	NETWORK.disconnect("connection_failed", _on_connection_failed)
	NETWORK.disconnect("connection_succeeded", _on_connection_succeeded)
	
	NETWORK = ENetMultiplayerPeer.new()


func _peer_connected(player_id):
	print("user " + str(player_id) + " connected")


func _peer_disconnected(player_id):
	print("user " + str(player_id) + " disconnected")


func _on_connection_failed():
	print("Connection Failed")


func _on_connection_succeeded():
	print("Connection Succeeded")
