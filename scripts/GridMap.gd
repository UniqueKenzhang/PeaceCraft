extends Node2D

class_name BuildingGrid

signal grid_updated()

# 格子配置
const CELL_SIZE = 16
const GRID_WIDTH = 100
const GRID_HEIGHT = 100

# 格子数据：key = "x,y", value = building_node
var grid_data: Dictionary = {}

var warehouse_buildings: Array = []

var warehouse_building: Node2D:
	get:
		if warehouse_buildings.is_empty():
			return null
		return warehouse_buildings[0]

# 格子颜色
const GRID_COLOR = Color(0.3, 0.3, 0.3, 0.3)
const HIGHLIGHT_COLOR = Color(0.0, 1.0, 0.0, 0.3)
const INVALID_COLOR = Color(1.0, 0.0, 0.0, 0.3)
const LIGHT_TILE_COLOR = Color(0.9, 0.9, 0.9, 1.0)
const DARK_TILE_COLOR = Color(0.7, 0.7, 0.7, 1.0)
const OCCUPIED_OVERLAY_COLOR = Color(0.0, 0.0, 0.0, 0.5)

# 调试选项
var debug_show_occupied: bool = true

# 地图移动配置
const EDGE_THRESHOLD = 50.0
const CAMERA_SPEED = 500.0

# 当前高亮的格子
var highlighted_cell: Vector2i = Vector2i(-1, -1)
var is_placement_valid: bool = true
var placement_building_name: String = ""

# 建筑大小配置（格子数）
var building_sizes: Dictionary = {
	"Farm": Vector2i(10, 8), # 不要更改
	"Lumberjack": Vector2i(5, 3),
	"SulfurMine": Vector2i(1, 1),
	"FungusCave": Vector2i(1, 1),
	"Armory": Vector2i(2, 1),
	"Workshop": Vector2i(2, 1),
	"Lair": Vector2i(2, 1),
	"DeserterShelter": Vector2i(2, 1),
	"Road": Vector2i(1, 1),
	"Warehouse": Vector2i(9, 9)
}

# 道路网格
var road_network: Dictionary = {}

# 道路路径预览
var road_preview_path: Array = []

# TileLayer引用
@onready var road_tile_layer: TileMapLayer = $RoadTileLayer
@onready var camera: Camera2D = $Camera2D

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	_handle_camera_movement(delta)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		debug_show_occupied = not debug_show_occupied
		queue_redraw()

func _handle_camera_movement(delta: float) -> void:
	var viewport_size = get_viewport_rect().size
	var mouse_pos = get_viewport().get_mouse_position()
	var move_vector = Vector2.ZERO
	
	if mouse_pos.x < EDGE_THRESHOLD:
		move_vector.x -= 1
	elif mouse_pos.x > viewport_size.x - EDGE_THRESHOLD:
		move_vector.x += 1
	
	if mouse_pos.y < EDGE_THRESHOLD:
		move_vector.y -= 1
	elif mouse_pos.y > viewport_size.y - EDGE_THRESHOLD:
		move_vector.y += 1
	
	if move_vector != Vector2.ZERO:
		var new_position = camera.position + move_vector * CAMERA_SPEED * delta
		camera.position = _clamp_camera_position(new_position)

func _clamp_camera_position(new_position: Vector2) -> Vector2:
	var viewport_size = get_viewport_rect().size
	var half_viewport = viewport_size / 2.0
	
	var min_x = half_viewport.x
	var max_x = GRID_WIDTH * CELL_SIZE - half_viewport.x
	var min_y = half_viewport.y
	var max_y = GRID_HEIGHT * CELL_SIZE - half_viewport.y
	
	new_position.x = clamp(new_position.x, min_x, max_x)
	new_position.y = clamp(new_position.y, min_y, max_y)
	
	return new_position

