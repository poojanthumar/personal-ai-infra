# Personal AI Stack — Build Plan

MacBook Pro M1 Pro, 16 GB · India · budget ₹2,000–3,000/month.

**Front door: OpenClaw on WhatsApp.** Everything else exists to serve it.

---

## How to use these files

Each file is a build step. They're numbered in the order you should do them.

**Every file ends with a `⚠️ Verify with AI` section.** I have no web access, so
anything I couldn't confirm is listed there with a ready-made prompt. Paste it
into Gemini, ChatGPT, or any web-enabled AI, then update the file with what comes
back.

> **The rule:** if you see ⚠️ in a file, the answer is in that file's verify
> prompt. Don't guess, and don't trust my number.

Two files are **prompt-only** because I genuinely lack the information to write
them accurately:

| File | Why |
|---|---|
| [07 — OpenClaw](07-openclaw.md) | Config format, tool interface, WhatsApp method and MCP support are all version-specific and undocumented in what I have. The file contains a prompt that generates the real setup guide |
| [08 — MCP servers](08-mcp-servers.md) | Which servers exist and their current tool counts change constantly. The architecture is fixed; the catalogue is a prompt |

---

## The design in one picture

```
   Your phone                Oracle VM (free, always on)         MacBook
   ──────────                ───────────────────────────         ───────
   WhatsApp    ──────────▶   OpenClaw    (front door)
                             LiteLLM     (router, budgets)
                             Postgres    (job queue + logs)
                             MCP servers (community + hosted)
                             SearXNG     (search)
                             Crawl4AI    (page reading)
                                   │
                                   │  Mac asks: "any jobs?"
                                   ◀───────────────────────────  Pull agent
                                   │                              Ollama 12B
                                   └───────────────────────────▶  CLIP scorer
                                       here's job 42               ffmpeg
                                                                   your files
```

**Two rules make this work:**

1. **Your Mac always asks. Nothing connects into it.** That's why it works on
   Indian internet with no fixed IP, and why a sleeping Mac means jobs *wait*
   instead of failing.
2. **Models handle text. Your Mac handles files.** Never send media to a model —
   score it locally, send a text summary. Doing it the other way costs
   ₹15,000–25,000 for one pass over your 10 GB.

Full reasoning: [00 — Architecture](00-architecture.md).

---

## Files in build order

| # | File | Time | What you get |
|---|---|---|---|
| 00 | [Architecture](00-architecture.md) | read | **Start here.** The design and why |
| 01 | [Decisions and costs](01-decisions-and-costs.md) | read | Every option ranked, model tables, budget |
| 02 | [Local AI](02-local-ai.md) | 1 h | Models on your Mac |
| 03 | [**Photo ranker**](03-photo-ranker.md) | 3 h | 🏆 **Real value on day one. ₹0** |
| 04 | [Oracle box](04-oracle-box.md) | 3 h | The always-on machine + job queue |
| 05 | [Mac agent](05-mac-agent.md) | 2 h | Remote requests reach your files |
| 06 | [LiteLLM](06-litellm.md) | 1 h | Router, budgets, privacy gate |
| 07 | [**OpenClaw**](07-openclaw.md) | 3 h | 🏆 **WhatsApp front door** (prompt-driven) |
| 08 | [MCP servers](08-mcp-servers.md) | 1 h | Community tools (prompt-driven) |
| 09 | [Reels](09-reels.md) | 3 h | Ranked clips + music → video |
| 10 | [Albums](10-albums.md) | 3 h | Photos grouped into events |
| 11 | [Web research](11-web-research.md) | 2 h | Search and read, ₹0 |
| 12 | [Dashboard](12-dashboard.md) | 2 h | Spend, jobs, quotas |
| 13 | [Request flows](13-request-flows.md) | read | What happens at runtime, step by step |
| 14 | [**Verification prompts**](14-verification-prompts.md) | — | 🏆 Every web-research prompt in one place |
| 15 | [Build prompts](15-build-prompts.md) | — | Prompts for AI to write the code |

### Appendices — not in the plan

| File | Why it's here |
|---|---|
| [A1 — Telegram fallback](A1-telegram-fallback.md) | If WhatsApp gets your number banned, or OpenClaw fights you. Simpler to debug |
| [A2 — Open WebUI](A2-openwebui-optional.md) | Only if you want document upload and RAG |
| [A3 — Music, out of scope](A3-music-out-of-scope.md) | Dropped. Kept for reference |
| [CHANGELOG](CHANGELOG.md) | What changed and why, across two rounds of corrections |

---

## Minimum viable stack

You don't need all of it. Three useful stopping points:

| Stop after | You have | Cost |
|---|---|---|
| **03** | Your 10 GB of media scored, deduplicated, ranked to your own taste | **₹0** |
| **07** | All of that, plus WhatsApp control from anywhere | **₹0** + spare SIM |
| **12** | The whole thing, with visibility into what it costs | ~₹1,200/mo |

**Steps 02 and 03 alone solve the problem you originally described.** Do those
first regardless of what else you decide.

---

## What it costs

| Item | ₹/month |
|---|---|
| Google AI Plus — already bundled with your Google One | **0** |
| Oracle Always Free VM | **0** |
| Local models, CLIP, ffmpeg, SearXNG, Crawl4AI, Postgres, OpenClaw, Tailscale | **0** |
| Coding — metered Claude Sonnet 5 | ~1,000 |
| Automation calls — reels, captions, album names | ~50 |
| ⚠️ Spare SIM for WhatsApp | 150–200 |
| **Total** | **~₹1,200** |

⚠️ Sonnet 5's intro pricing ends **31 Aug 2026**. When it does, compare your
dashboard spend against Claude Pro at ₹1,760 and switch if metered costs more.

---

## Two things that gate the build

Do both **before** building, because either can change the plan:

1. 🚨 **Can you get an Oracle A1 instance in Mumbai or Hyderabad?** Free capacity
   isn't guaranteed. Expect to retry over several days. If you can't, Phase 2
   becomes a ₹250–500 Indian VM instead. → [04](04-oracle-box.md)
2. ⚠️ **How does OpenClaw connect to WhatsApp** — official API or unofficial Web
   bridge? That decides whether you need a spare number. → [07](07-openclaw.md)

---

## Symbols

| Symbol | Meaning |
|---|---|
| ✅ | Verified against an official source |
| ⚠️ | **Unverified — answered by the verify prompt in that file** |
| 🚨 | Important warning |
| 🏆 | Recommendation |
| ❌ | Don't do this |

---

## Archive

The previous version of this plan is in `../personal-ai-stack 2/`. It used
Cloudflare Workers as the always-on box and a Telegram bot as the front door. Both
were replaced — see [CHANGELOG](CHANGELOG.md) for why.
