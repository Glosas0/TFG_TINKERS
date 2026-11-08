extends CharacterBody2D

const TILE_SIZE = 48
var is_hooked: bool = false
var original_modulate: Color = Color.WHITE

func _ready() -> void:
	# Añadir al grupo para que el gancho y el jugador la reconozcan
	add_to_group("Rock")
	original_modulate = modulate

# Método necesario para que el gancho cambie su color a naranja
func set_hooked(hooked: bool) -> void:
	is_hooked = hooked
	if hooked:
		modulate = Color(1.0, 0.6, 0.2) # Naranja
	else:
		modulate = original_modulate

# Método para ser empujada por el jugador o por otras mecánicas
func try_push(direction: Vector2) -> bool:
	var target_pos = global_position + direction * TILE_SIZE
	
	# Verificar que la casilla destino esté libre (sin paredes, enemigos u otras rocas)
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, target_pos)
	query.exclude = [get_rid()]
	var result = space_state.intersect_ray(query)
	
	if result.is_empty():
		global_position = target_pos
		return true
	return false
