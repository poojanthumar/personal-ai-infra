# 14 — Research Prompts

Prompts for verifying the ⚠️ figures in these documents yourself. Run them in
Gemini or ChatGPT with search enabled, one at a time.

**Status:** Priority 1 (prompts 1–4) and prompts 5–10 have been run — results
folded into the docs on 2 Aug 2026. See [CHANGELOG](CHANGELOG.md). Re-run any of
them when a figure looks stale.

---

## Why the rules matter

Two research passes on the same prompts produced very different quality. The
rigorous one marked **NOT FOUND** rather than guessing; the other filled gaps
with year-old figures and asserted things that were false.

**The rules block at the top of each prompt is what produced the difference.**
Don't remove it.

---

## The shared rules block

Every prompt below includes this. If you write your own, include it too.

```
RULES — follow exactly:
- Use only official sources: the company's own pricing page, docs, or changelog.
  No blogs, no news articles, no aggregators, no community posts.
- For every figure give the source URL and the page's last-updated date if shown.
- If you cannot find an official source, write NOT FOUND. Do not substitute a
  number from elsewhere and do not estimate.
- Say clearly if any figure you find looks older than 3 months.
- I am in India. India-specific pricing takes priority over US pricing.
- Convert USD to INR at ₹88 = $1 and label it as your conversion.
```

---

## Priority 1 — could change the plan

### RESEARCH 1 — India subscription pricing and telecom offers

```
[paste the shared RULES block here]

Find the current INDIA pricing (in INR, including tax if shown) for:
1. ChatGPT Go, ChatGPT Plus, ChatGPT Pro
2. Claude Pro and Claude Max
3. Google AI Plus, Google AI Pro, Google AI Ultra
4. Perplexity Pro
5. GitHub Copilot Pro and Pro+

Then check these two bundled offers and report whether they are STILL ACTIVE:
6. Reliance Jio bundling Google AI Pro free — what duration, who is eligible
   (age limits, plan requirements), and the last date to claim
7. Airtel bundling Perplexity Pro free — same details

Output as a markdown table:
| Product | India price INR/month | Free trial | Source URL | Page updated |

Then a second table:
| Offer | Still active? | Duration | Eligibility | Claim deadline | Source URL |

Finally, one line: which single subscription gives the best value for someone in
India spending under ₹1,000/month, and why.
```

### RESEARCH 2 — Free tier limits

```
[paste the shared RULES block here]

For each provider below, find the FREE TIER limits: requests per minute,
requests per day, and tokens per day or per minute if capped.

1. Groq — per model if they differ. Include which models are on the free tier.
2. Cerebras Cloud
3. Google Gemini API via AI Studio — per model (Flash, Flash-Lite, Pro)
4. OpenRouter free models (the ":free" variants) — before and after adding
   any lifetime credit
5. Mistral La Plateforme free tier
6. Cloudflare Workers AI free allowance
7. Gemini CLI free tier — daily request limit on a personal Google account
8. Qwen Code CLI free tier

Output as a markdown table:
| Provider | Model | Req/min | Req/day | Tokens/day | Source URL | Updated |

Then answer these three specific questions, each with a source URL:
A. Does Google use FREE TIER Gemini API data to train or improve its products?
   Quote the exact sentence from their terms. Is the paid tier different?
B. Do Groq or Cerebras use free tier data for training?
C. Which of these providers offers prompt caching on the FREE tier?

Finally, one line: which two providers give the most free tokens per day
combined, with the numbers.
```

### RESEARCH 3 — Google Photos, Apple Music, and music APIs

```
[paste the shared RULES block here]

Answer each question separately, with a source URL for each:

1. GOOGLE PHOTOS LIBRARY API — current state:
   a. Can a third-party app read a user's ENTIRE photo library today, with the
      user's consent? Yes or no.
   b. Which OAuth scopes are still available, and which were removed or
      restricted? Give the dates of any changes.
   c. What is the Picker API for, and can it be used for automated or repeated
      access, or only one-off user selection?
   d. Is there any officially supported way to build automated albums across a
      user's whole library?

2. APPLE MUSIC:
   a. Current cost of the Apple Developer Program, in INR if Apple lists an
      India price.
   b. Does the Apple Music API (MusicKit) require that paid membership for
      personal, non-distributed use?
   c. Does AppleScript control of the Music app still work on the current macOS
      version? Any deprecation notices from Apple?
   d. Can the AppleScript "download" command still mark library tracks for
      offline playback?

3. SPOTIFY: is the recommendations endpoint (and related audio-features
   endpoints) available to NEW applications today? Give the deprecation date and
   notice URL if not.

4. LAST.FM and LISTENBRAINZ: are their APIs still free? What are the rate limits
   and do they require an API key?

Output as a markdown table:
| Question | Answer | Source URL | Date |

Then one paragraph: if someone wants to automatically organise their photo
library into albums, what is the best officially-supported option available today?
```

