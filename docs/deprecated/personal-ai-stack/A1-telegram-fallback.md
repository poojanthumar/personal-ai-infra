# 05 — Telegram Bot

> ## ⚠️ SUPERSEDED BY OPENCLAW
>
> **[File 15 — OpenClaw](07-openclaw.md) is the recommended front door.** It gives
> you WhatsApp plus a dozen other channels, MCP support, and a model that picks
> tools for you instead of you typing exact commands.
>
> **Keep this file for two reasons:**
> 1. **Fallback.** If WhatsApp automation gets your number banned, or OpenClaw
>    proves too unstable, this works and has no ban risk.
> 2. **It is much simpler to debug.** ~150 lines you fully understand. Build it
>    first if OpenClaw is fighting you — it proves the queue works end to end.
>
> **Two changes if you use this now:**
> - The hub is the **Oracle queue API** (file 04), not a Cloudflare Worker
> - Drop the `/music` command — music is out of scope


> ⚠️ **Anything marked ⚠️ in this file is unverified.** All of it is answered
> by the prompt in [⚠️ Verify with AI](#-verify-with-ai) at the bottom — paste it
> into Gemini or any web-enabled AI and update this file with the result.

---

**Goal:** the fastest way to reach your AI from your phone. One message, one
answer. Also how you trigger jobs on your Mac and check your budget.

**Time:** about 1 hour.

**Cost:** ₹0.

**Build this before Open WebUI if you want value fastest.** It is the interface
you will actually use every day.

---

## Why Telegram and not a custom app

| | Telegram bot | Custom app |
|---|---|---|
| Build time | 1 hour | Weeks |
| Cost | ₹0 | ₹0 plus your time |
| Works on any phone | ✅ | Needs building twice |
| Push notifications | ✅ Built in | Needs setup |
| Send/receive files, voice, photos | ✅ Built in | Needs building |
| Works on bad mobile data | ✅ Very well | Depends |

There is nothing a custom app would give you here that Telegram does not.

---

## Step 1 — Create the bot

1. Open Telegram, search for **@BotFather**.
2. Send `/newbot`.
3. Give it a name (e.g. `Poojan AI`) and a username ending in `bot`
   (e.g. `poojan_ai_hub_bot`).
4. It gives you a **token** that looks like
   `1234567890:AAF...`. This is a password — treat it like one.

Also send `/setprivacy` → **Disable**, so the bot can read all messages in the
chat, not just commands.

## Step 2 — Find your own chat ID

You need this so the bot only answers you.

```bash
TOKEN="1234567890:AAF..."

# Send any message to your bot in Telegram first, then run:
curl -s "https://api.telegram.org/bot$TOKEN/getUpdates" | python3 -m json.tool
```

Look for `"chat": {"id": 123456789`. That number is your chat ID.

---

## Step 3 — Decide where the bot runs

| Phase | Where | How Telegram reaches it |
|---|---|---|
| **1** | On your Mac | **Polling** — the bot asks Telegram for messages. Works with no public address |
| **2** | Cloudflare Worker | **Webhook** — Telegram calls your Worker URL. Always on |

Start with polling on the Mac. Move to a webhook when you want it always
available.

---

# PHASE 1 — Polling bot on your Mac

## Step 4 — Install

```bash
python3.12 -m venv ~/.venvs/tgbot
source ~/.venvs/tgbot/bin/activate
pip install python-telegram-bot requests
```

## Step 5 — Configuration file

```bash
mkdir -p ~/.config/aihub
cat > ~/.config/aihub/.env <<'EOF'
TELEGRAM_TOKEN=1234567890:AAF...
TELEGRAM_ALLOWED_CHAT=123456789
LITELLM_URL=http://localhost:4000/v1
LITELLM_KEY=sk-your-telegram-key
HUB_URL=https://ai-hub.yourname.workers.dev
WORKER_TOKEN=your-worker-token
EOF
chmod 600 ~/.config/aihub/.env
```

## Step 6 — The bot

Save as `~/Documents/Code/aihub/bot.py`:

```python
#!/usr/bin/env python3
"""Telegram bot: chat with AI, trigger Mac jobs, check the budget."""

import os, json, requests
from telegram import Update
from telegram.ext import ApplicationBuilder, CommandHandler, MessageHandler, filters

TOKEN        = os.environ["TELEGRAM_TOKEN"]
ALLOWED      = int(os.environ["TELEGRAM_ALLOWED_CHAT"])
LITELLM_URL  = os.environ["LITELLM_URL"]
LITELLM_KEY  = os.environ["LITELLM_KEY"]
HUB_URL      = os.environ.get("HUB_URL", "")
WORKER_TOKEN = os.environ.get("WORKER_TOKEN", "")


def mine(update: Update) -> bool:
    """Only respond to my own chat. Everyone else is ignored silently."""
    return update.effective_chat and update.effective_chat.id == ALLOWED


def ask_ai(prompt: str, model: str = "tier1-free") -> str:
    """Send one question to LiteLLM and return the text answer."""
    r = requests.post(
        f"{LITELLM_URL}/chat/completions",
        headers={"Authorization": f"Bearer {LITELLM_KEY}"},
        json={
            "model": model,
            "messages": [{"role": "user", "content": prompt}],
            # tag so the dashboard can count requests by type
            "metadata": {"tags": ["source:telegram"]},
        },
        timeout=120,
    )
    r.raise_for_status()
    return r.json()["choices"][0]["message"]["content"]


def queue_job(job_type: str, payload: dict, chat_id: int) -> int:
    """Put a job on the queue for the Mac agent to pick up."""
    r = requests.post(
        f"{HUB_URL}/jobs",
        headers={"x-worker-token": WORKER_TOKEN},
        json={"type": job_type, "payload": payload, "reply_to": str(chat_id)},
        timeout=30,
    )
    r.raise_for_status()
    return r.json()["id"]


# ---------------------------------------------------------------- commands

async def cmd_start(update, ctx):
    if not mine(update):
        return
    await update.message.reply_text(
        "Commands:\n"
        "/ask <question>      quick answer (free tier)\n"
        "/think <question>    harder question (costs a little)\n"
        "/local <question>    answer from my Mac only, never leaves home\n"
        "/rank <folder>       score photos and videos in that folder\n"
        "/reel <description>  build a short video\n"
        "/stats               requests and jobs today\n"
        "/budget              money spent this month\n\n"
        "Or just send a message to chat."
    )


async def cmd_ask(update, ctx):
    if not mine(update):
        return
    q = " ".join(ctx.args)
    if not q:
        await update.message.reply_text("Usage: /ask what is the capital of Japan")
        return
    await update.message.chat.send_action("typing")
    await update.message.reply_text(ask_ai(q, "tier1-free"))


async def cmd_think(update, ctx):
    if not mine(update):
        return
    q = " ".join(ctx.args)
    await update.message.chat.send_action("typing")
    await update.message.reply_text(ask_ai(q, "tier2-cheap"))


async def cmd_local(update, ctx):
    if not mine(update):
        return
    q = " ".join(ctx.args)
    await update.message.chat.send_action("typing")
    try:
        await update.message.reply_text(ask_ai(q, "private-local"))
    except Exception:
        # private-local has no fallback on purpose
        await update.message.reply_text(
            "My Mac is not reachable right now. Nothing was sent to the cloud."
        )


async def cmd_rank(update, ctx):
    """Trigger photo scoring on the Mac. The folder name is just a string here."""
    if not mine(update):
        return
    folder = " ".join(ctx.args) or "Photos/Inbox"
    job_id = queue_job("rank_media", {"path": folder}, update.effective_chat.id)
    await update.message.reply_text(
        f"Queued job #{job_id} to score '{folder}'.\n"
        "It will run when my Mac is awake. I'll message you when it's done."
    )


async def cmd_reel(update, ctx):
    if not mine(update):
        return
    desc = " ".join(ctx.args)
    if not desc:
        await update.message.reply_text("Usage: /reel 30 second beach trip, upbeat")
        return
    job_id = queue_job("reel_render", {"description": desc},
                       update.effective_chat.id)
    await update.message.reply_text(f"Queued reel job #{job_id}: {desc}")


async def cmd_stats(update, ctx):
    if not mine(update):
        return
    # Filled in properly in file 12 once the dashboard tables exist
    await update.message.reply_text("Stats coming in file 12.")


async def cmd_budget(update, ctx):
    if not mine(update):
        return
    await update.message.reply_text("Budget view coming in file 12.")


async def on_text(update, ctx):
    """Any plain message becomes a normal question."""
    if not mine(update):
        return
    await update.message.chat.send_action("typing")
    await update.message.reply_text(ask_ai(update.message.text, "tier1-free"))


def main():
    app = ApplicationBuilder().token(TOKEN).build()
    app.add_handler(CommandHandler("start",  cmd_start))
    app.add_handler(CommandHandler("help",   cmd_start))
    app.add_handler(CommandHandler("ask",    cmd_ask))
    app.add_handler(CommandHandler("think",  cmd_think))
    app.add_handler(CommandHandler("local",  cmd_local))
    app.add_handler(CommandHandler("rank",   cmd_rank))
    app.add_handler(CommandHandler("reel",   cmd_reel))
    app.add_handler(CommandHandler("stats",  cmd_stats))
    app.add_handler(CommandHandler("budget", cmd_budget))
    app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, on_text))
    print("Bot running. Press Ctrl-C to stop.")
    app.run_polling()


if __name__ == "__main__":
    main()
```

## Step 7 — Run it

```bash
source ~/.venvs/tgbot/bin/activate
set -a; source ~/.config/aihub/.env; set +a
python ~/Documents/Code/aihub/bot.py
```

In Telegram, send `/start` to your bot.

Then test each command:

| Send | Expect |
|---|---|
| `/ask what is 2+2` | An answer, fast, free |
| `/local say hello` | An answer from your Mac |
| `/rank Photos/Test` | "Queued job #1..." |
| Any plain message | A normal answer |

## Step 8 — Keep it running

Create `~/Library/LaunchAgents/com.poojan.tgbot.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.poojan.tgbot</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/zsh</string>
    <string>-lc</string>
    <string>source ~/.venvs/tgbot/bin/activate &amp;&amp; set -a &amp;&amp; source ~/.config/aihub/.env &amp;&amp; set +a &amp;&amp; exec python ~/Documents/Code/aihub/bot.py</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardOutPath</key><string>/tmp/tgbot.log</string>
  <key>StandardErrorPath</key><string>/tmp/tgbot.err</string>
</dict>
</plist>
```

```bash
launchctl load ~/Library/LaunchAgents/com.poojan.tgbot.plist
tail -f /tmp/tgbot.log
```

---

# PHASE 2 — Webhook on Cloudflare (always on)

With polling, the bot dies when your Mac sleeps. A webhook means Telegram calls
your Worker instead, so the bot is always awake — it can queue jobs even at 3am
and answer using cloud models.

## Step 9 — Add a webhook route to the Worker

Add this inside the `fetch` function in `src/index.js` from file 04:

```js
// Telegram calls this. Path includes the secret so random traffic bounces.
if (url.pathname === `/tg/${env.TG_SECRET}` && request.method === "POST") {
  const update = await request.json();
  const msg = update.message;
  if (!msg || String(msg.chat.id) !== env.TG_CHAT) {
    return Response.json({ ok: true });   // ignore everyone else
  }

  const text = (msg.text || "").trim();
  let reply;

  if (text.startsWith("/rank")) {
    const folder = text.slice(5).trim() || "Photos/Inbox";
    const r = await env.DB.prepare(
      "INSERT INTO jobs (type,payload,reply_to,created_at) VALUES (?,?,?,?)"
    ).bind("rank_media", JSON.stringify({ path: folder }),
           String(msg.chat.id), new Date().toISOString()).run();
    reply = `Queued job #${r.meta.last_row_id} to score '${folder}'.`;

  } else {
    // Everything else goes to a cloud model via LiteLLM
    const ai = await fetch(`${env.LITELLM_URL}/chat/completions`, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${env.LITELLM_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "tier1-free",
        messages: [{ role: "user", content: text }],
        metadata: { tags: ["source:telegram"] },
      }),
    });
    const j = await ai.json();
    reply = j.choices?.[0]?.message?.content ?? "Something went wrong.";
  }

  await fetch(`https://api.telegram.org/bot${env.TG_TOKEN}/sendMessage`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ chat_id: msg.chat.id, text: reply }),
  });

  return Response.json({ ok: true });
}
```

## Step 10 — Set the secrets and register the webhook

```bash
cd ~/Documents/Code/ai-hub-worker

