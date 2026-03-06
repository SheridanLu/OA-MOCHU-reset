# OA-MOCHU-reset

> 基于 Long-running Agent 架构的 OA 系统开发项目

## 🎯 项目简介

本项目采用 Anthropic 提出的 Long-running Agent 架构，通过多个 AI Agent 跨会话协作，逐步完成 OA 系统的开发。

### 核心理念

1. **任务驱动**: 所有工作都围绕 `task.json` 中的任务展开
2. **渐进式开发**: 每个 Agent 每次只完成一个任务
3. **状态持久化**: 通过文件记录进度，实现跨会话协作
4. **自动恢复**: 任何 Agent 都能从当前状态继续工作

## 📁 项目结构

```
OA-MOCHU-reset/
├── task.json          # 任务清单（22个任务）
├── progress.txt       # 进度日志
├── CLAUDE.md          # Agent 工作指南
├── init.sh            # 环境初始化脚本
├── run_glm_agent.sh   # GLM Agent 自动运行脚本
├── run_agent.sh       # Claude Agent 运行脚本
├── .gitignore         # Git 忽略配置
├── frontend/          # 前端代码（React + Vite）
├── backend/           # 后端代码（Express）
├── data/              # 数据库文件
├── docs/              # 项目文档
└── logs/              # 运行日志
```

## 🚀 快速开始

### 1. 初始化项目

```bash
# 克隆仓库
git clone https://github.com/SheridanLu/OA-MOCHU-reset.git
cd OA-MOCHU-reset

# 添加执行权限
chmod +x init.sh run_glm_agent.sh

# 初始化环境
./init.sh
```

### 2. 运行 Agent

```bash
# 运行 1 次（单次开发流程）
./run_glm_agent.sh 1

# 运行 10 次
./run_glm_agent.sh 10

# 模拟运行（不实际执行）
./run_glm_agent.sh 5 --dry-run
```

### 3. 查看进度

```bash
# 查看任务状态
cat task.json | grep -E '"id"|"status"|"priority"' | head -30

# 查看进度日志
cat progress.txt

# 查看最近的提交
git log --oneline -10
```

## 📋 工作流程

每个 Agent 执行时都会遵循以下流程：

```
┌─────────────────────────────────────┐
│  1. 初始化环境                       │
│     - 检查项目状态                   │
│     - 运行 init.sh（首次）           │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│  2. 了解项目状态                     │
│     - 读取 CLAUDE.md                 │
│     - 读取 progress.txt              │
│     - 读取 task.json                 │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│  3. 领取任务                         │
│     - 选择优先级最高的待处理任务     │
│     - 更新状态为 in_progress         │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│  4. 执行开发                         │
│     - 创建功能分支                   │
│     - 实现 task steps                │
│     - 编写代码                       │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│  5. 测试验证                         │
│     - 运行测试                       │
│     - 手动验证                       │
│     - 检查错误                       │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│  6. 更新文档                         │
│     - 更新 progress.txt              │
│     - 更新 task.json                 │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│  7. 提交代码                         │
│     - git add .                      │
│     - git commit                     │
│     - git push                       │
└─────────────────────────────────────┘
```

## 📊 任务清单

项目包含 22 个任务，涵盖：

### 后端开发 (10 个任务)
- T001: 初始化项目结构
- T002: 数据库设计
- T003: 用户认证
- T004: 组织架构
- T005: 项目管理
- T006: 合同管理
- T007: 预算管理
- T008: 物资管理
- T009: 审批流程
- T010: 报表系统

### 前端开发 (9 个任务)
- T011: 前端框架搭建
- T012: 登录页面
- T013: 主布局导航
- T014: 组织架构页面
- T015: 项目管理页面
- T016: 合同管理页面
- T017: 预算管理页面
- T018: 物资管理页面
- T019: 报表中心页面

### 测试部署 (3 个任务)
- T020: 单元测试
- T021: 生产部署配置
- T022: 项目文档

## 🛠️ 技术栈

### 前端
- React 18
- Vite
- Ant Design 5
- Axios
- React Router

### 后端
- Express.js
- SQLite (better-sqlite3)
- JWT
- Multer

## 📖 重要文件说明

### task.json
任务清单文件，包含所有待完成的任务。**规则**:
- ✅ 只能修改 `status`、`assigned_to`、`notes` 等字段
- ❌ 不能删除任务或修改任务 ID

### progress.txt
进度日志文件，记录所有 Agent 的工作历史。**规则**:
- ✅ 只能在末尾追加新记录
- ❌ 不能修改或删除历史记录

### CLAUDE.md
Agent 工作指南，定义了标准工作流程和规范。

## ⚠️ 注意事项

1. **一次一个任务**: 每个 Agent 每次只处理一个任务
2. **遇到困难求助**: 在 progress.txt 中标记为 blocked 并详细说明
3. **规范提交**: Git commit 必须包含任务 ID
4. **保持同步**: 定期 push 到远程仓库

## 📞 支持

- GitHub Issues: https://github.com/SheridanLu/OA-MOCHU-reset/issues
- 开发者: 全能大龙虾 🦞

---

*此项目基于 Anthropic 的 Long-running Agent 架构*
