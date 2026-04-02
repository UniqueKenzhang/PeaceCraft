extends Node

# 用于通知UI有关变化的信号
signal balance_updated(new_balance)
signal game_over
signal warehouse_updated(faction_warehouses)
signal penalty_triggered
signal deserter_count_updated(alliance_deserters, abyss_deserters)
signal order_updated(new_order)
signal research_points_updated(rp, rp_rate)
signal building_unlocked(building_scene_path, building_name, faction, cost)
signal resource_changed(faction, resource_name, change_amount)

# --- 模块一: 动态平衡系统 ---
var balance_value: float = 0.0
var domination_timer: float = 0.0
const DOMINATION_THRESHOLD: float = 75.0
const COLLAPSE_TIME_LIMIT: float = 10.0 # 使用10秒以便于测试
var is_game_over: bool = false
const COUNTERFEIT_DETECTION_RISK = 0.15

# --- 模块一.二: 指令系统 ---
var current_order: Order = null
var order_timer: Timer
const ORDER_INTERVAL_SECONDS = 30.0 # 每30秒一个新指令

# --- 模块四: 逃兵与共振 ---
var alliance_deserters: int = 0
var abyss_deserters: int = 0
var research_points: float = 0.0
var research_point_generation_rate: float = 0.0
var research_timer: Timer
const BASE_RP_RATE = 0.1 # 每秒每个逃兵的基础产出
var rp_bonus_multiplier: float = 1.0 # 科研点数产出倍率
var active_shelters: int = 0 # 活跃的收容所数量

# 战斗结算的占位符值
const TOTAL_FRONTLINE_POPULATION = 1000
const BASE_FATALITY_RATE = 0.10
const BASE_DESERTER_RATE = 0.05

# --- 模块五: 科技系统 ---
var available_techs: Dictionary = {}  # 所有可用科技
var unlocked_techs: Dictionary = {}   # 已解锁科技
var production_efficiency_bonus: float = 0.0  # 全局生产效率加成

# --- 模块三: Anno风格建设与经济系统 ---
# 我们使用字典来存储资源数量. 键: 资源名称 (String), 值: 数量 (int)
var human_warehouse: Dictionary = {}
var abyss_warehouse: Dictionary = {}

# 人口阶层系统
var human_populations: Dictionary = {}
var abyss_populations: Dictionary = {}

# 这里将保存所有可制造资源的定义
var crafting_resources: Dictionary = {}
# 这里将保存所有三色物资的定义
var materials: Dictionary = {}
# 已解锁的可用于订单的物资名称列表
var unlocked_material_names: Array = []

signal population_updated(faction, population_data)


func _ready() -> void:
	_define_crafting_resources()
	_define_materials()
	_define_techs()

	order_timer = Timer.new()
	order_timer.wait_time = ORDER_INTERVAL_SECONDS
	order_timer.one_shot = false # Keep repeating, for now
	order_timer.timeout.connect(_on_order_timer_timeout)
	add_child(order_timer)

	research_timer = Timer.new()
	research_timer.wait_time = 1.0 # Calculate every second
	research_timer.one_shot = false
	research_timer.timeout.connect(_on_research_timer_timeout)
	add_child(research_timer)

	reset()

func _process(delta: float) -> void:
	if is_game_over:
		return
	# 检查优胜状态
	if abs(balance_value) > DOMINATION_THRESHOLD:
		domination_timer += delta
		if domination_timer > COLLAPSE_TIME_LIMIT:
			print("Stalemate Collapse! Game Over.")
			is_game_over = true
			emit_signal("game_over")
	else:
		# 如果恢复平衡则重置计时器
		domination_timer = 0.0
	
	# 更新人口阶层系统
	update_populations(delta)

# --- 私有方法 ---

func _on_research_timer_timeout() -> void:
	if is_game_over:
		return
	
	var total_deserters = alliance_deserters + abyss_deserters
	if total_deserters == 0:
		research_point_generation_rate = 0.0
		emit_signal("research_points_updated", research_points, research_point_generation_rate)
		return
		
	var balance_factor = 1.0 - (abs(alliance_deserters - abyss_deserters) / float(total_deserters))
	research_point_generation_rate = BASE_RP_RATE * total_deserters * balance_factor * rp_bonus_multiplier
	
	research_points += research_point_generation_rate
	
	emit_signal("research_points_updated", research_points, research_point_generation_rate)

