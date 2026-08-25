# CHANGELOG

# Round 4 — 2 Aug 2026: verification results folded in

**Source:** `~/Downloads/resposne_ai.txt` — one model's answers to prompts 01–07.

## Quality: mixed, and one output must not be trusted

| Prompt | Verdict |
|---|---|
| 01 Pricing | ⚠️ Partly stale (sources Feb 2025 / Jul 2025), **two wrong answers** |
| 02 Local models | ⚠️ Mixed — one good find, two dubious claims, one wrong answer |
| 03 Photo tooling | ✅ **Best of the set.** Three genuine upgrades |
| 04 Oracle | ✅ **Strong.** Resolved the reclamation question |
| 05 Path safety | ✅ **Excellent — found a real hole in my code** |
| 06 LiteLLM | ⚠️ Older version than the previous pass, but one major finding |
| 07 OpenClaw | 🚨 **Do not follow as written** |

### Two answers rejected outright

| Claim | Reality |
|---|---|
| "Anthropic has not released Claude Sonnet 5" | **Wrong.** It exists: 1M context, $3/$15, $2/$10 intro through 31 Aug 2026, from Anthropic's own reference. Kept my figures |
| "Google does not recognise an AI Plus plan" | **Wrong.** Poojan has it. An earlier pass found ₹399/month on `one.google.com/intl/en_in` |

Both point the same way: that pass's training is older than the previous one's.
**Heuristic added:** when two passes disagree, prefer the one citing newer model
names.

## 🚨 Four findings that changed the plan

### 1. `caffeinate -s` does not survive a closed lid — file 05, 03

The man page says the assertion is *"valid only when system is running on AC
power"*, and clamshell sleep overrides IOKit power assertions. **A 25-minute photo
scan dies when you shut the lid, even plugged in.**

Fix documented: rely on **resumability** (the ranker already skips scored files) plus
the hourly `/jobs/reclaim`, and leave the lid open for big runs.

### 2. Hard links defeat `safe_path()` — file 05

> *"`.resolve()` does not resolve hard links — it treats the hard link as a normal
> file located inside the root."*

A real hole I hadn't considered. Added an optional `reject_hard_links()` guard.
Also confirmed: **`is_relative_to()` is purely lexical**, so both candidate and
root must be resolved — my code already resolves roots at load, so that part was fine.

### 3. 🏆 LiteLLM **is** an MCP gateway, with tool filtering — files 06, 08

```yaml
mcp_servers:
  - name: weather_mcp
    base_url: http://weather-mcp-server:8080
    include_tools: ["get_weather"]
```

**The most useful finding in the whole response.** `include_tools` is exactly the
per-tool allowlist I said didn't exist in mcpo — and I'd previously invented an
`mcpo --allow-tools` flag that doesn't exist.

Revised recommendation: **register MCP servers in LiteLLM, not in OpenClaw.**
Central config, tool filtering, and MCP spend on the same dashboard.

### 4. Oracle is less risky than I implied — file 04

- **Reclamation needs all three simultaneously** over 7 days: CPU <20%, network
  <20%, **and** memory <20%. Postgres alone keeps memory above 20%.
- 🏆 **Pay-As-You-Go accounts get capacity priority** while still using free-tier
  resources — the real workaround for the Mumbai shortage. Add a card, pay ₹0.
- ⚠️ **Allocation now disputed**: this pass says 4 OCPU / 24 GB, the last said
  2 / 12. Check your own tenancy console.
- Both passes independently concluded: don't make it your only Postgres host.

## Other changes