func _draw() -> void:
	# 绘制被占用的格子（调试功能）
	if debug_show_occupied:
		for key in grid_data:
			var parts = key.split(",")
			var x = int(parts[0])
			var y = int(parts[1])
			var rect = Rect2(x * CELL_SIZE, y * CELL_SIZE, CELL_SIZE, CELL_SIZE)
			draw_rect(rect, OCCUPIED_OVERLAY_COLOR)
	
	# 绘制高亮格子区域
	if highlighted_cell.x >= 0 and highlighted_cell.y >= 0 and not placement_building_name.is_empty():
		var size = get_building_size(placement_building_name)
		var color = HIGHLIGHT_COLOR if is_placement_valid else INVALID_COLOR
		var rect = Rect2(
			(highlighted_cell.x - size.x / 2) * CELL_SIZE,
			(highlighted_cell.y - size.y / 2) * CELL_SIZE,
			size.x * CELL_SIZE,
			size.y * CELL_SIZE
		)
		draw_rect(rect, color)
	
	# 绘制道路路径预览
	if not road_preview_path.is_empty():
		for grid_pos in road_preview_path:
			var rect = Rect2(
				grid_pos.x * CELL_SIZE,
				grid_pos.y * CELL_SIZE,
				CELL_SIZE,
				CELL_SIZE
			)
			draw_rect(rect, Color(0.0, 1.0, 0.5, 0.3))

func world_to_grid(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		floor((world_pos.x - CELL_SIZE / 2.0) / CELL_SIZE),
		floor((world_pos.y - CELL_SIZE / 2.0) / CELL_SIZE)
	)

func grid_to_world(grid_pos: Vector2i) -> Vector2:
	return Vector2(
		grid_pos.x * CELL_SIZE + CELL_SIZE / 2.0,
		grid_pos.y * CELL_SIZE + CELL_SIZE / 2.0
	)

func is_cell_valid(grid_pos: Vector2i) -> bool:
	return grid_pos.x >= 0 and grid_pos.x < GRID_WIDTH and grid_pos.y >= 0 and grid_pos.y < GRID_HEIGHT

func is_cell_occupied(grid_pos: Vector2i) -> bool:
	return grid_data.has(str(grid_pos.x, ",", grid_pos.y))

func is_area_occupied(center_pos: Vector2i, size: Vector2i) -> bool:
	var half_size_x = floor(size.x / 2.0)
	var half_size_y = floor(size.y / 2.0)
	
	for x in range(center_pos.x - half_size_x, center_pos.x + size.x - half_size_x):
		for y in range(center_pos.y - half_size_y, center_pos.y + size.y - half_size_y):
			var cell_pos = Vector2i(x, y)
			if not is_cell_valid(cell_pos) or is_cell_occupied(cell_pos):
				return true
	return false

func occupy_area(center_pos: Vector2i, size: Vector2i, building: Node2D) -> bool:
	if is_area_occupied(center_pos, size):
		return false
	
	var half_size_x = floor(size.x / 2.0)
	var half_size_y = floor(size.y / 2.0)
	
	for x in range(center_pos.x - half_size_x, center_pos.x + size.x - half_size_x):
		for y in range(center_pos.y - half_size_y, center_pos.y + size.y - half_size_y):
			var cell_pos = Vector2i(x, y)
			grid_data[str(cell_pos.x, ",", cell_pos.y)] = building
	
	emit_signal("grid_updated")
	return true

func clear_area(start_pos: Vector2i, size: Vector2i) -> void:
	var half_size_x = floor(size.x / 2.0)
	var half_size_y = floor(size.y / 2.0)
	

	for x in range(start_pos.x - half_size_x, start_pos.x + size.x - half_size_x):
		for y in range(start_pos.y - half_size_y, start_pos.y + size.y - half_size_y):
			var cell_pos = Vector2i(x, y)
			grid_data.erase(str(cell_pos.x, ",", cell_pos.y))
	
	emit_signal("grid_updated")

func get_building_size(building_name: String) -> Vector2i:
	if building_sizes.has(building_name):
		return building_sizes[building_name]
	return Vector2i(1, 1)

func update_highlight(world_pos: Vector2, building_name: String) -> void:
	placement_building_name = building_name
	var grid_pos = world_to_grid(world_pos)
	var size = get_building_size(building_name)
	
	# 检查整个区域是否有效
	var valid = true
	for x in range(grid_pos.x - size.x / 2, grid_pos.x + size.x - size.x / 2):
		for y in range(grid_pos.y - size.y / 2, grid_pos.y + size.y - size.y / 2):
			var cell_pos = Vector2i(x, y)
			if not is_cell_valid(cell_pos) or is_cell_occupied(cell_pos):
				valid = false
				break
		if not valid:
			break
	
	highlighted_cell = grid_pos
	is_placement_valid = valid
	queue_redraw()

