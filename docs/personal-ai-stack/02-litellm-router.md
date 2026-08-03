# 02 — LiteLLM Router

**Goal:** one address that every app talks to, which then picks the right AI
model, keeps your spending inside a hard limit, and logs everything.

**Time:** about 1 hour.

**Cost:** ₹0 (the software is free).

---

## What LiteLLM is, and what it is not

| It does | It does not |
|---|---|
| Take a request in OpenAI format | Read your files |
| Send it to any of 100+ providers | Run tools or commands |
| Fall back to another model if one fails | Understand a folder path |
| Enforce a monthly spending cap | Store documents |
| Log every request for your dashboard | Think or decide anything |

**LiteLLM is a post office, not an assistant.** It moves messages. Everything
about files and folders is handled by the Mac agent (file 06).

---

## Two copies, one database

You run **two** LiteLLM instances:

| Copy | Runs on | Serves | First choice |
|---|---|---|---|
| **Mac copy** | Your MacBook | The Mac agent's local jobs | `localhost:11434` (Ollama) |
| **VM copy** | The VM | Telegram, Open WebUI, your phone | Cloud models |

**Why two?** If the Mac agent needs your local Gemma model, and it asked the
VM, the request would travel Mac → VM → Mac. Slow and fragile. The Mac copy
talks to Ollama directly.

They both write to **one shared Postgres database**, so your spending dashboard
still shows a single combined total.

Start with just the Mac copy. Add the VM copy in Phase 2.

---

## Step 1 — Install

```bash
brew install python@3.12
python3.12 -m venv ~/.venvs/litellm
source ~/.venvs/litellm/bin/activate

pip install 'litellm[proxy]'
litellm --version
```

---

## Step 2 — Get your API keys

Collect these now. All the free ones are genuinely free — no card needed.

| Provider | Where to get the key | Free? |
|---|---|---|
| **Groq** | console.groq.com | ✅ Yes, generous |
| **Cerebras** | cloud.cerebras.ai | ✅ Yes, generous |
| **Gemini** | aistudio.google.com/apikey | ✅ Yes — but see warning below |
| DeepSeek | platform.deepseek.com | Paid, very cheap. ~₹450 minimum top-up |
| Anthropic | console.anthropic.com | Paid, prepaid credit |

🚨 **Gemini's free tier may use your data to train Google's products.** Never
put it anywhere personal data can reach. See the privacy gate below.

Store the keys in a file that is never shared:

```bash
mkdir -p ~/.config/litellm
cat > ~/.config/litellm/.env <<'EOF'
GROQ_API_KEY=paste_here
CEREBRAS_API_KEY=paste_here
GEMINI_API_KEY=paste_here
DEEPSEEK_API_KEY=paste_here
ANTHROPIC_API_KEY=paste_here
EOF

chmod 600 ~/.config/litellm/.env
```

Add `.env` to any `.gitignore` if this folder is ever a git repository.

---

## Step 3 — Write the config

This is the important file. Save as `~/.config/litellm/config.yaml`.

⚠️ **LiteLLM's config format changes between versions.** Compare this against
https://docs.litellm.ai before trusting it. If the proxy refuses to start, the
error message will name the bad key.

