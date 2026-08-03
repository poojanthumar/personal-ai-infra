# 00 — Decisions and Costs

Everything compared, ranked, and priced. Read this before building anything.

**Confirmed prices:** Claude / Anthropic only.
**⚠️ Unconfirmed:** everything else — from memory around May 2026. Prices and
free limits in India change often. Check before you pay.
**Exchange rate used:** ₹88 = $1.

---

## Part 1 — Three truths that shape every decision

### 1. "Local means unlimited" is true for money, not for ability

Your Mac has 16 GB of memory shared between macOS and the model. After macOS
you have about 10–11 GB. That limits you to models around 8–14 billion
parameters.

Speed depends on **memory bandwidth**, not processor power. To produce one
word, the machine must read the whole model out of memory. So:

```
speed ≈ memory bandwidth ÷ model size
```

Your M1 Pro has about 200 GB/s of bandwidth. That is genuinely excellent — a
cheap cloud server has around 10–20 GB/s. **Your laptop is 10× faster at this
than a rented server you could afford.**

So local models are great for: sorting, tagging, describing images,
summarising, and routing. They are **not** good enough for serious coding or
hard reasoning. Use the cloud for those.

### 2. Google Photos is mostly closed to outside apps now

⚠️ Since around March 2025, Google restricted the Photos API. Outside apps can
generally only see photos they created themselves. Reading your whole library
is no longer possible the way it used to be.

So "point an AI at my Google Photos and build albums" cannot be built as
described. Working alternatives:

- **Immich** — free photo server you run yourself. Has AI search and face
  grouping built in. 🏆 Best replacement.
- **osxphotos** — reads your Apple Photos library from Python. Best if you
  already use Apple Photos.
- **Google Takeout** — download a copy, work on it offline.

### 3. Keep work and personal completely separate

Several of the best-value AI providers are Chinese companies (Z.ai/GLM,
DeepSeek, MiniMax, Kimi). They are excellent for personal projects and hobby
code.

**Never send Apple work code to them.** Use a separate macOS user account, or
at minimum separate config folders and separate API keys. Do not touch your
work Claude Code setup.

---

## Part 2 — What to use for what

### Chat interface (the place you type)

| Option | Cost | Phone support | Verdict |
|---|---|---|---|
| **Telegram bot** | ₹0 | Excellent — it's just Telegram | 🏆 **Build first.** Zero cost, works on any network, sends files and voice. You will actually use it |
| **Open WebUI** | ₹0 | Good — install as a phone app (PWA) | 🏆 **Build second.** Needed for long conversations, file uploads, comparing models |
| LibreChat | ₹0 | Good | Similar to Open WebUI. Pick one, not both |
| Build your own app | Weeks of work | — | ❌ No. You get nothing Telegram doesn't already give you |

**Why both?** Telegram is for quick things — one question, one command, one
result. Open WebUI is for sitting down and working through something. They
share the same brain underneath, so it costs nothing to have both.

### The router (decides which AI model answers)

| Option | Cost | Verdict |
|---|---|---|
| **LiteLLM** (self-hosted) | ₹0 | 🏆 **Yes.** One address for 100+ providers. Real spending limits. Automatic fallback. Logs everything for your dashboard |
| OpenRouter (hosted) | ~5% fee on credits | Good if you never want to run a server. But no self-imposed hard budget cap |
| No router — call each API directly | ₹0 | ❌ You'd rewrite every app when you change models, and you'd have no spending visibility |

### Automation (things that run on a schedule)

| Option | Cost | Verdict |
|---|---|---|
| **n8n** (self-hosted) | ₹0 | 🏆 Visual. Cron timers, webhooks, retries built in. You will maintain it because you can see it |
| Plain Python + cron | ₹0 | Also fine, and lighter. Choose this if you prefer code over drag-and-drop |
| Windmill / Node-RED | ₹0 | Fine, no clear advantage here |

### Where things live

