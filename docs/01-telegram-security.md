# Telegram Bot 安全建议

## 1) Token 管理

- **永远不要**把 bot token 提交到 GitHub / 发群 / 截图外传。
- 建议保存到 1Password / Keychain。
- 如果怀疑泄露：立刻在 BotFather `@BotFather` 里 `/revoke`（或重新生成 token），然后更新 OpenClaw 配置并重启 gateway。

## 2) 推荐的 DM 策略：pairing

`dmPolicy: "pairing"` 的意义：

- 陌生人私聊 bot，不会直接进入对话
- 你需要在本机 `openclaw pairing approve` 才会放行

适合个人/小团队自用。

## 3) 群聊隐私模式

Telegram 默认开启 bot 隐私模式（Privacy Mode）：

- bot 只能看到被 @ 提及的消息（或命令）

如果你要 bot 看到群里所有消息：

- BotFather `/setprivacy` → Disable
- 把 bot 移出群再加回去（让设置生效）
- 或把 bot 设置为群管理员

## 4) 最小权限原则

- 如果只是 DM 自用，不要把 bot 拉进大群
- 如果必须进群：建议限制 allowlist / requireMention
