# 13 — AI Prompts

Every copy-paste prompt from these documents, plus the rules that make them work
on Gemini Pro/Flash and Composer rather than only on frontier models.

---

## Part 1 — How to hand work to a weaker model

### The five rules

**1. One file, one job.** "Write `rate_photos.py` that does X" works. "Build the
photo system" does not. If the answer needs more than about 200 lines, split it.

**2. Show the shape of the answer.** Weak models guess formats badly. Give them
the exact output you want:

```
Print a table with these exact columns:
MODEL | SECONDS | OUTPUT_TOKENS | TOKENS_PER_SEC
```

Not: "print a nice summary".

**3. Never trust configuration it writes from memory.** This is the biggest
source of wasted time. Tool config formats — LiteLLM YAML, Docker Compose,
Grafana JSON, Immich settings — change often, and models confidently produce
last year's format.

> Ask AI for **code**. Look up **config** in the real docs.

If you must ask for config, add: *"Add a comment on every line saying what it
does, and list which version of the tool this format applies to."* Then check
those claims.

**4. Tell it what NOT to do.** Weak models add unrequested features. Always end
with restrictions:

```
- Do not add any command-line options I did not ask for.
- Do not add logging, retry logic, or a config file.
- Do not rewrite existing functions. Only give me the new code.
```

**5. Make mistakes visible.** *"Put a one-line comment above each function
saying what it does"* costs nothing and lets you spot wrong logic in seconds
without reading the code closely.

### Which model for which task

| Task | Gemini Flash | Gemini Pro | Composer | Notes |
|---|---|---|---|---|
| Small utility script with a clear spec | ✅ Good | ✅ Good | ✅ Good | Ideal for all three |
| SQL schema from a description | ✅ | ✅ | ✅ | Very reliable |
| pytest tests for a function you describe | ⚠️ OK | ✅ Good | ✅ Good | Pro is noticeably better |
| AppleScript | ⚠️ Weak | ⚠️ OK | ⚠️ OK | Less training data. Expect to fix it |
| ffmpeg command from a description | ⚠️ Often wrong flags | ⚠️ OK | ⚠️ OK | **Always test before trusting** |
| Explaining an error message | ✅ | ✅ | ✅ | Good use of a cheap model |
| Refactoring across many files | ❌ | ⚠️ | ⚠️ | Use Claude/GLM for this |
| Designing architecture | ❌ | ❌ | ❌ | Don't. That is what these documents are |
| Tool config (LiteLLM, Docker) | ❌ | ❌ | ❌ | Read the docs instead |

### A template that works

```
Write a [language] [file type] called [exact filename].

Purpose: [one sentence]

Inputs: [each one, with type and where it comes from]

What it does:
1. [step]
2. [step]
...

Output format: [exact shape — show it]

Edge cases it must handle:
- [case] → [what to do]

Rules:
- [restriction]
- Add a one-line comment above each function saying what it does.
- Do not add anything I did not ask for.
```

---

## Part 2 — The prompts

Each is repeated here so you have them in one place. They also appear at the end
of their own file.

---

### 2.1 — Speed test for local models (file 01)

```
Write a Python script called bench_local.py.

What it does:
1. Reads a list of model names from a command-line argument, comma separated.
   Example: python bench_local.py qwen3:4b,qwen3:8b
2. For each model, sends this prompt to http://localhost:11434/v1/chat/completions
   using the requests library:
   "Write exactly 100 words about the ocean."
3. Measures how long the request took, and reads the number of output tokens
   from the response field usage.completion_tokens
4. Calculates tokens per second.
5. Prints a table with these exact columns:
   MODEL | SECONDS | OUTPUT_TOKENS | TOKENS_PER_SEC
6. If a model fails, print the model name and the word FAILED in the table
   instead of crashing, then continue to the next model.

Rules:
- Use only the standard library plus requests.
- Set the request timeout to 300 seconds.
- Add a short comment above each function saying what it does.
- Do not add any command-line options I did not ask for.
```

---

### 2.2 — Test the LiteLLM router (file 02)

