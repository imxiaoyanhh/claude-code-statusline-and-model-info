#!/bin/bash

# 默认值
DEFAULT_MODEL="unknown"
DEFAULT_CONTEXT=200000
BLOCK="█"
JQ_PATH="/f/develop/miniconda/Library/mingw-w64/bin/jq.exe"

# ============================================
# 从 model-config.json 读取当前模型配置
# ============================================
MODEL_CONFIG_FILE="$HOME/.claude/model-config.json"
if [ -f "$MODEL_CONFIG_FILE" ] && [ -x "$JQ_PATH" ]; then
    CONFIG_MODEL=$("$JQ_PATH" -r '.model // empty' "$MODEL_CONFIG_FILE" 2>/dev/null)
    if [ -n "$CONFIG_MODEL" ] && [ "$CONFIG_MODEL" != "null" ]; then
        DEFAULT_MODEL="$CONFIG_MODEL"
    fi
fi

# 读取 JSON 输入
input_json=$(cat)

# 输入验证 - 无输入时显示默认值
if [ -z "$input_json" ]; then
    gray_bar=$(seq 1 16 | while read i; do printf "${BLOCK}"; done)
    echo -e "$DEFAULT_MODEL | \033[90m${gray_bar}\033[0m 0k/$((DEFAULT_CONTEXT/1000))k (0%) | Tokens:0"
    exit 0
fi

# 使用 jq 解析 JSON
if [ -x "$JQ_PATH" ]; then
    # 解析模型名称 - 优先使用 model-config.json 中的配置
    model=$("$JQ_PATH" -r 'if .model.display_name then .model.display_name elif .model.name then .model.name elif .model.id then .model.id else "unknown" end' <<< "$input_json")

    # 如果 model-config.json 中有配置，则覆盖从 input_json 解析出的模型名称
    if [ -n "$CONFIG_MODEL" ] && [ "$CONFIG_MODEL" != "null" ]; then
        model="$CONFIG_MODEL"
    fi

    # 清理模型名称（移除日期后缀）
    if [[ "$model" =~ ^(.+)-[0-9]{8}$ ]]; then
        model="${BASH_REMATCH[1]}"
    fi

    # 解析上下文大小
    context_size=$("$JQ_PATH" -r 'if .context_window.context_window_size then .context_window.context_window_size else "'"$DEFAULT_CONTEXT"'" end' <<< "$input_json")

    # 获取当前 token 使用量（对话级别）
    in_tokens=$("$JQ_PATH" -r 'if .context_window.current_usage.input_tokens then .context_window.current_usage.input_tokens else "0" end' <<< "$input_json")
    out_tokens=$("$JQ_PATH" -r 'if .context_window.current_usage.output_tokens then .context_window.current_usage.output_tokens else "0" end' <<< "$input_json")
    cache_create=$("$JQ_PATH" -r 'if .context_window.current_usage.cache_creation_input_tokens then .context_window.current_usage.cache_creation_input_tokens else "0" end' <<< "$input_json")
    cache_read=$("$JQ_PATH" -r 'if .context_window.current_usage.cache_read_input_tokens then .context_window.current_usage.cache_read_input_tokens else "0" end' <<< "$input_json")

    current_used=$((in_tokens + out_tokens + cache_create + cache_read))

    # 获取总 tokens（会话级别）
    total_in=$("$JQ_PATH" -r 'if .context_window.total_input_tokens then .context_window.total_input_tokens else "0" end' <<< "$input_json")
    total_out=$("$JQ_PATH" -r 'if .context_window.total_output_tokens then .context_window.total_output_tokens else "0" end' <<< "$input_json")
    current_total_tokens=$((total_in + total_out))

    # 显示 tokens：优先使用 current_used（对话级别），回退到 total_tokens
    if [ "$current_used" -gt 0 ]; then
        display_tokens=$current_used
    elif [ "$current_total_tokens" -gt 0 ]; then
        display_tokens=$current_total_tokens
    else
        display_tokens=0
    fi