func add_road_to_tilemap(grid_pos: Vector2i) -> void:
	var key = str(grid_pos.x, ",", grid_pos.y)
	road_network[key] = null
	road_tile_layer.set_cell(grid_pos, 0, Vector2i(0, 0))
	print("  Added road to network at: ", grid_pos, " key: ", key)

func add_road(grid_pos: Vector2i, road: Road) -> void:
	var key = str(grid_pos.x, ",", grid_pos.y)
	road_network[key] = road
	road_tile_layer.set_cell(grid_pos, 0, Vector2i(0, 0))
	road.set_grid_position(grid_pos)
	_update_road_connections(road)
	_check_nearby_buildings(road, grid_pos)
	print("  Added road to network at: ", grid_pos, " key: ", key)

func _check_nearby_buildings(road: Road, grid_pos: Vector2i) -> void:
	var neighbors = [
		Vector2i(grid_pos.x + 1, grid_pos.y),
		Vector2i(grid_pos.x - 1, grid_pos.y),
		Vector2i(grid_pos.x, grid_pos.y + 1),
		Vector2i(grid_pos.x, grid_pos.y - 1)
	]
	
	for neighbor_pos in neighbors:
		var building = get_building_at(neighbor_pos)
		if building != null:
			road.add_connected_building(building)
			if building.has_method("add_connected_road"):
				building.add_connected_road(road)
			if building.has_method("update_warehouse_connection"):
				building.update_warehouse_connection()

func _check_nearby_roads(building: Node2D, cell: Vector2i) -> void:
	var neighbors = [
		Vector2i(cell.x + 1, cell.y),
		Vector2i(cell.x - 1, cell.y),
		Vector2i(cell.x, cell.y + 1),
		Vector2i(cell.x, cell.y - 1)
	]
	
	for neighbor_pos in neighbors:
		var road = get_road_at(neighbor_pos)
		if road != null:
			if building.has_method("add_connected_road"):
				building.add_connected_road(road)
				road.add_connected_building(building)
				print("Connected ", building.name, " to road at ", neighbor_pos)

func get_building_at(grid_pos: Vector2i) -> Node2D:
	var key = str(grid_pos.x, ",", grid_pos.y)
	if grid_data.has(key):
		return grid_data[key]
	return null

func on_building_placed(building: Node2D) -> void:
	if not building.has_meta("grid_pos"):
		return
	
	var grid_pos = building.get_meta("grid_pos")
	var size = building.get_meta("grid_size") if building.has_meta("grid_size") else Vector2i(1, 1)
	
	for x in range(size.x):
		for y in range(size.y):
			var cell = Vector2i(
				grid_pos.x - floor(size.x / 2.0) + x,
				grid_pos.y - floor(size.y / 2.0) + y
			)
			_check_nearby_roads(building, cell)
	
	if building.has_method("update_warehouse_connection"):
		building.update_warehouse_connection()

func on_building_removed(building: Node2D) -> void:
	if building.has_method("get_connected_roads"):
		for road in building.get_connected_roads():
			road.remove_connected_building(building)
		building.connected_roads.clear()

func remove_road(grid_pos: Vector2i) -> void:
	var key = str(grid_pos.x, ",", grid_pos.y)
	if road_network.has(key):
		var road = road_network[key]
		if road != null:
			for building in road.connected_buildings:
				if building.has_method("remove_connected_road"):
					building.remove_connected_road(road)
				if building.has_method("update_warehouse_connection"):
					building.update_warehouse_connection()
			_disconnect_road(road)
		road_network.erase(key)
		road_tile_layer.erase_cell(grid_pos)