| Option | Cost/month | Always on? | Verdict |
|---|---|---|---|
| **Everything on the Mac + Tailscale** | **₹0** | ❌ Stops when lid closes | 🏆 **Phase 1.** Start here. Prove the whole thing works before paying anything |
| **Cloudflare Workers + D1/KV** | **₹0** | ✅ Yes | 🏆 **Phase 2.** ⚠️ ~100k requests/day free. Perfect for the Telegram webhook and job queue. Nothing to maintain |
| **Oracle Cloud Always Free** (4 ARM cores, 24 GB RAM) | **₹0** | ✅ Yes | 🏆 **Phase 2 alternative** if you want a real Linux box. More RAM than your Mac. ⚠️ Hard to get capacity in Mumbai/Hyderabad; they reclaim idle instances |
| Utho / E2E (Indian providers) | ₹250–400 | ✅ Yes | 🏆 **Phase 3.** Billed in rupees, no forex charge, low latency, Indian data centre |
| AWS Lightsail Mumbai | ₹310–440 | ✅ Yes | Fine. Free for the first 12 months |
| DigitalOcean Bangalore | ₹350–530 | ✅ Yes | Reliable and boring |
| Hetzner ARM (Germany) | ₹300–360 | ✅ Yes | Cheapest solid VM, but ~150 ms extra delay |
| RackNerd yearly plan | ₹80–150 | ✅ Yes | ⚠️ Cheapest paid option if you pay yearly. No India data centre |
| Google Cloud free e2-micro | ₹0 | ✅ Yes | Only 1 GB RAM, US only. Works but tight |
| ❌ Cloud GPU (rented graphics card) | ₹15,000–36,000 | ✅ | ❌ **Never.** 5–10× your whole budget, and slower than your Mac for this work |

### Connecting phone to home

| Option | Cost | Works on Indian ISPs? | Verdict |
|---|---|---|---|
| **Mac asks VM for work (pull queue)** | ₹0 | ✅ Always | 🏆 For background jobs. Jobs wait safely if the Mac is asleep |
| **Tailscale** | ₹0 | ✅ Yes, even behind CGNAT | 🏆 For live chatting with your local model. Gives your Mac a permanent private address |
| SSH reverse tunnel + autossh | ₹0 | ✅ Yes | Good backup. No extra software needed |
| Cloudflare Tunnel | ₹0 | ✅ Yes | Gives a public HTTPS link without a VPN app on the phone |
| ❌ Port forwarding + DDNS | ₹0 | ❌ **No** | ❌ Most Indian ISPs (especially Jio) give you a shared IP. There is no port to forward |

### Web searching and reading

| Job | Tool | Cost | Verdict |
|---|---|---|---|
| Search | **SearXNG** (self-hosted) | ₹0 | 🏆 No API key, no daily limit |
| Search backup | Brave API / Tavily | ₹0 | ⚠️ ~2,000 and ~1,000 free calls/month |
| Read a page | **Crawl4AI** | ₹0 | 🏆 Runs locally, converts pages to clean text for AI |
| Read a page (hosted) | Firecrawl | ⚠️ ~500 free/month | Good, but you don't need it |
| Click around a site | **Playwright MCP** | ₹0 | 🏆 Made by Microsoft. Lets AI actually use a browser |

### Photos and music

| Job | Tool | Cost | Verdict |
|---|---|---|---|
| Photo library with AI search | **Immich** (self-hosted) | ₹0 | 🏆 Face grouping and text search built in |
| Read Apple Photos | **osxphotos** | ₹0 | 🏆 If you live in Apple Photos |
| Score photos by how good they look | **CLIP + aesthetic model** | ₹0 | 🏆 See file 07 |
| Video editing | **ffmpeg** | ₹0 | 🏆 The only real answer |
| Beat detection for music sync | librosa or aubio | ₹0 | 🏆 |
| Control Apple Music | **AppleScript** (`osascript`) | ₹0 | 🏆 Built into macOS. Can make playlists, set ratings, trigger downloads |
| Apple Music official API | Apple Developer Program | ⚠️ ₹8,900/year (~₹740/mo) | ❌ **Skip it.** AppleScript does the same for free |
| Find similar music | Last.fm or ListenBrainz API | ₹0 | 🏆 ⚠️ Spotify closed its recommendation API to new apps around Nov 2024 — don't plan around it |

