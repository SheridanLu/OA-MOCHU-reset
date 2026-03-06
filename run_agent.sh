#!/bin/bash

# ============================================
# OA-MOCHU-reset Agent 自动运行脚本
# ============================================
# 
# 用法: ./run_agent.sh <次数> [选项]
# 示例: ./run_agent.sh 10
#       ./run_agent.sh 5 --dry-run
#
# 此脚本会循环调用 GLM Agent，
# 每次 Agent 会：
# 1. 读取 CLAUDE.md 了解工作流程
# 2. 读取 progress.txt 了解项目进展
# 3. 从 task.json 领取一个任务
# 4. 执行开发工作
# 5. 更新文档并提交代码
# ============================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# 配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
PROMPT_FILE="$SCRIPT_DIR/agent_prompt.txt"
MAX_RETRIES=3
DELAY_BETWEEN_RUNS=5

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

log_agent() {
    echo -e "${PURPLE}[AGENT]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# 显示使用帮助
show_usage() {
    echo "用法: $0 <运行次数> [选项]"
    echo ""
    echo "参数:"
    echo "  运行次数    Agent 执行的次数 (1-100)"
    echo ""
    echo "选项:"
    echo "  --dry-run   只显示将要执行的操作，不实际运行"
    echo "  --no-delay  运行之间不等待"
    echo "  --help      显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 1              # 运行 1 次"
    echo "  $0 10             # 运行 10 次"
    echo "  $0 5 --dry-run    # 模拟运行 5 次"
    exit 0
}

# 检查依赖
check_dependencies() {
    log_info "检查依赖..."
    
    # 检查 claude 命令是否存在
    if ! command -v claude &> /dev/null; then
        log_error "未找到 'claude' 命令"
        log_info "请先安装 Claude CLI: npm install -g @anthropic-ai/claude-code"
        exit 1
    fi
    
    # 检查必要文件
    if [ ! -f "$SCRIPT_DIR/CLAUDE.md" ]; then
        log_error "未找到 CLAUDE.md 文件"
        exit 1
    fi
    
    if [ ! -f "$SCRIPT_DIR/task.json" ]; then
        log_error "未找到 task.json 文件"
        exit 1
    fi
    
    log_success "依赖检查通过"
}

# 创建日志目录
setup_logging() {
    mkdir -p "$LOG_DIR"
    
    # 创建本次运行的日志文件
    RUN_LOG="$LOG_DIR/run_$(date '+%Y%m%d_%H%M%S').log"
    touch "$RUN_LOG"
    
    log_info "日志文件: $RUN_LOG"
}

# 创建 Agent 提示词
create_agent_prompt() {
    cat > "$PROMPT_FILE" << 'EOF'
你是一个长期运行的自主开发 Agent。请严格按照 CLAUDE.md 中定义的工作流程执行：

1. 首先，读取 CLAUDE.md 文件了解工作流程和规范
2. 然后，读取 progress.txt 了解项目的最新进展
3. 接着，查看 task.json，找到一个状态为 "pending" 且优先级最高的任务
4. 执行该任务的开发工作，遵循任务中的 steps
5. 完成后，更新 progress.txt 和 task.json
6. 最后，用 git 提交所有更改

重要提示：
- 一次只处理一个任务
- 遇到困难时必须在 progress.txt 中记录并求助
- 所有 git commit 必须包含任务 ID
- 不要跳过测试环节

请开始工作！
EOF
}

# 获取任务统计
get_task_stats() {
    local total=$(grep -c '"id":' "$SCRIPT_DIR/task.json" 2>/dev/null || echo "0")
    local completed=$(grep -c '"status": "completed"' "$SCRIPT_DIR/task.json" 2>/dev/null || echo "0")
    local pending=$(grep -c '"status": "pending"' "$SCRIPT_DIR/task.json" 2>/dev/null || echo "0")
    local in_progress=$(grep -c '"status": "in_progress"' "$SCRIPT_DIR/task.json" 2>/dev/null || echo "0")
    
    echo "总任务: $total | 已完成: $completed | 进行中: $in_progress | 待处理: $pending"
}

# 运行单次 Agent
run_agent_once() {
    local run_number=$1
    local dry_run=$2
    
    log_agent "========== 第 $run_number 次运行 =========="
    
    # 显示当前状态
    log_info "当前任务状态: $(get_task_stats)"
    
    if [ "$dry_run" = "true" ]; then
        log_warning "[DRY-RUN] 将执行: claude --dangerously-skip-permissions -p \"\$(cat $PROMPT_FILE)\""
        return 0
    fi
    
    # 记录开始时间
    local start_time=$(date +%s)
    
    # 调用 Claude
    log_info "启动 Agent..."
    
    # 使用 --dangerously-skip-permissions 自动跳过所有权限确认
    # 使用 --allowedTools 指定允许的工具
    # 使用 -p 传入提示词
    if claude --dangerously-skip-permissions \
              --allowedTools "Read,Write,Edit,Bash,Glob,Grep" \
              -p "$(cat $PROMPT_FILE)" \
              2>&1 | tee -a "$RUN_LOG"; then
        
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        log_success "第 $run_number 次运行完成 (耗时: ${duration}s)"
        log_info "更新后的任务状态: $(get_task_stats)"
        
        # 检查是否还有待处理任务
        local pending=$(grep -c '"status": "pending"' "$SCRIPT_DIR/task.json" 2>/dev/null || echo "0")
        if [ "$pending" -eq 0 ]; then
            log_success "🎉 所有任务已完成！"
            return 99  # 特殊退出码表示全部完成
        fi
        
        return 0
    else
        log_error "第 $run_number 次运行失败"
        return 1
    fi
}

# 主函数
main() {
    # 解析参数
    local runs=1
    local dry_run=false
    local no_delay=false
    
    # 检查参数
    if [ $# -eq 0 ]; then
        show_usage
    fi
    
    # 解析第一个参数（运行次数）
    if [[ $1 =~ ^[0-9]+$ ]]; then
        runs=$1
        shift
    else
        log_error "无效的运行次数: $1"
        show_usage
    fi
    
    # 验证运行次数范围
    if [ "$runs" -lt 1 ] || [ "$runs" -gt 100 ]; then
        log_error "运行次数必须在 1-100 之间"
        exit 1
    fi
    
    # 解析其他选项
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
            --help|-h)
                show_usage
                ;;
            *)
                log_error "未知选项: $1"
                show_usage
                ;;
        esac
    done
    
    # 显示 banner
    echo ""
    echo "========================================"
    echo "  OA-MOCHU-reset Agent Runner"
    echo "========================================"
    echo ""
    log_info "计划运行次数: $runs"
    log_info "Dry Run 模式: $dry_run"
    log_info "工作目录: $SCRIPT_DIR"
    echo ""
    
    # 检查依赖
    check_dependencies
    
    # 设置日志
    setup_logging
    
    # 创建提示词
    create_agent_prompt
    
    # 主循环
    local success_count=0
    local fail_count=0
    local i=1
    
    while [ $i -le $runs ]; do
        echo ""
        log_info "进度: $i / $runs (成功: $success_count, 失败: $fail_count)"
        
        if run_agent_once $i $dry_run; then
            ((success_count++))
        else
            ((fail_count++))
            
            # 如果连续失败，询问是否继续
            if [ $fail_count -ge $MAX_RETRIES ]; then
                log_error "连续失败 $fail_count 次"
                read -p "是否继续？(y/n): " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    log_info "用户终止运行"
                    break
                fi
                fail_count=0  # 重置失败计数
            fi
        fi
        
        # 检查是否全部完成
        if [ $? -eq 99 ]; then
            break
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
    echo "========================================"
    echo "  运行完成"
    echo "========================================"
    log_info "总运行次数: $((success_count + fail_count))"
    log_success "成功: $success_count"
    log_error "失败: $fail_count"
    log_info "最终任务状态: $(get_task_stats)"
    log_info "详细日志: $RUN_LOG"
    echo ""
}

# 运行主函数
main "$@"
