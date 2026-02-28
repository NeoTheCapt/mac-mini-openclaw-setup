# Mac mini 从零安装 OpenClaw + Telegram Bot（完整步骤）

这份文档面向「全新买回来的 Mac mini」：从开机初始化，到安装 OpenClaw、启动 Gateway、配置 Telegram Bot 并完成 DM 配对（pairing）。

> 安全提示：**不要把 Telegram bot token、OpenAI key、OpenRouter key 等密钥提交到 GitHub。**本文档所有 token 都用占位符表示。

## 目标（你最终会得到什么）

- Mac mini 上安装完成 OpenClaw CLI
- Gateway 作为后台服务运行（daemon）
- 可以通过 Control UI 本地聊天（不依赖 Telegram）
- Telegram Bot 配置完成，并能在 Telegram DM 里稳定对话

## 目录

- [0. 准备工作](#0-准备工作)
- [1. Mac mini 首次开机初始化](#1-mac-mini-首次开机初始化)
- [2. 安装基础工具（Xcode CLT / Homebrew）](#2-安装基础工具xcode-clt--homebrew)
- [3. 安装 Node.js 22+](#3-安装-nodejs-22)
- [4. 安装 OpenClaw](#4-安装-openclaw)
- [5. 运行 onboarding（生成配置 + 安装 daemon）](#5-运行-onboarding生成配置--安装-daemon)
- [6. 启动并验证 Gateway / Control UI](#6-启动并验证-gateway--control-ui)
- [7. 创建 Telegram Bot（BotFather）](#7-创建-telegram-botbotfather)
- [8. 配置 OpenClaw 的 Telegram Channel](#8-配置-openclaw-的-telegram-channel)
- [9. Telegram DM 配对（pairing approve）](#9-telegram-dm-配对pairing-approve)
- [10. 常见故障排查](#10-常见故障排查)
- [附录：Anthropic（Claude）认证配置](#附录anthropicclaude认证配置)

---

## 0. 准备工作

你需要：

- 一台全新 Mac mini（Apple Silicon 或 Intel 都可）
- 稳定的外网（能访问 `api.telegram.org`、模型提供商 API 等）
- 一个 Telegram 账号
- 一个模型提供商账号（例如 OpenAI / OpenRouter 等）

建议准备：

- 记录密钥的安全工具（1Password / Apple Keychain / Bitwarden）

---

## 1. Mac mini 首次开机初始化

1. 连接显示器/键鼠/网络，开机。
2. 完成 macOS Setup Assistant：
   - 语言/地区
   - Wi‑Fi / 以太网
   - Apple ID（可选，但建议登录，方便后续更新）
   - 创建本地管理员用户
3. 进入桌面后：
   - 打开 **System Settings → General → Software Update**，先把系统更新到当前稳定版本。

> 可选：如果你计划做远程运维，建议开启 Remote Login（SSH）：
> System Settings → General → Sharing → Remote Login。

---

## 2. 安装基础工具（Xcode CLT / Homebrew）

### 2.1 安装 Xcode Command Line Tools

打开 Terminal，执行：

```bash
xcode-select --install
```

弹窗安装完成后，验证：

```bash
xcode-select -p
clang --version
```

### 2.2 安装 Homebrew

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

安装完成后按提示把 brew 加到 PATH（Apple Silicon 通常是）：

```bash
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"
```

验证：

```bash
brew --version
```

---

## 3. 安装 Node.js 22+

OpenClaw 要求 Node 22+。

### 方案 A：让 OpenClaw 官方安装脚本自动安装（推荐）

如果你不想自己装 Node，直接跳到第 4 步使用安装脚本即可。

### 方案 B：用 Homebrew 安装 Node 22

```bash
brew install node@22
brew link --force --overwrite node@22
```

验证：

```bash
node -v   # 期望 v22.x 或更高
npm -v
```

---

## 4. 安装 OpenClaw

推荐用官方 installer：

```bash
curl -fsSL https://openclaw.ai/install.sh | bash
```

> 该脚本会处理 Node 检测/安装，并引导你进入 onboarding。

如果你已经有 Node 22+，也可以用 npm：

```bash
npm install -g openclaw@latest
```

验证：

```bash
openclaw --version
openclaw help
```

---

## 5. 运行 onboarding（生成配置 + 安装 daemon）

```bash
openclaw onboard --install-daemon
```

这一步会按向导配置关键项（建议选 QuickStart 先跑通）：

- **Model/Auth（模型与密钥）**：选择 OpenAI / Anthropic / OpenRouter 或自定义兼容提供商，并录入 API key
  - 建议用“secret reference”/环境变量方式保存密钥（不要硬写进文档或 git）
- **Workspace**：默认 `~/.openclaw/workspace/`
- **Gateway**：默认端口 18789，loopback 绑定 + token auth
- **Channels（可选）**：也可以在这里直接配置 Telegram（后面第 8 节也给了手工配置方式）
- **Daemon**：macOS 下安装并启动 LaunchAgent（让 Gateway 常驻）

完成后检查：

```bash
openclaw gateway status
```

---

## 6. 启动并验证 Gateway / Control UI

### 6.1 打开 Control UI

```bash
openclaw dashboard
```

或者浏览器打开：

- `http://127.0.0.1:18789/`

只要 Control UI 能正常打开，说明 Gateway 基本 OK。

### 6.2 基本健康检查

```bash
openclaw status
openclaw doctor
```

---

## 7. 创建 Telegram Bot（BotFather）

1. 在 Telegram 搜索并打开 **@BotFather**。
2. 执行 `/newbot`。
3. 按提示设置 bot 名称与 username。
4. BotFather 会返回一个 token，形如：

```
1234567890:AA....
```

**把 token 安全保存**（不要发群、不要上 GitHub）。

> 如果你需要 bot 在群里看见所有消息：
> - BotFather `/setprivacy` → Disable
> - 然后把 bot 移出群再加回去让设置生效

---

## 8. 配置 OpenClaw 的 Telegram Channel

Telegram 不需要 `openclaw channels login`，只需要把 bot token 写进配置，然后重启 gateway。

### 8.1 写入配置（推荐用 openclaw config set）

```bash
openclaw config set channels.telegram.enabled true
openclaw config set channels.telegram.botToken '"<YOUR_TELEGRAM_BOT_TOKEN>"'
openclaw config set channels.telegram.dmPolicy '"pairing"'
```

> `dmPolicy: pairing` 是推荐默认值：任何新 DM 都需要你 approve。

### 8.2 重启 gateway

```bash
openclaw gateway restart
```

### 8.3 检查 channel 状态

```bash
openclaw channels status
```

---

## 9. Telegram DM 配对（pairing approve）

1. 用你的 Telegram 账号去 **私聊你的 bot**，随便发一句：

> hi

2. 在 Mac mini 终端查看待审批列表：

```bash
openclaw pairing list telegram
```

3. 你会看到一个 code，然后 approve：

```bash
openclaw pairing approve telegram <CODE> --notify
```

4. 现在你再跟 bot 说话，它就会回复了。

---

## 10. 常见故障排查

### 10.1 `openclaw` 找不到命令

检查 global npm bin 是否在 PATH：

```bash
npm prefix -g
echo $PATH
```

如果缺失，把 `$(npm prefix -g)/bin` 加到 `~/.zshrc`。

### 10.2 Telegram 不回消息

- 确认 Gateway 运行：`openclaw gateway status`
- 确认 token 配置正确（不要有多余空格）
- 看日志：
  ```bash
  openclaw logs --follow
  ```
- 如果 `setMyCommands failed` 或网络错误：通常是 DNS/HTTPS 出网问题。

### 10.3 群里看不到消息

- BotFather `/setprivacy` 关闭隐私模式
- 让 bot 变成管理员，或移出群再加回

---

## 附录：Anthropic（Claude）认证配置

- 详见：[`docs/02-anthropic-auth.md`](docs/02-anthropic-auth.md)

## License

MIT
