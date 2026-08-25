# 11 — Dashboard


> ⚠️ **Anything marked ⚠️ in this file is unverified.** All of it is answered
> by the prompt in [⚠️ Verify with AI](#-verify-with-ai) at the bottom — paste it
> into Gemini or any web-enabled AI and update this file with the result.

**Goal:** always be able to see how many requests you have made, how much money
you have spent, how much free quota is left, and what jobs ran.

**Time:** 1–2 hours.

**Cost:** ₹0.

---

## "Tokens left" means two different things

This is worth settling before you build anything, because only one of them
LiteLLM knows about.

| | What it is | Who tracks it |
|---|---|---|
| **Spending against your budget** | Paid APIs are metered. There is no quota — only the rupee ceiling *you* chose | ✅ LiteLLM does this already |
| **Free-tier quota** | Groq and Gemini have hard caps — but ⚠️ **neither publishes them**; they are account-specific | ❌ **You must count these yourself** |

Both need to be on the dashboard. If you only show spending, you will get
surprise "429 too many requests" errors from the free tiers while the money
chart still looks comfortable.

## And a third gap: work that never touches a model

Your photo ranker uses CLIP, not a language model. **LiteLLM never sees it.** So
on a night your Mac scored 5,000 photos, a LiteLLM-only dashboard shows *zero
activity* — exactly backwards.

So there are three sources of numbers:

| Source | Table | Records |
|---|---|---|
| LiteLLM | `LiteLLM_SpendLogs` | Every request that reached a model |
| Your Mac agent | `job_runs` | Every job, including free local ones |
| Your counter | `quota_usage` | Free-tier consumption per provider per day |

---

## Step 1 — What LiteLLM already gives you for free

No extra work needed for these dimensions:

| Dimension | Comes from | Example values |
|---|---|---|
| **Tier** | the `model` column | `tier0-local`, `tier1-free`, `tier2-cheap` |
| **Provider** | the resolved model string | `ollama`, `groq`, `gemini`, `deepseek` |
| **App** | the virtual key used | `telegram-key`, `openwebui-key`, `automation-key` |
| **Success or failure** | request status | for an error-rate tile |
| Tokens, cost, time taken | logged per request | — |

```sql
-- Requests per tier per day
SELECT date_trunc('day', "startTime") AS day,
       model,
       count(*) AS requests
FROM "LiteLLM_SpendLogs"
WHERE "startTime" > now() - interval '30 days'
GROUP BY 1, 2
ORDER BY 1;
```

⚠️ 🚨 **The spend-log schema is NOT a stable public contract.** LiteLLM's own docs
say column names change between releases and SQL should be written against the
schema shipped with your exact deployed version. Get yours before writing any
query:

```bash
# Find your version
litellm --version

# Pull the exact table definition for that tag
curl -sL https://raw.githubusercontent.com/BerriAI/litellm/v1.86.2/schema.prisma \
  | sed -n '/model LiteLLM_SpendLogs/,/^}/p'
```

Substitute your own version tag. Then confirm against your live database:

```bash
psql litellm -c "\dt"
psql litellm -c '\d "LiteLLM_SpendLogs"'
```

**Every SQL query in this file is written against `LiteLLM_SpendLogs` with
columns `startTime`, `model`, `spend`, and `total_tokens`.** If your version
names them differently, adjust — the queries are the pattern, not gospel.

---

## Step 2 — The one dimension LiteLLM cannot know

It has no idea whether a request was a reel plan or a chat reply. **Tag it at
the call site.** Every code example in these files already does this:

```python
requests.post(f"{LITELLM}/chat/completions",
    headers={"Authorization": f"Bearer {KEY}"},
    json={
        "model": "tier2-cheap",
        "messages": [...],
        "metadata": {"tags": ["job:reel_edl"]},     # ← this line
    })
```

✅ **Verified against v1.86.2 docs:** `metadata` is documented as an object for
arbitrary request metadata, and `tags` inside it is the documented field for
spend attribution. There is a dedicated docs page at
`docs.litellm.ai/docs/proxy/tag_tracking` — read it, because it also explains how
to query tags back out.

If tags behave oddly on your version, the fallback is the standard OpenAI `user`
field, which LiteLLM logs regardless:

```python
"user": "job:reel_edl"
```

Tags used across these files:

| Tag | Where from |
|---|---|
| `source:telegram` | appendix A1 |
| `job:caption_batch` | file 03 |
| `job:reel_edl` | file 09 |
| `job:name_events` | file 10 |
| `job:research` | file 11 |

---

## Step 3 — Tables for the other two sources

```bash
psql litellm <<'SQL'

-- Every job the Mac agent ran, whether or not a model was involved
CREATE TABLE IF NOT EXISTS job_runs (
  id           bigserial PRIMARY KEY,
  job_type     text NOT NULL,     -- rank_media, reel_render, group_events
  status       text NOT NULL,     -- ok | failed | skipped
  items        int  DEFAULT 0,    -- files processed
  started_at   timestamptz NOT NULL,
  duration_ms  int,
  llm_calls    int  DEFAULT 0,    -- 0 for pure-local jobs like CLIP scoring
  error        text
);
CREATE INDEX IF NOT EXISTS idx_job_runs_time ON job_runs (started_at DESC);
CREATE INDEX IF NOT EXISTS idx_job_runs_type ON job_runs (job_type, started_at DESC);

-- Free-tier consumption, one row per provider per day
CREATE TABLE IF NOT EXISTS quota_usage (
  provider  text NOT NULL,
  day       date NOT NULL,
  requests  int  DEFAULT 0,
  tokens    bigint DEFAULT 0,
  PRIMARY KEY (provider, day)
);

-- The published daily caps, so the dashboard can show a percentage
CREATE TABLE IF NOT EXISTS quota_limits (
  provider        text PRIMARY KEY,
  daily_requests  int,
  daily_tokens    bigint,
  note            text
);

-- 🚨 Leave these NULL until you read YOUR OWN numbers from each console.
-- Research confirmed Groq and Gemini do NOT publish free-tier limits — they are
-- account-specific. A guessed cap gives you a dashboard that lies.
INSERT INTO quota_limits (provider, daily_requests, daily_tokens, note) VALUES
  ('groq',       NULL, NULL, 'NOT PUBLISHED - read from console.groq.com'),
  ('gemini',     NULL, NULL, 'NOT PUBLISHED - account-specific. FREE TIER TRAINS ON YOUR DATA'),
  ('openrouter', 1000, NULL, 'verified: 50/day, 1000/day after a one-time $10 credit')
ON CONFLICT (provider) DO NOTHING;
-- Cerebras deliberately absent: no longer a standing free tier (now $5 credits,
-- 30-day expiry), so there is no daily cap to track.

SQL
```

---

## Step 4 — Have the Mac agent log its jobs

Add to `~/Documents/Code/aihub/agent.py` from file 05:

```python
import psycopg2   # pip install psycopg2-binary

PG_DSN = os.environ.get("DATABASE_URL", "")


def log_job_run(job_type, status, items=0, duration_ms=0,
                llm_calls=0, error=None, started_at=None):
    """
    Record what this job did, even if no AI model was involved.
    Never let a logging failure break the actual work.
    """
    if not PG_DSN:
        return
    try:
        with psycopg2.connect(PG_DSN) as c, c.cursor() as cur:
            cur.execute("""
                INSERT INTO job_runs
                (job_type, status, items, started_at, duration_ms, llm_calls, error)
                VALUES (%s,%s,%s,%s,%s,%s,%s)
            """, (job_type, status, items,
                  started_at or datetime.now(timezone.utc),
                  duration_ms, llm_calls, error))
    except Exception as e:
        print(f"could not log job run: {e}", flush=True)
```

Then wire it into `run_one`:

```python
def run_one(job):
    job_id, jtype = job["id"], job["type"]
    payload = json.loads(job["payload"]) if isinstance(job["payload"], str) \
              else (job["payload"] or {})
    reply_to = job.get("reply_to")
    started = time.time()
    started_at = datetime.now(timezone.utc)

    handler = HANDLERS.get(jtype)
    if not handler:
        send_result(job_id, "failed", {"error": f"unknown job type: {jtype}"})
        log_job_run(jtype, "failed", error="unknown job type",
                    started_at=started_at)
        return

    try:
        result = handler(payload)
        ms = int((time.time() - started) * 1000)
        result["seconds"] = round(ms / 1000, 1)
        send_result(job_id, "done", result)

        log_job_run(jtype, "ok",
                    items=result.get("scored") or result.get("tracks") or 0,
                    duration_ms=ms,
                    llm_calls=result.get("llm_calls", 0),
                    started_at=started_at)

        notify(reply_to, f"Job #{job_id} ({jtype}) done in {result['seconds']}s")

    except Exception as e:
        ms = int((time.time() - started) * 1000)
        msg = f"{type(e).__name__}: {e}"
        send_result(job_id, "failed", {"error": msg})
        log_job_run(jtype, "failed", duration_ms=ms, error=msg[:500],
                    started_at=started_at)
        notify(reply_to, f"Job #{job_id} ({jtype}) failed:\n{msg}")
```

---

## Step 5 — Count free-tier usage

Simplest reliable approach: read it out of LiteLLM's own logs every few minutes,
rather than trying to hook into LiteLLM's callback system (which varies by
version).

