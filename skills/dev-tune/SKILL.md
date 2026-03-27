---
name: dev-tune
description: |
  优化 /dev 开发工作流。报告问题、调整分级规则、修改质量门禁、
  更新 agent 角色定义。用于持续改进 Agent Team 工作方式。
  Use when: "优化工作流", "工作流有问题", "调整流程", "dev-tune"
allowed-tools:
  - Read
  - Edit
  - Write
  - Bash
  - AskUserQuestion
  - Grep
  - Glob
---

# /dev-tune — 开发工作流优化命令

## 调用方式

- `/dev-tune` — 交互式诊断模式（默认）
- `/dev-tune <问题描述>` — 直接描述问题，跳过引导
- `/dev-tune review` — 回顾最近 5 次 /dev 执行，总结模式

根据参数判断进入哪个模式：
- 无参数 → 交互式诊断（Step 1 引导提问）
- 有文本 → 直接进入 Step 2 分析
- `review` → 进入 review 模式

---

## 交互式诊断流程

### Step 1: 诊断 — 定位问题

读取当前工作流配置文件，建立上下文：

```
必读文件（按优先级）：
1. .claude/skills/dev/SKILL.md         — /dev skill 定义
2. CLAUDE.md                            — 开发工作流 section
3. AGENTS.md                            — agent 角色定义
```

如果用户没有描述具体问题，用 AskUserQuestion 引导选择：

```
你遇到了什么问题？

A) 分级不准 — S/M/L 判断经常偏大或偏小
B) 审批太多/太少 — 打扰频率不对
C) Quality Gate 问题 — review 太慢/漏检/误报
D) Agent 角色问题 — agent 产出质量不好/职责不清
E) 流程缺失 — 某个场景没覆盖到
F) 其他 — 请描述
```

### Step 2: 分析 — 定位修改目标

根据问题类型，精确定位需要修改的文件和 section：

| 问题类型 | 修改文件 | 修改内容 |
|---------|---------|---------|
| A 分级不准 | SKILL.md + CLAUDE.md | 调整信号词列表和分级阈值 |
| B 审批频率 | SKILL.md | 调整各级别的审批节点和自动跳过规则 |
| C Quality Gate | SKILL.md + CLAUDE.md | 调整门禁触发条件和 skill 组合策略 |
| D Agent 角色 | AGENTS.md | 调整职责边界/约束条件/测试要求 |
| E 流程缺失 | SKILL.md | 新增处理分支或场景覆盖 |
| F 其他 | 视情况定 | 先分析再决定 |

读取对应文件的相关 section，提取当前配置值。

### Step 3: 提出修改方案

输出格式：

```
## 问题诊断
<一句话总结问题根因>

## 当前配置
<摘录当前相关配置片段>

## 建议修改
<用 diff 格式展示变更>

## 修改理由
<为什么这样改，预期效果是什么>
```

关键：展示 before/after 对比，让用户能快速判断。

### Step 4: 应用修改

等待用户确认后，用 Edit tool 修改对应文件。

修改完成后提交：
```bash
git add <修改的文件>
git commit -m "fix(workflow): <具体改了什么>"
```

### Step 5: 记录优化历史

将本次优化追加到 memory 文件，格式：

```markdown
## YYYY-MM-DD /dev-tune: <问题简述>
- 问题类型：<A-F>
- 修改文件：<文件列表>
- 变更摘要：<一句话>
```

写入路径：项目的 memory 目录下 `workflow_tuning.md`

### Step 6: 同步通用仓库

如果本次修改涉及通用内容（分级逻辑、pipeline 流程、quality gate 规则、agent 协作规则），而非项目特定内容（具体技术栈、文件路径），则同步到通用仓库。

**判断标准：**
- 通用内容：S/M/L 分级信号词、审批节点数量、quality gate 触发条件、agent 派发规则、pipeline 阶段行为
- 项目特定：具体技术栈引用、具体文件路径、具体 agent 角色技术细节

**同步流程：**
1. 读取通用仓库对应文件（`~/Works/Project/agent-dev-workflow/`）
2. 将通用改动泛化后写入（去掉项目特定引用，保持 `<placeholder>` 风格）
3. 提交并推送：
```bash
cd ~/Works/Project/agent-dev-workflow
git add -A
git commit -m "fix(workflow): <具体改了什么>"
git push
```
4. 通知用户："已同步到 agent-dev-workflow 仓库"

**如果改动纯属项目特定，跳过此步。**

---

## `/dev-tune review` 模式

回顾最近工作流执行情况，生成优化建议。

### 数据采集

1. 读取最近 git log，筛选 `/dev` 相关 commit（关键词：feat/fix/refactor + workflow）
2. 读取 `.context/retros/` 目录下最近的 retro 数据（如果存在）
3. 读取 memory 中的 `workflow_tuning.md` 历史记录

### 分析维度

- 哪些 skill 最常被触发？哪些从未使用？
- PR 平均包含几个 commit？规模分布如何？
- Agent 任务完成率：成功/失败/需要人工介入的比例
- 最近 5 次 /dev 执行的耗时趋势

### 输出格式

```
## /dev 工作流回顾（最近 N 次执行）

### 执行摘要
<统计数据表格>

### 发现的模式
<好的模式 + 需要改进的模式>

### 优化建议
<具体的、可执行的建议，按优先级排列>
```

---

## 关键原则

1. **单点修改** — 每次只改一件事，不做大重构，降低引入新问题的风险
2. **必须提交** — 改完立即 commit，保持完整的变更历史，可随时回滚
3. **记录到 memory** — 让未来对话知道工作流经历了哪些调整，避免反复踩坑
4. **数据驱动** — review 模式基于实际执行数据，不凭感觉优化
