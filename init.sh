#!/bin/bash

# ============================================
# OA-MOCHU-reset 项目初始化脚本
# ============================================

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 显示 banner
show_banner() {
    echo "========================================"
    echo "  OA-MOCHU-reset 项目初始化"
    echo "  基于 Long-running Agent 架构"
    echo "========================================"
    echo ""
}

# 检查依赖
check_dependencies() {
    log_info "检查系统依赖..."
    
    local missing=()
    
    # 检查 Node.js
    if ! command -v node &> /dev/null; then
        missing+=("Node.js")
    else
        log_success "Node.js $(node -v) 已安装"
    fi
    
    # 检查 npm
    if ! command -v npm &> /dev/null; then
        missing+=("npm")
    else
        log_success "npm $(npm -v) 已安装"
    fi
    
    # 检查 Git
    if ! command -v git &> /dev/null; then
        missing+=("Git")
    else
        log_success "Git $(git --version | awk '{print $3}') 已安装"
    fi
    
    if [ ${#missing[@]} -gt 0 ]; then
        log_error "缺少以下依赖: ${missing[*]}"
        log_info "请先安装这些依赖后再运行此脚本"
        exit 1
    fi
}

# 创建目录结构
create_directories() {
    log_info "创建项目目录结构..."
    
    mkdir -p frontend/src/{components,pages,services,utils,hooks,assets}
    mkdir -p frontend/public
    mkdir -p backend/{routes,controllers,models,middleware,utils}
    mkdir -p data/backups
    mkdir -p docs
    mkdir -p logs
    
    log_success "目录结构创建完成"
}

# 初始化后端
init_backend() {
    log_info "初始化后端项目..."
    
    if [ ! -f "backend/package.json" ]; then
        cat > backend/package.json << 'EOF'
{
  "name": "oa-mochu-backend",
  "version": "1.0.0",
  "description": "OA-MOCHU Backend Server",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js",
    "test": "jest"
  },
  "dependencies": {
    "express": "^4.18.2",
    "cors": "^2.8.5",
    "better-sqlite3": "^9.2.2",
    "jsonwebtoken": "^9.0.2",
    "bcryptjs": "^2.4.3",
    "dotenv": "^16.3.1",
    "multer": "^1.4.5-lts.1",
    "uuid": "^9.0.0"
  },
  "devDependencies": {
    "nodemon": "^3.0.2",
    "jest": "^29.7.0"
  }
}
EOF
        log_success "backend/package.json 创建完成"
    else
        log_warning "backend/package.json 已存在，跳过"
    fi
    
    # 创建基础 server.js
    if [ ! -f "backend/server.js" ]; then
        cat > backend/server.js << 'EOF'
const express = require('express');
const cors = require('cors');
const path = require('path');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3001;

// 中间件
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// 健康检查
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// API 路由（待实现）
// app.use('/api/auth', require('./routes/auth'));
// app.use('/api/projects', require('./routes/projects'));
// app.use('/api/contracts', require('./routes/contracts'));

// 错误处理
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ error: '服务器内部错误' });
});

app.listen(PORT, () => {
  console.log(`🚀 后端服务运行在 http://localhost:${PORT}`);
});
EOF
        log_success "backend/server.js 创建完成"
    fi
}

# 初始化前端
init_frontend() {
    log_info "初始化前端项目..."
    
    if [ ! -f "frontend/package.json" ]; then
        cat > frontend/package.json << 'EOF'
{
  "name": "oa-mochu-frontend",
  "version": "1.0.0",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-router-dom": "^6.20.0",
    "antd": "^5.12.0",
    "axios": "^1.6.2",
    "@ant-design/icons": "^5.2.6"
  },
  "devDependencies": {
    "@vitejs/plugin-react": "^4.2.0",
    "vite": "^5.0.0"
  }
}
EOF
        log_success "frontend/package.json 创建完成"
    else
        log_warning "frontend/package.json 已存在，跳过"
    fi
    
    # 创建 vite.config.js
    if [ ! -f "frontend/vite.config.js" ]; then
        cat > frontend/vite.config.js << 'EOF'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    port: 3000,
    proxy: {
      '/api': {
        target: 'http://localhost:3001',
        changeOrigin: true
      }
    }
  }
})
EOF
        log_success "frontend/vite.config.js 创建完成"
    fi
}

# 创建环境变量模板
create_env_template() {
    log_info "创建环境变量模板..."
    
    if [ ! -f ".env.example" ]; then
        cat > .env.example << 'EOF'
# 后端配置
PORT=3001
NODE_ENV=development

# JWT 配置
JWT_SECRET=your-super-secret-jwt-key-change-in-production
JWT_EXPIRES_IN=7d

# 数据库配置
DB_PATH=./data/oa.db

# 前端配置
VITE_API_BASE_URL=http://localhost:3001/api
EOF
        log_success ".env.example 创建完成"
    fi
    
    # 复制为实际配置
    if [ ! -f ".env" ]; then
        cp .env.example .env
        log_success ".env 创建完成（从模板复制）"
    fi
}

# 安装依赖
install_dependencies() {
    log_info "安装项目依赖..."
    
    # 后端依赖
    if [ -f "backend/package.json" ]; then
        log_info "安装后端依赖..."
        cd backend
        npm install
        cd ..
        log_success "后端依赖安装完成"
    fi
    
    # 前端依赖
    if [ -f "frontend/package.json" ]; then
        log_info "安装前端依赖..."
        cd frontend
        npm install
        cd ..
        log_success "前端依赖安装完成"
    fi
}

# 初始化 Git
init_git() {
    log_info "检查 Git 状态..."
    
    if [ ! -d ".git" ]; then
        git init
        log_success "Git 仓库初始化完成"
    else
        log_warning "Git 仓库已存在，跳过初始化"
    fi
}

# 显示完成信息
show_completion() {
    echo ""
    echo "========================================"
    log_success "项目初始化完成！"
    echo "========================================"
    echo ""
    echo "📁 项目结构:"
    echo "   ├── frontend/     前端 (React + Vite)"
    echo "   ├── backend/      后端 (Express)"
    echo "   ├── data/         数据库文件"
    echo "   ├── docs/         文档"
    echo "   ├── task.json     任务清单"
    echo "   ├── progress.txt  进度日志"
    echo "   └── CLAUDE.md     工作指南"
    echo ""
    echo "🚀 快速开始:"
    echo "   1. cd backend && npm run dev    # 启动后端"
    echo "   2. cd frontend && npm run dev   # 启动前端"
    echo "   3. ./run_agent.sh 1             # 运行 Agent"
    echo ""
    echo "📚 文档:"
    echo "   - 工作指南: cat CLAUDE.md"
    echo "   - 任务清单: cat task.json"
    echo "   - 进度日志: cat progress.txt"
    echo ""
}

# 主函数
main() {
    show_banner
    check_dependencies
    create_directories
    init_backend
    init_frontend
    create_env_template
    init_git
    
    # 询问是否安装依赖
    read -p "是否现在安装依赖？(y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        install_dependencies
    else
        log_warning "跳过依赖安装，请稍后手动运行: cd backend && npm install && cd ../frontend && npm install"
    fi
    
    show_completion
}

# 运行主函数
main
