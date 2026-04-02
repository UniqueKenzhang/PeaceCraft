extends Node2D

class_name MainScene

# 建筑场景
const FARM_SCENE = preload("res://scenes/buildings/Farm.tscn")
const LUMBERJACK_SCENE = preload("res://scenes/buildings/Lumberjack.tscn")
const SULFUR_MINE_SCENE = preload("res://scenes/buildings/SulfurMine.tscn")
const FUNGUS_CAVE_SCENE = preload("res://scenes/buildings/FungusCave.tscn")
const ARMORY_SCENE = preload("res://scenes/buildings/Armory.tscn")
const WORKSHOP_SCENE = preload("res://scenes/buildings/Workshop.tscn")
const LAIR_SCENE = preload("res://scenes/buildings/Lair.tscn")
const FLOATING_TEXT_SCENE = preload("res://scenes/ui/FloatingText.tscn")
const PORTAL_SCENE = preload("res://scenes/buildings/Portal.tscn")
const SMUGGLING_DOCK_SCENE = preload("res://scenes/buildings/SmugglingDock.tscn")
const TRANSPORT_PANEL_SCENE = preload("res://scenes/ui/TransportPanel.tscn")
const HOUSING_SCENE = preload("res://scenes/buildings/Housing.tscn")
const FOOD_PROVIDER_SCENE = preload("res://scenes/buildings/FoodProvider.tscn")
const ROAD_SCENE = preload("res://scenes/buildings/Road.tscn")
const WAREHOUSE_SCENE = preload("res://scenes/buildings/Warehouse.tscn")
const PLACEMENT_PARTICLES_SCENE = preload("res://scenes/ui/PlacementParticles.tscn")

# 当前国度
enum Realm { HUMAN, ABYSS }
var current_realm: Realm = Realm.HUMAN

# 格子地图
@onready var human_grid_map: BuildingGrid = $HumanRealm/HumanGridMap
@onready var abyss_grid_map: BuildingGrid = $AbyssRealm/AbyssGridMap
@onready var realm_switch_button: Button = $CanvasLayer/RealmSwitchButton

# UI 节点引用
@onready var balance_label: Label = $CanvasLayer/BalanceLabel
@onready var deserter_label: Label = $CanvasLayer/DeserterLabel
@onready var research_points_label: Label = $CanvasLayer/ResearchPointsLabel
@onready var research_rate_label: Label = $CanvasLayer/ResearchRateLabel
@onready var warehouse_label: Label = $CanvasLayer/WarehouseLabel
@onready var game_over_label: Label = $CanvasLayer/GameOverLabel
@onready var restart_button: Button = $CanvasLayer/RestartButton
@onready var penalty_label: Label = $CanvasLayer/PenaltyLabel
@onready var penalty_timer: Timer = $CanvasLayer/PenaltyTimer
@onready var tech_button: Button = $CanvasLayer/GlobalButtons/TechButton

# 动态建筑按钮存储
var building_buttons: Dictionary = {}

# 指令UI
@onready var order_target_label: Label = $CanvasLayer/VBoxContainer/OrderTargetLabel
@onready var order_requirements_label: Label = $CanvasLayer/VBoxContainer/OrderRequirementsLabel
@onready var order_time_limit_label: Label = $CanvasLayer/VBoxContainer/OrderTimeLimitLabel
@onready var fulfill_order_button: Button = $CanvasLayer/VBoxContainer/FulfillOrderButton