```
Write a Python script called test_litellm.py that checks a LiteLLM proxy.

Inputs, from command-line arguments:
  --url      default http://localhost:4000
  --key      required, the API key to use

What it does:
1. Sends a chat completion request to {url}/v1/chat/completions for each of
   these model names, one at a time:
   tier0-local, tier1-free, tier2-cheap, private-local
2. The message body is always:
   {"model": "<name>", "messages": [{"role":"user","content":"Reply with only the word OK."}]}
3. Header: Authorization: Bearer <key>
4. For each model, record:
   - HTTP status code
   - how many seconds it took
   - the value of the "model" field in the response (this shows which real
     model actually answered, which reveals whether a fallback happened)
   - the first 60 characters of the reply text
5. Print a table with columns:
   REQUESTED | STATUS | SECONDS | ACTUALLY_ANSWERED | REPLY
6. If a request fails or times out, print FAILED in the STATUS column and keep
   going to the next model. Never crash.

Rules:
- Use only the standard library plus requests.
- Timeout each request at 120 seconds.
- Exit with code 1 if any model returned a status other than 200, otherwise 0.
- Put a one-line comment above each function saying what it does.
```

---

### 2.3 — Check the job queue (file 03)

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

### 2.4 — Open WebUI setup script (file 04)

```
Write a bash script called openwebui_setup.sh.

It must be safe to run more than once (idempotent).

Steps:
1. Read these environment variables. If any is missing, print which one and
   exit with code 2:
     LITELLM_URL   (example: http://host.docker.internal:4000/v1)
     LITELLM_KEY
2. Check that the docker command exists. If not, print a message and exit 1.
3. If a container named "openwebui" already exists, stop and remove it.
   Print a line saying it did so.
4. Create a docker volume called openwebui-data if it does not exist.
5. Run the open-webui container with:
     - name openwebui
     - restart policy unless-stopped
     - port 8080 mapped to 8080
     - volume openwebui-data mounted at /app/backend/data
     - environment variables OPENAI_API_BASE_URL, OPENAI_API_KEY, WEBUI_AUTH=true
     - image ghcr.io/open-webui/open-webui:main
6. Wait up to 60 seconds for http://localhost:8080 to return any HTTP response.
   Check once per 3 seconds. Print a dot each time you check.
7. Print SUCCESS with the URL, or print FAILED and the last 20 lines of
   "docker logs openwebui".

Rules:
- Use "set -euo pipefail" at the top.
- Never print the value of LITELLM_KEY.
- Add a comment above each step describing it.
```

---

### 2.5 — Extra Telegram commands (file 05)

```
Add three new commands to an existing python-telegram-bot script.

The script already has:
- a function mine(update) that returns True if the message is from the allowed chat
- a function ask_ai(prompt, model) that returns a string answer
- a function queue_job(job_type, payload, chat_id) that returns an integer job id
- handlers registered with app.add_handler(CommandHandler("name", func))

Write these three async handler functions in the same style as the existing ones:

1. cmd_summarise(update, ctx)
   - Takes the text after the command as a URL.
   - If there is no URL, reply: "Usage: /summarise https://example.com"
   - Calls queue_job("fetch_and_summarise", {"url": <the url>}, chat_id)
   - Replies: "Queued job #<id> to read and summarise that page."

2. cmd_albums(update, ctx)
   - Takes no arguments.
   - Calls queue_job("group_events", {}, chat_id)
   - Replies: "Queued job #<id> to group photos into events and name them."

3. cmd_transcribe(update, ctx)
   - Only works if the message is a reply to another message containing audio
     or a voice note. If it is not, reply:
     "Reply to a voice note or audio file with /transcribe"
   - Gets the file_id from the replied-to message and calls
     queue_job("transcribe", {"file_id": <file_id>}, chat_id)
   - Replies: "Queued job #<id> to transcribe that audio."

Rules:
- Every handler must start with: if not mine(update): return
- Wrap the queue_job call in try/except. On any error reply
  "Could not queue that job right now." and do not crash.
- Also give me the three app.add_handler lines to add.
- Do not rewrite any existing function. Only give me the new code.
- Put a one-line docstring at the top of each function.
```

