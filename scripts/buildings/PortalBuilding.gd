extends Node2D

class_name PortalBuilding

enum PortalType { PORTAL, SMUGGLING_DOCK }

@export var portal_type: PortalType = PortalType.PORTAL
@export var faction: String = "Human"

var transport_timer: Timer
var is_transporting: bool = false
var transport_queue: Array = []

const TRANSPORT_TIME = 5.0 # 运输所需时间（秒）
const TRANSPORT_COST_PER_UNIT = 1.0 # 每个单位的运输成本

func _ready() -> void:
	transport_timer = Timer.new()
	transport_timer.wait_time = TRANSPORT_TIME
	transport_timer.one_shot = true
	transport_timer.timeout.connect(_on_transport_complete)
	add_child(transport_timer)
	
	print(self.name, " ready. Type: ", portal_type, ", Faction: ", faction)

func start_transport(from_faction: String, to_faction: String, resource_name: String, quantity: int) -> bool:
	if is_transporting:
		print("Portal is busy, cannot start transport")
		return false
	
	# 检查是否有足够的资源
	if not GameState.has_in_warehouse(from_faction, resource_name, quantity):
		print("Not enough resources to transport")
		return false
	
	# 扣除来源国度的资源
	GameState.get_from_warehouse(from_faction, resource_name, quantity)
	
	# 添加到运输队列
	transport_queue.append({
		"from_faction": from_faction,
		"to_faction": to_faction,
		"resource_name": resource_name,
		"quantity": quantity
	})
	
	is_transporting = true
	transport_timer.start()
	
	print("Transport started: ", quantity, " ", resource_name, " from ", from_faction, " to ", to_faction)
	return true

func _on_transport_complete() -> void:
	for transport_data in transport_queue:
		var to_faction = transport_data["to_faction"]
		var resource_name = transport_data["resource_name"]
		var quantity = transport_data["quantity"]
		
		# 添加到目标国度的仓库
		GameState.add_to_warehouse(to_faction, resource_name, quantity)
		print("Transport completed: ", quantity, " ", resource_name, " delivered to ", to_faction)
	
	transport_queue.clear()
	is_transporting = false

func get_transport_progress() -> float:
	if is_transporting and transport_timer.time_left > 0:
		return 1.0 - (transport_timer.time_left / TRANSPORT_TIME)
	return 0.0

func get_queue_info() -> Array:
	return transport_queue.duplicate()