# 建造菜单UI
@onready var build_farm_button: Button = $CanvasLayer/BuildMenusContainer/HumanBuildMenu/BuildFarmButton
@onready var build_lumberjack_button: Button = $CanvasLayer/BuildMenusContainer/HumanBuildMenu/BuildLumberjackButton
@onready var build_armory_button: Button = $CanvasLayer/BuildMenusContainer/HumanBuildMenu/BuildArmoryButton
@onready var build_workshop_button: Button = $CanvasLayer/BuildMenusContainer/HumanBuildMenu/BuildWorkshopButton
@onready var build_warehouse_button: Button = $CanvasLayer/BuildMenusContainer/HumanBuildMenu/BuildWarehouseButton
@onready var build_sulfur_mine_button: Button = $CanvasLayer/BuildMenusContainer/AbyssBuildMenu/BuildSulfurMineButton
@onready var build_fungus_cave_button: Button = $CanvasLayer/BuildMenusContainer/AbyssBuildMenu/BuildFungusCaveButton
@onready var build_lair_button: Button = $CanvasLayer/BuildMenusContainer/AbyssBuildMenu/BuildLairButton

# 运输系统UI
@onready var transport_panel: Control = $CanvasLayer/TransportPanel

# 人口系统UI
@onready var human_population_label: Label = $CanvasLayer/PopulationContainer/HumanPopulationLabel
@onready var abyss_population_label: Label = $CanvasLayer/PopulationContainer/AbyssPopulationLabel

# --- 成本 ---
var BUILDING_COSTS = {
	"Farm": {"Wood": 10, "faction": "Human"},
	"Lumberjack": {"Wood": 5, "faction": "Human"},
	"Armory": {"Wood": 25, "faction": "Human"},
	"Workshop": {"Wood": 15, "faction": "Human"},
	"Fungus Cave": {"Wood": 15, "faction": "Human"}, # 用人类资源启动
	"Sulfur Mine": {"Shadow-shroom": 10, "faction": "Abyss"}, # 现在依赖深渊资源
	"Lair": {"Shadow-shroom": 20, "faction": "Abyss"},
	"Portal": {"Wood": 50, "faction": "Human"},
	"SmugglingDock": {"Shadow-shroom": 50, "faction": "Abyss"},
	"Housing": {"Wood": 20, "faction": "Human"},
	"FoodProvider": {"Wood": 15, "faction": "Human"},
	"Road": {"Wood": 5, "faction": "Human"},
	"Warehouse": {"Wood": 1, "faction": "Human"}
}

# 放置模式
var placement_mode_scene: PackedScene = null
var placement_preview: Node2D = null
var placement_building_name: String = ""
var placement_particles: GPUParticles2D = null

# 道路放置状态
var road_start_cell: Vector2i = Vector2i(-1, -1)
var road_start_selected: bool = false
var road_preview_path: Array = []

# 获取当前活动的格子地图
func get_active_grid_map() -> BuildingGrid:
	return human_grid_map if current_realm == Realm.HUMAN else abyss_grid_map

# 获取当前活动的国度容器
func get_active_realm() -> Node2D:
	return $HumanRealm if current_realm == Realm.HUMAN else $AbyssRealm