func register_shelter() -> void:
	active_shelters += 1
	_update_rp_multiplier()

func unregister_shelter() -> void:
	active_shelters -= 1
	if active_shelters < 0: active_shelters = 0
	_update_rp_multiplier()

func _update_rp_multiplier() -> void:
	rp_bonus_multiplier = 1.0 + (active_shelters * 0.1) # 每个收容所提供10%加成
	print("Active shelters: ", active_shelters, ", RP multiplier: ", rp_bonus_multiplier)

func _on_order_timer_timeout() -> void:
	if is_game_over:
		return
		
	# If an order exists when the timer runs out, the player has failed it.
	if current_order != null:
		print("Order failed! Applying penalty.")
		# TODO: Implement more complex penalties as per 01_DYNAMIC_BALANCE.md
		var penalty_impact = -10.0
		update_balance(penalty_impact)
		emit_signal("penalty_triggered") # Reuse the counterfeit penalty signal for UI feedback

	# Whether the last order succeeded or failed, a new one is issued.
	print("Order timer timeout, generating new order.")
	_generate_new_order()

var resource_faction_map: Dictionary = {
	"Wheat": "Human",
	"Wood": "Human",
	"Sulfur": "Abyss",
	"Shadow-shroom": "Abyss",
	"True Armaments": "Human",
	"Counterfeit Gear": "Human", # Let's say humans make them
	"Whimsical Subversion": "Abyss", # Let's say abyss makes them
	"Enhanced Whimsical Subversion": "Abyss",
}

func _generate_new_order() -> void:
	var new_order = Order.new()
	
	# Randomly choose faction for the order to target
	if randf() > 0.5:
		new_order.target_faction = "Human"
	else:
		new_order.target_faction = "Abyss"
		
	# Randomly create requirements from the unlocked material types
	var material_names = unlocked_material_names
	var required = {}
	var num_requirements = randi_range(1, 2)
	for i in range(num_requirements):
		if material_names.is_empty():
			break
		var mat_name = material_names.pick_random()
		if not required.has(mat_name):
			required[mat_name] = randi_range(1, 5) # Orders require fewer crafted items
	
	new_order.required_materials = required
	new_order.time_limit = ORDER_INTERVAL_SECONDS # Simple countdown
	
	current_order = new_order
	print("New Order Generated: ", current_order.required_materials, " for ", current_order.target_faction)
	emit_signal("order_updated", current_order)

func _define_materials() -> void:
	# True Armaments
	var true_arms = HumanMaterial.new()
	true_arms.material_name = "True Armaments"
	true_arms.balance_impact = 10.0
	true_arms.fatality_rate_modifier = 0.05
	true_arms.deserter_rate_modifier = -0.05
	materials[true_arms.material_name] = true_arms

	# Counterfeit Gear
	var counterfeit_gear = HumanMaterial.new()
	counterfeit_gear.material_name = "Counterfeit Gear"
	counterfeit_gear.balance_impact = -10.0
	counterfeit_gear.fatality_rate_modifier = 0.02
	counterfeit_gear.detection_risk = 0.15
	materials[counterfeit_gear.material_name] = counterfeit_gear

	# Whimsical Subversion
	var whimsical_sub = HumanMaterial.new()
	whimsical_sub.material_name = "Whimsical Subversion"
	whimsical_sub.balance_impact = 8.0
	whimsical_sub.fatality_rate_modifier = -0.5
	whimsical_sub.deserter_rate_modifier = 0.5
	materials[whimsical_sub.material_name] = whimsical_sub

	# 默认解锁前三种物资
	unlocked_material_names.append("True Armaments")
	unlocked_material_names.append("Counterfeit Gear")
	unlocked_material_names.append("Whimsical Subversion")

	# Enhanced Whimsical Subversion (解锁后可用)
	var enhanced_whimsical = HumanMaterial.new()
	enhanced_whimsical.material_name = "Enhanced Whimsical Subversion"
	enhanced_whimsical.balance_impact = 12.0
	enhanced_whimsical.fatality_rate_modifier = -0.7
	enhanced_whimsical.deserter_rate_modifier = 0.7
	materials[enhanced_whimsical.material_name] = enhanced_whimsical

	print("Defined materials: ", materials.keys())

