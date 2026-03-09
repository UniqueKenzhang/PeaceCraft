from fastapi import FastAPI, BackgroundTasks
from pydantic import BaseModel
import asyncio
import time

app = FastAPI(title="天平之祭 - 和平序章 API")

# 龙王大人的游戏世界状态
class WorldState:
    def __init__(self):
        self.human = {"pop": 100, "food": 500, "steel": 100, "power": 50}
        self.demon = {"pop": 100, "meat": 500, "bone": 100, "power": 50}
        self.battlefield = {"human_force": 50, "demon_force": 50, "balance": 50}
        self.running = True

state = WorldState()

@app.get("/state")
async def get_state():
    """获取三个场景的实时状态"""
    return {
        "human": state.human,
        "demon": state.demon,
        "battlefield": state.battlefield
    }

@app.post("/supply")
async def send_supply(target: str, item_type: str, ratio: dict):
    """
    龙王大人发起的物资填装补给
    ratio: {"true": 0.3, "fake": 0.4, "funny": 0.3}
    """
    # 逻辑：根据比例调整 battlefield 的战力和逃兵转化
    if target == "human":
        # 增加战力（真货），减少战力（假货），转化人口（搞怪货）
        state.battlefield["human_force"] += ratio["true"] * 10
        state.battlefield["human_force"] -= ratio["fake"] * 5
        # 核心逻辑：搞怪货直接救人回老家
        saved_pop = int(ratio["funny"] * 20)
        state.human["pop"] += saved_pop
        return {"msg": f"补给抵达！救下逃兵 {saved_pop} 人"}
    return {"msg": "补给成功"}

async def game_loop():
    """全效同步逻辑：每秒钟都在产出资源"""
    while state.running:
        # 人类产出：人口越多，粮食越多
        state.human["food"] += state.human["pop"] * 0.1
        # 魔族产出：人口越多，腐肉越多
        state.demon["meat"] += state.demon["pop"] * 0.1
        
        # 动态平衡：如果不干预，战力会产生随机波动
        state.battlefield["balance"] = (state.battlefield["human_force"] / (state.battlefield["human_force"] + state.battlefield["demon_force"])) * 100
        
        await asyncio.sleep(1)

@app.on_event("startup")
async def startup_event():
    asyncio.create_task(game_loop())

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
