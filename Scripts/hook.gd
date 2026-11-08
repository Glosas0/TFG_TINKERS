extends Node2D

const TILE_SIZE := 48
const MAX_LENGTH := 5

var path: Array[Vector2] = []
var selected_entity: Node2D = null
var selected_entity_position: Vector2 = Vector2.ZERO
var hooked_entity: Node2D = null

var is_retracting: bool = false
var anchor_direction: Vector2 = Vector2.ZERO  # Dirección fija del gancho al enganchar

var is_locked: bool = false

func _ready() -> void:
	print("Hook listo")

func _process(_delta: float) -> void:
	# Bloquear todas las acciones mientras el turno se está procesando
	if is_locked:
		return
	
	var dir := Vector2.ZERO
	if Input.is_action_just_pressed("hook_up"): 
		dir = Vector2.UP
	elif Input.is_action_just_pressed("hook_down"): 
		dir = Vector2.DOWN
	elif Input.is_action_just_pressed("hook_left"): 
		dir = Vector2.LEFT
	elif Input.is_action_just_pressed("hook_right"): 
		dir = Vector2.RIGHT

	if dir != Vector2.ZERO:
		extend_hook(dir)
		if hooked_entity != null:
			_sync_hooked_enemy()

	if Input.is_action_just_pressed("hook_retract"):
		retract_one()
		if hooked_entity != null:
			_sync_hooked_enemy()
	
	if Input.is_action_just_pressed("hook_retract_all"):
		# Si hay enemigo enganchado, NO permitir retraer
		if hooked_entity != null:
			return
		# Solo retraer gancho sin consumir turno
		path.clear()
		selected_entity = null
		queue_redraw()
	
	if Input.is_action_just_pressed("hook_drag"):
		engage_enemy()
	
	if Input.is_action_just_pressed("hook_release"):
		release_enemy()
	
	if Input.is_action_just_pressed("hook_attract"):
		attract_selected_enemy()

func extend_hook(direction: Vector2) -> void:
	if is_locked:
		return
	
	if path.size() > 0 and direction == -path[-1]:
		retract_one()
		return
	
	if hooked_entity != null:
		if path.size() == 1 and direction == -anchor_direction:
			return
	
	if path.size() >= MAX_LENGTH:
		return
	
	if selected_entity != null and is_hook_reaching_entity(selected_entity):
		return
	
	var start_pos = get_end_position()
	var end_pos = start_pos + direction * TILE_SIZE
	
	# Autocolisión
	var player_pos = get_parent().global_position
	var current_pos = player_pos
	var occupied_tiles: Array[Vector2] = [current_pos]
	for dir in path:
		current_pos += dir * TILE_SIZE
		occupied_tiles.append(current_pos)
	if occupied_tiles.has(end_pos):
		return
	
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(start_pos, end_pos)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.exclude = []
	if hooked_entity != null:
		query.exclude.append(hooked_entity.get_rid())
	
	var result = space_state.intersect_ray(query)
	
	if result:
		var collider = result.collider
		
		# Si llevamos algo enganchado
		if hooked_entity != null:
			var holding_consumible = hooked_entity.is_in_group("MinimapCoin") or hooked_entity.is_in_group("MinimapHeart") or hooked_entity.is_in_group("MinimapKey")
			var holding_enemy = hooked_entity.is_in_group("Enemy")
			var holding_rock = hooked_entity.is_in_group("Rock")
			
			# REGLA 1: Consumible o ROCA enganchada = SÓLIDO (bloquea con ABSOLUTAMENTE TODO)
			if holding_consumible or holding_rock:
				if collider.is_in_group("Wall") or collider.is_in_group("Rock") or collider.is_in_group("Enemy") or collider == get_parent() or \
				   collider.is_in_group("MinimapCoin") or collider.is_in_group("MinimapHeart") or collider.is_in_group("MinimapKey"):
					return
			
			# REGLA 2: Enemigo enganchado = FANTASMA con consumibles (bloquea con paredes, rocas, jugador y otros enemigos)
			elif holding_enemy:
				if collider.is_in_group("Wall") or collider.is_in_group("Rock") or collider == get_parent() or collider.is_in_group("Enemy"):
					return
				# Si es un consumible, NO retornamos, dejamos que el path avance (la araña pasa por encima)
		else:
			# Gancho libre buscando objetivo
			if selected_entity != null:
				return
			
			# NUEVO: Si choca con una PARED, bloquear el gancho
			if collider.is_in_group("Wall"):
				return
			
			# Si choca con un objetivo válido, seleccionarlo
			if collider.is_in_group("Enemy") or collider.is_in_group("MinimapCoin") or collider.is_in_group("MinimapHeart") or collider.is_in_group("MinimapKey") or collider.is_in_group("Rock"):
				selected_entity = collider
				selected_entity_position = collider.global_position
				path.append(direction)
				queue_redraw()
				return
	
	path.append(direction)
	queue_redraw()
	