func _define_techs() -> void:
	print("Defining techs...")
	# 科技1: 高级恶搞物资
	var tech1 = TechResource.new()
	tech1.tech_name = "高级恶搞物资"
	tech1.description = "解锁效果更强的恶作剧，提供更显著的战略优势。"
	tech1.research_cost = 50.0
	tech1.effect_type = TechResource.EffectType.UNLOCK_NEW_MATERIAL
	tech1.effect_parameters = {
		"material_name": "Enhanced Whimsical Subversion"
	}
	available_techs[tech1.tech_name] = tech1

	# 科技2: 生产效率提升
	var tech2 = TechResource.new()
	tech2.tech_name = "生产优化"
	tech2.description = "提升所有生产建筑10%的效率。"
	tech2.research_cost = 30.0
	tech2.effect_type = TechResource.EffectType.PRODUCTION_EFFICIENCY
	tech2.effect_parameters = {
		"efficiency_bonus": 0.10
	}
	available_techs[tech2.tech_name] = tech2

	# 科技3: 逃兵管理设施
	var tech3 = TechResource.new()
	tech3.tech_name = "逃兵收容所"
	tech3.description = "解锁特殊建筑，用于管理逃兵人口。"
	tech3.research_cost = 40.0
	tech3.effect_type = TechResource.EffectType.UNLOCK_NEW_BUILDING
	tech3.effect_parameters = {
		"building_scene": "res://scenes/buildings/DeserterShelter.tscn",
		"building_name": "DeserterShelter",
		"faction": "Human",
		"cost": {"Wood": 30, "Wheat": 10, "faction": "Human"} # 添加成本信息
	}
	available_techs[tech3.tech_name] = tech3

	print("Defined techs: ", available_techs.keys())

func _define_crafting_resources() -> void:
	# 人类阵营
	var wheat = CraftingResource.new()
	wheat.human_resource_name = "Wheat"
	crafting_resources["Wheat"] = wheat
	
	var wood = CraftingResource.new()
	wood.human_resource_name = "Wood"
	crafting_resources["Wood"] = wood

	# 深渊阵营
	var sulfur = CraftingResource.new()
	sulfur.human_resource_name = "Sulfur"
	crafting_resources["Sulfur"] = sulfur
	
	var shadow_shroom = CraftingResource.new()
	shadow_shroom.human_resource_name = "Shadow-shroom"
	crafting_resources["Shadow-shroom"] = shadow_shroom
	
	print("Defined crafting resources: ", crafting_resources.keys())

# --- 公开 API ---

func unlock_tech(tech_name: String) -> bool:
	if is_game_over:
		return false

	if not available_techs.has(tech_name):
		print("Tech not found: ", tech_name)
		return false

	var tech = available_techs[tech_name]
	if tech.is_unlocked:
		print("Tech already unlocked: ", tech_name)
		return false

	if research_points < tech.research_cost:
		print("Not enough research points to unlock ", tech_name, ". Need ", tech.research_cost, " have ", research_points)
		return false

	# 扣除科研点数
	research_points -= tech.research_cost
	tech.is_unlocked = true
	unlocked_techs[tech_name] = tech

	# 应用科技效果
	_apply_tech_effect(tech)

	print("Tech unlocked successfully: ", tech_name)
	emit_signal("research_points_updated", research_points, research_point_generation_rate)
	return true

