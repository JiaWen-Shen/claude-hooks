# claude-hooks

Claude Code hooks that send Telegram notifications when Claude finishes work or needs your confirmation.

## What it does

| Event | Trigger | Message |
|-------|---------|---------|
| `Stop` | Claude finishes a response | ✅ Claude 完成工作了，回來看看吧 |
| `Notification` | Claude needs your input/approval | ⏸ Claude 需要你確認 + detail |

## Setup

**1. Create a Telegram bot**

Talk to [@BotFather](https://t.me/BotFather), run `/newbot`, and save the token.
Then send any message to your bot and open:
`https://api.telegram.org/bot<TOKEN>/getUpdates` to find your `chat.id`.

**2. Clone and symlink**

```bash
git clone https://github.com/JiaWen-Shen/claude-hooks ~/path/to/claude-hooks
ln -s ~/path/to/claude-hooks/notify-telegram.sh ~/.claude/notify-telegram.sh
```

**3. Add to `~/.claude/settings.json`**

```json
{
  "env": {
    "TELEGRAM_BOT_TOKEN": "your-bot-token",
    "TELEGRAM_CHAT_ID": "your-chat-id"
  },
  "hooks": {
    "Stop": [
      { "hooks": [{ "type": "command", "command": "bash ~/.claude/notify-telegram.sh stop" }] }
    ],
    "Notification": [
      { "hooks": [{ "type": "command", "command": "bash ~/.claude/notify-telegram.sh notification" }] }
    ]
  }
}
```

Restart Claude Code — done.