Save as `~/Documents/Code/aihub/update_quotas.py`:

```python
#!/usr/bin/env python3
"""
Roll today's LiteLLM requests up into the quota_usage table, per provider.
Run every 5 minutes from cron.
"""

import os, psycopg2

DSN = os.environ["DATABASE_URL"]

# ⚠️ Adjust the column names to match your LiteLLM version
SQL = """
INSERT INTO quota_usage (provider, day, requests, tokens)
SELECT
  CASE
    WHEN model LIKE '%groq%'     OR model LIKE '%llama-3.3%' THEN 'groq'
    WHEN model LIKE '%cerebras%'                             THEN 'cerebras'
    WHEN model LIKE '%gemini%'                               THEN 'gemini'
    WHEN model LIKE '%openrouter%'                           THEN 'openrouter'
    ELSE 'other'
  END                                    AS provider,
  ("startTime" AT TIME ZONE 'Asia/Kolkata')::date AS day,
  COUNT(*)                               AS requests,
  COALESCE(SUM("total_tokens"), 0)       AS tokens
FROM "LiteLLM_SpendLogs"
WHERE ("startTime" AT TIME ZONE 'Asia/Kolkata')::date
      = (now() AT TIME ZONE 'Asia/Kolkata')::date
GROUP BY 1, 2
ON CONFLICT (provider, day) DO UPDATE
  SET requests = excluded.requests,
      tokens   = excluded.tokens;
"""

with psycopg2.connect(DSN) as c, c.cursor() as cur:
    cur.execute(SQL)
    print("quota_usage updated")
```

