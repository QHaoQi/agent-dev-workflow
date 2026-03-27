# 分级自治 Agent Team 开发工作流 — 设计规格书

> **版本**: v1.0
> **日期**: 2026-03-27
> **状态**: Approved
> **作者**: Main Agent (Claude Code)
> **审批**: 项目负责人

---

## 1. 概述

### 1.1 目标

让项目负责人只需 **提需求 + 在关键节点审批**，其余 brainstorm、plan、code、test、review、ship 全部由 Agent Team 自动执行。

### 1.2 解决的核心痛点

| # | 痛点 | 现状 | 目标状态 |
|---|------|------|---------|
| 1 | **质量失控** | 70 commit 直推 main，无 review | 强制 feature branch + PR + 自动 review |
| 2 | **上下文丢失** | 每次新对话重新解释项目背景 | planning-with-files-zh 三文件持久化 + `/clear` 后自动恢复 |
| 3 | **编排复杂** | 手动建 team / task / 派 agent | 一个 `/dev` 命令启动全流程 |

### 1.3 设计原则

| 原则 | 说明 |
|------|------|
| **保守分级** | 拿不准往大一级分，用户可覆盖降级 |
| **最小打扰** | 只在关键决策点请求审批，不做无意义确认 |
| **质量门禁** | 每个规模级别都有 review gate，只是数量和深度不同 |
| **文件即记忆** | 所有上下文持久化到文件，跨对话可恢复 |

### 1.4 适用范围

本规格书适用于 ai-hr-recruitment 项目的所有开发工作，包括 bug fix、功能迭代、模块开发。不涉及运维、数据库迁移等非开发类任务。

---

## 2. 核心架构：5 阶段 Pipeline

```
INTAKE  →  DESIGN  →  PLAN  →  BUILD  →  SHIP
需求理解    方案设计    执行计划   并行开发   交付上线
```

每个阶段有明确的 **输入**、**输出**、**审批点**、**跳过条件**。Pipeline 是单向流动的，不支持阶段回退（如果 BUILD 阶段发现设计问题，应新建一个 INTAKE 重新走流程）。

---

## 3. 分级规则

### 3.1 三级分类

| 规模 | 判断标准 | 用户参与节点 | 预计 Agent 数量 |
|------|---------|-------------|----------------|
| **S (小)** | bug fix / < 100 LOC / 1-3 文件 / 单层（纯前端或纯后端） | 仅 approve PR | 1 |
| **M (中)** | 单功能 / 100-500 LOC / 4-8 文件 / 前后端联动 | approve spec + approve PR | 2 |
| **L (大)** | 多模块 / 500+ LOC / 8+ 文件 / 前后端 + DB + 测试 + 文档 | approve spec + approve plan + approve PR | 3 |

### 3.2 自动判断逻辑

自动判断基于用户需求描述中的关键词和范围信号，按以下优先级从高到低匹配：

**强信号（直接决定级别）：**

| 信号 | 判定 |
|------|------|
| 描述包含"修复" / "fix" / "bug" / "hotfix" | S |
| 涉及多个新 DB 表（2+） | L |
| 描述包含"模块" / "系统" / "Phase" / "引擎" | L |

**弱信号（组合判断）：**

| 信号 | 倾向 |
|------|------|
| 描述包含"加一个" / "新增" / "实现 XX 功能" | M |
| 涉及 1 个新 DB 表 | 至少 M |
| 同时涉及前端和后端 | 至少 M |
| 涉及新 API 端点 + 新页面 | 至少 M |
| 涉及 Prompt 模板变更 | 至少 M |

**冲突处理规则：** 当强信号和弱信号冲突时，强信号优先。当多个弱信号同时存在时，取最高级别。始终遵守"拿不准往大一级分"原则。

### 3.3 覆盖机制

用户可随时通过以下方式覆盖自动判断：

