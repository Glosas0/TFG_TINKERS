extends Node

var enemies: Array[Node] = []
var player: CharacterBody2D

func _ready() -> void:
	player = get_tree().get_first_node_in_group("Player") as CharacterBody2D
	if player == null:
		push_warning("Enemies: no se encuentra ningún jugador en el grupo Player.")
		return

	call_deferred("_connect_player_signals")
	check_enemies()

func _connect_player_signals() -> void:
	var moved_callback := Callable(self, "on_player_moved")
	
	if player.has_signal("player_moved") and not player.is_connected("player_moved", moved_callback):
		player.connect("player_moved", moved_callback)


func check_enemies() -> void:
	enemies.clear()
	for enemy in get_tree().get_nodes_in_group("Enemy"):
		if is_instance_valid(enemy):
			enemies.append(enemy)

func on_player_moved() -> void:
	check_enemies()
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.has_method("move"):
			enemy.move() # Movimiento simultáneo (sin await)

func process_enemy_turn() -> void:
	print("🔍 process_enemy_turn() llamado")
	check_enemies()
	print("🔍 Enemigos encontrados: ", enemies.size())
	
	for i in range(enemies.size()):
		var enemy = enemies[i]
		print("🔍 Procesando enemigo ", i, ": ", enemy.name if is_instance_valid(enemy) else "NULL")
		
		if is_instance_valid(enemy) and enemy.has_method("move"):
			print("🔍 Llamando a move() del enemigo ", enemy.name)
			await enemy.move()
			print("🔍 Enemigo ", enemy.name, " terminó su movimiento")
			await get_tree().create_timer(0.25).timeout
	
	print("🔍 process_enemy_turn() completado")