**Note the timezone.** Most providers reset quota at midnight UTC, but you think
in India time. Pick one and be consistent — the query above uses India time,
which matches how you will read the dashboard. ⚠️ If you hit unexpected limits,
switch it to UTC to match the provider's reset.

Run it every 5 minutes:

```bash
( crontab -l 2>/dev/null; \
  echo "*/5 * * * * cd $HOME/Documents/Code/aihub && \
/bin/zsh -lc 'source ~/.venvs/aihub/bin/activate && \
set -a && source ~/.config/aihub/.env && set +a && \
python update_quotas.py' >> /tmp/quotas.log 2>&1" ) | crontab -
```

---

## Step 6 — Panel layout

Pick the right shape for each number before worrying about colours. Some of
these should not be charts at all.

| Row | Panel | Shape | Why this shape |
|---|---|---|---|
| 1 | Spend this month vs ₹ cap · Requests today · Jobs today · Failures today | **Stat tiles** | Single headline numbers. A chart adds nothing |
| 2 | Requests by tier, last 30 days | **Stacked bar** by day | Change over time plus composition |
| 3 | Requests by job type, last 7 days | **Horizontal bar** | Ranked amounts with long labels |
| 4 | Groq / Gemini / Cerebras — % of daily cap | **Progress meters** | Amount measured against a known ceiling |
| 5 | Recent failures | **Table** | You need the error text, not a shape |

### One trap to avoid

**Never put request count and money spent on the same chart.** They are
different scales, and a chart with two different y-axes is the single most
misleading thing you can build — it lets you draw almost any story by changing
the scales. Use two charts side by side, or convert both to a percentage of
their own maximum. The same applies to "tokens and rupees".

Also: assign a fixed colour to each tier and never let it change. If a filter
removes `tier2-cheap` from the view, `tier1-free` must keep the colour it had.
Colour should follow the thing, never its position in the list.

---

## Step 7 — The queries

