extends Area2D

func _ready() -> void:
	add_to_group("MinimapKey")
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("Player"):
		return

	# "in" comprueba si la propiedad EXISTE, sin importar si vale true o false
	if not ("has_key" in body):
		push_warning("La llave detectó a '" + body.name + "' pero NO tiene la propiedad has_key. ¿Está player.gd adjunto al nodo Player?")
		return

	body.set("has_key", true)
	print("¡Llave recogida!")
	queue_free()
