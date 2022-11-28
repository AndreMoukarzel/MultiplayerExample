extends Node


var NETWORK: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
var PLUG_AND_PLAY: UPNP = UPNP.new()
var PORT: int = 9999

var is_host: bool = false
var self_data: Dictionary = {} # Stores fixed information of player when entering the server
var all_data: Dictionary = {} # Stores relevant information of players used between/in scenes


func start_server(player_data: Dictionary) -> int:
	self_data = player_data
	is_host = true
	var error = NETWORK.create_server(PORT)
	if error == 0: # No error
		multiplayer.multiplayer_peer = NETWORK
		
		NETWORK.connect("peer_connected", _peer_connected)
		NETWORK.connect("peer_disconnected", _peer_disconnected)
		
#		_setup_upnp()
	return error


func connect_to_server(address: String, player_data: Dictionary) -> int:
	self_data = player_data
	var error = NETWORK.create_client(address, PORT)
	multiplayer.multiplayer_peer = NETWORK
	
	multiplayer.connect("connection_failed", _on_connection_failed)
	multiplayer.connect("connected_to_server", _on_connection_succeeded)
	
	return error


func shutdown_server():
	is_host = false
	multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	
	NETWORK.disconnect("peer_connected", _peer_connected)
	NETWORK.disconnect("peer_disconnected", _peer_disconnected)
	
	NETWORK = ENetMultiplayerPeer.new()
	
#	PLUG_AND_PLAY.delete_port_mapping(PORT, "UDP")
#	PLUG_AND_PLAY.delete_port_mapping(PORT, "TCP")
#
#	PLUG_AND_PLAY = UPNP.new()


func disconnect_from_server():
	multiplayer.multiplayer_peer.close()
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


func _setup_upnp():
	# Finds device and port forwards defined port automatically so external connections are possible
	# Doesn't work in all devices
	var discover_result = PLUG_AND_PLAY.discover(100)
	
	if discover_result == UPNP.UPNP_RESULT_SUCCESS:
		if PLUG_AND_PLAY.get_gateway() and PLUG_AND_PLAY.get_gateway().is_valid_gateway():
			_robust_port_mapping(PLUG_AND_PLAY, PORT, "godot")


func _robust_port_mapping(upnp: UPNP, port: int, description: String) -> void:
	# Some routers only allow port forwarding with a description while others only work without one.
	# This method makes sure post forwarding will not be stopped by this limitation.
	# It also ports for both UDP and TCP
	var result_udp = upnp.add_port_mapping(port, port, description + "_udp", "UDP")
	var result_tcp = upnp.add_port_mapping(port, port, description + "_tcp", "TCP")
	
	if not result_udp == UPNP.UPNP_RESULT_SUCCESS:
		upnp.add_port_mapping(port, port, '', "UDP")
	if not result_tcp == UPNP.UPNP_RESULT_SUCCESS:
		upnp.add_port_mapping(port, port, '', "TCP")