```sql
-- TILE: spend this month
SELECT ROUND(SUM(spend)::numeric * 88, 0) AS rupees_spent
FROM "LiteLLM_SpendLogs"
WHERE "startTime" >= date_trunc('month', now());

-- TILE: requests today
SELECT COUNT(*) FROM "LiteLLM_SpendLogs"
WHERE ("startTime" AT TIME ZONE 'Asia/Kolkata')::date
      = (now() AT TIME ZONE 'Asia/Kolkata')::date;

-- TILE: jobs today, and items processed
SELECT COUNT(*) AS jobs, COALESCE(SUM(items),0) AS items
FROM job_runs
WHERE (started_at AT TIME ZONE 'Asia/Kolkata')::date
      = (now() AT TIME ZONE 'Asia/Kolkata')::date;

-- TILE: failures today
SELECT
  (SELECT COUNT(*) FROM job_runs
   WHERE status='failed' AND started_at > now() - interval '1 day') AS job_failures;

-- CHART: requests by tier over time
SELECT date_trunc('day', "startTime") AS day, model, COUNT(*) AS requests
FROM "LiteLLM_SpendLogs"
WHERE "startTime" > now() - interval '30 days'
GROUP BY 1,2 ORDER BY 1;

-- CHART: jobs by type, last 7 days
SELECT job_type,
       COUNT(*)                                     AS runs,
       COALESCE(SUM(items),0)                       AS items,
       COUNT(*) FILTER (WHERE status='failed')      AS failures,
       ROUND(AVG(duration_ms)/1000.0, 1)            AS avg_seconds
FROM job_runs
WHERE started_at > now() - interval '7 days'
GROUP BY job_type ORDER BY runs DESC;

-- METERS: free-tier usage against the cap
SELECT u.provider,
       u.requests,
       l.daily_requests,
       ROUND(100.0 * u.requests / NULLIF(l.daily_requests,0), 1) AS pct_requests,
       u.tokens,
       l.daily_tokens,
       ROUND(100.0 * u.tokens / NULLIF(l.daily_tokens,0), 1)     AS pct_tokens
FROM quota_usage u
JOIN quota_limits l USING (provider)
WHERE u.day = (now() AT TIME ZONE 'Asia/Kolkata')::date;

-- TABLE: recent failures
SELECT started_at, job_type, LEFT(error, 120) AS error
FROM job_runs WHERE status='failed'
ORDER BY started_at DESC LIMIT 20;
```

---

## Step 8 — Start with LiteLLM's own UI

Before building anything, check what you already have:

```
http://localhost:4000/ui
```

⚠️ Verify the path against your version. It gives you spend per key, budgets,
and a request log with no work at all. If that covers you, stop here and just
add the Telegram command in step 10.

---

## Step 9 — Grafana (optional)

```bash
docker run -d --name grafana \
  --restart unless-stopped \
  -p 3000:3000 \
  -v grafana-data:/var/lib/grafana \
  grafana/grafana-oss
```

Open http://localhost:3000 (login `admin` / `admin`, change it immediately).

**Add the data source:** Connections → Add → PostgreSQL.

| Field | Value |
|---|---|
| Host | `host.docker.internal:5432` (on Mac) |
| Database | `litellm` |
| User | your macOS username |
| TLS/SSL Mode | `disable` for local |

Then create a dashboard and add one panel per query from step 7, choosing the
shape from the table in step 6.

Reach it from your phone over Tailscale at `http://100.x.y.z:3000`.

---

## Step 10 — The version you will actually check daily

Replace the placeholder handlers in appendix A1:

