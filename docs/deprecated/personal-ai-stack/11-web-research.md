# 12 — Web Crawling and Search


> ⚠️ **Anything marked ⚠️ in this file is unverified.** All of it is answered
> by the prompt in [⚠️ Verify with AI](#-verify-with-ai) at the bottom — paste it
> into Gemini or any web-enabled AI and update this file with the result.

**Goal:** let your AI search the web and read pages, without paying for a search
API and without hitting daily limits.

**Time:** 1–2 hours.

**Cost:** ₹0.

---

## The three separate jobs

People lump these together, but they are different tools:

| Job | Tool | Cost |
|---|---|---|
| **Search** — find which pages exist | SearXNG (self-hosted) | ₹0, unlimited |
| **Read** — turn one page into clean text | Crawl4AI | ₹0, unlimited |
| **Interact** — click, log in, fill forms | Playwright MCP | ₹0 |

You almost always want the first two. The third is for when a site needs
clicking through.

---

# PART 1 — SearXNG (search)

SearXNG asks many search engines on your behalf and combines the results. No API
key, no quota, no tracking.

## Step 1 — Run it

```bash
mkdir -p ~/Documents/Code/searxng && cd ~/Documents/Code/searxng

cat > settings.yml <<'EOF'
use_default_settings: true

server:
  secret_key: "change-this-to-something-random"
  limiter: false          # no rate limit; it is only you using it
  image_proxy: true

search:
  # JSON is what your scripts need. It is off by default.
  formats:
    - html
    - json
  safe_search: 0
  autocomplete: ""

engines:
  - name: google
    disabled: false
  - name: duckduckgo
    disabled: false
  - name: bing
    disabled: false
  - name: wikipedia
    disabled: false
EOF

docker run -d --name searxng \
  --restart unless-stopped \
  -p 8888:8080 \
  -v "$PWD/settings.yml:/etc/searxng/settings.yml:ro" \
  -e "BASE_URL=http://localhost:8888/" \
  searxng/searxng
```

**The `formats: json` line is the important one.** Without it, every API call
returns HTTP 403 and the error message does not explain why.

## Step 2 — Test it

```bash
# In a browser
open http://localhost:8888

# As an API
curl -s "http://localhost:8888/search?q=litellm+proxy&format=json" \
  | python3 -m json.tool | head -40
```

If you get 403, the `formats` setting did not take. Check
`docker logs searxng` and confirm the file mounted correctly.

## Step 3 — A search helper

Save as `~/Documents/Code/aihub/web_search.py`:

```python
"""Search the web using your own SearXNG. Free and unlimited."""

import os, requests

SEARX = os.environ.get("SEARXNG_URL", "http://localhost:8888")


def search(query, limit=8, category="general"):
    """Return a list of {title, url, snippet}. Raises on network failure."""
    r = requests.get(f"{SEARX}/search", params={
        "q": query,
        "format": "json",
        "categories": category,
        "language": "en",
    }, timeout=30)
    r.raise_for_status()

    out = []
    for item in r.json().get("results", [])[:limit]:
        out.append({
            "title": item.get("title", "")[:150],
            "url": item.get("url", ""),
            "snippet": (item.get("content") or "")[:300],
        })
    return out


if __name__ == "__main__":
    import sys, json
    print(json.dumps(search(" ".join(sys.argv[1:]) or "python asyncio"),
                     indent=2))
```

---

# PART 2 — Crawl4AI (reading pages)

Crawl4AI fetches a page in a real browser (so JavaScript-built pages work) and
converts it to clean Markdown. That matters: raw HTML wastes an enormous number
of tokens on tags and scripts.

## Step 4 — Install

```bash
source ~/.venvs/aihub/bin/activate
pip install crawl4ai
crawl4ai-setup          # downloads the browser it needs
```

⚠️ This downloads a Chromium browser, several hundred MB. It also needs Xcode
command line tools on macOS: `xcode-select --install`.

## Step 5 — A reading helper

Save as `~/Documents/Code/aihub/web_read.py`:

```python
#!/usr/bin/env python3
"""Fetch web pages and return clean Markdown ready for an AI to read."""

import asyncio, json, sys
from crawl4ai import AsyncWebCrawler


async def read_one(url, max_chars=12000):
    """Fetch one page. Returns {url, title, markdown, chars}."""
    async with AsyncWebCrawler(verbose=False) as crawler:
        result = await crawler.arun(url=url)
        md = (result.markdown or "")[:max_chars]
        return {
            "url": url,
            "title": getattr(result, "metadata", {}).get("title", "")[:200],
            "markdown": md,
            "chars": len(md),
            "truncated": len(result.markdown or "") > max_chars,
        }


async def read_many(urls, max_chars=8000, concurrency=4):
    """Fetch several pages at once. Failures come back with an error field."""
    sem = asyncio.Semaphore(concurrency)

    async def one(u):
        async with sem:
            try:
                return await read_one(u, max_chars)
            except Exception as e:
                return {"url": u, "error": f"{type(e).__name__}: {e}"}

    return await asyncio.gather(*[one(u) for u in urls])


if __name__ == "__main__":
    urls = sys.argv[1:]
    pages = asyncio.run(read_many(urls))
    for p in pages:
        print(f"\n=== {p.get('title') or p['url']} ===")
        print(p.get("error") or p["markdown"][:1500])
```

Test it:

```bash
python web_read.py https://docs.litellm.ai/docs/proxy/quick_start
```

---

# PART 3 — Put them together

This is the useful bit: search, read the top results, and have the AI answer
with sources.

Save as `~/Documents/Code/aihub/research.py`:

```python
#!/usr/bin/env python3
"""Search, read the best pages, and get an answer with sources cited."""

import asyncio, os, json, requests
from web_search import search
from web_read import read_many

LITELLM = os.environ.get("LITELLM_URL", "http://localhost:4000/v1")
KEY = os.environ["LITELLM_KEY"]


async def research(question, pages=4, model="tier1-public-only"):
    """
    Search, read, summarise with sources.

    Note the default model: tier1-public-only (Gemini free). That is safe here
    because everything involved is PUBLIC web content. Never use this tier for
    anything about you or your files.
    """
    print(f"searching: {question}")
    hits = search(question, limit=pages + 3)
    if not hits:
        return {"error": "no search results"}

    urls = [h["url"] for h in hits[:pages]]
    print(f"reading {len(urls)} pages...")
    read = await read_many(urls, max_chars=6000)

    good = [p for p in read if not p.get("error") and p.get("chars", 0) > 200]
    if not good:
        return {"error": "could not read any of the pages",
                "tried": urls}

    context = "\n\n".join(
        f"### SOURCE {i+1}: {p.get('title') or p['url']}\n"
        f"URL: {p['url']}\n\n{p['markdown']}"
        for i, p in enumerate(good)
    )

    prompt = (
        f"Question: {question}\n\n"
        "Answer using only the sources below. Rules:\n"
        "- Cite sources as [1], [2] and so on, matching the SOURCE numbers.\n"
        "- If the sources disagree, say so and give both positions.\n"
        "- If the sources do not answer the question, say that plainly. Do not "
        "fill the gap from memory.\n"
        "- Be direct. No preamble.\n\n"
        f"{context}"
    )

    r = requests.post(f"{LITELLM}/chat/completions",
        headers={"Authorization": f"Bearer {KEY}"},
        json={"model": model,
              "messages": [{"role": "user", "content": prompt}],
              "metadata": {"tags": ["job:research"]}},
        timeout=300)
    r.raise_for_status()

    return {
        "question": question,
        "answer": r.json()["choices"][0]["message"]["content"],
        "sources": [{"n": i + 1, "title": p.get("title"), "url": p["url"]}
                    for i, p in enumerate(good)],
        "failed": [p["url"] for p in read if p.get("error")],
    }


if __name__ == "__main__":
    import sys
    q = " ".join(sys.argv[1:]) or "what is the current price of Claude Opus 5"
    out = asyncio.run(research(q))
    print("\n" + (out.get("answer") or out.get("error", "")))
    for s in out.get("sources", []):
        print(f"[{s['n']}] {s['url']}")
```

Run it:

```bash
source ~/.venvs/aihub/bin/activate
set -a; source ~/.config/aihub/.env; set +a
export SEARXNG_URL=http://localhost:8888

python research.py "current Groq free tier rate limits"
```

**This solves a real problem for you:** every "⚠️ check this yourself" note in
these documents is exactly what this tool is for.

---

## Token cost of reading pages

| Content | Approximate tokens |
|---|---|
| Raw HTML page | 30,000–100,000 |
| Same page as clean Markdown | 3,000–10,000 |
| Trimmed to 6,000 characters | ~1,500 |

**So the Markdown conversion cuts the cost by roughly ten times.** Four pages at
6,000 characters each is about 6,000 tokens — ₹0 on the free tier, or about
₹0.17 on DeepSeek.

---

## Which model for research

| Model | Good for | Careful |
|---|---|---|
| `tier1-public-only` (Gemini free) | 🏆 Web research. It is all public data anyway | ⚠️ Never send personal data through this tier |
| `tier1-free` (Groq/Cerebras) | Also fine, and personal-data-safe | Daily token cap may bite on long pages |
| `tier2-cheap` (DeepSeek) | Long multi-page synthesis | ~₹0.20 per query |
| `tier0-local` (Qwen3-8B) | Short pages only | Struggles with 4 pages at once |

---

# PART 4 — Playwright MCP (optional)

For when a site needs actual clicking — logging in, pressing buttons, filling
forms.

```bash
npx -y @playwright/mcp@latest --help
```

Connect it to Open WebUI through the translator from appendix A2, step 8:

```bash
mcpo --port 8002 -- npx -y @playwright/mcp@latest
```

⚠️ Give this careful thought before using it with a logged-in browser. An AI
clicking around inside your accounts can do real damage. Start with public
sites only.

**Most of the time you do not need this.** Search plus read covers the vast
majority of what you want.

---

## Add it to Telegram

```python
async def cmd_research(update, ctx):
    """Search the web and answer with sources."""
    if not mine(update):
        return
    q = " ".join(ctx.args)
    if not q:
        await update.message.reply_text("Usage: /research groq free tier limits")
        return

    await update.message.reply_text("Searching and reading...")
    job_id = queue_job("research", {"question": q}, update.effective_chat.id)
    await update.message.reply_text(f"Queued job #{job_id}")
```

And in the Mac agent (file 05):

```python
def h_research(payload):
    import asyncio
    from research import research
    out = asyncio.run(research(payload["question"]))
    return {"answer": out.get("answer", out.get("error"))[:3000],
            "sources": out.get("sources", [])}

HANDLERS["research"] = h_research
```

---

## Troubleshooting

| Problem | Cause | Fix |
|---|---|---|
| SearXNG returns 403 on the API | `formats: json` missing | Add it to `settings.yml` and restart |
| Search results empty | Upstream engines blocking the container | Enable more engines; try again later |
| `crawl4ai-setup` fails | Missing Xcode tools | `xcode-select --install` |
| Crawl4AI hangs on some sites | JavaScript-heavy or blocking bots | Set a timeout; skip that URL |
| Answer says "sources do not cover this" | Search found the wrong pages | Rephrase the query more specifically |
| Answer invents facts | Model ignoring instructions | Use `tier2-cheap`; strengthen the "do not fill gaps" rule |
| Very slow | Reading pages one at a time | The `concurrency` setting handles this; raise it to 6 |
| High token cost | Not trimming pages | Lower `max_chars` to 4,000 |

---

## Prompt for AI

```
Write a Python module called url_filter.py with one function.

Signature:

    rank_urls(hits: list[dict], question: str, max_results: int = 4) -> list[dict]

Input: "hits" is a list of dictionaries from a web search. Each has keys
"title", "url", and "snippet". "question" is what the user asked.

Purpose: before I spend time and tokens reading pages, sort them so the most
likely useful ones come first, and drop the useless ones.

Scoring rules — start each hit at 0 points and apply all that match:
+3 if the URL's domain is an official documentation site. Treat a domain as
   official docs if it contains any of: "docs.", "developer.", ".dev/docs",
   "/documentation", "readthedocs".
+2 if any word from the question (longer than 3 characters, lowercased) appears
   in the title.
+1 for each question word that appears in the snippet, up to a maximum of +3.
+1 if the URL uses https.
-2 if the domain is in this list: pinterest.com, quora.com, facebook.com,
   x.com, twitter.com, reddit.com
-3 if the URL ends in .pdf, .zip, .doc, .docx, .xls, or .xlsx
-5 if the URL path contains any of: /login, /signin, /signup, /cart, /checkout

Then:
1. Remove any hit scoring below 0.
2. Remove duplicates by domain, keeping only the highest-scoring hit per domain.
3. Sort by score, highest first.
4. Return at most max_results items. Each returned dictionary must be the
   original one plus a new key "score" with the number.

Also write pytest tests covering:
- A docs URL beats a blog URL for the same question.
- A pinterest.com URL is dropped.
- A .pdf URL is dropped.
- Two URLs from the same domain collapse to one.
- An empty input list returns an empty list.
- max_results is respected when more hits qualify.

Rules:
- Standard library only.
- Do not modify the input list or its dictionaries. Return new dictionaries.
- Type hints on the signature.
- One comment above each numbered step.
```

---

## Check you are done

- [ ] SearXNG loads at `http://localhost:8888`
- [ ] `?format=json` returns JSON, not 403
- [ ] `web_search.py` returns results
- [ ] `web_read.py` returns clean Markdown for a real page
- [ ] `research.py` gives an answer with numbered sources
- [ ] Cost per research query is under ₹0.25
- [ ] `/research` works from Telegram

---

## ⚠️ Verify with AI

| # | Unverified | Why it matters |
|---|---|---|
| 1 | SearXNG settings schema | `formats: json` location matters or you get 403 |
| 2 | Crawl4AI current API | `arun` signature has changed before |
| 3 | Whether Crawl4AI runs on ARM Linux | Oracle is aarch64 |
| 4 | Free search API fallback limits | Brave and Tavily allowances shift

Paste this into Gemini or any web-enabled AI, then update this file with what comes back.

```
RULES — follow exactly:
- Use only the official SearXNG documentation and repository, the Crawl4AI
  repository and docs, and each search provider's own pricing page. No blogs.
- Give the source URL and version for each answer.
- If something is not documented, write NOT DOCUMENTED.

I run SearXNG and Crawl4AI in Docker on an Oracle Ubuntu ARM (aarch64) VM, and
call both from Python to feed clean text to an AI model.

1. SEARXNG:
   a. Current minimal settings.yml to enable the JSON API. Where exactly does the
      `formats` key go? Paste the official example.
   b. Confirm that omitting JSON from formats causes HTTP 403 on API calls.
   c. Current recommended Docker run or compose configuration, including where
      settings.yml must be mounted and the secret_key requirement.
   d. Does the official image support linux/arm64?
   e. Recommended way to disable rate limiting for single-user self-hosted use.
2. CRAWL4AI:
   a. Current version and the official quickstart example for fetching one page
      and getting Markdown.
   b. Exact current signature of the async crawl method and the result object's
      fields — where is the Markdown, where is the page title?
   c. Does crawl4ai-setup work on ARM Linux? Does its browser download support
      aarch64? Any extra system packages needed on Ubuntu ARM?
   d. Recommended way to crawl several URLs concurrently, with the official
      example and any concurrency limit they advise.
   e. Any built-in option to cap output length or strip boilerplate.
3. FALLBACK SEARCH APIS — current free tier for Brave Search API and Tavily:
   requests per month, rate limits, whether a card is required.
4. Is there an official MCP server for web fetch or web search maintained by the
   modelcontextprotocol organisation? Package name and transport.

Output as: | # | Answer | Official example | Source URL | Version |
```

---

Next: [13 — AI prompts](15-build-prompts.md)
