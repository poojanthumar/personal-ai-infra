# 03 — VM and Hosting

**Goal:** something that is always awake, so your automations still run when
your MacBook lid is shut, and your phone always has something to talk to.

**Time:** 1–2 hours.

**Cost:** ₹0 for Phase 1 and 2. ₹250–400 for Phase 3 if you ever need it.

---

## The problem, and why it is easy to solve

Your MacBook sleeps and moves between networks. Your home internet almost
certainly does not give you a fixed public address — most Indian ISPs (Jio
especially) put you behind a shared address, so there is no port to forward.

The fix is to **reverse the direction**. Your Mac always *reaches out*. Nothing
ever reaches *in*.

```
Phone  ──▶  VM (public address)  ◀──  Mac (asks for work)
```

The VM has a public address by definition, because you rented it. So the Mac
can always reach it. The Mac does not need any address of its own.

Three consequences, all good:

- No port forwarding, no router settings, no fixed IP needed.
- Your changing IP address does not matter at all.
- A sleeping Mac means jobs **wait in a queue** instead of failing.

---

## Three phases — do not skip to Phase 3

| Phase | What | Cost | Do this when |
|---|---|---|---|
| **1** | Everything on the Mac + Tailscale | **₹0** | **Now.** Prove the whole system works |
| **2** | Cloudflare Worker or Oracle free box takes over the always-on parts | **₹0** | When you get annoyed that 9am jobs don't run |
| **3** | Small Indian VM | **₹250–400** | When you want a real Linux box you fully control |

---

# PHASE 1 — Mac only, with Tailscale (₹0)

Tailscale creates a small private network between your devices. It works
through shared-IP internet because both devices dial *out* to a coordination
server, which then helps them connect directly to each other.

The important part: **each device gets a permanent private address** (like
`100.101.102.103`) that never changes, even when your real IP does, even when
you switch from home wifi to mobile data.

## Step 1 — Install on the Mac

```bash
brew install --cask tailscale
```

Open the Tailscale app, sign in (Google or GitHub account is fine), and enable
it.

Find your Mac's permanent address:

```bash
tailscale ip -4
```

Write this down. Example: `100.101.102.103`. This is now your Mac's address
forever.

## Step 2 — Install on your phone

Install Tailscale from the App Store, sign in with the same account. Done.

## Step 3 — Test from your phone

Make LiteLLM listen on all addresses instead of just localhost. Edit the
launch plist from file 02 and add `--host 0.0.0.0` to the command, then:

```bash
launchctl unload ~/Library/LaunchAgents/com.poojan.litellm.plist
launchctl load ~/Library/LaunchAgents/com.poojan.litellm.plist
```

On your phone's browser, visit:

```
http://100.101.102.103:4000/health/readiness
```

If you see a response, your phone can now reach your Mac from anywhere in the
world. No public exposure — only devices signed into your Tailscale account can
see it.

## Step 4 — Stop the Mac sleeping during jobs

```bash
# Keep awake while a specific job runs
caffeinate -s python3 my_long_job.py

# Or keep awake whenever plugged in (System Settings > Lock Screen >
# "Prevent automatic sleeping on power adapter when the display is off")
```

**What Phase 1 gives you:** everything works, from anywhere, for ₹0.
**What it does not give you:** jobs scheduled for 9am do not run if the lid was
shut at 9am.

---

# PHASE 2A — Cloudflare Workers (₹0, recommended)

🏆 **This is my recommendation for Phase 2.** No server to patch, no operating
system to update, genuinely free at your scale.

⚠️ Free tier is roughly 100,000 requests/day plus free D1 (database) and KV
(key-value store) allowances. Far more than you need.

## What lives here

| Piece | Cloudflare product |
|---|---|
| Telegram webhook receiver | Worker |
| Job queue | D1 (SQL database) or KV |
| Heartbeat store ("is the Mac awake?") | KV |
| Scheduled triggers (9am, nightly) | Cron Triggers |

