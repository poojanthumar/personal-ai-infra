# CHANGELOG — corrections and scope changes

---

# Round 2 — 2 Aug 2026 (later): architecture and scope

Driven by your questions, not by research. Four things changed.

## 🚨 Oracle replaces Cloudflare as the always-on box

You asked why Cloudflare was there when we'd discussed Oracle. Fair — I had
recommended Cloudflare and listed Oracle as the alternative. **Oracle is the
better call**, and two facts from the research make it clear:

| | Cloudflare Workers | Oracle Always Free |
|---|---|---|
| CPU per request | 🚨 **10 ms** | Unlimited |
| Can host Postgres, LiteLLM, **OpenClaw** | ❌ No | ✅ Yes |
| Cron jobs | ⚠️ 5 per account | Unlimited |
| Your data lives in | D1 **and** Postgres — two databases | **One** Postgres |

The 10 ms CPU ceiling makes a Worker a doorbell, not a house. And I'd
under-weighted the two-database problem: the dashboard in file 11 would have had
to read D1 *and* Postgres and stitch them together.

**Cloudflare keeps one job: Cloudflare Tunnel**, free, for HTTPS with no open
ports.

**Almost nothing in the design changed** — the pull-queue is host-agnostic. The
Mac polls an HTTP endpoint and doesn't care what serves it. Files 06, 07, 08, 10
are untouched.

| File | Change |
|---|---|
| **03** | 🔁 **Rewritten.** Oracle primary, FastAPI queue API, Postgres, Tunnel, backups |
| 00 | Hosting table and final decisions updated |
| 11 | Now one database instead of two |

## 🚨 OpenClaw is in — on Oracle, not your Mac

You asked why not use OpenClaw given it has WhatsApp. I never said don't — I said
**don't run it on the laptop with Apple work code.** On Oracle, every objection
disappears: no work source, no SSH agent, no corporate browser profile.

**New: [file 15](15-openclaw.md).** Setup, LiteLLM wiring, the queue tools, and
the security boundary.

⚠️ **The one risk to weigh:** WhatsApp automation usually rides an unofficial Web
bridge and **Meta bans personal numbers for it.** Use a spare SIM (~₹150–200/mo)
or stay on Telegram.

**What OpenClaw replaces:** file 05 (Telegram bot) and most of file 04 (Open
WebUI). **What it can't:** it runs on Oracle, so it cannot see your Mac's photos.
Files 06, 07, 08, 10 remain necessary and unchanged.

## 🚨 No MCP servers on your Mac. I contradicted myself.

File 06 said *"skip MCP inside your own Mac agent — MCP exists so programs
written by different people can interoperate."* Then I invented a `music_search`
MCP server on your Mac. Wrong, and against your stated constraint that all MCP
servers are off-the-shelf.

**Corrected placement:**

| Location | Servers |
|---|---|
| **Oracle** | All of them — community stdio subprocesses, or hosted URLs |
| ❌ **Your Mac** | **None.** It exposes only Ollama on :11434 |
| ❌ **LiteLLM** | **None.** It is not an MCP client |

**The trap that forces this:** `filesystem` on Oracle sees *Oracle's* disk;
`sqlite` on Oracle can only open a database *on Oracle*. No off-the-shelf MCP
server can reach your Mac. That is exactly why the job queue exists.

I also proposed syncing your SQLite files to Oracle so MCP could query them.
**Dropped** — it's a cache that goes stale, and queueing the query costs ~7
seconds with a 5-second poll interval. One source of truth is worth more.

## Music automation dropped

Apple exposes no danceability, tempo or energy field. Spotify closed the
equivalent API to new apps in Nov 2024. ⚠️ AcousticBrainz is frozen. So
*"bollywood dance songs"* can't be answered from library data — it needs a
one-time classification pass to build your own tags, which is a sub-project.

[File 09](09-apple-music.md) is kept for reference with an OUT OF SCOPE banner.

## Other fixes this round

| # | Change | File |
|---|---|---|
| 19 | `safe_path()` now takes a **list** of roots, so `~/Downloads` works. Your `Downloads/Australia/Day1` example would have been rejected | 06 |
| 20 | Safety test extended with the multi-root trap — `../Documents` must stay blocked even with `~/Downloads` as a root | 06 |
| 21 | `POLL_SECONDS` default 20 → **5**, so queued queries feel responsive | 06 |
| 22 | `rank_media` handler now wraps work in `caffeinate -s` | 06 |
| 23 | Music handler removed; `group_events` handler added | 06 |
| 24 | Job queue is **Postgres**, not D1 | 03, 06 |

## New files

