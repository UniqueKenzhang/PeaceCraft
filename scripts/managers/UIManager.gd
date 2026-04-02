extends Node

class_name UIManager

var balance_label: Label
var deserter_label: Label
var research_points_label: Label
var research_rate_label: Label
var warehouse_label: Label
var game_over_label: Label
var penalty_label: Label
var penalty_timer: Timer
var tech_button: Button
var restart_button: Button
var order_target_label: Label
var order_requirements_label: Label
var order_time_limit_label: Label
var fulfill_order_button: Button
var human_population_label: Label
var abyss_population_label: Label

var building_buttons: Dictionary = {}

func initialize(canvas_layer: CanvasLayer) -> void:
	balance_label = canvas_layer.get_node("BalanceLabel")
	deserter_label = canvas_layer.get_node("DeserterLabel")
	research_points_label = canvas_layer.get_node("ResearchPointsLabel")
	research_rate_label = canvas_layer.get_node("ResearchRateLabel")
	warehouse_label = canvas_layer.get_node("WarehouseLabel")
	game_over_label = canvas_layer.get_node("GameOverLabel")
	restart_button = canvas_layer.get_node("RestartButton")
	penalty_label = canvas_layer.get_node("PenaltyLabel")
	penalty_timer = canvas_layer.get_node("PenaltyTimer")
	tech_button = canvas_layer.get_node("GlobalButtons/TechButton")
	
	var vbox_container = canvas_layer.get_node("VBoxContainer")
	order_target_label = vbox_container.get_node("OrderTargetLabel")
	order_requirements_label = vbox_container.get_node("OrderRequirementsLabel")
	order_time_limit_label = vbox_container.get_node("OrderTimeLimitLabel")
	fulfill_order_button = vbox_container.get_node("FulfillOrderButton")
	
	var population_container = canvas_layer.get_node("PopulationContainer")
	human_population_label = population_container.get_node("HumanPopulationLabel")
	abyss_population_label = population_container.get_node("AbyssPopulationLabel")
	
	_connect_game_state_signals()
	_initialize_ui_state()

func _connect_game_state_signals() -> void:
	GameState.balance_updated.connect(_on_balance_updated)
	GameState.game_over.connect(_on_game_over)
	GameState.warehouse_updated.connect(_on_warehouse_updated)
	GameState.penalty_triggered.connect(_show_penalty_notification)
	GameState.deserter_count_updated.connect(_on_deserter_count_updated)
	GameState.order_updated.connect(_on_order_updated)
	GameState.research_points_updated.connect(_on_research_points_updated)
	GameState.building_unlocked.connect(_on_building_unlocked)
	GameState.resource_changed.connect(_on_resource_changed)
	GameState.population_updated.connect(_on_population_updated)
	
	penalty_timer.timeout.connect(_on_penalty_timer_timeout)

func _initialize_ui_state() -> void:
	_on_balance_updated(GameState.balance)
	_on_warehouse_updated({"Human": GameState.human_warehouse, "Abyss": GameState.abyss_warehouse})
	_on_deserter_count_updated(GameState.alliance_deserters, GameState.abyss_deserters)
	_on_research_points_updated(GameState.research_points, GameState.research_rate)
	_on_population_updated("Human", GameState.human_populations)
	_on_population_updated("Abyss", GameState.abyss_populations)
	
	var order = GameState.current_order
	if order != null:
		_on_order_updated(order)

func _on_balance_updated(new_balance: float) -> void:
	balance_label.text = "Balance: %.2f" % new_balance
	if new_balance > 25.0:
		balance_label.modulate = Color.CORNFLOWER_BLUE
	elif new_balance < -25.0:
		balance_label.modulate = Color.INDIAN_RED
	else:
		balance_label.modulate = Color.WHITE

func _on_deserter_count_updated(alliance_deserters: int, abyss_deserters: int) -> void:
	deserter_label.text = "Deserters: A-%d, H-%d" % [abyss_deserters, alliance_deserters]

