# 00 — Architecture

Read this once. Everything else is implementation.

---

## The problem

You have three things that don't naturally fit together:

| | |
|---|---|
| **Your phone** | Where you want to type. Always with you |
| **Your MacBook** | Where your files are, and the only fast AI hardware you own. But it sleeps, moves networks, and has no fixed address |
| **A cheap always-on box** | Can be reached from anywhere, but can't do real work |

Most designs fail by asking the wrong machine to do the wrong job.

---

## The design

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

### What runs where, and why

| Oracle box | Why there | Your Mac | Why there |
|---|---|---|---|
| OpenClaw | Must be awake when you message | **Ollama 12B model** | 200 GB/s memory bandwidth |
| LiteLLM | Must be reachable by OpenClaw | CLIP + aesthetic scorer | Needs the GPU and the files |
| Postgres | Holds the queue while the Mac sleeps | ffmpeg | Video files are here |
| MCP servers | They only reach the internet anyway | Pull agent | Only outbound connections |
| SearXNG, Crawl4AI | Nothing local needed | `index.sqlite` | Written by local jobs |

**Your Mac exposes exactly one thing: Ollama on port 11434, over Tailscale.**
That's a model endpoint, not a tool server. Everything else it does is outbound.

---

## Rule 1 — The Mac always asks. Nothing connects in.

Indian ISPs mostly put you behind a shared address. There's no port to forward,
and your IP changes.

**So reverse the direction.** The Oracle box has a public address by definition —
you rented it. The Mac dials out to it.

```
Phone ──▶ Oracle (public) ◀── Mac (asks for work)
```

Four consequences, all good:

| | |
|---|---|
| No port forwarding, no router config, no fixed IP | The Mac never needs an address |
| Your changing IP is irrelevant | Identity is the connection, not the address |
| **A sleeping Mac means jobs wait** | Push would lose them |
| Nothing of yours is exposed to the internet | Only outbound 443 |

### Why not push?

| | Mac asks (pull) | Oracle sends (push) |
|---|---|---|
| Needs a public address on the Mac | ❌ No | ✅ Yes — you don't have one |
| Works behind shared-IP internet | ✅ | ❌ |
| Mac asleep at 9am | Job **waits** | Job **fails and is lost** |

---

## Rule 2 — Models handle text. Your Mac handles files.

An AI model cannot read a folder. Neither can a router. Only code running on the
machine that has the files.

| Component | What it does | Can it read your files? |
|---|---|---|
| **The model** (Gemma, Claude) | Turns text into text | ❌ **Never** |
| **LiteLLM** | Routes one request to one model | ❌ **Never.** No filesystem, no tools |
| **MCP servers** | Run tools — but on Oracle | ❌ Not your Mac's files |
| **The Mac agent** | Runs code: walks folders, runs CLIP, calls ffmpeg | ✅ **Only this** |

### The sentence that makes it click

**A folder path is inert text until it reaches the Mac.** Oracle stores
`"Downloads/Australia/Day1"` as 26 characters. It has no idea what that means and
never needs to. Only the Mac gives it meaning.

```
You type:      "rank the photos in Downloads/Australia/Day1"
                        ↓
Oracle stores: {"type":"rank_media","payload":{"path":"Downloads/Australia/Day1"}}
                        ↑ just text here
                        ↓
Mac asks:      GET /jobs/next → gets that JSON
                        ↓
Mac resolves:  /Users/poojanthumar/Downloads/Australia/Day1   ← NOW it means something
                        ↓
Mac runs:      CLIP on 186 real files
                        ↓
Mac returns:   {"scored": 186, "distinct": 94, "top": [...]}
```

### The arithmetic that forces this

One minute of 1080p video at 1 frame per second, sent to a premium model:

| Approach | Cost |
|---|---|
| Claude Opus 5, standard-res frames | ~96,000 tokens ≈ **₹85** |
| Claude Opus 5, high-res frames | ~287,000 tokens ≈ **₹250** |
| **CLIP on your Mac** | **₹0**, ~1 second |

Your 10 GB folder is 3–5 hours of footage. Through a model that's
**₹15,000–25,000 for one pass** — and slower than the free local version.

**So the model never touches your media.** Local tools score and describe it; only
a small text summary is ever sent anywhere.

---

## Rule 3 — The model never acts. It asks.

This trips everyone up, including me twice while writing these files.

A model emits text describing what it wants, then **stops**. Something else
performs the action. That something is OpenClaw.

```
1. OpenClaw → LiteLLM → model:  your question + tool definitions as text
2. Model returns TEXT:          {"tool":"web_search","arguments":{"query":"..."}}
                                ← it has made no connection. It has stopped.
3. OpenClaw reads that and MAKES the HTTP request to SearXNG
4. OpenClaw sends the results back to the model as more text
5. Model returns a final answer
```

