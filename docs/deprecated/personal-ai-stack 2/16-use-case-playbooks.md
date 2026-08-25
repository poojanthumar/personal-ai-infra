# 16 — Use Case Playbooks

Every use case, end to end: what to build, in what order, and exactly what
happens when you send a request.

**Music automation has been dropped from scope.** File 09 is kept for reference
but is not part of the plan.

---

## Part 1 — The three routes

Every request takes one of three paths. Knowing which is the single most useful
thing in this document.

| Route | Work happens on | Response | Use when |
|---|---|---|---|
| **A — MCP server** | Oracle, or a remote service | Synchronous, seconds | The data is on the internet or on Oracle |
| **B — Direct tools** | Oracle | Synchronous, seconds | SearXNG, Crawl4AI — things you wired yourself |
| **C — Job queue** | **Your Mac** | **Asynchronous, minutes** | Anything touching your files, photos, or heavy compute |

### The decision rule

> **Finishes in under ~10 seconds and returns a small result → A or B.
> Otherwise → C.**

### Where MCP servers sit

**A community MCP server runs as a subprocess of OpenClaw, on Oracle.** That
gives you exactly two possible locations:

| Location | Servers | Configured in |
|---|---|---|
| **Oracle** — stdio subprocess | `fetch`, `filesystem`, `sqlite`, Playwright | OpenClaw's MCP config |
| **Remote** — a URL | GitHub, Linear, Notion | Same, plus credentials |
| ❌ **Your Mac** | **None** | — |
| ❌ **LiteLLM** | **None.** It is not an MCP client | No MCP config exists there |

🚨 **The trap:** `filesystem` on Oracle sees **Oracle's** disk. `sqlite` on Oracle
can only open a database **on Oracle**. Your photos and `index.sqlite` are on the
Mac. **No off-the-shelf MCP server can reach across.** That is exactly why Route
C exists.

⚠️ Worth checking: `docs.litellm.ai/docs/mcp` exists. If LiteLLM now acts as an
MCP *gateway*, you could register servers centrally there. Read it before
building anything around per-client config.

### Your Mac exposes one thing

**Ollama on port 11434, over Tailscale.** That's a model endpoint, not MCP.
Everything else the Mac does is outbound — polling the queue.

### The language that keeps this clear

The model never acts. It emits text describing what it wants, then stops.

| Don't say | Say |
|---|---|
| "the model searches" | "the model **asks for** a search" |
| "the model reads the file" | "the model **requests** a read; the client performs it" |
| "the model calls the tool" | "the model **emits a tool request**; the client executes it" |

Count the network connections a model makes: **zero.** OpenClaw makes them all.

---

## Part 2 — Build order

Each row is independently useful. Stop whenever you have enough.

| # | Build | File | Time | Unlocks |
|---|---|---|---|---|
| 1 | Local models on the Mac | [01](01-local-ai-setup.md) | 1 h | Everything else |
| 2 | **Photo/video ranker** | [07](07-photo-video-ranker.md) | 3 h | 🏆 Real value on day one, ₹0 |
| 3 | LiteLLM router | [02](02-litellm-router.md) | 1 h | Budgets, privacy gate |
| 4 | Oracle box + queue API | [03](03-vm-hosting.md) | 3 h | Always-on |
| 5 | Mac agent | [06](06-job-queue-and-mac-agent.md) | 2 h | Remote requests reach your files |
| 6 | OpenClaw on WhatsApp | [15](15-openclaw.md) | 3 h | The front door |
| 7 | Reels pipeline | [08](08-reels-pipeline.md) | 3 h | Videos from ranked clips |
| 8 | Photo albums | [10](10-photos-albums.md) | 3 h | Event grouping |
| 9 | Web research | [12](12-web-crawling.md) | 2 h | Search and read, ₹0 |
| 10 | Dashboard | [11](11-dashboard.md) | 2 h | See spend and jobs |

**Steps 1 and 2 alone are worth doing even if you build nothing else.** They cost
₹0 and solve the problem you actually described.

---

# USE CASE 1 — Rank photos and videos

**Route C — job queue.** No MCP server can do this: none of them can run CLIP.

## Build steps