| File | Contents |
|---|---|
| [15 — OpenClaw](15-openclaw.md) | WhatsApp front door on Oracle |
| [16 — Use case playbooks](16-use-case-playbooks.md) | 🏆 **Every use case end to end** — build steps, runtime flow, cost, failure modes. The three routes and the decision rule |

## Language correction

You caught me writing *"the model searches"* and *"model searches → OpenClaw
calls SearXNG"*, which reads like two things happening. **The model makes zero
network connections.** It emits text describing what it wants and stops.

| Don't say | Say |
|---|---|
| "the model searches" | "the model **asks for** a search" |
| "the model calls the tool" | "the model **emits a tool request**; the client executes it" |

Fixed throughout file 16.

## Still open

| Item | How to settle it |
|---|---|
| **Can you get an Oracle A1 instance in an Indian region?** | 🚨 Try this first — it blocks Phase 2. Expect to retry over days |
| Can OpenClaw scope MCP servers per profile or channel? | ⚠️ Not documented. Prompt at the end of file 15 |
| How does OpenClaw connect to WhatsApp — official API or Web bridge? | Decides the spare-number question |
| Does OpenClaw accept a custom OpenAI base URL? | Decides whether its spend appears on your dashboard |

---

# Round 1 — 2 Aug 2026: verification research

**Source:** your research files `AI_Pricing_and_API_Research.md`,
`india_ai_research_2026-08-02.md`, `research_5_to_10_official_sources.md`

---

## About the research quality

Two research passes disagreed substantially. I used the **ChatGPT** and
**Research 5–10** files, and mostly discarded the first Gemini file.

| | ChatGPT / Research 5–10 | Gemini file |
|---|---|---|
| Dated sources | ✅ "crawled Aug 2, 2026", per-page update dates | ❌ "Not Shown" everywhere |
| Model generation cited | Current | ❌ Gemini 1.5, GPT-4o, Claude 3.5 — over a year stale |
| Honest about gaps | ✅ Marks NOT FOUND | ⚠️ Fills in, then asserts wrongly |

The Gemini file claimed *"OpenAI, Anthropic, and GitHub do not offer official
ChatGPT Go, Claude Max, or Copilot Pro+ tiers."* All three exist. That single
error made the rest of that file untrustworthy.

**Lesson worth keeping:** research quality varies enormously between models. The
prompts in file 13 that force official sources and NOT FOUND answers are what
made the difference — the more rigorous run followed them, the other did not.

---

## 🚨 One real bug found

**Cloudflare KV allows only 1,000 writes per day.** A heartbeat every 60 seconds
is 1,440 writes/day. It would have worked every morning and started failing every
afternoon.

Fixed in **file 03** — the heartbeat uses **D1** (100,000 writes/day), which the
Worker code already did. The table that suggested KV was wrong.

---

## Corrections applied

| # | Was | Now | Files changed |
|---|---|---|---|
| 1 | GLM Coding Plan ~₹300–550 | 🚨 **$18 = ₹1,584.** Rejected — Claude Pro is better for ₹176 more | 00 |
| 2 | Cerebras free tier ~1M tokens/day | 🚨 **$5 credits, 30-day expiry.** Not a standing free tier | 00, 02 |
| 3 | Qwen Code CLI free tier | 🚨 **Discontinued 15 Apr 2026** | 00 |
| 4 | Oracle free: 4 cores / 24 GB | ⚠️ **2 OCPU / 12 GB** on the current page | 03, 10 |
| 5 | Heartbeat in KV | 🚨 **D1 only** — KV write limit too low | 03 |
| 6 | `max_budget` in `litellm_settings` | ✅ **`general_settings`**, duration `1mo` not `30d` | 02 |
| 7 | `mcpo --allow-tools` | 🚨 **No such flag exists.** I invented it | 04 |
| 8 | MLX is 20–40% faster | ⚠️ **Not published.** No controlled benchmark exists | 01 |
| 9 | Aesthetic weights `sac+logos+ava1-l14-linearMSE.pth` | ✅ **`ava+logos-l14-linearMSE.pth`** | 07 |
| 10 | Whisper turbo ≈ 1.6 GB | ✅ **0.464 GB** (4-bit MLX) | 01 |
| 11 | Immich search `/api/search/smart` | ✅ **`/api/search/metadata`** | 10 |
| 12 | Spend-log columns are stable | ⚠️ **Not a public contract** — read `schema.prisma` from your tag | 11 |
| 13 | Gemini Pro blended ₹385 | ✅ **₹297** — cheaper than I thought | 00 |
| 14 | DeepSeek $0.28/$0.42 | ⚠️ **Unverified.** Two passes failed. Use Flash-Lite instead | 00 |
| 15 | `nomic-embed-text` unqualified | ⚠️ **Only 2K context.** Use `qwen3-embedding:4b` (40K) for documents | 01 |
| 16 | Airtel Perplexity offer live | ❌ **Claims closed 16 Jan 2026** | 00 |
| 17 | Indian VPS prices ₹250–400 | ⚠️ **Unverified** — no official pricing found. Check before buying | 03 |
| 18 | Tailscale 100 devices free | ⚠️ **Not found.** India DERP not guaranteed either | 03 |

