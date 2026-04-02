extends Node2D

class_name Building

@export var faction: String = "Human"
@export var building_name: String = ""
var connected_roads: Array = []

func add_connected_road(road: Road) -> void:
	if not connected_roads.has(road):
		connected_roads.append(road)

func remove_connected_road(road: Road) -> void:
	connected_roads.erase(road)

func get_connected_roads() -> Array:
	return connected_roads

func deduct_building_cost() -> bool:
	if building_name.is_empty():
		print("Building name not set, cannot deduct cost")
		return false
	
	var game_state = GameState
	if game_state == null:
		print("GameState not found")
		return false
	
	var costs = _get_building_costs()
	if costs.is_empty():
		print("No cost defined for building: ", building_name)
		return true
	
	for resource_name in costs:
		var cost = costs[resource_name]
		if not game_state.has_in_warehouse(faction, resource_name, cost):
			print("Not enough ", resource_name, " for building ", building_name)
			return false
	
	for resource_name in costs:
		var cost = costs[resource_name]
		game_state.get_from_warehouse(faction, resource_name, cost)
		print("Deducted ", cost, " ", resource_name, " for building ", building_name)
	
	return true

func _get_building_costs() -> Dictionary:
	var building_costs = {
		"Farm": {"Wood": 10},
		"Lumberjack": {"Wood": 5},
		"Armory": {"Wood": 25},
		"Workshop": {"Wood": 15},
		"Fungus Cave": {"Wood": 15},
		"Sulfur Mine": {"Shadow-shroom": 10},
		"Lair": {"Shadow-shroom": 20},
		"Portal": {"Wood": 50},
		"SmugglingDock": {"Shadow-shroom": 50},
		"Housing": {"Wood": 20},
		"FoodProvider": {"Wood": 15},
		"Road": {"Wood": 5},
		"Warehouse": {"Wood": 1}
	}
	
	if building_costs.has(building_name):
		return building_costs[building_name]
	
	return {}
