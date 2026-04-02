** 本文档只保留项目整体架构和最新改动内容 **

## 当前任务 (Current Task)

### 🔴 高优先级（核心玩法）

**1. 物流系统架构重构（已完成）**
- ✅ 从实时计算改为事件驱动的连接管理
- ✅ 道路放置时自动建立与建筑的连接关系
- ✅ 建筑放置时自动建立与道路的连接关系
- ✅ 实现高效的连接状态查询
- ✅ 优化性能，减少不必要的路径搜索

**2. 统一财政系统（模块三）**
- 实现统一国库系统（目前只有独立仓储）
- 实现人口税收系统
- 实现建筑维护费系统
- 实现经济破产失败条件（总国库为负且持续亏损）

**3. 逃兵作为劳动力（模块四）**
- 逃兵可以像普通人口一样工作
- 逃兵的特殊加成（深渊逃兵在矿场有加成）
- 逃兵的特殊需求（需要地下酒馆等特殊建筑）

**4. 更复杂的生产链（模块三）**
- 人类：磨坊 → 面粉 → 面包房 → 面包
- 深渊：腐化池 → 菌类肉糜
- 高级恶搞物资的跨国度生产（需要人类和深渊的物资）

### 🟡 中优先级（UI和反馈）

**5. 视觉警告系统（模块一）**
- 实现BalanceState枚举（AbyssDominated, Contested, AllianceDominated）
- 当DominationTimer启动时的视觉警告（闪烁、变色）

**6. 交付界面优化（模块二）**
- 物资的图标和描述
- 数量选择器
- 清晰的库存显示

**7. 科技内容扩展（模块四）**
- 新型恶搞物资科技（战场迪斯科舞厅、便携式充气城堡等）
- 效率提升科技
- 特殊建筑科技（满足逃兵特殊需求的建筑）

### 🟢 低优先级（完善体验）

**8. 人口系统完善**
- 人类：教堂、酒馆等建筑
- 深渊：拷问室、献祭坑等建筑

**9. 经济细节**
- 财政报表UI
- 分别列出人类和深渊的收入与支出

---

## 项目整体架构

### 核心模块

#### 模块一：战场与动态平衡系统
- **势力均势**：`balance_value` (-100 to 100) 核心均势值，压制计时器，均势崩溃失败条件
- **大世界意志**：定时触发的指令管理器（每30秒生成新订单），订单超时惩罚机制，假货识破风险

#### 模块二：三色物资与交付系统
- **True Armaments（真货）**：增强势力，高伤亡率，低逃兵率
- **Counterfeit Gear（假货）**：削弱势力，有识破风险
- **Whimsical Subversion（恶搞物资）**：增强势力，低伤亡率，高逃兵率
- **Enhanced Whimsical Subversion（高级恶搞物资）**：更强的恶搞效果

#### 模块三：Anno风格建设与经济系统
- **格子地图系统**：20x12格子网格，世界坐标与格子坐标双向转换，放置预览和高亮反馈
- **双国度系统**：HumanRealm 和 AbyssRealm 两个独立国度，独立仓库，国度切换
- **基础资源**：
  - 人类：Farm（农田）→ Wheat（小麦），Lumberjack（伐木工）→ Wood（木材）
  - 深渊：FungusCave（真菌洞穴）→ Shadow-shroom（暗影菇），SulfurMine（硫磺矿）→ Sulfur（硫磺）
- **战略物资生产**：Armory（兵工厂），Workshop（黑作坊），Lair（巢穴）

#### 模块四：逃兵与文明共振系统
- **逃兵人口管理**：基于物资的 deserter_rate_modifier 产生逃兵，逃兵计数显示
- **科研点数生成**：基于逃兵数量和平衡度，逃兵收容所提供加成
- **科技系统**：高级恶搞物资、生产优化、逃兵收容所

#### 模块五：物流系统（最新重构）
- **事件驱动的连接管理**：道路和建筑放置时自动建立连接关系
- **高效查询**：使用维护的连接数据直接查询，无需重复计算
- **实时更新**：连接状态实时维护，立即反馈

### 关键文件结构

```
scripts/
├── singletons/
│   └── GameState.gd          # 全局游戏状态管理
├── buildings/
│   ├── ProductionBuilding.gd  # 生产建筑基类
│   ├── Road.gd                # 道路建筑
│   └── Warehouse.gd           # 仓库建筑
├── units/
│   └── Worker.gd              # 工人单位
├── managers/
│   ├── BuildingManager.gd     # 建筑放置管理
│   ├── UIManager.gd           # UI状态管理
│   └── TransportManager.gd    # 跨界运输管理
└── GridMap.gd                 # 格子地图和道路网络管理
```

