# claude-hooks

Claude Code hooks that send Telegram notifications when Claude finishes work or needs your confirmation.

Notifications only fire when you've been **idle for 30+ seconds** — no spam during active sessions.

## How it works

| Hook | Event | Behavior |
|------|-------|----------|
| `UserPromptSubmit` | You send a message | Records timestamp → suppresses next Stop notification |
| `Stop` | Claude finishes | Sends notification **only if idle > 30s** |
| `Notification` | Claude needs input | Always sends (Claude is blocked waiting for you) |

## Setup

**1. Create a Telegram bot**

Talk to [@BotFather](https://t.me/BotFather), run `/newbot`, save the token.
Then send a message to your bot and open:
`https://api.telegram.org/bot<TOKEN>/getUpdates` to find your `chat.id`.

**2. Clone**

```bash
git clone https://github.com/JiaWen-Shen/claude-hooks ~/Jottacloud/vibe/claude-hooks
```

**3. Add to `~/.claude/settings.json`**

```json
{
  "env": {
    "TELEGRAM_BOT_TOKEN": "your-bot-token",
    "TELEGRAM_CHAT_ID": "your-chat-id"
  },
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [{
          "type": "command",
          "command": "bash ~/Jottacloud/vibe/claude-hooks/notify-telegram.sh activity"
        }]
      }
    ],
    "Stop": [
      {
        "hooks": [{
          "type": "command",
          "command": "bash ~/Jottacloud/vibe/claude-hooks/notify-telegram.sh stop"
        }]
      }
    ],
    "Notification": [
      {
        "hooks": [{
          "type": "command",
          "command": "bash ~/Jottacloud/vibe/claude-hooks/notify-telegram.sh notification"
        }]
      }
    ]
  }
}
```

Restart Claude Code — done.

## Tuning

Edit `IDLE_THRESHOLD` in `notify-telegram.sh` (default: `30` seconds).