func _ready() -> void:
	# --- 连接UI与逻辑 ---
	restart_button.pressed.connect(_on_restart_pressed)
	fulfill_order_button.pressed.connect(_on_fulfill_order_pressed)
	tech_button.pressed.connect(_on_tech_button_pressed)
	realm_switch_button.pressed.connect(_on_realm_switch_pressed)
	$CanvasLayer/TransportButton.pressed.connect(_on_transport_button_pressed)

	build_farm_button.pressed.connect(_on_build_button_pressed.bind(FARM_SCENE, BUILDING_COSTS["Farm"], "Farm"))
	build_lumberjack_button.pressed.connect(_on_build_button_pressed.bind(LUMBERJACK_SCENE, BUILDING_COSTS["Lumberjack"], "Lumberjack"))
	build_armory_button.pressed.connect(_on_build_button_pressed.bind(ARMORY_SCENE, BUILDING_COSTS["Armory"], "Armory"))
	build_workshop_button.pressed.connect(_on_build_button_pressed.bind(WORKSHOP_SCENE, BUILDING_COSTS["Workshop"], "Workshop"))
	build_warehouse_button.pressed.connect(_on_build_button_pressed.bind(WAREHOUSE_SCENE, BUILDING_COSTS["Warehouse"], "Warehouse"))
	$CanvasLayer/BuildMenusContainer/HumanBuildMenu/BuildPortalButton.pressed.connect(_on_build_button_pressed.bind(PORTAL_SCENE, BUILDING_COSTS["Portal"], "Portal"))
	$CanvasLayer/BuildMenusContainer/HumanBuildMenu/BuildHousingButton.pressed.connect(_on_build_button_pressed.bind(HOUSING_SCENE, BUILDING_COSTS["Housing"], "Housing"))
	$CanvasLayer/BuildMenusContainer/HumanBuildMenu/BuildFoodProviderButton.pressed.connect(_on_build_button_pressed.bind(FOOD_PROVIDER_SCENE, BUILDING_COSTS["FoodProvider"], "FoodProvider"))
	$CanvasLayer/BuildMenusContainer/HumanBuildMenu/BuildRoadButton.pressed.connect(_on_build_button_pressed.bind(ROAD_SCENE, BUILDING_COSTS["Road"], "Road"))
	build_sulfur_mine_button.pressed.connect(_on_build_button_pressed.bind(SULFUR_MINE_SCENE, BUILDING_COSTS["Sulfur Mine"], "Sulfur Mine"))
	build_fungus_cave_button.pressed.connect(_on_build_button_pressed.bind(FUNGUS_CAVE_SCENE, BUILDING_COSTS["Fungus Cave"], "Fungus Cave"))
	$CanvasLayer/BuildMenusContainer/AbyssBuildMenu/BuildSmugglingDockButton.pressed.connect(_on_build_button_pressed.bind(SMUGGLING_DOCK_SCENE, BUILDING_COSTS["SmugglingDock"], "SmugglingDock"))
	build_lair_button.pressed.connect(_on_build_button_pressed.bind(LAIR_SCENE, BUILDING_COSTS["Lair"], "Lair"))

	# 连接运输面板信号
	transport_panel.transport_requested.connect(_on_transport_requested)

	# 连接GameState信号到UI更新函数
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

	# --- 初始化UI状态 ---
	_on_restart_pressed()

