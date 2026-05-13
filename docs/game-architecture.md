# 星际探索 SLG — 技术架构设计文档

## 1. 概述

本文档定义游戏的技术架构：一个 **LLM 驱动的 Agent** 作为玩家与游戏世界的交互中介，玩家通过**自然语言对话**下达指令，Agent 理解意图后调用游戏 API 执行操作，游戏状态通过 **2D 俯视星图**实时可视化。

**核心交互范式**：

- 玩家 ↔ Agent：自然语言对话
- Agent ↔ Game Server：结构化工具调用（JSON）
- Game Server → 前端：状态推送（WebSocket / SSE）
- 前端：2D 星图展示 + 对话面板

---

## 2. 系统架构

```
┌─────────────────────────────────────────────────────────────────────┐
│                         玩家浏览器                                   │
│  ┌──────────────────┐    ┌──────────────────┐                      │
│  │   对话输入框      │    │   2D 星图画布     │                      │
│  │   "派船去采矿"    │    │   飞船、轨道、星球   │                      │
│  └────────┬─────────┘    └────────▲─────────┘                      │
│           │                       │                                 │
│           │ WebSocket/SSE         │ 状态推送                         │
│           │                       │                                 │
│  ┌────────▼───────────────────────┴─────────┐                      │
│  │           Game Server (apps/server)        │  ← 权威状态源        │
│  │  - 星系状态管理                             │                      │
│  │  - 飞船行为模拟（定时器驱动）                │                      │
│  │  - 资源产出计算                             │                      │
│  │  - 操作验证与执行                           │                      │
│  └──────────────────┬────────────────────────┘                      │
│                     │                                               │
│                     │ HTTP API (get_state / execute_action)        │
│                     │                                               │
│  ┌──────────────────▼────────────────────────┐                      │
│  │        Agent Core (apps/llmagent)          │                      │
│  │                                            │                      │
│  │  ┌─────────┐    ┌─────────┐    ┌────────┐ │                      │
│  │  │Perceive │───►│ Decide  │───►│  Act   │ │                      │
│  │  │读状态   │    │ LLM推理 │    │执行操作│ │                      │
│  │  └─────────┘    └─────────┘    └────────┘ │                      │
│  │                                            │                      │
│  │  Tools: dispatch_ship, build_ship,         │                      │
│  │         upgrade_reactor, get_status...     │                      │
│  └────────────────────────────────────────────┘                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 3. 模块划分

| 模块              | 路径                     | 职责                             | 技术栈               |
| ----------------- | ------------------------ | -------------------------------- | -------------------- |
| **Game Server**   | `apps/server`            | 游戏状态管理、定时模拟、操作验证 | Python               |
| **Agent Core**    | `apps/llmagent`          | LLM 交互、工具调用、意图理解     | Python               |
| **Frontend**      | `apps/landing`           | 2D 星图渲染、对话 UI、状态展示   | Next.js / TypeScript |
| **Shared Types**  | `packages/types`         | 前后端共享的 TypeScript 类型     | TypeScript           |
| **Shared Python** | `python-packages/shared` | Python 侧共享模型和工具          | Python               |

---

## 4. Agent 的 Perceive-Decide-Act 循环

### 4.1 Perceive — 状态感知

每次玩家发送消息时，Agent 先从 Game Server 拉取**当前状态快照**，并编码为自然语言上下文。

**状态快照示例**：

```json
{
  "timestamp": "2026-05-12T10:30:00Z",
  "player_id": "player_001",
  "base": {
    "energy": 145,
    "energy_capacity": 500,
    "energy_production_per_minute": 12,
    "mineral": 30,
    "mineral_capacity": 200,
    "reactor_level": 1,
    "dock_capacity": 3,
    "dock_occupied": 1
  },
  "ships": [
    {
      "id": "ship_01",
      "name": "探矿者一号",
      "status": "docked",
      "cargo_capacity": 50,
      "cargo_current": 0,
      "energy_tank": 100,
      "energy_current": 100
    }
  ],
  "celestial_bodies": [
    {
      "id": "asteroid_belt_1",
      "type": "asteroid",
      "name": "近地小行星带",
      "distance": 2,
      "richness": 0.8,
      "travel_time_one_way_seconds": 30
    },
    {
      "id": "planet_surface",
      "type": "planet_surface",
      "name": "星球地表",
      "distance": 0,
      "richness": 1.2,
      "travel_time_one_way_seconds": 0
    }
  ]
}
```

**编码为自然语言（注入 LLM 上下文）**：

```
你是星际基地指挥官的 AI 助理。当前状态：

