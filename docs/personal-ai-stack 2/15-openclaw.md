# 15 — OpenClaw (WhatsApp front door)

**Goal:** talk to your whole stack from WhatsApp, and let a model decide which
tool to use instead of you typing exact commands.

**Time:** 2–3 hours.

**Cost:** ₹0 for the software. ⚠️ ~₹150–200/month if you use a spare number.

**Requires:** file 03 (Oracle box with Postgres and the queue API).

---

## What it is

⚠️ **Verified Aug 2026:** `github.com/openclaw/openclaw` — an open-source,
self-hosted personal AI assistant. MIT licence, built by Peter Steinberger and
contributors. Previously named **Clawdbot**, then **Moltbot** — older posts use
those names.

It connects messaging apps to an AI that can actually use tools. Officially
listed channels include WhatsApp, Telegram, Slack, Discord, Signal, iMessage,
Google Chat, Matrix, Teams and about a dozen more.

**Requirements:** Node 24 recommended (22.16+ minimum). Runs on macOS and Linux.

⚠️ Its own `VISION.md` says the project is **early and iterating fast**. Expect
things to move.

---

## 🚨 Run it on Oracle, not on your Mac

This is the whole reason we built the Oracle box.

| Risk | On your Mac | On Oracle |
|---|---|---|
| Can read Apple work source code | 🚨 **Yes** | ✅ Not there |
| Can reach your SSH agent | 🚨 **Yes** | ✅ Not there |
| Corporate browser profile | 🚨 **Yes** | ✅ Not there |
| Prompt-injection blast radius | Your whole home directory | One disposable VM |
| Meets requirements | ✅ | ✅ 12 GB, 2 cores |

An assistant that processes messages from the internet and can run shell
commands does not belong on the same user account as your employer's code. The
independent research reached the same conclusion:

> *"No — not with broad shell, filesystem, browser, messaging or third-party-skill
> access... I would use a separate OS user at minimum, and preferably a dedicated
> machine... with no mount of work directories, no corporate browser profile, no
> SSH agent."*

On Oracle, every one of those objections disappears.

---

## 🚨 The WhatsApp ban risk — decide this first

⚠️ WhatsApp automation for personal numbers generally rides an unofficial Web
bridge, and **Meta bans numbers for it.** This is the standard failure mode for
this whole category of tool, not a hypothetical.

| Option | Cost | Risk |
|---|---|---|
| 🏆 **Spare number** (second SIM or eSIM) | ~₹150–200/mo | Lose a throwaway number, not your life |
| **Telegram or Signal instead** | ₹0 | ✅ No ban risk. But not where you live |
| WhatsApp Business Cloud API (official) | Per message | ✅ Sanctioned, but costs and is more setup |
| Your main number | ₹0 | 🚨 **Losing your primary WhatsApp is genuinely disruptive** |

**Check how OpenClaw actually connects before you decide.** If it uses the
official Business Cloud API, the risk mostly disappears. If it drives WhatsApp
Web, use a spare number.

---

## What it replaces, and what it can't

| Your file | Fate |
|---|---|
| 05 — Telegram bot | ✅ **Replaced.** OpenClaw does messaging better |
| 04 — Open WebUI | ⚠️ Partly. Keep it only if you want document upload and RAG |
| 02 — LiteLLM | ✅ **Keep.** Point OpenClaw at it so your budgets and privacy gate still apply |
| **06 — Mac agent + queue** | ✅ **Still required, unchanged** |
| **07, 08, 10 — media pipelines** | ✅ **Still required, unchanged** |

**The load-bearing point: OpenClaw on Oracle cannot see your Mac's photos.**
Different machine. So it becomes the *front door* that drops jobs on the queue —
exactly what the Telegram bot did.

```
WhatsApp ──▶ OpenClaw (Oracle) ──▶ queue API ──▶ Postgres
                   │                                 ▲
                   ├──▶ LiteLLM ──▶ models           │ Mac polls
                   └──▶ MCP servers (Oracle)         │
                                          Mac agent ─┘ ──▶ CLIP, ffmpeg
```

---

## Step 1 — Install on Oracle

