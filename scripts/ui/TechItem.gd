extends Panel

signal unlock_requested(tech_name)

@onready var name_label: Label = $HBoxContainer/InfoVBox/NameLabel
@onready var desc_label: Label = $HBoxContainer/InfoVBox/DescLabel
@onready var cost_label: Label = $HBoxContainer/InfoVBox/CostLabel
@onready var unlock_button: Button = $HBoxContainer/UnlockButton

var tech_name: String = ""

func setup(tech: TechResource) -> void:
	tech_name = tech.tech_name
	name_label.text = tech.tech_name
	desc_label.text = tech.description
	cost_label.text = "成本: %.0f RP" % tech.research_cost
	
	var game_state = get_node("/root/GameState")
	
	if tech.is_unlocked:
		unlock_button.text = "已解锁"
		unlock_button.disabled = true
		self.modulate = Color(0.7, 1.0, 0.7) # 浅绿色表示已解锁
	else:
		unlock_button.text = "解锁"
		unlock_button.disabled = game_state.research_points < tech.research_cost
		self.modulate = Color(1.0, 1.0, 1.0) # 正常颜色

	# 连接信号
	if not unlock_button.pressed.is_connected(_on_unlock_button_pressed):
		unlock_button.pressed.connect(_on_unlock_button_pressed)

func _on_unlock_button_pressed() -> void:
	emit_signal("unlock_requested", tech_name)
