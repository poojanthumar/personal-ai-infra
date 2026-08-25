# 00 — Decisions and Costs


> ⚠️ **Anything marked ⚠️ in this file is unverified.** All of it is answered
> by the prompt in [⚠️ Verify with AI](#-verify-with-ai) at the bottom — paste it
> into Gemini or any web-enabled AI and update this file with the result.

Everything compared, ranked, and priced. Read this before building anything.

**Verified 2 Aug 2026** against official sources — see [CHANGELOG](CHANGELOG.md).
**✅ Confirmed:** Claude/Anthropic prices, and everything marked ✅.
**⚠️ Unverified:** anything marked ⚠️. Check before you pay.
**Exchange rate used:** ₹88 = $1.

**Scope note:** music automation was dropped. Front door is OpenClaw on WhatsApp.

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
| **OpenClaw** ([file 07](07-openclaw.md)) | ₹0 + ⚠️ spare SIM | **WhatsApp**, Telegram, Signal, +18 more | 🏆 **Build this.** A model picks the tool instead of you typing exact commands. Runs on Oracle. ⚠️ Early-stage; ⚠️ Meta bans personal numbers for WhatsApp automation |
| **Telegram bot** ([appendix A1](A1-telegram-fallback.md)) | ₹0 | Excellent | 🏆 **The fallback.** ~150 lines you fully understand, no ban risk. Build it first if OpenClaw fights you — it proves the queue works |
| **Open WebUI** ([appendix A2](A2-openwebui-optional.md)) | ₹0 | Good — installs as a phone app | ⚠️ **Optional now.** Only worth it for document upload and RAG, which OpenClaw may not do |
| LibreChat | ₹0 | Good | No advantage over Open WebUI here |
| Build your own app | Weeks | — | ❌ No. You get nothing these don't already give you |

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
| **Oracle Cloud Always Free** (⚠️ **2 OCPU, 12 GB RAM** on the current page) | **₹0** | ✅ Yes | 🏆 **Phase 2. The always-on box.** Runs Postgres, LiteLLM, the job queue, MCP servers and OpenClaw. ⚠️ Capacity not guaranteed in Mumbai/Hyderabad; reclamation thresholds not published; **back it up nightly** |
| Cloudflare Workers + D1/KV | ₹0 | ✅ Yes | ⚠️ **Demoted.** 🚨 **10 ms CPU per request** means it can never host a database, an agent, or OpenClaw. And it splits your data across two databases. **Keep only Cloudflare Tunnel**, free, to give Oracle an HTTPS address with no open ports |
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
| Click around a site | **Playwright MCP** | ₹0 | Runs on Oracle. ⚠️ Not maintained by the official MCP org. Only add it when a site genuinely needs clicking |

### Photos and video

| Job | Tool | Cost | Verdict |
|---|---|---|---|
| Photo library with AI search | **Immich** (self-hosted) | ₹0 | 🏆 Face grouping and text search built in |
| Read Apple Photos | **osxphotos** | ₹0 | 🏆 If you live in Apple Photos |
| Score photos by how good they look | **CLIP + aesthetic model** | ₹0 | 🏆 See file 03 |
| Video editing | **ffmpeg** | ₹0 | 🏆 The only real answer |
| Beat detection for music sync | librosa or aubio | ₹0 | 🏆 |
| ~~Music automation~~ | — | — | ❌ **Out of scope.** Apple exposes no danceability, tempo or energy field, and Spotify closed the equivalent API to new apps in Nov 2024. Answering "bollywood dance songs" needs a one-time classification pass to build your own tags — a sub-project of its own. See [appendix A3](A3-music-out-of-scope.md) if you revisit it |

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

⚠️ **On MLX:** MLX is Apple's own framework, built for Apple Silicon. I
previously claimed it runs 20–40% faster than Ollama — **that is not supported by
any published benchmark.** Measure it on your own Mac before switching anything
(file 02, step 7). One place it clearly wins: Whisper speech-to-text, where the
4-bit build is only 0.464 GB and has no Ollama equivalent.

**Electricity cost:** M1 Pro under full load is about 40 W. That is roughly
**₹0.30 per hour**. Effectively free.

### Tier 1 — Free cloud APIs (verified Aug 2026)

| Provider | Models | Free allowance | Speed | Warning |
|---|---|---|---|---|
| **Groq** | Llama, Qwen, Kimi, gpt-oss | ⚠️ **Not published** — account and model specific | 🏆 300–1,000 words/sec | Read your real limits from console.groq.com |
| **Gemini API** (AI Studio) | Flash, Flash-Lite | ⚠️ Account-specific; no stable public number | Fast | 🚨 **Free tier data IS used to train Google products** |
| **Gemini CLI** | Flash only | ✅ **60/min, 1,000/day** on a personal account | Fast | ⚠️ **Pro models cut off for free users since 25 Mar 2026** |
| **OpenRouter** free models | DeepSeek, Qwen, GLM, Llama | ✅ **50/day**, rising to **1,000/day** after a one-time $10 credit purchase | Varies | Shared capacity |
| **Cloudflare Workers AI** | Small open models | ✅ 10,000 Neurons/day, resets 00:00 UTC | Fast | Measured in Neurons, not tokens |
| ❌ **Cerebras** | — | 🚨 **No longer a standing free tier.** Now **$5 credits expiring after 30 days** | — | Changed 16 Jul 2026 |
| ❌ **Qwen Code CLI** | — | 🚨 **Free tier discontinued 15 Apr 2026** | — | Remove from any plan |

🚨 **Two corrections to what I said earlier:**

**Cerebras is gone as a free tier.** My claim that "Groq + Cerebras give roughly
1.5 million free tokens per day" is no longer true. **Groq is now your only real
standing free tier.**

**Qwen Code CLI free access ended.** Do not plan around it.

🚨 **Gemini free tier and your data — confirmed from Google's own pricing table:**

| Tier | "Used to improve our products" |
|---|---|
| Free | **Yes** |
| Paid | **No** |

Never send personal photos, private notes, or personal context through the Gemini
**free** tier. The paid tier is fine. This is exactly what the `private-local`
and `tier1-public-only` split in file 06 exists for.

**Consequence of Cerebras leaving:** your cheap bulk layer is no longer a free
tier — it is **Gemini Flash-Lite paid at ₹15 per million tokens**. Fifty million
tokens costs ₹440. Effectively free at your volume, and it does not train on
your data.

### Tier 2 — Cheap paid APIs (verified Aug 2026)

"Blended" price assumes 3 words in for every 1 word out, which is realistic.

| Model | $/1M in | $/1M out | Blended ₹/1M | Verdict |
|---|---|---|---|---|
| ✅ **Gemini Flash-Lite** | 0.10 | 0.40 | **₹15** | 🏆 **Verified.** Your bulk layer. 50M tokens = ₹440 |
| ✅ **Gemini Flash** | 0.30 | 2.50 | **₹75** | Verified. Cached input drops to **$0.03/1M** — a 10× discount |
| ✅ **Gemini Pro** | 1.50 | 9.00 | **₹297** | Verified. **Cheaper than I thought** (I said ₹385). Cached input $0.15/1M |
| ⚠️ **DeepSeek** | ⚠️ **NOT FOUND** | — | — | 🚨 Two research passes failed to verify. Check api-docs.deepseek.com before relying on it |
| ⚠️ GLM, Kimi, MiniMax | NOT FOUND | — | — | No first-party pricing confirmed. Treat as unknown |

🚨 **DeepSeek was my Tier 2 backbone and its pricing is now unverified.** One
source said $0.14/$0.28, another found nothing, and my own figure was $0.28/$0.42.
Until you confirm it, **use Gemini Flash-Lite at ₹15/1M instead** — verified,
cheaper than every DeepSeek estimate, and no data leaves a provider you already
pay.

⚠️ DeepSeek, GLM, Kimi, MiniMax are Chinese providers. Fine for personal
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

This is the one place worth spending money — and the only place, given what you
already own.

| Option | Price/month | Notes |
|---|---|---|
| **Gemini CLI free tier** | **₹0** | ✅ 60/min, 1,000/day. ⚠️ **Flash models only** since 25 Mar 2026 — Pro is gone for free users |
| GitHub Copilot Pro | ✅ $10 = ₹880 | Autocomplete and chat, not an agent |
| GitHub Copilot Pro+ | ✅ $39 = ₹3,432 | Over budget |
| **Claude Pro** | ✅ **$20 = ₹1,760** | 🏆 **Best coding available to you.** Claude Code with Opus 5 / Sonnet 5 |
| Claude Max 5× | ✅ $100 = ₹8,800 | Over budget |
| **Metered API** (Sonnet 5) | ₹352/1M blended | 🏆 **Cheaper if you code a few times a week.** ⚠️ Intro price ends 31 Aug 2026 |
| ❌ **Z.ai GLM Coding Plan** | 🚨 **$18 = ₹1,584** | **Rejected.** Was quoted at $3–6. At ₹1,584 vs Claude Pro's ₹1,760, pay ₹176 more for a better model and no data going to China |
| ❌ Qwen Code CLI | — | Free tier discontinued 15 Apr 2026 |
| ❌ ChatGPT Go | ₹649 | Unnecessary — you already have Google AI Plus for daily chat |

🚨 **Correction:** I previously recommended the GLM Coding Plan as "best value on
this list" at ₹300–550. The verified price is **$18/month (₹1,584)** for the Lite
tier, with rolling limits of 2,000 credits per 5 hours and 10,000 per week. At
that price its entire argument disappears. Buy Claude Pro instead, or go metered.

If you do use GLM anyway, the verified Claude Code configuration is:

```bash
ANTHROPIC_AUTH_TOKEN="<your Z.ai API key>"
ANTHROPIC_BASE_URL="https://api.z.ai/api/anthropic"
```

**Important thing people get wrong:** a subscription is **not** an API key.

| What you buy | What it is | Can LiteLLM use it? |
|---|---|---|
| Claude Pro / Max | Seat for claude.ai and Claude Code | ❌ Not an API endpoint |
| **Google AI Plus / Pro** (you have this) | Gemini app + CLI benefits | ❌ Not an API key |
| ChatGPT Go / Plus | ChatGPT app + Codex CLI | ❌ Not an API endpoint |
| **Gemini API key** (AI Studio) | Real endpoint, has a free tier | ✅ Yes |
| **Anthropic API key** | Real endpoint, prepaid credit, **billed separately from Claude Pro** | ✅ Yes |
| Groq / OpenRouter keys | Real endpoints | ✅ Yes |

Buying Claude Pro does **not** give you Anthropic API credit. They are two
separate bills. Your Google AI Plus subscription does **not** give you Gemini API
quota — that is a separate AI Studio key.

---

## Part 5 — Cost analysis

### What you already have

| Item | Cost to you |
|---|---|
| **Google AI Plus** — bundled with your Google One subscription | **₹0 incremental** |

That covers your daily assistant and premium Gemini access. So **ChatGPT Go is
unnecessary**, and your full ₹2,000–3,000 is available for the one gap: coding.

⚠️ Worth checking: does AI Plus raise your **Gemini CLI** limits? Pro models were
cut off for *free* users in March 2026, but you are a paying customer. Run
`gemini` and see which models you are offered — if Pro is available, your free
coding tier is much stronger than the table above suggests.

### Option comparison

| # | What you buy | ₹/month | Verdict |
|---|---|---|---|
| **0** | Local models + Groq free + Gemini CLI free + SearXNG + Crawl4AI + n8n + Immich + Telegram + Tailscale, all on the Mac | **₹0** | Genuinely capable for everything except serious coding |
| **A** | Google AI Plus (₹0) + **Claude Pro ₹1,760** + API credit ₹400 | **₹2,160** | 🏆 **Best coding.** Tooling you already know. Spare burst capacity |
| **B** | Google AI Plus (₹0) + **API credits only ₹1,000** | **₹1,000** | 🏆 **Half the price.** Sonnet 5 metered for coding, Flash-Lite at ₹15/1M for bulk |
| **C** | Option A + ₹400 Indian VM | ₹2,560 | Only when Cloudflare's free tier stops being enough |
| ❌ | Anything with GLM Coding Plan | ₹1,584+ | Claude Pro is better for ₹176 more |
| ❌ | ChatGPT Go | +₹649 | You already have premium Gemini |
| ❌ | Apple Developer Program for the Music API | ~₹8,700/yr + GST | **Reject.** AppleScript is free and does the same |
| ❌ | Rented cloud GPU | ₹15,000+ | **Reject.** Your Mac is faster and free |

### Choosing between A and B — it's purely volume

₹1,000 of metered Sonnet 5 at intro pricing buys roughly **2.8 million tokens**,
which is about **10–25 coding sessions**.

| Your coding pattern | Choose |
|---|---|
| Daily, hours at a time | **A** — Claude Pro flat beats per-token |
| A few sessions a week | **B** — saves ₹1,160/month |
| Occasional | **B**, or even Option 0 plus ₹400 of burst credit |

⚠️ **Sonnet 5's intro pricing ends 31 Aug 2026.** After that, metered gets about
50% more expensive and A becomes the better deal. Start with B, watch your
dashboard, and switch when the numbers say so — which is exactly what file 12
is for.

### If you only care about one thing

| You value | Choose |
|---|---|
| Best coding | **A** (₹2,160) |
| Lowest cost that still works | **B** (₹1,000) |
| Fewest moving parts | **A** — one subscription, no metering to watch |
| Maximum privacy | **0 or A** — nothing personal leaves your Mac |
| Nothing at all this month | **0** (₹0) and add credit when you hit a wall |

### Recommended monthly budget

Starting point — Option B, then upgrade if the dashboard says you need it:

| Item | ₹/month |
|---|---|
| Google AI Plus (already bundled with Google One) | **0** |
| API credit — Sonnet 5 for coding, Flash-Lite for bulk | 1,000 |
| Hosting — Oracle Always Free VM + your Mac | **0** |
| Local models, Telegram, Tailscale, SearXNG, Crawl4AI, n8n, Immich, ffmpeg, CLIP | **0** |
| **Total** | **₹1,000** |

That is a third of your ceiling. Keep the rest unspent until something actually
demands it — most likely Claude Pro when Sonnet 5's intro pricing ends.

### Where the free stuff carries the weight

| Job | Cost | Why free |
|---|---|---|
| Scoring 10 GB of photos and video | **₹0** | CLIP on your Mac. Not a language model at all |
| Describing thousands of photos | **₹0** | Gemma-3-4B locally |
| Rendering reels | **₹0** | ffmpeg |
| Web search and reading | **₹0** | SearXNG + Crawl4AI |
| Quick questions from phone | **₹0** | Groq free tier |
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
| Hosting | Phase 1 Mac only (₹0) → **Phase 2 Oracle Always Free** (₹0) → Phase 3 OpenClaw on Oracle (₹0) → Phase 4 Indian VM (₹250–500) only if Oracle proves unreliable |
| Local models | Qwen3-8B (general), Gemma-3-4B (vision), Qwen3-4B (routing), CLIP (photos) |
| Free cloud | **Groq** (personal-safe). Gemini free tier for **public research only** — it trains on your data |
| Cheap paid | **Gemini Flash-Lite** at ₹15/1M. DeepSeek only if you verify its pricing yourself |
| Premium | **Claude Opus 5** with caching, batching, and `effort: medium` |
| Coding | **Metered Sonnet 5** (₹1,000/mo) to start → **Claude Pro** (₹1,760) when intro pricing ends 31 Aug 2026. **Not GLM** — it's $18, not $6 |
| Daily assistant | **Google AI Plus** — you already have it, bundled with Google One. ₹0 |
| Photos | **Immich** or **osxphotos** — not the Google Photos API |
| Front door | **OpenClaw on Oracle** (WhatsApp). ⚠️ Use a spare number — Meta bans personal numbers for automation. Telegram bot ([appendix A1](A1-telegram-fallback.md)) is the fallback |
| MCP servers | **All on Oracle** — community stdio or hosted URLs. **None on your Mac.** Your own tools stay as job handlers |
| ~~Music~~ | ❌ **Out of scope** |
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

## ✅ Verified 2 Aug 2026 — and two answers to reject

### Confirmed

| Item | Figure | Note |
|---|---|---|
| **Utho** smallest ≥1 GB | **₹350/mo** + tax — 1 vCPU, 1 GB, 25 GB SSD, Noida/Mumbai | ✅ New. Was NOT FOUND |
| **E2E Networks** C3.1GB | **₹375/mo** + tax — 1 vCPU, 1 GB, 20 GB SSD, Noida/Mumbai | ✅ New |
| Tailscale free | Unlimited devices, 6 users, **DERP relay in Bengaluru** | ✅ New |

So Phase 4 is **₹350–375/month**, at the bottom of my ₹250–500 estimate.

### 🚨 Two answers to reject

| Claim | Reality |
|---|---|
| *"Anthropic has not released a model designated Claude Sonnet 5"* | **Wrong.** `claude-sonnet-5` exists: 1M context, **$3/$15**, with **$2/$10 intro through 31 Aug 2026**. From Anthropic's own reference. **Keep the figures in this file** |
| *"Google documentation does not recognize an AI Plus plan"* | **Wrong.** You have it. An earlier pass found **₹399/month** on `one.google.com/intl/en_in`. The model is confusing it with the older "AI Premium" name |

Both errors point the same way: that pass's training is older than the previous
one's. When two passes disagree, **prefer the one citing newer model names.**

### ⚠️ DeepSeek — still not trustworthy

Quoted **$0.14 in / $0.28 out** for chat and **$0.55 / $2.19** for reasoner, with a
50% off-peak discount 16:30–00:30 UTC (22:00–06:00 IST). But the source page was
dated **Feb 2025** — roughly 18 months stale.

🏆 **Don't act on it.** Gemini Flash-Lite at **₹15/1M blended** is verified, cheaper
than every DeepSeek estimate, and from a provider you already pay. Use that as your
bulk tier and treat DeepSeek as unresolved.

### ⚠️ Groq limits — plausible but stale

Quoted 30 RPM with 100k–500k tokens/day depending on model, sourced July 2025. It
also listed `mixtral-8x7b-32768`, which has been retired — so the model list is old.

**Read your own limits from console.groq.com** and put those in `quota_limits`
([12](12-dashboard.md)).

---

## ⚠️ Verify with AI

| # | Unverified | Why it matters |
|---|---|---|
| 1 | DeepSeek current pricing | Two research passes failed. Until confirmed, use Gemini Flash-Lite |
| 2 | Your own Groq free-tier limits | Not published — account-specific |
| 3 | Whether Google AI Plus unlocks Gemini CLI Pro models | Could make your free coding tier much stronger |
| 4 | Claude Sonnet 5 pricing after 31 Aug 2026 | Decides metered vs Claude Pro |
| 5 | Indian VPS prices (Utho, E2E) | Needed only if Oracle fails |

Paste this into Gemini or any web-enabled AI, then update this file with what comes back.

```
RULES — follow exactly:
- Use only official sources: the provider's or project's own pricing page, docs,
  changelog, or GitHub repository. No blogs, no news, no aggregators.
- Give the source URL and the page's last-updated date for every answer.
- If you cannot find an official source, write NOT FOUND. Do not estimate.
- Say clearly if a figure looks older than 3 months.
- I am in India. India-specific pricing takes priority. Convert USD at Rs 88 = $1
  and label it as your conversion.

Answer each, separately, with a source URL:

1. DeepSeek API pricing right now: input and output per 1 million tokens for
   deepseek-chat and deepseek-reasoner. Any cached-input price. Any off-peak
   discount, with the percentage and the exact hours in UTC and IST.
2. Groq free tier: are per-minute, per-day, or per-day-token limits published
   anywhere official, or only shown inside the console? If published, give them
   per model.
3. Does a paid Google AI Plus subscription raise Gemini CLI limits or unlock Pro
   models for the CLI? Quote Google's own wording. Compare AI Plus against AI Pro
   for CLI entitlements specifically.
4. Claude Sonnet 5 API pricing: current input/output per million tokens, whether
   introductory pricing is still active, and the exact date it ends.
5. Smallest plan with at least 1 GB RAM, monthly price in INR, and data centre
   city for Utho and E2E Networks.
6. Anything cheaper than Gemini Flash-Lite ($0.10/$0.40 per million) for bulk
   classification, from a provider that does NOT train on customer data?

Output as: | # | Answer | Source URL | Page updated |
Then one line: has anything in this list changed enough to alter a
Rs 1,200/month budget?
```

---

Next: [01 — Local AI setup](02-local-ai.md)
