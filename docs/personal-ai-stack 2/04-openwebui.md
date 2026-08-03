# 04 — Open WebUI

**Goal:** a proper chat interface that works in a browser and installs on your
phone like an app. This is where you sit down and work through something,
upload documents, and compare models.

**Time:** about 45 minutes.

**Cost:** ₹0.

---

## What it does, and what it does not

| Open WebUI handles | LiteLLM handles |
|---|---|
| The chat interface | Choosing which model answers |
| Conversation history | Budgets and spending limits |
| **File uploads and document search** | Falling back when a model fails |
| Phone app install (PWA) | Logging for your dashboard |
| Comparing two models side by side | Talking to the actual providers |

**This is how "give the AI a file" works:** you upload a PDF to Open WebUI, it
splits the text into chunks and stores them, then sends only the relevant text
chunks through LiteLLM. LiteLLM never sees the file. The model never sees the
file. They only ever see text.

⚠️ This works for **documents**. It does not work for a folder of videos — see
file 06 and 07 for that.

---

## Step 1 — Install Docker

**On the Mac:**

```bash
brew install --cask docker
open -a Docker      # let it finish starting
docker --version
```

**On a VM:** already done in file 03.

---

## Step 2 — Start Open WebUI

Choose one, depending on which phase you are in.

### Option A — On the Mac (Phase 1)

```bash
docker run -d \
  --name openwebui \
  --restart unless-stopped \
  -p 8080:8080 \
  -v openwebui-data:/app/backend/data \
  -e OPENAI_API_BASE_URL=http://host.docker.internal:4000/v1 \
  -e OPENAI_API_KEY=sk-your-openwebui-key \
  -e WEBUI_AUTH=true \
  -e ENABLE_SIGNUP=false \
  -e RAG_EMBEDDING_ENGINE=ollama \
  -e RAG_EMBEDDING_MODEL=nomic-embed-text \
  -e OLLAMA_BASE_URL=http://host.docker.internal:11434 \
  ghcr.io/open-webui/open-webui:main
```

`host.docker.internal` is the special name Docker on Mac uses to mean "the Mac
itself". Using `localhost` here would point inside the container and fail.

✅ **These variable names are verified against current Open WebUI docs (Aug
2026).** Setting the RAG variables here means you never have to click through the
UI for them. Two extras worth knowing:

- **`ENABLE_SIGNUP=false`** closes registration. Set it **after** you create your
  admin account — the first account to register becomes admin.
- Plural forms exist for multiple endpoints, semicolon-separated:
  `OPENAI_API_BASE_URLS='http://a:4000/v1;https://api.openai.com/v1'` and
  `OPENAI_API_KEYS='sk-a;sk-b'`

### Option B — On the VM (Phase 2/3)

```bash
docker run -d \
  --name openwebui \
  --restart unless-stopped \
  -p 8080:8080 \
  -v openwebui-data:/app/backend/data \
  -e OPENAI_API_BASE_URL=http://localhost:4000/v1 \
  -e OPENAI_API_KEY=sk-your-openwebui-key \
  -e WEBUI_AUTH=true \
  ghcr.io/open-webui/open-webui:main
```

If LiteLLM is on your Mac and Open WebUI is on the VM, use the Mac's Tailscale
address instead: `http://100.101.102.103:4000/v1`.

⚠️ Environment variable names in Open WebUI have changed between releases. If
your models do not show up, check https://docs.openwebui.com for the current
names.

---

## Step 3 — First login