- 直接说明："按 S 处理" / "升级为 L" / "这个走 M 流程"
- 在 `/dev` 命令中指定：`/dev -s <需求>` / `/dev -m <需求>` / `/dev -l <需求>`

覆盖后 Agent 不再质疑，直接按指定级别执行。

---

## 4. 各阶段详细设计

### 4.1 Stage 1: INTAKE（需求理解）

**触发条件：** 用户输入 `/dev <需求描述>` 或描述一个开发需求。

**全规模执行，无跳过条件。**

**执行流程：**

1. Main Agent 解析需求描述
2. 基于 3.2 节规则自动判断规模 (S/M/L)
3. 向用户报告：
   - 需求理解摘要（一句话）
   - 判断的规模等级及依据
   - 该级别对应的完整流程和审批节点
   - 预计涉及的文件范围
4. 等待用户确认或覆盖

**输入：** 用户的需求描述（自然语言）

**输出：**
- 明确的需求描述（结构化）
- 确定的规模等级 (S/M/L)
- 用户确认

**审批点：** 用户确认规模判断（可覆盖）

### 4.2 Stage 2: DESIGN（方案设计）

**分级行为：**

| 规模 | 行为 | 审批点 |
|------|------|--------|
| S | **跳过此阶段**，直接进入 PLAN | 无 |
| M | 调用 `/office-hours`（builder mode）brainstorm → 生成 design doc → 用户选方案 | 用户选择方案 |
| L | 调用 `/office-hours` → 生成 design doc → 调用 `/plan-ceo-review` 审视 scope → 用户选方案 | 用户选择方案 |

**跳过条件：** S 级需求；或用户已提供完整的设计方案。

**输出文件：** `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`

**集成的 gstack skills：**

| Skill | 用途 | 触发条件 |
|-------|------|---------|
| `/office-hours` | 结构化 brainstorm，产出标准化 design doc | M/L 级需求进入 DESIGN 阶段 |
| `/plan-ceo-review` | CEO 视角审视 scope 合理性，防止 over-engineering 或 under-scoping | L 级需求，在 `/office-hours` 产出 design doc 之后 |

**`/office-hours` 使用模式：** 固定使用 builder mode（非 startup mode），因为本项目是已有产品的功能迭代。

**Design Doc 标准结构：**

```markdown
# <功能名称> 设计文档
## 问题定义
## 方案选项（至少 2 个）
## 推荐方案及理由
## 技术影响面（前端/后端/DB/API/测试）
## 风险点
```

### 4.3 Stage 3: PLAN（执行计划）

**核心机制：** 使用 `planning-with-files-zh` skill 管理计划文件。

**三个持久化文件：**

| 文件 | 路径 | 用途 | 更新时机 |
|------|------|------|---------|
| `task_plan.md` | 工作目录根 | 任务分解：checkbox 列表 + 依赖关系 + 验收标准 | PLAN 阶段创建，BUILD 阶段每完成一个 task 更新 checkbox |
| `findings.md` | 工作目录根 | 研究发现：代码探索结果、现有 pattern、风险点 | PLAN 阶段创建，BUILD 阶段发现新信息时追加 |
| `progress.md` | 工作目录根 | 进度追踪：实时更新，支持 `/clear` 后自动恢复 | BUILD 阶段实时更新 |

**分级行为：**

#### S 级

1. `planning-with-files-zh` 生成简单 `task_plan.md`（3-5 tasks）
2. 不生成 `findings.md`（scope 太小，无需研究）
3. **自动进入 BUILD，不需审批**

#### M 级

1. `planning-with-files-zh` 生成 `task_plan.md` + `findings.md`
2. 调用 `/plan-eng-review` 检查架构合理性 + 测试覆盖完整性
3. 自动修正 `/plan-eng-review` 发现的问题（无需用户介入）
4. **[用户审批] plan 概要** — 展示 task 列表和预计工作量，用户确认后进入 BUILD

#### L 级