func _unhandled_input(event: InputEvent) -> void:
	if GameState.is_game_over:
		return

	if placement_mode_scene != null:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
			var active_grid = get_active_grid_map()
			var grid_pos = active_grid.world_to_grid(get_global_mouse_position())
			
			# 道路特殊处理
			if placement_building_name == "Road":
				if not road_start_selected:
					road_start_cell = grid_pos
					road_start_selected = true
					print("Road start selected: ", road_start_cell)
				else:
					var path = active_grid.find_road_placement_path(road_start_cell, grid_pos)
					if not path.is_empty():
						_place_road_path(active_grid, path)
						_exit_placement_mode()
					else:
						print("Cannot find path from ", road_start_cell, " to ", grid_pos)
						road_start_selected = false
						road_start_cell = Vector2i(-1, -1)
			else:
				# 普通建筑放置
				var building_size = active_grid.get_building_size(placement_building_name)
				
				# 检查是否可以放置
				if not active_grid.is_area_occupied(grid_pos, building_size):
					var new_building = placement_mode_scene.instantiate()
					var world_pos = active_grid.grid_to_world(grid_pos)
					new_building.position = world_pos
					
					# 设置建筑名称和阵营
					new_building.building_name = placement_building_name
					new_building.faction = "Human" if current_realm == Realm.HUMAN else "Abyss"
					
					# 扣除资源
					if new_building.deduct_building_cost():
						# 记录建筑格子信息以便后续删除
						new_building.set_meta("grid_pos", grid_pos)
						new_building.set_meta("grid_size", building_size)
						
						# 添加到当前活动的国度
						get_active_realm().add_child(new_building)
						active_grid.occupy_area(grid_pos, building_size, new_building)
						
						# 如果是仓库，注册到GridMap
						if placement_building_name == "Warehouse":
							active_grid.set_warehouse(new_building)
						
						# 建立建筑与道路的连接
						active_grid.on_building_placed(new_building)
						
						# 触发粒子效果
						if placement_particles != null:
							placement_particles.global_position = world_pos
							placement_particles.restart()
						
						_exit_placement_mode()
					else:
						print("Failed to deduct resources for building")
						new_building.queue_free()
						_exit_placement_mode()
				else:
					print("Cannot place building: area occupied or invalid")
			
			get_viewport().set_input_as_handled()

		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.is_pressed():
			# 取消放置
			_exit_placement_mode()
			get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if placement_preview != null:
		var active_grid = get_active_grid_map()
		var grid_pos = active_grid.world_to_grid(get_global_mouse_position())
		
		# 道路特殊处理
		if placement_building_name == "Road":
			if road_start_selected:
				road_preview_path = active_grid.find_road_placement_path(road_start_cell, grid_pos)
				active_grid.set_road_preview_path(road_preview_path)
				placement_preview.visible = false
			else:
				active_grid.clear_road_preview_path()
				placement_preview.visible = true
				var world_pos = active_grid.grid_to_world(grid_pos)
				placement_preview.global_position = world_pos
		else:
			# 普通建筑预览
			var world_pos = active_grid.grid_to_world(grid_pos)
			placement_preview.global_position = world_pos
		
		# 更新粒子效果位置
		if placement_particles != null:
			var world_pos = active_grid.grid_to_world(grid_pos)
			placement_particles.global_position = world_pos
		
		# 更新格子高亮
		active_grid.update_highlight(get_global_mouse_position(), placement_building_name)
	
	if GameState.current_order != null and order_time_limit_label != null:
		order_time_limit_label.text = "时限: %.1f" % GameState.current_order.time_limit


# --- 信号处理器 ---

func _on_tech_button_pressed() -> void:
	$CanvasLayer/TechTree.visible = not $CanvasLayer/TechTree.visible

func _on_order_updated(order: Order) -> void:
	if order == null:
		return
	order_target_label.text = "目标: " + order.target_faction
	
	var req_text = "需求:
"
	for mat_name in order.required_materials:
		var quantity = order.required_materials[mat_name]
		req_text += "  - %s: %d
" % [mat_name, quantity]
	order_requirements_label.text = req_text

func _on_fulfill_order_pressed() -> void:
	# This is a placeholder call. The full logic will be implemented later.
	GameState.fulfill_current_order()


func _show_penalty_notification() -> void:
	penalty_label.visible = true
	penalty_timer.start(3.0)

func _on_penalty_timer_timeout() -> void:
	penalty_label.visible = false

func _on_build_button_pressed(building_scene: PackedScene, cost: Dictionary, building_name: String = "") -> void:
	print("Build button pressed for: ", building_name)
	print("Cost: ", cost)
	
	if placement_mode_scene != null:
		_exit_placement_mode()

	var can_afford = _can_afford(cost)
	print("Can afford: ", can_afford)
	
	if can_afford:
		if building_name.is_empty():
			for key in BUILDING_COSTS:
				if BUILDING_COSTS[key] == cost:
					building_name = key
					break
		_enter_placement_mode(building_scene, building_name)
	else:
		print("Not enough resources to build!")

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
	var text = "Warehouse:
"
	text += "  Human:
"
	if warehouses["Human"].is_empty():
		text += "    (Empty)
"
	else:
		for resource_name in warehouses["Human"]:
			text += "    %s: %d
" % [resource_name, warehouses["Human"][resource_name]]

	text += "  Abyss:
"
	if warehouses["Abyss"].is_empty():
		text += "    (Empty)
"
	else:
		for resource_name in warehouses["Abyss"]:
			text += "    %s: %d
" % [resource_name, warehouses["Abyss"][resource_name]]

	warehouse_label.text = text
	_update_button_states()