func retract_one() -> void:
	if is_retracting:
		return
	
	if path.size() == 0:
		return
	
	# CON ENEMIGO ENGANCHADO: no permitir retraer más allá del anclaje
	# El path mínimo es 1 (casilla adyacente al jugador)
	if hooked_entity != null and path.size() <= 1:
		return
	
	path.pop_back()
	
	if selected_entity != null and not is_hook_reaching_entity(selected_entity):
		selected_entity = null
	
	queue_redraw()

func is_hook_reaching_entity(entity: Node2D) -> bool:
	if entity == null or path.size() == 0:
		return false
	
	var end_pos = get_end_position()
	# Usar la posición guardada al seleccionar
	return end_pos.distance_to(selected_entity_position) < 24.0

func is_hook_on_selected_enemy() -> bool:
	if selected_entity == null or path.size() == 0:
		return false
	
	var end_pos = get_end_position()
	var enemy_pos = selected_entity.global_position
	return end_pos.distance_to(enemy_pos) < 24.0

func engage_enemy() -> void:
	if selected_entity == null:
		return
	
	if not is_hook_reaching_entity(selected_entity):
		return
	
	print("Enganchando a: ", selected_entity.name)
	hooked_entity = selected_entity
	selected_entity = null
	
	# Fijar la dirección de anclaje en la PRIMERA casilla del path
	if path.size() > 0:
		anchor_direction = path[0]  # Primera dirección, no la última
	else:
		anchor_direction = Vector2.ZERO
	
	# Aplicar efecto visual naranja
	if hooked_entity.has_method("set_hooked"):
		hooked_entity.set_hooked(true)
	
	# Mover al enemigo a la punta del gancho
	_sync_hooked_enemy()
	queue_redraw()

func attract_selected_enemy() -> void:
	if selected_entity == null or not is_instance_valid(selected_entity):
		return
	
	if not is_hook_reaching_entity(selected_entity):
		return
	
	if is_locked:
		return
	
	# BLOQUEAR INPUTS
	get_parent().is_action_locked = true
	
	hooked_entity = selected_entity
	selected_entity = null
	
	if hooked_entity.has_method("set_hooked"):
		hooked_entity.set_hooked(true)
	
	_sync_hooked_enemy()
	queue_redraw()
	
	is_locked = true
	
	# Fase 1: Retraer hasta que el path tenga 1 elemento
	while path.size() > 1:
		path.pop_back()
		if not is_inside_tree(): break
		if hooked_entity != null and is_instance_valid(hooked_entity):
			_sync_hooked_enemy()
		queue_redraw()
		await get_tree().create_timer(0.08).timeout
	
	# Fase 2: Retraer el resto del gancho
	while path.size() > 0:
		path.pop_back()
		if not is_inside_tree(): break
		queue_redraw()
		await get_tree().create_timer(0.08).timeout
	
	# 1. Guardamos la referencia en una variable local
	var entity_to_release = hooked_entity
	
	# 2. Limpiamos la variable global inmediatamente
	hooked_entity = null 
	
	# 3. Comprobamos que la variable local siga siendo válida
	if entity_to_release != null and is_instance_valid(entity_to_release):
		
		# Si es Enemigo o Roca: solo se libera (cambia de color)
		if entity_to_release.is_in_group("Enemy") or entity_to_release.is_in_group("Rock"):
			if entity_to_release.has_method("set_hooked"):
				entity_to_release.set_hooked(false)
				
			# Si es un enemigo, que compruebe si pisó un consumible al ser atraído
			if entity_to_release.is_in_group("Enemy"):
				if entity_to_release.has_method("consume_items_on_tile"):
					entity_to_release.consume_items_on_tile()
					
		# Si es consumible: se recoge
		elif entity_to_release.is_in_group("MinimapCoin") or entity_to_release.is_in_group("MinimapHeart") or entity_to_release.is_in_group("MinimapKey"):
			_collect_item(entity_to_release)
	
	queue_redraw()
	
	await get_tree().create_timer(0.15).timeout
	get_parent().player_action_completed.emit()
	
	# 4. Desbloquear al final
	is_locked = false
	get_parent().is_action_locked = false

func _collect_item(item: Node2D) -> void:
	var player = get_parent()
	
	if item.is_in_group("MinimapKey"):
		player.set("has_key", true)
		print("¡Llave recogida con el gancho!")
	elif item.is_in_group("MinimapHeart"):
		if Global.health < Global.max_health:
			Global.health += 1
			print("¡Corazón recogido con el gancho!")
		else:
			print("Vida al máximo, el corazón se pierde")
	elif item.is_in_group("MinimapCoin"):
		Global.coins += 1
		print("¡Moneda recogida con el gancho!")
	
	item.queue_free()


