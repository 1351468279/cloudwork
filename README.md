# ⚡ CloudWork: AI Coding Agent 掌上指挥官

<p align="center">
  <strong>一款专为重度 AI 开发者打造的开源、中立、零配置（Zero-Config）移动端 Agent 遥控指挥中心</strong>
</p>

<p align="center">
  <a href="#核心特色">核心特色</a> •
  <a href="#系统架构">系统架构</a> •
  <a href="#快速启动">快速启动</a> •
  <a href="#支持的-agent">支持的 Agent</a> •
  <a href="#开源与自托管">开源与自托管</a>
</p>

---

## 🌟 为什么选择 CloudWork？

当你在电脑前使用 **Claude Code**、**Codex CLI** 或 **Aider** 执行重构、跑单测或多文件修改等长耗时任务时，无需肉身死守屏幕：

- 🛋️ **离开电脑，躺在沙发上遥控**：离开工位，手机随时查看 Agent 思考进度与实时标准输出。
- 🔔 **异步系统推送唤醒**：Agent 任务完成、遇到报错或等待权限授权时，系统级通知秒速推送至手机。
- ⚡ **一键审批卡片 (y/n)**：告别在手机软键盘上笨拙地敲 `y` 和回车，交互式原生大按钮一键允许或拒绝危险命令。
- 🔒 **零配置 & 端到端加密（E2EE）**：100% 继承你电脑本地现有的 API Key 与配置（`.env`, `config.toml`, `settings.json`），手机端不碰任何敏感 Key，中继服务器零知识存储。
- 📁 **最近工作区直连**：自动读取电脑端常用项目与 Git 仓库，手机端一键切换派发任务。

---

## 🏗️ 系统架构

```
┌─────────────────────────────────┐       E2EE WebSocket       ┌─────────────────────────────────┐
│       移动端 (Flutter App)       │ <========================> │     电脑端 (Go Desktop Daemon)    │
│  • 任务指派与 Prompt 快捷芯片     │      (公网穿透/局域网直连)     │  • 子进程/PTY 管理器             │
│  • 交互式审批卡片 (y/n)          │                            │  • 自动继承本地 Agent 环境与凭据   │
│  • Git Diff 手机端审查           │                            │  • 动态终端二维码配对             │
└─────────────────────────────────┘                            └────────────────┬────────────────┘
                                                                                │ 进程托管 / 管道拦截
                                                               ┌────────────────▼────────────────┐
                                                               │ 受控 Agent: Claude/Codex/Aider   │
                                                               └─────────────────────────────────┘
```

---

## 🚀 快速启动

### 1. 在电脑端启动守护进程

无需任何额外依赖，直接运行已编译的单二进制文件：

```powershell
# 运行守护程序（自动输出终端扫码二维码）
./daemon/bin/cloudwork-daemon.exe
```

### 2. 手机端连接体验

- 打开手机 App 扫描电脑终端显示的二维码即可瞬间完成握手与设备绑定。
- 在本地测试阶段，也可直接在浏览器中打开 [`web/index.html`](file:///e:/privateproject/cloudwork/web/index.html) 进行即时体验。

---

## 🤖 深度适配的 Agent 清单

| Agent | 接入机制 | 交互特色 |
| :--- | :--- | :--- |
| **OpenAI Codex CLI** | `codex exec --json` 管道流 | 结构化 JSONL 事件流解析，秒级响应，沙箱审批拦截 |
| **Anthropic Claude Code** | `claude -p` 非交互/交互桥接 | 自动关闭 stdin EOF 消除等待，精准捕获 Bash 工具调用 |
| **Aider** | Stdio 模式 / 参数化调用 | 支持 Git Commit 变动捕获与自动化修改 |
| **通用 CLI 工具** | 通用终端管道 + 启发式检测 | 自动识别 `[y/N]`、`Password:` 等待输入事件 |

---

## 🌐 开源与自建中继服务 (Docker)

CloudWork 官方提供免费高可用的 E2EE 中继通道。如果你希望 100% 私有化部署中继服务，只需一行 Docker 命令：

```bash
cd relay
docker compose up -d
```

服务即在 `9289` 端口就绪，可在客户端中将中继地址替换为你自己的服务器域名（如 `wss://relay.your-domain.com/v1/tunnel`）。

---

## 📄 开源许可证

本项目采用 **Apache License 2.0** 开源许可证。