【基地】
- 能源：145 / 500（每分钟产出 12）
- 矿物：30 / 200
- 反应堆等级：1
- 船坞：1 / 3（已占用 / 容量）

【飞船】
- 探矿者一号（ship_01）：停靠在基地，货舱空置，能源满

【可采集点】
- 近地小行星带（距离 2，单程 30 秒，富饶度 0.8）
- 星球地表（距离 0，无需航行，富饶度 1.2）

请根据玩家指令，选择适当的工具执行操作。如果指令存在风险，
请拒绝并说明原因。
```

### 4.2 Decide — LLM 决策

通过 **OpenAI Function Calling（Tool Use）**实现。

**可用工具定义**：

```json
{
  "tools": [
    {
      "type": "function",
      "function": {
        "name": "dispatch_ship",
        "description": "派遣指定飞船前往目标采集点执行采矿任务。需要消耗能源用于航行。",
        "parameters": {
          "type": "object",
          "properties": {
            "ship_id": {
              "type": "string",
              "description": "飞船唯一标识"
            },
            "target_id": {
              "type": "string",
              "description": "目标采集点标识"
            },
            "mission_type": {
              "type": "string",
              "enum": ["mining"],
              "description": "任务类型"
            }
          },
          "required": ["ship_id", "target_id", "mission_type"]
        }
      }
    },
    {
      "type": "function",
      "function": {
        "name": "build_ship",
        "description": "消耗矿物建造新飞船。每艘船需要固定数量的矿物和少量能源。",
        "parameters": {
          "type": "object",
          "properties": {
            "count": {
              "type": "integer",
              "description": "建造数量",
              "default": 1
            }
          }
        }
      }
    },
    {
      "type": "function",
      "function": {
        "name": "upgrade_reactor",
        "description": "升级反应堆，提升能源产出速率。消耗矿物。"
      }
    },
    {
      "type": "function",
      "function": {
        "name": "expand_dock",
        "description": "扩建船坞，提升飞船容量上限。消耗矿物。"
      }
    },
    {
      "type": "function",
      "function": {
        "name": "get_status",
        "description": "获取基地和飞船的详细状态信息。"
      }
    },
    {
      "type": "function",
      "function": {
        "name": "respond_to_player",
        "description": "当不需要执行任何游戏操作时，直接向玩家回复文本消息。",
        "parameters": {
          "type": "object",
          "properties": {
            "message": {
              "type": "string",
              "description": "回复给玩家的消息内容"
            }
          },
          "required": ["message"]
        }
      }
    }
  ]
}
```

**LLM 输出示例 — 执行操作**：

```json
{
  "role": "assistant",
  "content": null,
  "tool_calls": [
    {
      "id": "call_abc123",
      "type": "function",
      "function": {
        "name": "dispatch_ship",
        "arguments": "{\"ship_id\":\"ship_01\",\"target_id\":\"asteroid_belt_1\",\"mission_type\":\"mining\"}"
      }
    }
  ]
}
```

**LLM 输出示例 — 拒绝操作**：

```json
{
  "role": "assistant",
  "content": "目前只有 1 艘飞船，且它已经在执行任务了。请先等待它返航，或者使用现有矿物（30）建造新飞船（每艘需要 50 矿物）。",
  "tool_calls": []
}
```

### 4.3 Act — 执行与反馈

Agent 检测到工具调用后的执行流程：

```
1. 解析 tool_calls → 提取函数名和参数
2. 调用 Game Server HTTP API
3. Server 验证合法性：
   - 能源是否足够？
   - 飞船状态是否允许？
   - 目标是否存在？
