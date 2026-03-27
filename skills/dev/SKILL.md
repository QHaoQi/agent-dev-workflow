---
name: dev
description: |
  一键启动分级自治开发工作流。解析需求 → 自动分级 S/M/L → 按级别编排
  INTAKE > DESIGN > PLAN > BUILD > SHIP 五阶段 Pipeline。
  Main Agent 全程只对话和派发，所有代码工作由 Agent Team 执行。
user-invocable: true
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Skill
  - SendMessage
  - TaskCreate
  - TaskUpdate
  - TaskList
  - TaskGet
  - TeamCreate
  - TeamDelete
  - EnterWorktree
  - ExitWorktree
---

# /dev — 分级自治开发工作流

## 项目配置

> **安装后必须根据项目实际情况自定义以下内容：**
>
> 1. **分级信号词**（Stage 1.2）— 替换为你项目的领域关键词
> 2. **Agent 角色**（Stage 4.2）— 根据你的技术栈调整 implementer 类型
> 3. **Quality Gate 触发条件**（Stage 4.4）— 根据项目的前端/后端路径和安全边界调整
> 4. **Branch 规范**（Stage 4.1）— 确认基准分支名和 PR 目标分支
> 5. **启停/测试命令** — 替换为你项目的脚本路径（如 `./scripts/test.sh`）
>
> 具体配置项在各 section 中用 `<!-- CUSTOMIZE -->` 标注。

## 调用方式

| 命令 | 用途 |
|------|------|
| `/dev <需求描述>` | 完整流程：INTAKE → DESIGN → PLAN → BUILD → SHIP |
| `/dev plan <需求描述>` | 仅 DESIGN → PLAN（需求已明确时） |
| `/dev build` | 仅 BUILD → SHIP（plan 已就绪时） |
| `/dev status` | 查看当前进度 |

**规模覆盖选项：** `/dev -s <需求>` / `/dev -m <需求>` / `/dev -l <需求>`

**开始前宣告：** "正在使用 /dev skill 启动分级自治开发工作流。"

---

## Stage 1: INTAKE（需求理解）

### 1.1 解析需求

读取用户输入，提取以下信息：
- 需求的核心目标（一句话总结）
- 涉及的层级（前端 / 后端 / 数据库 / 测试 / 其他）
- 预计影响的文件范围

### 1.2 自动分级

按以下优先级判断规模等级：

<!-- CUSTOMIZE: 根据项目领域替换信号词 -->

**强信号（直接决定）：**

| 信号 | 判定 |
|------|------|
| 描述包含 "修复" / "fix" / "bug" / "hotfix" | S |
| 涉及多个新 DB 表（2+） | L |
| 描述包含 "模块" / "系统" / "Phase" / "引擎" | L |

**弱信号（组合判断）：**

| 信号 | 倾向 |
|------|------|
| "加一个" / "新增" / "实现 XX 功能" | M |
| 涉及 1 个新 DB 表 | 至少 M |
| 同时涉及前端和后端 | 至少 M |
| 涉及新 API 端点 + 新页面 | 至少 M |

**冲突处理：** 强信号优先；多个弱信号取最高级别；拿不准往大一级分。

**用户覆盖：** 如果命令中包含 `-s` / `-m` / `-l` 标志，或用户明确说"按 X 处理"，直接使用指定级别，不再质疑。

### 1.3 向用户报告

向用户展示以下信息，等待确认：

```
需求理解: <一句话总结>
规模等级: <S/M/L>（依据: <判断理由>）
审批节点: <该级别对应的审批点列表>
预计涉及: <文件范围概述>
```

等待用户确认或覆盖后，进入下一阶段。

---

## Stage 2: DESIGN（方案设计）

### 2.1 分级行为

| 规模 | 行为 |
|------|------|
| S | **跳过此阶段**，直接进入 PLAN |
| M | 调用 `/office-hours`（builder mode）→ 生成 design doc → [用户选方案] |
| L | 调用 `/office-hours`（builder mode）→ 生成 design doc → 调用 `/plan-ceo-review` → [用户选方案] |

### 2.2 执行步骤（M/L）

1. 使用 Skill tool 调用 `/office-hours`，固定使用 **builder mode**（非 startup mode）。
2. 将 brainstorm 结果输出为 design doc，保存到：
   `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`