| # | Do | Where | File |
|---|---|---|---|
| 1 | Install ffmpeg, exiftool, torch, open_clip, imagehash, scenedetect | Mac | [01](01-local-ai-setup.md) §8 |
| 2 | Confirm `torch.backends.mps.is_available()` is `True` | Mac | [01](01-local-ai-setup.md) §8 |
| 3 | Download `ava+logos-l14-linearMSE.pth` to `~/.cache/aesthetic/` | Mac | [07](07-photo-video-ranker.md) §2 |
| 4 | Create `media_db.py` — the SQLite schema | Mac | [07](07-photo-video-ranker.md) §3 |
| 5 | Create `rank_media.py` | Mac | [07](07-photo-video-ranker.md) §4 |
| 6 | Run on a 20-file test folder | Mac | [07](07-photo-video-ranker.md) §5 |
| 7 | Run on the real folder with `caffeinate -s` | Mac | [07](07-photo-video-ranker.md) §5 |
| 8 | **Rate ~100 photos, fit weights to your taste** | Mac | [07](07-photo-video-ranker.md) §6 |
| 9 | Caption the top 500 using `private-local` | Mac | [07](07-photo-video-ranker.md) §7 |
| 10 | Register `rank_media` as a job handler | Mac | [06](06-job-queue-and-mac-agent.md) §8 |
| 11 | Define the `rank_media` tool in OpenClaw | Oracle | [15](15-openclaw.md) §3 |

**Step 8 is the one people skip and shouldn't.** Without it you get a stranger's
taste. Fifteen minutes of rating makes the scores yours.

## 🚨 Your example path will be rejected first time

`/Users/mymac/Downloads/Australia/Day1` is outside `~/Media`, so `safe_path()`
blocks it — correctly, since that guard is what stops a WhatsApp message reading
`~/.ssh`.

**Fix: give the agent a list of roots.** In `agent.py`:

```python
MEDIA_ROOTS = [
    Path(p).expanduser().resolve()
    for p in os.environ.get("MEDIA_ROOTS", "~/Media:~/Downloads").split(":")
]


def safe_path(user_path: str) -> Path:
    """
    Turn text from a chat message into a real folder path.
    The most important function in the file.
    """
    if not user_path or not isinstance(user_path, str):
        raise ValueError("no path given")

    cleaned = user_path.strip().lstrip("/").replace("~", "")

    for root in MEDIA_ROOTS:
        candidate = (root / cleaned).resolve()
        # resolve() follows symlinks, so this also catches link-based escapes
        if candidate.is_relative_to(root) and candidate.exists():
            return candidate

    raise ValueError(f"path is not inside any allowed root: {user_path}")
```

**Re-run the safety test in file 06 §4 after this change.** Every line must
print `OK`.

## What happens at runtime

You send: *"rank the images and videos in Downloads/Australia/Day1"*

| # | Step | Where | Notes |
|---|---|---|---|
| 1 | Message arrives | Oracle | OpenClaw |
| 2 | Request sent to LiteLLM → model, with tool definitions as text | Oracle | ~800 tokens |
| 3 | **Model emits a tool request**: `rank_media(path="Downloads/Australia/Day1")` then stops | — | No connection made |
| 4 | OpenClaw executes it — POST to the queue API. **No work done.** Returns `{job_id: 42}` | Oracle | Milliseconds |
| 5 | Model replies *"queued as 42, I'll message you"* → WhatsApp | Oracle | |
| 6 | **Conversation ends. No model running.** | — | |
| — | *Gap: seconds to hours, until your Mac is awake* | — | |
| 7 | Agent polls `GET /jobs/next`, receives job 42 | Mac | Path still inert text |
| 8 | `safe_path()` resolves it against your roots | Mac | **Now it's a real folder** |
| 9 | `caffeinate -s` starts so the Mac won't sleep | Mac | |
| 10 | Walks the folder. Videos split into scenes, one frame each via ffmpeg | Mac | 180 photos + 6 videos |
| 11 | Per item: CLIP → aesthetic, Laplacian → sharpness, histogram → exposure, face detect, perceptual hash | Mac | **30–60 s. No LLM. ₹0** |
| 12 | Dedup pass collapses near-identical shots | Mac | The most useful output |
| 13 | Rows written to `index.sqlite` | Mac | |
| 14 | Optional: captions on the top 30 via **`private-local`** (local Gemma) | Mac | **Photos never leave the Mac** |
| 15 | Row written to `job_runs` | Oracle | For the dashboard |
| 16 | Result POSTed: `{scored: 186, distinct: 94, top: [...]}` | Mac → Oracle | |
| 17 | Watcher sees the finished job, reads `reply_to` | Oracle | |
| 18 | One cheap model call to phrase it, then send | Oracle | ~₹0.01 |
| 19 | WhatsApp: *"Ranked 186 items. 94 distinct moments. Top 10: …"* | — | |

