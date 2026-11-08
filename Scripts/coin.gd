extends Area2D


func _ready() -> void:
	add_to_group("MinimapCoin")
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		Global.coins += 1
		print("Moneda recogida. Total: ", Global.coins)
		queue_free()