func _update_road_connections(road: Road) -> void:
	var grid_pos = road.get_grid_position()
	var neighbors = [
		Vector2i(grid_pos.x + 1, grid_pos.y),
		Vector2i(grid_pos.x - 1, grid_pos.y),
		Vector2i(grid_pos.x, grid_pos.y + 1),
		Vector2i(grid_pos.x, grid_pos.y - 1)
	]
	
	for neighbor_pos in neighbors:
		var neighbor_key = str(neighbor_pos.x, ",", neighbor_pos.y)
		if road_network.has(neighbor_key):
			var neighbor_road = road_network[neighbor_key]
			road.add_connected_road(neighbor_road)
			neighbor_road.add_connected_road(road)

func _disconnect_road(road: Road) -> void:
	for connected_road in road.get_connected_roads():
		connected_road.remove_connected_road(road)
	road.connected_roads.clear()

func is_building_connected_to_road(building: Node2D) -> bool:
	var building_grid_pos = world_to_grid(building.global_position)
	var neighbors = [
		Vector2i(building_grid_pos.x + 1, building_grid_pos.y),
		Vector2i(building_grid_pos.x - 1, building_grid_pos.y),
		Vector2i(building_grid_pos.x, building_grid_pos.y + 1),
		Vector2i(building_grid_pos.x, building_grid_pos.y - 1)
	]
	
	for neighbor_pos in neighbors:
		var neighbor_key = str(neighbor_pos.x, ",", neighbor_pos.y)
		if road_network.has(neighbor_key):
			return true
	return false

func get_road_at(grid_pos: Vector2i) -> Road:
	var key = str(grid_pos.x, ",", grid_pos.y)
	if road_network.has(key):
		return road_network[key]
	return null

func find_path(start_pos: Vector2i, end_pos: Vector2i) -> Array:
	var start_key = str(start_pos.x, ",", start_pos.y)
	var end_key = str(end_pos.x, ",", end_pos.y)
	
	print("=== find_path called ===")
	print("  Start: ", start_pos, " key: ", start_key)
	print("  End: ", end_pos, " key: ", end_key)
	
	if not road_network.has(start_key):
		print("  ERROR: Start not in road_network")
		return []
	
	if not road_network.has(end_key):
		print("  ERROR: End not in road_network")
		return []
	
	var start_road = road_network[start_key]
	var end_road = road_network[end_key]
	
	print("  Start road: ", start_road)
	print("  End road: ", end_road)
	
	if start_road == null:
		print("  ERROR: Start road is null")
		return []
	
	if end_road == null:
		print("  ERROR: End road is null")
		return []
	
	print("  Start road connected_roads: ", start_road.connected_roads.size())
	print("  End road connected_roads: ", end_road.connected_roads.size())
	
	var open_set: Array = [start_road]
	var came_from: Dictionary = {}
	var g_score: Dictionary = {}
	var f_score: Dictionary = {}
	
	g_score[start_road] = 0
	f_score[start_road] = _heuristic(start_pos, end_pos)
	
	var iterations = 0
	while not open_set.is_empty():
		iterations += 1
		if iterations > 1000:
			print("  ERROR: Too many iterations, breaking")
			break
		
		var current = _get_lowest_f_score_road(open_set, f_score)
		
		if current == end_road:
			var path = _reconstruct_road_path(came_from, current)
			print("  SUCCESS: Path found with ", path.size(), " steps")
			return path
		
		open_set.erase(current)
		
		for neighbor_road in current.connected_roads:
			if neighbor_road == null:
				print("  WARNING: Null neighbor in connected_roads")
				continue
			
			var tentative_g_score = g_score[current] + 1
			
			if not g_score.has(neighbor_road) or tentative_g_score < g_score[neighbor_road]:
				came_from[neighbor_road] = current
				g_score[neighbor_road] = tentative_g_score
				f_score[neighbor_road] = tentative_g_score + _heuristic(neighbor_road.grid_position, end_pos)
				
				if not open_set.has(neighbor_road):
					open_set.append(neighbor_road)
	
	print("  ERROR: No path found after ", iterations, " iterations")
	return []

func _heuristic(a: Vector2i, b: Vector2i) -> float:
	return abs(a.x - b.x) + abs(a.y - b.y)