```bash
ssh ubuntu@100.90.80.70

# Node 24 via nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash
source ~/.nvm/nvm.sh
nvm install 24
node --version        # must be 22.16 or higher
```

⚠️ **Install and configuration commands change often.** Read the repository's
current README rather than trusting a snapshot here:

```bash
git clone https://github.com/openclaw/openclaw.git ~/openclaw
cd ~/openclaw
cat README.md | head -80        # follow their current instructions
```

---

## Step 2 — Point it at LiteLLM

This is the important configuration decision. Send OpenClaw's model calls through
your own router rather than straight to a provider, so you keep:

- Your monthly budget cap
- Per-app spending visibility on the dashboard
- **The privacy gate** — `private-local` never escalates to the cloud
- Automatic fallback when a provider fails

⚠️ Exact config file and key names are version-specific. The shape you want:

```
provider:  openai-compatible
base URL:  http://localhost:4000/v1        (LiteLLM on the same Oracle box)
api key:   sk-your-openclaw-litellm-key
model:     tier2-cheap
```

Create the key on the Oracle LiteLLM instance first (file 02, step 7):

```bash
curl -s -X POST http://localhost:4000/key/generate \
  -H "Authorization: Bearer $MASTER_KEY" -H "Content-Type: application/json" \
  -d '{"models":["tier1-free","tier2-cheap","tier1-public-only"],
       "max_budget":2,"budget_duration":"1mo"}'
```

Note what that key **cannot** reach: `private-local` is absent. OpenClaw is
internet-facing, so it must never be able to route a request at your photo
captioning model.

⚠️ **Verify OpenClaw exposes a custom base URL** for its OpenAI-compatible
provider. Research found this "supported in principle... exact config is
version-sensitive." If it does not, fall back to giving it a Gemini key directly
and accept that those calls bypass your dashboard.

---

## Step 3 — Give it your job-queue tools

This is how WhatsApp reaches your Mac. Define tools that **enqueue and return
immediately** — they must never wait for the work.

⚠️ Tool definition format is version-specific; read OpenClaw's current tools
docs. The shape:

```json
{
  "name": "rank_media",
  "description": "Score photos and videos in a folder on the user's Mac by how good they look. ASYNCHRONOUS: returns a job id immediately, the work takes 1-25 minutes, and the user is messaged separately when it finishes. Never wait for a result. Never claim the ranking is done.",
  "input_schema": {
    "type": "object",
    "properties": {
      "path": {"type": "string",
               "description": "Folder path relative to the user's media roots, e.g. 'Photos/Australia/Day1' or 'Downloads/Australia/Day1'"}
    },
    "required": ["path"]
  }
}
```

**The description is doing real work.** Without "ASYNCHRONOUS" and "never claim
the ranking is done", the model will tell you it has finished when it has only
queued the job.

The handler is four lines — a POST to your queue API:

```javascript
// Sketch. Adapt to OpenClaw's actual tool-handler interface.
async function rank_media({ path }, ctx) {
  const r = await fetch(`${process.env.HUB_URL}/jobs`, {
    method: "POST",
    headers: { "x-worker-token": process.env.WORKER_TOKEN,
               "Content-Type": "application/json" },
    body: JSON.stringify({ type: "rank_media", payload: { path },
                           reply_to: ctx.chatId }),
  });
  const { id } = await r.json();
  return { job_id: id, status: "queued",
           message: `Queued job ${id}. I'll message you when it's done.` };
}
```

Tools worth defining, all the same pattern:

| Tool | Job type | Typical duration |
|---|---|---|
| `rank_media(path)` | `rank_media` | 1–25 min |
| `make_reel(description, seconds)` | `reel_render` | 1–3 min |
| `group_photos()` | `group_events` | 1–2 min |
| `job_status(job_id)` | — reads `/jobs/{id}` directly, synchronous | instant |

`job_status` is the one synchronous tool — it lets you ask *"is job 42 done?"*
without waiting for the notification.

---

## Step 4 — Let the Mac send the reply

When the Mac finishes, it must message the right WhatsApp chat. The queue already
carries `reply_to`.