## Step 1 — Install the tool

```bash
npm install -g wrangler
wrangler login
```

## Step 2 — Create the project

```bash
mkdir -p ~/Documents/Code/ai-hub-worker
cd ~/Documents/Code/ai-hub-worker
wrangler init . --yes
```

## Step 3 — Create the job queue database

```bash
wrangler d1 create ai-hub
```

It prints a database ID. Put it in `wrangler.toml`:

```toml
name = "ai-hub"
main = "src/index.js"
compatibility_date = "2026-01-01"

[[d1_databases]]
binding = "DB"
database_name = "ai-hub"
database_id = "paste-the-id-here"

[triggers]
crons = ["0 3 * * *"]   # 3am UTC = 8:30am India — nightly photo scoring
```

## Step 4 — Create the tables

Save as `schema.sql`:

```sql
CREATE TABLE IF NOT EXISTS jobs (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  type        TEXT NOT NULL,       -- rank_media, reel_render, music_sync
  payload     TEXT NOT NULL,       -- JSON string with the details
  status      TEXT NOT NULL DEFAULT 'queued',   -- queued|running|done|failed
  result      TEXT,
  reply_to    TEXT,                -- Telegram chat id to answer
  created_at  TEXT NOT NULL,
  claimed_at  TEXT,
  finished_at TEXT
);

CREATE INDEX IF NOT EXISTS idx_jobs_status ON jobs(status, id);

CREATE TABLE IF NOT EXISTS heartbeat (
  worker    TEXT PRIMARY KEY,
  last_seen TEXT NOT NULL
);
```

Apply it:

```bash
wrangler d1 execute ai-hub --file=schema.sql --remote
```

## Step 5 — Write the Worker

Save as `src/index.js`:

```js
// Shared secret so only your Mac can claim jobs.
// Set it with: wrangler secret put WORKER_TOKEN
function authorised(request, env) {
  return request.headers.get("x-worker-token") === env.WORKER_TOKEN;
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    // --- Mac asks for the next job -------------------------------------
    if (url.pathname === "/jobs/next" && request.method === "GET") {
      if (!authorised(request, env)) return new Response("no", { status: 401 });

      const job = await env.DB.prepare(
        "SELECT * FROM jobs WHERE status='queued' ORDER BY id LIMIT 1"
      ).first();

      if (!job) return Response.json({ job: null });

      await env.DB.prepare(
        "UPDATE jobs SET status='running', claimed_at=? WHERE id=?"
      ).bind(new Date().toISOString(), job.id).run();

      return Response.json({ job });
    }

    // --- Mac returns the result ----------------------------------------
    if (url.pathname === "/jobs/result" && request.method === "POST") {
      if (!authorised(request, env)) return new Response("no", { status: 401 });

      const { id, status, result } = await request.json();
      await env.DB.prepare(
        "UPDATE jobs SET status=?, result=?, finished_at=? WHERE id=?"
      ).bind(status, JSON.stringify(result), new Date().toISOString(), id).run();

      return Response.json({ ok: true });
    }

    // --- Mac says "I am awake" -----------------------------------------
    if (url.pathname === "/heartbeat" && request.method === "POST") {
      if (!authorised(request, env)) return new Response("no", { status: 401 });

      await env.DB.prepare(
        "INSERT INTO heartbeat (worker,last_seen) VALUES ('mac',?) " +
        "ON CONFLICT(worker) DO UPDATE SET last_seen=excluded.last_seen"
      ).bind(new Date().toISOString()).run();

      return Response.json({ ok: true });
    }

    // --- Anything adds a job (Telegram handler calls this) -------------
    if (url.pathname === "/jobs" && request.method === "POST") {
      if (!authorised(request, env)) return new Response("no", { status: 401 });

      const { type, payload, reply_to } = await request.json();
      const r = await env.DB.prepare(
        "INSERT INTO jobs (type,payload,reply_to,created_at) VALUES (?,?,?,?)"
      ).bind(type, JSON.stringify(payload), reply_to || null,
             new Date().toISOString()).run();

      return Response.json({ id: r.meta.last_row_id });
    }

    return new Response("ai-hub ok");
  },

  // Runs on the cron schedule in wrangler.toml
  async scheduled(event, env) {
    await env.DB.prepare(
      "INSERT INTO jobs (type,payload,created_at) VALUES ('rank_media',?,?)"
    ).bind(JSON.stringify({ path: "Photos/Inbox" }),
           new Date().toISOString()).run();
  },
};
```