---

## 最新改动：第二十三阶段 - 物流系统架构重构

### 问题分析

**旧实现的问题：**
1. **低效的实时计算**：每次检查连接都要遍历所有格子并重新计算路径
2. **重复计算**：建筑和仓库的位置每次都从 position 重新计算
3. **性能开销大**：时间复杂度 O(格子数 × 道路数)，随着建筑数量增加性能下降
4. **维护困难**：连接逻辑分散在多个地方，难以维护和扩展

### 新架构设计

**核心思想：事件驱动的连接管理**

#### 1. 数据结构改进

**ProductionBuilding.gd 新增：**
```gdscript
var connected_roads: Array = []  # 连接到该建筑的道路列表

func add_connected_road(road: Road) -> void
func remove_connected_road(road: Road) -> void
func update_warehouse_connection() -> void
```

**Road.gd 已有：**
```gdscript
var connected_buildings: Array = []  # 连接到该道路的建筑列表
```

#### 2. 连接建立逻辑

**GridMap.gd 新增函数：**

```gdscript
# 道路放置时检查周围建筑
func _check_nearby_buildings(road: Road, grid_pos: Vector2i) -> void:
	# 检查四个方向
	for offset in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
		var building = get_building_at(grid_pos + offset)
		if building:
			# 建立双向连接
			road.add_connected_building(building)
			building.add_connected_road(road)
			building.update_warehouse_connection()

# 建筑放置时检查周围道路
func _check_nearby_roads(building: Node2D, cell: Vector2i) -> void:
	# 检查四个方向
	for offset in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
		var road = get_road_at(cell + offset)
		if road:
			building.add_connected_road(road)
			road.add_connected_building(building)

# 建筑放置后的处理
func on_building_placed(building: Node2D) -> void:
	# 检查建筑周围的所有格子，建立道路连接
	# 更新建筑的仓库连接状态

# 建筑移除后的处理
func on_building_removed(building: Node2D) -> void:
	# 断开与道路的所有连接
```

**修改的函数：**
- `add_road()`: 添加 `_check_nearby_buildings()` 调用
- `remove_road()`: 断开与建筑的所有连接，更新连接状态

#### 3. 查询优化

**旧实现：**
```gdscript
func is_building_connected_to_warehouse(building: Node2D) -> bool:
	# 遍历建筑所有格子
	# 对每个格子查找附近道路
	# BFS搜索路径
	# 时间复杂度：O(格子数 × 道路数)
```

**新实现：**
```gdscript
func is_building_connected_to_warehouse(building: Node2D) -> bool:
	# 直接使用建筑维护的连接道路
	for road in building.connected_roads:
		if _can_reach_warehouse_from_road(road):
			return true
	return false

func _can_reach_warehouse_from_road(start_road: Road) -> bool:
	# BFS搜索，从道路开始，检查是否连接到仓库
	# 时间复杂度：O(连接数)
```

### 性能对比

**性能提升：**
- 旧方案：O(格子数 × 道路数) 每次查询
- 新方案：O(连接数) 每次查询，连接状态实时维护

**代码质量：**
- ✅ 职责清晰：连接管理集中在特定函数
- ✅ 易于维护：事件驱动，状态一致
- ✅ 易于扩展：可以轻松添加新的连接类型

**用户体验：**
- ✅ 实时反馈：连接状态立即更新
- ✅ 性能更好：减少卡顿
- ✅ 更可靠：避免计算错误

### 实现完成情况

**阶段一：数据结构准备** ✅
- 在 ProductionBuilding 中添加 `connected_roads` 数组和连接管理方法
- 确认 Road 中 `connected_buildings` 数组可用

**阶段二：连接建立逻辑** ✅
- 实现 `_check_nearby_buildings()` 和 `_check_nearby_roads()`
- 修改 `add_road()` 和 `remove_road()` 函数
- 添加 `on_building_placed()` 和 `on_building_removed()` 函数

**阶段三：查询优化** ✅
- 重构 `is_building_connected_to_warehouse()` 函数
- 实现 `_can_reach_warehouse_from_road()` 函数

**阶段四：集成测试** ✅
- 集成到 BuildingManager 和 MainScene
- 测试所有连接建立和断开场景

---

**大内总管：虾总管 敬录**
*最后修订于 2026-03-31*