| # | Change | File |
|---|---|---|
| 25 | 🏆 **`qwen2.5-vl:3b`** replaces `gemma3:4b` for captioning — 1.9 GB, 128K context, **supports tool calling** | 02 |
| 26 | 🏆 **MediaPipe** replaces OpenCV Haar cascades — "SUPERSEDED", and gives eye-aspect-ratio for eyes-open | 03 |
| 27 | 🏆 **`pyobjc-framework-Vision`** exposes Apple's `VNDetectFaceCaptureQualityRequest` on the Neural Engine | 03 |
| 28 | 🏆 **`pyiqa`** (NIMA/MUSIQ/CLIP-IQA/TOPIQ) — LAION's predictor is **UNMAINTAINED since 2022** | 03 |
| 29 | ✅ **Utho ₹350/mo, E2E ₹375/mo** — Phase 4 is cheaper than estimated | 01, 04 |
| 30 | ✅ **Tailscale: unlimited devices, 6 users, DERP relay in Bengaluru** | 04 |
| 31 | ✅ **`nomic-embed-text` context is 8,192**, not 2,000 as I said — fine for documents after all | 02 |
| 32 | ✅ **`key_alias` is supported**, plus `tpm_limit`, `rpm_limit`, `soft_budget` | 06 |
| 33 | ✅ **Spend-log columns confirmed** — all four my SQL uses exist. `metadata` is a **JSON** column, so tags are queryable | 06, 12 |
| 34 | 🏆 **Health-check driven routing** (`background_health_checks`, `/router/cooldown`) — cleaner than timeout failover | 06 |
| 35 | 🚨 Whisper answer rejected — it gave `tiny.en` (least accurate) for "smallest accurate". Kept `large-v3-turbo` | 02 |
| 36 | ⚠️ **LAION weights filename: three sources, three answers.** Unresolved — check the repos, or sidestep with `pyiqa` | 02, 03 |
| 37 | ⚠️ `gemma3:4b → gemma3n:e4b` claim doubted — Gemma 3 and 3n are different models | 02 |
| 38 | ⚠️ DeepSeek still unverified (Feb 2025 source). **Use Gemini Flash-Lite** | 01 |
| 39 | ⚠️ Groq limits stale (listed retired `mixtral-8x7b`). Read your own console | 01 |
| 40 | ⚠️ LiteLLM version conflict: v1.86.2 vs v1.70. Run `litellm --version` | 06 |

## 🚨 File 07 — a generated guide arrived and should not be followed

The prompt produced a polished, complete-looking guide with exact JSON5 keys, a
gateway port (`18789`), CLI commands, and doc URLs. **The previous pass explicitly
found all of that NOT DOCUMENTED.** Producing precise config where another pass
found nothing is the classic hallucination signature — and the same response was
demonstrably stale elsewhere.

Added to file 07: **a five-minute verification checklist** (`npm view`, `--help` on
each claimed command, `ss -tlnp` for the port) plus a table of the specific claims
worth checking. If `openclaw channels login` and `openclaw mcp reload` both exist,
the guide is probably sound; if either is unrecognised, discard its config sections.

**One thing worth acting on regardless:** it claims `exec`, `filesystem` and
`browser` tools are **enabled by default**. If true, an unconfigured OpenClaw can
run shell commands on your VM from a WhatsApp message. **Configure the tool
allowlist before linking WhatsApp**, whatever the exact key names turn out to be.

---

# Round 3 — restructure around OpenClaw

**Folder renumbered into build order, and every file now carries its own
verification prompt.**

## Why

The previous version was organised by component, so LiteLLM and Open WebUI led the
plan even after we decided OpenClaw was the right front door. The numbering said
"build LiteLLM second" when the photo ranker gives value first and OpenClaw is
what you actually type into.

## New structure

Numbering is now build order. OpenClaw is a first-class step; Open WebUI and the
Telegram bot are appendices.

| Old | New |
|---|---|
| — | **00-architecture.md** — 🆕 the design, three routes, the two rules |
| 00-decisions-and-costs | 01-decisions-and-costs |
| 01-local-ai-setup | 02-local-ai |
| 07-photo-video-ranker | **03-photo-ranker** — promoted, it's the first thing worth building |
| 03-vm-hosting | 04-oracle-box |
| 06-job-queue-and-mac-agent | 05-mac-agent |
| 02-litellm-router | 06-litellm |
| 15-openclaw | **07-openclaw** — promoted to a core step |
| — | **08-mcp-servers.md** — 🆕 placement, cost, catalogue prompt |
| 08-reels-pipeline | 09-reels |
| 10-photos-albums | 10-albums |
| 12-web-crawling | 11-web-research |
| 11-dashboard | 12-dashboard |
| 16-use-case-playbooks | 13-request-flows |
| 14-research-prompts | 14-verification-prompts — now an index of every prompt |
| 13-ai-prompts | 15-build-prompts |
| 05-telegram-bot | **A1-telegram-fallback** — appendix |
| 04-openwebui | **A2-openwebui-optional** — appendix |
| 09-apple-music | **A3-music-out-of-scope** — appendix |