func release_enemy() -> void:
	if is_locked:
		return
	
	if hooked_entity == null:
		return
	
	# BLOQUEAR INPUTS
	get_parent().is_action_locked = true
	
	# 1. Guardamos la referencia en una variable local
	var entity_to_release = hooked_entity
	
	# 2. Limpiamos la variable global inmediatamente
	hooked_entity = null 
	
	# 3. Comprobamos que la variable local siga siendo válida
	if entity_to_release != null and is_instance_valid(entity_to_release):
		if entity_to_release.has_method("set_hooked"):
			entity_to_release.set_hooked(false)
			
		# 4. Si es un enemigo, que compruebe si pisó un consumible al ser soltado
		if entity_to_release.is_in_group("Enemy"):
			if entity_to_release.has_method("consume_items_on_tile"):
				entity_to_release.consume_items_on_tile()
	
	# 5. Iniciar animación de retracción y bloquear
	is_locked = true
	await retract_all_animated()
	
	await get_tree().create_timer(0.15).timeout
	get_parent().player_action_completed.emit()
	
	# 6. Desbloquear al final
	is_locked = false
	get_parent().is_action_locked = false

func retract_all_animated() -> void:
	while path.size() > 0:
		path.pop_back()
		queue_redraw()
		await get_tree().create_timer(0.08).timeout
	
	selected_entity = null
	queue_redraw()
	
	# Limpiar el anclaje
	anchor_direction = Vector2.ZERO




# Mueve al enemigo enganchado exactamente a la punta del gancho
func _sync_hooked_enemy() -> void:
	if hooked_entity == null or not is_instance_valid(hooked_entity):
		return
	
	# Verificar que el nodo Hook aún existe y está en el árbol
	if not is_inside_tree():
		return
	
	# Si el path está vacío, no hacer nada
	if path.size() == 0:
		return
	
	var target_pos = get_end_position()
	
	# Redondear al grid
	var grid_aligned_pos = Vector2(
		floor(target_pos.x / TILE_SIZE) * TILE_SIZE + TILE_SIZE / 2.0,
		floor(target_pos.y / TILE_SIZE) * TILE_SIZE + TILE_SIZE / 2.0
	)
	
	# Verificar que get_world_2d() no sea null
	var world = get_world_2d()
	if world == null:
		return
	
	var space_state = world.direct_space_state
	if space_state == null:
		return
	
	var query = PhysicsPointQueryParameters2D.new()
	query.position = grid_aligned_pos
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.collision_mask = 1
	
	var hits = space_state.intersect_point(query, 16)
	var is_blocked = false
	
	for hit in hits:
		var collider = hit.get("collider")
		if collider is Node:
			if collider.is_in_group("Wall"):
				is_blocked = true
				break
			if collider.is_in_group("Enemy") and collider != hooked_entity:
				is_blocked = true
				break
			# Bloquear si hay otra piedra o consumible
			if collider.is_in_group("Rock") and collider != hooked_entity:
				is_blocked = true
				break
			# Bloquear si hay otro objeto en la casilla (excepto el enganchado)
			if (collider.is_in_group("MinimapCoin") or collider.is_in_group("MinimapHeart") or collider.is_in_group("MinimapKey")) and collider != hooked_entity:
				is_blocked = true
				break
	
	if not is_blocked:
		hooked_entity.global_position = grid_aligned_pos
	
	queue_redraw()

func get_end_position() -> Vector2:
	var pos = Vector2.ZERO
	for dir in path:
		pos += dir * TILE_SIZE
	return get_parent().global_position + pos

func is_tile_occupied(global_pos: Vector2) -> bool:
	var current_pos = get_parent().global_position
	for dir in path:
		current_pos += dir * TILE_SIZE
		if current_pos.distance_to(global_pos) < 1.0:
			return true
	return false

func _draw() -> void:
	# Dibujar tile del enemigo seleccionado (amarillo)
	if selected_entity != null and is_instance_valid(selected_entity):
		var tile_corner = Vector2(
			floor(selected_entity.global_position.x / TILE_SIZE) * TILE_SIZE,
			floor(selected_entity.global_position.y / TILE_SIZE) * TILE_SIZE
		)
		var local_pos = to_local(tile_corner)
		draw_rect(Rect2(local_pos, Vector2(TILE_SIZE, TILE_SIZE)), Color(1.0, 0.85, 0.0, 0.4), true)
	
	# Dibujar tile del enemigo enganchado (naranja)
	if hooked_entity != null and is_instance_valid(hooked_entity):
		var tile_corner = Vector2(
			floor(hooked_entity.global_position.x / TILE_SIZE) * TILE_SIZE,
			floor(hooked_entity.global_position.y / TILE_SIZE) * TILE_SIZE
		)
		var local_pos = to_local(tile_corner)
		draw_rect(Rect2(local_pos, Vector2(TILE_SIZE, TILE_SIZE)), Color(1.0, 0.5, 0.0, 0.7), true)
	
	# Dibujar el gancho
	var current_pos = Vector2.ZERO
	for dir in path:
		var next_pos = current_pos + dir * TILE_SIZE
		draw_line(current_pos, next_pos, Color.YELLOW, 4.0)
		draw_circle(next_pos, 6.0, Color.ORANGE)
		current_pos = next_pos