4. Server 执行操作，更新持久化状态
5. Server 返回执行结果（成功 / 失败 + 原因）
6. Agent 将结果翻译为自然语言回复玩家
```

**支持多工具并行调用**：当玩家说"造一艘船然后派它去采矿"时，Agent 可以返回多个 tool_calls，按顺序执行。

---

## 5. Agent 拒绝策略

Agent 有权拒绝玩家的危险或非法指令。

### 5.1 拒绝场景

| 场景           | 玩家指令                    | Agent 回应                                                                     |
| -------------- | --------------------------- | ------------------------------------------------------------------------------ |
| **资源不足**   | "造 10 艘船"                | "当前矿物只有 30，造一艘船需要 50 矿物。请先派遣飞船采集更多矿物。"            |
| **状态冲突**   | "让 ship_01 同时去两个地方" | "ship_01 只能执行一个任务。请选择一个目标。"                                   |
| **能源危机**   | "把所有能源用来造船"        | "⚠️ 警告：这将耗尽全部能源，导致反应堆降载。确定要继续吗？"                    |
| **不可达目标** | "派船去银河系中心"          | "当前跃迁引擎尚未研发，无法离开本星系。请先升级科技。"                         |
| **无意义操作** | "让飞船跳舞"                | "我没有找到与"跳舞"相关的游戏操作。你可以派遣飞船采矿、建造新飞船或升级设施。" |

### 5.2 拒绝与确认的边界

| 情况                          | 处理方式           | 示例                                |
| ----------------------------- | ------------------ | ----------------------------------- |
| **非法（资源不足/状态冲突）** | 直接拒绝，说明原因 | "矿物不足，无法建造"                |
| **危险但技术上可行**          | 警告并请求确认     | "这将耗尽能源，确定吗？"            |
| **模糊**                      | 澄清意图           | "你想派哪艘船去哪个目标？"          |
| **无关**                      | 礼貌引导           | "我无法执行这个操作。你可以尝试..." |

---

## 6. Game Server（Python）

### 6.1 职责

- **状态管理**：星系、基地、飞船、采集点的持久化状态
- **定时模拟**：飞船航行倒计时、资源自动产出、采集进度
- **操作验证**：所有 Agent 发起的操作必须经过合法性校验
- **状态推送**：通过 WebSocket / SSE 向前端推送状态更新

### 6.2 核心数据模型

```python
from dataclasses import dataclass, field
from enum import Enum, auto
from datetime import datetime


class ShipStatus(Enum):
    DOCKED = auto()       # 停靠在基地
    TRAVELING_OUT = auto()  # 航行去目标
    LANDING = auto()      # 降落中
    MINING = auto()       # 采集中
    LIFTING = auto()      # 升空中
    TRAVELING_BACK = auto()  # 返航中


@dataclass
class Ship:
    id: str
    name: str
    status: ShipStatus = ShipStatus.DOCKED
    cargo_capacity: int = 50
    cargo_current: int = 0
    energy_tank: int = 100
    energy_current: int = 100
    # 任务相关
    target_id: str | None = None
    mission_start_time: datetime | None = None
    mission_complete_time: datetime | None = None


@dataclass
class Base:
    energy: float = 100.0
    energy_capacity: float = 500.0
    energy_production_per_second: float = 0.2
    mineral: float = 0.0
    mineral_capacity: float = 200.0
    reactor_level: int = 1
    dock_capacity: int = 3
    ships: list[Ship] = field(default_factory=list)