1. `planning-with-files-zh` 生成完整三文件（`task_plan.md` + `findings.md` + `progress.md`）
2. 调用 `/autoplan` 自动跑全部 review pipeline：
   - `/plan-ceo-review`: scope 是否合理，功能边界是否清晰
   - `/plan-design-review`: UI/UX 是否完整（仅在有前端变更时触发）
   - `/plan-eng-review`: 架构 + 测试 + 性能
3. `/autoplan` 仅在 taste decisions（审美/体验类决策，无明确对错）时暂停请求用户输入
4. **[用户审批] 完整 plan** — 展示 task 列表、依赖关系、风险点，用户确认后进入 BUILD

**集成的 gstack skills：**

| Skill | 用途 | 触发条件 |
|-------|------|---------|
| `planning-with-files-zh` | 生成和管理计划文件 | 所有规模进入 PLAN 阶段 |
| `/plan-eng-review` | 架构和测试审查 | M/L 级 |
| `/plan-ceo-review` | scope 审查（通过 `/autoplan`） | L 级 |
| `/plan-design-review` | UI/UX 审查（通过 `/autoplan`） | L 级且有前端变更 |
| `/autoplan` | 自动跑全部 review pipeline | L 级 |

**关键价值：** `/clear` 后不丢失上下文。`progress.md` 记录了当前进度、已完成的 task、下一步计划，任何新对话读取后都能自动接续之前的工作。

### 4.4 Stage 4: BUILD（并行开发）

#### 4.4.0 Branch 规范

- **分支命名**：`feat/<topic>`（功能）/ `fix/<topic>`（修复）/ `refactor/<topic>`（重构）
- **基于 `dev` 分支创建**，不基于 `main`
- **永远在 feature branch 上工作**，Agent 不允许直接 commit 到 `main` 或 `dev`
- **PR 目标分支**：`dev`

#### 4.4.1 Agent Team 结构

```
Main Agent (用户对话窗口，不执行代码操作)
│
├─ TeamCreate("feature-<topic>")
├─ TaskCreate(从 task_plan.md 解析每个 task)
│
├─ implementer-backend   ← 后端开发 agent，在 feature branch 上工作
├─ implementer-frontend  ← 前端开发 agent，在同一 feature branch 上工作
├─ test-writer           ← 测试 agent，在同一 feature branch 上编写和运行测试
│
│  S 级：仅派 1 个 implementer（根据变更类型选 backend 或 frontend）
│  M 级：派 2 个 agent（implementer-backend + implementer-frontend，或 implementer + test-writer）
│  L 级：派 3 个 agent（implementer-backend + implementer-frontend + test-writer）
│
│  每个 agent 完成 task 后：
│  ├─ 运行对应测试（单元/集成）验证
│  ├─ 更新 task_plan.md 对应 checkbox
│  ├─ 更新 progress.md 当前状态
│  └─ 通过 SendMessage 汇报给 Main Agent
│
├─ 所有 tasks 完成后：
│  ├─ 运行 scripts/test.sh 全量测试
│  ├─ Quality Gate（见 4.4.2）
│  ├─ 生成 PR（目标分支 dev）
│  └─ [用户审批] approve PR
│
└─ TeamDelete（清理 team 资源）
```

**Agent 协作规则：**
- 多个 agent 共享同一 feature branch
- 通过 TaskList / TaskUpdate 协调任务分配，避免并发编辑同一文件
- 如果两个 agent 需要修改同一文件，通过 task 依赖关系串行化（`addBlockedBy`）
- Agent 之间通过 SendMessage 沟通，不通过文件传递信息

#### 4.4.2 Quality Gate — BUILD 完成后的自动审查

所有 task 完成且全量测试通过后，自动进入 Quality Gate：

