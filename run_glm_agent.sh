#!/bin/bash

# ============================================
# OA-MOCHU-reset GLM Agent 自动运行脚本
# ============================================
# 
# 用法: ./run_glm_agent.sh <次数> [选项]
# 示例: ./run_glm_agent.sh 10
#       ./run_glm_agent.sh 5 --dry-run
#
# 此脚本会循环调用 GLM Agent，
# 每次 Agent 会执行一次完整的开发流程
# ============================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# 配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
SESSION_LOG=""  # 将在运行时设置
DELAY_BETWEEN_RUNS=3
MAX_RETRIES=3

# 日志函数
timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $(timestamp) - $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $(timestamp) - $1"
}

log_warning() {
    echo -e "${YELLOW}[⚠]${NC} $(timestamp) - $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $(timestamp) - $1"
}

log_agent() {
    echo -e "${PURPLE}[AGENT]${NC} $(timestamp) - $1"
}

log_divider() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# 显示帮助
show_usage() {
    cat << EOF
用法: $0 <运行次数> [选项]

参数:
  运行次数    Agent 执行的次数 (1-1000)

选项:
  --dry-run       只显示将要执行的操作，不实际运行
  --no-delay      运行之间不等待
  --delay <秒>    设置运行间隔（默认 3 秒）
  --help          显示此帮助信息

示例:
  $0 1              # 运行 1 次
  $0 10             # 运行 10 次
  $0 100            # 运行 100 次
  $0 5 --dry-run    # 模拟运行 5 次
  $0 10 --delay 5   # 运行 10 次，每次间隔 5 秒

注意:
  - 每次运行都会执行完整的开发流程（领取任务 -> 开发 -> 测试 -> 提交）
  - 如果所有任务完成，脚本会自动停止
  - 遇到困难时 Agent 会自动记录到 progress.txt

EOF
    exit 0
}