func _apply_tech_effect(tech: TechResource) -> void:
	match tech.effect_type:
		TechResource.EffectType.UNLOCK_NEW_MATERIAL:
			var new_material_name = tech.effect_parameters.get("material_name")
			print("New material unlocked: ", new_material_name)
			if new_material_name and not unlocked_material_names.has(new_material_name):
				unlocked_material_names.append(new_material_name)
			# 新物资已在materials中定义，现在可以出现在订单中
			# 可以在这里触发UI更新或其他效果
		TechResource.EffectType.PRODUCTION_EFFICIENCY:
			var bonus = tech.effect_parameters.get("efficiency_bonus", 0.0)
			production_efficiency_bonus += bonus
			print("Production efficiency increased by: ", bonus, ". Total bonus: ", production_efficiency_bonus)
			# 可以在这里通知所有生产建筑更新效率
		TechResource.EffectType.UNLOCK_NEW_BUILDING:
			var building_scene = tech.effect_parameters.get("building_scene")
			var building_name = tech.effect_parameters.get("building_name", "New Building")
			var faction = tech.effect_parameters.get("faction", "Human")
			var cost = tech.effect_parameters.get("cost", {})
			
			print("New building unlocked: ", building_name, " (", building_scene, ") for ", faction, " with cost: ", cost)
			# 触发信号通知MainScene更新UI
			emit_signal("building_unlocked", building_scene, building_name, faction, cost)
		TechResource.EffectType.SPECIAL_EFFECT:
			print("Special effect applied: ", tech.effect_parameters)
		_:
			print("Unknown tech effect type")

func process_delivery(material: HumanMaterial, target_faction: String) -> void:
	print("Processing delivery of: ", material.material_name, " for ", target_faction)

	# 1. 检查假货风险
	if material.material_name == "Counterfeit Gear":
		if randf() < material.detection_risk:
			print("Counterfeit Gear delivery DETECTED! Triggering penalty.")
			trigger_penalty()
			# 交付失败，不产生任何效果
			return

	# 2. 更新战场平衡
	var final_impact = material.balance_impact
	if target_faction == "Abyss":
		final_impact = -final_impact # A positive impact for Abyss means moving the bar towards their side (negative)
	update_balance(final_impact)

	# 3. 结算战斗伤亡和逃兵
	var final_fatality_rate = clamp(BASE_FATALITY_RATE + material.fatality_rate_modifier, 0.0, 1.0)
	var final_deserter_rate = clamp(BASE_DESERTER_RATE + material.deserter_rate_modifier, 0.0, 1.0) # Corrected typo

	var fatalities = int(TOTAL_FRONTLINE_POPULATION * final_fatality_rate)
	var deserters = int(TOTAL_FRONTLINE_POPULATION * final_deserter_rate)

	if target_faction == "Human":
		alliance_deserters += deserters
	elif target_faction == "Abyss":
		abyss_deserters += deserters

	print("Battle settled. Fatalities: %d, Deserters: %d, Final Deserter Rate: %.2f (for ", target_faction, ")" % [fatalities, deserters, final_deserter_rate])
	
	# 4. 发出信号以更新UI
	emit_signal("deserter_count_updated", alliance_deserters, abyss_deserters)


func fulfill_current_order() -> void:
	if is_game_over or not can_fulfill_current_order():
		print("Cannot fulfill order: Not enough resources or no active order.")
		return

	print("Fulfilling order for: ", current_order.target_faction)

	# Process effects for each delivered item
	for resource_name in current_order.required_materials:
		var quantity = current_order.required_materials[resource_name]
		var faction = resource_faction_map[resource_name]
		var material: HumanMaterial = materials[resource_name]
		
		# Deduct resource
		get_from_warehouse(faction, resource_name, quantity)
		
		# Process effect for each unit
		for i in range(quantity):
			process_delivery(material, current_order.target_faction)

	# Generate the next order
	_generate_new_order()


func can_fulfill_current_order() -> bool:
	if is_game_over or current_order == null:
		return false

	for resource_name in current_order.required_materials:
		var required_amount = current_order.required_materials[resource_name]
		if not resource_faction_map.has(resource_name):
			return false # Should not happen if orders are generated correctly
		
		var faction = resource_faction_map[resource_name]
		if not has_in_warehouse(faction, resource_name, required_amount):
			return false
			
	return true


func update_balance(impact: float) -> void:
	if is_game_over:
		return
	balance_value = clamp(balance_value + impact, -100.0, 100.0)
	print("Balance updated by: ", impact, ". New balance: ", balance_value)
	emit_signal("balance_updated", balance_value)

func trigger_penalty() -> void:
	if is_game_over:
		return
	var penalty_impact = -25.0
	print("Penalty triggered! Balance impacted by: ", penalty_impact)
	update_balance(penalty_impact)
	emit_signal("penalty_triggered")

