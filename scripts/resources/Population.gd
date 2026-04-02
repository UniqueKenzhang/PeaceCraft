extends Resource
class_name Population

enum SocialClass { WORKER, ARTISAN, NOBLE }

var class_type: SocialClass = SocialClass.WORKER
var count: int = 0
var happiness: float = 100.0
var needs_satisfied: Dictionary = {}

const HAPPINESS_DECAY_RATE = 0.5 # 每秒幸福度衰减
const HAPPINESS_GAIN_RATE = 2.0 # 需求满足时幸福度增长
const HAPPINESS_THRESHOLD = 30.0 # 幸福度低于此值时开始流失人口
const POPULATION_LOSS_RATE = 0.1 # 每秒人口流失率（当幸福度低于阈值时）

func _init(init_class_type: SocialClass, initial_count: int = 0) -> void:
	class_type = init_class_type
	count = initial_count
	happiness = 100.0
	needs_satisfied = {}

func update(delta: float) -> void:
	if count <= 0:
		return
	
	# 幸福度衰减
	if not _all_needs_satisfied():
		happiness -= HAPPINESS_DECAY_RATE * delta
	else:
		happiness += HAPPINESS_GAIN_RATE * delta
	
	happiness = clamp(happiness, 0.0, 100.0)
	
	# 人口流失
	if happiness < HAPPINESS_THRESHOLD:
		var loss_amount = int(count * POPULATION_LOSS_RATE * delta)
		if loss_amount > 0:
			count = max(0, count - loss_amount)
			print("Population loss: ", loss_amount, " ", _get_class_name(), " due to low happiness")

func satisfy_need(need_name: String) -> void:
	needs_satisfied[need_name] = true

func reset_needs() -> void:
	needs_satisfied.clear()

func _all_needs_satisfied() -> bool:
	if needs_satisfied.size() == 0:
		return false
	
	for value in needs_satisfied.values():
		if not value:
			return false
	return true

func _get_class_name() -> String:
	match class_type:
		SocialClass.WORKER:
			return "Worker"
		SocialClass.ARTISAN:
			return "Artisan"
		SocialClass.NOBLE:
			return "Noble"
	return "Unknown"

func get_required_needs() -> Array:
	match class_type:
		SocialClass.WORKER:
			return ["Food", "Shelter"]
		SocialClass.ARTISAN:
			return ["Food", "Shelter", "Tools"]
		SocialClass.NOBLE:
			return ["Food", "Shelter", "Luxury"]
	return []

func add_population(amount: int) -> void:
	count += amount
	if count < 0:
		count = 0

func get_production_efficiency() -> float:
	return happiness / 100.0

func is_unhappy() -> bool:
	return happiness < HAPPINESS_THRESHOLD