### RESEARCH 4 — Coding plans and paid API pricing

```
[paste the shared RULES block here]

PART A — flat-rate coding plans:
1. Z.ai GLM Coding Plan — all tiers, monthly price, what limits apply
2. Does the Z.ai GLM Coding Plan work with the Claude Code command-line tool?
   If yes, what exact environment variables or base URL do their official docs
   say to set?
3. Any similar flat-rate coding plans from MiniMax, Moonshot/Kimi, or DeepSeek

PART B — per-token API pricing, input and output per 1 million tokens:
4. Google Gemini API — Flash-Lite, Flash, and Pro models (paid tier)
5. DeepSeek — chat and reasoner models. Include any off-peak discount, the
   discount percentage, and the exact hours in UTC and IST.
6. Z.ai GLM — per-token pricing
7. Moonshot Kimi
8. MiniMax
9. Whether each of the above offers prompt caching, and the cached-input price

Output as a markdown table:
| Provider | Model | $/1M in | $/1M out | ₹/1M in | ₹/1M out | Caching? | Cached $/1M in | Source URL |

Then a second table for PART A:
| Plan | Tier | USD/month | INR/month | Limits | Works with Claude Code? | Source URL |

Finally: two lines naming the cheapest option for (a) bulk classification of
50 million tokens per month, and (b) daily coding work, with the monthly cost
in INR for each.
```

---

## Priority 2 — unblocks the build

### RESEARCH 5 — LiteLLM current reference

```
RULES — follow exactly:
- Use ONLY the official LiteLLM documentation at docs.litellm.ai and the
  BerriAI/litellm GitHub repository. No blogs, no third-party tutorials.
- State the LiteLLM version the documentation applies to.
- Give the source URL for each answer.
- If something is not documented, write NOT DOCUMENTED. Do not infer it.

I am running LiteLLM as a proxy with a config.yaml file. Find the CURRENT
correct syntax for each of these, and paste the official example for each:

1. Defining a model group with multiple providers under one model_name
2. Setting per-model timeout and disabling retries
3. Configuring fallbacks between model groups — the exact key name and nesting.
   Is it under router_settings? Show a complete working example.
4. Setting a hard monthly spending cap for the whole proxy, in USD
5. Generating a virtual API key with its own budget — the exact endpoint path,
   HTTP method, and JSON field names
6. Attaching custom tags or metadata to a request so it appears in the logs.
   What is the exact field name, and is it inside "metadata"?
7. The URL path of the built-in admin UI
8. The environment variable for the Postgres connection
9. What the "drop_params" setting does, and whether it would discard an
   "mcp_servers" parameter passed through to Anthropic

Then, from the repo or docs, give me:
10. The exact table name and column names LiteLLM uses to store request/spend
    logs in Postgres. I need to write SQL against it. List every column with its
    type if documented.

Output each answer as: number, short answer, official code example in a fenced
block, source URL, applies-to version.
```

### RESEARCH 6 — Open WebUI, mcpo, and Immich

```
RULES — follow exactly:
- Use ONLY official documentation and GitHub repositories for each project.
  No blogs, no third-party tutorials.
- State the version each answer applies to.
- Give a source URL for every answer.
- If something is not documented, write NOT DOCUMENTED.

OPEN WEBUI:
1. The exact current environment variable names for connecting Open WebUI to an
   OpenAI-compatible endpoint (base URL and API key). Have these names changed
   recently? List any old names that still work.
2. How to set the embedding model to a local Ollama model — the exact setting
   name and where it lives in the UI.
3. How to disable new user sign-ups after creating the first admin account.
4. Whether it can connect to MCP servers directly, or whether a translator like
   mcpo is still required.
5. The recommended way to back up its data volume.

MCPO:
6. The current command-line flags. Specifically: is there a flag to expose only
   SOME tools from an MCP server rather than all of them? Give the exact flag
   name and an example.
7. How Open WebUI is configured to use an mcpo endpoint.

IMMICH:
8. The current recommended installation method and where to get the official
   docker-compose file.
9. Its minimum RAM requirement, and which machine-learning features can be
   disabled to reduce memory use. Name the exact settings.
10. The API endpoint for smart/semantic search by text, and for creating an
    album. Give the paths and required headers.
11. Whether an "external library" can read photos from a folder in place without
    copying them.

Output each answer as: number, short answer, code or config example in a fenced
block, source URL, version.
```