**Total cost: ~₹0.01**, all of it in step 18. The ranking is free.

## Why the model never sees the media

One minute of 1080p video at 1 frame per second, sent to a premium model:

| Approach | Cost |
|---|---|
| Claude Opus 5, standard-res frames | ~96,000 tokens ≈ **₹85** |
| Claude Opus 5, high-res frames | ~287,000 tokens ≈ **₹250** |
| **CLIP on your Mac** | **₹0**, ~1 second |

Your 10 GB folder is 3–5 hours of footage. Through a model that's
**₹15,000–25,000 for one pass** — and slower than the free local version.

## What can go wrong

| Problem | Fix |
|---|---|
| "path is not inside any allowed root" | Add `~/Downloads` to `MEDIA_ROOTS` |
| Under 5 images/sec | Running on CPU — check MPS |
| All aesthetic scores near 5 | Weights file missing; using the prompt fallback |
| Model claims ranking is done | Strengthen the tool description with "ASYNCHRONOUS" |
| Job stuck at `running` | Mac slept. Hourly `/jobs/reclaim` puts it back |
| Dedup groups everything | Lower `max_distance` to 4 |

---

# USE CASE 2 — Make a reel

**Route C.** Depends on Use Case 1 having run.

## Build steps

| # | Do | Where | File |
|---|---|---|---|
| 1 | `pip install librosa soundfile` | Mac | [08](08-reels-pipeline.md) §1 |
| 2 | Create `beats.py`, test on a track | Mac | [08](08-reels-pipeline.md) §1 |
| 3 | Put music **you own** in `~/Media/Music` | Mac | [08](08-reels-pipeline.md) ⚠️ |
| 4 | Create `manifest.py` | Mac | [08](08-reels-pipeline.md) §2 |
| 5 | Create `plan_reel.py` **with the validator** | Mac | [08](08-reels-pipeline.md) §3 |
| 6 | Create `build_reel.py` | Mac | [08](08-reels-pipeline.md) §4 |
| 7 | Render one by hand end to end | Mac | [08](08-reels-pipeline.md) §5 |
| 8 | Register `reel_render` handler | Mac | [06](06-job-queue-and-mac-agent.md) §8 |
| 9 | Define `make_reel` tool | Oracle | [15](15-openclaw.md) §3 |
| 10 | Add beat-snapping in code | Mac | [08](08-reels-pipeline.md) §7 |

⚠️ **You cannot use Apple Music or Spotify tracks in an export.** They're
copy-protected — the render will simply fail. Use music you own or royalty-free
tracks.

## The architecture that makes it cheap

**The model writes a plan. ffmpeg does the work. The model never touches a
pixel.**

## What happens at runtime

You send: *"make a 30 second reel from the Australia photos, upbeat"*

| # | Step | Where | Notes |
|---|---|---|---|
| 1–6 | Same as Use Case 1 — tool request, job queued, conversation ends | Oracle | |
| 7 | Agent claims the job | Mac | |
| 8 | Query `index.sqlite` for the best matching clips | Mac | Free, instant |
| 9 | Build the manifest — **2–5 KB of text**. IDs, timestamps, scores, captions, beat times | Mac | |
| 10 | POST manifest to LiteLLM → `tier2-cheap` | Mac → Oracle | ~₹0.05 |
| 11 | Model returns an edit decision list as JSON | — | |
| 12 | **Validator checks every cut** against real clip IDs and time ranges | Mac | Rejects invented IDs |
| 13 | Snap cut boundaries to the nearest beat, in code | Mac | Not the model's job |
| 14 | ffmpeg extracts each cut, scales to 1080×1920, normalises frame rate | Mac | |
| 15 | Photos become clips with a slow zoom | Mac | |
| 16 | Pieces concatenated, music added with a fade-out | Mac | |
| 17 | Result POSTed; MP4 sent to WhatsApp if under ~45 MB | Mac → Oracle | |

**Total: ~₹0.05.** 1–3 minutes, mostly encoding.

## Why the validator matters more than the prompt