func _on_population_updated(faction: String, populations: Dictionary) -> void:
	var text = faction + " Population:\n"
	for key in populations:
		var population = populations[key]
		text += "  %s: %d (Happiness: %.1f%%)\n" % [key, population.count, population.happiness]
	
	if faction == "Human":
		human_population_label.text = text
	else:
		abyss_population_label.text = text

func _on_resource_changed(faction: String, resource_name: String, amount: int) -> void:
	if FLOATING_TEXT_SCENE == null:
		return
		
	var text_instance = FLOATING_TEXT_SCENE.instantiate()
	add_child(text_instance)
	
	var sign_str = "+" if amount > 0 else ""
	var content = "%s%d %s" % [sign_str, amount, resource_name]
	
	# 简单的颜色区分：获得为绿，消耗为红
	var color = Color(0.2, 1.0, 0.2) if amount > 0 else Color(1.0, 0.2, 0.2)
	
	# 将浮动文字显示在仓库标签附近，并添加一点随机偏移
	if warehouse_label:
		var random_offset = Vector2(randf_range(0, 50), randf_range(-20, 20))
		# 假设仓库标签在左侧，我们在其右侧显示
		text_instance.global_position = warehouse_label.global_position + Vector2(150, 0) + random_offset
	else:
		text_instance.global_position = get_viewport_rect().get_center()
	
	if text_instance.has_method("setup"):
		text_instance.setup(content, color)


func _on_game_over() -> void:
	game_over_label.show()
	restart_button.show()
	fulfill_order_button.disabled = true
	_update_button_states() # Update all button states dynamically
	if placement_mode_scene:
		_exit_placement_mode()

func _on_restart_pressed() -> void:
	GameState.reset()
	# 给予玩家一些起始资源用于建设
	GameState.add_to_warehouse("Human", "Wood", 20)
	GameState.add_to_warehouse("Human", "Wheat", 10)
	# 给予深渊一些起始资源用于建设
	GameState.add_to_warehouse("Abyss", "Sulfur", 20)
	GameState.add_to_warehouse("Abyss", "Shadow-shroom", 10)

	game_over_label.hide()
	restart_button.hide()
	
	fulfill_order_button.disabled = false
	_update_button_states() # Update all button states dynamically
	_update_build_menu_visibility() # 初始化建筑菜单可见性

	_on_balance_updated(GameState.balance_value)
	_on_warehouse_updated({"Human": GameState.human_warehouse, "Abyss": GameState.abyss_warehouse})
	_on_deserter_count_updated(GameState.alliance_deserters, GameState.abyss_deserters)
	_on_research_points_updated(GameState.research_points, GameState.research_point_generation_rate)
	if GameState.current_order:
		_on_order_updated(GameState.current_order)


# --- 辅助函数 ---

func _update_button_states() -> void:
	fulfill_order_button.disabled = not GameState.can_fulfill_current_order()
	
	_update_build_menu_buttons($CanvasLayer/BuildMenusContainer/HumanBuildMenu)
	_update_build_menu_buttons($CanvasLayer/BuildMenusContainer/AbyssBuildMenu)

func _update_build_menu_buttons(menu_container: Control) -> void:
	print("Updating build menu buttons for: ", menu_container.name)
	for button in menu_container.get_children():
		if button is Button:
			var button_text = button.text
			# 假设按钮文本格式为 "Build <BuildingName>"
			var building_name_start = button_text.find("Build ")
			if building_name_start != -1:
				var building_name = button_text.substr(building_name_start + 6).strip_edges()
				# 处理特殊名称（如 SmugglingDock）
				if building_name == "Smuggling Dock":
					building_name = "SmugglingDock"
				print("  Button: ", button_text, " -> Building: ", building_name)
				if BUILDING_COSTS.has(building_name):
					var can_afford = _can_afford(BUILDING_COSTS[building_name])
					button.disabled = not can_afford
					print("    Disabled: ", button.disabled)
				else:
					# 如果成本未定义，可能是不应该可建造的，或者是一个新的科技建筑
					button.disabled = true
					print("    No cost defined, disabled")
			else:
				button.disabled = true # 无法解析的按钮文本，禁用它
				print("    Cannot parse button text, disabled")

