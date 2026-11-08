extends CharacterBody2D

const TILE_SIZE: int = 48
const DETECTION_RANGE_TILES: int = 6
const PLAYER_HIT_CHANCE: float = 0.92
const ENEMY_HIT_CHANCE: float = 0.8726

@onready var player: CharacterBody2D = get_tree().get_first_node_in_group("Player") as CharacterBody2D

var health: int = 3
var max_health: int = 3  # Necesario para que sepan cuándo curarse
var damage: int = 1
var has_detected_player: bool = false

# Variable para saber si tienen la llave
var has_key: bool = false 

var is_hooked: bool = false
var original_modulate: Color = Color.WHITE



func move() -> void:
	print("🕷️ ", name, " - move() llamado")
	
	if player == null or not is_instance_valid(player):
		print("🕷️ ", name, " - ERROR: player es null")
		return

	var distance_tiles := int(round(global_position.distance_to(player.global_position) / TILE_SIZE))
	print("🕷️ ", name, " - Distancia al jugador: ", distance_tiles, " casillas")
	
	if distance_tiles <= DETECTION_RANGE_TILES:
		has_detected_player = true

	if has_detected_player:
		var delta := player.global_position - global_position
		print("🕷️ ", name, " - Delta al jugador: ", delta)
		
		if absf(delta.x) + absf(delta.y) <= TILE_SIZE + 10.0:
			print("🕷️ ", name, " - ¡Está adyacente! Atacando...")
			await attack_player()
			return
		
		print("🕷️ ", name, " - Persiguiendo al jugador...")
		chase_player()
		return

	print("🕷️ ", name, " - Movimiento aleatorio...")
	if randf() < 0.5:
		return
	try_move(get_random_direction())

func chase_player() -> void:
	var delta := player.global_position - global_position
	var directions: Array[Vector2] = []
	if absf(delta.x) >= absf(delta.y):
		directions.append(Vector2(signf(delta.x), 0))
		directions.append(Vector2(0, signf(delta.y)))
	else:
		directions.append(Vector2(0, signf(delta.y)))
		directions.append(Vector2(signf(delta.x), 0))
	# Si la ruta directa está bloqueada, intenta la dirección alternativa.
	for direction in directions:
		if direction != Vector2.ZERO and try_move(direction):
			return

func try_move(direction: Vector2) -> bool:
	var target_position := global_position + direction * TILE_SIZE
	
	# BLOQUEO 1: Comprobación de otras arañas (menos de media casilla de distancia)
	for other in get_tree().get_nodes_in_group("Enemy"):
		if other != self and is_instance_valid(other):
			if target_position.distance_to(other.global_position) < TILE_SIZE * 0.5:
				return false
	
	# BLOQUEO 2: Comprobación del jugador (menos de media casilla de distancia)
	if player != null and is_instance_valid(player):
		if target_position.distance_to(player.global_position) < TILE_SIZE * 0.5:
			return false
	
	# BLOQUEO 3: Raycast para obstáculos físicos (Paredes y Rocas)
	var query := PhysicsRayQueryParameters2D.create(global_position, target_position)
	query.exclude = [get_rid()]
	var result := get_world_2d().direct_space_state.intersect_ray(query)
	
	if not result.is_empty():
		var collider: Object = result.get("collider")
		if collider is Node and (collider.is_in_group("Wall") or collider.is_in_group("Rock")):
			return false
			
	# Si todo está libre, el enemigo se mueve
	global_position = target_position
	consume_items_on_tile()  # Esto hace que coman al caminar
	
	return true


func attack_player() -> void:
	if player != null and randf() < ENEMY_HIT_CHANCE:
		print("🕷️ ", name, " te atacó!")
		await player.take_damage(damage) # <--- espera obligatoria
	else:
		print("🕷️ ", name, " intentó atacarte, pero falló.")
		
		
func get_random_direction() -> Vector2:
	match randi_range(0, 3):
		0: return Vector2.UP
		1: return Vector2.DOWN
		2: return Vector2.RIGHT
		3: return Vector2.LEFT
	return Vector2.ZERO


# Método para ser empujado por el gancho
func try_push(direction: Vector2) -> void:
	var target_position = global_position + direction * TILE_SIZE
	var space_state = get_world_2d().direct_space_state
	
	var query = PhysicsRayQueryParameters2D.create(global_position, target_position)
	query.exclude = [get_rid()]
	var result = space_state.intersect_ray(query)
	
	if result.is_empty():
		global_position = target_position
	else:
		var collider = result.collider
		
		if collider.is_in_group("Wall"):
			_find_adjacent_free_space(direction)
		
		elif collider.is_in_group("Enemy"):
			if collider.has_method("try_push"):
				collider.try_push(direction)
			# Verificar si ahora está libre después de empujar en cadena
			var result2 = space_state.intersect_ray(query)
			if result2.is_empty():
				global_position = target_position
			else:
				_find_adjacent_free_space(direction)


