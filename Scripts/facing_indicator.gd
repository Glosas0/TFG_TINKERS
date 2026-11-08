extends Node2D

const TILE_SIZE = 48
var show_indicator: bool = false

func _ready() -> void:
	position = Vector2.ZERO
	
	var player = get_parent()
	if player.has_signal("player_moved"):
		player.connect("player_moved", Callable(self, "queue_redraw"))
	if player.has_signal("player_action_completed"):
		player.connect("player_action_completed", Callable(self, "queue_redraw"))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_G:
			show_indicator = !show_indicator
			queue_redraw()

func _process(_delta: float) -> void:
	# Redibujar constantemente para el efecto de pulso
	if show_indicator:
		queue_redraw()

func _draw() -> void:
	if not show_indicator:
		return
	
	var player = get_parent()
	if player == null:
		return
	
	var facing_dir = player.get("facing_direction")
	if facing_dir == null or facing_dir == Vector2.ZERO:
		return
	
	# --- CÁLCULO DEL CENTRO DE LA CASILLA DEL JUGADOR ---
	var player_global_pos = player.global_position
	var grid_x = floor(player_global_pos.x / TILE_SIZE)
	var grid_y = floor(player_global_pos.y / TILE_SIZE)
	
	var player_tile_center_global = Vector2(
		grid_x * TILE_SIZE + TILE_SIZE / 2,
		grid_y * TILE_SIZE + TILE_SIZE / 2
	)
	var player_tile_center_local = to_local(player_tile_center_global)
	
	# --- EFECTO DE ECO ---
	var time = Time.get_ticks_msec() / 6000.0
	var pulse = 0.8 + 0.1 * sin(time * 8.0)
	var glow_color = Color(2, 0.7, 0.1, pulse)
	
	# --- CORRECCIÓN: Reducir 1 píxel para evitar solapamiento ---
	var half_tile = TILE_SIZE / 2.0
	var border_fix := 5  # Ajuste para que los bordes no se solapen
	
	# --- CASILLA DEL JUGADOR ---
	var player_tile_rect = Rect2(
		player_tile_center_local.x - half_tile + border_fix,
		player_tile_center_local.y - half_tile + border_fix,
		TILE_SIZE - border_fix * 2,
		TILE_SIZE - border_fix * 2
	)
	draw_rect(player_tile_rect, glow_color, false, 2.0)
	
	# --- TRAYECTORIA ---
	var grid_dir = Vector2(
		sign(facing_dir.x),
		sign(facing_dir.y)
	)
	
	var max_distance = 10
	
	for i in range(1, max_distance + 1):
		var tile_offset = grid_dir * i
		
		var trail_offset_global = Vector2(
			tile_offset.x * TILE_SIZE,
			tile_offset.y * TILE_SIZE
		)
		
		var trail_tile_center_global = player_tile_center_global + trail_offset_global
		var trail_tile_center_local = to_local(trail_tile_center_global)
		
		var trail_pulse = pulse * (1.0 - float(i) / max_distance)
		var trail_color = Color(0.4, 0.8, 1.0, trail_pulse)
		
		# Mismo ajuste de 1 píxel
		var trail_tile_rect = Rect2(
			trail_tile_center_local.x - half_tile + border_fix,
			trail_tile_center_local.y - half_tile + border_fix,
			TILE_SIZE - border_fix * 2,
			TILE_SIZE - border_fix * 2
		)
		draw_rect(trail_tile_rect, trail_color, false, 2.0)
	
	# --- TRIÁNGULO ---
	var triangle_size = 3
	var edge_offset = Vector2.ZERO
	if abs(facing_dir.x) > 0.1:
		edge_offset.x = sign(facing_dir.x) * half_tile
	if abs(facing_dir.y) > 0.1:
		edge_offset.y = sign(facing_dir.y) * half_tile
	
	var tip_pos = player_tile_center_local + edge_offset
	var dir_norm = facing_dir.normalized()
	var perp = Vector2(-dir_norm.y, dir_norm.x).normalized() * triangle_size * 2
	var base1 = tip_pos - dir_norm * triangle_size + perp
	var base2 = tip_pos - dir_norm * triangle_size - perp
	
	var points = PackedVector2Array([tip_pos, base1, base2])
	draw_colored_polygon(points, Color(1.0, 1.0, 0.0, 0.412))