---

## Part 3 — Model comparison

### Tier 0 — Models that run on your Mac (free forever)

Remember: model size on disk is not the full memory cost. Running an 8B model
with a long conversation needs about 2 GB extra for the conversation memory.
So "5 GB model" really means about 7 GB in use.

| Model | Size (Q4) | Speed on M1 Pro | Fits? | Best for |
|---|---|---|---|---|
| **Qwen3-4B** | 2.5 GB | 35–50 words/sec | ✅ Easy | 🏆 Sorting requests, tagging, naming albums |
| **Gemma-3-4B** (vision) | 2.6 GB | 35–45 | ✅ Easy | 🏆 Describing thousands of photos |
| **Qwen3-8B** | 5.0 GB | 20–30 | ✅ Comfortable | 🏆 Your general local workhorse |
| **Qwen2.5-VL-7B** | 5.5 GB | 18–25 | ✅ | Reading text in screenshots and documents |
| **Gemma-3-12B** (vision) | 7.5 GB | 12–18 | ⚠️ Tight | Best local vision model that fits |
| **Qwen3-14B** | 9.0 GB | 10–16 | ⚠️ Uses most of your RAM | Best local reasoning — but your Mac gets slow |
| gpt-oss-20b | 12–13 GB | 20–30 | ❌ Swaps to disk | Fast design, but too big for 16 GB |
| Mistral-Small-24B | 14+ GB | — | ❌ | Needs 24 GB+ |
| **nomic-embed-text** | 275 MB | Very fast | ✅ | Search over your own notes and files |
| **CLIP ViT-L/14** | 1.7 GB | 30–60 images/sec | ✅ | 🏆 The photo ranker |
| **whisper-large-v3-turbo** | 1.6 GB | ~10× real time | ✅ | Transcribing audio and video |

**Tip:** use **MLX** versions instead of GGUF where you can. MLX is built for
Apple chips and runs 20–40% faster for the same model.

**Electricity cost:** M1 Pro under full load is about 40 W. That is roughly
**₹0.30 per hour**. Effectively free.

### Tier 1 — Free cloud APIs ⚠️

| Provider | Models | Free limits (approx) | Speed | Warning |
|---|---|---|---|---|
| **Groq** | Llama 3.3 70B, Llama 4, Qwen3-32B, Kimi K2, gpt-oss-120b | ~30/min, 1k–14k/day, **plus a daily token cap** (~100k–500k) | 🏆 300–1,000 words/sec | The token cap runs out fast on long documents |
| **Cerebras** | Llama, Qwen, gpt-oss | ~30/min, ~1M tokens/day | 🏆 2,000+ words/sec | Fewer models available |
| **Gemini API** (AI Studio) | Flash and Pro models | Flash ~10–15/min, 250–1,500/day. Pro ~5/min, ~100/day | Fast | 🚨 **Free tier data may be used to train Google's products** |
| **OpenRouter** free models | DeepSeek, Qwen, GLM, Llama | ~20/min; ~50/day, rises to ~1,000/day after a one-time $10 credit | Varies | Shared capacity, so speed varies |
| Cloudflare Workers AI | Small open models | ~10k units/day | Fast | Limited model list |
| GitHub Models | GPT, Llama, Phi | Low | — | Testing only |

🚨 **Important:** because Gemini's *free* tier may train on your data, never
send personal photos, private notes, or personal context to it. Use **Groq or
Cerebras free** for anything personal, and Gemini free only for public
research and drafting. Gemini's *paid* tier does not train on your data.

**Groq + Cerebras together give you roughly 1.5 million free tokens per day at
very high speed.** That alone can be your entire cloud layer.