---

## Confirmed correct — no change needed

| Claim | Status |
|---|---|
| Google Photos closed to whole-library access | ✅ Confirmed by both passes. Picker is user-mediated only |
| Gemini **free** tier trains on your data; paid does not | ✅ Confirmed from Google's own pricing table |
| Spotify recommendations closed to new apps (27 Nov 2024) | ✅ Confirmed |
| MusicKit requires paid Apple Developer membership | ✅ Confirmed — AppleScript remains the right call |
| AppleScript Music control still works, no deprecation | ✅ Confirmed |
| LiteLLM `fallbacks` under `router_settings` | ✅ Confirmed for v1.86.2 |
| LiteLLM `metadata.tags` for request tagging | ✅ Confirmed — there's a `tag_tracking` docs page |
| LiteLLM UI at `/ui`, Postgres via `DATABASE_URL` | ✅ Confirmed |
| Open WebUI `OPENAI_API_BASE_URL` / `OPENAI_API_KEY` | ✅ Confirmed |
| Immich external library reads a folder in place | ✅ Confirmed |
| Cloudflare Workers 100,000 requests/day | ✅ Confirmed |
| Anthropic MCP connector is **remote-only** | ✅ Confirmed — local stdio needs a local client |
| OpenClaw is real, MIT, by Peter Steinberger, early-stage | ✅ Confirmed |
| Don't run OpenClaw beside employer source code | ✅ Independently reached the same conclusion, more forcefully |

---

## New things learned

| Discovery | Why it matters |
|---|---|
| **Google AI Plus is ₹399/month in India** | You already have it via Google One → **₹0 incremental** |
| **Gemini has native server-side MCP** — `type: "mcp_server"`, Streamable HTTP | Directly usable since you already pay for Gemini. Still remote-only |
| Gemini Flash **cached input $0.03/1M** — a 10× discount | Big for repeated automation prompts |
| **Worker CPU capped at 10 ms/request** | Confirms heavy work must live on the Mac |
| **Cron triggers: 5 per account** | Plan your schedules; branch on the hour inside one trigger |
| Open WebUI supports `ENABLE_SIGNUP`, `RAG_EMBEDDING_ENGINE`, `RAG_EMBEDDING_MODEL` as env vars | No clicking through the UI |
| `OPENAI_API_BASE_URLS` plural form (semicolon-separated) | Multiple endpoints at once |
| Immich ML can be omitted from Compose entirely | Best way to cut its memory use |
| Last.fm has a **100 MB stored-data cap** | Irrelevant at your scale, but real |
| Jio offer runs to **29 Oct 2026** | Not applicable to you, but if your plan changes |

---

## Still unverified

| Item | What to do |
|---|---|
| **DeepSeek pricing** | Check api-docs.deepseek.com/quick_start/pricing. Until then use Gemini Flash-Lite |
| **Your Groq limits** | Read them from console.groq.com and put them in `quota_limits` (file 11) |
| **AppleScript `download`** | One-line test: `osascript -e 'tell application "Music" to download track 1 of playlist "Library"'` |
| **Does AI Plus unlock Gemini CLI Pro models?** | Run `gemini` and see what you're offered |
| **Immich minimum RAM** | Not published. Measure with `docker stats` |
| **Indian VPS prices** | Check Utho and E2E directly before buying |

---

## Budget: before and after

| | Before | After |
|---|---|---|
| Recommended | ChatGPT Go ₹649 + GLM ₹1,584 + VM ₹400 + API ₹400 = **₹3,033** ❌ over | **API credits ₹1,000** = **₹1,000** ✅ |
| Why it changed | GLM was 3× my estimate; ChatGPT Go unnecessary because you already have Google AI Plus; Cloudflare free tier replaces the VM | |

Upgrade trigger: when **Sonnet 5's intro pricing ends 31 Aug 2026**, compare your
dashboard's monthly spend against Claude Pro at ₹1,760 and switch if metered
costs more.

---

Back to: [README](README.md) · [Decisions and costs](00-decisions-and-costs.md)
