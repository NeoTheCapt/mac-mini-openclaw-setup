# Anthropic（Claude）认证配置：API Key / 订阅 setup-token（一步一步）

本章把 Anthropic（Claude）在 OpenClaw 里的认证方式讲清楚，并给出 **Mac mini** 上从零到可用的完整步骤。

> 重要：不要把任何 key/token 写进 GitHub。本文所有密钥都用 `<...>` 占位。

## 你到底需要哪一种？（先选路）

OpenClaw 支持两条路：

1) **Anthropic API Key（推荐）**
- 适合：你有 Anthropic Console 的 API Key（通常是按量计费/有额度）。
- 优点：最稳、最官方、兼容所有 Claude API 请求。

2) **Claude 订阅的 setup-token（可用但不推荐）**
- 适合：你主要是 Claude 订阅用户（Pro/Max），通过 `claude setup-token` 生成一个长 token 给 OpenClaw 用。
- 注意：如果你看到错误：
  - `This credential is only authorized for use with Claude Code...`
  那就说明该 token 不能用于通用 API，请改用 **API Key**。

---

## 路线 A：配置 Anthropic API Key（推荐）

### A1. 在 Anthropic Console 创建 API Key

1. 打开 Anthropic Console（登录你的 Anthropic 账号）
2. 进入 **API Keys**（或开发者设置页）
3. 创建一个新的 key
4. 复制并安全保存：

- `ANTHROPIC_API_KEY=<YOUR_KEY>`

> 建议保存到 1Password / Keychain。不要发群、不要截图外传。

### A2. 临时验证（只对当前 Terminal 生效）

在 Mac mini 的 Terminal 执行：

```bash
export ANTHROPIC_API_KEY="<YOUR_ANTHROPIC_API_KEY>"
```

然后让 OpenClaw 做一次模型状态检查：

```bash
openclaw models status
```

如果这里能看到 Anthropic 相关 provider OK，说明 key 本身没问题。

### A3. 让 daemon（launchd）也能读到 key（关键步骤）

因为 OpenClaw Gateway 通常以 **daemon** 方式运行（macOS: launchd），它**不会继承**你当前 Terminal 的环境变量。

推荐写入 OpenClaw 专用 env 文件：`~/.openclaw/.env`

```bash
cat >> ~/.openclaw/.env <<'EOF'
ANTHROPIC_API_KEY=<YOUR_ANTHROPIC_API_KEY>
EOF
```

> `~/.openclaw/.env` 属于本机私密文件，不要纳入 git，也不要同步到公网。

### A4. 重启 Gateway

```bash
openclaw gateway restart
```

### A5. 再次验证

```bash
openclaw models status
openclaw doctor
```

到这一步，Anthropic API Key 对 **daemon + Control UI + Telegram** 都应该生效。

---

## 路线 B：配置 Claude 订阅 setup-token（一步一步）

> 这条路线依赖 **Claude Code CLI** 的 `claude` 命令。

### B1. 安装 Claude Code CLI（确保有 `claude` 命令）

Anthropic 的 CLI 安装方式可能随版本变化，请以 Anthropic 官方文档为准。

你的目标是：

```bash
claude --version
```

能正常输出版本号。

### B2. 生成 setup-token

在 **gateway host（就是这台 Mac mini）** 上执行：

```bash
claude setup-token
```

它会输出一个 token（长字符串）。

### B3. 让 OpenClaw 接管这个 token

推荐用 OpenClaw 自带命令直接写入认证档：

```bash
openclaw models auth setup-token --provider anthropic
```

如果你的 token 是在别的机器上生成的（不建议，但可行），可以在网关机器上手动粘贴：

```bash
openclaw models auth paste-token --provider anthropic
```

### B4. 验证

```bash
openclaw models status
openclaw doctor
```

如果报 “只能用于 Claude Code” 一类错误，改走路线 A（API Key）。

---

## 进阶：多 agent 场景（main + dev）如何共享 Anthropic 认证

OpenClaw 的 auth profiles 是 **按 agent 隔离**的（每个 agent 一个 `auth-profiles.json`）。

路径类似：

- `~/.openclaw/agents/main/agent/auth-profiles.json`
- `~/.openclaw/agents/dev/agent/auth-profiles.json`

如果你希望 `dev` agent 也能用同一套 Anthropic 凭证：

- **API Key 路线**：只要 daemon 能读到 `~/.openclaw/.env` 里的 `ANTHROPIC_API_KEY`，通常就够用。
- **setup-token 路线**：可能需要把 `main` 的 `auth-profiles.json` 复制到 `dev` 对应目录（注意不要覆盖掉 dev 里其他 provider 凭证）。

建议做法是：优先用 API Key，然后用 `openclaw models status` 分 agent 验证（如果你用多 agent）。

---

## 最小化自检清单

- [ ] `openclaw gateway status` 显示 running
- [ ] `openclaw models status` 能看到 Anthropic provider OK
- [ ] `openclaw doctor` 无 auth 报错
- [ ] Control UI 能正常对话（`openclaw dashboard`）
