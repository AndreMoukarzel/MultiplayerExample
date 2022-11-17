# Log In screen that allows for hosting and connecting to an online lobby, as well as customizing
# your personal player charater's name and color
extends HBoxContainer


func _get_players_name():
	var player_name: String = %NameText.text
	if player_name == "":
		return %NameText.placeholder_text
	return player_name


func _change_to_lobby():
	var _val = get_tree().change_scene_to_file("res://lobby.tscn")


func _on_host_pressed():
	# Hosts a new lobby session
	Connection.start_server({"name": _get_players_name(), "color": %PlayerVisual.modulate})
	_change_to_lobby()


func _on_enter_pressed():
	# Checks if a valid IP address is inputed, and if true tries to connect to it
	var ip_text: String = %IpText.text
	if ip_text == '':
		ip_text = 'localhost'
	
	if ip_text.is_valid_ip_address() or ip_text == 'localhost':
		var Network = Connection.connect_to_server(
			ip_text,
			{"name": _get_players_name(), "color": %PlayerVisual.modulate}
		)
		Network.connect("connection_succeeded", _change_to_lobby)


func _on_quit_pressed():
	get_tree().quit()


func _on_color_picker_button_color_changed(color):
	%PlayerVisual.modulate = color
