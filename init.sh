#!/bin/bash

# init.sh - OA-MOCHU-reset 项目环境初始化脚本
# 用法: bash init.sh

set -e

echo "========================================"
echo "  OA-MOCHU-reset 项目环境初始化"
echo "========================================"
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo -e "${YELLOW}[1/6] 检查环境...${NC}"

# 检查 Node.js
if ! command -v node &> /dev/null; then
    echo -e "${RED}错误: 未安装 Node.js${NC}"
    exit 1
fi
echo -e "  Node.js: $(node -v)"

# 检查 npm
if ! command -v npm &> /dev/null; then
    echo -e "${RED}错误: 未安装 npm${NC}"
    exit 1
fi
echo -e "  npm: $(npm -v)"

# 检查 Git
if ! command -v git &> /dev/null; then
    echo -e "${RED}错误: 未安装 Git${NC}"
    exit 1
fi
echo -e "  Git: $(git --version | cut -d' ' -f3)"

echo ""
echo -e "${YELLOW}[2/6] 创建目录结构...${NC}"

# 创建后端目录
mkdir -p backend/routes
mkdir -p backend/models
mkdir -p backend/middleware
mkdir -p backend/services
mkdir -p backend/scripts
mkdir -p backend/uploads

# 创建前端目录
mkdir -p frontend/src/pages
mkdir -p frontend/src/services
mkdir -p frontend/src/components
mkdir -p frontend/public

echo -e "${GREEN}  ✓ 目录结构创建完成${NC}"

echo ""
echo -e "${YELLOW}[3/6] 创建后端 package.json...${NC}"

cat > backend/package.json << 'EOF'
{
  "name": "oa-mochu-backend",
  "version": "1.0.0",
  "description": "MOCHU OA Backend - 虚拟项目转实体&中止功能",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js"
  },
  "dependencies": {
    "express": "^4.21.0",
    "better-sqlite3": "^11.10.0",
    "bcryptjs": "^2.4.3",
    "jsonwebtoken": "^9.0.3",
    "multer": "^1.4.5-lts.1",
    "cors": "^2.8.5",
    "node-cron": "^3.0.3"
  },
  "devDependencies": {
    "nodemon": "^3.1.9"
  }
}
EOF

echo -e "${GREEN}  ✓ backend/package.json 创建完成${NC}"

echo ""
echo -e "${YELLOW}[4/6] 创建前端 package.json...${NC}"

cat > frontend/package.json << 'EOF'
{
  "name": "oa-mochu-frontend",
  "version": "1.0.0",
  "description": "MOCHU OA Frontend - 虚拟项目转实体&中止功能",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "react": "^19.0.0",
    "react-dom": "^19.0.0",
    "react-router-dom": "^7.13.1",
    "antd": "^5.29.3",
    "axios": "^1.13.6",
    "dayjs": "^1.11.19",
    "@ant-design/icons": "^5.6.1"
  },
  "devDependencies": {
    "@types/react": "^19.0.0",
    "@types/react-dom": "^19.0.0",
    "@vitejs/plugin-react": "^4.4.1",
    "vite": "^7.3.1"
  }
}
EOF

echo -e "${GREEN}  ✓ frontend/package.json 创建完成${NC}"

echo ""
echo -e "${YELLOW}[5/6] 安装依赖...${NC}"

cd backend
if [ ! -d "node_modules" ]; then
    npm install
    echo -e "${GREEN}  ✓ 后端依赖安装完成${NC}"
else
    echo -e "${GREEN}  ✓ 后端依赖已存在${NC}"
fi

cd ../frontend
if [ ! -d "node_modules" ]; then
    npm install
    echo -e "${GREEN}  ✓ 前端依赖安装完成${NC}"
else
    echo -e "${GREEN}  ✓ 前端依赖已存在${NC}
fi

cd ..

echo ""
echo -e "${YELLOW}[6/6] 检查 Git...${NC}"

if [ -d ".git" ]; then
    echo -e "${GREEN}  ✓ Git 仓库已初始化${NC}"
else
    git init
    echo -e "${GREEN}  ✓ Git 仓库初始化完成${NC}"
fi

echo ""
echo "========================================"
echo -e "${GREEN}  环境初始化完成！${NC}"
echo "========================================"
echo ""
echo "下一步:"
echo "  1. 查看任务列表: cat task.json"
echo "  2. 开始开发: 阅读 CLAUDE.md"
echo "  3. 自动运行: bash run_agent.sh 5"
echo ""
