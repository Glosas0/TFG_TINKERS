extends GridContainer

const TILE_SIZE: int = 48
const ROOM_SLOT_TILES: int = 17
const ROOM_DRAW_TILES: int = 11
const MAP_WIDTH_TILES: int = 7 * ROOM_SLOT_TILES
const ROOM_SPACING: float = 816.0

const FLOOR_COLOR := Color(0.66, 0.75, 0.66, 1.0)
const WALL_COLOR := Color(0.25, 0.30, 0.26, 1.0)
const CORRIDOR_COLOR := Color(0.78, 0.70, 0.48, 1.0)
const PLAYER_COLOR := Color(1.0, 0.82, 0.12, 1.0)
const ENEMY_COLOR := Color(1.0, 0.18, 0.18, 1.0)
const KEY_COLOR := Color(1.0, 0.88, 0.12, 1.0)
const COIN_COLOR := Color(0.20, 0.85, 1.0, 1.0)
const HEART_COLOR := Color(1.0, 0.30, 0.48, 1.0)

var player: CharacterBody2D
var generation: Node
var explored_tiles: Dictionary = {}
var explored_corridor_tiles: Dictionary = {}
var visited_rooms: Dictionary = {}
var blink_time: float = 0.0

func _ready() -> void:
	var minimap_panel := get_parent() as Panel
	if minimap_panel != null:
		minimap_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		minimap_panel.modulate = Color(1.0, 1.0, 1.0, 1.0)

	player = get_tree().get_first_node_in_group("Player") as CharacterBody2D
	generation = get_tree().current_scene.get_node_or_null("Generation")
	columns = MAP_WIDTH_TILES
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)
	call_deferred("initialize_minimap")

func initialize_minimap() -> void:
	if player == null or generation == null:
		push_warning("Minimap: no se encuentra Player o Generation.")
		return

	call_deferred("_connect_minimap_signal")
	call_deferred("_reveal_initial_room")
	
	reveal_player_position()
	queue_redraw()

func _reveal_initial_room() -> void:
	await get_tree().physics_frame
	
	var player_room := room_at_world_position(player.global_position)
	if is_valid_room(player_room) and generation.map[player_room.x][player_room.y]:
		visited_rooms[player_room] = true
		reveal_room(player_room)
		queue_redraw()

func _connect_minimap_signal() -> void:
	var moved_callback := Callable(self, "on_player_moved")
	if player.has_signal("player_moved") and not player.is_connected("player_moved", moved_callback):
		player.connect("player_moved", moved_callback)

func _process(delta: float) -> void:
	blink_time += delta
	queue_redraw()

func on_player_moved() -> void:
	reveal_player_position()
	queue_redraw()

func reveal_player_position() -> void:
	if player == null or generation == null or generation.map.is_empty():
		return

	var player_cell := world_to_map_cell(player.global_position)
	var player_room := room_at_world_position(player.global_position)

	var is_in_room: bool = is_valid_room(player_room) and generation.map[player_room.x][player_room.y]
	var is_deep_interior: bool = false
	var player_at_nexus: bool = false

	if is_in_room:
		var room_origin := Vector2(player_room) * ROOM_SPACING
		
		var local_x: int = floori((player.global_position.x - room_origin.x) / TILE_SIZE)
		var local_y: int = floori((player.global_position.y - room_origin.y) / TILE_SIZE)
		
		is_deep_interior = local_x >= 2 and local_x <= (ROOM_DRAW_TILES - 3) \
			and local_y >= 2 and local_y <= (ROOM_DRAW_TILES - 3)
		
		player_at_nexus = (local_x == 1 or local_x == (ROOM_DRAW_TILES - 2)) \
			or (local_y == 1 or local_y == (ROOM_DRAW_TILES - 2))

	if is_in_room and is_deep_interior and not visited_rooms.has(player_room):
		visited_rooms[player_room] = true
		reveal_room(player_room)

	reveal_around_player(player_cell, is_in_room, player_at_nexus)


