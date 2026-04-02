# 模块一：战场与动态平衡系统 (Battlefield & Dynamic Balance System)

这是游戏的核心裁决机制，负责模拟两大阵营的对抗，并根据玩家行为做出反应。

## 1. 核心任务与目标

- **模拟战场**：抽象化模拟“联盟（人类）”与“深渊（魔族）”两大阵营的对抗。
- **动态反馈**：根据玩家交付的“三色物资”实时调整战场局势。
- **胜负裁决**：判定“均势崩溃”这一核心失败条件。
- **驱动玩家行为**：通过发布“大世界征集令”来引导玩家的生产和策略。

---

## 2. 功能拆解与实现方案

### 任务 1.1：势力均势模块

- **数据模型**：
    - `BalanceValue` (浮点数, 范围 -100 to 100): 核心均势值。
        - `-100`: 深渊完全压制联盟。
        - `0`: 绝对均势。
        - `100`: 联盟完全压制深渊。
    - `BalanceState` (枚举: `AbyssDominated`, `Contested`, `AllianceDominated`): 根据 `BalanceValue` 划分的战场状态。
    - `DominationTimer` (计时器): 当 `BalanceState` 进入 `AbyssDominated` 或 `AllianceDominated` 状态时开始计时。

- **UI 设计**：
    - 在主界面顶部或一个专门的“战争”界面中，放置一个视觉化的天平或势力条。
    - 该UI需实时反映 `BalanceValue` 的变化。
    - 当计时器 `DominationTimer` 启动时，需有明显的视觉警告（如闪烁、变色）。

- **失败逻辑**：
    - 设定一个 `DominationThreshold` (例如 75) 和 `CollapseTimeLimit` (例如 游戏内的3个周期)。
    - 当 `abs(BalanceValue)` > `DominationThreshold` 状态持续时间超过 `CollapseTimeLimit` 时，游戏判定为“均势崩溃”，触发失败结局。

### 任务 1.2：大世界意志与指令系统

- **事件驱动框架**：
    - 基于游戏内的时间系统，创建一个定时触发的“指令管理器”。
    - 例如，每隔一个游戏周期（或一个随机范围内的时间），该管理器将生成一个新的“征集令”。

- **征集令 (Order) 数据结构**：
    - `OrderID` (唯一ID)
    - `TargetFaction` (枚举: `Alliance` 或 `Abyss`): 本次物资的目标势力。
    - `RequiredMaterials` (列表): 一个包含多种物资需求的列表，每个元素包含：
        - `MaterialType` (枚举: `TrueArmaments`, `CounterfeitGear`, `WhimsicalSubversion`)
        - `Quantity` (整数)
    - `TimeLimit` (游戏内时间戳): 订单的截止日期。
    - `Status` (枚举: `Active`, `Fulfilled`, `Failed`)

- **惩罚机制**：
    - **交付失败**：若到 `TimeLimit` 仍未满足 `RequiredMaterials` 的要求，根据未完成的比例施加惩罚（例如，扣除大量金钱，降低全国幸福度，甚至直接小幅推动战场天平向不利方向发展）。
    - **风险惩罚**：与“假货”交付系统联动，当玩家交付假货时，有一定几率被“大世界意志”识破，立即触发一次性的严厉惩罚。

---
## 3. 关联模块接口

- **输入**：
    - `(来自模块二)` 接收玩家交付的物资类型、数量和目标势力。
- **输出**：
    - `(至模块二)` 影响战场结算，特别是“阵亡率”和“逃兵”产出率。
    - `(至模块四)` 将结算产生的“逃兵”数量和阵营归属传递给“逃兵人口系统”。
    - `(至UI系统)` 提供 `BalanceValue` 和 `DominationTimer` 等数据用于界面展示。
