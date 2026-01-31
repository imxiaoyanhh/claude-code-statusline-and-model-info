# Statusline 脚本功能说明

> **版本**: v1.0.0
> **日期**: 2026-01-31 23:01:28

---

## 📖 功能简介

`statusline-command.sh` 是 Claude Code 的状态栏脚本，用于在 IDE 状态栏显示：
- 当前使用的模型名称
- Token 使用进度条
- Token 使用量统计

---

## ✨ 核心功能

### 1. 实时读取模型配置
从 `~/.claude/model-config.json` 读取当前使用的模型名称，支持本地代理模型（如 GLM-4.7）。

### 2. 模型名称覆盖机制
优先使用 `model-config.json` 中的配置，覆盖 Claude Code 默认传递的模型名称。

```bash
# 核心逻辑
if [ -n "$CONFIG_MODEL" ] && [ "$CONFIG_MODEL" != "null" ]; then
    model="$CONFIG_MODEL"
fi
```

### 3. Token 进度条显示
- 绿色进度条：已使用的 Token
- 灰色进度条：剩余可用 Token
- 百分比显示：使用率

### 4. 会话检测
自动识别新会话，重置 Token 统计。

---

## 📋 显示格式

```
glm-4.7 | ████████░░░░░░░░░ 111k/200k (55%) | Tokens:111292
```

| 部分 | 说明 |
|------|------|
| `glm-4.7` | 当前模型名称 |
| `████████░░░░░░░░░` | 进度条（16格） |
| `111k/200k` | 已用/总量 Token |
| `(55%)` | 使用百分比 |
| `Tokens:111292` | 具体 Token 数量 |

---

## 🔧 配置要求

### 必需工具
- **jq**: JSON 解析工具
- **bash**: Shell 环境

### 配置变量
```bash
JQ_PATH="/f/develop/miniconda/Library/mingw-w64/bin/jq.exe"  # jq 可执行文件路径
DEFAULT_MODEL="unknown"                                        # 默认模型名称
DEFAULT_CONTEXT=200000                                         # 默认上下文大小
```

---

## 📁 相关文件

| 文件 | 路径 |
|------|------|
| 脚本位置 | `~/.claude/statusline-command.sh` |
| 模型配置 | `~/.claude/model-config.json` |
| 状态文件 | `~/.claude/statusline-state.json` |

---

## 🔄 工作流程

```
1. 读取 model-config.json 获取模型名称
              ↓
2. 接收 Claude Code 传递的 input_json
              ↓
3. 使用 model-config.json 的值覆盖 input_json 中的模型
              ↓
4. 计算 Token 使用量和进度条
              ↓
5. 输出格式化的状态栏信息
```

---

## 🐛 常见问题

### Q: Statusline 显示错误的模型名称？
**A**: 检查 `~/.claude/model-config.json` 文件内容是否正确。

### Q: 进度条不显示？
**A**: 确认 jq 路径配置正确，且 jq 可执行。

### Q: Token 数量不准确？
**A**: 重启 IDE 或删除 `~/.claude/statusline-state.json` 重置统计。