Models occasionally invent a clip ID or an out-of-range timestamp. Catching it in
step 12 gives you a clear error instead of a corrupt video.

## What can go wrong

| Problem | Fix |
|---|---|
| "fewer than 3 scored clips" | Run Use Case 1 first |
| Validation fails repeatedly | Use `tier2-cheap`, not a local 8B — it can't do reliable structured output |
| JSON parse error | Model wrapped it in markdown fences. The stripper handles it |
| Music silent | Copy-protected file. Use one you own |
| Cuts feel sloppy | Add beat-snapping (step 13) |

---

# USE CASE 3 — Group photos into albums

**Route C for the grouping. Route A afterwards, if you sync the index.**

## Build steps

| # | Do | Where | File |
|---|---|---|---|
| 1 | Choose **Immich** (own server) or **osxphotos** (Apple Photos) | Mac | [10](10-photos-albums.md) |
| 2 | If Immich: install via their official compose file | Mac or Oracle | [10](10-photos-albums.md) §1 |
| 3 | If Immich: comment out `immich-machine-learning` to save memory | — | [10](10-photos-albums.md) §2 |
| 4 | If osxphotos: `pip install osxphotos`, import metadata | Mac | [10](10-photos-albums.md) Option B |
| 5 | Create `group_photos.py` — time and distance gaps | Mac | [10](10-photos-albums.md) §5 |
| 6 | Run it, then **tune `TIME_GAP_HOURS`** to match real trips | Mac | [10](10-photos-albums.md) §5 |
| 7 | Create `name_events.py` | Mac | [10](10-photos-albums.md) §6 |
| 8 | Register `group_events` handler | Mac | [06](06-job-queue-and-mac-agent.md) §8 |

🚨 **Google Photos cannot do this.** Since 31 Mar 2025 third-party apps can only
see media they created. Whole-library access is gone, and the Picker API is
one-off user selection only. Immich or osxphotos are the working paths.

## What happens at runtime

You send: *"group my photos into events"*

| # | Step | Where | Notes |
|---|---|---|---|
| 1–6 | Tool request, job queued, conversation ends | Oracle | |
| 7 | Agent claims the job | Mac | |
| 8 | Read all photos with dates from `index.sqlite`, in time order | Mac | Free |
| 9 | Walk them, splitting on a **gap over 8 hours** or **movement over 30 km** | Mac | **No AI. Pure arithmetic** |
| 10 | Drop clusters with fewer than 4 photos | Mac | |
| 11 | Write to `events` and `event_photos` | Mac | |
| 12 | For each unnamed event: send its dates and top 12 captions to a model | Mac | **Text only, no images** |
| 13 | Model returns a short name — "Beach Trip", "Diwali at Home" | — | |
| 14 | Names stored, marked `named_by='ai'` so you can override | Mac | |
| 15 | Result POSTed and sent | Mac → Oracle | |

**Cost: ₹0 locally** (Gemma-3-12B), or **~₹0.10** for 50 events on Flash-Lite.
The grouping itself is always free.

## Why this feeds Use Case 2

Once events are named, *"make a reel of the Australia trip"* matches against
**event names** rather than guessing from captions. Much more accurate. Add the
event lookup to `build_manifest` — file 10, last section.

## What can go wrong

| Problem | Fix |
|---|---|
| "no photos with dates" | EXIF stripped (common from WhatsApp). Fall back to file modification time |
| One giant event | No GPS, similar timestamps. Lower `TIME_GAP_HOURS` to 4 |
| Hundreds of tiny events | Raise `TIME_GAP_HOURS` and `MIN_PHOTOS_PER_EVENT` |
| Generic names | Improve the captioning prompt in file 07 §7 |

---

# USE CASE 4 — Research and daily questions

**Route B — direct tools on Oracle.** Or Route A with the `fetch` MCP server.
**Your Mac is not involved, so this works while it sleeps.**

## Build steps

| # | Do | Where | File |
|---|---|---|---|
| 1 | Run SearXNG in Docker with `formats: json` | Oracle | [12](12-web-crawling.md) §1 |
| 2 | Confirm `?format=json` returns JSON, not 403 | Oracle | [12](12-web-crawling.md) §2 |
| 3 | `pip install crawl4ai`, run `crawl4ai-setup` | Oracle | [12](12-web-crawling.md) §4 |
| 4 | Create `web_search.py` and `web_read.py` | Oracle | [12](12-web-crawling.md) §3, §5 |
| 5 | Wire both as OpenClaw tools | Oracle | [15](15-openclaw.md) §3 |
| 6 | Optional: attach the `fetch` MCP server instead | Oracle | [15](15-openclaw.md) §5 |