func add_to_warehouse(faction: String, resource_name: String, quantity: int) -> void:
	var warehouse = human_warehouse if faction == "Human" else abyss_warehouse
	if not warehouse.has(resource_name):
		warehouse[resource_name] = 0
	warehouse[resource_name] += quantity
	print(faction, " warehouse: +", quantity, " ", resource_name, ". Total: ", warehouse[resource_name])
	emit_signal("warehouse_updated", {"Human": human_warehouse, "Abyss": abyss_warehouse})
	emit_signal("resource_changed", faction, resource_name, quantity)

func get_from_warehouse(faction: String, resource_name: String, quantity: int) -> bool:
	var warehouse = human_warehouse if faction == "Human" else abyss_warehouse
	if has_in_warehouse(faction, resource_name, quantity):
		warehouse[resource_name] -= quantity
		print(faction, " warehouse: -", quantity, " ", resource_name, ". Total: ", warehouse[resource_name])
		emit_signal("warehouse_updated", {"Human": human_warehouse, "Abyss": abyss_warehouse})
		emit_signal("resource_changed", faction, resource_name, -quantity)
		return true
	return false

func has_in_warehouse(faction: String, resource_name: String, quantity: int) -> bool:
	var warehouse = human_warehouse if faction == "Human" else abyss_warehouse
	return warehouse.has(resource_name) and warehouse[resource_name] >= quantity

func reset() -> void:
	balance_value = 0.0
	domination_timer = 0.0
	is_game_over = false
	alliance_deserters = 0
	abyss_deserters = 0
	research_points = 0.0
	research_point_generation_rate = 0.0
	current_order = null

	# 重置科技状态
	unlocked_techs.clear()
	for tech_name in available_techs:
		var tech = available_techs[tech_name]
		tech.is_unlocked = false

	human_warehouse.clear()
	abyss_warehouse.clear()

	# 初始化人口阶层系统
	_init_populations()

	if order_timer != null:
		order_timer.stop()
	if research_timer != null:
		research_timer.stop()

	print("Game state has been reset.")
	# Start game with an order
	_generate_new_order()
	order_timer.start()
	research_timer.start()

	emit_signal("balance_updated", balance_value)
	emit_signal("warehouse_updated", {"Human": human_warehouse, "Abyss": abyss_warehouse})
	emit_signal("deserter_count_updated", alliance_deserters, abyss_deserters)
	emit_signal("research_points_updated", research_points, research_point_generation_rate)
	emit_signal("population_updated", "Human", human_populations)
	emit_signal("population_updated", "Abyss", abyss_populations)

func _init_populations() -> void:
	human_populations.clear()
	abyss_populations.clear()
	
	# 初始化人类人口阶层
	human_populations["Worker"] = Population.new(Population.SocialClass.WORKER, 10)
	human_populations["Artisan"] = Population.new(Population.SocialClass.ARTISAN, 5)
	human_populations["Noble"] = Population.new(Population.SocialClass.NOBLE, 2)
	
	# 初始化深渊人口阶层
	abyss_populations["Worker"] = Population.new(Population.SocialClass.WORKER, 10)
	abyss_populations["Artisan"] = Population.new(Population.SocialClass.ARTISAN, 5)
	abyss_populations["Noble"] = Population.new(Population.SocialClass.NOBLE, 2)
	
	print("Populations initialized")

func update_populations(delta: float) -> void:
	for key in human_populations:
		human_populations[key].update(delta)
	
	for key in abyss_populations:
		abyss_populations[key].update(delta)
	
	emit_signal("population_updated", "Human", human_populations)
	emit_signal("population_updated", "Abyss", abyss_populations)

func get_population(faction: String, key: String) -> Population:
	var populations = human_populations if faction == "Human" else abyss_populations
	if populations.has(key):
		return populations[key]
	return null

func add_population(faction: String, key: String, amount: int) -> void:
	var populations = human_populations if faction == "Human" else abyss_populations
	if populations.has(key):
		populations[key].add_population(amount)
		emit_signal("population_updated", faction, populations)

func satisfy_population_need(faction: String, key: String, need_name: String) -> void:
	var populations = human_populations if faction == "Human" else abyss_populations
	if populations.has(key):
		populations[key].satisfy_need(need_name)

func get_total_population(faction: String) -> int:
	var populations = human_populations if faction == "Human" else abyss_populations
	var total = 0
	for key in populations:
		total += populations[key].count
	return total