### Tier 2 — Cheap paid APIs ⚠️

"Blended" price assumes 3 words in for every 1 word out, which is realistic.

| Model | $/1M in | $/1M out | Blended ₹/1M | Verdict |
|---|---|---|---|---|
| **Gemini Flash-Lite** | 0.10 | 0.40 | **₹15** | 🏆 Cheapest usable. Bulk tagging and sorting |
| **DeepSeek V3.x** | 0.28 | 0.42 | **₹28** | 🏆 Best quality per rupee. Cached input drops to ~₹2.5/1M. Off-peak discount 50–75% |
| MiniMax M2 | 0.30 | 1.20 | ₹53 | Solid middle option |
| Gemini 2.5/3 Flash | 0.30 | 2.50 | ₹75 | Good all-rounder, paid tier does not train on your data |
| GLM-4.6 / 4.7 | 0.60 | 2.20 | ₹88 | Strong at code — but take the flat monthly plan instead (below) |
| Kimi K2 | 0.60 | 2.50 | ₹95 | Good for very long documents |
| DeepSeek R1 (reasoning) | 0.55 | 2.19 | ₹85 | Cheap step-by-step reasoning |
| Grok-4-fast | ~0.20–0.30 | — | ~₹30–50 | Fast and cheap |

⚠️ DeepSeek, GLM, Kimi, MiniMax are Chinese providers. Great for personal
projects. **Never for Apple work code.**

### Tier 3 — Premium models (Anthropic prices confirmed)

| Model | Model ID | Context | $/1M in | $/1M out | Blended ₹/1M |
|---|---|---|---|---|---|
| Claude Fable 5 | `claude-fable-5` | 1M | 10.00 | 50.00 | ₹1,760 |
| **Claude Opus 5** | `claude-opus-5` | 1M | 5.00 | 25.00 | **₹880** |
| Claude Sonnet 5 | `claude-sonnet-5` | 1M | 3.00 (**2.00 intro until 31 Aug 2026**) | 15.00 (**10.00 intro**) | ₹528 (**₹352 intro**) |
| Claude Haiku 4.5 | `claude-haiku-4-5` | 200K | 1.00 | 5.00 | **₹176** |

⚠️ For comparison: Gemini 3 Pro ~$1.25/$10 (₹385 blended). GPT-5.x mini-class
~$0.25/$2 (₹60).

**Three discounts that matter more than the sticker price:**

| Discount | Effect | Use it for |
|---|---|---|
| **Prompt caching** | Repeated parts of your prompt cost about **1/10th** | Your automations send the same instructions every night. Huge saving |
| **Batch API** | **50% off**, finishes within about an hour | All your overnight jobs |
| **Effort setting** | `effort: "low"` or `"medium"` on Opus 5 cuts token use a lot | Routine tasks. Low and medium are unusually good on this model |

Minimum size for caching to work: **512 tokens** on Opus 5, 1,024 on Sonnet 5,
4,096 on Haiku 4.5. Below that it silently does not cache.

Caching plus batching realistically turns ₹880/1M into **₹150–250/1M** for
work shaped like yours.

### Overall capability ranking

| Rank | Models | Can you afford it? |
|---|---|---|
| **S — best available** | Claude Fable 5, **Claude Opus 5**, Gemini 3 Pro, GPT-5.x flagship | Only in small amounts. About 600k tokens/month for ₹500 |
| **A — nearly as good** | **Claude Sonnet 5**, GLM-4.7, DeepSeek V3.x/R1, Kimi K2, **gpt-oss-120b (free on Groq!)**, Gemini Flash | ✅ **This is your working tier.** Millions of tokens, or flat monthly fee |
| **B — fast and cheap** | Claude Haiku 4.5, Gemini Flash-Lite, Llama 4, Qwen3-32B | ✅ Effectively unlimited at your budget |
| **C — local medium** | Qwen3-14B, Gemma-3-12B, Qwen3-8B | ✅ Truly unlimited, ₹0 |
| **D — local small** | Qwen3-4B, Gemma-3-4B | ✅ Unlimited and fast, ₹0 |