| Skill | 触发条件 | 审查内容 |
|-------|---------|---------|
| `/review` | **所有 PR 必跑**（S/M/L） | 代码审查：SQL 注入、LLM 信任边界、条件副作用、API 安全 |
| `/qa` | 有前端变更时 | 自动化 QA 测试：页面交互、表单提交、异常路径 |
| `/design-review` | 有 UI 变更时 | 视觉一致性、间距、层级审查 |
| `/cso` | 涉及 auth / 安全 / 数据隔离 / Cookie 加密时 | 安全审计：认证绕过、权限升级、数据泄露 |
| `/benchmark` | 涉及性能敏感路径（列表查询、AI 调用、文件上传）时 | 性能基线对比 |
| `/codex` | L 级 PR | 独立第二意见 review（OpenAI Codex） |

**审查结果处理流程：**

```
Quality Gate 启动
├─ 并行运行所有适用的 review skill
├─ 收集所有审查结果
│
├─ 全部通过？
│  ├─ 是 → 生成 PR → 提交给用户审批
│  └─ 否 → 进入修复循环：
│     ├─ 自动修复审查发现的问题
│     ├─ 重新运行失败的 review skill
│     ├─ 修复循环最多 3 次
│     └─ 3 次后仍未通过 → 向用户报告问题，请求人工介入
```

#### 4.4.3 异常处理

| 异常类型 | 触发的 skill | 处理行为 |
|---------|-------------|---------|
| 测试失败 | `/investigate` | 四阶段根因分析（调查 → 分析 → 假设 → 实施），不盲目修复 |
| 性能回退 | `/benchmark` | 对比基线，定位瓶颈，生成优化方案 |
| 安全漏洞 | `/cso` | 安全审计 + 修复建议 + 重新验证 |
| Agent 间冲突 | Main Agent 仲裁 | 通过 task 依赖关系重新编排，必要时串行化 |

#### 4.4.4 关键规则

| 规则 | 说明 |
|------|------|
| **Feature Branch 强制** | 永远在 feature branch 上工作，不直接推 main/dev |
| **PR 体量控制** | 每个 PR 建议 <= 500 行变更；超过时自动拆分为多个 PR，按依赖顺序提交 |
| **测试强制** | 新 API 端点必须有对应测试，reviewer 会检查覆盖率 |
| **文档同步** | 涉及 API 变更时更新 `docs/agent/api.md`；涉及架构变更时更新 `docs/agent/architecture.md`；涉及 DB 变更时更新 `docs/agent/database.md` |
| **progress.md 实时更新** | 每完成一个 task 就更新 progress.md，确保 `/clear` 后可恢复 |
| **Commit 规范** | 遵循 Conventional Commits：`feat:` / `fix:` / `test:` / `docs:` / `refactor:` |

### 4.5 Stage 5: SHIP（交付上线）

**触发条件：** 用户 approve PR。

**执行流程：**

```
用户 approve PR
│
├─ /ship
│  ├─ merge feature branch → dev
│  ├─ version bump（遵循 semver：S 级 patch，M 级 minor，L 级根据影响判断）
│  ├─ 更新 CHANGELOG
│  ├─ push to remote
│  └─ 创建 merge PR（如需要合入 main）
│
├─ /document-release
│  ├─ 对比 diff，识别受影响的文档
│  ├─ 自动更新 api.md / architecture.md / database.md
│  ├─ 更新 CLAUDE.md 中的项目状态
│  └─ 清理已完成的 task_plan.md / findings.md / progress.md（归档到 docs/superpowers/archive/）
│
├─ /land-and-deploy（如果配置了部署）
│  ├─ 首次部署：dry run 验证部署环境
│  └─ 后续部署：自动部署 + 健康检查
│
├─ /canary（如果有 prod URL）
│  ├─ 部署后监控：console errors、性能回退、页面可用性
│  └─ 异常时自动告警
│
└─ 通知用户："[功能名] 已上线, PR #N"
```

**集成的 gstack skills：**