All cross-references and prose "file NN" mentions were rewritten to match.

## Every file now has a verification prompt

You asked for this. Each file ends with **`⚠️ Verify with AI`** containing:

- A table of what in that file is unverified, and why it matters
- **A ready-to-paste prompt** that answers all of it

And each file's header states plainly that anything marked ⚠️ is answered by that
file's prompt. No more hunting for which claim I couldn't check.

## Two files are now prompt-only

You said: if a file needs mostly web information, put the whole file into a prompt.

| File | Why | Output |
|---|---|---|
| [07 — OpenClaw](07-openclaw.md) | Config format, tool interface, WhatsApp method and MCP support are all **NOT DOCUMENTED** in what I have. A plausible-looking guess would waste more of your time than having none | Prompt generates `07a-openclaw-setup.md` |
| [08 — MCP servers](08-mcp-servers.md) | The architecture is fixed and correct; the *catalogue* changes constantly | Prompt generates `08a-mcp-catalogue.md` |

Both files still contain everything I *can* state accurately — OpenClaw's role in
the architecture, its four required tools, the privacy-gate key, acceptance tests,
and the MCP token-cost arithmetic.

## Folder note

Your `personal-ai-stack` folder had been renamed to `personal-ai-stack 2` (Finder
duplicate). The restructured plan is in a clean `personal-ai-stack`; the old one is
untouched as an archive.

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
under-weighted the two-database problem: the dashboard in file 12 would have had
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

**New: [file 07](07-openclaw.md).** Setup, LiteLLM wiring, the queue tools, and
the security boundary.

⚠️ **The one risk to weigh:** WhatsApp automation usually rides an unofficial Web
bridge and **Meta bans personal numbers for it.** Use a spare SIM (~₹150–200/mo)
or stay on Telegram.

**What OpenClaw replaces:** appendix A1 (Telegram bot) and most of appendix A2 (Open
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

[File 09](A3-music-out-of-scope.md) is kept for reference with an OUT OF SCOPE banner.

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
| [15 — OpenClaw](07-openclaw.md) | WhatsApp front door on Oracle |
| [16 — Use case playbooks](13-request-flows.md) | 🏆 **Every use case end to end** — build steps, runtime flow, cost, failure modes. The three routes and the decision rule |

## Language correction

You caught me writing *"the model searches"* and *"model searches → OpenClaw
calls SearXNG"*, which reads like two things happening. **The model makes zero
network connections.** It emits text describing what it wants and stops.

| Don't say | Say |
|---|---|
| "the model searches" | "the model **asks for** a search" |
| "the model calls the tool" | "the model **emits a tool request**; the client executes it" |

Fixed throughout file 13.

## Still open

| Item | How to settle it |
|---|---|
| **Can you get an Oracle A1 instance in an Indian region?** | 🚨 Try this first — it blocks Phase 2. Expect to retry over days |
| Can OpenClaw scope MCP servers per profile or channel? | ⚠️ Not documented. Prompt at the end of file 07 |
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
prompts in file 15 that force official sources and NOT FOUND answers are what
made the difference — the more rigorous run followed them, the other did not.

---

## 🚨 One real bug found

**Cloudflare KV allows only 1,000 writes per day.** A heartbeat every 60 seconds
is 1,440 writes/day. It would have worked every morning and started failing every
afternoon.

Fixed in **file 04** — the heartbeat uses **D1** (100,000 writes/day), which the
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
| **Your Groq limits** | Read them from console.groq.com and put them in `quota_limits` (file 12) |
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

Back to: [README](README.md) · [Decisions and costs](01-decisions-and-costs.md)