## Step 6 — Deploy

```bash
# Make up a long random secret
python3 -c "import secrets; print(secrets.token_urlsafe(32))"

wrangler secret put WORKER_TOKEN     # paste it when asked
wrangler deploy
```

It prints your URL, something like `https://ai-hub.yourname.workers.dev`.

## Step 7 — Test it

```bash
HUB="https://ai-hub.yourname.workers.dev"
TOK="your-worker-token"

# Add a job
curl -s -X POST $HUB/jobs -H "x-worker-token: $TOK" \
  -H "Content-Type: application/json" \
  -d '{"type":"rank_media","payload":{"path":"Photos/Test"}}'

# Pretend to be the Mac and claim it
curl -s $HUB/jobs/next -H "x-worker-token: $TOK"

# Return a result (use the id from the first command)
curl -s -X POST $HUB/jobs/result -H "x-worker-token: $TOK" \
  -H "Content-Type: application/json" \
  -d '{"id":1,"status":"done","result":{"scored":42}}'
```

**Note what did not happen:** the Worker never touched a file. It moved a text
string called `path` around. Only the Mac gives that string meaning.

---

# PHASE 2B — Oracle Cloud Always Free (₹0, alternative)

Choose this instead of Cloudflare if you want a full Linux machine.

**What you get:** ⚠️ up to 4 ARM cores, 24 GB RAM, 200 GB disk, free forever.
That is more memory than your MacBook.

**Warnings:**
- ⚠️ Capacity in Mumbai and Hyderabad is often unavailable. Keep retrying, or
  pick a different region.
- ⚠️ They reclaim instances that stay under about 20% CPU for a week. Running
  n8n and LiteLLM usually keeps you above that, but check occasionally.
- ⚠️ Indian credit cards sometimes fail their verification step.

## Setup

1. Sign up at cloud.oracle.com. Choose an Indian region if it lets you.
2. Create instance → shape **VM.Standard.A1.Flex** → 4 cores, 24 GB.
3. Image: **Ubuntu 22.04** or newer.
4. Download the SSH private key when offered. You cannot get it later.
5. Connect: `ssh -i ~/Downloads/key.pem ubuntu@YOUR_PUBLIC_IP`

## Prepare the box

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y docker.io docker-compose-v2 postgresql-client
sudo usermod -aG docker $USER
# log out and back in

# Oracle blocks ports by default at the OS level too
sudo iptables -I INPUT -p tcp --dport 4000 -j ACCEPT   # LiteLLM
sudo iptables -I INPUT -p tcp --dport 8080 -j ACCEPT   # Open WebUI
sudo apt install -y iptables-persistent    # save the rules
```

Also open the same ports in Oracle's web console under **Networking →
Virtual Cloud Network → Security Lists**. Both layers must allow it.

## Put it on Tailscale too

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
tailscale ip -4
```

Now the safest setup: **close the public ports again** and reach everything
over Tailscale only. Nothing of yours is exposed to the internet.

## A small model on the free box

Because you have 24 GB, the VM can run a small model itself for cheap routing
decisions without waking your Mac:

```bash
curl -fsSL https://ollama.com/install.sh | sh
ollama pull qwen3:4b
```

⚠️ Expect around 10–15 tokens/sec on ARM cores. Fine for sorting and
classifying, too slow for conversation.