func _on_research_points_updated(rp: float, rp_rate: float) -> void:
	var bonus_text = ""
	if GameState.rp_bonus_multiplier > 1.0:
		bonus_text = " (x%.1f)" % GameState.rp_bonus_multiplier
	research_points_label.text = "RP: %.1f" % rp
	research_rate_label.text = "(+%.2f/s)%s" % [rp_rate, bonus_text]

func _on_warehouse_updated(warehouses: Dictionary) -> void:
	var text = "Warehouse:\n"
	
	if warehouses["Human"].is_empty():
		text += "  Human: Empty\n"
	else:
		text += "  Human:\n"
		for resource_name in warehouses["Human"]:
			text += "    %s: %d\n" % [resource_name, warehouses["Human"][resource_name]]
	
	if warehouses["Abyss"].is_empty():
		text += "  Abyss: Empty"
	else:
		text += "  Abyss:\n"
		for resource_name in warehouses["Abyss"]:
			text += "    %s: %d" % [resource_name, warehouses["Abyss"][resource_name]]
	
	warehouse_label.text = text

func _on_order_updated(order: Order) -> void:
	if order == null:
		order_target_label.text = "No active order"
		order_requirements_label.text = ""
		order_time_limit_label.text = ""
		fulfill_order_button.disabled = true
		return
	
	order_target_label.text = "Order for %s" % order.target_faction
	order_requirements_label.text = "Requirements: %s" % str(order.requirements)
	order_time_limit_label.text = "Time limit: %.1f" % order.time_limit
	fulfill_order_button.disabled = false

func _on_population_updated(faction: String, populations: Dictionary) -> void:
	if faction == "Human":
		var text = "Human Population:\n"
		for pop_type in populations:
			var pop_data = populations[pop_type] as Population
			text += "  %s: %d (Happiness: %d)\n" % [pop_type, pop_data.count, pop_data.happiness]
		human_population_label.text = text
	else:
		var text = "Abyss Population:\n"
		for pop_type in populations:
			var pop_data = populations[pop_type] as Population
			text += "  %s: %d (Happiness: %d)\n" % [pop_type, pop_data.count, pop_data.happiness]
		abyss_population_label.text = text

func _on_resource_changed(faction: String, resource_name: String, amount: int) -> void:
	var text_instance = preload("res://scenes/ui/FloatingText.tscn").instantiate()
	var color = Color.GREEN if amount > 0 else Color.RED
	text_instance.modulate = color
	text_instance.text = "%+d %s" % [amount, resource_name]
	
	var random_offset = Vector2(randf_range(-20, 20), randf_range(-20, 20))
	text_instance.global_position = warehouse_label.global_position + Vector2(150, 0) + random_offset
	
	get_tree().current_scene.add_child(text_instance)
	
	await get_tree().create_timer(2.0).timeout
	text_instance.queue_free()

func _on_game_over() -> void:
	game_over_label.visible = true
	game_over_label.text = "GAME OVER\n" + GameState.game_over_reason

func _show_penalty_notification() -> void:
	penalty_label.visible = true
	penalty_label.text = "PENALTY!\n" + GameState.penalty_reason
	penalty_timer.start()

func _on_penalty_timer_timeout() -> void:
	penalty_label.visible = false

func _on_building_unlocked(building_scene_path: String, building_name: String, faction: String, cost: Dictionary) -> void:
	print("Building unlocked: ", building_name, " for ", faction)

func update_button_states(building_costs: Dictionary, current_faction: String) -> void:
	for building_name in building_costs:
		var cost = building_costs[building_name]
		if cost["faction"] != current_faction:
			continue
		
		var button = building_buttons.get(building_name)
		if button == null:
			continue
		
		var can_afford = true
		for resource_name in cost:
			if resource_name == "faction":
				continue
			var required_amount = cost[resource_name]
			var has_resource = GameState.has_in_warehouse(current_faction, resource_name, required_amount)
			if not has_resource:
				can_afford = false
				break
		
		button.disabled = not can_afford

func register_building_button(building_name: String, button: Button) -> void:
	building_buttons[building_name] = button