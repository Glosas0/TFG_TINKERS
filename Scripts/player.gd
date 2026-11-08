extends CharacterBody2D

var is_action_locked : bool = false  # Bloqueo de inputs durante acciones

# Señal para movimiento simple (simultáneo)
signal player_moved
signal player_action_completed
var has_key : bool = false
var facing_direction : Vector2 = Vector2.DOWN  # Hacia dónde mira el jugador

# Sistema de auto-caminar (mantener P)
var auto_walk_cooldown : float = 0.0
const AUTO_WALK_DELAY : float = 0.12  # Segundos entre pasos automáticos

func _physics_process(delta):
	# Decrementar el cooldown de auto-walk
	if auto_walk_cooldown > 0:
		auto_walk_cooldown -= delta
	
	player_input()

func player_input() -> void:
	if is_action_locked:
		# Si intentas atacar mientras estás bloqueado, mostrar mensaje
		if Input.is_action_just_pressed("attack"):
			print("⚠️ No puedes atacar ahora mismo. Debe acabar el flujo de combate (turno del prota y del enemigo).")
		return
	
	var input_dir = Vector2.ZERO
	var is_auto_walking = Input.is_action_pressed("auto_walk")
	
	# Comprobar si el grid está activo (modo puntería)
	var grid_active = false
	if $FacingIndicator:
		grid_active = $FacingIndicator.show_indicator
	
	# Detectar dirección según el modo
	if is_auto_walking and not grid_active:
		# MODO AUTO-WALK: movimiento continuo
		if Input.is_action_pressed("move_right"):
			input_dir.x += 1
		if Input.is_action_pressed("move_left"):
			input_dir.x -= 1
		if Input.is_action_pressed("move_down"):
			input_dir.y += 1
		if Input.is_action_pressed("move_up"):
			input_dir.y -= 1
		
		if input_dir != Vector2.ZERO and auto_walk_cooldown > 0:
			input_dir = Vector2.ZERO
	else:
		# MODO NORMAL o MODO PUNTERÍA: una pulsación = un paso
		# Movimiento cardinal (WASD)
		if Input.is_action_just_pressed("move_right"):
			input_dir.x += 1
		if Input.is_action_just_pressed("move_left"):
			input_dir.x -= 1
		if Input.is_action_just_pressed("move_down"):
			input_dir.y += 1
		if Input.is_action_just_pressed("move_up"):
			input_dir.y -= 1
		
		# Movimiento diagonal (QEZC)
		if Input.is_action_just_pressed("move_up_left"):
			input_dir = Vector2(-1, -1)
		if Input.is_action_just_pressed("move_up_right"):
			input_dir = Vector2(1, -1)
		if Input.is_action_just_pressed("move_down_left"):
			input_dir = Vector2(-1, 1)
		if Input.is_action_just_pressed("move_down_right"):
			input_dir = Vector2(1, 1)
	
	# Si hay dirección válida
	if input_dir != Vector2.ZERO:
		facing_direction = input_dir
		
		# SOLO MOVERSE SI EL GRID NO ESTÁ ACTIVO
		if not grid_active:
			move(input_dir)
			
			if is_auto_walking:
				auto_walk_cooldown = AUTO_WALK_DELAY
	
	# ATAQUE que usa la dirección actual
	if Input.is_action_just_pressed("attack"):
		try_attack(facing_direction)
	
	# Gancho
	if Input.is_action_just_pressed("hook_drag"):
		$Hook.engage_enemy()
	if Input.is_action_just_pressed("hook_release"):
		$Hook.release_enemy()
	if Input.is_action_just_pressed("hook_attract"):
		$Hook.attract_selected_enemy()


func move(direction: Vector2) -> void:
	if $Hook.path.size() > 0:
		return
	
	if is_action_locked:
		return

	# Convertir la dirección a movimiento de grid (48 píxeles por eje)
	var grid_movement = Vector2.ZERO
	
	if direction.x > 0:
		grid_movement.x = 48
	elif direction.x < 0:
		grid_movement.x = -48
	
	if direction.y > 0:
		grid_movement.y = 48
	elif direction.y < 0:
		grid_movement.y = -48

	var target_pos: Vector2 = global_position + grid_movement

	if $Hook.is_tile_occupied(target_pos):
		return

	# NUEVO: Comprobar si hay un enemigo en la casilla destino
	for enemy in get_tree().get_nodes_in_group("Enemy"):
		if is_instance_valid(enemy):
			if enemy.global_position.distance_to(target_pos) < 10.0:
				return  # Casilla ocupada por enemigo

	# Raycast solo para paredes y rocas
	var space_rid = get_world_2d().space
	var space_state = PhysicsServer2D.space_get_direct_state(space_rid)

	var query = PhysicsRayQueryParameters2D.create(
		global_position,
		target_pos
	)
	query.exclude = [get_rid()]
	query.collision_mask = 1  # Solo colisiona con el layer 1 (paredes/rocas)

	var result = space_state.intersect_ray(query)

	if not result.is_empty():
		if result.collider.is_in_group("Wall"):
			return
		
		if result.collider.is_in_group("Rock"):
			if result.collider.has_method("try_push"):
				if result.collider.try_push(grid_movement):
					position += grid_movement
					player_moved.emit()
			return

	position += grid_movement
	player_moved.emit()

func try_attack(direction: Vector2) -> void:
	if $Hook.path.size() > 0:
		return
	
	# 1. BLOQUEAR INPUTS AL INICIO
	print("🔒 BLOQUEANDO INPUTS - Inicio del turno del jugador")
	is_action_locked = true

	var space_rid = get_world_2d().space
	var space_state = PhysicsServer2D.space_get_direct_state(space_rid)
	var query = PhysicsRayQueryParameters2D.create(global_position, global_position + Vector2(48, 48) * direction)
	query.exclude = [get_rid()]
	var result = space_state.intersect_ray(query)
	
	print("❤️ Vida actual: ", Global.health)

	if not result.is_empty():
		if result.collider.is_in_group("Enemy"):
			if randf() < 0.92:
				await result.collider.take_damage(1)
				print("⚔️ ¡Golpeaste al enemigo!")
			else:
				print("❌ ¡Has fallado el ataque!")
	
	# 2. Esperar directamente a que los enemigos terminen su turno
	print("⏳ Esperando a que los enemigos terminen su turno...")
	var enemies_node = get_tree().get_first_node_in_group("EnemyManager")
	if enemies_node:
		await enemies_node.process_enemy_turn()
		print("✅ Enemigos terminaron su turno")
	
	# 3. Pequeña pausa de transición y DESBLOQUEAR
	await get_tree().create_timer(0.1).timeout
	print("🔓 DESBLOQUEANDO INPUTS - Flujo de combate completado")
	is_action_locked = false

func take_damage(damage_taken: int) -> void:
	# ⚠️ NO bloqueamos ni desbloqueamos aquí
	# try_attack() mantiene el bloqueo durante todo el turno del enemigo
	
	var vida_anterior = Global.health
	Global.health -= damage_taken
	
	print("💥 ¡Recibiste ", damage_taken, " de daño!")
	print("❤️ Vida: ", vida_anterior, " → ", Global.health)
	
	if Global.health <= 0:
		print("💀 ¡Has muerto!")
		get_tree().reload_current_scene()
	else:
		$AnimationPlayer.play("Hit")
		# ESPERAR a que termine la animación de daño del jugador
		await $AnimationPlayer.animation_finished
