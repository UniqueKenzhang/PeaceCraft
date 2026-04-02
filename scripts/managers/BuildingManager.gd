extends Node

class_name BuildingManager

signal building_placement_started(building_name: String)
signal building_placement_finished()
signal road_placement_started()
signal road_placement_finished()

var placement_mode_scene: PackedScene = null
var placement_preview: Node2D = null
var placement_building_name: String = ""
var placement_particles: GPUParticles2D = null

var road_start_cell: Vector2i = Vector2i(-1, -1)
var road_start_selected: bool = false
var road_preview_path: Array = []

var active_grid_map: BuildingGrid = null
var active_realm: Node2D = null
var current_faction: String = "Human"

const PLACEMENT_PARTICLES_SCENE = preload("res://scenes/ui/PlacementParticles.tscn")

func initialize(grid_map: BuildingGrid, realm: Node2D, faction: String = "Human") -> void:
	active_grid_map = grid_map
	active_realm = realm
	current_faction = faction

func enter_placement_mode(building_scene: PackedScene, building_name: String) -> void:
	placement_mode_scene = building_scene
	placement_building_name = building_name
	
	if placement_building_name == "Road":
		road_start_cell = Vector2i(-1, -1)
		road_start_selected = false
		road_preview_path.clear()
		road_placement_started.emit()
	else:
		placement_preview = placement_mode_scene.instantiate()
		placement_preview.modulate = Color(1, 1, 1, 0.5)
		placement_preview.z_index = 100
		active_realm.add_child(placement_preview)
		
		placement_particles = PLACEMENT_PARTICLES_SCENE.instantiate()
		placement_particles.z_index = 101
		active_realm.add_child(placement_particles)
		
		building_placement_started.emit(building_name)

func exit_placement_mode() -> void:
	if placement_preview != null:
		placement_preview.queue_free()
		placement_preview = null
	
	if placement_particles != null:
		placement_particles.queue_free()
		placement_particles = null
	
	road_start_cell = Vector2i(-1, -1)
	road_start_selected = false
	road_preview_path.clear()
	
	if placement_building_name == "Road":
		road_placement_finished.emit()
	else:
		building_placement_finished.emit()
	
	placement_mode_scene = null
	placement_building_name = ""

func handle_placement_click(grid_pos: Vector2i) -> bool:
	if placement_building_name == "Road":
		return _handle_road_placement(grid_pos)
	else:
		return _handle_building_placement(grid_pos)

func update_preview(mouse_pos: Vector2) -> void:
	if placement_mode_scene == null:
		return
	
	if placement_building_name == "Road":
		_update_road_preview(mouse_pos)
	else:
		_update_building_preview(mouse_pos)

func _handle_road_placement(grid_pos: Vector2i) -> bool:
	if not road_start_selected:
		road_start_cell = grid_pos
		road_start_selected = true
		print("Road start selected: ", road_start_cell)
		return false
	else:
		var path = active_grid_map.find_path(road_start_cell, grid_pos)
		if not path.is_empty():
			_place_road_path(path)
			exit_placement_mode()
			return true
		else:
			print("Cannot find path from ", road_start_cell, " to ", grid_pos)
			road_start_selected = false
			road_start_cell = Vector2i(-1, -1)
			return false

func _handle_building_placement(grid_pos: Vector2i) -> bool:
	var building_size = active_grid_map.get_building_size(placement_building_name)
	
	if active_grid_map.is_area_occupied(grid_pos, building_size):
		return false
	
	var new_building = placement_mode_scene.instantiate()
	var world_pos = active_grid_map.grid_to_world(grid_pos)
	new_building.position = world_pos
	
	new_building.building_name = placement_building_name
	new_building.faction = current_faction
	
	if new_building.deduct_building_cost():
		new_building.set_meta("grid_pos", grid_pos)
		new_building.set_meta("grid_size", building_size)
		
		active_realm.add_child(new_building)
		active_grid_map.occupy_area(grid_pos, building_size, new_building)
		
		if placement_building_name == "Warehouse":
			active_grid_map.set_warehouse(new_building)
		
		active_grid_map.on_building_placed(new_building)
		
		if placement_particles != null:
			placement_particles.global_position = world_pos
			placement_particles.restart()
		
		exit_placement_mode()
		return true
	else:
		print("Failed to deduct resources for building")
		new_building.queue_free()
		exit_placement_mode()
		return false

func _place_road_path(path: Array) -> void:
	var road_cost = {"Wood": 5}
	var game_state = GameState
	
	if game_state == null:
		print("GameState not found")
		return
	
	var total_cost = {}
	for resource_name in road_cost:
		total_cost[resource_name] = road_cost[resource_name] * path.size()
	
	for resource_name in total_cost:
		var cost = total_cost[resource_name]
		if not game_state.has_in_warehouse(current_faction, resource_name, cost):
			print("Not enough ", resource_name, " for road path")
			return
	
	for resource_name in total_cost:
		var cost = total_cost[resource_name]
		game_state.get_from_warehouse(current_faction, resource_name, cost)
		print("Deducted ", cost, " ", resource_name, " for road path")
	
	for grid_pos in path:
		var road = active_grid_map.get_road_at(grid_pos)
		if road == null:
			var new_road = preload("res://scenes/buildings/Road.tscn").instantiate()
			var world_pos = active_grid_map.grid_to_world(grid_pos)
			new_road.position = world_pos
			new_road.set_meta("grid_pos", grid_pos)
			new_road.building_name = "Road"
			new_road.faction = current_faction
			active_realm.add_child(new_road)
			active_grid_map.add_road(grid_pos, new_road)
	
	if placement_particles != null:
		var center_pos = path[floor(path.size() / 2.0)]
		var world_pos = active_grid_map.grid_to_world(center_pos)
		placement_particles.global_position = world_pos
		placement_particles.restart()

func _update_building_preview(mouse_pos: Vector2) -> void:
	if placement_preview == null:
		return
	
	var grid_pos = active_grid_map.world_to_grid(mouse_pos)
	var world_pos = active_grid_map.grid_to_world(grid_pos)
	placement_preview.position = world_pos
	
	active_grid_map.update_highlight(mouse_pos, placement_building_name)

func _update_road_preview(mouse_pos: Vector2) -> void:
	var grid_pos = active_grid_map.world_to_grid(mouse_pos)
	
	if road_start_selected:
		var path = active_grid_map.find_path(road_start_cell, grid_pos)
		active_grid_map.set_road_preview_path(path)
	else:
		active_grid_map.set_road_preview_path([grid_pos])
