extends Node2D

# 建筑场景
const FARM_SCENE = preload("res://scenes/buildings/Farm.tscn")
const LUMBERJACK_SCENE = preload("res://scenes/buildings/Lumberjack.tscn")
const SULFUR_MINE_SCENE = preload("res://scenes/buildings/SulfurMine.tscn")
const FUNGUS_CAVE_SCENE = preload("res://scenes/buildings/FungusCave.tscn")
const ARMORY_SCENE = preload("res://scenes/buildings/Armory.tscn")
const WORKSHOP_SCENE = preload("res://scenes/buildings/Workshop.tscn")
const LAIR_SCENE = preload("res://scenes/buildings/Lair.tscn")
const PORTAL_SCENE = preload("res://scenes/buildings/Portal.tscn")
const SMUGGLING_DOCK_SCENE = preload("res://scenes/buildings/SmugglingDock.tscn")
const HOUSING_SCENE = preload("res://scenes/buildings/Housing.tscn")
const FOOD_PROVIDER_SCENE = preload("res://scenes/buildings/FoodProvider.tscn")
const ROAD_SCENE = preload("res://scenes/buildings/Road.tscn")
const WAREHOUSE_SCENE = preload("res://scenes/buildings/Warehouse.tscn")

# 当前国度
enum Realm { HUMAN, ABYSS }
var current_realm: Realm = Realm.HUMAN

# 格子地图
@onready var human_grid_map: BuildingGrid = $HumanRealm/HumanGridMap
@onready var abyss_grid_map: BuildingGrid = $AbyssRealm/AbyssGridMap
@onready var realm_switch_button: Button = $CanvasLayer/RealmSwitchButton

# 管理器
@onready var building_manager: BuildingManager = $BuildingManager
@onready var ui_manager: UIManager = $UIManager
@onready var transport_manager: TransportManager = $TransportManager

# --- 成本 ---
var BUILDING_COSTS = {
	"Farm": {"Wood": 10, "faction": "Human"},
	"Lumberjack": {"Wood": 5, "faction": "Human"},
	"Armory": {"Wood": 25, "faction": "Human"},
	"Workshop": {"Wood": 15, "faction": "Human"},
	"Fungus Cave": {"Wood": 15, "faction": "Human"},
	"Sulfur Mine": {"Shadow-shroom": 10, "faction": "Abyss"},
	"Lair": {"Shadow-shroom": 20, "faction": "Abyss"},
	"Portal": {"Wood": 50, "faction": "Human"},
	"SmugglingDock": {"Shadow-shroom": 50, "faction": "Abyss"},
	"Housing": {"Wood": 20, "faction": "Human"},
	"FoodProvider": {"Wood": 15, "faction": "Human"},
	"Road": {"Wood": 5, "faction": "Human"},
	"Warehouse": {"Wood": 1, "faction": "Human"}
}

# 获取当前活动的格子地图
func get_active_grid_map() -> BuildingGrid:
	return human_grid_map if current_realm == Realm.HUMAN else abyss_grid_map

# 获取当前活动的国度容器
func get_active_realm() -> Node2D:
	return $HumanRealm if current_realm == Realm.HUMAN else $AbyssRealm

func _ready() -> void:
	# 初始化管理器
	building_manager.initialize(get_active_grid_map(), get_active_realm())
	ui_manager.initialize($CanvasLayer)
	transport_manager.initialize($CanvasLayer)
	
	# 连接建筑按钮
	_connect_building_buttons()
	
	# 连接其他按钮
	realm_switch_button.pressed.connect(_on_realm_switch_pressed)
	ui_manager.restart_button.pressed.connect(_on_restart_pressed)
	ui_manager.tech_button.pressed.connect(_on_tech_button_pressed)
	ui_manager.fulfill_order_button.pressed.connect(_on_fulfill_order_pressed)
	
	# 初始化UI状态
	_on_restart_pressed()