🏆 **Prefer your own two tools over the `fetch` MCP server.** Two small schemas
cost fewer tokens than a whole server's set, and Crawl4AI's Markdown output is
better for a model to read than generic fetch.

## What happens at runtime

You send: *"best wedding destinations in Goa"*

| # | Step | Where | Notes |
|---|---|---|---|
| 1 | Message arrives | Oracle | |
| 2 | Request to LiteLLM → **`tier1-public-only`** (Gemini free), with tool definitions | Oracle | **₹0** — public data, so the free tier's training clause is irrelevant |
| 3 | **Model emits**: `web_search(query="wedding venues Goa")` then stops | — | No connection made |
| 4 | **OpenClaw makes the HTTP request** to SearXNG on localhost:8888 | Oracle | Free, no key, no quota |
| 5 | 8 results returned to OpenClaw | Oracle | Title, URL, snippet |
| 6 | Everything sent back to the model as text | Oracle | |
| 7 | **Model emits**: `web_read(urls=[3 or 4 it picked])` then stops | — | |
| 8 | **OpenClaw performs the fetches** via Crawl4AI | Oracle | Headless browser → clean Markdown, trimmed to ~6,000 chars each |
| 9 | Page text back as tool results | Oracle | |
| 10 | Model returns an answer with `[1] [2]` citations. No tool request, so the loop ends | — | |
| 11 | → WhatsApp | Oracle | |

**Network connections the model made: zero. OpenClaw made five.**

**~15 seconds, ~6,000 tokens, ₹0.**

## Why the Markdown conversion matters

| Content | Tokens |
|---|---|
| Raw HTML page | 30,000–100,000 |
| Same page as clean Markdown | 3,000–10,000 |
| Trimmed to 6,000 characters | **~1,500** |

Roughly a **ten times** cost reduction.

## This is also how you verify the ⚠️ marks

Every "check this yourself" note in these documents is what this tool is for.
Use the prompts in [file 14](14-research-prompts.md).

## What can go wrong

| Problem | Fix |
|---|---|
| SearXNG returns 403 | `formats: json` missing from `settings.yml` |
| Answer invents facts | Strengthen the "do not fill gaps from memory" instruction; use `tier2-cheap` |
| Very slow | Raise `concurrency` in `read_many` to 6 |
| High token cost | Lower `max_chars` to 4,000 |

---

# USE CASE 5 — Coding

**Not a build — a purchase decision.** Coding happens in your terminal, not
through this stack.

## What to use

| Option | ₹/month | Verdict |
|---|---|---|
| **Gemini CLI free tier** | **₹0** | ⚠️ Flash-only since 25 Mar 2026. Check if Google AI Plus unlocks Pro |
| **Metered Sonnet 5 API** | ~₹1,000 buys ~2.8M tokens | 🏆 **Start here.** 10–25 sessions |
| **Claude Pro** | ₹1,760 | 🏆 Switch when intro pricing ends 31 Aug 2026 |
| ❌ Z.ai GLM Coding Plan | ₹1,584 | Claude Pro is better for ₹176 more |
| ❌ Qwen Code CLI | — | Free tier ended 15 Apr 2026 |

## Steps

1. **Check what Google AI Plus already gives you.** Run `gemini` and see which
   models are offered. If Pro is available, your free tier is much stronger than
   the table suggests.
2. Get an **Anthropic API key** — separate bill from Claude Pro.
3. Add it as `tier3-smart` in LiteLLM ([file 02](02-litellm-router.md) §3).
4. Point Claude Code at your **Mac's** LiteLLM: `ANTHROPIC_BASE_URL=http://localhost:4000`
5. Watch the dashboard. When monthly spend exceeds ₹1,760, buy Claude Pro instead.

🚨 **Keep work and personal completely separate.** Your Apple work Claude Code
setup stays untouched. Never route Apple source code through a personal provider,
and never through a Chinese provider.

## Configure MCP for coding separately

Claude Code is its own MCP client on your **Mac**, configured in `~/.claude.json`
or a project `.mcp.json`. Those servers are for coding — filesystem, git, your
project's database. **Nothing to do with OpenClaw's servers on Oracle.**