func _update_build_menu_visibility() -> void:
	# 根据当前国度显示/隐藏建筑菜单
	var human_menu = $CanvasLayer/BuildMenusContainer/HumanBuildMenu
	var abyss_menu = $CanvasLayer/BuildMenusContainer/AbyssBuildMenu
	var human_label = $CanvasLayer/BuildMenusContainer/HumanBuildLabel
	var abyss_label = $CanvasLayer/BuildMenusContainer/AbyssBuildLabel
	
	if current_realm == Realm.HUMAN:
		human_menu.visible = true
		human_label.visible = true
		abyss_menu.visible = false
		abyss_label.visible = false
	else:
		human_menu.visible = false
		human_label.visible = false
		abyss_menu.visible = true
		abyss_label.visible = true


func _enter_placement_mode(building_scene: PackedScene, building_name: String) -> void:
	placement_mode_scene = building_scene
	placement_building_name = building_name
	placement_preview = placement_mode_scene.instantiate()
	# 使预览半透明
	placement_preview.modulate = Color(1, 1, 1, 0.5)
	# 设置z_index确保预览显示在Ground上面
	placement_preview.z_index = 100
	get_active_realm().add_child(placement_preview)
	
	# 添加粒子效果
	placement_particles = PLACEMENT_PARTICLES_SCENE.instantiate()
	placement_particles.z_index = 101
	get_active_realm().add_child(placement_particles)

func _exit_placement_mode() -> void:
	if placement_preview != null:
		placement_preview.queue_free()
		placement_preview = null
	if placement_particles != null:
		placement_particles.queue_free()
		placement_particles = null
	placement_mode_scene = null
	placement_building_name = ""
	
	# 清除道路放置状态
	road_start_cell = Vector2i(-1, -1)
	road_start_selected = false
	road_preview_path.clear()
	
	# 清除格子高亮
	var active_grid = get_active_grid_map()
	active_grid.placement_building_name = ""
	active_grid.highlighted_cell = Vector2i(-1, -1)
	active_grid.clear_road_preview_path()
	active_grid.queue_redraw()

func _place_road_path(active_grid: BuildingGrid, path: Array) -> void:
	# 清除预览路径
	active_grid.clear_road_preview_path()
	
	for grid_pos in path:
		# 检查该位置是否已经有道路
		if active_grid.get_road_at(grid_pos) != null:
			continue
		
		# 创建道路节点
		var new_road = ROAD_SCENE.instantiate()
		var world_pos = active_grid.grid_to_world(grid_pos)
		new_road.position = world_pos
		get_active_realm().add_child(new_road)
		
		# 使用TileLayer放置道路
		active_grid.occupy_area(grid_pos, Vector2i(1, 1), new_road)
		active_grid.add_road(grid_pos, new_road)
		
		print("Road placed at: ", grid_pos)
	
	# 触发粒子效果（在路径中心）
	if not path.is_empty():
		var center_index = floor(path.size() / 2.0)
		var center_pos = active_grid.grid_to_world(path[center_index])
		if placement_particles != null:
			placement_particles.global_position = center_pos
			placement_particles.restart()
	
	print("Road path placed with ", path.size(), " segments")
	
	# 更新所有生产建筑的连接状态
	_update_production_buildings_connection_status(active_grid)

func _update_production_buildings_connection_status(grid: BuildingGrid) -> void:
	for child in get_active_realm().get_children():
		if child is ProductionBuilding:
			child._check_warehouse_connection()

