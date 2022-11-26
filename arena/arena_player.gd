extends CharacterBody2D


const SPEED: float = 300.0

var UNLOCKED: bool = false


func _physics_process(_delta: float) -> void:
	if is_multiplayer_authority() and UNLOCKED:
		var hor_dir = Input.get_axis("ui_left", "ui_right")
		var ver_dir = Input.get_axis("ui_up", "ui_down")
		
		velocity = Vector2.ZERO
		if hor_dir:
			velocity.x = hor_dir * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
		
		if ver_dir:
			velocity.y = ver_dir * SPEED
		else:
			velocity.y = move_toward(velocity.y, 0, SPEED)

		var _collided: bool = move_and_slide()
	else:
		if Input.is_action_just_pressed("ui_accept"):
			print(get_multiplayer_authority())


@rpc
func give_authority(peer_id: int) -> void:
	set_multiplayer_authority(peer_id)
	$MultiplayerSynchronizer.set_multiplayer_authority(peer_id)
	UNLOCKED = true
