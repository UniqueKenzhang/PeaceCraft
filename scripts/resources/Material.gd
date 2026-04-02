extends Resource

class_name HumanMaterial

# A human-readable name for the material
@export var material_name: String = "Generic Material"

# --- Core Parameters from Design Doc ---

# Direct impact on the balance value. Positive for Alliance, Negative for Abyss.
# For the resource itself, we'll treat it as a positive or negative value.
@export var balance_impact: float = 0.0

# Modifies the fatality rate in a battle.
@export var fatality_rate_modifier: float = 0.0

# Modifies the rate at which deserters are produced.
@export var deserter_rate_modifier: float = 0.0

# The risk of being detected when delivering counterfeit gear.
@export var detection_risk: float = 0.0 # Probability from 0.0 to 1.0
