extends Control


signal active # User has interacted with chatbox with mouse or sent a message
signal inactive # User has not interacted with chatbox for the allotted time
signal text_submited(text)


const INACTIVE_TIMER: float = 5.0 
const WRITER_COLOR: Color = Color(0.8, 0.8, 0)

var WRITER_NAME: String = "Writer"



func add_new_message(author: String, message: String, color: Color=Color(1, 1, 1)):
	%MessageHistory.text += "[color=" + color.to_html(false) + "][b]" + author + ":[/b] " + message + "[/color]\n"


func _on_current_message_text_submitted(new_text):
	if len(new_text.strip_escapes()) == 0: # Doesn't allow submission of empty messages
		return
	add_new_message(WRITER_NAME, new_text, WRITER_COLOR)
	$CurrentMessage.text = ""
	emit_signal("active")
	emit_signal("text_submited", new_text)
	$InactivityTimer.start()


func _on_message_history_mouse_entered():
	emit_signal("active")
	$InactivityTimer.start()


func _on_current_message_mouse_entered():
	emit_signal("active")
	$InactivityTimer.start()


func _on_inactivity_timer_timeout():
	# Time of non-interaction it takes for the chatbox to be considered inactive
	emit_signal("inactive")