func _get_lowest_f_score(open_set: Array, f_score: Dictionary) -> Vector2i:
	var lowest = open_set[0]
	var lowest_score = f_score[str(lowest.x, ",", lowest.y)]
	
	for pos in open_set:
		var score = f_score[str(pos.x, ",", pos.y)]
		if score < lowest_score:
			lowest = pos
			lowest_score = score
	
	return lowest

func _get_neighbors(pos: Vector2i) -> Array:
	var neighbors = []
	neighbors.append(Vector2i(pos.x + 1, pos.y))
	neighbors.append(Vector2i(pos.x - 1, pos.y))
	neighbors.append(Vector2i(pos.x, pos.y + 1))
	neighbors.append(Vector2i(pos.x, pos.y - 1))
	return neighbors

func _reconstruct_path(came_from: Dictionary, current: Vector2i) -> Array:
	var path = [current]
	var current_key = str(current.x, ",", current.y)
	
	while came_from.has(current_key):
		current = came_from[current_key]
		current_key = str(current.x, ",", current.y)
		path.append(current)
	
	path.reverse()
	return path

func _get_lowest_f_score_road(open_set: Array, f_score: Dictionary) -> Road:
	var lowest = open_set[0]
	var lowest_score = f_score[lowest]
	
	for road in open_set:
		var score = f_score[road]
		if score < lowest_score:
			lowest = road
			lowest_score = score
	
	return lowest

func _reconstruct_road_path(came_from: Dictionary, current: Road) -> Array:
	var path = [current.grid_position]
	
	while came_from.has(current):
		current = came_from[current]
		path.append(current.grid_position)
	
	path.reverse()
	return path

func find_road_placement_path(start_pos: Vector2i, end_pos: Vector2i) -> Array:
	if not is_cell_valid(start_pos) or not is_cell_valid(end_pos):
		return []
	
	var open_set: Array = [start_pos]
	var came_from: Dictionary = {}
	var visited: Dictionary = {}
	
	var start_key = str(start_pos.x, ",", start_pos.y)
	visited[start_key] = true
	
	while not open_set.is_empty():
		var current = open_set.pop_front()
		
		if current == end_pos:
			return _reconstruct_placement_path(came_from, current)
		
		var neighbors = _get_neighbors(current)
		for neighbor in neighbors:
			if not is_cell_valid(neighbor):
				continue
			
			var neighbor_key = str(neighbor.x, ",", neighbor.y)
			
			if visited.has(neighbor_key):
				continue
			
			var road_key = neighbor_key
			if is_cell_occupied(neighbor) and not road_network.has(road_key):
				continue
			
			visited[neighbor_key] = true
			came_from[neighbor_key] = current
			open_set.append(neighbor)
	
	return []

func _reconstruct_placement_path(came_from: Dictionary, current: Vector2i) -> Array:
	var path = [current]
	var current_key = str(current.x, ",", current.y)
	
	while came_from.has(current_key):
		current = came_from[current_key]
		current_key = str(current.x, ",", current.y)
		path.append(current)
	
	path.reverse()
	return path

func set_road_preview_path(path: Array) -> void:
	road_preview_path = path
	queue_redraw()

func clear_road_preview_path() -> void:
	road_preview_path.clear()
	queue_redraw()

func set_warehouse(warehouse: Node2D) -> void:
	if not warehouse_buildings.has(warehouse):
		warehouse_buildings.append(warehouse)
		print("Warehouse added to grid: ", warehouse.name, " Total warehouses: ", warehouse_buildings.size())
		_schedule_buildings_update()
	else:
		print("Warehouse already in list: ", warehouse.name)

func remove_warehouse(warehouse: Node2D) -> void:
	warehouse_buildings.erase(warehouse)
	print("Warehouse removed from grid: ", warehouse.name, " Remaining: ", warehouse_buildings.size())
	_schedule_buildings_update()

var _buildings_update_scheduled: bool = false

func _schedule_buildings_update() -> void:
	if _buildings_update_scheduled:
		return
	
	_buildings_update_scheduled = true
	call_deferred("_update_all_buildings_connection_status")