**The key insight:** Tier A gives you 80–90% of Tier S ability for 5–20% of
the price, and one Tier A model is completely free on Groq. Save the premium
models for hard multi-file coding and long automatic tasks — that is the one
place they clearly earn their price.

### What ₹500 of API credit buys

| Model | Tokens for ₹500 |
|---|---|
| Gemini Flash-Lite | **~32 million** |
| DeepSeek V3.x | **~18 million** |
| Gemini Flash | ~6.7 million |
| GLM-4.6 | ~5.7 million |
| Claude Haiku 4.5 | ~2.8 million |
| Claude Sonnet 5 (intro price) | ~1.4 million |
| Claude Opus 5 | ~570,000 |
| Claude Fable 5 | ~280,000 |

Batching halves these prices. Caching cuts the repeated part by about 90%.

---

## Part 4 — Coding tools

This is the one place worth spending money.

| Option | ⚠️ Price/month | Notes |
|---|---|---|
| **Gemini CLI free tier** | **₹0** | ~1,000 requests/day on a personal Google account. Genuinely useful |
| **Qwen Code CLI free tier** | **₹0** | ~2,000 requests/day |
| GitHub Copilot free tier | ₹0 | Limited completions and chat |
| **Z.ai GLM Coding Plan** | **~₹300–550** ($3–6) | 🏆 **Best value on this list.** Works with the Claude Code command-line tool directly. Chinese provider — personal projects only |
| ChatGPT Go (includes Codex CLI) | **₹649** (your figure) | Also becomes your daily chat and image tool |
| Claude Pro | ⚠️ ~₹1,700–1,900 | Strongest single subscription — but takes two-thirds of your budget alone |
| DeepSeek / OpenRouter credits | ₹100–800 as needed | Extra capacity behind LiteLLM |

**Important thing people get wrong:** a subscription is **not** an API key.

| What you buy | What it is | Can LiteLLM use it? |
|---|---|---|
| Claude Pro / Max | Seat for claude.ai and Claude Code | ❌ Not an API endpoint |
| Gemini AI Pro | Gemini app + higher CLI limits | ❌ Not an API key |
| ChatGPT Go / Plus | ChatGPT app + Codex CLI | ❌ Not an API endpoint |
| **Gemini API key** (AI Studio) | Real endpoint, has a free tier | ✅ Yes |
| **Anthropic API key** | Real endpoint, prepaid credit, **billed separately from Claude Pro** | ✅ Yes |
| DeepSeek / Groq / OpenRouter keys | Real endpoints | ✅ Yes |

Buying Claude Pro does **not** give you Anthropic API credit. They are two
separate bills.

---

## Part 5 — Cost analysis

### Option comparison

| # | What you buy | ⚠️ ₹/month | Good for | Verdict |
|---|---|---|---|---|
| **0** | Local models + Gemini/Qwen free CLIs + SearXNG + Crawl4AI + n8n + Immich + Telegram + Tailscale — all on the Mac | **₹0** | Proving it works | Surprisingly capable. Weak points: coding quality, nothing runs when the lid is shut |
| **1** | Option 0 + GLM Coding Plan | **~₹500** | Heavy coding | 🏆 **Best value on the list.** A real coding agent for pocket money |
| **2** | Option 0 + ChatGPT Go | **₹649** | One subscription for everything | Simplest. Coding is weaker than option 1 |
| **3** | ChatGPT Go + GLM Coding + ₹400 VM + ₹400 API credit | **~₹2,000** | **You** | 🏆 **Recommended.** Strong coding, strong daily assistant, always on, spare capacity — and ₹1,000 under your ceiling |
| **4** | Claude Pro + ₹400 VM | **~₹2,300** | One vendor, best reasoning | Cleanest and most private, but no spare capacity and no cheap bulk option |
| **5** | Free premium tier from a telecom offer + GLM + ₹400 VM | **~₹900** | If you qualify ⚠️ | Best case overall. Check eligibility first |
| ❌ | Apple Developer Program for the Music API | ₹740 | — | **Reject.** AppleScript is free and does the same |
| ❌ | Rented cloud GPU | ₹15,000+ | — | **Reject.** Your Mac is faster and free |