| Skill | 用途 | 触发条件 |
|-------|------|---------|
| `/ship` | merge + version bump + CHANGELOG + push + PR | 用户 approve PR 后，必跑 |
| `/document-release` | 自动同步所有受影响的文档 | `/ship` 完成后，必跑 |
| `/land-and-deploy` | 部署 + 健康检查 | `/ship` 完成后，仅在已配置部署时触发 |
| `/canary` | 部署后监控 | `/land-and-deploy` 完成后，仅在有 prod URL 时触发 |

---

## 5. 上下文连续性设计

### 5.1 持久化层级

| 层级 | 文件位置 | 用途 | 生命周期 | 更新触发 |
|------|---------|------|---------|---------|
| **项目记忆** | `CLAUDE.md` | 架构、规范、技术栈、当前状态 | 永久 | 每次 SHIP 后由 `/document-release` 自动更新 |
| **需求记忆** | `docs/superpowers/specs/*.md` | 设计决策和上下文 | 随功能 | DESIGN 阶段创建，SHIP 后归档 |
| **执行计划** | `task_plan.md` + `findings.md` + `progress.md` | task breakdown + 进度追踪 | 随功能 | PLAN 阶段创建，BUILD 阶段实时更新，SHIP 后归档 |
| **个人偏好** | `~/.claude/projects/.../memory/` | 用户习惯和反馈 | 永久 | 用户表达偏好时自动记录 |
| **Retro 数据** | `.context/retros/*.json` | 工程复盘历史趋势 | 永久 | 每周 `/retro` 生成 |

### 5.2 新对话恢复机制

新对话启动时，Agent 按以下顺序自动读取：

