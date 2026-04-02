extends Control

signal transport_requested(from_faction: String, to_faction: String, resource_name: String, quantity: int)

@onready var from_faction_label: Label = $VBoxContainer/FromFactionLabel
@onready var to_faction_label: Label = $VBoxContainer/ToFactionLabel
@onready var resource_name_edit: LineEdit = $VBoxContainer/ResourceNameEdit
@onready var quantity_spin: SpinBox = $VBoxContainer/QuantitySpin
@onready var transport_button: Button = $VBoxContainer/TransportButton
@onready var status_label: Label = $VBoxContainer/StatusLabel

var current_from_faction: String = "Human"
var current_to_faction: String = "Abyss"

func _ready() -> void:
	_update_faction_labels()
	transport_button.pressed.connect(_on_transport_button_pressed)

func _on_transport_button_pressed() -> void:
	var resource_name = resource_name_edit.text.strip_edges()
	var quantity = quantity_spin.value
	
	if resource_name.is_empty():
		status_label.text = "请输入资源名称"
		return
	
	if quantity <= 0:
		status_label.text = "数量必须大于0"
		return
	
	emit_signal("transport_requested", current_from_faction, current_to_faction, resource_name, quantity)
	status_label.text = "运输请求已发送"

func set_from_faction(faction: String) -> void:
	current_from_faction = faction
	_update_faction_labels()

func set_to_faction(faction: String) -> void:
	current_to_faction = faction
	_update_faction_labels()

func _update_faction_labels() -> void:
	from_faction_label.text = "从: " + current_from_faction
	to_faction_label.text = "到: " + current_to_faction

func reset_status() -> void:
	status_label.text = ""
	resource_name_edit.text = ""
	quantity_spin.value = 1