---

### 2.6 — Tests for the path safety check (file 06)

**This is the most important prompt in the set.** The function it tests is what
stops a chat message reading your SSH keys.

```
Write a Python file called test_safe_path.py using pytest.

It tests this function, which you should import from a module called agent:

    safe_path(user_path: str) -> Path

Behaviour being tested:
- MEDIA_ROOT is a folder. Any path that resolves INSIDE it is allowed and
  returned as a resolved Path.
- Any path that resolves OUTSIDE it must raise ValueError.
- A path that does not exist must raise ValueError.

Write these tests:

1. A pytest fixture that creates a temporary folder using tmp_path, makes
   subfolders "Photos" and "Videos" inside it, creates a file
   "Photos/a.jpg", sets the environment variable MEDIA_ROOT to that temporary
   folder, and reloads the agent module so it picks up the new value.

2. Tests that MUST be allowed:
   - "Photos"
   - "Photos/a.jpg"
   - "Photos/../Videos"      (goes up but stays inside)

3. Tests that MUST raise ValueError:
   - "../etc"
   - "../../etc/passwd"
   - "/etc/passwd"
   - "~/.ssh"
   - "Photos/../../somewhere"
   - ""                       (empty string)
   - "Photos/does_not_exist"

4. A test that creates a symbolic link inside MEDIA_ROOT pointing to a folder
   OUTSIDE it, and confirms that passing the link's name raises ValueError.
   This is the most important test.

Rules:
- Use pytest.raises(ValueError) for the blocking cases.
- Give each test a name that describes what it checks, for example
  test_blocks_parent_directory_escape.
- Do not use mocks. Use real temporary folders.
- Add a one-line comment above each test group explaining the group.
```

---

### 2.7 — Photo rating tool (file 07)

```
Write a Python script called rate_photos.py. It is a small local web page for
rating photos quickly.

Setup:
- Uses Flask.
- Reads a SQLite database at ~/Media/index.sqlite.
- Photos live under ~/Media/ and the database column "path" is relative to that.

Database tables that already exist:
  media(id, path, final_score, is_best_of_group, caption)
  my_ratings(path TEXT PRIMARY KEY, rating INTEGER, rated_at TEXT)

Behaviour:
1. Route "/" shows ONE photo at a time. Pick a photo that:
   - has is_best_of_group = 1
   - does NOT already appear in my_ratings
   - chosen with ORDER BY RANDOM() LIMIT 1
2. The page shows:
   - the image, scaled to fit the window, maximum 800px tall
   - the file path as text
   - the caption if there is one
   - five buttons labelled 1, 2, 3, 4, 5
   - a "Skip" button
   - text showing how many photos have been rated so far, out of the total
     eligible
3. Clicking a number saves it to my_ratings with the current time, then loads
   the next photo. Skip loads the next photo without saving.
4. Keyboard shortcuts: pressing keys 1 to 5 does the same as the buttons.
   Pressing the spacebar skips.
5. Route "/img/<path>" serves the image file. It must reject any path that does
   not resolve to a location inside ~/Media — return HTTP 403 in that case.
   This is a security requirement, do not skip it.
6. When there are no unrated photos left, show the message
   "All done. You have rated N photos." and no buttons.

Rules:
- Single file. Use Flask's render_template_string, no separate template files.
- Bind to 127.0.0.1 port 5555 only. Never 0.0.0.0.
- Use parameterised SQL queries everywhere. Never build SQL with string
  formatting.
- Add a comment above each route saying what it does.
- Print the URL to open when the server starts.
```

---

### 2.8 — Beat-snapping for reels (file 08)