# 检查依赖
check_dependencies() {
    log_info "检查系统依赖..."
    
    local missing=()
    
    # 检查必要文件
    if [ ! -f "$SCRIPT_DIR/CLAUDE.md" ]; then
        log_error "未找到 CLAUDE.md"
        missing+=("CLAUDE.md")
    fi
    
    if [ ! -f "$SCRIPT_DIR/task.json" ]; then
        log_error "未找到 task.json"
        missing+=("task.json")
    fi
    
    if [ ! -f "$SCRIPT_DIR/progress.txt" ]; then
        log_error "未找到 progress.txt"
        missing+=("progress.txt")
    fi
    
    if [ ${#missing[@]} -gt 0 ]; then
        log_error "缺少必要文件: ${missing[*]}"
        log_info "请先运行 ./init.sh 初始化项目"
        exit 1
    fi
    
    log_success "所有依赖文件就绪"
}

# 设置日志
setup_logging() {
    mkdir -p "$LOG_DIR"
    SESSION_LOG="$LOG_DIR/session_$(date '+%Y%m%d_%H%M%S').log"
    touch "$SESSION_LOG"
    log_info "会话日志: $SESSION_LOG"
}

# 获取任务统计
get_task_stats() {
    local json_file="$SCRIPT_DIR/task.json"
    
    if [ ! -f "$json_file" ]; then
        echo "任务文件不存在"
        return
    fi
    
    # 使用 grep 和 wc 统计（兼容性好）
    local total=$(grep -o '"id":' "$json_file" | wc -l | tr -d ' ')
    local completed=$(grep -o '"status": "completed"' "$json_file" | wc -l | tr -d ' ')
    local pending=$(grep -o '"status": "pending"' "$json_file" | wc -l | tr -d ' ')
    local in_progress=$(grep -o '"status": "in_progress"' "$json_file" | wc -l | tr -d ' ')
    
    echo "📊 总计: $total | ✅ 完成: $completed | 🔄 进行中: $in_progress | ⏳ 待处理: $pending"
}

# 获取下一个待处理任务
get_next_task() {
    local json_file="$SCRIPT_DIR/task.json"
    
    # 简单地查找第一个 pending 状态的任务 ID
    grep -B 5 '"status": "pending"' "$json_file" | grep '"id"' | head -1 | cut -d'"' -f4
}

# 运行单次 Agent
run_agent_once() {
    local run_number=$1
    local total_runs=$2
    local dry_run=$3
    
    echo ""
    log_divider
    log_agent "🚀 第 ${BOLD}${run_number}/${total_runs}${NC} 次运行"
    log_divider
    echo ""
    
    # 显示当前状态
    log_info "$(get_task_stats)"
    
    local next_task=$(get_next_task)
    if [ -n "$next_task" ]; then
        log_info "下一个任务: $next_task"
    else
        log_success "🎉 没有待处理任务了！"
        return 99  # 特殊码：全部完成
    fi
    
    if [ "$dry_run" = "true" ]; then
        log_warning "[DRY-RUN] 模拟运行 - 不会执行实际操作"
        log_info "将要执行的开发流程:"
        echo "  1. 读取 CLAUDE.md 了解工作流程"
        echo "  2. 读取 progress.txt 了解项目进展"
        echo "  3. 从 task.json 领取任务: $next_task"
        echo "  4. 执行开发工作"
        echo "  5. 更新文档和任务状态"
        echo "  6. Git 提交代码"
        return 0
    fi
    
    # 记录开始时间
    local start_time=$(date +%s)
    
    log_info "启动 Agent 执行开发流程..."
    echo ""
    
    # 构建提示词
    local prompt="
你是一个长期运行的自主开发 Agent。请严格按照以下流程执行：

## 工作流程

### 第一步：了解项目状态
1. 运行: pwd（确认工作目录）
2. 读取 CLAUDE.md 文件了解工作流程
3. 读取 progress.txt 了解项目进展
4. 读取 task.json 查看任务列表
5. 运行: git status 检查当前状态

### 第二步：领取任务
1. 从 task.json 中找一个 status 为 pending 的任务
2. 选择优先级最高（priority 数字最小）的任务
3. 一次只领取一个任务

### 第三步：执行开发
1. 创建功能分支: git checkout -b feature/TASK_ID
2. 按任务的 steps 逐步实现
3. 遵循代码规范
4. 确保代码可运行

### 第四步：测试验证
1. 运行相关测试（如有）
2. 手动测试新增功能
3. 检查控制台错误

### 第五步：更新文档
1. 更新 progress.txt 记录工作内容
2. 更新 task.json 标记任务状态

### 第六步：提交代码
1. git add .
2. git commit -m \"feat(TASK_ID): 描述\"
3. 如果配置了远程仓库: git push

## 重要规则
- 遇到困难必须在 progress.txt 中记录并求助
- 不要删除或修改已完成任务的描述
- 保持代码质量

请开始工作！当前是第 $run_number 次运行。
"
    
    # 调用 OpenClaw/GLM
    # 注意：这里假设你通过 OpenClaw 运行，它会自动处理模型调用
    # 如果需要直接调用，请根据你的环境调整
    
    log_info "Agent 正在工作中..."
    log_info "提示词已准备好，等待模型响应..."
    
    # 方式1：如果使用 OpenClaw CLI
    if command -v openclaw &> /dev/null; then
        log_info "检测到 OpenClaw CLI"
        # 这里需要根据 OpenClaw 的实际 API 调整
        # 暂时记录提示词
        echo "$prompt" > "$SCRIPT_DIR/.current_prompt.txt"
        log_warning "请手动运行: openclaw chat 或你的调用方式"
        log_info "提示词已保存到: .current_prompt.txt"
    else
        # 方式2：提示用户手动操作
        log_warning "未检测到自动调用方式"
        log_info "请手动将以下内容发送给你的 AI 模型："
        echo ""
        echo "━━━━━━ 提示词开始 ━━━━━━"
        echo "$prompt"
        echo "━━━━━━ 提示词结束 ━━━━━━"
        echo ""
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # 检查任务状态是否改变
    local new_stats=$(get_task_stats)
    log_info "运行后状态: $new_stats"
    
    log_success "第 $run_number 次运行流程完成 (耗时: ${duration}s)"
    
    return 0
}

# 主函数
main() {
    local runs=1
    local dry_run=false
    local no_delay=false
    
    # 解析参数
    if [ $# -eq 0 ]; then
        show_usage
    fi
    
    # 第一个参数：运行次数
    if [[ $1 =~ ^[0-9]+$ ]]; then
        runs=$1
        shift
    else
        case "$1" in
            --help|-h)
                show_usage
                ;;
            *)
                log_error "无效的运行次数: $1"
                show_usage
                ;;
        esac
    fi
    
    # 验证范围
    if [ "$runs" -lt 1 ] || [ "$runs" -gt 1000 ]; then
        log_error "运行次数必须在 1-1000 之间"
        exit 1
    fi
    
    # 解析选项
    while [ $# -gt 0 ]; do
        case "$1" in
            --dry-run)
                dry_run=true
                shift
                ;;
            --no-delay)
                no_delay=true
                shift
                ;;
            --delay)
                DELAY_BETWEEN_RUNS=$2
                shift 2
                ;;
            --help|-h)
                show_usage
                ;;
            *)
                log_error "未知选项: $1"
                show_usage
                ;;
        esac
    done
    
    # 显示启动信息
    echo ""
    echo -e "${BOLD}╔══════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║   OA-MOCHU-reset GLM Agent Runner   ║${NC}"
    echo -e "${BOLD}╚══════════════════════════════════════╝${NC}"
    echo ""
    log_info "计划运行次数: ${BOLD}$runs${NC}"
    log_info "Dry Run 模式: $dry_run"
    log_info "运行间隔: ${DELAY_BETWEEN_RUNS}s"
    log_info "工作目录: $SCRIPT_DIR"
    echo ""
    
    # 检查依赖
    check_dependencies
    
    # 设置日志
    setup_logging
    
    # 显示初始状态
    log_info "初始任务状态:"
    log_info "$(get_task_stats)"
    echo ""
    
    # 主循环
    local success_count=0
    local fail_count=0
    local consecutive_fails=0
    local i=1
    
    while [ $i -le $runs ]; do
        if run_agent_once $i $runs $dry_run; then
            ((success_count++))
            consecutive_fails=0
        else
            local exit_code=$?
            if [ $exit_code -eq 99 ]; then
                # 所有任务完成
                log_success "🎉 所有任务已完成！提前结束运行"
                break
            fi
            
            ((fail_count++))
            ((consecutive_fails++))
            
            if [ $consecutive_fails -ge $MAX_RETRIES ]; then
                log_error "连续失败 $consecutive_fails 次"
                read -p "是否继续？(y/n): " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    log_info "用户终止运行"
                    break
                fi
                consecutive_fails=0
            fi
        fi
        
        # 等待间隔
        if [ "$no_delay" = "false" ] && [ $i -lt $runs ]; then
            log_info "等待 ${DELAY_BETWEEN_RUNS}s 后继续..."
            sleep $DELAY_BETWEEN_RUNS
        fi
        
        ((i++))
    done
    
    # 显示总结
    echo ""
    log_divider
    echo -e "${BOLD}              运行总结              ${NC}"
    log_divider
    echo ""
    log_info "总运行次数: $((success_count + fail_count))"
    log_success "成功: $success_count"
    if [ $fail_count -gt 0 ]; then
        log_error "失败: $fail_count"
    fi
    echo ""
    log_info "最终任务状态:"
    log_info "$(get_task_stats)"
    echo ""
    log_info "会话日志: $SESSION_LOG"
    echo ""
    log_divider
    echo ""
}

# 捕获中断信号
trap 'echo ""; log_warning "收到中断信号，正在退出..."; exit 130' INT TERM

# 运行主函数
main "$@"
