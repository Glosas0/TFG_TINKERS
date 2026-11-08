extends Node2D

var inside_width: int = 9
var inside_height: int = 9

# Generation se asigna antes de añadir la habitación al árbol.
var Generation: Node
@export var enemy_node: PackedScene
@export var coin_node: PackedScene
@export var heart_node: PackedScene
@export var key_node: PackedScene
@export var exit_door_node: PackedScene
@export var rock_node: PackedScene

var used_position: Array[Vector2] = []

func _ready() -> void:
	if Generation != null:
		generate_interior()

func north() -> void:
	$NorthDoor.visible = true
	$NorthWall.queue_free()

func south() -> void:
	$SouthDoor.visible = true
	$SouthWall.queue_free()

func east() -> void:
	$EastDoor.visible = true
	$EastWall.queue_free()

func west() -> void:
	$WestDoor.visible = true
	$WestWall.queue_free()

func generate_interior() -> void:
	if randf() < Generation.enemy_spawn_chance:
		spawn_node(enemy_node, 1, Generation.max_enemies_per_room)

	if randf() < Generation.coin_spawn_chance:
		spawn_node(coin_node, 1, Generation.max_coins_per_room)

	if randf() < Generation.heart_spawn_chance:
		spawn_node(heart_node, 1, Generation.max_hearts_per_room)
	
	# Generar rocas (ajusta el 0.5 a la probabilidad, entre 0.0 y 1.0)
	if randf() < 0.5: 
		spawn_node(rock_node, 1, 2) # Genera entre 1 y 2 rocas por sala

func spawn_node(node_scene: PackedScene, min_instances: int = 0, max_instances: int = 0) -> void:
	if node_scene == null:
		push_warning("Room: se intentó generar una escena que no está asignada en el Inspector.")
		return

	var number: int = 1
	if min_instances != 0 or max_instances != 0:
		if max_instances < min_instances:
			push_warning("Room: max_instances es menor que min_instances.")
			return
		number = randi_range(min_instances, max_instances)

	for i in range(number):
		var pos := get_free_spawn_position()
		if pos == Vector2(-1, -1):
			push_warning("Room: no quedan posiciones libres para generar más objetos.")
			break

		var node_object = node_scene.instantiate()
		node_object.position = pos
		add_child(node_object)
		used_position.append(pos)

	# El gestor refresca su lista cuando el jugador consume un turno.
	# Lo actualizamos aquí también para que incluya enemigos recién creados.
	if node_scene == enemy_node:
		var enemy_manager = get_tree().get_first_node_in_group("EnemyManager")
		if enemy_manager != null and enemy_manager.has_method("check_enemies"):
			enemy_manager.check_enemies()
		else:
			push_warning("Room: no se encuentra un nodo con el grupo EnemyManager y el método check_enemies().")

func get_free_spawn_position() -> Vector2:
	# Hay 7 x 7 posiciones interiores posibles con estos límites.
	# Un límite de intentos evita un bucle infinito si la sala se llena.
	for attempt in range(100):
		var candidate := Vector2(
			48 * randi_range(2, inside_width - 1) - 24,
			48 * randi_range(2, inside_height - 1) - 24
		)
		if not used_position.has(candidate):
			return candidate
	return Vector2(-1, -1)