func _connect_building_buttons() -> void:
	var human_build_menu = $CanvasLayer/BuildMenusContainer/HumanBuildMenu
	var abyss_build_menu = $CanvasLayer/BuildMenusContainer/AbyssBuildMenu
	
	ui_manager.register_building_button("Farm", human_build_menu.get_node("BuildFarmButton"))
	ui_manager.register_building_button("Lumberjack", human_build_menu.get_node("BuildLumberjackButton"))
	ui_manager.register_building_button("Armory", human_build_menu.get_node("BuildArmoryButton"))
	ui_manager.register_building_button("Workshop", human_build_menu.get_node("BuildWorkshopButton"))
	ui_manager.register_building_button("Warehouse", human_build_menu.get_node("BuildWarehouseButton"))
	ui_manager.register_building_button("Portal", human_build_menu.get_node("BuildPortalButton"))
	ui_manager.register_building_button("Housing", human_build_menu.get_node("BuildHousingButton"))
	ui_manager.register_building_button("FoodProvider", human_build_menu.get_node("BuildFoodProviderButton"))
	ui_manager.register_building_button("Road", human_build_menu.get_node("BuildRoadButton"))
	
	ui_manager.register_building_button("Sulfur Mine", abyss_build_menu.get_node("BuildSulfurMineButton"))
	ui_manager.register_building_button("Fungus Cave", abyss_build_menu.get_node("BuildFungusCaveButton"))
	ui_manager.register_building_button("SmugglingDock", abyss_build_menu.get_node("BuildSmugglingDockButton"))
	ui_manager.register_building_button("Lair", abyss_build_menu.get_node("BuildLairButton"))
	
	# 连接建筑按钮事件
	human_build_menu.get_node("BuildFarmButton").pressed.connect(_on_build_button_pressed.bind(FARM_SCENE, BUILDING_COSTS["Farm"], "Farm"))
	human_build_menu.get_node("BuildLumberjackButton").pressed.connect(_on_build_button_pressed.bind(LUMBERJACK_SCENE, BUILDING_COSTS["Lumberjack"], "Lumberjack"))
	human_build_menu.get_node("BuildArmoryButton").pressed.connect(_on_build_button_pressed.bind(ARMORY_SCENE, BUILDING_COSTS["Armory"], "Armory"))
	human_build_menu.get_node("BuildWorkshopButton").pressed.connect(_on_build_button_pressed.bind(WORKSHOP_SCENE, BUILDING_COSTS["Workshop"], "Workshop"))
	human_build_menu.get_node("BuildWarehouseButton").pressed.connect(_on_build_button_pressed.bind(WAREHOUSE_SCENE, BUILDING_COSTS["Warehouse"], "Warehouse"))
	human_build_menu.get_node("BuildPortalButton").pressed.connect(_on_build_button_pressed.bind(PORTAL_SCENE, BUILDING_COSTS["Portal"], "Portal"))
	human_build_menu.get_node("BuildHousingButton").pressed.connect(_on_build_button_pressed.bind(HOUSING_SCENE, BUILDING_COSTS["Housing"], "Housing"))
	human_build_menu.get_node("BuildFoodProviderButton").pressed.connect(_on_build_button_pressed.bind(FOOD_PROVIDER_SCENE, BUILDING_COSTS["FoodProvider"], "FoodProvider"))
	human_build_menu.get_node("BuildRoadButton").pressed.connect(_on_build_button_pressed.bind(ROAD_SCENE, BUILDING_COSTS["Road"], "Road"))
	abyss_build_menu.get_node("BuildSulfurMineButton").pressed.connect(_on_build_button_pressed.bind(SULFUR_MINE_SCENE, BUILDING_COSTS["Sulfur Mine"], "Sulfur Mine"))
	abyss_build_menu.get_node("BuildFungusCaveButton").pressed.connect(_on_build_button_pressed.bind(FUNGUS_CAVE_SCENE, BUILDING_COSTS["Fungus Cave"], "Fungus Cave"))
	abyss_build_menu.get_node("BuildSmugglingDockButton").pressed.connect(_on_build_button_pressed.bind(SMUGGLING_DOCK_SCENE, BUILDING_COSTS["SmugglingDock"], "SmugglingDock"))
	abyss_build_menu.get_node("BuildLairButton").pressed.connect(_on_build_button_pressed.bind(LAIR_SCENE, BUILDING_COSTS["Lair"], "Lair"))

func _unhandled_input(event: InputEvent) -> void:
	if GameState.is_game_over:
		return
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.is_pressed():
		building_manager.exit_placement_mode()
	
	if building_manager.placement_mode_scene != null:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
			var grid_pos = get_active_grid_map().world_to_grid(get_global_mouse_position())
			building_manager.handle_placement_click(grid_pos)

func _process(delta: float) -> void:
	if building_manager.placement_mode_scene != null:
		building_manager.update_preview(get_global_mouse_position())
	
	ui_manager.update_button_states(BUILDING_COSTS, "Human" if current_realm == Realm.HUMAN else "Abyss")

