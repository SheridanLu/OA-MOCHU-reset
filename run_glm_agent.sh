#!/bin/bash

# ============================================
# OA-MOCHU-reset GLM Agent 自动运行脚本
# ============================================
# 
# 用法: ./run_glm_agent.sh <次数> [选项]
# 此脚本会在当前会话中触发 Agent 执行开发流程
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
SESSION_LOG=""
DELAY_BETWEEN_RUNS=3

# 日志函数
timestamp() { date '+%Y-%m-%d %H:%M:%S'; }
log_info() { echo -e "${BLUE}[INFO]${NC} $(timestamp) - $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $(timestamp) - $1"; }
log_warning() { echo -e "${YELLOW}[⚠]${NC} $(timestamp) - $1"; }
log_error() { echo -e "${RED}[✗]${NC} $(timestamp) - $1"; }
log_agent() { echo -e "${PURPLE}[AGENT]${NC} $(timestamp) - $1"; }
log_divider() { echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; }

# 显示帮助
show_usage() {
    cat << EOF
用法: $0 <运行次数> [选项]

参数:
  运行次数    Agent 执行的次数 (1-100)

选项:
  --dry-run       只生成提示词，不实际运行
  --no-delay      运行之间不等待
  --help          显示帮助

示例:
  $0 1              # 运行 1 次
  $0 10             # 运行 10 次

注意:
  - 此脚本会生成 .agent_task 文件，标记当前需要执行的任务
  - Agent 读取该文件后执行对应任务
  - 完成后更新 task.json 和 progress.txt

EOF
    exit 0
}

# 获取任务统计（使用 Python 解析 JSON 更准确）
get_task_stats() {
    python3 << 'PYEOF'
import json
try:
    with open('task.json', 'r', encoding='utf-8') as f:
        data = json.load(f)
    tasks = data.get('tasks', [])
    total = len(tasks)
    completed = sum(1 for t in tasks if t.get('status') == 'completed')
    pending = sum(1 for t in tasks if t.get('status') == 'pending')
    in_progress = sum(1 for t in tasks if t.get('status') == 'in_progress')
    print(f"📊 总计: {total} | ✅ 完成: {completed} | 🔄 进行中: {in_progress} | ⏳ 待处理: {pending}")
except Exception as e:
    print(f"读取任务失败: {e}")
PYEOF
}

# 获取下一个待处理任务
get_next_task() {
    python3 << 'PYEOF'
import json
try:
    with open('task.json', 'r', encoding='utf-8') as f:
        data = json.load(f)
    tasks = data.get('tasks', [])
    pending = [t for t in tasks if t.get('status') == 'pending']
    if pending:
        # 按优先级排序
        pending.sort(key=lambda x: x.get('priority', 999))
        task = pending[0]
        print(f"{task['id']}|{task['title']}")
except Exception as e:
    print(f"ERROR:{e}")
PYEOF
}

# 生成 Agent 任务文件
generate_agent_task() {
    local task_info=$1
    local task_id=$(echo "$task_info" | cut -d'|' -f1)
    local task_title=$(echo "$task_info" | cut -d'|' -f2)
    
    cat > "$SCRIPT_DIR/.agent_task" << EOF
# 当前任务
- 任务ID: $task_id
- 任务标题: $task_title
- 分配时间: $(date '+%Y-%m-%d %H:%M:%S')

## 执行指令

请按照 CLAUDE.md 中的工作流程执行以下操作：

1. **读取项目文件**
   - 读取 task.json 找到任务 $task_id 的详细信息
   - 读取 progress.txt 了解项目进展
   - 读取 CLAUDE.md 了解工作规范

2. **更新任务状态**
   - 将 task.json 中 $task_id 的 status 改为 "in_progress"
   - 设置 started_at 为当前时间

3. **执行开发工作**
   - 按照任务的 steps 逐步实现
   - 遵循 acceptance_criteria 验收标准

4. **更新进度**
   - 完成后更新 progress.txt 记录工作内容
   - 更新 task.json 标记任务完成

5. **提交代码**
   - git add .
   - git commit -m "feat($task_id): $task_title"

开始工作！
EOF
    echo "$SCRIPT_DIR/.agent_task"
}

# 主函数
main() {
    local runs=1
    local dry_run=false
    local no_delay=false
    
    # 解析参数
    while [ $# -gt 0 ]; do
        case "$1" in
            --help|-h) show_usage ;;
            --dry-run) dry_run=true; shift ;;
            --no-delay) no_delay=true; shift ;;
            [0-9]*) runs=$1; shift ;;
            *) log_error "未知选项: $1"; show_usage ;;
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
    log_info "工作目录: $SCRIPT_DIR"
    echo ""
    
    # 检查依赖
    if [ ! -f "$SCRIPT_DIR/task.json" ]; then
        log_error "未找到 task.json"
        exit 1
    fi
    
    # 显示初始状态
    log_info "初始任务状态: $(get_task_stats)"
    echo ""
    
    # 主循环
    local i=1
    while [ $i -le $runs ]; do
        log_divider
        log_agent "🚀 第 ${BOLD}${i}/${runs}${NC} 次运行"
        log_divider
        
        # 获取下一个任务
        local task_info=$(get_next_task)
        
        if [[ "$task_info" == ERROR:* ]] || [ -z "$task_info" ]; then
            log_success "🎉 没有待处理任务了！"
            break
        fi
        
        local task_id=$(echo "$task_info" | cut -d'|' -f1)
        local task_title=$(echo "$task_info" | cut -d'|' -f2)
        
        log_info "领取任务: $task_id - $task_title"
        
        if [ "$dry_run" = "true" ]; then
            log_warning "[DRY-RUN] 模拟运行"
            generate_agent_task "$task_info"
            log_info "任务文件已生成: $SCRIPT_DIR/.agent_task"
            cat "$SCRIPT_DIR/.agent_task"
        else
            # 生成任务文件
            generate_agent_task "$task_info"
            log_info "任务文件已生成: $SCRIPT_DIR/.agent_task"
            
            # 输出提示词供外部 Agent 使用
            echo ""
            echo "══════════════════════════════════════════════════════════════"
            echo "请将以下内容发送给 Agent 执行："
            echo "══════════════════════════════════════════════════════════════"
            cat "$SCRIPT_DIR/.agent_task"
            echo "══════════════════════════════════════════════════════════════"
            echo ""
            
            # 标记任务为 in_progress
            python3 << PYEOF
import json
with open('task.json', 'r+', encoding='utf-8') as f:
    data = json.load(f)
    for task in data['tasks']:
        if task['id'] == '$task_id':
            task['status'] = 'in_progress'
            task['started_at'] = '$(date -Iseconds)'
            break
    f.seek(0)
    json.dump(data, f, ensure_ascii=False, indent=2)
    f.truncate()
print("任务 $task_id 已标记为进行中")
PYEOF
            
            log_success "任务 $task_id 已准备就绪，等待 Agent 执行"
            log_info "Agent 完成后请更新 task.json 和 progress.txt"
        fi
        
        # 显示当前状态
        log_info "当前状态: $(get_task_stats)"
        
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
    log_info "最终任务状态: $(get_task_stats)"
    log_divider
}

main "$@"