func reveal_around_player(center_cell: Vector2i, player_in_room: bool, player_at_nexus: bool) -> void:
	for offset_y in range(-2, 3):
		for offset_x in range(-2, 3):
			var check_cell: Vector2i = center_cell + Vector2i(offset_x, offset_y)
			
			if check_cell.x < 0 or check_cell.y < 0 or check_cell.x >= MAP_WIDTH_TILES or check_cell.y >= MAP_WIDTH_TILES:
				continue

			var world_pos := Vector2(
				check_cell.x * TILE_SIZE + TILE_SIZE / 2.0,
				check_cell.y * TILE_SIZE + TILE_SIZE / 2.0
			)

			var cell_room := room_at_world_position(world_pos)
			var is_in_room_target: bool = is_valid_room(cell_room) and generation.map[cell_room.x][cell_room.y]

			# REGLA DE ORO: Si el jugador está en la sala pero NO en la casilla de nexo,
			# ocultamos ABSOLUTAMENTE TODO lo que no pertenezca a su sala actual.
			if player_in_room and not player_at_nexus:
				if not is_in_room_target:
					continue

			# --- DIBUJADO DE LA CASILLA ---
			if is_in_room_target:
				var is_unvisited: bool = not visited_rooms.has(cell_room)
				
				# Calcular posición lógica en la cuadrícula de la sala (0 a 10)
				var room_origin := Vector2(cell_room) * ROOM_SPACING
				var lx: int = floori((world_pos.x - room_origin.x) / TILE_SIZE)
				var ly: int = floori((world_pos.y - room_origin.y) / TILE_SIZE)
				
				if is_unvisited:
					# Sala no visitada: usar is_wall_at para determinar si es un muro real
					var is_wall := is_wall_at(world_pos)
					
					# CORRECCIÓN: Solo el borde EXACTO (lx==0, lx==10, ly==0, ly==10) es la casilla de unión
					var is_exact_edge: bool = (lx == 0 or lx == ROOM_DRAW_TILES - 1 or ly == 0 or ly == ROOM_DRAW_TILES - 1)
					
					if is_wall:
						# Es un muro físico → negro
						explored_tiles[check_cell] = WALL_COLOR
					elif is_exact_edge:
						# Casilla de unión en el borde exacto → marrón
						explored_tiles[check_cell] = CORRIDOR_COLOR
					else:
						# Interior de la sala → verde
						explored_tiles[check_cell] = FLOOR_COLOR
					explored_corridor_tiles[check_cell] = true
				else:
					# Sala visitada: usar la misma lógica
					var is_wall := is_wall_at(world_pos)
					var is_exact_edge: bool = (lx == 0 or lx == ROOM_DRAW_TILES - 1 or ly == 0 or ly == ROOM_DRAW_TILES - 1)
					
					if is_wall:
						explored_tiles[check_cell] = WALL_COLOR
					elif is_exact_edge:
						explored_tiles[check_cell] = CORRIDOR_COLOR
					else:
						explored_tiles[check_cell] = FLOOR_COLOR
			else:
				# --- LÓGICA DEL PASILLO ---
				# Solo llegamos aquí si el jugador NO está en la sala, O está exactamente en el nexo.
				if is_valid_tile(check_cell):
					if is_wall_at(world_pos):
						explored_tiles[check_cell] = WALL_COLOR
					else:
						explored_tiles[check_cell] = CORRIDOR_COLOR
					explored_corridor_tiles[check_cell] = true


