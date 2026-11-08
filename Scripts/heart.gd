extends Area2D

func _ready() -> void:
	add_to_group("MinimapHeart")


func _on_body_entered(body):
	if body.is_in_group("Player"):
		if Global.health < Global.max_health:
			Global.health += 1
			queue_free()