---

## Priority 3 — refinements

### RESEARCH 7 — Hosting

```
RULES — follow exactly:
- Use only official provider documentation and pricing pages. For community
  experiences on Oracle capacity, you may cite the Oracle community forum but
  must label it as community-reported, not official.
- Give the source URL for every figure.
- Convert USD/EUR to INR at ₹88 = $1 and ₹96 = €1, labelled as your conversion.
- If a figure is not published, write NOT FOUND.

1. ORACLE CLOUD ALWAYS FREE:
   a. Exact ARM (Ampere A1) allocation: cores, RAM, storage
   b. Which regions in or near India offer it
   c. The official idle-reclamation policy — the exact CPU/network thresholds
      and time period that trigger reclamation
   d. Whether Indian debit or credit cards are accepted for the verification
      step. Community-reported is fine here, labelled as such.

2. CLOUDFLARE free tier limits for: Workers requests per day, D1 database
   (rows read/written, storage), KV (reads/writes/storage), Queues, and Cron
   Triggers. Also: can a Worker make outbound requests to an arbitrary IP
   address and port?

3. TAILSCALE free/personal plan: device limit, user limit, and whether there are
   DERP relay servers located in India. Any bandwidth limits.

4. INDIAN VPS PROVIDERS — smallest plan with at least 1 GB RAM, monthly price in
   INR, and data centre city, for: Utho, E2E Networks, and one other Indian
   provider you can find with official pricing.

5. AWS Lightsail and DigitalOcean: smallest plan price for the Mumbai and
   Bangalore regions respectively, in INR.

Output as a markdown table where sensible:
| Provider | Plan | vCPU | RAM | Storage | INR/month | Region | Source URL |

Then one paragraph: for a machine that only needs to run a job queue, a small
router, and Postgres, what is the cheapest genuinely reliable option for someone
in India, and what would you avoid?
```

### RESEARCH 8 — Local models for a 16 GB Apple Silicon Mac

```
RULES — follow exactly:
- Use only official model cards on Hugging Face, the Ollama model library, the
  Apple MLX repositories, and model releases from the labs themselves. No blogs,
  no benchmark aggregator sites for the model list itself.
- Give the exact model identifier and the source URL for each.
- If you cannot confirm a file size, write UNKNOWN rather than estimating.

I have a MacBook Pro M1 Pro with 16 GB of unified memory. After macOS I have
roughly 10-11 GB available for a model.

1. List the best currently-available open models that fit in 10 GB at 4-bit
   quantisation, for each of these jobs. Give the exact Ollama tag AND the exact
   MLX community identifier where one exists, plus the file size in GB:
   a. General text and reasoning
   b. Vision — describing photos
   c. Small and fast, for classification and routing
   d. Text embeddings
   e. Speech to text

2. For each model listed above, state its context window and whether it supports
   tool/function calling.

3. Have any of these Ollama tags changed or been retired recently: qwen3:4b,
   qwen3:8b, qwen3:14b, gemma3:4b, gemma3:12b, nomic-embed-text? Give the
   current correct tag for each.

4. Is MLX still measurably faster than llama.cpp/Ollama on Apple Silicon for the
   same model and quantisation? Cite an official Apple MLX benchmark or the MLX
   repo's own numbers, not a blog.

5. For the LAION aesthetic predictor v2: what is the current official download
   location for the weights file, what is it called, and what CLIP model
   variant does it expect as input? Is there a newer or better-maintained
   alternative for scoring image aesthetics?

Output the model list as a markdown table:
| Job | Model | Ollama tag | MLX id | Size GB | Context | Tools? | Source URL |
```

### RESEARCH 9 — OpenClaw

```
RULES — follow exactly:
- Use only the project's own GitHub repository, its official documentation site,
  and posts from its maintainers. You may cite discussions but must label them
  as community-reported.
- Give source URLs for everything.
- If you cannot find the project at all, say so plainly and stop. Do not
  describe a different project with a similar name.

Investigate a project called OpenClaw. It may have previously been named
Clawdbot or Moltbot — check those names too if the current one finds nothing.

Report:
1. What it is, in three sentences. What problem does it solve?
2. Who maintains it, the GitHub repository URL, its licence, star count, and the
   date of the most recent commit.
3. Which messaging platforms it connects to.
4. Which AI providers it supports. Can it use a self-hosted OpenAI-compatible
   endpoint such as a LiteLLM proxy, or local models via Ollama?
5. Does it act as an MCP client? Can it connect to both local (stdio) and remote
   (URL) MCP servers?
6. What level of access to the host machine does it need or request — shell
   commands, filesystem, AppleScript, browser control? Be specific.
7. SECURITY — this is the most important part. Quote directly from the project's
   own documentation any warnings about the risk of running it. Does it
   recommend sandboxing, a separate user account, or a dedicated machine? Have
   there been any publicly discussed security incidents?
8. What are its system requirements, and does it run on macOS?
9. Does it have scheduled/cron task support?
10. Is it production-ready or experimental, according to its own maintainers?

Output as a markdown table:
| Question | Answer | Source URL |

Then one paragraph answering: would you run this on a laptop that also contains
confidential work source code from an employer? Explain the reasoning either way.
```

