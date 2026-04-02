extends "res://scripts/buildings/Building.gd"

class_name ProductionBuilding

const Worker = preload("res://scripts/units/Worker.gd")

@export var production_cycle_time: float = 5.0

@export var output_resource: String = "Wheat"
@export var output_quantity: int = 1
@export var inputs: Dictionary = {}

@onready var timer: Timer = $Timer
var is_stalled: bool = false
var is_connected_to_warehouse: bool = false

var building_grid: BuildingGrid = null
var warehouse: Node2D = null
var active_workers: Array = []

const WORKER_SCENE = preload("res://scenes/units/Worker.tscn")

# 连接状态颜色
const CONNECTED_COLOR = Color(1.0, 1.0, 1.0, 1.0)
const DISCONNECTED_COLOR = Color(0.5, 0.5, 0.5, 1.0)

func _ready() -> void:
	timer.wait_time = production_cycle_time
	timer.timeout.connect(_on_production_timer_timeout)
	timer.start()
	
	var input_str = ""
	if not inputs.is_empty():
		input_str = " consuming %s" % inputs
	print(self.name, " started. Produces ", output_quantity, " ", output_resource, " every ", production_cycle_time, " seconds", input_str)

func _check_warehouse_connection() -> void:
	# 查找BuildingGrid
	var grid = null
	
	# 首先尝试在父节点中查找BuildingGrid
	var parent = get_parent()
	if parent != null:
		for child in parent.get_children():
			if child is BuildingGrid:
				grid = child
				break
	
	if grid == null:
		print(self.name, " could not find BuildingGrid for warehouse connection check")
		return
	
	building_grid = grid
	
	if grid.has_method("is_building_connected_to_warehouse"):
		is_connected_to_warehouse = grid.is_building_connected_to_warehouse(self)
		if not is_connected_to_warehouse:
			print(self.name, " is not connected to warehouse!")
		
		_update_visuals()

func _update_visuals() -> void:
	if is_connected_to_warehouse:
		modulate = CONNECTED_COLOR
	else:
		modulate = DISCONNECTED_COLOR

func _on_production_timer_timeout() -> void:
	var game_state = get_node("/root/GameState")
	
	# 0. 检查是否连接到仓库
	if not is_connected_to_warehouse or warehouse == null:
		print(self.name, " cannot produce - not connected to warehouse or warehouse is null")
		print("  is_connected_to_warehouse: ", is_connected_to_warehouse)
		print("  warehouse: ", warehouse)
		return
	
	# 1. 检查输入原料
	if not _has_input_materials(game_state):
		if not is_stalled:
			is_stalled = true
			print(self.name, " is stalled due to lack of input materials.")
		return # 中断生产

	# 如果之前是停滞状态，现在恢复了
	if is_stalled:
		is_stalled = false
		print(self.name, " has resumed production.")

	# 2. 消耗输入原料
	for resource_name in inputs:
		var quantity = inputs[resource_name]
		# 假设原料和建筑属于同一阵营
		game_state.get_from_warehouse(faction, resource_name, quantity)

	# 3. 产出资源（应用效率加成）
	var actual_output = output_quantity
	if game_state.has_method("get_production_efficiency_bonus"):
		var efficiency_bonus = game_state.production_efficiency_bonus
		actual_output = int(output_quantity * (1.0 + efficiency_bonus))
		if actual_output < 1:
			actual_output = 1

	# 4. 派出工人运送资源到仓库
	_dispatch_worker(actual_output)

func _has_input_materials(gs) -> bool:
	# 如果没有输入需求，则始终返回 true
	if inputs.is_empty():
		return true
	
	for resource_name in inputs:
		var quantity = inputs[resource_name]
		# 假设原料和建筑属于同一阵营
		if not gs.has_in_warehouse(faction, resource_name, quantity):
			return false
			
	return true

func _dispatch_worker(quantity: int) -> void:
	if building_grid == null or warehouse == null:
		print(self.name, " cannot dispatch worker - grid or warehouse is null")
		return
	
	var worker = WORKER_SCENE.instantiate()
	worker.initialize(self, warehouse, building_grid, output_resource, quantity, faction)
	worker.delivery_completed.connect(_on_worker_delivered)
	worker.returned_to_source.connect(_on_worker_returned)
	
	var parent = get_parent()
	if parent != null:
		parent.add_child(worker)
		active_workers.append(worker)
		print(self.name, " dispatched worker to deliver ", quantity, " ", output_resource)
	else:
		print(self.name, " cannot add worker - no parent found")

func _on_worker_delivered(worker: Worker) -> void:
	print(self.name, " worker delivered resources")

func _on_worker_returned(worker: Worker) -> void:
	active_workers.erase(worker)
	worker.queue_free()
	print(self.name, " worker returned and freed")

func add_connected_road(road: Road) -> void:
	if not connected_roads.has(road):
		connected_roads.append(road)

func remove_connected_road(road: Road) -> void:
	connected_roads.erase(road)

func update_warehouse_connection() -> void:
	if building_grid == null:
		var parent = get_parent()
		if parent != null:
			for child in parent.get_children():
				if child is BuildingGrid:
					building_grid = child
					break
	
	if building_grid == null:
		return
	
	var result = _find_nearest_warehouse()
	warehouse = result.warehouse
	var was_connected = is_connected_to_warehouse
	is_connected_to_warehouse = (warehouse != null)
	
	if was_connected != is_connected_to_warehouse:
		_update_visuals()
		
		if is_connected_to_warehouse:
			print(self.name, " connected to warehouse: ", warehouse.name, " distance: ", result.distance)
		else:
			print(self.name, " disconnected from warehouse")

func _find_nearest_warehouse() -> Dictionary:
	var result = {"warehouse": null, "distance": -1}
	
	if connected_roads.is_empty():
		return result
	
	var warehouses = building_grid.warehouse_buildings
	if warehouses.is_empty():
		return result
	
	var visited_roads = {}
	var queue = []
	
	for road in connected_roads:
		queue.append({"road": road, "distance": 0})
		var key = str(road.grid_position.x, ",", road.grid_position.y)
		visited_roads[key] = true
	
	while queue.size() > 0:
		var current_item = queue.pop_front()
		var current_road = current_item.road
		var current_distance = current_item.distance
		
		if current_distance > 30:
			continue
		
		for building in current_road.connected_buildings:
			if warehouses.has(building):
				result.warehouse = building
				result.distance = current_distance
				return result
		
		for neighbor_road in current_road.connected_roads:
			var key = str(neighbor_road.grid_position.x, ",", neighbor_road.grid_position.y)
			if not visited_roads.has(key):
				visited_roads[key] = true
				queue.append({"road": neighbor_road, "distance": current_distance + 1})
	
	return result