1. **CLAUDE.md** — 获取项目全貌、技术栈、当前状态
2. **memory/** — 获取用户偏好和历史决策
3. **最近的 progress.md** — 检测是否有未完成的工作：
   - 存在未完成 task → 自动提示用户："检测到未完成的工作 [功能名]，是否继续？"
   - 用户确认 → 从 `progress.md` 记录的断点处接续执行
   - 用户拒绝 → 忽略，按新需求处理

### 5.3 归档策略

功能完成（SHIP 阶段）后：
- `task_plan.md` → 移动到 `docs/superpowers/archive/YYYY-MM-DD-<topic>-task-plan.md`
- `findings.md` → 移动到 `docs/superpowers/archive/YYYY-MM-DD-<topic>-findings.md`
- `progress.md` → 删除（进度信息已无意义）
- `docs/superpowers/specs/*-design.md` → 保留原位（作为设计决策记录）

---

## 6. 触发方式

### 6.1 CLAUDE.md 常驻规范

以下规范写入 CLAUDE.md，每次对话自动遵循：

- Agent Team 工作模式（Main Agent 只对话和派发）
- 分级规则（S/M/L 判断标准）
- 质量门禁（review 触发条件）
- Branch 规范（feature branch 强制，PR 目标 dev）
- gstack skill 触发条件映射表

### 6.2 Slash Commands

| 命令 | 用途 | 等价的 Pipeline 阶段 |
|------|------|---------------------|
| `/dev <需求描述>` | 一键启动完整流程 | INTAKE -> DESIGN -> PLAN -> BUILD -> SHIP |
| `/dev plan <需求描述>` | 只做 brainstorm + plan（需求已明确时） | DESIGN -> PLAN |
| `/dev build` | 只做 build（plan 已就绪时） | BUILD -> SHIP |
| `/dev status` | 查看当前进度 | 读取 progress.md + Team 状态并汇报 |

**`/dev` 命令规模覆盖选项：**

| 选项 | 说明 |
|------|------|
| `/dev -s <需求>` | 强制 S 级 |
| `/dev -m <需求>` | 强制 M 级 |
| `/dev -l <需求>` | 强制 L 级 |

**`/dev status` 输出格式：**

```
当前功能: <功能名称>
规模等级: M
当前阶段: BUILD (3/7 tasks completed)
Agent Team: feature-csv-export
  - implementer-backend: idle (completed task #3)
  - implementer-frontend: in_progress (task #4: 前端导出按钮)
下一审批点: approve PR
```

---

## 7. gstack Skills 完整集成清单

### 7.1 Pipeline 内自动触发

| Skill | 阶段 | 触发条件 | 输入 | 输出 |
|-------|------|---------|------|------|
| `/office-hours` | DESIGN | M/L 级需求进入 DESIGN | 需求描述 | Design doc（spec 文件） |
| `/plan-ceo-review` | DESIGN | L 级，`/office-hours` 产出后 | Design doc | Scope 审查意见 |
| `/plan-eng-review` | PLAN | M/L 级 plan 生成后 | task_plan.md + findings.md | 架构/测试审查意见 |
| `/plan-design-review` | PLAN | L 级且有前端变更（通过 `/autoplan`） | task_plan.md | UI/UX 审查意见 |
| `/autoplan` | PLAN | L 级 plan 生成后 | 三文件 | 全部 review 结果 + taste decisions |
| `/review` | BUILD | **所有 PR**（S/M/L 必跑） | PR diff | 代码审查结果（pass/fail + 问题列表） |
| `/qa` | BUILD | 有前端变更时 | 运行中的前端页面 | QA 测试报告 |
| `/design-review` | BUILD | 有 UI 变更时 | 运行中的前端页面 | 视觉审查报告 |
| `/cso` | BUILD | 涉及 auth / 安全 / 数据隔离 / Cookie 加密 | PR diff + 相关代码 | 安全审计报告 |
| `/benchmark` | BUILD | 涉及性能敏感路径 | 变更前后基线 | 性能对比报告 |
| `/codex` | BUILD | L 级 PR | PR diff | 独立 review 意见 |
| `/investigate` | BUILD | 测试失败或遇到 bug | 错误信息 + 相关代码 | 根因分析报告 + 修复方案 |
| `/ship` | SHIP | 用户 approve PR 后 | Approved PR | merge + version + CHANGELOG |
| `/document-release` | SHIP | `/ship` 完成后 | merge diff | 更新后的文档 |
| `/land-and-deploy` | SHIP | 已配置部署时 | 部署配置 | 部署结果 + 健康检查 |
| `/canary` | SHIP | 有 prod URL 时 | prod URL | 监控报告 |

### 7.2 周期性触发

| Skill | 频率 | 用途 | 输出 |
|-------|------|------|------|
| `/retro` | 每周 | 工程复盘 + 趋势追踪 | Retro 报告（`.context/retros/` 下） |
| `/cso`（comprehensive 模式） | 每月 | 全面安全审计 | 安全审计报告 |

### 7.3 Skill 判断"有前端变更"的标准

当 PR diff 中包含以下路径的文件变更时，视为"有前端变更"：

- `src/frontend/**`
- 任何 `.tsx` / `.ts`（位于 frontend 目录下）
- `tailwind.config.*`
- `next.config.*`

### 7.4 Skill 判断"涉及安全"的标准

当 PR diff 中涉及以下内容时，视为"涉及安全"：

- `src/backend/auth/**` 或认证相关代码
- Cookie / Session / Token 相关变更
- `cryptography` / `Fernet` 相关代码
- 数据库权限或数据隔离逻辑
- 新增或修改 API 端点的权限检查

---

## 8. 完整生命周期示例

### 8.1 S 级示例："修复候选人列表分页 bug"

```
用户: "候选人列表翻页后数据没更新"

→ INTAKE:
  - 判断: S 级（"翻页" + "没更新" = bug fix 信号）
  - 报告: "S 级 bug fix，仅需 approve PR"
  - 用户确认

→ PLAN:
  - planning-with-files-zh 生成 task_plan.md（3 tasks）:
    [ ] 定位分页状态管理逻辑
    [ ] 修复 state 更新时机
    [ ] 添加分页切换测试
  - 自动进入 BUILD

→ BUILD:
  - git checkout -b fix/candidate-pagination
  - 1 个 implementer agent 执行所有 tasks
  - /investigate 定位根因
  - 修复 + 运行测试
  - /review 审查修复（必跑）
  - 生成 PR

→ [用户 approve PR]

→ SHIP:
  - /ship: merge → dev, patch version bump, CHANGELOG
  - /document-release: 无文档变更，跳过
  - 通知: "分页 bug 已修复, PR #N"
```

### 8.2 M 级示例："给候选人列表加导出 CSV 功能"

```
用户: "候选人列表需要导出 CSV"

→ INTAKE:
  - 判断: M 级（"新增功能" + 前后端联动）
  - 报告: "M 级功能，需 approve spec + approve PR"
  - 用户确认

→ DESIGN:
  - /office-hours (builder mode):
    - 方案 A: 前端纯导出（无需后端，但数据量受限）
    - 方案 B: 后端生成 CSV 流式下载（支持大数据量）
    - 推荐方案 B
  - 生成 spec: docs/superpowers/specs/2026-XX-XX-csv-export-design.md
  - [用户选方案 B]

→ PLAN:
  - planning-with-files-zh 生成 task_plan.md + findings.md
  - /plan-eng-review 检查:
    - 架构: StreamingResponse 方案合理
    - 测试: 需要覆盖大文件和中文编码
  - [用户审批 plan]

→ BUILD:
  - git checkout -b feat/csv-export
  - TeamCreate("csv-export")
  - implementer-backend: CSV 生成 API + 测试
  - implementer-frontend: 导出按钮 + 下载逻辑
  - scripts/test.sh 全量测试
  - /review (必跑) + /qa (有前端变更)
  - 生成 PR

→ [用户 approve PR]

→ SHIP:
  - /ship: merge → dev, minor version bump, CHANGELOG
  - /document-release: 更新 api.md（新端点）
  - 通知: "CSV 导出已上线, PR #N"
```

### 8.3 L 级示例："实现 v0.4 Phase 4.1 经验提取引擎"

```
用户: "实现经验提取引擎"

→ INTAKE:
  - 判断: L 级（新模块 + 新 DB 表 + 新页面 + 新 API + 新 Prompt）
  - 报告: "L 级模块开发，需 approve spec + approve plan + approve PR"
  - 用户确认

→ DESIGN:
  - /office-hours (builder mode):
    - 讨论: 经验提取的触发时机、存储结构、与现有反馈系统的关系
    - 方案: experience_records 表 + 自动提取服务 + 管理页面
  - 生成 spec
  - /plan-ceo-review:
    - 确认 scope 合理，不过度设计
    - 建议先做手动提取，自动提取作为后续优化
  - [用户选方案]

→ PLAN:
  - planning-with-files-zh 生成三文件:
    - task_plan.md: 12 tasks（DB migration + API + Service + Prompt + 前端 + 测试）
    - findings.md: 现有反馈系统 pattern、Prompt 模板注册机制
    - progress.md: 初始状态
  - /autoplan 自动跑全部 review:
    - /plan-ceo-review: scope 合理
    - /plan-design-review: 管理页面布局合理（有 UI 变更）
    - /plan-eng-review: 架构合理，建议增加批量提取的并发控制
  - taste decision: 管理页面使用 table 还是 card 布局 → [用户选 table]
  - [用户审批 plan]

→ BUILD:
  - git checkout -b feat/experience-extraction
  - TeamCreate("exp-extraction")
  - implementer-backend: DB model + API + Service + Prompt（6 tasks）
  - implementer-frontend: 管理页面 + 列表 + 详情（4 tasks）
  - test-writer: API 测试 + 集成测试（2 tasks）
  - progress.md 实时更新
  - scripts/test.sh 全量测试
  - Quality Gate:
    - /review (必跑)
    - /qa (有前端变更)
    - /design-review (有 UI 变更)
    - /cso (涉及数据隔离)
    - /codex (L 级)
  - 生成 PR

→ [用户 approve PR]

→ SHIP:
  - /ship: merge → dev, CHANGELOG
  - /document-release: 更新 api.md + database.md + architecture.md + CLAUDE.md
  - /land-and-deploy (如已配置)
  - /canary (如有 prod URL)
  - 通知: "经验提取引擎已上线, PR #N"
```

---

## 9. 实现计划

### 9.1 需要创建/修改的文件

| 文件 | 操作 | 内容 |
|------|------|------|
| `CLAUDE.md` | **修改** | 加入分级规则、质量门禁、branch 规范、gstack 触发条件（Section: Agent Team 工作模式） |
| `/dev` slash command | **创建** | Skill 文件，实现一键启动 INTAKE → DESIGN → PLAN → BUILD → SHIP 全流程 |
| `AGENTS.md` | **修改** | 更新 agent 角色定义：implementer-backend、implementer-frontend、test-writer |

### 9.2 不需要修改的

| 项目 | 原因 |
|------|------|
| gstack skills 本身 | 只在正确时机调用，不改 skill 实现 |
| `planning-with-files-zh` | 直接使用，不改 skill 实现 |
| `scripts/*.sh` | 现有启停/测试脚本不变 |
| 项目源码目录结构 | 不改变 `src/` 下的组织方式 |
| 数据库 schema | 本 spec 不涉及 DB 变更 |

---

## 10. 非目标 (Non-Goals)

以下内容明确排除在本 spec 范围之外：

| 非目标 | 原因 |
|--------|------|
| 改变现有技术栈 | 本 spec 是工作流优化，不是技术迁移 |
| 修改 gstack/superpowers skills 本身 | 只编排调用，不改 skill 实现 |
| 引入新的外部工具或服务 | 充分利用现有 skill 生态 |
| 改变 git 仓库结构 | 只增加 branch 规范，不改目录 |
| CI/CD 自动化 | 保持现有 `scripts/*.sh` 方式 |
| 多人协作工作流 | 当前项目为单人 + AI 模式 |
| 自动 merge 到 main | PR merge 永远需要用户审批 |

---

## 附录 A: 术语表

| 术语 | 定义 |
|------|------|
| **Main Agent** | 与用户直接对话的 Claude Code 实例，不执行代码操作，只负责对话、派发、汇报 |
| **Agent Team** | 由 Main Agent 创建的一组协作 agent，通过 TeamCreate/SendMessage/TaskUpdate 协调 |
| **Teammate / Implementer** | Agent Team 中执行具体开发工作的 agent |
| **Quality Gate** | BUILD 阶段完成后的自动审查检查点，由一组 gstack skills 组成 |
| **Feature Branch** | 基于 `dev` 创建的功能分支，所有开发工作在此进行 |
| **Pipeline** | INTAKE -> DESIGN -> PLAN -> BUILD -> SHIP 五阶段流程 |
| **Taste Decision** | 审美/体验类决策（如 UI 布局选择），无明确对错，需要用户判断 |
| **planning-with-files-zh** | Manus 风格的文件规划 skill，通过三文件持久化实现跨对话恢复 |

## 附录 B: 决策记录

| # | 决策 | 理由 | 替代方案 |
|---|------|------|---------|
| D1 | PR 目标分支为 `dev` 而非 `main` | 项目当前在 `dev` 分支开发，`main` 用于稳定发布 | 直接推 main（被否，缺少缓冲） |
| D2 | S 级跳过 DESIGN 和 findings.md | bug fix scope 小，设计和研究增加不必要延迟 | 统一走全流程（被否，过度编排） |
| D3 | Quality Gate 修复循环最多 3 次 | 防止无限循环，3 次足以覆盖大多数自动可修复问题 | 无限重试（被否，可能死循环） |
| D4 | 多 agent 共享同一 feature branch | 简化 branch 管理，避免 merge 冲突 | 每个 agent 独立 branch（被否，合并成本高） |
| D5 | progress.md SHIP 后删除而非归档 | 进度信息仅在开发中有价值，完成后无归档意义 | 全部归档（被否，信息冗余） |