3. Design doc 必须包含以下结构：
   - 问题定义
   - 方案选项（至少 2 个）
   - 推荐方案及理由
   - 技术影响面
   - 风险点
4. **仅 L 级：** 在生成 design doc 后，调用 `/plan-ceo-review` 审视 scope 合理性。
5. **[用户审批]** 向用户展示方案选项，等待用户选择。

### 2.3 跳过条件

- S 级需求
- 用户已提供完整的设计方案（直接跳到 PLAN）

---

## Stage 3: PLAN（执行计划）

### 3.1 核心机制

使用 Skill tool 调用 `planning-with-files-zh` 生成计划文件：

| 文件 | 用途 |
|------|------|
| `task_plan.md` | 任务分解：checkbox 列表 + 依赖关系 + 验收标准 |
| `findings.md` | 研究发现：代码探索结果、现有 pattern、风险点 |
| `progress.md` | 进度追踪：实时更新，支持 `/clear` 后恢复 |

### 3.2 分级行为

#### S 级
1. 调用 `planning-with-files-zh` 生成简单 `task_plan.md`（3-5 tasks）。
2. 不生成 `findings.md`（scope 太小，无需研究）。
3. **自动进入 BUILD，不需审批。**

#### M 级
1. 调用 `planning-with-files-zh` 生成 `task_plan.md` + `findings.md`。
2. 调用 `/plan-eng-review` 检查架构合理性 + 测试覆盖完整性。
3. 自动修正 `/plan-eng-review` 发现的问题（无需用户介入）。
4. **[用户审批]** 展示 task 列表和预计工作量，等待确认。

#### L 级
1. 调用 `planning-with-files-zh` 生成完整三文件。
2. 调用 `/autoplan` 自动跑全部 review pipeline：
   - `/plan-ceo-review`: scope 是否合理
   - `/plan-design-review`: UI/UX 是否完整（仅在有前端变更时）
   - `/plan-eng-review`: 架构 + 测试 + 性能
3. `/autoplan` 仅在 taste decisions（审美/体验类决策）时暂停请求用户输入。
4. **[用户审批]** 展示完整 plan：task 列表、依赖关系、风险点。

---

## Stage 4: BUILD（并行开发）

### 4.1 创建 Feature Branch

<!-- CUSTOMIZE: 替换 <base-branch> 为你项目的基准开发分支 -->

根据需求类型创建分支：
- 功能：`feat/<topic>`
- 修复：`fix/<topic>`
- 重构：`refactor/<topic>`

**基于 `<base-branch>` 分支创建，PR 目标为 `<base-branch>`。永远不直接 commit 到保护分支。**

```bash
git checkout <base-branch>
git pull origin <base-branch>
git checkout -b feat/<topic>
```

### 4.2 Agent Team 编排

<!-- CUSTOMIZE: 根据项目技术栈调整 agent 角色名和职责 -->

根据规模创建 Team 和分派 Agent：

#### S 级 — 单 Agent
```
不创建 Team，直接派发 1 个 Agent（根据变更类型选 implementer-backend 或 implementer-frontend）。
Agent 在 feature branch 上完成所有 tasks。
```

#### M 级 — 2 Agents
```
TeamCreate("feature-<topic>")
从 task_plan.md 解析 tasks → TaskCreate 逐个创建
派发 2 个 Agent：
  - implementer-backend：后端 tasks
  - implementer-frontend：前端 tasks
  （如果无前端变更，替换为 implementer-backend + test-writer）
```

#### L 级 — 3 Agents
```
TeamCreate("feature-<topic>")
从 task_plan.md 解析 tasks → TaskCreate 逐个创建
派发 3 个 Agent：
  - implementer-backend：后端开发
  - implementer-frontend：前端开发
  - test-writer：测试编写和运行
```

### 4.3 Agent 协作规则

- 多个 Agent 共享同一 feature branch。
- 通过 TaskList / TaskUpdate 协调任务分配，避免并发编辑同一文件。
- 如果两个 Agent 需要修改同一文件，通过 task 依赖关系串行化（`addBlockedBy`）。
- Agent 之间通过 SendMessage 沟通。
- 每个 Agent 完成 task 后：
  1. 运行对应测试验证
  2. 更新 task_plan.md 对应 checkbox
  3. 更新 progress.md 当前状态
  4. 通过 SendMessage 汇报给 Main Agent
