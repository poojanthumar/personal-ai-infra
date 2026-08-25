# 14 — Verification Prompts (index)

Every prompt in this plan, in one place, so you can work through them without
opening each file.

**Two kinds:**

| Kind | Purpose | Where they live |
|---|---|---|
| **Verify** | Confirm a fact I couldn't check — prices, limits, API syntax | At the bottom of each file, under `⚠️ Verify with AI` |
| **Generate** | Produce a whole file I couldn't write accurately | [07](07-openclaw.md) and [08](08-mcp-servers.md) |

Build prompts — for AI to *write code* rather than research facts — are separate:
[15 — Build prompts](15-build-prompts.md).

**Already run once**, on 2 Aug 2026, on the earlier version of this plan. That
pass corrected 18 things — see [CHANGELOG](CHANGELOG.md). The prompts below are
the current set, rewritten per file.

---

## Do these first

Both can change the plan, so run them before building anything.

| # | Prompt | Answers |
|---|---|---|
| 1 | [04 — Oracle box](04-oracle-box.md) → Verify section | 🚨 **Can you get a free A1 instance in an Indian region?** If not, Phase 2 becomes a paid VM |
| 2 | [07 — OpenClaw](07-openclaw.md) → generation prompt | ⚠️ **How does WhatsApp connect?** Decides whether you need a spare SIM. Also generates the whole setup guide |

---

## The two generation prompts

These produce files. Run them and save the output alongside the plan.

| Prompt | Save output as | Produces |
|---|---|---|
| [07 — OpenClaw](07-openclaw.md) → "The generation prompt" | `07a-openclaw-setup.md` | Install, WhatsApp setup, LiteLLM wiring, the four job tools, the inbound message API, systemd unit, security defaults, troubleshooting |
| [08 — MCP servers](08-mcp-servers.md) → "The catalogue prompt" | `08a-mcp-catalogue.md` | Which servers exist and are maintained, tool counts and token cost, which support tool filtering, native server-side MCP for Anthropic and Gemini |

---

## Verify prompts, by file

| File | Confirms |
|---|---|
| [01 — Decisions and costs](01-decisions-and-costs.md) | DeepSeek pricing, your Groq limits, whether AI Plus unlocks Gemini CLI Pro models, Sonnet 5 pricing after August, Indian VPS prices |
| [02 — Local AI](02-local-ai.md) | Ollama tags and sizes, whether MLX is actually faster, best small vision model, aesthetic weights location |
| [03 — Photo ranker](03-photo-ranker.md) | LAION weights, better aesthetic scorers, current face detector, PySceneDetect API |
| [04 — Oracle box](04-oracle-box.md) | 🚨 Free-tier size and Indian capacity, reclamation policy, card acceptance, Cloudflare and Tailscale limits |
| [05 — Mac agent](05-mac-agent.md) | 🚨 Path-traversal edge cases on macOS, `caffeinate` behaviour on lid close, launchd network timing |
| [06 — LiteLLM](06-litellm.md) | Config schema for your version, 🚨 spend-log columns, whether `drop_params` eats `mcp_servers`, whether it's an MCP gateway now |
| [09 — Reels](09-reels.md) | ffmpeg filter syntax, hardware encoding on M1, librosa API, platform video specs |
| [10 — Albums](10-albums.md) | Google Photos current state, Immich RAM and API paths, osxphotos API |
| [11 — Web research](11-web-research.md) | SearXNG JSON config, Crawl4AI API and ARM support, free search API limits |
| [12 — Dashboard](12-dashboard.md) | 🚨 Spend-log schema, whether spend is available via API instead of raw SQL, provider quota headers |
| [13 — Request flows](13-request-flows.md) | Nothing — measure your own timings instead |
| [A1 — Telegram](A1-telegram-fallback.md) | `python-telegram-bot` API, message and file limits |
| [A2 — Open WebUI](A2-openwebui-optional.md) | Env var names, native MCP support, per-model tool limits, ARM support |
| [A3 — Music](A3-music-out-of-scope.md) | Only if you revive it: whether any audio-feature API exists again |

---

## Why the rules block matters

Two research passes on identical prompts produced very different quality. The
rigorous one wrote **NOT FOUND** rather than guessing; the other filled gaps with
year-old figures and asserted things that were false — including that ChatGPT Go,
Claude Max and Copilot Pro+ don't exist. All three do.

**The rules block at the top of each prompt is what produced the difference.**
Don't remove it. If you write your own prompt, include it:

```
RULES — follow exactly:
- Use only official sources: the company's or project's own pricing page, docs,
  changelog, or GitHub repository. No blogs, no news, no aggregators.
- Give the source URL and the page's last-updated date for every answer.
- If you cannot find an official source, write NOT FOUND. Do not substitute a
  number from elsewhere and do not estimate.
- Say clearly if any figure looks older than 3 months.
- I am in India. India-specific pricing takes priority. Convert USD at Rs 88 = $1
  and label it as your conversion.
```

🏆 **Run important prompts on two different models.** The disagreement is what
exposes stale answers — that's how the corrections in
[CHANGELOG](CHANGELOG.md) were found.

---

## Two general-purpose prompts

### Check one figure

For any single ⚠️ that's blocking a decision.

```
Find the current official price or limit for: [the thing]

Requirements:
- Use only the provider's own website or official documentation. No blog posts,
  no news articles, no aggregator sites.
- Give the figure, the exact page URL, and the date the page was last updated if
  it shows one.
- If prices are in US dollars, also give the rupee figure at Rs 88 = $1 and say
  clearly that you converted it.
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

Run this against any config in this plan before trusting it.

```
RULES:
- Use ONLY the official documentation site and GitHub repository for [tool name].
- State the version your answer applies to.
- If something is not documented, write NOT DOCUMENTED. Do not infer.

I am using this configuration for [tool name]:

[paste your config]

For each setting, tell me:
1. Is the key name still correct in the current version? If not, what is it now?
2. Is it in the right section of the file?
3. Is the value format still correct (units, string vs number, allowed values)?
4. Was anything deprecated or removed?

Output as:
| My setting | Still correct? | Current form | Source URL | Version |

Then list anything important in the current version that my config is missing.
```

---

## What to do with the answers

1. **Update the file the prompt came from.** Replace the ⚠️ with ✅, the real
   figure, and the date you checked.
2. **A NOT FOUND is a useful answer.** It tells you to design around the
   uncertainty rather than trust a number.
3. **Add a line to [CHANGELOG](CHANGELOG.md)** when something is materially
   different. Future-you will want to know when the number was last true.
4. **Paste the results back to me** and I'll fold them in.

---

Back to: [README](README.md) · [Build prompts](15-build-prompts.md) ·
[CHANGELOG](CHANGELOG.md)
