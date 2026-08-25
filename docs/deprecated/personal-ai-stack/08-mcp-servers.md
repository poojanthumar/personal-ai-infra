# 08 — MCP Servers

> ## ⚠️ PARTLY PROMPT-DRIVEN
>
> **The architecture in this file is fixed and correct** — where servers run, what
> they can reach, what they cost. That doesn't change with versions.
>
> **The catalogue is not.** Which servers exist, whether they're maintained, and
> how many tools each exposes changes constantly. That part is a
> [generation prompt](#the-catalogue-prompt) — run it and save the output as
> `08a-mcp-catalogue.md`.

---

## What MCP is, in one paragraph

MCP is a standard way for a program to discover and run tools. **The model never
knows MCP exists** — it only ever sees a list of tool definitions in its own API
format. MCP is a convention for *your side*: how a client finds tools and calls
them.

So something has to run this loop:

```
1. Connect to the MCP server, ask "what tools do you have?"
2. Convert those to the model's tool format
3. Send them with the request
4. Model replies "call get_issue(id=ENG-123)"     ← it stops here
5. Execute that against the MCP server            ← the client does this
6. Send the result back
7. Repeat until the model stops asking
```

That loop is the **client**. In your stack, the client is **OpenClaw**.

---

## Where servers can run — and only two places

**A community MCP server is a subprocess of OpenClaw, on Oracle.** That gives you
exactly two locations.

| Location | Type | Examples | Configured in |
|---|---|---|---|
| **Oracle** | stdio subprocess | `fetch`, `filesystem`, `sqlite`, Playwright | OpenClaw's MCP config |
| **Remote** | a URL | GitHub, Linear, Notion | Same, plus credentials |
| ❌ **Your Mac** | — | **None** | — |
| 🏆 **LiteLLM** | gateway | Any of the above, registered centrally | ✅ **`mcp_servers` in config.yaml with `include_tools`** — see below |

### 🚨 The trap that catches everyone

| Server, running on Oracle | What it can actually see |
|---|---|
| `filesystem` | **Oracle's** disk. Empty |
| `sqlite` | A database file **on Oracle**. Your `index.sqlite` is on the Mac |
| `fetch` | The internet. ✅ Fine |

**No off-the-shelf MCP server can reach across to your Mac.** Oracle cannot spawn
a subprocess on your laptop, and your laptop has no inbound listener.

That is precisely why the **job queue** exists ([05](05-mac-agent.md)). It is the
Mac's interface, and it is not MCP.

🏆 **VERIFIED 2 Aug 2026: LiteLLM *is* an MCP gateway, and it filters tools.**
This is the most useful thing verification turned up, and it changes the
recommendation in this file.

LiteLLM can register MCP servers centrally and expose them to clients —
**with per-tool filtering**:

```yaml
# config.yaml on the Oracle box
mcp_servers:
  - name: weather_mcp
    base_url: http://weather-mcp-server:8080
    include_tools: ["get_weather"]        # ← ONLY this tool is exposed
```

Source: `docs.litellm.ai/docs/mcp`. ⚠️ Confirm `include_tools` exists in your own
version before relying on it.

### Why this matters

`include_tools` is exactly the per-tool allowlist I earlier said didn't exist. It
is **fixes 1 and 2 from the cost table below, in one config line.**

| | Configured per client | With LiteLLM as gateway |
|---|---|---|
| Where MCP config lives | Once each in OpenClaw, Claude Code, Open WebUI | **Once, centrally** |
| Filtering tools | ⚠️ Not possible in mcpo | ✅ `include_tools` |
| A GitHub server's ~40 tools | ~15,000 tokens per request | **Only the 2 you need** |
| Adding a second client | Reconfigure everything again | It just works |
| MCP spend on your dashboard | Scattered | Same place as everything else |

🏆 **So: register MCP servers in LiteLLM, not in OpenClaw** — if your version
supports it. Keep OpenClaw's own MCP config only for servers LiteLLM can't reach.

**Everything else in this file still holds.** Servers still run on Oracle, still
cannot see your Mac's files, and you still write none of them. Only *where you
configure them* changes.

---

## You write zero MCP servers

**MCP exists so programs written by different people can interoperate.**

For your own tools you control both sides — the tool and the caller. Wrapping your
CLIP scorer in an MCP server so your own script can call it adds a protocol, a
subprocess, and token overhead to replace a Python function call.

| Situation | Use |
|---|---|
| Someone else's tool server — GitHub, Linear, Notion, Playwright | ✅ **MCP** |
| Someone else's client should reach *your* tools — e.g. Claude Desktop querying your photo database | ✅ MCP, later. A genuinely nice idea |
| Your own Mac agent calling your own functions | ❌ **Plain Python.** Job handlers |

---

## 🚨 The cost problem, and it's the biggest one here

Every tool's **full JSON schema goes into every request**. And a tool-use loop
resends the whole set on each turn.

| Tool complexity | Tokens each |
|---|---|
| Simple — one string argument | ~100–150 |
| Typical | ~250 |
| Complex — many optional parameters | ~400–800 |

At ~250 average:

| Attached | Per request | 4-turn loop |
|---|---|---|
| Your 4 queue tools | ~800 | 3,200 |
| Plus `fetch` | ~2,000 | 8,000 |
| 3 servers × 10 tools | ~7,500 | 30,000 |
| Plus a GitHub-class server | **~15,000** | **60,000** |

### The number that should worry you

**One question with a fat MCP server attached can cost 30× more than ranking 186
photos.** Tool schemas cost tokens; CLIP doesn't.

⚠️ And on a free tier with a daily token cap, a single 4-turn loop with 75 tools
attached can consume your whole day.

### Four fixes, best first

| # | Fix | Effect | Notes |
|---|---|---|---|
| 1 | 🏆 **Attach under ~10 tools** | ~90% cut | Free. Do this before anything else |
| 2 | 🏆 **`include_tools` in LiteLLM** | ~90% on a fat server | ✅ Verified. Expose only the tools you need |
| 2b | **Restrict at the server** | Large | Most servers take arguments limiting scope |
| 3 | **Prompt caching** | ~90% off the tool block | ⚠️ Needs a byte-identical, deterministically sorted tool list. Changing the set invalidates everything |
| 4 | ⚠️ **Scope servers per profile** | Large | **Not documented for OpenClaw.** Asked in [07](07-openclaw.md)'s prompt |

🚨 **Correction:** I previously suggested an `mcpo --allow-tools` flag. **No such
flag is documented — I invented it.** But the capability does exist, one layer up:
**LiteLLM's `include_tools`**. Use that instead.

### Prompt caching, if you use it

Two rules or it silently doesn't work:

```python
tools = sorted(tools, key=lambda t: t["name"])   # deterministic order, always
```

- **Sort deterministically.** Order changes → cache miss.
- **Never change the tool set mid-conversation.** Adding one tool invalidates the
  whole prefix, including your system prompt and history.

⚠️ Minimum cacheable size: 512 tokens on Claude Opus 5, 1,024 on Sonnet 5, 4,096
on Haiku 4.5. Below that it silently doesn't cache. And most **free tiers don't
offer caching at all** — on those, fix 1 is your only lever.

---

## What to actually attach

Start with almost nothing and add deliberately.

| Server | Attach? | Why |
|---|---|---|
| Your 4 queue tools ([07](07-openclaw.md)) | ✅ **Always** | How WhatsApp reaches your Mac |
| **Web fetch** | ✅ **Yes** | Cheap, constantly useful |
| `filesystem` on Oracle | ⚠️ Only for reports/exports | Cannot see your Mac |
| GitHub / Linear / Notion | ⚠️ **Only when you need it** | Expensive. Detach after |
| Playwright | ⚠️ Rarely | ⚠️ Not maintained by the official MCP org. Only when a site needs clicking |
| `sqlite` on Oracle | ❌ Skip | Your databases are on the Mac |

🏆 **For web research, prefer your own SearXNG + Crawl4AI tools over a `fetch` MCP
server** ([11](11-web-research.md)). Two small schemas cost fewer tokens than a
whole server's set, and Crawl4AI's Markdown output is better for a model to read.

---

## Native server-side MCP — a different route

Two providers can connect to a **remote** MCP server themselves, so OpenClaw
doesn't run the loop at all.

| Provider | Support | ⚠️ Caveat |
|---|---|---|
| **Anthropic** | `mcp_servers` parameter + a beta header | **Remote URL only.** Not on Bedrock or Vertex |
| **Google Gemini** | `type: "mcp_server"` with a `url`. Streamable HTTP, not SSE | Remote only |

Since you already pay for Gemini, this is directly usable for hosted servers.

🚨 **But test whether it survives LiteLLM.** Your config has `drop_params: true`,
which discards parameters LiteLLM doesn't recognise. If `mcp_servers` gets
dropped, the model just answers without tools and **nothing errors** — you'd never
notice.

⚠️ Research found this behaviour **NOT DOCUMENTED**. Test it:

1. Call the provider directly with `mcp_servers`. Confirm the tool gets used.
2. Call the same thing through LiteLLM. Compare.
3. If it silently stops working, that's `drop_params`.

---

## Coding MCP is separate

Claude Code is its own MCP client on your **Mac**, configured in `~/.claude.json`
or a project `.mcp.json`. Those servers are for coding — filesystem, git, your
project's database.

**Nothing to do with OpenClaw's servers on Oracle.** Different client, different
machine, different config file. Don't try to share them.

---

## The catalogue prompt

Run this and save the output as `08a-mcp-catalogue.md`.

```
You are writing one file of a build guide. Produce a current, accurate catalogue
of Model Context Protocol servers worth using, plus answers to the specific
questions below.

RULES — follow exactly:
- Use ONLY the official MCP specification site (modelcontextprotocol.io), the
  modelcontextprotocol GitHub organisation, Anthropic's official documentation,
  Google's Gemini API documentation, and the first-party repository of any server
  you list. No blogs, no "awesome-mcp" lists, no aggregators.
- For every server: give the exact package name, who maintains it, whether it is
  stdio or remote-URL or both, and roughly how many tools it exposes. Get the
  tool count from its README or its tools/list output — if you cannot, write
  UNKNOWN.
- If a server is archived or unmaintained, say so prominently.
- If something is not documented, write NOT DOCUMENTED. Do not guess.
- Output GitHub-flavoured markdown ready to save as a file. Simple English.

MY CONTEXT:
- MCP servers run as subprocesses of OpenClaw on an Oracle Ubuntu ARM VM, or as
  remote URLs. They CANNOT reach my MacBook — that is handled by a separate job
  queue, deliberately.
- I care intensely about token cost, because tool schemas are sent on every
  request and I use free tiers with daily token caps.
- I am in India. I use Gemini (paid and free) and Claude via API.

SECTIONS TO WRITE:

1. OFFICIAL REFERENCE SERVERS
   Everything currently in the modelcontextprotocol/servers repository. For each:
   package name, purpose, stdio or remote, approximate tool count, and whether it
   is actively maintained or archived. Flag the archived ones clearly.

2. SERVERS FOR MY SPECIFIC USES
   For each of these, name the best-maintained option and say who maintains it:
   a. Fetching and reading a web page as clean text
   b. Web search
   c. Reading and writing files on the VM itself
   d. Querying a SQLite database
   e. Browser automation (clicking, forms, login)
   f. GitHub
   g. Google Drive or Google Docs
   If a hosted remote-URL version exists (so I do not have to run a subprocess),
   say so and give the URL.

3. TOKEN COST — the section I care most about
   a. For each server in section 2, estimate the total tokens its tool schemas
      add to a single request. Show your working: number of tools × approximate
      schema size. If you cannot estimate, write UNKNOWN rather than guessing.
   b. Does any official source publish a per-tool token figure? If not, say
      NOT PUBLISHED.
   c. Which servers in section 2 support restricting which tools are exposed —
      through a command-line flag, config option, or scope argument? Give the
      exact syntax. This is the single most useful thing you can tell me.

4. ANTHROPIC SERVER-SIDE MCP
   a. The current beta header value
   b. A complete working request example
   c. Confirm: remote URL servers only, or local stdio too?
   d. Which platforms support it — Anthropic API, Bedrock, Vertex, Foundry,
      Claude Platform on AWS

5. GOOGLE GEMINI NATIVE MCP
   a. Exact parameter shape, with a complete working example
   b. Which transports are supported (Streamable HTTP, SSE, other)
   c. Which Gemini models support it
   d. Whether it works on the free tier or only paid

6. ANTHROPIC TOOL SEARCH
   a. Current tool type strings
   b. How defer_loading works and what its constraints are
   c. Any published figure for how much it reduces prompt tokens

7. PROMPT CACHING AND TOOLS
   Confirm from official docs that tool definitions are part of the cacheable
   prefix, exactly what invalidates that cache, and the minimum cacheable prefix
   size per model.

8. LITELLM AS AN MCP GATEWAY
   Read docs.litellm.ai/docs/mcp. Can LiteLLM itself register and serve MCP
   servers to clients, acting as a central gateway? If yes, explain how and what
   version added it. If no, say so plainly. Also: does LiteLLM forward an
   "mcp_servers" request parameter through to Anthropic or Gemini, and does the
   "drop_params: true" setting discard it?

At the very end, add "STILL NOT DOCUMENTED" listing everything you could not
answer, with the exact page or command I should check myself.
```

---

## ⚠️ Verify with AI

| # | Unverified | Answered by |
|---|---|---|
| 1 | Which official servers exist and are maintained | The catalogue prompt above, §1 |
| 2 | Tool counts and token cost per server | §2, §3 |
| 3 | Which servers support tool filtering | §3c — **the most useful answer** |
| 4 | Anthropic MCP connector current beta header | §4 |
| 5 | Gemini native MCP exact syntax and model support | §5 |
| 6 | Tool search current strings and constraints | §6 |
| 7 | Whether LiteLLM is an MCP gateway now | §8 |
| 8 | Whether `drop_params` eats `mcp_servers` | §8 — test it yourself too |
| 9 | Whether OpenClaw can scope servers per profile | [07](07-openclaw.md)'s prompt, §7b |

**The architecture in this file needs no verification** — where servers can run is
determined by how subprocesses and networks work, not by any provider's docs.

---

Next: [09 — Reels](09-reels.md)