```python
import psycopg2

def db_query(sql, params=()):
    """Run one read-only query and return the rows."""
    with psycopg2.connect(os.environ["DATABASE_URL"]) as c, c.cursor() as cur:
        cur.execute(sql, params)
        return cur.fetchall()


async def cmd_stats(update, ctx):
    if not mine(update):
        return

    reqs = db_query("""
        SELECT model, COUNT(*) FROM "LiteLLM_SpendLogs"
        WHERE ("startTime" AT TIME ZONE 'Asia/Kolkata')::date
              = (now() AT TIME ZONE 'Asia/Kolkata')::date
        GROUP BY model ORDER BY 2 DESC
    """)

    jobs = db_query("""
        SELECT job_type, COUNT(*), COALESCE(SUM(items),0)
        FROM job_runs
        WHERE (started_at AT TIME ZONE 'Asia/Kolkata')::date
              = (now() AT TIME ZONE 'Asia/Kolkata')::date
        GROUP BY job_type ORDER BY 2 DESC
    """)

    fails = db_query("""
        SELECT COUNT(*) FROM job_runs
        WHERE status='failed' AND started_at > now() - interval '1 day'
    """)

    quota = db_query("""
        SELECT u.provider,
               ROUND(100.0*u.requests/NULLIF(l.daily_requests,0),0),
               ROUND(100.0*u.tokens/NULLIF(l.daily_tokens,0),0)
        FROM quota_usage u JOIN quota_limits l USING (provider)
        WHERE u.day = (now() AT TIME ZONE 'Asia/Kolkata')::date
    """)

    spend = db_query("""
        SELECT ROUND(SUM(spend)::numeric * 88, 0) FROM "LiteLLM_SpendLogs"
        WHERE "startTime" >= date_trunc('month', now())
    """)

    total_reqs = sum(n for _, n in reqs)
    lines = [
        "TODAY",
        f"  requests   {total_reqs}",
    ]
    for model, n in reqs[:4]:
        lines.append(f"    {model:16} {n}")

    lines.append(f"  jobs       {sum(n for _, n, _ in jobs)}")
    for jt, n, items in jobs:
        lines.append(f"    {jt:16} {n} runs, {items} items")

    lines += [f"  failures   {fails[0][0] if fails else 0}", "", "MONTH",
              f"  spend      ₹{spend[0][0] or 0} of ₹500"]

    if quota:
        lines.append("")
        lines.append("FREE QUOTA USED TODAY")
        for prov, pr, pt in quota:
            bits = []
            if pr is not None:
                bits.append(f"{pr}% requests")
            if pt is not None:
                bits.append(f"{pt}% tokens")
            lines.append(f"  {prov:12} {' · '.join(bits) or 'no cap set'}")

    await update.message.reply_text("```\n" + "\n".join(lines) + "\n```",
                                    parse_mode="Markdown")


async def cmd_budget(update, ctx):
    """Just the money, for a quick glance."""
    if not mine(update):
        return
    rows = db_query("""
        SELECT ROUND(SUM(spend)::numeric*88,0) FROM "LiteLLM_SpendLogs"
        WHERE "startTime" >= date_trunc('month', now())
    """)
    spent = rows[0][0] or 0
    cap = 500
    bar_len = 20
    filled = min(bar_len, int(bar_len * spent / cap))
    bar = "█" * filled + "░" * (bar_len - filled)
    await update.message.reply_text(
        f"₹{spent} of ₹{cap} this month\n`{bar}` {round(100*spent/cap)}%",
        parse_mode="Markdown")
```

Example output:

```
TODAY
  requests   142
    tier0-local      118
    tier1-free        19
    tier2-cheap        5
  jobs       4
    rank_media       2 runs, 1240 items
    reel_render      1 runs, 0 items
    group_events     1 runs, 94 items
  failures   0

MONTH
  spend      ₹340 of ₹500

FREE QUOTA USED TODAY
  groq         14% requests · 62% tokens
  gemini       18% requests
```

**Build this before Grafana.** Four rows in Telegram get read every day. A
Grafana board gets opened when something already looks wrong.

---

## Troubleshooting

| Problem | Cause | Fix |
|---|---|---|
| `LiteLLM_SpendLogs` does not exist | Table name differs by version | `psql litellm -c "\dt"` and adjust the queries |
| Spend always zero | Local models genuinely cost ₹0 | Correct. Check with a paid tier request |
| Job counts zero but jobs did run | `DATABASE_URL` missing in the agent's env | Add it to `~/.config/aihub/.env` |
| Grafana cannot connect | Wrong host from inside Docker | Use `host.docker.internal:5432` on Mac |
| Quota percentages over 100% | Your cap numbers are wrong | Update `quota_limits` from the provider's docs |
| Quota resets at the wrong time | Timezone mismatch with the provider | Switch the query to UTC |
| `/stats` times out | Query too slow | Add the indexes from step 3 |

---

## Prompt for AI

