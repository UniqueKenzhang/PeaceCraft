from fastapi import FastAPI, BackgroundTasks
from pydantic import BaseModel
from typing import Dict
import asyncio
import random

app = FastAPI(title="PeaceCraft - Equilibrium Core v1.1")

# --- 世界观数值底座 ---
class State:
    def __init__(self):
        # 人类领地
        self.human_pop = 100
        self.human_food = 500
        self.human_morale = 100 # 民心：太低会产生内乱
        
        # 魔族领地
        self.demon_pop = 100
        self.demon_meat = 500
        self.demon_fear = 100 # 恐惧：魔族的管理核心
        
        # 战场天平
        self.human_force = 500
        self.demon_force = 500
        self.peace_score = 0 # 和平溢价：救人越多，评分越高
        
        self.is_running = True

world = State()

# --- 补给指令格式 ---
class SupplyOrder(BaseModel):
    target: str # "human" 或 "demon"
    true_ratio: float  # 真武器比例 (0.0 - 1.0)
    funny_ratio: float # 搞怪武器比例 (0.0 - 1.0)
    # fake_ratio 则自动计算为 1 - true - funny

@app.get("/api/state")
async def get_world_state():
    """呈报当前双界万象"""
    return {
        "human": {"pop": int(world.human_pop), "food": int(world.human_food), "morale": world.human_morale},
        "demon": {"pop": int(world.demon_pop), "meat": int(world.demon_meat), "fear": world.demon_fear},
        "battle": {
            "h_force": int(world.human_force),
            "d_force": int(world.demon_force),
            "balance": round(world.human_force / (world.human_force + world.demon_force) * 100, 2),
            "peace_score": world.peace_score
        }
    }

@app.post("/api/supply")
async def handle_supply(order: SupplyOrder):
    """处理大人的物资调拨"""
    fake_ratio = max(0, 1.0 - order.true_ratio - order.funny_ratio)
    
    if order.target == "human":
        # 1. 战力变动：真货加力，假货削弱
        world.human_force += order.true_ratio * 50
        world.human_force -= fake_ratio * 30
        
        # 2. 核心逻辑：搞怪货截留人口
        # 假设每次补给影响 20 名远方士兵，搞怪武器能救下其中一部分
        saved_souls = int(order.funny_ratio * 25)
        world.human_pop += saved_souls
        world.peace_score += saved_souls * 10 # 救人积德
        
        return {"msg": f"人类补给完毕：由于大人的幽默，救下了 {saved_souls} 名逃兵！"}
    
    elif order.target == "demon":
        world.demon_force += order.true_ratio * 50
        world.demon_force -= fake_ratio * 30
        saved_demons = int(order.funny_ratio * 25)
        world.demon_pop += saved_demons
        world.peace_score += saved_demons * 10
        return {"msg": f"魔族补给完毕：又有 {saved_demons} 个恶魔因为好笑而留在了领地。"}

async def internal_engine():
    """大内引擎：全效同步生产与战场自动损耗"""
    while world.is_running:
        # 生产：人口就是生产力
        world.human_food += world.human_pop * 0.2
        world.demon_meat += world.demon_pop * 0.2
        
        # 战场自然损耗：如果没有补给，双方战力会由于持续交战而缓慢下降
        world.human_force = max(100, world.human_force - 2)
        world.demon_force = max(100, world.demon_force - 2)
        
        # 崩坏检查：若平衡打破，和平分暴跌 (未来可加入末日逻辑)
        balance = world.human_force / (world.human_force + world.demon_force)
        if balance < 0.3 or balance > 0.7:
            world.peace_score = max(0, world.peace_score - 50)
            
        await asyncio.sleep(1)

@app.on_event("startup")
async def startup():
    asyncio.create_task(internal_engine())
