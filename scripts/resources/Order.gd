extends Resource

class_name Order

# The faction requesting the materials ("Human" or "Abyss")
@export var target_faction: String

# A dictionary where keys are material names (String) and values are quantities (int)
# Example: {"True Armaments": 10, "Whimsical Subversion": 5}
@export var required_materials: Dictionary

# The in-game time (e.g., timestamp or seconds from now) by which the order must be fulfilled
@export var time_limit: float