```
Write a Python function called snap_cuts_to_beats and its tests.

The function signature:

    snap_cuts_to_beats(cuts, beats, tolerance=0.25) -> list

Inputs:
- cuts: a list of dictionaries. Each has "in" and "out" as floats (seconds
  within the source clip). The LENGTH of a cut is out minus in.
- beats: a sorted list of floats. These are beat times measured from the start
  of the finished video, not from the start of any clip.
- tolerance: how far a boundary may be moved, in seconds.

What it must do:
1. Walk through the cuts in order, keeping a running total of elapsed time in
   the finished video, starting at 0.
2. For each cut, work out where its end would fall in the finished video
   (elapsed + length).
3. Find the beat time closest to that point.
4. If that beat is within tolerance, change the cut's "out" so the cut ends
   exactly on the beat. Keep "in" unchanged.
5. If no beat is within tolerance, leave the cut alone.
6. Never make a cut shorter than 0.5 seconds or longer than 6.0 seconds. If
   snapping would break that, leave the cut alone.
7. Return a NEW list. Do not modify the input list or its dictionaries.

Then write pytest tests covering:
- An empty beats list returns the cuts unchanged.
- A single cut whose end is 0.1s before a beat gets extended to the beat.
- A single cut whose nearest beat is 2s away is left alone.
- Snapping that would make a cut 0.3s long is refused, leaving it alone.
- The input list is not modified (check the original is still equal to a copy
  you made before calling).
- Three cuts in a row where the running total matters, so a bug in the elapsed
  time calculation would be caught.

Rules:
- Standard library only.
- Type hints on the function signature.
- One comment above each numbered step.
```

---

### 2.9 — Apple Music statistics (file 09)

⚠️ AppleScript is where weak models struggle most. Expect to fix the result.

```
Write an AppleScript file called music_stats.applescript.

It takes no arguments and returns a single block of text.

What it must gather from the Music application:
1. Total number of tracks in the library.
2. Total number of user playlists.
3. The name and artist of the 10 most played tracks, with their play counts.
4. The 5 genres with the most tracks, with the count for each.
5. How many tracks have a rating of 80 or higher (that is 4 stars or more).
6. How many tracks have never been played.

Output format — exactly this shape, as plain text:

  LIBRARY
  tracks: 1234
  playlists: 56

  TOP PLAYED
  1. Song Name — Artist Name (42 plays)
  2. ...

  TOP GENRES
  Rock: 300
  ...

  RATINGS
  four stars or more: 210
  never played: 450

Rules:
- Wrap every property read in a try block so one broken track cannot stop the
  whole script.
- Do not modify anything in the Music library. Read only.
- Use "library playlist 1" to reach all tracks.
- Add an AppleScript comment above each section explaining what it collects.
- Return the text with the "return" statement, do not use display dialog.
```

---

### 2.10 — Automatic event-gap tuning (file 10)

```
Write a Python function called suggest_time_gap and its tests.

Purpose: my photo grouping uses a fixed time gap of 8 hours to decide where one
event ends and the next begins. I want the gap chosen from the actual data
instead of guessed.

Signature:

    suggest_time_gap(timestamps: list[float], target_events: int) -> float

Inputs:
- timestamps: a list of photo times as seconds since the epoch, in any order.
- target_events: roughly how many events I want to end up with.

What it must do:
1. Sort the timestamps.
2. Work out the gap in hours between each consecutive pair.
3. Sort those gaps from largest to smallest.
4. To produce N events you need N-1 splits, so the answer is just below the
   (N-1)th largest gap. Return that gap value minus 0.01 hours.
5. Handle these edge cases:
   - Fewer than 2 timestamps: return 8.0 as a default.
   - target_events of 1 or less: return a very large number (999999.0) so
     nothing ever splits.
   - target_events larger than the number of gaps available: return the
     smallest gap minus 0.01, with a floor of 0.1.
6. Never return a negative number. The minimum returned value is 0.1.

Then write pytest tests covering:
- An empty list returns 8.0.
- A single timestamp returns 8.0.
- Four timestamps with one obvious large gap, asking for 2 events, returns a
  value that would produce exactly 2 groups.
- target_events of 1 returns 999999.0.
- target_events of 100 with only 5 timestamps returns at least 0.1.
- A test that builds 20 timestamps in 4 clear clusters and confirms that
  applying the returned gap actually produces 4 groups. Write a small helper
  inside the test file that does the grouping so you can check this.

Rules:
- Standard library only.
- Type hints on the signature.
- One comment above each numbered step.
```

