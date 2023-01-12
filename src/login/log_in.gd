# Log In screen that allows for hosting and connecting to an online lobby, as well as customizing
# your personal player charater's name and color
extends HBoxContainer


func _ready():
	%Warning.text = ""
	%LoadingIcon.hide()


func _get_players_name():
	var player_name: String = %NameText.text
	if player_name == "":
		return %NameText.placeholder_text
	return player_name


func _change_to_lobby():
	var _val = get_tree().change_scene_to_file("res://src/lobby/lobby.tscn")


func _on_host_pressed():
	# Hosts a new lobby session
	var error = Connection.start_server({"name": _get_players_name(), "color": %PlayerVisual.modulate})
	if error == 0:
		_change_to_lobby()
	else:
		print("Server error: ", error)
		Connection.shutdown_server()


func _on_connection_failed():
	%LoadingIcon.hide()
	$Connection/Connect/HBoxContainer/Enter.show()
	%Warning.text = "Connection to " + %IpText.text + " failed!"
	%IpText.text = ""


func _on_enter_pressed():
	# Checks if a valid IP address is inputed, and if true tries to connect to it
	var ip_text: String = %IpText.text
	if ip_text == '':
		ip_text = 'localhost'
	
	if ip_text.is_valid_ip_address() or ip_text == 'localhost':
		var error: int = Connection.connect_to_server(
			ip_text,
			{"name": _get_players_name(), "color": %PlayerVisual.modulate}
		)
		print(error)
		if error == 0:
			%LoadingIcon.show()
			$Connection/Connect/HBoxContainer/Enter.hide()
			
			multiplayer.connect("connection_failed", _on_connection_failed)
			multiplayer.connect("connected_to_server", _change_to_lobby)
		else:
			print("Client error: ", error)
			Connection.disconnect_from_server()


func _on_quit_pressed():
	get_tree().quit()


func _on_color_picker_button_color_changed(color):
	%PlayerVisual.modulate = color
