# 07 — OpenClaw (WhatsApp front door)

> ## 🚨 THIS FILE IS PROMPT-DRIVEN
>
> I could not write an accurate setup guide for OpenClaw. Its config file format,
> tool-handler interface, WhatsApp connection method and MCP support are all
> version-specific, and the research I have marks most of them **NOT
> DOCUMENTED**.
>
> **Writing a plausible-looking guide from guesses would waste more of your time
> than having none.**
>
> So this file gives you three things I *can* provide accurately:
>
> 1. **What OpenClaw must do in this architecture** — that's fixed by the design,
>    not by their docs
> 2. **The decisions you have to make first**
> 3. **[A generation prompt](#the-generation-prompt) that produces the real setup
>    guide** — paste it into Gemini or any web-enabled AI, and save the output as
>    `07a-openclaw-setup.md` alongside this file
>
> Plus **acceptance tests** at the end, which are about behaviour rather than
> config, so they're valid regardless of version.

---

## What is verified

⚠️ From research on 2 Aug 2026. Confirm the live state with the prompt below.

| Item | Verified |
|---|---|
| Repository | `github.com/openclaw/openclaw` |
| Maintainer, licence | Peter Steinberger and contributors, **MIT** |
| Former names | **Clawdbot → Moltbot → OpenClaw**. Older posts use those |
| What it is | Self-hosted personal AI assistant; always-on gateway + model providers + tools/skills |
| Channels listed | WhatsApp, Telegram, Slack, Discord, Signal, iMessage, Google Chat, Matrix, Teams, and ~14 more |
| Requirements | **Node 24 recommended, 22.16+ minimum.** macOS and Linux; Windows via WSL2 |
| Maturity | Its own `VISION.md` says **early, iterating fast** |
| Host access | Can run commands, access workspace files, automate browsers, use device features |

| Item | ⚠️ **NOT documented** in what I have |
|---|---|
| MCP client matrix — stdio vs remote | Unknown |
| Whether MCP servers can be scoped per profile or channel | Unknown |
| Config file paths and format | Unknown |
| Tool-handler interface | Unknown |
| **How WhatsApp connects** — official API or Web bridge | Unknown |
| Inbound API for sending a message from a script | Unknown |
| Whether a custom OpenAI base URL is supported | "In principle", version-sensitive |

That last row matters a lot — it decides whether OpenClaw's spending shows up on
your dashboard.

---

## Its job in this architecture

This part **is** fixed. Whatever the config looks like, OpenClaw must do exactly
five things:

| # | Job | Why |
|---|---|---|
| 1 | Receive WhatsApp messages, from **you only** | Front door |
| 2 | Send model requests **through LiteLLM**, not direct to a provider | Keeps your budget cap, spend visibility, and the privacy gate |
| 3 | Hold **four job-queue tools** that enqueue and return immediately | How WhatsApp reaches your Mac |
| 4 | Host **all MCP servers** — community stdio, or hosted URLs | Nothing MCP runs on your Mac |
| 5 | Send finished-job results back to your chat | Closes the loop |

```
WhatsApp ──▶ OpenClaw (Oracle) ──▶ queue API ──▶ Postgres
                   │                                 ▲
                   ├──▶ LiteLLM ──▶ models           │ Mac polls
                   └──▶ MCP servers (Oracle)         │
                                          Mac agent ─┘ ──▶ CLIP, ffmpeg
```

🚨 **The load-bearing constraint: OpenClaw runs on Oracle, so it cannot see your
Mac's photos.** It is the *front door*, not the worker. Files
[03](03-photo-ranker.md), [05](05-mac-agent.md), [09](09-reels.md) and
[10](10-albums.md) remain necessary and unchanged.

### The four tools it needs

| Tool | Job type | Duration | Returns |
|---|---|---|---|
| `rank_media(path)` | `rank_media` | 1–25 min | job id, immediately |
| `make_reel(description, seconds)` | `reel_render` | 1–3 min | job id, immediately |
| `group_albums()` | `group_events` | 1–2 min | job id, immediately |
| `job_status(job_id)` | — reads the queue directly | instant | the actual status |

Only the last one is synchronous. The first three **must return a job id without
waiting**, or the model will claim work is finished when it has only been queued.

**The tool description does real work here:**

```
ASYNCHRONOUS: returns a job id immediately. The work takes 1-25 minutes and the
user is messaged separately when it finishes. Never wait for a result. Never
claim the ranking is done.
```

Without that wording, the model will lie to you. It's a prompt problem, not a
code problem.

---

## Decide these two things before you install

### 1. 🚨 The WhatsApp number

⚠️ WhatsApp automation for personal numbers usually rides an unofficial Web
bridge, and **Meta bans numbers for it.** This is the standard failure mode for
this whole category of tool, not a hypothetical.

| Option | Cost | Risk |
|---|---|---|
| 🏆 **Spare number** (second SIM or eSIM) | ~₹150–200/mo | Lose a throwaway, not your life |
| **Telegram instead** ([A1](A1-telegram-fallback.md)) | ₹0 | ✅ No ban risk. But not where you live |
| WhatsApp Business Cloud API | Per message | ✅ Sanctioned, more setup |
| Your main number | ₹0 | 🚨 **Losing your primary WhatsApp is genuinely disruptive** |

**The generation prompt asks which method OpenClaw actually uses.** If it's the
official Cloud API, this risk mostly disappears.

### 2. Whether it replaces Open WebUI

| Your file | Fate |
|---|---|
| [A1 — Telegram bot](A1-telegram-fallback.md) | ✅ Replaced. Keep as fallback |
| [A2 — Open WebUI](A2-openwebui-optional.md) | ⚠️ Partly. Keep only for document upload and RAG |
| [06 — LiteLLM](06-litellm.md) | ✅ **Keep.** Point OpenClaw at it |
| [05 — Mac agent](05-mac-agent.md) | ✅ **Required, unchanged** |

---

## Create its LiteLLM key first

This you can do now, and it should exist before OpenClaw starts. On the Oracle
LiteLLM instance:

```bash
curl -s -X POST http://localhost:4000/key/generate \
  -H "Authorization: Bearer $MASTER_KEY" -H "Content-Type: application/json" \
  -d '{"models":["tier1-free","tier2-cheap","tier1-public-only"],
       "max_budget":2,"budget_duration":"1mo"}'
```

🚨 **Note what that key cannot reach: `private-local` is absent.** OpenClaw is
internet-facing, so it must never be able to route a request at your photo
captioning model. This is the privacy gate, enforced at the key.

---

## The generation prompt

Paste this into Gemini, ChatGPT, or any web-enabled AI. **Save the output as
`07a-openclaw-setup.md`** in this folder.

```
You are writing one file of a build guide. Produce a complete, accurate setup
guide for OpenClaw (github.com/openclaw/openclaw) for the specific architecture
described below.

RULES — follow exactly:
- Use ONLY the openclaw/openclaw GitHub repository, its official documentation
  site, and posts by its maintainers. No blogs, no third-party tutorials.
- State the OpenClaw version your instructions apply to, and where you read it.
- If something is not documented, write NOT DOCUMENTED and say what the reader
  should run to find out (e.g. a --help command). Do NOT invent config syntax.
- Paste official examples verbatim where they exist. Mark anything you adapted.
- Output GitHub-flavoured markdown, ready to save as a file. Use tables where
  they help. Simple English, short sentences.

MY SETUP (do not change this — write the guide to fit it):
- Host: Oracle Cloud Always Free VM, Ubuntu 22.04, ARM (aarch64), 2 OCPU, 12 GB RAM
- OpenClaw runs on that VM. NOT on my MacBook, deliberately — my laptop has
  confidential employer source code and I will not give an internet-facing agent
  access to it.
- A LiteLLM proxy already runs on the same VM at http://localhost:4000/v1
  (OpenAI-compatible). I have an API key for it, budget-capped at $2/month.
- A job queue REST API already runs on the same VM at http://localhost:8000 with
  these endpoints, authenticated by a shared secret in the header
  "x-worker-token":
     POST /jobs           body {"type": "...", "payload": {...}, "reply_to": "<chat id>"}
                          returns {"id": <int>}
     GET  /jobs/{id}      returns the job row including "status" and "result"
- PostgreSQL runs on the same VM.
- My MacBook polls that queue API and does all heavy work (photo scoring with
  CLIP, video rendering with ffmpeg). OpenClaw must NEVER try to touch my Mac's
  files — it cannot reach them.
- Channel: WhatsApp is what I want. I am considering a spare SIM.

WRITE THESE SECTIONS, IN THIS ORDER:

1. VERSION AND PREREQUISITES
   Current stable version, Node version required, and the exact install commands
   for Ubuntu ARM. Flag anything that is x86-only.

2. WHATSAPP CONNECTION — answer these precisely, this is my biggest open question
   a. Does OpenClaw use the official WhatsApp Business Cloud API, an unofficial
      WhatsApp Web bridge, or both? Quote the documentation.
   b. If it is a Web bridge: what does the linking flow look like (QR code?), and
      does the project's own documentation acknowledge any account-ban risk?
   c. What are the exact setup steps for whichever method it uses?
   d. Does it support multiple channels at once (WhatsApp AND Telegram)?

3. RESTRICT IT TO ME ONLY
   How do I configure it to respond ONLY to my own phone number or chat ID and
   silently ignore everyone else? Give the exact config. This is a security
   requirement — if it is not possible, say so clearly and prominently.

4. POINT IT AT MY LITELLM PROXY
   Exact config for a custom OpenAI-compatible provider with my own base URL
   (http://localhost:4000/v1), my own API key, and a default model name I choose.
   If a custom base URL is NOT supported, say so clearly and tell me what my
   options are instead.

5. DEFINE MY FOUR CUSTOM TOOLS
   Show me exactly how to define a custom tool with my own handler code, then
   write all four of these completely, using OpenClaw's real interface:

   - rank_media(path: string)
       Handler: POST to http://localhost:8000/jobs with
         {"type":"rank_media","payload":{"path": path},"reply_to": <this chat id>}
       Return the job id immediately. Do NOT wait for the work.
       Description must tell the model: ASYNCHRONOUS, returns a job id, work takes
       1-25 minutes, the user is messaged separately, never claim it is finished.

   - make_reel(description: string, seconds: integer, default 30)
       Same pattern, type "reel_render", payload {"description":..., "seconds":...}

   - group_albums()
       Same pattern, type "group_events", empty payload

   - job_status(job_id: integer)
       Synchronous. GET http://localhost:8000/jobs/{job_id} and return status
       plus result.

   Show how the handler gets the current chat id, since I need it for reply_to.

6. SENDING A MESSAGE FROM AN EXTERNAL SCRIPT
   When a job finishes on my Mac, a separate Python script on the VM needs to make
   OpenClaw send me the result on WhatsApp. Is there an inbound HTTP API, a CLI
   command, or a queue for this? Give the exact path, method, headers and body.
   If there is no such mechanism, tell me and suggest the closest alternative.

7. MCP SERVERS
   a. Does it act as an MCP client? Can it use local stdio servers, remote URL
      servers, or both? Give the config shape for each.
   b. Can MCP servers be scoped to one profile, agent or channel — or is the tool
      set global? This matters because tool schemas cost tokens on every request.
   c. Can servers be enabled or disabled at runtime without a restart?
   d. Where exactly does MCP config live? Which file, which format?

8. RUNNING IT AS A SERVICE
   A working systemd unit file for Ubuntu, with the real entrypoint command,
   restart-on-failure, and an EnvironmentFile for secrets.

9. SECURITY — quote their own documentation
   a. Quote any warnings in their docs or SECURITY.md about the risks of running
      it.
   b. Which tools are enabled by DEFAULT? I want to start with only my four
      custom tools plus web fetch, and add shell or filesystem access later if at
      all. How do I disable the rest?
   c. How should third-party skills be treated? Are they code execution?
   d. Where do secrets live, and is there anywhere they must NOT go?

10. UPGRADING AND BACKUP
    How to upgrade safely, and what state or config directory I should back up.

11. TROUBLESHOOTING TABLE
    A table of the most common failures with causes and fixes, drawn from their
    docs and issue tracker. Include: WhatsApp won't link; tools not offered to the
    model; the model claiming an async job is finished; provider connection
    refused.

At the very end, add a section called "STILL NOT DOCUMENTED" listing everything
above that you could not answer from official sources, with the exact command or
page I should check myself.
```

---

## 🚨 A generated guide arrived — verify it before following it

On 2 Aug 2026 the generation prompt produced a complete-looking setup guide. **Do
not follow it as written.** Treat it as a hypothesis.

### Why I don't trust it

| Signal | Detail |
|---|---|
| It contradicts the earlier pass | The first research explicitly found the MCP matrix, config format and tool interface **NOT DOCUMENTED**. This one produced exact JSON5 keys and a port number |
| Same response was stale elsewhere | Its LiteLLM answer cited `claude-3-5-sonnet-20240620` (retired) and v1.70 when v1.86 exists. Its pricing answer claimed Claude Sonnet 5 doesn't exist |
| Suspicious precision | Port `18789`, `dmPolicy: "allowlist"`, `~/.openclaw/openclaw.json`, `docs.openclaw.ai` — I cannot confirm any of it |

Some of it is probably right. `@c.us` is genuine WhatsApp Web JID format, and the
config naming is plausible. **But you can't tell which parts by reading.**

### Verify in five minutes, before writing any config

```bash
# 1. Does the npm package exist, and what version?
npm view openclaw version 2>&1 | head -3

# 2. Do the claimed commands exist?  ← the decisive test
openclaw --help          2>&1 | head -30
openclaw channels --help 2>&1 | head -20
openclaw mcp --help      2>&1 | head -20
openclaw message --help  2>&1 | head -20

# 3. Does it create the config path it claims?
openclaw --version && ls -la ~/.openclaw/ 2>&1

# 4. Does the gateway listen on the port it claims?
sudo ss -tlnp | grep -E '18789|openclaw'

# 5. What tools are enabled out of the box?
openclaw tools list 2>&1 | head -40
```

**If `openclaw channels login` and `openclaw mcp reload` both exist, the guide is
probably sound** — proceed, but check each config key against `--help` output as
you go.

**If either is unrecognised**, discard every config block in it and re-run the
generation prompt with this line added to the RULES:

```
Before answering, confirm each CLI command and config key exists by finding it in
the repository source or docs. Quote the file and line where you found it. If you
cannot find it, write NOT DOCUMENTED instead of describing it.
```

### Claims worth checking specifically

| Claim | Why it matters | Verify with |
|---|---|---|
| **Unofficial WhatsApp Web bridge** via headless Chromium | 🚨 Confirms the ban risk. Use a spare number | `openclaw channels --help` |
| `dmPolicy: "allowlist"` + `allowFrom: ["91...@c.us"]` | 🚨 Your only access control | Test with a second number |
| `tools.allow` / `tools.deny` **per agent** | 🏆 Answers the token-scoping question — if real | `openclaw tools list` |
| `openclaw mcp reload` for runtime toggling | Would be genuinely useful | `openclaw mcp --help` |
| Gateway API at `127.0.0.1:18789/api/v1/messages/send` | How the Mac's results reach WhatsApp | `ss -tlnp` |
| Node **22.0.0+** | Conflicts with the earlier "24 recommended, 22.16+ minimum" | `node -v` and their README |

### 🏆 One thing to take regardless

If `tools.allow` works as described, **start with exactly this** and add nothing
until you need it:

```json5
{ "agents": { "defaults": { "tools": {
    "allow": ["custom_jobs__rank_media", "custom_jobs__make_reel",
              "custom_jobs__group_albums", "custom_jobs__job_status",
              "web_fetch"],
    "deny":  ["exec", "filesystem", "browser"]
}}}}
```

That denies shell, filesystem and browser access on an internet-facing agent. Even
if the exact key names are wrong, **the intent is right** — find the equivalent in
`openclaw tools --help` and apply it before your first message.

⚠️ And note its own admission: **`exec`, `filesystem` and `browser` are enabled by
default.** If that's true, an unconfigured OpenClaw can run shell commands on your
Oracle box from a WhatsApp message. Configure the allowlist *first*, then link
WhatsApp.

---

## Acceptance tests

These are about **behaviour**, so they're valid whatever the config turns out to
be. Run them in order — each isolates one thing.

| # | Test | Passes when |
|---|---|---|
| 1 | Send "hello" | You get a reply |
| 2 | Ask a general question | Model answers, **and spend appears in LiteLLM's `/ui`** |
| 3 | Ask someone else to message it | They get **no** reply |
| 4 | Check its LiteLLM key's model list | `private-local` is **absent** |
| 5 | "What's in the news about X?" | Uses web fetch, cites sources |
| 6 | "Rank the photos in Photos/Test" | Replies with a **job id**. Does **not** claim it finished |
| 7 | `SELECT * FROM jobs ORDER BY id DESC LIMIT 1` on Oracle | Row exists, status `queued` |
| 8 | Start the Mac agent | Job goes `running` then `done` |
| 9 | Wait | WhatsApp message arrives with the results |
| 10 | "Is job 42 done?" | Answers from `job_status`, instantly |
| 11 | Count attached tools | **Under 10** |
| 12 | Reboot the VM | Comes back on its own |

**Test 6 is the one that usually fails first.** If the model claims the ranking
finished, strengthen the tool description — that's a prompt fix, not code.

**Test 2 is the one that matters most for cost control.** If spend doesn't appear
in LiteLLM's UI, OpenClaw is talking to a provider directly and your budget cap
isn't protecting you.

---

## 🚨 Token cost — check this before attaching MCP servers

Every tool's full schema goes into **every request**, and a tool-use loop resends
it each turn.

| Attached | Tokens per request | 4-turn loop |
|---|---|---|
| Your 4 queue tools | ~800 | 3,200 |
| Plus web fetch | ~2,000 | 8,000 |
| Plus a GitHub-class MCP server | **~15,000** | **60,000** |

**One question with GitHub attached can cost 30× more than ranking 186 photos.**

Section 7b of the generation prompt asks whether servers can be scoped per
profile. If the answer is no, keep the global set small. More in
[08 — MCP servers](08-mcp-servers.md).

---

## If OpenClaw doesn't work out

Perfectly reasonable outcome — it's early-stage software.

| Symptom | Do this |
|---|---|
| WhatsApp number banned | Switch to [A1 — Telegram](A1-telegram-fallback.md). Same queue, no ban risk |
| Config too unstable to follow | Build A1 first. ~150 lines you fully understand, and it proves the queue works |
| No custom base URL support | Either accept that its spend bypasses your dashboard, or use A1 |
| Too much host access for comfort | A1 has none |

**Nothing else in the plan depends on OpenClaw.** It's the front door; the house
stands without it.

---

## ⚠️ Verify with AI

Everything in this file is unverified except the table at the top. **The
[generation prompt](#the-generation-prompt) above answers all of it** — it's the
main deliverable of this file, not an afterthought.

Run it, save the output as `07a-openclaw-setup.md`, then come back and work
through the acceptance tests.

Additional targeted prompts, if you want narrower answers first:
[14 — Verification prompts](14-verification-prompts.md) §OpenClaw.

---

Next: [08 — MCP servers](08-mcp-servers.md)