Open `http://localhost:8080` (or the VM's Tailscale address on port 8080).

The **first account you create becomes the administrator**. Create it
immediately, before anyone else can find the page.

Then go to **Settings → Admin Settings → Users** and turn OFF new sign-ups. It
is your private tool; nobody else should be able to register.

---

## Step 4 — Confirm your models appear

In the model dropdown at the top of a new chat, you should see your LiteLLM
model names:

- `tier0-local`
- `tier1-free`
- `tier2-cheap`
- `tier3-smart`
- `tier1-public-only`

If the list is empty:

```bash
# Can the container reach LiteLLM?
docker exec openwebui curl -s -m 5 \
  http://host.docker.internal:4000/v1/models \
  -H "Authorization: Bearer sk-your-openwebui-key" | head -c 300

# What does Open WebUI say went wrong?
docker logs openwebui --tail 50
```

The usual cause is the wrong address (`localhost` instead of
`host.docker.internal`) or a wrong key.

Do **not** add `private-local` as a normal model here. It is meant for batch
jobs from the Mac agent, and it deliberately has no fallback — from a chat
window it would just look broken when the Mac is busy.

---

## Step 5 — Install it on your phone

1. Make sure Tailscale is on, on both Mac/VM and phone.
2. On your phone, open Safari and go to `http://100.101.102.103:8080`.
3. Tap **Share → Add to Home Screen**.

It now behaves like a real app — its own icon, full screen, no browser bars.
This is why you don't need to build an app.

⚠️ Some browser features need HTTPS. If something misbehaves, put a Cloudflare
Tunnel in front of it (file 03) to get a real HTTPS address.

---

## Step 6 — Turn on document search

This is the "give the AI my files" feature.

**Settings → Documents:**

| Setting | Set to | Why |
|---|---|---|
| Embedding model | `nomic-embed-text` via your local Ollama | Free, private, never leaves your Mac |
| Chunk size | 500–1,000 | Smaller = more precise, larger = more context |
| Chunk overlap | 100 | Stops sentences being cut in half |
| Top K | 4–6 | How many chunks get sent with your question |

⚠️ Exact setting names vary by version. The important thing is that the
embedding model points at your local Ollama, not a cloud provider — otherwise
every document you upload gets sent out.

**Test it:** upload a PDF, then ask a question that can only be answered from
inside it. If it answers correctly, document search works.

---

## Step 7 — Save prompts you reuse

**Workspace → Prompts.** Create shortcuts you can trigger with `/`:

| Shortcut | Prompt |
|---|---|
| `/short` | Answer in at most 3 sentences. No preamble. |
| `/india` | Answer for an Indian context — prices in rupees, Indian providers, Indian regulations. |
| `/steps` | Give me numbered steps I can follow, with the exact commands. |
| `/why` | Explain the reasoning and the trade-offs, not just the answer. |

Small thing, big daily time saving.

---

## Step 8 — Connect MCP tools (optional, later)

MCP is a standard way for AI to use tools. Open WebUI's own project for this is
**`mcpo`**, which translates a local (stdio) MCP server into an OpenAPI service
Open WebUI can call.

✅ Run it with `uvx`, which is what the official README documents:

```bash
uvx mcpo --host 0.0.0.0 --port 8001 --api-key change-me \
  -- npx -y @modelcontextprotocol/server-filesystem ~/Media
```

Then in Open WebUI: **Settings → Tools → Add** →
`http://localhost:8001/openapi.json`

Check the exact path in mcpo's own Swagger UI — if you load servers from a config
file, the path includes the server name.

🚨 **Correction to something I said earlier: there is no `--allow-tools` flag.**
Research confirmed mcpo has **no documented way to expose only some tools** from a
server. That matters, because a chatty MCP server puts every tool's schema into
every request. Your real options:

| Option | How |
|---|---|
| 🏆 Restrict at the server | Many MCP servers take arguments limiting scope — e.g. the filesystem server only sees the folder you pass it |
| 🏆 One mcpo per tool group | Separate instances on different ports, attached to different Open WebUI assistants |
| Open WebUI tool permissions | Control which tools each assistant may use in the UI |

Always run `uvx mcpo --help` against your installed version — the flags change.

**Do this last.** Telegram commands (file 05) cover most of what you want and are
far simpler to debug. And see file 14 for why you should not wrap your own
functions in MCP at all.

---

## Which chat interface for which situation

| Situation | Use |
|---|---|
| Quick question while walking | **Telegram** |
| "Rank my beach photos" | **Telegram** (`/rank`) |
| Long back-and-forth on a problem | **Open WebUI** |
| Uploading a PDF to ask about | **Open WebUI** |
| Comparing two models on the same question | **Open WebUI** |
| Writing code | **Neither** — use the Claude Code / Gemini CLI in Terminal |

---

## Keeping it updated

```bash
docker pull ghcr.io/open-webui/open-webui:main
docker stop openwebui && docker rm openwebui
# then re-run the docker run command from step 2
```

Your data is in the `openwebui-data` volume, so conversations and documents
survive. Back it up before a major update:

```bash
docker run --rm -v openwebui-data:/data -v ~/Backups:/backup \
  alpine tar czf /backup/openwebui-$(date +%F).tar.gz /data
```

---

## Troubleshooting

| Problem | Cause | Fix |
|---|---|---|
| Model list empty | Wrong base URL or key | Use `host.docker.internal` on Mac; check `docker logs openwebui` |
| Works on Mac, not phone | Tailscale off, or wrong address | Check `tailscale status` on both devices |
| Uploads fail | Embedding model not set | Set it to local `nomic-embed-text` |
| Very slow answers | Routed to a big local model | Pick `tier1-free` for chat, keep local for batch |
| Container keeps restarting | Port 8080 already in use | `lsof -i :8080`, or change to `-p 8081:8080` |
| Lost admin access | First account is the only admin | Restore the volume backup |

---

## Prompt for AI

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

## Check you are done

- [ ] `http://localhost:8080` loads
- [ ] Admin account created and new sign-ups disabled
- [ ] All your LiteLLM tiers appear in the model dropdown
- [ ] A chat with `tier1-free` gets an answer
- [ ] Installed on your phone home screen and works on mobile data
- [ ] A PDF upload can be asked questions about
- [ ] Embedding model is the local one, not a cloud one

---

Next: [05 — Telegram bot](05-telegram-bot.md)
