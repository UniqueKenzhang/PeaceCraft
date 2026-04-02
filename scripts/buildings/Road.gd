extends Node2D

class_name Road

var grid_position: Vector2i = Vector2i.ZERO
var connected_roads: Array = []
var connected_buildings: Array = []

func _ready() -> void:
	pass

func set_grid_position(pos: Vector2i) -> void:
	grid_position = pos

func get_grid_position() -> Vector2i:
	return grid_position

func add_connected_road(road: Road) -> void:
	if not connected_roads.has(road):
		connected_roads.append(road)

func add_connected_building(building: Node2D) -> void:
	if not connected_buildings.has(building):
		connected_buildings.append(building)

func remove_connected_road(road: Road) -> void:
	connected_roads.erase(road)

func remove_connected_building(building: Node2D) -> void:
	connected_buildings.erase(building)

func is_connected_to(other_road: Road) -> bool:
	return connected_roads.has(other_road)

func get_connected_roads() -> Array:
	return connected_roads

func get_connected_buildings() -> Array:
	return connected_buildings
