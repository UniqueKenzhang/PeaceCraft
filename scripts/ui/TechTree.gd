extends Control

@onready var close_button: Button = $Panel/VBoxContainer/CloseButton
@onready var tech_items_container: VBoxContainer = $Panel/VBoxContainer/TechItemsContainer
@onready var current_rp_label: Label = $Panel/VBoxContainer/CurrentRPLabel

# 科技项目场景模板
const TECH_ITEM_SCENE = preload("res://scenes/ui/TechItem.tscn")

func _ready() -> void:
	close_button.pressed.connect(hide)
	var game_state = get_node("/root/GameState")
	if game_state:
		game_state.research_points_updated.connect(_on_research_points_updated)

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		if visible:
			_update_ui()

func _on_research_points_updated(_rp, _rate) -> void:
	if visible:
		_update_rp_label()

func _update_ui() -> void:
	_update_rp_label()
	_populate_tech_items()

func _update_rp_label() -> void:
	if current_rp_label:
		var game_state = get_node("/root/GameState")
		var total_deserters = game_state.alliance_deserters + game_state.abyss_deserters
		var balance_factor = 0.0
		if total_deserters > 0:
			balance_factor = 1.0 - (abs(game_state.alliance_deserters - game_state.abyss_deserters) / float(total_deserters))
		
		# Re-calculate base for display
		var base_generation = game_state.BASE_RP_RATE * total_deserters * balance_factor
		
		var text = "当前科研点: %.1f\n" % game_state.research_points
		text += "产出速率: %.2f/s\n" % game_state.research_point_generation_rate
		text += "------------------\n"
		text += "逃兵总数: %d (平衡度: %.0f%%)\n" % [total_deserters, balance_factor * 100]
		text += "基础产出: %.2f\n" % base_generation
		text += "设施加成: x%.1f (收容所: %d)" % [game_state.rp_bonus_multiplier, game_state.active_shelters]
		
		current_rp_label.text = text

func _populate_tech_items() -> void:
	# 清空现有项目
	for child in tech_items_container.get_children():
		child.queue_free()

	var game_state = get_node("/root/GameState")

	# 获取所有可用科技
	for tech_name in game_state.available_techs:
		var tech = game_state.available_techs[tech_name]

		# 实例化科技项目
		var tech_item_instance = TECH_ITEM_SCENE.instantiate()
		tech_items_container.add_child(tech_item_instance)

		# 设置科技信息并连接信号
		if tech_item_instance.has_method("setup"):
			tech_item_instance.setup(tech)
			tech_item_instance.unlock_requested.connect(_on_tech_unlock_requested)
		else:
			print("Error: TechItem script missing setup method!")

func _on_tech_unlock_requested(tech_name: String) -> void:
	var game_state = get_node("/root/GameState")
	if game_state.unlock_tech(tech_name):
		# 解锁成功，刷新UI
		_update_ui()