---

### 2.11 — Free-tier quota report (file 11)

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

### 2.12 — Search result ranking (file 12)

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

## Part 3 — Prompts for maintenance

### 3.1 — Explain an error

Cheap and effective on any model.

```
I ran this command:

  [paste the command]

I got this error:

  [paste the full error, including the stack trace]

Context: macOS on Apple Silicon, Python 3.12 in a virtual environment.

Tell me:
1. What the error means, in one or two plain sentences.
2. The single most likely cause.
3. The exact command or code change that fixes it.
4. How I check afterwards that it is actually fixed.

Do not give me a list of five possible causes. Give me the most likely one. If
you genuinely cannot tell from the information given, tell me exactly what extra
output you need and the command that produces it.
```

### 3.2 — Review a script before you run it

```
Read this script and tell me only what is WRONG with it. Do not rewrite it, do
not praise it, do not suggest style improvements.

Check specifically for:
1. Anything that deletes, overwrites, or moves a file. List every one, with the
   line number and what it affects.
2. Any file path that comes from outside the script (an argument, an environment
   variable, a network request) and is used without being validated.
3. Any SQL built with string formatting instead of parameters.
4. Any secret, key, or token that would be printed to the screen or a log.
5. Any loop that could run forever.
6. Any network request with no timeout.

Format each finding as:
  LINE <number>: <what is wrong> → <the fix>

If you find nothing in a category, write "category N: nothing found". Do not
invent findings to fill it out.

[paste the script]
```

### 3.3 — Turn a document step into a script

```
I am following a setup guide. Turn this section into a single bash script I can
run.

Requirements:
- Safe to run more than once. Check whether each thing is already done before
  doing it, and print "already done: <thing>" when it is.
- Stop at the first real failure with a clear message saying which step failed.
- Print "STEP n/N: <description>" before each step.
- At the end, run a check that proves it worked, and print PASS or FAIL.
- Never print the value of any variable whose name contains KEY, TOKEN,
  SECRET, or PASSWORD.
- Use "set -euo pipefail".
- Add a comment above each step.

Do not add steps that are not in the section below. Do not add error recovery
or retries unless the section mentions them.

Here is the section:

[paste it]
```

### 3.4 — Check a price or limit that I flagged

Pair this with the research tool from file 12.

```
Find the current official price or limit for: [the thing]

Requirements:
- Use only the provider's own website or official documentation. No blog posts,
  no news articles, no aggregator sites.
- Give me the figure, the exact page URL it came from, and the date the page was
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

---

## Part 4 — What to never ask AI for

| Do not ask | Why | Do this instead |
|---|---|---|
| LiteLLM `config.yaml` | Format changes often, models produce old versions | Copy from file 02, verify at docs.litellm.ai |
| Docker Compose for Immich | Same problem, and Immich changes fast | Download their official file |
| Grafana dashboard JSON | Huge, version-specific, unverifiable by eye | Build panels in the UI |
| "Design my AI architecture" | Too open-ended; you get generic advice | These documents |
| "What is the cheapest AI API" | Prices change weekly; models are out of date | Research tool (file 12) with official sources only |
| ffmpeg commands for anything unusual | Flags are subtly wrong very often | Copy from file 08, test on one file first |
| Anything touching your work code | Data goes to a third party | Your work Claude Code setup only |

---

## Part 5 — A workflow that works

1. **Read the file** in this folder for what you are building.
2. **Copy the code** given there. It is written for your setup.
3. **Where a prompt is offered,** paste it into Gemini or Composer to generate
   the extra tool.
4. **Before running generated code,** use prompt 3.2 to check it for anything
   destructive.
5. **When something breaks,** use prompt 3.1 with the full error.
6. **When you hit a ⚠️ mark,** use prompt 3.4 with the research tool to get the
   current figure, then update the document yourself.

Keeping these files updated as you learn things is worth the two minutes. In six
months the ⚠️ marks will be the only part that has gone stale.

---

Back to: [README](README.md) · [Decisions and costs](00-decisions-and-costs.md)