wrangler secret put TG_TOKEN       # your BotFather token
wrangler secret put TG_CHAT        # your chat id
wrangler secret put TG_SECRET      # a long random string
wrangler secret put LITELLM_URL    # Mac's Tailscale address, or the VM's
wrangler secret put LITELLM_KEY
wrangler deploy
```

⚠️ If LiteLLM lives on your Mac behind Tailscale, a Cloudflare Worker **cannot
reach it** — Workers are not on your Tailscale network. Either run a LiteLLM
copy on a VM the Worker can reach, or keep chat on the polling bot and use the
Worker only for job queueing. This is a real limitation worth planning around.

Register the webhook:

```bash
TOKEN="your-bot-token"
SECRET="your-tg-secret"
HUB="https://ai-hub.yourname.workers.dev"

curl -s "https://api.telegram.org/bot$TOKEN/setWebhook?url=$HUB/tg/$SECRET"

# Confirm
curl -s "https://api.telegram.org/bot$TOKEN/getWebhookInfo" | python3 -m json.tool
```

**Important:** polling and webhook cannot both be active. Stop the Mac bot
first (`launchctl unload ...`), or Telegram will complain.

To go back to polling later:

```bash
curl -s "https://api.telegram.org/bot$TOKEN/deleteWebhook"
```

---

## Command reference

| Command | What it does | Where the work happens | Cost |
|---|---|---|---|
| `/ask <q>` | Quick answer | Groq free tier | ₹0 |
| `/think <q>` | Harder question | DeepSeek | ~₹0.02 |
| `/local <q>` | Private answer | Your Mac only | ₹0 |
| `/rank <folder>` | Score photos/videos | Your Mac (CLIP) | ₹0 |
| `/reel <desc>` | Build a video | Mac + one cheap AI call | ~₹0.05 |
| `/stats` | Requests and jobs today | Database | ₹0 |
| `/budget` | Money spent | Database | ₹0 |

---

## Security notes

| Risk | Protection |
|---|---|
| Anyone finds your bot and uses your credits | The `mine()` check — only your chat ID is answered |
| Bot token leaks | Keep it in `.env` with `chmod 600`, never in git |
| Someone guesses your webhook URL | The secret is part of the path |
| A message makes your Mac read `~/.ssh` | Path safety check in file 05. **Do not skip this** |
| Runaway spending | Per-key budget in LiteLLM (file 06, step 7) |

---

## Troubleshooting

| Problem | Cause | Fix |
|---|---|---|
| Bot silent | Not running, or wrong chat ID | `tail /tmp/tgbot.err`; re-check chat ID |
| "Conflict: terminated by other getUpdates" | Polling and webhook both on | Delete the webhook, or stop the polling bot |
| Long answers cut off | Telegram limit is ~4,096 characters | Split the reply into chunks |
| `/rank` says queued but nothing happens | Mac agent not running | See file 05 |
| Works on wifi, not mobile data | Bot reaching LiteLLM over localhost | Fine for polling on Mac; for webhook see the Tailscale warning above |
| Webhook returns 401 | Wrong secret in URL | Re-run `setWebhook` |

---

## Prompt for AI

```
Add three new commands to an existing python-telegram-bot script.