@dataclass
class CelestialBody:
    id: str
    name: str
    type: str  # "asteroid", "planet_surface", "gas_cloud"
    distance: float  # 距离基地的距离（天文单位或抽象单位）
    richness: float  # 富饶度倍率
    travel_time_one_way_seconds: float


@dataclass
class Galaxy:
    player_id: str
    base: Base
    bodies: list[CelestialBody] = field(default_factory=list)
```

### 6.3 定时模拟循环

Server 以固定频率（如每秒）推进游戏时间：

```python
def tick(self, delta_seconds: float):
    """推进游戏时间，更新所有状态。"""
    # 1. 能源自动产出
    self.base.energy = min(
        self.base.energy + self.base.energy_production_per_second * delta_seconds,
        self.base.energy_capacity
    )

    # 2. 更新所有飞船状态
    now = datetime.now()
    for ship in self.base.ships:
        if ship.status == ShipStatus.TRAVELING_OUT and now >= ship.mission_complete_time:
            ship.status = ShipStatus.LANDING
            ship.mission_complete_time = now + timedelta(seconds=LANDING_DURATION)

        elif ship.status == ShipStatus.LANDING and now >= ship.mission_complete_time:
            ship.status = ShipStatus.MINING
            # 计算采集时长...

        elif ship.status == ShipStatus.MINING and now >= ship.mission_complete_time:
            ship.status = ShipStatus.LIFTING
            # 装载矿物...

        elif ship.status == ShipStatus.LIFTING and now >= ship.mission_complete_time:
            ship.status = ShipStatus.TRAVELING_BACK
            # 设置返航完成时间...

        elif ship.status == ShipStatus.TRAVELING_BACK and now >= ship.mission_complete_time:
            ship.status = ShipStatus.DOCKED
            # 卸载矿物到基地...
```

### 6.4 API 设计

```python
# HTTP Endpoints (REST)

GET  /api/v1/galaxy/{player_id}/state
     → 返回当前完整状态快照（供 Agent Perceive 使用）

POST /api/v1/galaxy/{player_id}/action
     Body: { "action": "dispatch_ship", "params": { ... } }
     → 执行操作，返回 { "success": bool, "message": str, "new_state": GalaxyState }

# WebSocket (状态推送)

WS   /ws/v1/galaxy/{player_id}
     → 连接后 Server 主动推送状态更新（飞船状态变化、资源变化等）