```
Write a Python script called quota_report.py.

It connects to PostgreSQL using the DATABASE_URL environment variable and
prints a plain-text report about free-tier API usage.

Tables that already exist:
  quota_usage(provider TEXT, day DATE, requests INT, tokens BIGINT)
  quota_limits(provider TEXT PRIMARY KEY, daily_requests INT, daily_tokens BIGINT, note TEXT)

Note: daily_requests or daily_tokens may be NULL, meaning that provider has no
published cap for that measure. Handle NULL without crashing.

What it prints:
1. A heading with today's date in India time (Asia/Kolkata).
2. For each provider that has a row in quota_usage for today, one block:
     provider name
     requests: 420 of 14000 (3%)
     tokens: 310000 of 500000 (62%)  [WARNING if over 80%]
   If a cap is NULL, print "no published cap" instead of the numbers and
   percentage for that line.
3. A section called "LAST 7 DAYS" showing, for each provider, the highest
   single-day percentage reached for requests and for tokens over the last
   seven days. This tells me which cap I am closest to hitting regularly.
4. At the very end, one line: either
     "All providers under 80% today."
   or
     "AT RISK: groq, gemini"
   listing every provider over 80% on either measure today.

Rules:
- Use psycopg2. Parameterised queries only, never string formatting for SQL.
- Exit with code 1 if any provider is over 80%, otherwise 0. This lets me run
  it from cron and get an alert.
- Handle the case where quota_usage has no rows for today: print
  "No usage recorded today." and exit 0.
- Add a comment above each of the four sections saying what it does.
- No command-line arguments.
```

---

## Check you are done

- [ ] `job_runs`, `quota_usage`, `quota_limits` tables exist
- [ ] The Mac agent writes a row to `job_runs` for every job
- [ ] `update_quotas.py` runs every 5 minutes and fills `quota_usage`
- [ ] LiteLLM's own UI opens and shows spend per key
- [ ] `/stats` in Telegram returns real numbers
- [ ] `/budget` shows a progress bar
- [ ] A free-tier percentage moves when you make requests
- [ ] Grafana reachable from your phone (if you built it)

---

## ⚠️ Verify with AI

| # | Unverified | Why it matters |
|---|---|---|
| 1 | LiteLLM spend-log columns for your version | 🚨 Every SQL query here depends on them |
| 2 | Your own Groq and Gemini free-tier caps | The quota meters are meaningless without them |
| 3 | Whether `metadata.tags` is queryable in SQL | Decides how per-job-type counting works |
| 4 | Grafana Postgres connection from Docker | `host.docker.internal` is Mac-only

Paste this into Gemini or any web-enabled AI, then update this file with what comes back.

```
RULES — follow exactly:
- Use ONLY docs.litellm.ai and the BerriAI/litellm repository, each AI provider's
  own rate-limit documentation, and the official Grafana documentation. No blogs.
- Give the source URL and version for every answer.
- If something is not documented, write NOT DOCUMENTED.

I am building a dashboard over LiteLLM's PostgreSQL logs plus two tables of my
own, showing money spent this month, requests per tier, jobs run, and how much
free-tier quota is left.

1. For the current stable LiteLLM: the exact spend-log table name and every
   column with its type. Give the command to extract it from schema.prisma for a
   specific version tag.
2. Is there a stable documented view or API endpoint for spend reporting that I
   should use INSTEAD of querying tables directly? If yes, give the endpoint and
   response shape — I would rather not depend on an internal schema.
3. When I send `metadata: {"tags": [...]}` with a request, where does it end up in
   PostgreSQL? Which column, and what shape? Give a working SQL example that
   counts requests grouped by tag. Read the tag_tracking docs page.
4. Are per-key and per-tag spend figures available through the API rather than
   raw SQL? Give the endpoints.
5. GROQ: are free-tier requests-per-minute, requests-per-day or tokens-per-day
   limits published on any official page, or only visible in the console? If
   published, give them per model. Do response headers report remaining quota? If
   so, which headers?
6. GEMINI API free tier: same questions. Which headers report remaining quota?
7. Confirm again, with the exact quote and URL: does the Gemini FREE tier use
   request data to improve Google products, and does the PAID tier not?
8. Grafana in Docker connecting to PostgreSQL on the host: the officially
   recommended host address on Linux (host.docker.internal does not work there).
   Give the recommended approach.

Output as: | # | Answer | Source URL | Version |
Then a section: "SQL I should change", listing any query in my plan that would
break on the current schema.
```

---

Next: [12 — Web crawling](11-web-research.md)
