extends "res://scripts/buildings/Building.gd"

class_name Warehouse

var warehouse_id: int = -1
var connected_to_network: bool = false

func _ready() -> void:
	warehouse_id = get_instance_id()
	print("Warehouse created for faction: ", faction, " ID: ", warehouse_id)

func set_connected(connected: bool) -> void:
	connected_to_network = connected