```

---

## 7. 前端：2D 星图 + 对话界面

### 7.1 布局

```
┌────────────────────────────────────────────────────────────┐
│                                                            │
│                    2D 星图画布（主区域）                      │
│                                                            │
│    ☉ 恒星                                                    │
│                                                            │
│         ┌──────┐     ● 小行星带                              │
│         │ 🏠基地 │─────╱                                     │
│         └──┬───┘    /                                       │
│            │       /  ◄── ship_01 航行中 (▸)                │
│            │      /                                         │
│            │     /                                          │
│            └────● 星球地表                                   │
│                                                            │
│  ┌────────────────────────────────────────────────────┐   │
│  │ 💬 已派遣 ship_01 前往小行星带采矿...                 │   │
│  │                                                      │   │
│  │ [ship_01] 点击弹出快捷菜单                            │   │
│  │   ├─ 派遣到小行星带                                   │   │
│  │   ├─ 派遣到星球地表                                   │   │
│  │   └─ 查看详情                                         │   │
│  └────────────────────────────────────────────────────┘   │
│                                                            │
│  ┌────────────────────────────────────────────────────┐   │
│  │ 输入消息...  [发送]                                   │   │
│  └────────────────────────────────────────────────────┘   │
└────────────────────────────────────────────────────────────┘
```

### 7.2 星图交互

| 元素            | 交互 | 行为                                 |
| --------------- | ---- | ------------------------------------ |
| **星球/小行星** | 悬停 | 显示名称、距离、富饶度               |
| **飞船图标**    | 点击 | 弹出快捷菜单（派遣/查看详情）        |
| **基地**        | 点击 | 显示基地面板（能源、矿物、船坞状态） |
| **空白处**      | 拖拽 | 平移视角                             |
| **滚轮**        | 缩放 | 放大/缩小星图                        |

### 7.3 快捷操作菜单

点击飞船后弹出的菜单项会**预填充对话输入框**：

```
玩家点击 ship_01 → 菜单选择"派遣到小行星带"
→ 输入框自动填入："派遣 ship_01 前往近地小行星带采矿"
→ 玩家按发送或回车确认
→ Agent 处理并执行
```

这样既保留了"对话为核心"的交互模式，又提供了快捷操作的便利。

### 7.4 状态同步

前端通过 **WebSocket** 与 Game Server 保持长连接：

```
WebSocket 事件：
- "state_update" → 完整状态快照（定期推送）
- "ship_status_changed" → { ship_id, old_status, new_status }
- "resource_changed" → { resource_type, old_value, new_value }
- "action_result" → { success, message, action }
```

---

## 8. 离线收益

玩家离线期间，Game Server 继续运行：

- **能源**：反应堆持续产出，直到达到容量上限
- **飞船**：在途任务正常执行，返航后矿物自动存入基地
- **状态更新**：玩家重新登录时，Server 计算离线期间的所有变化，一次性推送

**离线计算示例**：

```python
def compute_offline_progress(player_id: str, last_online: datetime) -> StateDelta:
    """计算玩家离线期间的所有状态变化。"""
    galaxy = load_galaxy(player_id)
    now = datetime.now()
    elapsed = (now - last_online).total_seconds()

    # 快速推进 elapsed 秒的游戏时间
    for _ in range(int(elapsed)):
        galaxy.tick(1.0)

    return compute_delta(galaxy, last_online)
```

---

## 9. 多玩家互动

### 9.1 异步观光模式

- 玩家可以在星图上**查看其他玩家的星系状态**（只读）
- 无直接交互（战斗、贸易、聊天）
- 提供排行榜或光点地图，显示各玩家的发展程度

### 9.2 实现方式

```python
GET /api/v1/galaxy/explore
    → 返回附近玩家的星系概览（匿名或实名，仅显示发展水平）

GET /api/v1/galaxy/{player_id}/view
    → 查看指定玩家的完整星系（需对方设置为公开）