func _on_build_button_pressed(building_scene: PackedScene, cost: Dictionary, building_name: String = "") -> void:
	print("Build button pressed for: ", building_name)
	print("Cost: ", cost)
	
	if building_manager.placement_mode_scene != null:
		building_manager.exit_placement_mode()
	
	var can_afford = _can_afford(cost)
	print("Can afford: ", can_afford)
	
	if can_afford:
		_deduct_cost(cost)
		
		if building_name.is_empty():
			for key in BUILDING_COSTS:
				if BUILDING_COSTS[key] == cost:
					building_name = key
					break
		
		building_manager.enter_placement_mode(building_scene, building_name)
	else:
		print("Not enough resources to build!")

func _on_tech_button_pressed() -> void:
	print("Tech button pressed")

func _on_fulfill_order_pressed() -> void:
	var order = GameState.current_order
	if order == null:
		print("No active order to fulfill")
		return
	
	print("Fulfilling order for ", order.target_faction)
	print("Requirements: ", order.requirements)
	
	var all_requirements_met = true
	for resource_name in order.requirements:
		var required_amount = order.requirements[resource_name]
		if not GameState.has_in_warehouse(order.target_faction, resource_name, required_amount):
			all_requirements_met = false
			print("Missing ", resource_name, ": need ", required_amount)
			break
	
	if all_requirements_met:
		for resource_name in order.requirements:
			var quantity = order.requirements[resource_name]
			GameState.get_from_warehouse(order.target_faction, resource_name, quantity)
		
		GameState.process_delivery(order.target_faction, order.requirements)
		print("Order fulfilled successfully!")
	else:
		print("Cannot fulfill order: missing resources")

func _on_realm_switch_pressed() -> void:
	current_realm = Realm.ABYSS if current_realm == Realm.HUMAN else Realm.HUMAN
	
	var human_realm = $HumanRealm
	var abyss_realm = $AbyssRealm
	
	if current_realm == Realm.HUMAN:
		human_realm.visible = true
		abyss_realm.visible = false
		realm_switch_button.text = "Switch to Abyss"
	else:
		human_realm.visible = false
		abyss_realm.visible = true
		realm_switch_button.text = "Switch to Human"
	
	_update_build_menu_visibility()
	
	building_manager.initialize(get_active_grid_map(), get_active_realm())
	transport_manager._update_transport_panel_defaults()

func _update_build_menu_visibility() -> void:
	var human_build_menu = $CanvasLayer/BuildMenusContainer/HumanBuildMenu
	var abyss_build_menu = $CanvasLayer/BuildMenusContainer/AbyssBuildMenu
	
	if current_realm == Realm.HUMAN:
		human_build_menu.visible = true
		abyss_build_menu.visible = false
	else:
		human_build_menu.visible = false
		abyss_build_menu.visible = true

func _can_afford(cost: Dictionary) -> bool:
	var faction = cost["faction"]
	for resource_name in cost:
		if resource_name == "faction":
			continue
		var required_amount = cost[resource_name]
		if not GameState.has_in_warehouse(faction, resource_name, required_amount):
			return false
	return true

func _deduct_cost(cost: Dictionary) -> void:
	var faction = cost["faction"]
	for resource_name in cost:
		if resource_name == "faction":
			continue
		var quantity = cost[resource_name]
		GameState.get_from_warehouse(faction, resource_name, quantity)

func _on_restart_pressed() -> void:
	print("Restarting game...")
	GameState.reset_game()
	
	ui_manager.game_over_label.visible = false
	ui_manager.penalty_label.visible = false
	ui_manager.penalty_timer.stop()
	
	GameState.add_to_warehouse("Human", "Wood", 20)
	GameState.add_to_warehouse("Human", "Wheat", 10)
	GameState.add_to_warehouse("Abyss", "Sulfur", 20)
	GameState.add_to_warehouse("Abyss", "Shadow-shroom", 10)
	
	ui_manager._on_warehouse_updated({"Human": GameState.human_warehouse, "Abyss": GameState.abyss_warehouse})
	ui_manager._on_deserter_count_updated(GameState.alliance_deserters, GameState.abyss_deserters)
	ui_manager._on_research_points_updated(GameState.research_points, GameState.research_rate)
	ui_manager._on_population_updated("Human", GameState.human_populations)
	ui_manager._on_population_updated("Abyss", GameState.abyss_populations)
	
	var order = GameState.current_order
	if order != null:
		ui_manager._on_order_updated(order)