The script already has:
- a function mine(update) that returns True if the message is from the allowed chat
- a function ask_ai(prompt, model) that returns a string answer
- a function queue_job(job_type, payload, chat_id) that returns an integer job id
- handlers registered with app.add_handler(CommandHandler("name", func))

Write these three async handler functions in the same style as the existing ones:

1. cmd_summarise(update, ctx)
   - Takes the text after the command as a URL.
   - If there is no URL, reply: "Usage: /summarise https://example.com"
   - Calls queue_job("fetch_and_summarise", {"url": <the url>}, chat_id)
   - Replies: "Queued job #<id> to read and summarise that page."

2. cmd_music(update, ctx)
   - Takes the text after the command as a mood, for example "focus" or "upbeat".
   - Default the mood to "recent favourites" if nothing was given.
   - Calls queue_job("music_playlist", {"mood": <mood>}, chat_id)
   - Replies: "Queued job #<id> to build a '<mood>' playlist."

3. cmd_transcribe(update, ctx)
   - Only works if the message is a reply to another message containing audio
     or a voice note. If it is not, reply:
     "Reply to a voice note or audio file with /transcribe"
   - Gets the file_id from the replied-to message and calls
     queue_job("transcribe", {"file_id": <file_id>}, chat_id)
   - Replies: "Queued job #<id> to transcribe that audio."

