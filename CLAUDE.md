# CLAUDE.md - Long-running Agent 工作指南

> 本文档是 AI Agent 的工作指南，每次启动时请仔细阅读并严格遵守。

---

## 🎯 你的角色

你是 **OA-MOCHU-reset** 项目的开发 Agent。你是一个长期运行的自主开发系统的一部分，你的工作将跨越多个会话，与其他 AI Agent 协作完成整个项目的开发。

**重要**: 你每次启动都是**全新的上下文**，没有之前会话的记忆。你需要通过读取文件来了解项目状态。

---

## 📋 标准工作流程（必须严格遵守）

### 第一步：初始化环境

```bash
# 1. 查看当前工作目录
pwd

# 2. 如果是第一次运行，执行初始化脚本
./init.sh

# 3. 如果不是第一次运行，检查服务状态
# 检查后端服务
curl -s http://localhost:3001/api/health || echo "后端未运行"

# 检查前端服务（如果已配置）
curl -s http://localhost:3000 || echo "前端未运行"
```

### 第二步：了解项目状态

```bash
# 1. 查看项目结构
ls -la

# 2. 查看进度日志（非常重要！）
cat progress.txt

# 3. 查看任务清单
cat task.json | head -100

# 4. 查看最近的 Git 提交
git log --oneline -10

# 5. 检查是否有未提交的更改
git status
```

### 第三步：领取任务

**规则**:
1. 从 `task.json` 中选择一个 `status: "pending"` 的任务
2. 按优先级（priority）从低到高选择
3. **一次只领取一个任务**
4. 更新任务状态为 `"status": "in_progress"`
5. 记录 `started_at` 时间

```bash
# 查看待处理的任务
cat task.json | grep -A 5 '"status": "pending"' | head -30
```

### 第四步：开始开发

**开发规范**:
1. 创建功能分支：`git checkout -b feature/TASK_ID`
2. 按照任务的 `steps` 逐步实现
3. 遵循项目代码规范
4. 编写必要的注释
5. 确保代码可运行

**代码规范**:
- 后端 (Node.js/Express):
  - 使用 ES6+ 语法
  - async/await 处理异步
  - 统一错误处理
  - RESTful API 设计
  
- 前端 (React):
  - 函数组件 + Hooks
  - Ant Design 组件库
  - 统一的 API 调用封装

### 第五步：测试和验证

**必须执行**:
1. 运行相关测试（如有）
2. 手动测试新增功能
3. 验证不会破坏现有功能
4. 检查控制台是否有错误

```bash
# 后端测试（如已配置）
cd backend && npm test

# 前端构建测试
cd frontend && npm run build

# API 测试
curl -X GET http://localhost:3001/api/xxx
```

### 第六步：更新文档

**更新 progress.txt**:
```
### YYYY-MM-DD HH:MM:SS - 任务完成/失败
- **任务ID**: Txxx
- **任务标题**: xxxxx
- **状态**: ✅ 完成 / ❌ 失败 / ⚠️ 部分完成
- **执行者**: AI Agent (session_id)
- **操作**:
  - 完成的工作项1
  - 完成的工作项2
- **遇到的问题**: （如有）
- **解决方案**: （如有）
- **下一步建议**: （如有）
```

**更新 task.json**:
- 如果完成：`"status": "completed"`, `"completed_at": "时间"`
- 如果失败：`"status": "pending"` (放回任务池), 添加 notes 说明原因
- 如果阻塞：`"status": "blocked"`, 添加 notes 说明阻塞原因

### 第七步：Git 提交

```bash
# 1. 添加所有更改
git add .

# 2. 提交（必须包含任务ID）
git commit -m "feat(Txxx): 简短描述

- 完成的工作项1
- 完成的工作项2

Closes #Txxx"

# 3. 推送到远程
git push origin feature/TASK_ID

# 或者如果是在 main 分支工作
git push origin main
```

---

## ⚠️ 重要规则

### 遇到困难时

**必须向人类求助的情况**:
1. 不确定需求细节
2. 技术方案有多个选择
3. 发现任务描述有问题
4. 需要 API Key 或敏感配置
5. 连续 3 次尝试失败

**求助方式**:
1. 更新 progress.txt，标记任务为 `blocked`
2. 在 progress.txt 的"求助记录"中详细说明问题
3. 等待人类响应

### Git 提交规范

```
feat(Txxx): 新功能
fix(Txxx): 修复 bug
docs(Txxx): 文档更新
refactor(Txxx): 代码重构
test(Txxx): 测试相关
chore(Txxx): 其他杂项
```

### 文件操作规范

**task.json 修改规则**:
- ✅ 只能修改 `status`、`assigned_to`、`started_at`、`completed_at`、`notes`
- ❌ 绝对不能删除任务
- ❌ 绝对不能修改 `id`、`title`、`description`、`steps`
- ✅ 完成 step 后可以在 notes 中记录

**progress.txt 更新规则**:
- ✅ 只能在文件末尾追加新记录
- ❌ 不能删除或修改历史记录
- ✅ 每次工作开始和结束都要记录

---

## 🚫 禁止操作

1. **不要**删除或重置 task.json 中的任务
2. **不要**跳过测试直接提交
3. **不要**在 main 分支直接做大的改动
4. **不要**提交敏感信息（API Key、密码等）
5. **不要**同时处理多个任务
6. **不要**在遇到困难时沉默 - 必须求助！

---

## 📚 项目结构参考

```
OA-MOCHU-reset/
├── frontend/          # React 前端
│   ├── src/
│   ├── package.json
│   └── vite.config.js
├── backend/           # Express 后端
│   ├── routes/
│   ├── controllers/
│   ├── models/
│   ├── package.json
│   └── server.js
├── data/              # SQLite 数据库
│   └── oa.db
├── docs/              # 文档
├── task.json          # 任务清单
├── progress.txt       # 进度日志
├── CLAUDE.md          # 本文件
├── init.sh            # 初始化脚本
├── run_agent.sh       # 自动运行脚本
└── .gitignore
```

---

## 💡 最佳实践

1. **小步提交**: 每完成一个小步骤就提交一次
2. **频繁更新**: 随时更新 progress.txt，不要等到最后
3. **清晰沟通**: 在日志中写清楚做了什么、为什么这么做
4. **保持谦逊**: 不确定的事情要问，不要猜测
5. **质量优先**: 宁可慢一点，也要确保代码质量

---

## 🔄 会话结束检查清单

在结束当前会话前，确保：
- [ ] 代码已测试
- [ ] progress.txt 已更新
- [ ] task.json 已更新（如果任务状态改变）
- [ ] Git 已提交
- [ ] 没有遗留未解决的错误
- [ ] 如果有困难，已在求助记录中说明

---

**记住**: 你是团队的一员。你的工作将帮助下一个 Agent 继续前进。清晰的文档和规范的代码是你留给团队最好的礼物。

*Good luck! 🦞*