Two ways:

| Approach | How | Verdict |
|---|---|---|
| 🏆 **Mac → queue API → OpenClaw** | Mac POSTs the result; a small Oracle-side watcher sends it | Mac needs no WhatsApp credentials |
| Mac → OpenClaw directly | Mac calls OpenClaw's API over Tailscale | Fewer moving parts, but the Mac holds messaging credentials |

Take the first. On Oracle, a watcher polls for finished jobs and hands them to
OpenClaw:

```python
# notify_watcher.py — runs on Oracle, every 15 seconds
import os, time, psycopg2, psycopg2.extras, requests

DSN = os.environ["DATABASE_URL"]

while True:
    with psycopg2.connect(DSN, cursor_factory=psycopg2.extras.RealDictCursor) as c, \
         c.cursor() as cur:
        cur.execute("""
            UPDATE jobs SET status = status || '_notified'
            WHERE status IN ('done','failed') AND reply_to IS NOT NULL
            RETURNING id, type, status, result, reply_to
        """)
        for job in cur.fetchall():
            # Hand it to OpenClaw so the model can phrase it nicely.
            # ⚠️ Verify OpenClaw's inbound message API path.
            requests.post("http://localhost:PORT/api/message", json={
                "chat_id": job["reply_to"],
                "text": f"Job {job['id']} ({job['type']}) {job['status']}:\n"
                        f"{job['result']}",
            }, timeout=30)
    time.sleep(15)
```

⚠️ The `status || '_notified'` trick marks jobs as sent so they aren't
re-notified. Adjust to whatever OpenClaw's inbound API actually is.

---

## Step 5 — Attach MCP servers

**All MCP servers run on Oracle** — either as subprocesses OpenClaw spawns, or as
remote URLs. Full reasoning in file 16.

| Server | Type | Points at | Use |
|---|---|---|---|
| `fetch` | stdio, on Oracle | The internet | Reading web pages |
| GitHub / Linear / Notion | remote URL | Their servers | Work-adjacent lookups |
| `filesystem` | stdio, on Oracle | **Oracle's** disk | Reports and exports only |
| Playwright | stdio, on Oracle | Browser on Oracle | Only when a site needs clicking |

🚨 **The trap:** `filesystem` on Oracle sees **Oracle's** disk, not your Mac's.
There is no off-the-shelf MCP server that can reach across to your Mac. That is
exactly why Mac work goes through the job queue.

### 🚨 Watch the token cost

Every tool's full schema goes into **every request**, and a tool-use loop resends
it each turn.

| Setup | Tokens per request |
|---|---|
| Your 4 queue tools | ~800 |
| Plus `fetch` | ~2,000 |
| Plus a GitHub-class server | **~15,000** |

A 4-turn loop with GitHub attached is **60,000 tokens for one question**.

⚠️ **Open question:** can OpenClaw scope MCP servers to one profile or channel
rather than enabling them globally? Research found this **not documented**. Check
before attaching anything heavy — prompt at the end of this file.

If it only supports one global tool set, keep it small and enable heavy servers
deliberately when you need them.

---

## Step 6 — Lock it down

| Control | How |
|---|---|
| Only answer you | Allowlist your own chat ID. Same idea as `mine()` in file 05 |
| No shell tools initially | Start with your four queue tools plus `fetch`. Add more only when you need them |
| Budget cap | Its LiteLLM key is capped at $2/month |
| No access to `private-local` | Left out of its key's `models` list |
| Third-party skills | ⚠️ Treat as code execution. Read anything before installing it |
| Secrets | Only in OpenClaw's config on Oracle. Never in a prompt — prompts persist in history |

---

## Step 7 — Run it as a service

`/etc/systemd/system/openclaw.service`:

```ini
[Unit]
Description=OpenClaw
After=network.target aihub-queue.service

[Service]
User=ubuntu
WorkingDirectory=/home/ubuntu/openclaw
EnvironmentFile=/home/ubuntu/openclaw/.env
ExecStart=/home/ubuntu/.nvm/versions/node/v24.0.0/bin/node <entrypoint from their README>
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now openclaw
journalctl -u openclaw -f
```

