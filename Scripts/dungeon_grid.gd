# dungeon_grid.gd
extends Node2D

const TILE_SIZE := 48

var show_grid: bool = false
var dungeon_size: Vector2 = Vector2.ZERO

func _ready() -> void:
	# Calcular el tamaño total de la dungeon
	var generation = get_tree().current_scene.get_node_or_null("Generation")
	if generation == null:
		push_warning("DungeonGrid: no se encuentra Generation")
		return
	
	var map_width = generation.map_width
	var map_height = generation.map_height
	var room_spacing = 816.0
	dungeon_size = Vector2(map_width * room_spacing, map_height * room_spacing)

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("toggle_grid"):
		show_grid = !show_grid
		queue_redraw()

func _draw() -> void:
	if not show_grid:
		return
	
	var grid_color: Color = Color(0.8, 0.9, 1.0, 0.2)
	
	var tiles_x = int(dungeon_size.x / TILE_SIZE)
	var tiles_y = int(dungeon_size.y / TILE_SIZE)
	
	# Dibujar líneas verticales
	for i in range(tiles_x + 1):
		var x_pos = i * TILE_SIZE
		draw_line(Vector2(x_pos, 0), Vector2(x_pos, dungeon_size.y), grid_color, 1.0)
	
	# Dibujar líneas horizontales
	for i in range(tiles_y + 1):
		var y_pos = i * TILE_SIZE
		draw_line(Vector2(0, y_pos), Vector2(dungeon_size.x, y_pos), grid_color, 1.0)
