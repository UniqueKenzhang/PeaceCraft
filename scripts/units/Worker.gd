extends Node2D

class_name Worker

const BuildingGrid = preload("res://scripts/GridMap.gd")

signal delivery_completed(worker: Worker)
signal returned_to_source(worker: Worker)

enum State {
	IDLE,
	MOVING_TO_WAREHOUSE,
	DELIVERING,
	RETURNING_TO_SOURCE
}

var state: State = State.IDLE
var source_building: Node2D = null
var target_warehouse: Node2D = null
var building_grid: BuildingGrid = null

var resource_name: String = ""
var resource_quantity: int = 0
var faction: String = ""

var current_path: Array = []
var current_path_index: int = 0
var move_speed: float = 60.0

var carrying_resource: bool = false
var outbound_path: Array = []

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	if state == State.MOVING_TO_WAREHOUSE or state == State.RETURNING_TO_SOURCE:
		_move_along_path(delta)

func initialize(source: Node2D, warehouse: Node2D, grid: BuildingGrid, res_name: String, res_qty: int, fac: String) -> void:
	source_building = source
	target_warehouse = warehouse
	building_grid = grid
	resource_name = res_name
	resource_quantity = res_qty
	faction = fac
	
	global_position = source_building.global_position
	carrying_resource = true
	
	_update_visuals()
	_calculate_path_to_warehouse()
	state = State.MOVING_TO_WAREHOUSE

func _calculate_path_to_warehouse() -> void:
	if building_grid == null or target_warehouse == null:
		print("Worker: Cannot calculate path - grid or warehouse is null")
		return
	
	var start_road_pos = _get_connected_road_position(source_building)
	var end_road_pos = _get_connected_road_position(target_warehouse)
	
	if start_road_pos == Vector2i(-1, -1):
		print("Worker: No road found near source building at ", source_building.name)
		return
	
	if end_road_pos == Vector2i(-1, -1):
		print("Worker: No road found near warehouse at ", target_warehouse.name)
		return
	
	current_path = building_grid.find_path(start_road_pos, end_road_pos)
	current_path_index = 0
	
	if current_path.is_empty():
		print("Worker: No path found to warehouse from ", start_road_pos, " to ", end_road_pos)
	else:
		outbound_path = current_path.duplicate()
		print("Worker: Path found with ", current_path.size(), " steps")

func _find_nearby_road(grid_pos: Vector2i) -> Vector2i:
	var pos_key = str(grid_pos.x, ",", grid_pos.y)
	
	if building_grid.road_network.has(pos_key):
		return grid_pos
	
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var neighbor = Vector2i(grid_pos.x + dx, grid_pos.y + dy)
			var neighbor_key = str(neighbor.x, ",", neighbor.y)
			if building_grid.road_network.has(neighbor_key):
				return neighbor
	
	return Vector2i(-1, -1)

func _get_connected_road_position(building: Node2D) -> Vector2i:
	print("=== _get_connected_road_position ===")
	print("  Building: ", building.name if building != null else "null")
	
	if building == null:
		print("  ERROR: Building is null")
		return Vector2i(-1, -1)
	
	if not building.has_method("get_connected_roads"):
		print("  ERROR: Building has no get_connected_roads method")
		return Vector2i(-1, -1)
	
	var connected_roads = building.get_connected_roads()
	print("  Connected roads count: ", connected_roads.size())
	
	if connected_roads.is_empty():
		print("  ERROR: No connected roads")
		return Vector2i(-1, -1)
	
	for i in range(connected_roads.size()):
		var road = connected_roads[i]
		print("  Road[", i, "]: ", road.name if road != null else "null")
	
	var road = connected_roads[0]
	if road == null:
		print("  ERROR: First road is null")
		return Vector2i(-1, -1)
	
	var grid_pos = Vector2i(-1, -1)
	if road.has_method("get_grid_position"):
		grid_pos = road.get_grid_position()
		print("  Got grid position via method: ", grid_pos)
	elif "grid_position" in road:
		grid_pos = road.grid_position
		print("  Got grid position via property: ", grid_pos)
	else:
		print("  ERROR: Road has no grid_position")
		return Vector2i(-1, -1)
	
	print("  SUCCESS: Returning ", grid_pos)
	return grid_pos

func _move_along_path(delta: float) -> void:
	if current_path.is_empty() or current_path_index >= current_path.size():
		return
	
	var target_grid_pos = current_path[current_path_index]
	var target_world_pos = building_grid.grid_to_world(target_grid_pos)
	
	var direction = (target_world_pos - global_position).normalized()
	var distance = global_position.distance_to(target_world_pos)
	
	var move_distance = move_speed * delta
	
	if move_distance >= distance:
		global_position = target_world_pos
		current_path_index += 1
		
		if current_path_index >= current_path.size():
			_on_path_completed()
	else:
		global_position += direction * move_distance

func _on_path_completed() -> void:
	if state == State.MOVING_TO_WAREHOUSE:
		_deliver_resource()
	elif state == State.RETURNING_TO_SOURCE:
		_on_returned_to_source()

func _deliver_resource() -> void:
	state = State.DELIVERING
	
	var game_state = get_node("/root/GameState")
	if game_state != null:
		game_state.add_to_warehouse(faction, resource_name, resource_quantity)
		print("Worker: Delivered ", resource_quantity, " ", resource_name, " to warehouse")
	
	carrying_resource = false
	delivery_completed.emit(self)
	
	if not outbound_path.is_empty():
		current_path = outbound_path.duplicate()
		current_path.reverse()
		current_path_index = 0
		print("Worker: Returning via same path with ", current_path.size(), " steps")
		state = State.RETURNING_TO_SOURCE
	else:
		print("Worker: No outbound path to return on")
		state = State.IDLE

func _on_returned_to_source() -> void:
	state = State.IDLE
	returned_to_source.emit(self)
	print("Worker: Returned to source building")

func set_faction(fac: String) -> void:
	faction = fac
	_update_visuals()

func _update_visuals() -> void:
	var sprite = $Sprite2D/ColorRect
	if sprite != null:
		if faction == "Human":
			sprite.color = Color(0.8, 0.6, 0.4, 1)
		else:
			sprite.color = Color(0.6, 0.4, 0.8, 1)
