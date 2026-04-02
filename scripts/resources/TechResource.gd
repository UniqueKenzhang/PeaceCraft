extends Resource

class_name TechResource

# 科技名称
@export var tech_name: String = "未命名科技"

# 科技描述
@export var description: String = ""

# 解锁所需的科研点数
@export var research_cost: float = 0.0

# 是否已解锁
@export var is_unlocked: bool = false

# 科技效果类型枚举
enum EffectType {
	UNLOCK_NEW_MATERIAL,  # 解锁新物资
	PRODUCTION_EFFICIENCY, # 生产效率提升
	UNLOCK_NEW_BUILDING,  # 解锁新建筑
	SPECIAL_EFFECT        # 特殊效果
}

# 科技效果类型
@export var effect_type: EffectType = EffectType.UNLOCK_NEW_MATERIAL

# 效果参数（根据类型不同而不同）
# 对于 UNLOCK_NEW_MATERIAL: 新物资名称
# 对于 PRODUCTION_EFFICIENCY: 字典 {建筑类型: 效率加成}
# 对于 UNLOCK_NEW_BUILDING: 新建筑场景路径
# 对于 SPECIAL_EFFECT: 特殊效果标识符
@export var effect_parameters: Dictionary = {}