---

## Step 8 — Test in order

Do these one at a time. Each isolates one thing.

| # | Test | Passes when |
|---|---|---|
| 1 | Send "hello" | You get a reply |
| 2 | Ask a general question | Model answers, and spend appears in LiteLLM's UI |
| 3 | Ask another person to message it | They get **no** reply |
| 4 | *"What's in the news about X?"* | It uses `fetch`, cites sources |
| 5 | *"Rank the photos in Photos/Test"* | Replies with a **job id**, does **not** claim it's finished |
| 6 | `SELECT * FROM jobs ORDER BY id DESC LIMIT 1` on Oracle | Row exists, status `queued` |
| 7 | Start the Mac agent | Job goes `running` then `done` |
| 8 | Wait | WhatsApp message arrives with the results |
| 9 | *"Is job 42 done?"* | Answers from `job_status`, instantly |

**Test 5 is the one that usually fails first.** If the model claims the ranking
finished, strengthen the tool description — that is a prompt problem, not a code
problem.

---

## Troubleshooting

| Problem | Cause | Fix |
|---|---|---|
| WhatsApp won't link | Bridge needs a QR scan | Check `journalctl -u openclaw` for the QR |
| Number banned | Unofficial bridge on a personal number | Use a spare number, or switch to Telegram |
| Model says a job is done when it isn't | Tool description too weak | Add "ASYNCHRONOUS" and "never claim it is done" |
| Tools not offered at all | Model too weak for tool calling, or tools not registered | Use `tier2-cheap`, not a local 8B |
| Every reply is slow | Too many tools attached | Count your schema tokens. Trim to under ~10 tools |
| Spending not on the dashboard | Not going through LiteLLM | Check the base URL |
| Job queued but nothing happens | Mac agent down | `tail /tmp/aihub-agent.err` on the Mac |
| Results never arrive on WhatsApp | Watcher not running, or wrong API path | `journalctl` for the watcher |

---

## Prompt for AI

⚠️ Run this **before** attaching heavy MCP servers.

```
RULES: use only the openclaw/openclaw GitHub repository and its official
documentation site. If something is not documented, write NOT DOCUMENTED. Give a
source URL for every answer and state which version it applies to.

Answer these about OpenClaw:

1. Can I define more than one agent configuration, profile, persona or preset,
   each with a DIFFERENT set of MCP servers and tools enabled? Or is the tool set
   global?
2. Can MCP servers be scoped to one profile or one messaging channel rather than
   enabled everywhere?
3. Can MCP servers be enabled or disabled at runtime without restarting?
4. Where exactly does MCP server configuration live — which file, which format?
   Paste the official example.
5. Does it support both stdio (subprocess) and remote URL MCP servers? Give the
   config shape for each.
6. How do I configure a custom OpenAI-compatible provider with my own base URL
   and API key? Paste the official example.
7. How does the WhatsApp integration connect — the official WhatsApp Business
   Cloud API, or an unofficial WhatsApp Web bridge? Quote the documentation.
8. How do I restrict it to respond only to specific chat IDs or phone numbers?
9. Is there an inbound HTTP API for sending a message to a chat from an external
   script? Give the path, method and body.
10. How do I define a custom tool with my own handler function? Paste the
    official example.

Output as a table: | # | Answer | Source URL | Version |
```

---

## Check you are done

- [ ] Oracle instance running with the queue API and Postgres (file 03)
- [ ] Decided on the WhatsApp number question — spare number, or Telegram
- [ ] OpenClaw installed, Node version confirmed
- [ ] Points at LiteLLM, spend visible in `/ui`
- [ ] Its key cannot reach `private-local`
- [ ] Only your chat ID gets replies
- [ ] Four queue tools defined and offered
- [ ] `rank_media` returns a job id and does **not** claim completion
- [ ] Mac agent picks the job up and finishes it
- [ ] Result arrives back on WhatsApp
- [ ] Runs as a service, survives reboot
- [ ] Under 10 tools attached

---

Next: [16 — Use case playbooks](16-use-case-playbooks.md)
