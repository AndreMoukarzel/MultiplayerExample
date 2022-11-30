extends TextEdit

@export var max_len: int = 15
@onready var prev_text: String = text


func _on_text_changed():
	# Filters text of all whitespaces, and makes sure the text doesn't exceed max_len
	var final_text: String = text.dedent().to_lower().lstrip("\n\t\r").rstrip("\n\t\r")
	
	if len(final_text) > max_len and len(final_text) > len(prev_text):
		text = prev_text
	else:
		prev_text = text
		text = final_text
	set_caret_column(16)