func _on_realm_switch_pressed() -> void:
	# 切换国度
	if current_realm == Realm.HUMAN:
		current_realm = Realm.ABYSS
		realm_switch_button.text = "切换到人类"
	else:
		current_realm = Realm.HUMAN
		realm_switch_button.text = "切换到深渊"
	
	# 更新地图可见性
	if current_realm == Realm.HUMAN:
		$HumanRealm.visible = true
		$AbyssRealm.visible = false
	else:
		$HumanRealm.visible = false
		$AbyssRealm.visible = true
	
	# 更新建筑菜单的可见性
	_update_build_menu_visibility()
	
	# 更新运输面板的默认设置
	_update_transport_panel_defaults()

func _update_transport_panel_defaults() -> void:
	# 根据当前国度设置运输面板的默认值
	if current_realm == Realm.HUMAN:
		transport_panel.set_from_faction("Human")
		transport_panel.set_to_faction("Abyss")
	else:
		transport_panel.set_from_faction("Abyss")
		transport_panel.set_to_faction("Human")

func _on_transport_button_pressed() -> void:
	# 打开/关闭运输面板
	transport_panel.visible = not transport_panel.visible
	if transport_panel.visible:
		_update_transport_panel_defaults()
		transport_panel.reset_status()

func _on_transport_requested(from_faction: String, to_faction: String, resource_name: String, quantity: int) -> void:
	# 查找传送门或走私船坞
	var portal = _find_portal(from_faction)
	if portal == null:
		print("No portal found in ", from_faction)
		return
	
	# 启动运输
	if portal.start_transport(from_faction, to_faction, resource_name, quantity):
		print("Transport started successfully")
	else:
		print("Transport failed")

func _find_portal(faction: String) -> PortalBuilding:
	var realm: Node2D
	if faction == "Human":
		realm = $HumanRealm
	else:
		realm = $AbyssRealm
	
	for child in realm.get_children():
		if child is PortalBuilding:
			return child
	return null

func _can_afford(cost: Dictionary) -> bool:
	var cost_copy = cost.duplicate()
	var faction = cost_copy.get("faction", "Human") # 如果未指定，则默认为Human
	cost_copy.erase("faction")

	print("Checking affordability for faction: ", faction)
	print("Cost copy: ", cost_copy)
	
	for resource_name in cost_copy:
		var required_amount = cost_copy[resource_name]
		var has_resource = GameState.has_in_warehouse(faction, resource_name, required_amount)
		print("  Checking ", resource_name, ": need ", required_amount, ", has: ", has_resource)
		if not has_resource:
			return false
	return true

func _deduct_cost(cost: Dictionary) -> void:
	var cost_copy = cost.duplicate()
	var faction = cost_copy.get("faction", "Human") # 如果未指定，则默认为Human
	cost_copy.erase("faction")

	for resource_name in cost_copy:
		var amount = cost_copy[resource_name]
		GameState.get_from_warehouse(faction, resource_name, amount)

func _on_building_unlocked(building_scene_path: String, building_name: String, faction: String, cost: Dictionary) -> void:
	print("Building unlocked: ", building_name, " (", building_scene_path, ") for ", faction, " with cost: ", cost)

	# 添加到 BUILDING_COSTS
	BUILDING_COSTS[building_name] = cost

	# 预加载场景
	var building_scene = load(building_scene_path)

	# 确定目标菜单
	var menu_container
	if faction == "Human":
		menu_container = $CanvasLayer/BuildMenusContainer/HumanBuildMenu
	elif faction == "Abyss":
		menu_container = $CanvasLayer/BuildMenusContainer/AbyssBuildMenu
	else:
		print("Unknown faction for building: ", faction)
		return

	# 创建新按钮
	var new_button = Button.new()
	new_button.text = "建造 " + building_name
	new_button.pressed.connect(_on_build_button_pressed.bind(building_scene, cost, building_name))
	menu_container.add_child(new_button)

	# 更新按钮状态
	_update_button_states()
