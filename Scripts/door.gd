extends Area2D

func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("Player"):
		return

	# QUITAR bool() - usar directamente el valor
	if not body.get("has_key"):
		return

	set_deferred("monitoring", false)
	Global.level += 1
	Global.dungeon_seed += randi_range(1, 40000)
	get_tree().reload_current_scene.call_deferred()