```yaml
model_list:

  # ---- TIER 0: Local on your Mac. Free, private, unlimited. ----
  - model_name: tier0-local
    litellm_params:
      model: ollama/qwen3:8b
      api_base: http://localhost:11434
      timeout: 8          # fail fast so fallback is quick
      num_retries: 0

  # ---- TIER 1: Free cloud. Personal-data-safe providers only. ----
  - model_name: tier1-free
    litellm_params:
      model: groq/llama-3.3-70b-versatile
      api_key: os.environ/GROQ_API_KEY
  - model_name: tier1-free
    litellm_params:
      model: cerebras/llama3.1-70b
      api_key: os.environ/CEREBRAS_API_KEY

  # ---- TIER 1-PUBLIC: Gemini free. Public research ONLY.
  #      Google may train on this data. Never send personal data here. ----
  - model_name: tier1-public-only
    litellm_params:
      model: gemini/gemini-flash-latest
      api_key: os.environ/GEMINI_API_KEY

  # ---- TIER 2: Cheap paid. About ₹28 per million tokens. ----
  - model_name: tier2-cheap
    litellm_params:
      model: deepseek/deepseek-chat
      api_key: os.environ/DEEPSEEK_API_KEY

  # ---- TIER 3: Premium. Hard reasoning and coding only. ----
  - model_name: tier3-smart
    litellm_params:
      model: anthropic/claude-opus-5
      api_key: os.environ/ANTHROPIC_API_KEY

  # ---- PRIVACY GATE: no fallback on purpose. ----
  # Photos, personal notes, private context. If the Mac is unreachable,
  # the job goes back on the queue instead of leaking to the cloud.
  - model_name: private-local
    litellm_params:
      model: ollama/gemma3:4b
      api_base: http://localhost:11434
      timeout: 600        # batch jobs are allowed to take a long time
      num_retries: 0

router_settings:
  fallbacks:
    - tier0-local: [tier1-free, tier2-cheap]
    - tier1-free:  [tier2-cheap]
    - tier2-cheap: [tier3-smart]
    # private-local and tier1-public-only are deliberately absent.
    # private-local must never escalate to the cloud.
  allowed_fails: 1
  cooldown_time: 60       # seconds to skip a provider after it fails

litellm_settings:
  max_budget: 6           # US dollars per month. HARD STOP.
  budget_duration: 30d
  drop_params: true       # ignore parameters a provider doesn't support

general_settings:
  master_key: os.environ/LITELLM_MASTER_KEY
  database_url: os.environ/DATABASE_URL
```

⚠️ Model IDs like `groq/llama-3.3-70b-versatile` and `cerebras/llama3.1-70b`
change as providers retire models. If one returns a 404, check the provider's
current model list.

**The most important lines in this file** are the missing ones:
`private-local` has no fallback. That single omission is what stops your
personal photos being sent to Google on a night your Mac happens to be asleep.

---

## Step 4 — Set up the database

The database is what makes your dashboard possible. Without it, LiteLLM works
but remembers nothing.

```bash
brew install postgresql@16
brew services start postgresql@16

createdb litellm
```

Add to your `.env`:

```bash
cat >> ~/.config/litellm/.env <<'EOF'
DATABASE_URL=postgresql://localhost:5432/litellm
LITELLM_MASTER_KEY=sk-make-up-a-long-random-string-here
EOF
```

Generate a real random master key rather than typing something:

```bash
python3 -c "import secrets; print('sk-' + secrets.token_urlsafe(32))"
```

---

## Step 5 — Start it

```bash
source ~/.venvs/litellm/bin/activate
set -a; source ~/.config/litellm/.env; set +a

litellm --config ~/.config/litellm/config.yaml --port 4000
```

`set -a` makes the variables visible to LiteLLM. Without it you will get
"missing API key" errors even though the file is correct.

Watch the startup log. It lists every model it loaded. Any model missing from
that list has a config problem.

---

## Step 6 — Test each tier

Open a second Terminal window.

```bash
KEY="sk-your-master-key"

# Local — should be fast and free
curl -s http://localhost:4000/v1/chat/completions \
  -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" \
  -d '{"model":"tier0-local","messages":[{"role":"user","content":"Say OK."}]}' | head -c 400

# Free cloud
curl -s http://localhost:4000/v1/chat/completions \
  -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" \
  -d '{"model":"tier1-free","messages":[{"role":"user","content":"Say OK."}]}' | head -c 400
```

**Now test the fallback, which is the part most likely to be broken:**

```bash
# Stop Ollama so the local tier fails
brew services stop ollama

# This should still answer — via tier1-free
curl -s http://localhost:4000/v1/chat/completions \
  -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" \
  -d '{"model":"tier0-local","messages":[{"role":"user","content":"Say OK."}]}' | head -c 400

# This should FAIL — private-local has no fallback. Failure here is CORRECT.
curl -s http://localhost:4000/v1/chat/completions \
  -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" \
  -d '{"model":"private-local","messages":[{"role":"user","content":"Say OK."}]}' | head -c 400

brew services start ollama
```

If `private-local` answered while Ollama was stopped, your privacy gate is
broken. Check that `private-local` is not listed under `fallbacks`.