---

# PHASE 3 — Paid VM (₹250–400/month)

Only if you want a real box and Oracle did not work out.

| Provider | ⚠️ ₹/month | Region | Notes |
|---|---|---|---|
| **Utho** | 250–400 | India | 🏆 Billed in rupees, no forex charge |
| **E2E Networks** | 300–500 | India | Indian, well established |
| AWS Lightsail | 310–440 | Mumbai | Free for 12 months first |
| DigitalOcean | 350–530 | Bangalore | Reliable |
| Hetzner ARM | 300–360 | Germany | Cheapest, but ~150 ms extra delay |
| RackNerd | 80–150 | US | Cheapest if paid yearly |

**Size to buy:** 1–2 GB RAM is enough. n8n + LiteLLM + Postgres all fit.
**Do not buy 8 GB "for the model"** — the model is not going there.

Setup is the same as Oracle above: Docker, Tailscale, close public ports.

---

## Six ways to keep hosting near ₹0

1. **Don't rent one.** Cloudflare Worker + your Mac. This is the real answer at
   your scale.
2. **Oracle Always Free.** ₹0 forever, big enough for a small model too.
3. **Right-size.** The always-on parts need 1–2 GB, not 8.
4. **Pay yearly** on a budget host: ₹80–150/month effective.
5. **Bill in rupees** with an Indian provider — saves the 3–5% forex markup.
6. **Choose ARM** — consistently cheaper per GB than Intel/AMD.

---

## Troubleshooting

| Problem | Cause | Fix |
|---|---|---|
| Can't reach VM port from outside | Two firewalls | Open it in the cloud console **and** in `iptables` |
| Tailscale connects but is slow | Direct connection failed, using a relay | Normal, still works. Latency is fine for this |
| Oracle instance disappeared | Reclaimed for being idle | Recreate; keep some load on it |
| "Out of capacity" on Oracle | Region full | Retry over several days, or change region |
| Mac stops asking for jobs after sleep | Poll loop died with the sleep | Use the retry loop in file 06 |
| Cron fired but nothing happened | Mac asleep | Correct behaviour — the job waits in the queue |

---

## Prompt for AI

```
Write a bash script called hub_check.sh that verifies my job queue is working.

It takes two environment variables:
  HUB_URL     e.g. https://ai-hub.example.workers.dev
  WORKER_TOKEN

Steps it performs, printing PASS or FAIL for each with a short reason:

1. GET $HUB_URL/ — expect HTTP 200
2. POST $HUB_URL/jobs with header "x-worker-token: $WORKER_TOKEN" and body
   {"type":"selftest","payload":{"note":"hub_check"}}
   Expect HTTP 200 and a JSON field called "id". Save that id.
3. GET $HUB_URL/jobs/next with the same header.
   Expect HTTP 200 and a job whose type is "selftest".
4. POST $HUB_URL/jobs/result with the same header and body
   {"id":<saved id>,"status":"done","result":{"ok":true}}
   Expect HTTP 200.
5. POST $HUB_URL/heartbeat with the same header. Expect HTTP 200.

Rules:
- Use curl and the jq command for reading JSON.
- Exit with code 0 only if every step passed, otherwise 1.
- If either environment variable is missing, print a clear message and exit 2.
- Do not print the token anywhere in the output.
- Add a comment line above each step saying what it checks.
```

---

## Check you are done

**Phase 1:**
- [ ] `tailscale ip -4` gives a `100.x.y.z` address
- [ ] Phone can open `http://100.x.y.z:4000/health/readiness`
- [ ] Works on mobile data, not just home wifi

**Phase 2:**
- [ ] `curl $HUB/` responds
- [ ] Adding, claiming, and finishing a job all work
- [ ] Heartbeat endpoint works
- [ ] Cron trigger created a job overnight

---

Next: [04 — Open WebUI](04-openwebui.md)