```

---

## 10. 技术栈确认

| 层次               | 技术                              | 理由                                               |
| ------------------ | --------------------------------- | -------------------------------------------------- |
| **Game Server**    | Python + FastAPI                  | 团队已有 Python 基础；FastAPI 原生支持 WebSocket   |
| **Agent Core**     | Python + OpenAI SDK               | 复用现有 `llmagent`；支持 Function Calling         |
| **前端**           | Next.js + TypeScript + Canvas API | 团队已有 `landing` 项目；Canvas 适合自定义 2D 星图 |
| **数据持久化**     | SQLite / PostgreSQL               | MVP 用 SQLite；规模扩大后迁移到 PostgreSQL         |
| **实时通信**       | WebSocket                         | 状态推送；Server → 前端                            |
| **Agent → Server** | HTTP REST                         | 请求-响应模式，无需长连接                          |

---

## 11. 开发阶段规划

| 阶段                      | 目标                                              | 涉及模块                 |
| ------------------------- | ------------------------------------------------- | ------------------------ |
| **P0：Agent 工具化**      | 在 `llmagent` 中增加 OpenAI Function Calling 支持 | `llmagent/llm/client.py` |
| **P1：Game Server 骨架**  | 实现状态模型 + 定时 tick + 基础 API               | `apps/server`            |
| **P2：Agent-Server 联调** | Agent 能通过工具调用操作游戏状态                  | `llmagent` ↔ `server`    |
| **P3：前端星图**          | 2D 星图渲染 + 飞船轨道动画                        | `apps/landing`           |
| **P4：前端对话**          | 对话面板 + 快捷菜单 + WebSocket 连接              | `apps/landing`           |
| **P5：多玩家**            | 星系探索 + 排行榜                                 | `apps/server`            |

---

## 12. 风险与待决策事项

| 问题           | 现状                                                | 备注                                                |
| -------------- | --------------------------------------------------- | --------------------------------------------------- |
| **LLM 延迟**   | 每次玩家发消息都需要调用 LLM（~1-3 秒）             | 可接受，但需有 loading 状态；后续可引入本地意图缓存 |
| **状态一致性** | Agent 读取状态 → LLM 决策 → Server 执行，存在时间差 | Server 执行时再次验证条件，拒绝过期的操作           |
| **并发**       | 乐观锁已实现（version 列 + StaleDataError 检测）    | 高并发场景需加 mapper version_id_col 或迁移到 Redis |
| **LLM 成本**   | 每轮对话都要调用 API                                | MVP 阶段可控；后续可考虑本地小模型处理简单意图      |

---

## 13. 接口边界（已实现）

Server 严格执行三层边界：

```
┌─────────────────────────────────────────┐
│  rpc/          ← 外部可见（HTTP handlers）│
│  只能 import server.state                │
├─────────────────────────────────────────┤
│  state/        ← 业务逻辑层              │
│  只能 import server.persistence          │
├─────────────────────────────────────────┤
│  persistence/  ← 持久化层（内部）        │
│  不暴露给 rpc/                            │
└─────────────────────────────────────────┘
```

**当前公开接口**（`server.state.__init__` 导出）：

- `create_new_player(db, user_id, ...)` → `PlayerState`
- `get_player_snapshot(db, user_id)` → `dict | None`
- `consume_resources(db, user_id, energy_cost, mineral_cost)` → `PlayerState`
- `player_exists(db, user_id)` → `bool`
- `InsufficientResourcesError`, `PlayerAlreadyExistsError`

**内部不暴露**：

- `persistence.crud.create_player` — 被 `state.service` 封装
- `persistence.crud.get_player` — 被 `state.service` 封装
- `persistence.models.PlayerState.compute_now()` — 内部计算逻辑

---

## 14. 日志

Server 使用 **structlog** 输出结构化 JSON 日志。

**每条 RPC 请求至少包含：**

- `rpc.create_player_requested` / `rpc.create_player_success` / `rpc.create_player_conflict`
- `rpc.consume_requested` / `rpc.consume_success` / `rpc.consume_insufficient`

**State 层日志：**

- `state.create_new_player` — 创建玩家
- `state.consume_resources` — 资源消耗

**日志格式示例：**

```json
{
  "event": "rpc.create_player_success",
  "user_id": "alice",
  "energy": 100,
  "timestamp": "2026-05-12T10:00:00"
}
```

---

## 15. 当前实现状态（MVP 完成）

| 模块                     | 状态 | 说明                                         |
| ------------------------ | ---- | -------------------------------------------- |
| **Server 资源管理**      | ✅   | 创建/读取/消耗，整数秒增长，容量上限         |
| **Server 日志**          | ✅   | structlog JSON 结构化日志                    |
| **Server 接口边界**      | ✅   | rpc → state → persistence 三层隔离           |
| **Agent Tool Use**       | ✅   | OpenAI Function Calling，3 个工具            |
| **Agent Game Client**    | ✅   | httpx async client 连接 server               |
| **前端 ChatPanel**       | ✅   | 自然语言输入，关键词路由到 API               |
| **前端 ResourceDisplay** | ✅   | 资源展示 + 自动刷新                          |
| **单元测试**             | ✅   | Server 12 个，Agent 13 个                    |
| **Eval 测试**            | ✅   | 4 个场景 + 2 个性能基准（需运行 server）     |
| **分级文档**             | ✅   | api-reference.md, agent-tools.md, testing.md |