---

# USE CASE 6 — Anything else, via MCP

**Route A.** This is where MCP genuinely earns its place: **you didn't write the
server.**

## Steps

1. Find a server — the official `modelcontextprotocol/servers` repo, or a hosted
   one like Linear or Notion.
2. Add it to OpenClaw's MCP config on Oracle — stdio command, or URL plus
   credentials ([file 15](15-openclaw.md) §5).
3. ⚠️ **Count the tokens it adds** before leaving it attached.
4. Restart OpenClaw, confirm the tools appear.

## What happens at runtime

You send: *"what's the status of ENG-123?"*

| # | Step | Where |
|---|---|---|
| 1 | Message arrives | Oracle |
| 2 | OpenClaw already holds the tool list, cached at startup | Oracle |
| 3 | Request to LiteLLM → model, tools attached | Oracle |
| 4 | **Model emits**: `get_issue(id="ENG-123")` then stops | — |
| 5 | **OpenClaw sends a JSON-RPC message** — down a pipe for stdio, or HTTPS for remote. Credentials from its config; **the model never sees them** | Oracle |
| 6 | Result back to OpenClaw | Oracle |
| 7 | Steps 3–6 repeat if the model wants another call | Oracle |
| 8 | Final answer → WhatsApp | Oracle |

**~3–5 seconds. Mac not involved.**

## 🚨 This is the most expensive route

Every tool's full schema goes into **every** request, and each loop turn resends
it.

| Attached | Tokens/request | 4-turn loop |
|---|---|---|
| Your 4 queue tools | ~800 | 3,200 |
| Plus `fetch` | ~2,000 | 8,000 |
| Plus a GitHub-class server | **~15,000** | **60,000** |

**One question with GitHub attached can cost 30× more than ranking 186 photos.**
Tool schemas cost tokens; CLIP doesn't.

| Fix | Effect |
|---|---|
| 🏆 Keep under ~10 tools attached | Biggest win, free |
| Prompt caching | ~90% off the tool block — ⚠️ needs a byte-identical, deterministically sorted tool list |
| ⚠️ Scope servers per profile | **Not documented for OpenClaw.** Check first — prompt in file 15 |

---

## Part 3 — All six side by side

| | UC1 Ranking | UC2 Reels | UC3 Albums | UC4 Research | UC5 Coding | UC6 MCP |
|---|---|---|---|---|---|---|
| Route | **C** | **C** | **C** | **B** | Terminal | **A** |
| Runs on | **Mac** | **Mac** | **Mac** | Oracle | Mac | Oracle |
| Synchronous | ❌ min | ❌ min | ❌ min | ✅ ~15 s | — | ✅ ~4 s |
| Needs Mac awake | Job waits | Job waits | Job waits | ❌ No | Yes | ❌ No |
| Tokens | ~200 | ~4k | ~6k | ~6k | Lots | 2k–60k |
| Cost per use | **~₹0.01** | ~₹0.05 | ₹0–0.10 | **₹0** | Metered | ₹0–0.5 |
| MCP involved | ❌ | ❌ | ❌ | Optional | ❌ | ✅ |

Three things worth internalising:

**Your heaviest work is your cheapest.** Ranking 186 media files costs ₹0.01.
One question with a fat MCP server can cost ₹0.50.

**Only three use cases touch your Mac**, and all three are the queue. Everything
synchronous runs on Oracle and works with the laptop shut.

**MCP appears in exactly one place** — Use Case 6, where you didn't write the
server. Your own tools stay as job handlers.

---

## Part 4 — Everything that costs money

| Item | ₹/month |
|---|---|
| Google AI Plus — bundled with your Google One | **0** |
| Oracle Always Free | **0** |
| Local models, CLIP, ffmpeg, SearXNG, Crawl4AI, Postgres, OpenClaw, Tailscale | **0** |
| Coding — metered Sonnet 5 | 1,000 |
| Automation API calls — reels, captions, album names | ~50 |
| ⚠️ Spare SIM for WhatsApp | 150–200 |
| **Total** | **~₹1,200** |

A third of your ₹3,000 ceiling. Keep the rest unspent until the dashboard says
you need it.

---

Back to: [README](README.md) · [Decisions and costs](00-decisions-and-costs.md) ·
[CHANGELOG](CHANGELOG.md)