- Commit 遵循 Conventional Commits：`feat:` / `fix:` / `test:` / `docs:` / `refactor:`

### 4.4 Quality Gate

<!-- CUSTOMIZE: 替换测试命令和触发条件路径 -->

所有 tasks 完成后，先运行全量测试：

```bash
./scripts/test.sh
```

测试通过后，按条件自动触发 review skills：

| Skill | 触发条件 |
|-------|---------|
| `/review` | **所有 PR 必跑**（S/M/L） |
| `/qa` | 有前端变更时（前端源码目录有修改） |
| `/design-review` | 有 UI 变更时（UI 组件文件有修改） |
| `/cso` | 涉及 auth / 安全 / 敏感数据时 |
| `/benchmark` | 涉及性能敏感路径时 |
| `/codex` | L 级 PR |

**审查结果处理：**
- 全部通过 → 生成 PR → 提交给用户审批
- 有问题 → 自动修复 → 重新运行失败的 review → 最多 3 次循环
- 3 次后仍未通过 → 向用户报告问题，请求人工介入

### 4.5 生成 PR

```bash
gh pr create --base <base-branch> --title "<type>: <简短描述>" --body "<PR 描述>"
```

PR 体量控制：建议 <= 500 行变更。超过时提醒用户考虑拆分。

### 4.6 异常处理

| 异常 | 处理 |
|------|------|
| 测试失败 | 调用 `/investigate` 四阶段根因分析 |
| 性能回退 | 调用 `/benchmark` 对比基线 |
| 安全漏洞 | 调用 `/cso` 安全审计 + 修复 |
| Agent 间冲突 | Main Agent 仲裁，通过 task 依赖重新编排 |

### 4.7 PR 审批

**[用户审批]** 向用户展示 PR 链接，等待 approve。

---

## Stage 5: SHIP（交付上线）

用户 approve PR 后，按顺序执行：

1. **`/ship`**（必跑）
   - merge feature branch → base branch
   - version bump（S: patch, M: minor, L: 根据影响判断）
   - 更新 CHANGELOG
   - push to remote

2. **`/document-release`**（必跑）
   - 对比 diff，自动更新受影响的文档
   - 更新 CLAUDE.md 中的项目状态
   - 归档 task_plan.md → `docs/superpowers/archive/`
   - 归档 findings.md → `docs/superpowers/archive/`
   - 删除 progress.md

3. **`/land-and-deploy`**（仅在已配置部署时）
   - 自动部署 + 健康检查

4. **`/canary`**（仅在有 prod URL 时）
   - 部署后监控：console errors、性能回退、页面可用性

5. **通知用户：** "[功能名] 已上线, PR #N"

---

## /dev status 命令

当用户调用 `/dev status` 时：

1. 读取 `progress.md`（如果存在）
2. 读取 `task_plan.md`（如果存在）
3. 调用 TaskList 获取 team 状态（如果有活跃 team）
4. 向用户展示：

```
当前功能: <功能名称>
规模等级: <S/M/L>
当前阶段: <INTAKE/DESIGN/PLAN/BUILD/SHIP> (<已完成 tasks>/<总 tasks>)
Agent Team: <team 名称>
  - <agent 名>: <状态> (<当前 task>)
下一审批点: <下一个需要用户参与的节点>
```

如果没有活跃的工作，报告："当前没有进行中的开发任务。"

---

## /dev plan 命令

跳过 INTAKE 的自动分级（仍需用户确认规模），直接从 DESIGN 阶段开始：
1. 执行 INTAKE 的 1.2 自动分级 + 1.3 报告（简化版）
2. 进入 DESIGN → PLAN
3. 不进入 BUILD（plan 完成后停止，等待用户决定何时 build）

## /dev build 命令

前提：`task_plan.md` 已存在。

1. 读取 `task_plan.md` 和 `progress.md`
2. 确认规模等级（从 plan 文件中读取，或询问用户）
3. 直接进入 BUILD → SHIP 流程

---

## 上下文恢复

如果检测到 `progress.md` 存在且有未完成的 tasks：
1. 读取三文件恢复上下文
2. 向用户报告："检测到未完成的工作 [功能名]，是否继续？"
3. 用户确认 → 从断点处接续
4. 用户拒绝 → 按新需求处理