Rules:
- Every handler must start with: if not mine(update): return
- Wrap the queue_job call in try/except. On any error reply
  "Could not queue that job right now." and do not crash.
- Also give me the three app.add_handler lines to add.
- Do not rewrite any existing function. Only give me the new code.
- Put a one-line docstring at the top of each function.
```

---

## Check you are done

- [ ] Bot replies to `/start`
- [ ] `/ask` returns an answer
- [ ] `/local` returns an answer from your Mac
- [ ] `/local` gives the friendly "not reachable" message when Ollama is stopped
- [ ] `/rank Photos/Test` returns a job number
- [ ] Someone else messaging the bot gets no reply
- [ ] Bot restarts automatically after a reboot

---

## ⚠️ Verify with AI

| # | Unverified | Why it matters |
|---|---|---|
| 1 | `python-telegram-bot` current API | v20+ changed handler signatures |
| 2 | Message length and file size limits | Long replies get truncated |
| 3 | Whether polling and webhook can coexist | They cannot — but confirm the error |

Paste this into Gemini or any web-enabled AI, then update this file with what comes back.

```
RULES — follow exactly:
- Use only the official Telegram Bot API documentation and the
  python-telegram-bot documentation. No blogs.
- Give the source URL and version for each answer.

I am writing a single-user Telegram bot in Python that answers questions via an
OpenAI-compatible proxy and queues jobs to a REST API.

1. Current stable python-telegram-bot version, and the current official minimal
   polling-bot example with a CommandHandler and a MessageHandler. Have the async
   handler signatures changed recently?
2. Current limits: maximum message length in characters; maximum file size a bot
   can send; maximum it can receive. Recommended way to split a long reply.
3. Confirm that polling and a webhook cannot both be active, and give the exact
   error Telegram returns. Give the correct calls to switch between them.
4. Official way to restrict a bot to one chat id. Is there a Telegram-side
   setting, or is it application-level only?
5. How to send a video file from a bot, and the official size limit for that.
6. Does the Bot API support anything like typing indicators for long operations?
   Give the current method name.

Output as: | # | Answer | Official example | Source URL | Version |
```

---

Next: [06 — Job queue and Mac agent](05-mac-agent.md)