# Buscar casilla libre adyacente si estamos bloqueados contra una pared
func _find_adjacent_free_space(original_direction: Vector2) -> void:
	var directions = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
	
	for dir in directions:
		if dir == original_direction or dir == -original_direction:
			continue
		
		var test_pos = global_position + dir * TILE_SIZE
		var query = PhysicsRayQueryParameters2D.create(global_position, test_pos)
		query.exclude = [get_rid()]
		var result = get_world_2d().direct_space_state.intersect_ray(query)
		
		if result.is_empty():
			global_position = test_pos
			return


func _ready() -> void:
	original_modulate = modulate


func set_hooked(hooked: bool) -> void:
	print("set_hooked(", hooked, ") en ", name)
	is_hooked = hooked
	if hooked:
		modulate = Color(1.0, 0.6, 0.2)  # Naranja
	else:
		modulate = Color.WHITE

func move_to_position(target_position: Vector2) -> void:
	var diff = target_position - global_position
	if diff.length() < 1.0:
		return
	
	var direction: Vector2
	if abs(diff.x) > abs(diff.y):
		direction = Vector2(sign(diff.x), 0)
	else:
		direction = Vector2(0, sign(diff.y))
	
	var new_pos = global_position + direction * TILE_SIZE
	
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, new_pos)
	query.exclude = [get_rid()]
	var result = space_state.intersect_ray(query)
	
	var is_blocked = false
	if not result.is_empty():
		var collider = result.collider
		if collider is Node:
			# Solo bloquean Paredes, otros Enemigos y Rocas.
			# Los consumibles (MinimapCoin, MinimapHeart, MinimapKey) NO bloquean.
			if collider.is_in_group("Wall") or \
			   collider.is_in_group("Enemy") or \
			   collider.is_in_group("Rock"):
				is_blocked = true
	
	if not is_blocked:
		global_position = new_pos


func consume_items_on_tile() -> void:
	# Buscamos todos los consumibles en la escena
	var items = get_tree().get_nodes_in_group("MinimapCoin") + \
				get_tree().get_nodes_in_group("MinimapHeart") + \
				get_tree().get_nodes_in_group("MinimapKey")
	
	for item in items:
		# Si el objeto está en la misma casilla que el enemigo (margen de 10 píxeles)
		if item.global_position.distance_to(global_position) < 10.0:
			
			if item.is_in_group("MinimapCoin"):
				damage += 1
				print("🕷️ ", name, " ha pisado una MONEDA. ¡Su daño sube a ", damage, "!")
				item.queue_free()
				
			elif item.is_in_group("MinimapHeart"):
				if health < max_health:
					health += 1
					print("💖 ", name, " ha pisado un CORAZÓN. Se cura. Vida: ", health, "/", max_health)
				else:
					print("💖 ", name, " pisó un corazón, pero ya tiene la vida llena (no lo gasta).")
				item.queue_free()
				
			elif item.is_in_group("MinimapKey"):
				has_key = true
				print("🔑 ", name, " ha recogido la LLAVE y la guarda consigo.")
				item.queue_free()


func take_damage(damage_taken: int) -> void:
	health -= damage_taken
	print("💥 ", name, " recibe ", damage_taken, " de daño. Vida restante: ", health)
	
	if health <= 0:
		if has_key:
			print("💀 ", name, " ha muerto y TENÍA LA LLAVE. ¡Soltándola al suelo!")
			drop_key()
		else:
			print("💀 ", name, " ha muerto.")
			
		queue_free()
		return
	
	# ESPERAR A QUE TERMINE LA ANIMACIÓN DE DAÑO
	if has_node("AnimationPlayer"):
		$AnimationPlayer.play("Hit")
		await $AnimationPlayer.animation_finished


func drop_key() -> void:
	# ⚠️ IMPORTANTE: Asegúrate de que esta ruta sea EXACTA a tu archivo .tscn
	var key_path = "res://Nodes/key.tscn" 
	
	if ResourceLoader.exists(key_path):
		var key_scene = load(key_path)
		var key_instance = key_scene.instantiate()
		
		# 1. Posición exacta donde murió la araña
		key_instance.global_position = global_position
		
		# 2. FORZAR VISIBILIDAD: Dibujar por encima de todo (suelo, enemigos, jugador)
		key_instance.z_index = 100
		key_instance.z_as_relative = false
		
		# 3. Añadirlo a la escena principal (nivel) en lugar de al padre del enemigo
		# Esto evita que desaparezca si el nodo padre del enemigo se elimina o se oculta
		get_tree().current_scene.add_child(key_instance)
		
		print("✅ ¡ÉXITO VISUAL! La llave se ha añadido a la escena principal en: ", key_instance.global_position)
	else:
		print("⚠️ ERROR CRÍTICO: No se encuentra la escena de la llave en: ", key_path)
		print("⚠️ Revisa el nombre de tu archivo .tscn y su carpeta.")