### RESEARCH 10 — MCP specifics

```
RULES — follow exactly:
- Use only the official Model Context Protocol specification site, Anthropic's
  own documentation, Google's Gemini API documentation, and the official MCP
  GitHub organisation. No blogs.
- Give source URLs and state which version or beta header each answer applies to.
- If something is not documented, write NOT DOCUMENTED.

1. ANTHROPIC MCP CONNECTOR (server-side MCP):
   a. The current beta header value
   b. The exact request parameters required, with a complete working example
   c. Confirm whether it supports ONLY remote URL-based MCP servers, or also
      local stdio servers
   d. Which platforms it is available on (Anthropic API, Bedrock, Vertex,
      Foundry, Claude Platform on AWS)

2. ANTHROPIC TOOL SEARCH:
   a. The current tool type strings
   b. How "defer_loading" works and what the constraints are
   c. How much it reduces prompt tokens, if they publish a figure

3. TOKEN COST OF TOOLS: does Anthropic or Google publish any official figure for
   how many tokens a tool definition consumes? If not, say NOT PUBLISHED.

4. PROMPT CACHING AND TOOLS: confirm officially that tool definitions are part
   of the cacheable prefix, and what invalidates that cache.

5. GOOGLE GEMINI: does the Gemini API support MCP natively in any form, or only
   generic function calling? If MCP is supported, give the exact parameter and
   an example.

6. OFFICIAL MCP SERVERS: list the officially maintained MCP servers from the
   modelcontextprotocol GitHub organisation. For each, give the package name and
   roughly how many tools it exposes.

7. Are there official MCP servers for: SQLite, filesystem, Playwright/browser,
   GitHub, and Google Drive? Give package names and whether they are stdio,
   URL-based, or both.

Output each answer as: number, answer, code example in a fenced block where
relevant, source URL, applies-to version.
```

---

## Two prompts for ongoing maintenance

### Check a single figure

Use this whenever a ⚠️ in these docs matters to a decision.

```
Find the current official price or limit for: [the thing]

Requirements:
- Use only the provider's own website or official documentation. No blog posts,
  no news articles, no aggregator sites.
- Give the figure, the exact page URL it came from, and the date the page was
  last updated if it shows one.
- If the provider lists prices in US dollars, also give the rupee figure at
  ₹88 = $1 and say clearly that you converted it.
- If there is separate India pricing, that takes priority — say so explicitly.
- If you cannot find an official source, say "not found on an official source"
  rather than giving me a number from somewhere else.

Answer in this format:

  FIGURE: <the number with its unit>
  SOURCE: <url>
  UPDATED: <date or "not shown">
  IN RUPEES: <converted figure, or "already in rupees">
  NOTES: <anything conditional — intro pricing, region limits, tier gates>
```

### Check whether a config format has changed

```
RULES:
- Use ONLY the official documentation site and GitHub repository for [tool name].
- State the version your answer applies to.
- If something is not documented, write NOT DOCUMENTED. Do not infer.

I am using this configuration for [tool name]:

[paste your config]

For each setting in it, tell me:
1. Is the key name still correct in the current version? If not, what is it now?
2. Is it in the right section of the file?
3. Is the value format still correct (units, string vs number, allowed values)?
4. Was anything deprecated or removed?

Output as a table:
| My setting | Still correct? | Current form | Source URL | Version |

Then list anything important in the current version that my config is missing.
```

---

## What to do with the results

1. **Paste them back to me labelled** (`RESEARCH 1`, etc.) and I'll fold them in.
2. **Compare against [CHANGELOG.md](CHANGELOG.md)** — it lists what's already
   verified and what is still open.
3. **A NOT FOUND answer is useful.** It tells you to design around the
   uncertainty rather than trust a number.
4. **Run two models on the same prompt when the answer matters.** The 2 Aug 2026
   pass did this and the disagreement is what exposed the stale figures.

---

Back to: [README](README.md) · [CHANGELOG](CHANGELOG.md) · [AI prompts](13-ai-prompts.md)
