#!/bin/bash

# ============================================================
# GLM Agent 循环运行脚本
# 用法: ./run_glm.sh <循环次数>
# 示例: ./run_glm.sh 10  # 运行10次开发流程
# ============================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_section() {
    echo ""
    echo -e "${PURPLE}============================================================${NC}"
    echo -e "${PURPLE}$1${NC}"
    echo -e "${PURPLE}============================================================${NC}"
}

# 检查参数
if [ -z "$1" ]; then
    log_error "缺少参数：循环次数"
    echo "用法: $0 <循环次数>"
    echo "示例: $0 10  # 运行10次开发流程"
    exit 1
fi

ITERATIONS=$1

# 验证参数是数字
if ! [[ "$ITERATIONS" =~ ^[0-9]+$ ]]; then
    log_error "参数必须是数字: $ITERATIONS"
    exit 1
fi

# 工作目录
WORK_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$WORK_DIR"

log_section "GLM Agent 循环运行脚本启动"
log_info "工作目录: $WORK_DIR"
log_info "计划运行次数: $ITERATIONS"
log_info "开始时间: $(date '+%Y-%m-%d %H:%M:%S')"

# 检查必要文件
if [ ! -f "task.json" ]; then
    log_error "task.json 不存在！"
    exit 1
fi

if [ ! -f "CLAUDE.md" ]; then
    log_error "CLAUDE.md 不存在！"
    exit 1
fi

# 创建日志目录
LOG_DIR="$WORK_DIR/logs"
mkdir -p "$LOG_DIR"

# 统计变量
SUCCESS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

# 主循环
for i in $(seq 1 $ITERATIONS); do
    log_section "第 $i/$ITERATIONS 次迭代"
    
    # 生成日志文件名
    LOG_FILE="$LOG_DIR/iteration_$i_$(date '+%Y%m%d_%H%M%S').log"
    
    log_info "日志文件: $LOG_FILE"
    
    # 检查是否还有待处理的任务
    PENDING_COUNT=$(grep -c '"status": "pending"' task.json 2>/dev/null || echo "0")
    
    if [ "$PENDING_COUNT" -eq 0 ]; then
        log_warning "没有待处理的任务了！"
        log_info "所有任务已完成或被阻塞"
        SKIP_COUNT=$((SKIP_COUNT + 1))
        break
    fi
    
    log_info "当前待处理任务数: $PENDING_COUNT"
    
    # 显示当前任务状态统计
    COMPLETED_COUNT=$(grep -c '"status": "completed"' task.json 2>/dev/null || echo "0")
    IN_PROGRESS_COUNT=$(grep -c '"status": "in_progress"' task.json 2>/dev/null || echo "0")
    BLOCKED_COUNT=$(grep -c '"status": "blocked"' task.json 2>/dev/null || echo "0")
    
    log_info "任务统计 - 待处理: $PENDING_COUNT | 进行中: $IN_PROGRESS_COUNT | 已完成: $COMPLETED_COUNT | 阻塞: $BLOCKED_COUNT"
    
    # 记录开始时间
    START_TIME=$(date +%s)
    
    log_info "开始调用 GLM Agent..."
    
    # 构建 prompt
    PROMPT="请严格按照 CLAUDE.md 中的工作流程执行：

1. 首先运行 ./init.sh 初始化环境（如果是第一次）
2. 读取 progress.txt 了解项目进展
3. 从 task.json 中领取一个 status='pending' 的任务
4. 开发实现该任务
5. 测试验证
6. 更新 progress.txt 和 task.json
7. Git 提交代码

注意：
- 一次只处理一个任务
- 遇到困难及时在 progress.txt 中记录并标记任务为 blocked
- 完成后更新任务状态为 completed

请开始工作！"

    # 调用 GLM
    # 使用 openclaw 命令（如果可用）
    if command -v openclaw &> /dev/null; then
        log_info "使用 openclaw 命令调用..."
        echo "$PROMPT" | openclaw chat --model glm-5 2>&1 | tee "$LOG_FILE"
        EXIT_CODE=${PIPESTATUS[1]}
    # 使用 claude 命令（如果可用）
    elif command -v claude &> /dev/null; then
        log_info "使用 claude 命令调用..."
        echo "$PROMPT" | claude --model glm-5 --permission-mode autoAccept 2>&1 | tee "$LOG_FILE"
        EXIT_CODE=${PIPESTATUS[1]}
    else
        log_error "未找到可用的 AI 命令 (openclaw/claude)"
        log_info "请确保已安装并配置好 AI CLI 工具"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        continue
    fi
    
    # 记录结束时间
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    
    # 检查执行结果
    if [ $EXIT_CODE -eq 0 ]; then
        log_success "第 $i 次迭代完成！耗时: ${DURATION}秒"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    else
        log_error "第 $i 次迭代失败！退出码: $EXIT_CODE, 耗时: ${DURATION}秒"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
    
    # 显示 Git 状态
    log_info "Git 状态:"
    git status --short 2>/dev/null || log_warning "无法获取 Git 状态"
    
    # 检查是否有未提交的更改
    if [ -n "$(git status --porcelain)" ]; then
        log_warning "有未提交的更改，可能需要手动处理"
    fi
    
    # 如果不是最后一次，等待一段时间
    if [ $i -lt $ITERATIONS ]; then
        WAIT_TIME=5
        log_info "等待 ${WAIT_TIME} 秒后继续..."
        sleep $WAIT_TIME
    fi
done

# 最终报告
log_section "执行完成报告"
log_info "总迭代次数: $ITERATIONS"
log_success "成功次数: $SUCCESS_COUNT"
log_error "失败次数: $FAIL_COUNT"
log_warning "跳过次数: $SKIP_COUNT"
log_info "结束时间: $(date '+%Y-%m-%d %H:%M:%S')"

# 最终任务统计
log_section "最终任务状态"
PENDING=$(grep -c '"status": "pending"' task.json 2>/dev/null || echo "0")
COMPLETED=$(grep -c '"status": "completed"' task.json 2>/dev/null || echo "0")
IN_PROGRESS=$(grep -c '"status": "in_progress"' task.json 2>/dev/null || echo "0")
BLOCKED=$(grep -c '"status": "blocked"' task.json 2>/dev/null || echo "0")

echo -e "  ${CYAN}待处理:${NC} $PENDING"
echo -e "  ${YELLOW}进行中:${NC} $IN_PROGRESS"
echo -e "  ${GREEN}已完成:${NC} $COMPLETED"
echo -e "  ${RED}已阻塞:${NC} $BLOCKED"

# 计算完成率
TOTAL=$((PENDING + COMPLETED + IN_PROGRESS + BLOCKED))
if [ $TOTAL -gt 0 ]; then
    COMPLETION_RATE=$(echo "scale=2; $COMPLETED * 100 / $TOTAL" | bc)
    log_info "完成率: ${COMPLETION_RATE}%"
fi

log_section "脚本结束"

# 返回退出码
if [ $FAIL_COUNT -gt 0 ]; then
    exit 1
else
    exit 0
fi