---

## Step 7 — Create one key per app

Never give your master key to an app. Make a separate key for each, each with
its own budget. This is what makes your dashboard show *which* app spent money.

```bash
create_key () {
  curl -s http://localhost:4000/key/generate \
    -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" \
    -d "{\"key_alias\":\"$1\",\"max_budget\":$2,\"budget_duration\":\"30d\"}"
  echo
}

create_key telegram   1
create_key openwebui  2
create_key automation 1
create_key coding     2
```

⚠️ Verify the endpoint path and field names against current docs — this API has
changed before. Save each returned key somewhere safe; they are shown once.

---

## Step 8 — Run it automatically on the Mac

Create `~/Library/LaunchAgents/com.poojan.litellm.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.poojan.litellm</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/zsh</string>
    <string>-lc</string>
    <string>source ~/.venvs/litellm/bin/activate &amp;&amp; set -a &amp;&amp; source ~/.config/litellm/.env &amp;&amp; set +a &amp;&amp; exec litellm --config ~/.config/litellm/config.yaml --port 4000</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardOutPath</key><string>/tmp/litellm.log</string>
  <key>StandardErrorPath</key><string>/tmp/litellm.err</string>
</dict>
</plist>
```

Load it:

```bash
launchctl load ~/Library/LaunchAgents/com.poojan.litellm.plist

# Check it came up
sleep 5 && curl -s http://localhost:4000/health/readiness && tail -5 /tmp/litellm.err
```

---

## Step 9 — Point your tools at it

```bash
# For OpenAI-compatible tools
export OPENAI_BASE_URL=http://localhost:4000/v1
export OPENAI_API_KEY=sk-your-app-key

# ⚠️ For Claude Code via LiteLLM's Anthropic-format endpoint — verify the path
export ANTHROPIC_BASE_URL=http://localhost:4000
export ANTHROPIC_AUTH_TOKEN=sk-your-coding-key
```

From your phone over Tailscale, replace `localhost` with your Mac's Tailscale
address (`100.x.y.z`).

---

## Cost controls to turn on

| Control | How | Saving |
|---|---|---|
| **Prompt caching** | Mark the repeated part of your prompt as cacheable | Cached part costs ~1/10th |
| **Batch API** | Send overnight jobs as a batch | **50% off** |
| **Effort setting** | `"effort": "medium"` on Claude Opus 5 | Large reduction in tokens |
| **Hard budget** | `max_budget: 6` in the config | Requests fail instead of overspending |
| **Per-app budgets** | Step 7 | Contains any runaway app |

Caching minimum size: **512 tokens** on Opus 5, 1,024 on Sonnet 5, 4,096 on
Haiku 4.5. Shorter prompts silently do not cache.

---

## Troubleshooting

| Problem | Cause | Fix |
|---|---|---|
| Starts, then "missing API key" | Env vars not exported | Use `set -a; source .env; set +a` |
| A model is missing from startup log | Bad `model_name` or provider prefix | Check the provider's current model list |
| Fallback never fires | Timeout too high, or model in a fallback loop | Set `timeout: 8` and `num_retries: 0` on tier 0 |
| `private-local` answers with Ollama off | Privacy gate broken | Remove it from `fallbacks` |
| Spending not recorded | `database_url` not set | Check step 4 |
| Works locally, not from phone | Bound to localhost only | Add `--host 0.0.0.0`, and rely on Tailscale for security |
| Slow first request every time | Ollama unloaded the model | Set `OLLAMA_KEEP_ALIVE=24h` (file 01, step 5) |

---

## Prompt for AI

A good narrow task — testing a config you already have.

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

## Check you are done

- [ ] All five model groups appear in the startup log
- [ ] `tier0-local`, `tier1-free`, `tier2-cheap` all return an answer
- [ ] With Ollama stopped, `tier0-local` still answers (fallback works)
- [ ] With Ollama stopped, `private-local` **fails** (privacy gate works)
- [ ] One key per app created, each with its own budget
- [ ] Restarts automatically after a reboot
- [ ] Spending appears in the LiteLLM UI at `http://localhost:4000/ui` (⚠️ verify path)

---

Next: [03 — VM and hosting](03-vm-hosting.md)