else
    # jq 不可用时使用默认值
    model="$DEFAULT_MODEL"
    context_size=$DEFAULT_CONTEXT
    current_used=0
    current_total_tokens=0
    display_tokens=0
fi

# ============================================
# 会话检测和状态管理
# ============================================
STATE_FILE="$HOME/.claude/statusline-state.json"
current_time=$(date +%s%3N 2>/dev/null || echo "$(date +%s)000")

last_session_time=0
last_total_tokens=0
is_new_session=false

# 读取状态文件
if [ -f "$STATE_FILE" ] && [ -x "$JQ_PATH" ]; then
    last_session_time=$("$JQ_PATH" -r '.sessionTime // 0' "$STATE_FILE" 2>/dev/null || echo 0)
    last_total_tokens=$("$JQ_PATH" -r '.totalTokens // 0' "$STATE_FILE" 2>/dev/null || echo 0)
fi

# 检测新会话
if [ "$last_session_time" -gt 0 ]; then
    # 计算时间差（毫秒转分钟）
    time_diff_minutes=$(( (current_time - last_session_time) / 60000 ))

    # 如果超过 1 小时，状态文件过期 - 删除并视为新会话
    if [ "$time_diff_minutes" -gt 60 ]; then
        rm -f "$STATE_FILE"
        is_new_session=true
    # Token 数量显著下降 = 新对话
    elif [ "$current_total_tokens" -lt "$((last_total_tokens * 40 / 100))" ]; then
        is_new_session=true
    # 超过 5 分钟 = 很可能是新对话
    elif [ "$time_diff_minutes" -gt 5 ]; then
        is_new_session=true
    fi
else
    # 首次运行或状态文件被删除
    is_new_session=true
fi

# 更新状态文件
if [ -x "$JQ_PATH" ]; then
    "$JQ_PATH" -n \
        --argjson sessionTime "$current_time" \
        --argjson totalTokens "$current_total_tokens" \
        --argjson contextSize "$context_size" \
        '{sessionTime: $sessionTime, totalTokens: $totalTokens, contextSize: $contextSize}' > "$STATE_FILE"
fi

# ============================================
# 计算进度条
# ============================================
# 对于进度条，使用 current_used 或回退到 total_tokens
if [ -n "$current_used" ] && [ "$current_used" -gt 0 ]; then
    bar_tokens=$current_used
elif [ -n "$current_total_tokens" ] && [ "$current_total_tokens" -gt 0 ]; then
    bar_tokens=$current_total_tokens
else
    bar_tokens=0
fi

# 计算百分比
if [ "$context_size" -gt 0 ] && [ "$bar_tokens" -gt 0 ]; then
    pct=$((bar_tokens * 100 / context_size))
    if [ "$pct" -gt 100 ]; then
        pct=100
    fi
else
    pct=0
fi

current_k=$((bar_tokens / 1000))
total_k=$((context_size / 1000))

# 构建进度条（16 个方块字符）
bar_width=16
filled=$((pct * bar_width / 100))
empty=$((bar_width - filled))

if [ "$bar_tokens" -eq 0 ]; then
    # 全灰色
    progress_bar=""
    seq 1 $bar_width | while read i; do
        progress_bar="${progress_bar}\033[90m${BLOCK}\033[0m"
    done
    progress_bar="\033[90m$(seq 1 $bar_width | while read i; do printf "${BLOCK}"; done)\033[0m"
else
    # 绿色已用部分 + 灰色未用部分
    filled_part=$(seq 1 $filled | while read i; do printf "${BLOCK}"; done)
    empty_part=$(seq 1 $empty | while read i; do printf "${BLOCK}"; done)
    progress_bar="\033[32m${filled_part}\033[90m${empty_part}\033[0m"
fi

# ============================================
# 输出结果
# ============================================
echo -e "$model | ${progress_bar} ${current_k}k/${total_k}k (${pct}%) | Tokens:$display_tokens"