func _update_all_buildings_connection_status() -> void:
	_buildings_update_scheduled = false
	print("=== Updating all buildings connection status ===")
	
	var updated_count = 0
	var buildings_to_update = []
	
	for key in grid_data.keys():
		var building = grid_data[key]
		if building == null:
			continue
		
		if building.has_method("update_warehouse_connection"):
			buildings_to_update.append(building)
	
	for building in buildings_to_update:
		building.update_warehouse_connection()
		updated_count += 1
		
		if updated_count % 10 == 0:
			await get_tree().process_frame
	
	print("  Updated ", updated_count, " buildings")

func is_building_connected_to_warehouse(building: Node2D) -> bool:
	if warehouse_buildings.is_empty():
		return false
	
	if not building.has_method("get_connected_roads"):
		return false
	
	var connected_roads = building.get_connected_roads()
	if connected_roads.is_empty():
		return false
	
	for road in connected_roads:
		if _can_reach_warehouse_from_road(road):
			return true
	
	return false

func _can_reach_warehouse_from_road(start_road: Road) -> bool:
	if start_road == null:
		return false
	
	var visited = {}
	var queue = [start_road]
	var start_key = str(start_road.grid_position.x, ",", start_road.grid_position.y)
	visited[start_key] = true
	
	while queue.size() > 0:
		var current = queue.pop_front()
		
		for building in current.connected_buildings:
			if warehouse_buildings.has(building):
				return true
		
		for connected_road in current.connected_roads:
			var key = str(connected_road.grid_position.x, ",", connected_road.grid_position.y)
			if not visited.has(key):
				visited[key] = true
				queue.append(connected_road)
	
	return false

func get_building_size_size(building: Node2D) -> Vector2i:
	if building.has_meta("grid_size"):
		return building.get_meta("grid_size")
	elif building is Warehouse:
		return Vector2i(9, 9)
	else:
		return Vector2i(1, 1)

func check_path_via_roads(start: Vector2i, end: Vector2i) -> bool:
	if start == end:
		return true
	
	var start_key = str(start.x, ",", start.y)
	var end_key = str(end.x, ",", end.y)
	
	var start_on_road = road_network.has(start_key)
	var end_on_road = road_network.has(end_key)
	
	var start_positions = []
	var end_positions = []
	
	print("  Path finding: start=", start, " end=", end)
	print("    start_on_road=", start_on_road, " end_on_road=", end_on_road)
	
	if start_on_road:
		start_positions.append(start)
	else:
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				if dx == 0 and dy == 0:
					continue
				var neighbor = Vector2i(start.x + dx, start.y + dy)
				var neighbor_key = str(neighbor.x, ",", neighbor.y)
				if road_network.has(neighbor_key):
					start_positions.append(neighbor)
					print("    Found road near start: ", neighbor)
	
	if end_on_road:
		end_positions.append(end)
	else:
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				if dx == 0 and dy == 0:
					continue
				var neighbor = Vector2i(end.x + dx, end.y + dy)
				var neighbor_key = str(neighbor.x, ",", neighbor.y)
				if road_network.has(neighbor_key):
					end_positions.append(neighbor)
					print("    Found road near end: ", neighbor)
	
	print("    start_positions=", start_positions)
	print("    end_positions=", end_positions)
	
	if start_positions.is_empty() or end_positions.is_empty():
		return false
	
	for start_pos in start_positions:
		for end_pos in end_positions:
			if _bfs_path_exists(start_pos, end_pos):
				print("    Found path from ", start_pos, " to ", end_pos)
				return true
	
	return false

func _bfs_path_exists(start: Vector2i, end: Vector2i) -> bool:
	var queue = [start]
	var visited = {}
	visited[str(start.x, ",", start.y)] = true
	
	while queue.size() > 0:
		var current = queue.pop_front()
		
		if current == end:
			return true
		
		var neighbors = [
			Vector2i(current.x + 1, current.y),
			Vector2i(current.x - 1, current.y),
			Vector2i(current.x, current.y + 1),
			Vector2i(current.x, current.y - 1)
		]
		
		for neighbor in neighbors:
			var neighbor_key = str(neighbor.x, ",", neighbor.y)
			if not visited.has(neighbor_key):
				if is_cell_valid(neighbor) and road_network.has(neighbor_key):
					visited[neighbor_key] = true
					queue.append(neighbor)
	
	return false
