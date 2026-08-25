# 03 — Oracle VM and Hosting

> ⚠️ **Anything marked ⚠️ in this file is unverified.** All of it is answered
> by the prompt in [⚠️ Verify with AI](#-verify-with-ai) at the bottom — paste it
> into Gemini or any web-enabled AI and update this file with the result.

**Goal:** one always-on Linux box that runs your job queue, router, database and
messaging front door — so automations still run when your MacBook lid is shut.

**Time:** 2–3 hours.

**Cost:** ₹0 on Oracle Always Free. ₹250–500 if you fall back to a paid VM.

---

## Why Oracle and not Cloudflare Workers

An earlier version of this plan used Cloudflare Workers. **Oracle is the better
choice**, for two reasons that only became clear once the real limits were
checked:


|                                | Cloudflare Workers                  | Oracle Always Free         |
| ------------------------------ | ----------------------------------- | -------------------------- |
| CPU per request                | 🚨 **10 ms**                        | Unlimited                  |
| Persistent processes           | ❌ None                              | ✅ Yes                      |
| Can run LiteLLM, n8n, Postgres | ❌ No                                | ✅ Yes                      |
| **Can run OpenClaw**           | ❌ **No**                            | ✅ Yes                      |
| Cron jobs                      | ⚠️ 5 per account                    | Unlimited                  |
| Your data lives in             | D1 **and** Postgres — two databases | **One** Postgres           |
| Maintenance                    | None                                | You patch it               |
| Reliability                    | Very high                           | ⚠️ Capacity + reclaim risk |


The 10 ms CPU limit makes a Worker a doorbell, not a house. It can receive a
webhook and write a row — it can never host a database, an agent, or a scheduler.

**Cloudflare keeps exactly one job: Cloudflare Tunnel**, free, to give Oracle an
HTTPS address without opening any ports.

---



## The problem this solves

Your MacBook sleeps and moves between networks, and Indian ISPs mostly put you
behind a shared address — there is no port to forward.

**The fix is to reverse the direction.** Your Mac always reaches *out*. Nothing
ever reaches *in*.

```
Phone ──▶ Oracle (public address) ◀── Mac (asks for work)
```

Three consequences, all good:

- No port forwarding, no router settings, no fixed IP.
- Your changing IP is irrelevant.
- A sleeping Mac means jobs **wait in a queue** instead of failing.

---



## What runs where


| Oracle box                                       | Your Mac                          |
| ------------------------------------------------ | --------------------------------- |
| OpenClaw (WhatsApp front door)                   | **Ollama** serving your 12B model |
| LiteLLM (router, budgets, privacy gate)          | CLIP + aesthetic scorer           |
| **Postgres** — job queue, spend logs, dashboards | ffmpeg                            |
| All MCP servers (community + hosted)             | AppleScript, osxphotos            |
| SearXNG, Crawl4AI                                | The pull agent (outbound only)    |
| cron                                             | `index.sqlite`                    |
| Open WebUI (optional)                            | —                                 |


**Exposes to the network:** Oracle exposes an HTTPS front door.
Your Mac exposes **only Ollama on port 11434**, over Tailscale.

---



## Phases


| Phase | What                                                     | Cost     | Do this when                             |
| ----- | -------------------------------------------------------- | -------- | ---------------------------------------- |
| **1** | Everything on the Mac + Tailscale                        | **₹0**   | **Now.** Prove the ranker and reels work |
| **2** | Oracle box: Postgres + LiteLLM + queue API. Mac polls it | **₹0**   | When missed 9am jobs annoy you           |
| **3** | Add OpenClaw on Oracle                                   | **₹0**   | When you want WhatsApp                   |
| **4** | Paid Indian VM                                           | ₹250–500 | Only if Oracle proves unreliable         |


---



# PHASE 1 — Mac only, with Tailscale (₹0)

Tailscale builds a private network between your devices. It works behind
shared-IP internet because both machines dial *out* to a coordinator, which then
helps them connect directly.

**Each device gets a permanent private address** that never changes, even when
your real IP does.

```bash
brew install --cask tailscale
# open the app, sign in, enable it
tailscale ip -4        # write this down — e.g. 100.101.102.103
```

Install Tailscale on your phone with the same account.

⚠️ Device and user limits on the free plan could not be confirmed from
Tailscale's own pricing page, and there is no documented guarantee of a DERP
relay in India. Neither matters much — latency is a non-issue for this workload.

**Test it.** Make Ollama listen beyond localhost, then reach it from your phone:

```bash
launchctl setenv OLLAMA_HOST 0.0.0.0:11434
brew services restart ollama
# on your phone's browser:
#   http://100.101.102.103:11434/api/tags
```

**Keep the Mac awake during jobs:** `caffeinate -s python3 job.py`

---



# PHASE 2 — The Oracle box (₹0)



## Step 1 — Get an instance

🚨 **Try this before anything else.** Capacity is the one thing that can block
the whole plan, and you want to know now.

1. Sign up at cloud.oracle.com. Choose **Mumbai** or **Hyderabad**.
2. Create instance → shape **VM.Standard.A1.Flex**.
3. ⚠️ **The current Free Tier page states no more than 2 OCPUs and 12 GB RAM
  total** across A1 instances. Older docs said 4 cores / 24 GB — do not plan on
   that. Ask for 2 OCPU / 12 GB.
4. Image: **Ubuntu 22.04** or newer.
5. **Download the SSH private key when offered.** You cannot get it later.
6. Connect: `ssh -i ~/Downloads/key.pem ubuntu@YOUR_PUBLIC_IP`

⚠️ **Three known frictions:**

- Always Free A1 capacity is **not guaranteed in any region.** Expect to retry
over several days. "Out of capacity" is normal, not a mistake.
- The exact idle-reclamation thresholds are **not published.** Assume they exist;
running Postgres and LiteLLM should keep you above them.
- Oracle says most users need a **credit card** for verification. Indian
debit-card acceptance is not documented either way.

**If you cannot get an instance after a few days, skip to Phase 4.** Don't fight
it — 12 GB free is nice but not worth a week.

## Step 2 — Harden and join Tailscale

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y docker.io docker-compose-v2 postgresql-client \
                    python3-venv python3-pip
sudo usermod -aG docker $USER
# log out and back in

# Join Tailscale
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
tailscale ip -4         # note this — e.g. 100.90.80.70

# Automatic security updates
sudo apt install -y unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades
```

🏆 **Keep every public port closed.** Reach everything over Tailscale, and use
Cloudflare Tunnel (step 5) for the one thing that genuinely needs a public
address. Nothing of yours is then exposed to the internet.

⚠️ Oracle blocks ports at **two** layers — the OS `iptables` *and* the Security
List in their web console. If you ever do open one, you must do both.

## Step 3 — Postgres

One database for everything: job queue, LiteLLM spend logs, dashboard tables.

```bash
sudo apt install -y postgresql
sudo -u postgres createuser --createdb aihub
sudo -u postgres psql -c "ALTER USER aihub WITH PASSWORD 'pick-something-long';"
sudo -u postgres createdb -O aihub aihub
```

Let it listen on the Tailscale address only:

```bash
# /etc/postgresql/*/main/postgresql.conf
listen_addresses = 'localhost,100.90.80.70'

# /etc/postgresql/*/main/pg_hba.conf  — add:
host  all  aihub  100.64.0.0/10  scram-sha-256
```

```bash
sudo systemctl restart postgresql
```

`100.64.0.0/10` is Tailscale's address range, so only your own devices can
connect.

Create the tables:

```bash
psql "postgresql://aihub:PASSWORD@localhost/aihub" <<'SQL'

CREATE TABLE IF NOT EXISTS jobs (
  id          bigserial PRIMARY KEY,
  type        text NOT NULL,
  payload     jsonb NOT NULL DEFAULT '{}',
  status      text NOT NULL DEFAULT 'queued',   -- queued|running|done|failed
  result      jsonb,
  reply_to    text,                             -- chat id to answer
  created_at  timestamptz NOT NULL DEFAULT now(),
  claimed_at  timestamptz,
  finished_at timestamptz
);
CREATE INDEX IF NOT EXISTS idx_jobs_queued ON jobs (status, id);

CREATE TABLE IF NOT EXISTS heartbeat (
  worker    text PRIMARY KEY,
  last_seen timestamptz NOT NULL
);

-- Dashboard tables (file 12)
CREATE TABLE IF NOT EXISTS job_runs (
  id          bigserial PRIMARY KEY,
  job_type    text NOT NULL,
  status      text NOT NULL,
  items       int  DEFAULT 0,
  started_at  timestamptz NOT NULL,
  duration_ms int,
  llm_calls   int  DEFAULT 0,
  error       text
);
CREATE INDEX IF NOT EXISTS idx_job_runs_time ON job_runs (started_at DESC);
CREATE INDEX IF NOT EXISTS idx_job_runs_type ON job_runs (job_type, started_at DESC);

CREATE TABLE IF NOT EXISTS quota_usage (
  provider text NOT NULL, day date NOT NULL,
  requests int DEFAULT 0, tokens bigint DEFAULT 0,
  PRIMARY KEY (provider, day)
);

CREATE TABLE IF NOT EXISTS quota_limits (
  provider text PRIMARY KEY,
  daily_requests int, daily_tokens bigint, note text
);
SQL
```

⚠️ Leave `quota_limits` empty for now. Groq's free-tier numbers are **not
published** — read your own from console.groq.com and insert them.

## Step 4 — The queue API

This replaces the Cloudflare Worker. Save as `~/aihub/queue_api.py`:

```python
#!/usr/bin/env python3
"""
Job queue API. The Mac polls this; nothing connects into the Mac.

Endpoints:
  GET  /jobs/next      Mac claims the next queued job
  POST /jobs/result    Mac reports what happened
  POST /heartbeat      Mac says it is awake
  POST /jobs           anything adds a job
  GET  /jobs/{id}      check one job
  GET  /health
"""

import os
from datetime import datetime, timezone, timedelta
from typing import Optional

import psycopg2
import psycopg2.extras
from fastapi import FastAPI, Header, HTTPException
from pydantic import BaseModel

DSN   = os.environ["DATABASE_URL"]
TOKEN = os.environ["WORKER_TOKEN"]

app = FastAPI(title="aihub queue")


def db():
    """One short-lived connection per request. Simple and reliable at this scale."""
    return psycopg2.connect(DSN, cursor_factory=psycopg2.extras.RealDictCursor)


def check(token: Optional[str]):
    """Shared-secret auth. Only my Mac and my own tools know this."""
    if token != TOKEN:
        raise HTTPException(status_code=401, detail="bad token")


class NewJob(BaseModel):
    type: str
    payload: dict = {}
    reply_to: Optional[str] = None


class JobResult(BaseModel):
    id: int
    status: str
    result: dict = {}


@app.get("/health")
def health():
    return {"ok": True}


@app.get("/jobs/next")
def next_job(x_worker_token: str = Header(None)):
    """
    Claim one job atomically. FOR UPDATE SKIP LOCKED means two workers can
    never grab the same row.
    """
    check(x_worker_token)
    with db() as c, c.cursor() as cur:
        cur.execute("""
            UPDATE jobs SET status='running', claimed_at=now()
            WHERE id = (
              SELECT id FROM jobs WHERE status='queued'
              ORDER BY id LIMIT 1 FOR UPDATE SKIP LOCKED
            )
            RETURNING id, type, payload, reply_to
        """)
        row = cur.fetchone()
    return {"job": row}


@app.post("/jobs/result")
def job_result(r: JobResult, x_worker_token: str = Header(None)):
    check(x_worker_token)
    with db() as c, c.cursor() as cur:
        cur.execute("""
            UPDATE jobs SET status=%s, result=%s, finished_at=now() WHERE id=%s
        """, (r.status, psycopg2.extras.Json(r.result), r.id))
    return {"ok": True}


@app.post("/heartbeat")
def heartbeat(x_worker_token: str = Header(None)):
    """Lets the router skip local tiers instantly when the Mac is asleep."""
    check(x_worker_token)
    with db() as c, c.cursor() as cur:
        cur.execute("""
            INSERT INTO heartbeat (worker, last_seen) VALUES ('mac', now())
            ON CONFLICT (worker) DO UPDATE SET last_seen = now()
        """)
    return {"ok": True}


@app.post("/jobs")
def add_job(j: NewJob, x_worker_token: str = Header(None)):
    check(x_worker_token)
    with db() as c, c.cursor() as cur:
        cur.execute("""
            INSERT INTO jobs (type, payload, reply_to) VALUES (%s,%s,%s)
            RETURNING id
        """, (j.type, psycopg2.extras.Json(j.payload), j.reply_to))
        jid = cur.fetchone()["id"]
    return {"id": jid}


@app.get("/jobs/{job_id}")
def get_job(job_id: int, x_worker_token: str = Header(None)):
    check(x_worker_token)
    with db() as c, c.cursor() as cur:
        cur.execute("SELECT * FROM jobs WHERE id=%s", (job_id,))
        row = cur.fetchone()
    if not row:
        raise HTTPException(404, "no such job")
    return row


@app.post("/jobs/reclaim")
def reclaim(x_worker_token: str = Header(None)):
    """
    Put stuck jobs back. A job claimed over an hour ago means the Mac slept
    mid-job. Call this from cron.
    """
    check(x_worker_token)
    with db() as c, c.cursor() as cur:
        cur.execute("""
            UPDATE jobs SET status='queued', claimed_at=NULL
            WHERE status='running' AND claimed_at < now() - interval '1 hour'
            RETURNING id
        """)
        ids = [r["id"] for r in cur.fetchall()]
    return {"reclaimed": ids}
```

Install and run it:

```bash
mkdir -p ~/aihub && cd ~/aihub
python3 -m venv .venv && source .venv/bin/activate
pip install fastapi 'uvicorn[standard]' psycopg2-binary

cat > ~/aihub/.env <<'EOF'
DATABASE_URL=postgresql://aihub:PASSWORD@localhost/aihub
WORKER_TOKEN=Poojan@0907
EOF
chmod 600 ~/aihub/.env

# Generate the token
python3 -c "import secrets; print(secrets.token_urlsafe(32))"
```

As a service — `/etc/systemd/system/aihub-queue.service`:

```ini
[Unit]
Description=aihub queue API
After=network.target postgresql.service

[Service]
User=ubuntu
WorkingDirectory=/home/ubuntu/aihub
EnvironmentFile=/home/ubuntu/aihub/.env
ExecStart=/home/ubuntu/aihub/.venv/bin/uvicorn queue_api:app --host 127.0.0.1 --port 8000
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now aihub-queue
curl -s localhost:8000/health
```

Note `--host 127.0.0.1`. Nothing is public yet — Cloudflare Tunnel handles that.

## Step 5 — HTTPS front door via Cloudflare Tunnel

Gives you a real HTTPS URL with **no open ports**. `cloudflared` dials out, same
trick as Tailscale.

```bash
curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64 \
  -o cloudflared && chmod +x cloudflared && sudo mv cloudflared /usr/local/bin/

cloudflared tunnel login          # opens a browser link
cloudflared tunnel create aihub
```

`~/.cloudflared/config.yml`:

```yaml
tunnel: <the-tunnel-id-it-printed>
credentials-file: /home/ubuntu/.cloudflared/<tunnel-id>.json

ingress:
  - hostname: aihub.yourdomain.com
    service: http://localhost:8000
  - service: http_status:404
```

```bash
cloudflared tunnel route dns aihub aihub.yourdomain.com
sudo cloudflared service install
sudo systemctl enable --now cloudflared
```

⚠️ Needs a domain on Cloudflare. **If you don't have one:** skip the tunnel and
have the Mac reach the queue at Oracle's Tailscale address
(`http://100.90.80.70:8000`). Everything works. You only need a public HTTPS
address later, for WhatsApp webhooks in file 07.

## Step 6 — Cron

No 5-trigger limit here.

```bash
crontab -e
```

```cron
# Nightly photo scan — 8:30am IST
0 3 * * *  curl -s -X POST http://localhost:8000/jobs -H "x-worker-token: TOKEN" \
             -H 'Content-Type: application/json' \
             -d '{"type":"rank_media","payload":{"path":"Photos/Inbox"}}'

# Put stuck jobs back, hourly
7 * * * *  curl -s -X POST http://localhost:8000/jobs/reclaim -H "x-worker-token: TOKEN"

# Refresh free-tier counters (file 12)
*/5 * * * * cd /home/ubuntu/aihub && ./.venv/bin/python update_quotas.py
```



## Step 7 — Backups. Do not skip this.

Oracle can reclaim your instance. Treat the box as disposable and the data as
precious.

On the **Mac**, pull a dump nightly:

```bash
cat > ~/bin/backup-oracle.sh <<'EOF'
#!/bin/zsh
set -euo pipefail
DEST="$HOME/Backups/oracle"
mkdir -p "$DEST"
ssh -i ~/.ssh/oracle.pem ubuntu@100.90.80.70 \
  'pg_dump "postgresql://aihub:PASSWORD@localhost/aihub"' \
  | gzip > "$DEST/aihub-$(date +%F).sql.gz"
# keep 14 days
ls -1t "$DEST"/aihub-*.sql.gz | tail -n +15 | xargs -r rm
echo "backed up: $(ls -1t $DEST | head -1)"
EOF
chmod +x ~/bin/backup-oracle.sh
```

```bash
( crontab -l 2>/dev/null; echo "30 2 * * * $HOME/bin/backup-oracle.sh >> /tmp/oracle-backup.log 2>&1" ) | crontab -
```

**Also keep Phase 1 working.** If Oracle disappears, point the Mac agent at
`http://localhost:8000` with the queue API running locally and you are back in
minutes.

## Step 8 — Test the whole chain

```bash
export HUB=http://100.90.80.70:8000       # or your tunnel URL
export TOK=your-worker-token

curl -s $HUB/health
curl -s -X POST $HUB/jobs -H "x-worker-token: $TOK" \
  -H 'Content-Type: application/json' -d '{"type":"selftest","payload":{}}'
curl -s $HUB/jobs/next -H "x-worker-token: $TOK"
curl -s -X POST $HUB/jobs/result -H "x-worker-token: $TOK" \
  -H 'Content-Type: application/json' \
  -d '{"id":1,"status":"done","result":{"ok":true}}'
curl -s -X POST $HUB/heartbeat -H "x-worker-token: $TOK"
```

**Note what did not happen:** the queue never touched a file. It moved a text
string called `path`. Only your Mac gives that string meaning — see file 05.

---



# PHASE 4 — Paid VM (₹250–500/month)

Only if Oracle capacity never appears or you get reclaimed repeatedly.

⚠️ **No Indian provider's current pricing could be confirmed from an official
page.** Check each yourself before buying.


| Provider         | Region                                             | Where to look                     |
| ---------------- | -------------------------------------------------- | --------------------------------- |
| **Utho**         | India                                              | utho.com/pricing                  |
| **E2E Networks** | India                                              | e2enetworks.com/pricing           |
| AWS Lightsail    | Mumbai                                             | aws.amazon.com/lightsail/pricing  |
| DigitalOcean     | Bangalore — ⚠️ confirm availability in the console | digitalocean.com/pricing/droplets |
| Hetzner ARM      | Germany (~150 ms extra)                            | hetzner.com/cloud                 |


**Buy 1–2 GB RAM.** Postgres, LiteLLM and the queue API all fit. **Do not buy
8 GB "for the model"** — the model runs on your Mac. Indian providers bill in
rupees, avoiding the 3–5% forex markup.

Setup is identical to steps 2–8 above.

---



## Troubleshooting


| Problem                               | Cause                              | Fix                                                                          |
| ------------------------------------- | ---------------------------------- | ---------------------------------------------------------------------------- |
| "Out of capacity" on Oracle           | Region full                        | Normal. Retry over days, or change region                                    |
| Instance vanished                     | Reclaimed for idling               | Rebuild from your backup. Keep some load on it                               |
| Can't reach a port from outside       | Two firewalls                      | Open in `iptables` **and** the Oracle console. Better: don't — use Tailscale |
| Postgres refuses Tailscale connection | `listen_addresses` / `pg_hba.conf` | Add the Tailscale IP and `100.64.0.0/10`, then restart                       |
| Mac stops polling after sleep         | Loop died with the sleep           | `KeepAlive` plus the backoff in file 05 handles it                           |
| Cron fired, nothing happened          | Mac asleep                         | Correct behaviour — the job waits                                            |
| Job stuck at `running`                | Mac slept mid-job                  | The hourly `/jobs/reclaim` puts it back                                      |
| Tunnel returns 502                    | Queue API down                     | `sudo systemctl status aihub-queue`                                          |


---



## Prompt for AI

```
Write a bash script called hub_check.sh that verifies my job queue API.

It reads two environment variables:
  HUB_URL       e.g. https://aihub.example.com or http://100.90.80.70:8000
  WORKER_TOKEN

Steps, printing PASS or FAIL for each with a short reason:

1. GET $HUB_URL/health — expect HTTP 200 and a JSON field "ok" that is true
2. POST $HUB_URL/jobs with header "x-worker-token: $WORKER_TOKEN" and body
   {"type":"selftest","payload":{"note":"hub_check"}}
   Expect HTTP 200 and a JSON field "id". Save that id.
3. GET $HUB_URL/jobs/next with the same header.
   Expect HTTP 200 and a job whose "type" is "selftest".
4. POST $HUB_URL/jobs/result with the same header and body
   {"id":<saved id>,"status":"done","result":{"ok":true}}
   Expect HTTP 200.
5. GET $HUB_URL/jobs/<saved id> with the same header.
   Expect status to be "done".
6. POST $HUB_URL/heartbeat with the same header. Expect HTTP 200.

Rules:
- Use curl and jq.
- Exit 0 only if every step passed, otherwise 1.
- If either environment variable is missing, print which one and exit 2.
- Never print the token.
- Add a comment above each step saying what it checks.
```

---



## Check you are done

**Phase 1:**

- [ ] `tailscale ip -4` gives a `100.x.y.z` address on Mac and phone
- [ ] Phone can reach Ollama on the Mac over Tailscale, on mobile data

**Phase 2:**

- [ ] Oracle instance running, reachable by SSH
- [ ] Oracle has a Tailscale address
- [ ] No public ports open
- [ ] Postgres has all five tables
- [ ] `/health` responds
- [ ] Add → claim → result → heartbeat all work
- [ ] `aihub-queue` survives a reboot
- [ ] Nightly `pg_dump` landing on your Mac
- [ ] Phase 1 still works as a fallback

---



## ✅ Verified 2 Aug 2026 — and it's better news than I implied


| #   | Finding                                                                                                                                                   | Impact                                                                                                                       |
| --- | --------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| 1   | **Reclamation needs ALL THREE simultaneously over 7 days:** 95th-percentile CPU <20%, network <20%, **and** memory <20%                                   | 🏆 **Postgres alone keeps memory above 20%.** Far less risky than I said                                                     |
| 2   | 🏆 **Pay-As-You-Go accounts get priority capacity allocation** over Always Free — while still using free-tier resources                                   | **The real workaround for the Mumbai shortage.** Add a card, stay inside free limits, pay ₹0                                 |
| 3   | Cards: *"credit cards and debit cards that function like credit cards. We do not accept debit cards with a PIN or virtual, single-use, or prepaid cards"* | An Indian international debit card with online transactions enabled should work. ⚠️ Community reports high 2FA failure rates |
| 4   | **Tailscale free: unlimited devices, up to 6 users, and a DERP relay in Bengaluru**                                                                       | ✅ Was NOT FOUND before. Latency will be fine                                                                                 |
| 5   | Cloudflare Quick Tunnels (`trycloudflare.com`) reset their URL on every restart                                                                           | ✅ Confirms: unsuitable for a long-running service. Use a domain, or Tailscale                                                |
| 6   | All Cloudflare free limits                                                                                                                                | ✅ Cross-verified identical across both passes                                                                                |




### ⚠️ Unresolved: how big is the free tier?


| Pass   | Said                                                   |
| ------ | ------------------------------------------------------ |
| First  | **2 OCPU / 12 GB** — "current Free Tier page"          |
| Second | **4 OCPU / 24 GB** — calls 2/12 "legacy documentation" |


They contradict each other in opposite directions. **Check your own tenancy
console** — it shows your actual limits. Either way it's enough: Postgres, LiteLLM,
the queue API and OpenClaw fit comfortably in 12 GB.

### 🚨 Both passes independently reached the same verdict

> *"Oracle Always Free is risky as a primary host for PostgreSQL due to severe
> region capacity shortages in India and aggressive idle reclamation; paying
> ₹350–500/month is significantly safer for data persistence and uptime."*

**Revised recommendation:**

1. 🏆 **Try Oracle, but upgrade the account to Pay-As-You-Go** — you get capacity
  priority and still pay ₹0 while inside free limits.
2. **Keep the nightly** `pg_dump` **to your Mac regardless** (step 7). Non-negotiable.
3. If capacity still won't come after a few days, go straight to Phase 4.

---



## ⚠️ Verify with AI


| #   | Unverified                                   | Why it matters                       |
| --- | -------------------------------------------- | ------------------------------------ |
| 1   | Oracle Always Free ARM allocation            | Docs conflict: 2/12 vs 4/24          |
| 2   | Whether Indian regions have A1 capacity      | 🚨 **This can block the whole plan** |
| 3   | Idle-reclamation thresholds                  | Decides how much load to keep on it  |
| 4   | Whether Indian debit cards pass verification | Decides if you can sign up at all    |
| 5   | Cloudflare Tunnel needing a domain           | Decides whether you need to buy one  |


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

1. Oracle Cloud Always Free, current allocation: exactly how many Ampere A1 OCPUs,
   how much RAM, and how much block storage. Quote the official Free Tier page. If
   older documentation says something different, say so and give both.
2. Is Always Free A1 capacity available in Oracle's Mumbai and Hyderabad regions
   right now? Official statements only for policy; you may cite the Oracle
   community forum for capacity reports but label it as community-reported.
3. Oracle's official idle-reclamation policy for Always Free compute: the exact
   CPU, network and memory thresholds and the time period that triggers
   reclamation. If not published, say NOT PUBLISHED.
4. Does Oracle accept Indian debit cards for Always Free account verification, or
   is a credit card required? Quote their own wording. Community-reported is fine
   if labelled.
5. Cloudflare Tunnel: do I need to own a domain on Cloudflare to get a public
   HTTPS hostname, or is there a free trycloudflare-style hostname suitable for a
   long-running service? Give the current limitations of each.
6. Cloudflare free tier limits today for: Workers requests/day, Worker CPU time
   per request, cron triggers per account, D1 rows read and written per day, D1
   storage, KV reads/writes/storage, Queues operations per day.
7. Tailscale personal/free plan: device limit, user limit, and whether DERP relay
   servers exist in India.

Output as: | # | Answer | Source URL | Page updated |
Then one line: based on this, is Oracle Always Free a sensible primary host for a
small PostgreSQL database, or should I pay for a VM instead?
```

---

Next: [04 — Open WebUI](A2-openwebui-optional.md) · or skip to
[15 — OpenClaw](07-openclaw.md) if WhatsApp is what you want