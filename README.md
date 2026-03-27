# agent-dev-workflow

分级自治 Agent Team 开发工作流 — 适用于 Claude Code + gstack 的通用开发自动化方案。

一个 `/dev` 命令启动完整流程：需求理解 → 方案设计 → 执行计划 → 并行开发 → 交付上线。

## 核心理念

- **提需求 + 审批关键节点**，其余全部由 Agent Team 自动执行
- **分级自治**：S/M/L 三级，规模越小自动化程度越高，打扰越少
- **质量门禁**：每个规模级别都有 review gate，只是数量和深度不同
- **上下文不丢失**：三文件持久化，`/clear` 后自动恢复

## 前置条件

- [Claude Code](https://claude.ai/code) 已安装
- [gstack](https://github.com/anthropics/gstack) 已安装（提供 `/office-hours`、`/review`、`/ship` 等 skills）
- 项目使用 git 进行版本管理

## 快速开始

### 1. 安装 skill 文件

```bash
git clone <this-repo> /tmp/agent-dev-workflow
cd /tmp/agent-dev-workflow
./install.sh /path/to/your/project
```

或手动复制：

```bash
cp skills/dev/SKILL.md /path/to/your/project/.claude/skills/dev/SKILL.md
cp skills/dev-tune/SKILL.md /path/to/your/project/.claude/skills/dev-tune/SKILL.md
```

### 2. 配置 CLAUDE.md

将 `templates/CLAUDE.md.example` 中的内容合并到你项目的 `CLAUDE.md`。

需要替换的关键配置：
- `<base-branch>` → 你的基准开发分支（如 `dev`、`develop`、`main`）
- LOC 阈值 → 根据项目规模调整
- 质量门禁表 → 根据已安装的 gstack skills 调整

### 3. 配置 AGENTS.md

将 `templates/AGENTS.md.example` 复制为你项目的 `AGENTS.md`。

需要替换的占位符：
- `<your-backend-tech>` → 如 `Python FastAPI + SQLAlchemy`
- `<your-frontend-tech>` → 如 `Next.js + React + Tailwind`
- `<your-test-framework>` → 如 `pytest + Playwright`
- `<your-backend-src>` → 如 `src/backend/`
- `<your-frontend-src>` → 如 `src/frontend/`
- 各种启动/测试命令 → 替换为你项目的实际命令

### 4. 开始使用

```
/dev 给候选人列表加导出 CSV 功能
```

## 5 阶段 Pipeline

```
INTAKE  →  DESIGN  →  PLAN  →  BUILD  →  SHIP
需求理解    方案设计    执行计划   并行开发   交付上线
```

| 阶段 | S 级 | M 级 | L 级 |
|------|------|------|------|
| INTAKE | 自动分级 + 用户确认 | 同 S | 同 S |
| DESIGN | 跳过 | `/office-hours` → 用户选方案 | `/office-hours` → `/plan-ceo-review` → 用户选方案 |
| PLAN | 简单 plan，自动进入 BUILD | plan + `/plan-eng-review` → 用户审批 | 完整 plan + `/autoplan` → 用户审批 |
| BUILD | 1 Agent，`/review` | 2 Agents，`/review` + `/qa` | 3 Agents，全量 review |
| SHIP | `/ship` + `/document-release` | 同 S | 同 S + `/land-and-deploy` + `/canary` |

## S/M/L 分级规则

| 规模 | 判断标准 | 用户审批节点 | Agent 数 |
|------|---------|-------------|---------|
| **S** | bug fix / < 100 LOC / 1-3 文件 / 单层 | approve PR | 1 |
| **M** | 单功能 / 100-500 LOC / 前后端联动 | approve spec + PR | 2 |
| **L** | 多模块 / 500+ LOC / 前后端 + DB + 测试 | approve spec + plan + PR | 3 |

拿不准往大一级分。可用 `/dev -s`、`/dev -m`、`/dev -l` 强制指定。

## 命令一览

| 命令 | 用途 |
|------|------|
| `/dev <需求>` | 完整流程 |
| `/dev plan <需求>` | 仅 DESIGN → PLAN |
| `/dev build` | 仅 BUILD → SHIP（plan 已就绪） |
| `/dev status` | 查看进度 |
| `/dev -s/-m/-l <需求>` | 强制指定规模 |
| `/dev-tune` | 交互式工作流优化 |
| `/dev-tune <问题>` | 直接描述问题 |
| `/dev-tune review` | 回顾执行历史 |

## 集成的 gstack Skills

Pipeline 内自动触发：

| Skill | 阶段 | 触发条件 |
|-------|------|---------|
| `/office-hours` | DESIGN | M/L 级 |
| `/plan-ceo-review` | DESIGN | L 级 |
| `planning-with-files-zh` | PLAN | 所有规模 |
| `/plan-eng-review` | PLAN | M/L 级 |
| `/autoplan` | PLAN | L 级 |
| `/review` | BUILD | 所有 PR |
| `/qa` | BUILD | 有前端变更 |
| `/design-review` | BUILD | 有 UI 变更 |
| `/cso` | BUILD | 涉及安全 |
| `/investigate` | BUILD | 测试失败 |
| `/ship` | SHIP | 用户 approve PR |
| `/document-release` | SHIP | `/ship` 后 |
| `/land-and-deploy` | SHIP | 已配置部署 |
| `/canary` | SHIP | 有 prod URL |

## 目录结构

```
agent-dev-workflow/
├── skills/
│   ├── dev/
│   │   └── SKILL.md          # /dev skill — 核心工作流
│   └── dev-tune/
│       └── SKILL.md          # /dev-tune skill — 工作流优化
├── templates/
│   ├── CLAUDE.md.example      # CLAUDE.md 工作流 section 模板
│   └── AGENTS.md.example      # AGENTS.md 角色定义模板
├── docs/
│   └── design-spec.md         # 设计规格书（参考文档）
├── install.sh                 # 安装脚本
├── .gitignore
└── README.md
```

## 自定义指南

### 添加新的分级信号词

编辑 `.claude/skills/dev/SKILL.md` 的 Stage 1.2 自动分级 section，在强信号/弱信号表格中添加你项目的领域关键词。

### 调整 Agent 角色

编辑 `AGENTS.md`，可以：
- 修改现有角色的职责和约束
- 添加新角色（如 `implementer-mobile`、`devops-agent`）
- 在 SKILL.md 的 Stage 4.2 中更新对应的编排规则

### 调整 Quality Gate

编辑 SKILL.md 的 Stage 4.4 和 CLAUDE.md 的质量门禁表，添加或移除 review skills。

### 使用 /dev-tune 持续优化

遇到工作流问题时，运行 `/dev-tune` 进入交互式诊断，它会引导你定位问题并生成修改方案。

## 设计文档

完整的设计规格书见 `docs/design-spec.md`，包含：
- 核心架构设计
- 分级判断逻辑
- 各阶段详细设计
- 上下文连续性方案
- 完整生命周期示例（S/M/L 各一个）

## License

MIT
