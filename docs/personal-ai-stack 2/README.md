# Personal AI Stack — Plan & Build Guide

Built for: MacBook Pro M1 Pro, 16 GB RAM · India · budget ₹2,000–3,000 per month.

> **Read [CHANGELOG.md](CHANGELOG.md) before following any pricing advice.**
> Verification research on 2 Aug 2026 corrected 18 things, including one real bug
> in the design.

---

## The short version

Three machines, three jobs:

```
Your phone  ──▶  Oracle VM (free, always on)  ──▶  MacBook (heavy work)
   WhatsApp      - OpenClaw (front door)           - Local 12B model
                 - LiteLLM (router, budgets)       - CLIP photo scoring
                 - Postgres (job queue)            - ffmpeg rendering
                 - All MCP servers                 - Your files
                 - SearXNG, Crawl4AI
                 - Dashboard
```

**The one rule that makes it work:** your MacBook always *asks* the Oracle box
for work. Nothing ever connects *into* your MacBook. That's why it works on
Indian internet without a fixed IP address.

**The second rule:** AI models handle text. Your Mac handles files. The router
just passes messages. Never send media to a model — score it locally and send a
text summary.

---

## Read in this order

| # | File | What it covers |
|---|---|---|
| 00 | [Decisions and costs](00-decisions-and-costs.md) | **Start here.** Every option compared, ranked, priced. Model comparison tables |
| 16 | [**Use case playbooks**](16-use-case-playbooks.md) | 🏆 **Then here.** Every use case end to end — build steps and what happens at runtime |
| 01 | [Local AI setup](01-local-ai-setup.md) | Models on your Mac, which fit in 16 GB |
| 07 | [Photo and video ranker](07-photo-video-ranker.md) | 🏆 **Build this second.** Score 10 GB+ by how good it looks. ₹0 |
| 02 | [LiteLLM router](02-litellm-router.md) | One address for all models, budgets, the privacy gate |
| 03 | [Oracle VM and hosting](03-vm-hosting.md) | The always-on box, job queue API, Tailscale |
| 06 | [Job queue and Mac agent](06-job-queue-and-mac-agent.md) | **The core piece.** How a message reaches your files |
| 15 | [OpenClaw](15-openclaw.md) | WhatsApp front door on Oracle |
| 08 | [Reels pipeline](08-reels-pipeline.md) | Ranked clips + music → short video |
| 10 | [Photos and albums](10-photos-albums.md) | Group photos into events, name them |
| 12 | [Web crawling](12-web-crawling.md) | Search and read websites, ₹0 |
| 11 | [Dashboard](11-dashboard.md) | Tokens used, money left, jobs run |
| 04 | [Open WebUI](04-openwebui.md) | Optional. Only for document upload and RAG |
| 13 | [AI prompts](13-ai-prompts.md) | Copy-paste prompts for building |
| 14 | [Research prompts](14-research-prompts.md) | Prompts for verifying prices yourself |
| — | [CHANGELOG](CHANGELOG.md) | What changed after verification, what's still unverified |

### Not part of the plan

| File | Why it's here |
|---|---|
| [05 — Telegram bot](05-telegram-bot.md) | ⚠️ **Superseded by OpenClaw (15).** Keep as a fallback if WhatsApp doesn't work out |
| [09 — Apple Music](09-apple-music.md) | ⚠️ **Out of scope.** Kept for reference only |

---

## Build order

| # | Build | Time | Why now |
|---|---|---|---|
| 1 | Local models ([01](01-local-ai-setup.md)) | 1 h | Everything depends on it |
| 2 | **Photo ranker ([07](07-photo-video-ranker.md))** | 3 h | 🏆 Real value on day one, ₹0, no cloud |
| 3 | LiteLLM ([02](02-litellm-router.md)) | 1 h | Budgets and the privacy gate |
| 4 | Oracle box ([03](03-vm-hosting.md)) | 3 h | Always-on |
| 5 | Mac agent ([06](06-job-queue-and-mac-agent.md)) | 2 h | Remote requests reach your files |
| 6 | OpenClaw ([15](15-openclaw.md)) | 3 h | WhatsApp |
| 7 | Reels ([08](08-reels-pipeline.md)) | 3 h | Videos |
| 8 | Albums ([10](10-photos-albums.md)) | 3 h | Event grouping |
| 9 | Research ([12](12-web-crawling.md)) | 2 h | Search, ₹0 |
| 10 | Dashboard ([11](11-dashboard.md)) | 2 h | Visibility |

**Steps 1 and 2 alone are worth doing even if you build nothing else.** They cost
₹0 and solve the problem you actually described.

---

## What it costs

| Item | ₹/month |
|---|---|
| Google AI Plus — already bundled with your Google One | **0** |
| Oracle Always Free VM | **0** |
| Local models, CLIP, ffmpeg, SearXNG, Crawl4AI, Postgres, OpenClaw, Tailscale | **0** |
| Coding — metered Claude Sonnet 5 | 1,000 |
| Automation calls — reels, captions, album names | ~50 |
| ⚠️ Spare SIM for WhatsApp | 150–200 |
| **Total** | **~₹1,200** |

A third of your ceiling. ⚠️ Upgrade trigger: when Sonnet 5's intro pricing ends
**31 Aug 2026**, compare your dashboard spend against Claude Pro at ₹1,760.

---

## Three things worth knowing up front

**Your Mac is the best hardware in this plan.** Its unified memory gives ~200 GB/s
bandwidth — roughly 10× a cloud VM you could afford. Never rent a GPU.

**Google Photos is closed.** ⚠️ Since 31 Mar 2025 third-party apps can only see
media they created. Whole-library automation isn't buildable. Use Immich or
osxphotos instead ([file 10](10-photos-albums.md)).

**Keep work and personal completely separate.** Some of the best-value providers
are Chinese companies. Fine for personal projects. **Never for Apple work code**,
and never on the same machine as OpenClaw.

---

## Symbols

| Symbol | Meaning |
|---|---|
| ✅ | Verified against an official source |
| ⚠️ | Check yourself — prices and limits change |
| 🚨 | Important warning |
| 🏆 | My recommendation |
| ❌ | Don't do this |

**Anthropic prices are confirmed.** Everything else was verified on 2 Aug 2026 or
is marked ⚠️. Always check a provider's own page before paying.

---

## Using AI to build this

Many files have a **"Prompt for AI"** section, written for Gemini Pro/Flash or
Composer. They're deliberately narrow — one small job each, exact file path,
exact output format.

Four rules that keep weak models useful:

1. **One file, one job.** Never "build the whole system".
2. **Show the shape of the answer.** Give the exact table or JSON you want.
3. **Never trust config it writes from memory.** LiteLLM, Docker, Grafana formats
   change often and models produce last year's version. Ask for **code**; look up
   **config**.
4. **Ask it to explain.** "Add a comment above each function" makes mistakes
   visible in seconds.

Full guidance: [13-ai-prompts.md](13-ai-prompts.md).