func is_valid_tile(cell: Vector2i) -> bool:
	var slot_x := cell.x / ROOM_SLOT_TILES
	var slot_y := cell.y / ROOM_SLOT_TILES
	var local_x := cell.x % ROOM_SLOT_TILES
	var local_y := cell.y % ROOM_SLOT_TILES
	
	# Si está dentro de una sala existente
	if local_x < ROOM_DRAW_TILES and local_y < ROOM_DRAW_TILES:
		if slot_x < generation.map_width and slot_y < generation.map_height:
			if generation.map[slot_x][slot_y]:
				return true
	
	# Si está en un pasillo horizontal (conecta slot_x con slot_x+1)
	if local_y >= 4 and local_y <= 6 and local_x >= 11:
		if slot_x + 1 < generation.map_width:
			if generation.map[slot_x][slot_y] and generation.map[slot_x + 1][slot_y]:
				return true
				
	# Si está en un pasillo vertical (conecta slot_y con slot_y+1)
	if local_x >= 4 and local_x <= 6 and local_y >= 11:
		if slot_y + 1 < generation.map_height:
			if generation.map[slot_x][slot_y] and generation.map[slot_x][slot_y + 1]:
				return true
				
	return false

func is_valid_room(room_pos: Vector2i) -> bool:
	return room_pos.x >= 0 and room_pos.x < generation.map_width \
		and room_pos.y >= 0 and room_pos.y < generation.map_height

func room_at_world_position(world_pos: Vector2) -> Vector2i:
	var slot_x := floori(world_pos.x / ROOM_SPACING)
	var slot_y := floori(world_pos.y / ROOM_SPACING)
	if slot_x < 0 or slot_y < 0:
		return Vector2i(-1, -1)

	var local_cell_x := floori((world_pos.x - slot_x * ROOM_SPACING) / TILE_SIZE)
	var local_cell_y := floori((world_pos.y - slot_y * ROOM_SPACING) / TILE_SIZE)
	if local_cell_x >= ROOM_DRAW_TILES or local_cell_y >= ROOM_DRAW_TILES:
		return Vector2i(-1, -1)
	return Vector2i(slot_x, slot_y)

func reveal_room(room_pos: Vector2i) -> void:
	var room_origin := Vector2(room_pos) * ROOM_SPACING

	for local_y in range(ROOM_DRAW_TILES):
		for local_x in range(ROOM_DRAW_TILES):
			var world_pos := room_origin + Vector2(
				local_x * TILE_SIZE + TILE_SIZE / 2.0,
				local_y * TILE_SIZE + TILE_SIZE / 2.0
			)
			var cell := Vector2i(
				room_pos.x * ROOM_SLOT_TILES + local_x,
				room_pos.y * ROOM_SLOT_TILES + local_y
			)
			
			var is_wall := is_wall_at(world_pos)
			var is_edge := (local_x == 0 or local_x == ROOM_DRAW_TILES - 1 or local_y == 0 or local_y == ROOM_DRAW_TILES - 1)

			if is_wall:
				explored_tiles[cell] = WALL_COLOR
			elif is_edge:
				explored_tiles[cell] = CORRIDOR_COLOR
			else:
				explored_tiles[cell] = FLOOR_COLOR

func is_wall_at(world_pos: Vector2) -> bool:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = world_pos
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.collision_mask = 1

	var world := player.get_world_2d()
	if world == null:
		return false

	var hits := world.direct_space_state.intersect_point(query, 16)
	for hit in hits:
		var collider: Object = hit.get("collider")
		if collider is Node and collider.is_in_group("Wall"):
			return true
	return false

func world_to_map_cell(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		floori(world_pos.x / TILE_SIZE),
		floori(world_pos.y / TILE_SIZE)
	)

