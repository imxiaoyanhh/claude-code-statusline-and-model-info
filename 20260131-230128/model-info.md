---
description: 查看当前大模型配置信息并同步到 statusline
argument-hint: ""
allowed-tools: Read(~/.claude/model-config.json, ~/.claude/settings.json, ~/.claude/config.json, ~/.claude/statusline-command.sh)
---

## 用法

`/model-info`

## 目标

查看当前 Claude Code 的大模型配置，包括：
- 当前使用的模型名称
- API 端点地址
- 代理配置信息
- **同步确认 statusline 会显示此模型**

## 执行步骤

**步骤 1**：读取 `~/.claude/model-config.json` 文件，获取当前模型配置

**步骤 2**：读取 `~/.claude/settings.json` 文件，获取 API 端点和环境配置

**步骤 3**：读取 `~/.claude/statusline-command.sh`，确认 statusline 已配置为从 model-config.json 读取模型

**步骤 4**：以清晰的格式输出配置信息，包括：
  - ✅ **当前模型**: 显示 model 字段值
  - 🔗 **API 端点**: 显示 ANTHROPIC_BASE_URL（如果有）
  - 🔑 **认证方式**: 显示 ANTHROPIC_AUTH_TOKEN 状态
  - 📝 **备注**: 显示 note 字段（如果有）
  - 🔄 **Statusline 同步**: 确认 statusline 会自动显示此模型

## 输出格式

使用表情符号和清晰的分段，使信息易于阅读。如果配置文件不存在或格式错误，给出友好的提示。

**重要提示**：明确告知用户 statusline 会从 model-config.json 实时读取模型名称，无需手动刷新。
