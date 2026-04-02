extends Node2D

class_name NeedsProvider

enum NeedType { FOOD, SHELTER, TOOLS, LUXURY }

@export var need_type: NeedType = NeedType.FOOD
@export var faction: String = "Human"
@export var capacity: int = 10 # 每个建筑可以满足多少人口的需求

var timer: Timer
const SATISFY_INTERVAL = 2.0 # 每2秒满足一次需求

func _ready() -> void:
	timer = Timer.new()
	timer.wait_time = SATISFY_INTERVAL
	timer.one_shot = false
	timer.timeout.connect(_on_satisfy_timeout)
	add_child(timer)
	timer.start()

func _on_satisfy_timeout() -> void:
	var need_name = _get_need_name()
	GameState.satisfy_population_need(faction, "Worker", need_name)
	GameState.satisfy_population_need(faction, "Artisan", need_name)
	GameState.satisfy_population_need(faction, "Noble", need_name)

func _get_need_name() -> String:
	match need_type:
		NeedType.FOOD:
			return "Food"
		NeedType.SHELTER:
			return "Shelter"
		NeedType.TOOLS:
			return "Tools"
		NeedType.LUXURY:
			return "Luxury"
	return ""