func _draw() -> void:
	var cell_size: float = min(size.x / MAP_WIDTH_TILES, size.y / MAP_WIDTH_TILES)
	if cell_size <= 0.0:
		return

	var map_pixel_size := Vector2(cell_size * MAP_WIDTH_TILES, cell_size * MAP_WIDTH_TILES)
	var origin_x: float = floor((size.x - map_pixel_size.x) * 0.5)
	var origin_y: float = floor((size.y - map_pixel_size.y) * 0.5)
	var origin := Vector2(origin_x, origin_y)

	var cell_w: float = ceil(cell_size)
	var cell_h: float = ceil(cell_size)

	for cell_variant in explored_tiles.keys():
		var cell: Vector2i = cell_variant
		if cell.x < 0 or cell.y < 0 or cell.x >= MAP_WIDTH_TILES or cell.y >= MAP_WIDTH_TILES:
			continue
		
		var rect_x: float = floor(origin.x + float(cell.x) * cell_size)
		var rect_y: float = floor(origin.y + float(cell.y) * cell_size)
		
		var rect := Rect2(rect_x, rect_y, cell_w, cell_h)
		draw_rect(rect, explored_tiles[cell])

	if player == null:
		return

	var player_cell := world_to_map_cell(player.global_position)
	var current_room := room_at_world_position(player.global_position)
	var pulse: float = 0.55 + 0.45 * absf(sin(blink_time * 5.0))

	for enemy in get_tree().get_nodes_in_group("Enemy"):
		if not is_instance_valid(enemy):
			continue
		var enemy_cell := world_to_map_cell(enemy.global_position)
		var enemy_room := room_at_world_position(enemy.global_position)
		var visible_in_current_room := is_valid_room(current_room) \
			and enemy_room == current_room and visited_rooms.has(current_room)
		var visible_in_explored_corridor := explored_corridor_tiles.has(enemy_cell) \
			and enemy_room == Vector2i(-1, -1)
		if visible_in_current_room or visible_in_explored_corridor:
			draw_map_marker(origin, cell_size, enemy_cell, ENEMY_COLOR, 0.18)

	draw_room_items(origin, cell_size, "MinimapKey", KEY_COLOR)
	draw_room_items(origin, cell_size, "MinimapCoin", COIN_COLOR)
	draw_room_items(origin, cell_size, "MinimapHeart", HEART_COLOR)

	if player_cell.x >= 0 and player_cell.y >= 0 and player_cell.x < MAP_WIDTH_TILES and player_cell.y < MAP_WIDTH_TILES:
		var p_rect_x: float = floor(origin.x + float(player_cell.x) * cell_size)
		var p_rect_y: float = floor(origin.y + float(player_cell.y) * cell_size)
		
		var player_rect := Rect2(p_rect_x, p_rect_y, cell_w, cell_h)
		draw_rect(player_rect, Color(PLAYER_COLOR.r, PLAYER_COLOR.g, PLAYER_COLOR.b, pulse))
		draw_rect(player_rect, Color(1.0, 0.95, 0.55, 1.0), false, maxf(1.0, cell_size * 0.12))

func draw_room_items(origin: Vector2, cell_size: float, group_name: String, marker_color: Color) -> void:
	for item in get_tree().get_nodes_in_group(group_name):
		if not is_instance_valid(item):
			continue
		var item_room := room_at_world_position(item.global_position)
		if not is_valid_room(item_room) or not visited_rooms.has(item_room):
			continue
		var item_cell := world_to_map_cell(item.global_position)
		draw_map_marker(origin, cell_size, item_cell, marker_color, 0.18)

func draw_map_marker(origin: Vector2, cell_size: float, cell: Vector2i, marker_color: Color, inset_ratio: float) -> void:
	if cell.x < 0 or cell.y < 0 or cell.x >= MAP_WIDTH_TILES or cell.y >= MAP_WIDTH_TILES:
		return
	
	var base_x: float = floor(origin.x + float(cell.x) * cell_size)
	var base_y: float = floor(origin.y + float(cell.y) * cell_size)
	var cell_w: float = ceil(cell_size)
	var cell_h: float = ceil(cell_size)
	
	var inset_x: float = cell_w * inset_ratio
	var inset_y: float = cell_h * inset_ratio
	var marker_w: float = maxf(1.0, cell_w - inset_x * 2.0)
	var marker_h: float = maxf(1.0, cell_h - inset_y * 2.0)
	
	var marker_position := Vector2(base_x + inset_x, base_y + inset_y)
	draw_rect(Rect2(marker_position, Vector2(marker_w, marker_h)), marker_color)