**Network connections made by the model: zero. By OpenClaw: all of them.**

| Don't say | Say |
|---|---|
| "the model searches" | "the model **asks for** a search" |
| "the model reads the file" | "the model **requests** a read; OpenClaw performs it" |
| "the model calls the tool" | "the model **emits a tool request**; OpenClaw executes it" |

---

## The three routes

Every request takes one of three paths. Knowing which is the most useful thing in
this whole plan.

| Route | Work happens on | Response | Use when |
|---|---|---|---|
| **A — MCP server** | Oracle, or a remote service | Synchronous, seconds | Data is on the internet |
| **B — Direct tools** | Oracle | Synchronous, seconds | SearXNG, Crawl4AI — things you wired |
| **C — Job queue** | **Your Mac** | **Asynchronous, minutes** | Anything touching your files |

### The decision rule

> **Under ~10 seconds and a small result → A or B. Otherwise → C.**

### Worked examples

| Request | Route | Why |
|---|---|---|
| "Best wedding destinations in Goa" | **B** | Public web. Oracle can do it all |
| "Status of ENG-123?" | **A** | Hosted MCP server. Oracle → internet |
| "Rank the photos in Downloads/Australia/Day1" | **C** | 186 files, 60 seconds, on the Mac |
| "Make a 30 second reel" | **C** | ffmpeg, on the Mac |
| "Is job 42 done?" | **A** | One database read on Oracle. Instant |

Full step-by-step traces: [13 — Request flows](13-request-flows.md).

---

## Where MCP servers sit

**A community MCP server runs as a subprocess of OpenClaw, on Oracle.** That
gives exactly two possible locations:

| Location | Servers | Configured in |
|---|---|---|
| **Oracle** — stdio subprocess | `fetch`, `filesystem`, `sqlite`, Playwright | OpenClaw's MCP config |
| **Remote** — a URL | GitHub, Linear, Notion | Same, plus credentials |
| ❌ **Your Mac** | **None** | — |
| ❌ **LiteLLM** | **None.** Not an MCP client | No MCP config exists there |

🚨 **The trap:** `filesystem` on Oracle sees **Oracle's** disk. `sqlite` on Oracle
opens a database **on Oracle**. Your files are on the Mac. **No off-the-shelf MCP
server can reach across.** That is exactly why Route C exists.

**And you write zero MCP servers.** MCP exists so programs by *different* people
can interoperate. For your own tools you control both sides — they stay as job
handlers. Details: [08 — MCP servers](08-mcp-servers.md).

---

## The privacy boundary

Two things must never cross it:

| Rule | Enforced by |
|---|---|
| **Photos and personal files never reach the cloud** | The `private-local` tier in LiteLLM has **no fallback**. If the Mac is unreachable the job fails or waits — it does not escalate |
| **Apple work code never touches any of this** | Separate machine. OpenClaw runs on Oracle, not on your laptop |

⚠️ The reason this matters concretely: **Google's Gemini free tier uses your data
to improve their products** (their own pricing table says so; the paid tier says
no). So free Gemini is fine for public web research and nothing else.

🚨 **Never run OpenClaw on the laptop that has Apple source code.** An assistant
that processes messages from the internet and can run shell commands does not
belong on the same user account as your employer's code.

---

## What's deliberately not here

| Rejected | Why |
|---|---|
| Cloudflare Workers as the main box | 🚨 10 ms CPU per request. Can't host a database, an agent, or OpenClaw |
| A rented cloud GPU | ₹15,000+/month, and **slower than your Mac** for this work |
| Running the model on the Oracle VM | ~4 tok/s on ARM CPU vs 12–18 on your Mac. Worse and not free |
| Google Photos API | ⚠️ Closed to whole-library access since 31 Mar 2025 |
| Apple Music API | Needs a ~₹8,700/year developer membership. AppleScript is free |
| Custom phone app | WhatsApp already does everything it would |
| MCP-wrapping your own tools | Adds a protocol between code you own on both sides |

---

## ⚠️ Verify with AI

**Nothing in this file needs verification** — it's design reasoning, not facts
about the world. The numbers it cites are verified in the files that own them:

| Claim | Verified in |
|---|---|
| Oracle free tier size and capacity | [04](04-oracle-box.md) |
| Gemini free tier trains on your data | [01](01-decisions-and-costs.md) |
| Claude token prices | [01](01-decisions-and-costs.md) — ✅ confirmed |
| Google Photos API closure | [10](10-albums.md) — ✅ confirmed |
| OpenClaw's actual capabilities | [07](07-openclaw.md) — ⚠️ largely unverified |

---

Next: [01 — Decisions and costs](01-decisions-and-costs.md)
