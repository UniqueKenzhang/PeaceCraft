extends Node

class_name TransportManager

signal transport_requested(from_faction: String, to_faction: String, resource_name: String, quantity: int)

var transport_panel: Control
var transport_button: Button

const TRANSPORT_PANEL_SCENE = preload("res://scenes/ui/TransportPanel.tscn")
const TRANSPORT_TIME = 5.0

func initialize(canvas_layer: CanvasLayer) -> void:
	transport_panel = TRANSPORT_PANEL_SCENE.instantiate()
	canvas_layer.add_child(transport_panel)
	transport_panel.visible = false
	
	transport_button = canvas_layer.get_node("TransportButton")
	transport_button.pressed.connect(_on_transport_button_pressed)
	
	transport_panel.transport_requested.connect(_on_transport_requested)

func _on_transport_button_pressed() -> void:
	transport_panel.visible = not transport_panel.visible
	
	if transport_panel.visible:
		_update_transport_panel_defaults()

func _on_transport_requested(from_faction: String, to_faction: String, resource_name: String, quantity: int) -> void:
	var cost = quantity * 2
	
	if not GameState.has_in_warehouse(from_faction, resource_name, quantity):
		print("Not enough ", resource_name, " in ", from_faction, " warehouse")
		return
	
	if not GameState.has_in_warehouse(from_faction, "Wood", cost):
		print("Not enough Wood for transport cost")
		return
	
	GameState.get_from_warehouse(from_faction, resource_name, quantity)
	GameState.get_from_warehouse(from_faction, "Wood", cost)
	
	print("Transport started: ", quantity, " ", resource_name, " from ", from_faction, " to ", to_faction)
	
	await get_tree().create_timer(TRANSPORT_TIME).timeout
	
	GameState.add_to_warehouse(to_faction, resource_name, quantity)
	print("Transport completed: ", quantity, " ", resource_name, " delivered to ", to_faction)
	
	transport_panel.visible = false

func _update_transport_panel_defaults() -> void:
	var current_faction = "Human" if GameState.current_realm == 0 else "Abyss"
	var target_faction = "Abyss" if current_faction == "Human" else "Human"
	
	transport_panel.set_defaults(current_faction, target_faction)

func _find_portal(faction: String) -> PortalBuilding:
	var realm = $HumanRealm if faction == "Human" else $AbyssRealm
	for child in realm.get_children():
		if child is PortalBuilding:
			return child
	return null