# CLAUDE.md - AI 开发指南

## 项目概述
- **项目**: OA-MOCHU-reset
- **仓库**: https://github.com/SheridanLu/OA-MOCHU-reset
- **技术栈**: React 19 + Vite 7 + Ant Design 5 | Express 4 + SQLite

## 开发工作流程

### 1. 初始化环境
```bash
bash init.sh
```

### 2. 领取任务
从 `task.json` 中选择第一个 `status: "pending"` 的任务：
```json
{
  "id": 1,
  "title": "任务标题",
  "description": "任务描述",
  "status": "pending"
}
```

**更新任务状态为 in_progress**:
```json
{
  "status": "in_progress",
  "assigned": "claude",
  "started_at": "2026-03-11T18:00:00+08:00"
}
```

### 3. 开发实现
- 每次只做 **一个任务**
- 遵循现有代码风格
- 添加必要注释

### 4. 测试验证
- 前端修改: `cd frontend && npm run build`
- 后端修改: `pm2 restart oa-server`
- 验证功能正常

### 5. 更新文档
**更新 task.json**:
```json
{
  "status": "completed",
  "completed_at": "2026-03-11T19:00:00+08:00"
}
```

**更新 progress.txt**:
```
### Session X - 2026-03-11 19:00
**任务**: Task 1 - 项目初始化
**状态**: ✅ 完成

**已完成**:
- [x] 具体工作内容

**遇到的问题**:
- 问题描述（如有）
- 解决方案
```

### 6. Git 提交
```bash
git add .
git commit -m "feat: 任务标题 (#task-id)"
git push
```

---

## 目录结构

```
OA-MOCHU-reset/
├── task.json          # 任务列表（从这里领取任务）
├── progress.txt       # 工作日志（每次完成任务后更新）
├── CLAUDE.md          # 本文件
├── init.sh            # 环境初始化脚本
├── run_agent.sh       # 自动化运行脚本
│
├── backend/           # 后端代码
│   ├── server.js      # 入口
│   ├── routes/        # API 路由
│   ├── models/        # 数据模型
│   ├── middleware/    # 中间件
│   └── database.db    # SQLite 数据库
│
└── frontend/          # 前端代码
    ├── src/
    │   ├── pages/     # 页面组件
    │   ├── services/  # API 调用
    │   ├── App.jsx    # 路由配置
    │   └── main.jsx   # 入口
    └── dist/          # 构建产物
```

---

## 功能需求

### 1. 虚拟项目转实体项目
- **审批流程**: 采购员 → 财务人员 → 总经理
- **必填信息**: 中标通知书、合同信息
- **项目编号**: 实体项目10位数字，虚拟项目8位数字
- **文件归集**: 自动将虚拟项目下文件归集到新实体项目

### 2. 虚拟项目中止
- **审批流程**: 采购员 → 财务人员 → 总经理
- **成本归集**: 选择被中止项目成本下挂项目（实体项目/综合部门成本）
- **状态保留**: 项目编号保留，信息保留，页面冻结

---

## 常用命令

```bash
# 服务管理
pm2 list                    # 查看服务
pm2 restart oa-server       # 重启后端
pm2 logs oa-server          # 查看日志

# 前端开发
cd frontend && npm run dev   # 开发模式
cd frontend && npm run build # 构建

# Git
git status
git add .
git commit -m "message"
git push
```

---

## 注意事项

1. **一次只做一个任务** - 不要同时修改多个功能
2. **保持干净状态** - 每次提交前确保代码可运行
3. **及时更新文档** - task.json 和 progress.txt
4. **遇到问题及时上报** - 更新 task.json 的 error 字段

---

## 遇到问题时

1. 将 task.json 中当前任务的 `error` 字段填写错误信息
2. 将 `status` 改为 `failed`
3. 更新 progress.txt 记录问题
4. 向用户报告问题详情