⚠️ **Check these two India offers before you subscribe to anything.** Jio has
bundled Google AI Pro free for around 18 months (worth ~₹1,950/month), and
Airtel has bundled Perplexity Pro free for around 12 months. If you qualify
for either, that's a premium tier at ₹0 and it changes the whole plan.

### If you only care about one thing

| You value | Choose |
|---|---|
| Best coding per rupee | **Option 1** (~₹500) |
| Fewest moving parts | **Option 4** (~₹2,300) |
| Most total ability under the ceiling | **Option 3** (~₹2,000) |
| Maximum privacy | **Option 0 or 4** — nothing personal leaves your Mac |
| Cheapest that still feels premium | **Option 5** if eligible, else **Option 1** |

### Recommended monthly budget

| Item | ₹/month |
|---|---|
| GLM Coding Plan (personal coding) | 500 |
| ChatGPT Go (daily assistant, optional) | 649 |
| VM hosting — Phase 3 only | 0–400 |
| API credit for bulk and premium work | 400 |
| Local models, Telegram, Tailscale, SearXNG, Crawl4AI, n8n, Immich, ffmpeg, CLIP | **0** |
| **Total** | **₹1,550 – ₹1,950** |

That leaves ₹1,000+ of your ceiling unspent. Keep it unspent until something
actually needs it.

### Where the free stuff carries the weight

| Job | Cost | Why free |
|---|---|---|
| Scoring 10 GB of photos and video | **₹0** | CLIP on your Mac. Not a language model at all |
| Describing thousands of photos | **₹0** | Gemma-3-4B locally |
| Rendering reels | **₹0** | ffmpeg |
| Apple Music playlists | **₹0** | AppleScript + Last.fm |
| Web search and reading | **₹0** | SearXNG + Crawl4AI |
| Quick questions from phone | **₹0** | Groq/Cerebras free tier |
| Phone access | **₹0** | Telegram + Tailscale |

Only two things cost real money: **coding** and **hard reasoning**.

---

## Part 6 — Final decisions

| Decision | Choice |
|---|---|
| Chat on phone | **Telegram bot** first, **Open WebUI** second |
| Router | **LiteLLM**, self-hosted, one copy on the Mac and one on the VM sharing a database |
| Automation | **n8n**, or plain Python + cron if you prefer code |
| Networking | **Mac asks VM for work** (pull queue) + **Tailscale** for live use |
| Hosting | Phase 1 Mac only (₹0) → Phase 2 Cloudflare Worker or Oracle free (₹0) → Phase 3 Indian VM (₹250–400) |
| Local models | Qwen3-8B (general), Gemma-3-4B (vision), Qwen3-4B (routing), CLIP (photos) |
| Free cloud | **Groq + Cerebras** (personal-safe), Gemini free for public research only |
| Cheap paid | **DeepSeek** and **Gemini Flash-Lite** |
| Premium | **Claude Opus 5** with caching, batching, and `effort: medium` |
| Coding | **GLM Coding Plan** (~₹500) |
| Photos | **Immich** or **osxphotos** — not the Google Photos API |
| Music | **AppleScript** — not the Apple Developer Program |
| Video | **ffmpeg**, driven by a plan the AI writes |
| Dashboard | **LiteLLM's own UI** + Grafana + a `/stats` Telegram command |

### The one architecture rule

**AI models handle text. Your Mac handles files. The router just passes
messages between them.**

Never send media to a model. Score and describe it locally, then send only a
small text summary. Doing it the other way round would cost ₹15,000–25,000 for
a single pass over your 10 GB folder — and take longer than the free local
version.

---

Next: [01 — Local AI setup](01-local-ai-setup.md)
