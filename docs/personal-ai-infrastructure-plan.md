# Personal AI Infrastructure — Setup Plan

Goal: a hub-and-spoke personal AI system — M1 Pro Mac as the local engine, an Oracle
Cloud free ARM VM as the always-on phone gateway (OpenClaw + WhatsApp), and Claude Pro
as the one paid reasoning/coding layer — for under ₹2,600/month.

**Order of operations:** Mac first (it's the foundation everything else calls into),
then Oracle (the always-on gateway), then Claude Pro + MCP wiring, then automations.
Each phase is independently testable before moving to the next.

---

## Phase 0 — Accounts and prerequisites (30 min)

- [ ] Apple ID with Apple Music subscription active (needed for the Music MCP server)
- [ ] Google account with Google Photos (only needed if you want Google Photos MCP;
      optional given its API limits — see Phase 1.5)
- [ ] A credit/debit card enabled for international transactions (Claude Pro doesn't
      support UPI yet) — confirm with your bank before subscribing
- [ ] A separate WhatsApp number/SIM if you don't want OpenClaw tied to your primary
      WhatsApp account (recommended but optional — a dedicated WhatsApp Business
      account works well here)
- [ ] Oracle Cloud account (sign-up needs a card for identity verification; you are
      not charged unless you explicitly upgrade) — start this signup early, account
      approval can take a day or two

---

## Phase 1 — Mac setup (the local engine)

### 1.1 Install core tools
```bash
# Install Homebrew if you don't have it
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Core packages
brew install ollama ffmpeg python@3.12 node git
brew install --cask tailscale
```

### 1.2 Install and test Ollama
```bash
# Start Ollama (runs as a background service)
brew services start ollama

# Pull your two workhorse models
ollama pull qwen2.5:7b          # general daily-driver chat
ollama pull qwen2.5-coder:7b    # lightweight local coding

# Sanity check
ollama run qwen2.5:7b "Say hello in one sentence"
```
Keep an eye on Activity Monitor the first few times — if the Mac swaps heavily, drop
to a smaller model (`qwen2.5:3b` or `phi-4`) instead.

### 1.3 Install Open WebUI (optional local chat UI, useful for testing models directly)
```bash
pip3 install open-webui --break-system-packages
open-webui serve   # visit http://localhost:8080
```
This isn't your primary phone interface anymore (OpenClaw is), but it's a handy way
to test and compare Ollama models from a browser on the Mac itself.

### 1.4 Set up Tailscale on the Mac
1. Open the Tailscale app (installed via brew cask above), sign in with a personal
   account (Google/GitHub/Microsoft — free tier covers 6 users, unlimited devices).
2. Confirm the Mac shows up in your tailnet at https://login.tailscale.com/admin/machines
3. Note the Mac's Tailscale IP (something like `100.x.x.x`) — you'll need this later
   so the Oracle VM can reach the Mac.
4. In Tailscale admin console, disable key expiry for this device (Settings → the
   device → "Disable key expiry") so it doesn't drop off the mesh unexpectedly.

### 1.5 Set up the MCP servers on the Mac

**Apple Music MCP** (playback, playlists, library search):
```bash
git clone https://github.com/epheterson/applemusic-mcp.git
cd applemusic-mcp
pipx install applemusic-mcp
# macOS default install needs nothing extra — it drives Music.app via AppleScript
applemusic-mcp serve   # test it starts cleanly, then Ctrl+C
```
The first time it runs, macOS will prompt for Automation permission for
Music.app/AppleScript — approve it in System Settings → Privacy & Security →
Automation.

**Apple Photos MCP** (albums, search, export — read-only by default):
```bash
git clone https://github.com/sweetrb/apple-photos-mcp.git
cd apple-photos-mcp
npm install && npm run build
```
Leave `APPLE_PHOTOS_MCP_ENABLE_WRITES` unset until you've tested read-only queries
and are comfortable letting it create albums automatically.

**Google Photos MCP** (optional, limited):
Only bother with this if your workflow imports *new* photos through the app itself.
Because Google's API only exposes app-created content for existing libraries, treat
your 10GB+ existing folder as a **local filesystem problem** (Phase 1.6 below), not
a Google Photos API problem.

**AirMCP** (broad Apple ecosystem coverage — optional, covers Music/Photos/Notes/
Calendar/Mail/Safari/Shortcuts in one server if you want fewer moving parts):
```bash
npx airmcp init
```
Follow the interactive prompts; grant Automation permissions as macOS asks for them.

### 1.6 Local photo aesthetic ranker (the 10GB+ folder, kept fully local)
```bash
mkdir -p ~/ai-tools/aesthetic-ranker && cd ~/ai-tools/aesthetic-ranker
python3 -m venv venv && source venv/bin/activate
pip install torch torchvision open_clip_torch pillow pandas --break-system-packages
```
Create `rank.py`:
```python
import open_clip, torch, glob, pandas as pd
from PIL import Image

device = "mps" if torch.backends.mps.is_available() else "cpu"
model, _, preprocess = open_clip.create_model_and_transforms(
    "ViT-L-14", pretrained="openai", device=device
)
tokenizer = open_clip.get_tokenizer("ViT-L-14")

positive = tokenizer(["a stunning, beautifully composed photo"]).to(device)
negative = tokenizer(["a blurry, poorly composed, ugly photo"]).to(device)

results = []
for path in glob.glob("/path/to/your/photos/**/*.jpg", recursive=True):
    img = preprocess(Image.open(path).convert("RGB")).unsqueeze(0).to(device)
    with torch.no_grad():
        img_feat = model.encode_image(img)
        pos_feat = model.encode_text(positive)
        neg_feat = model.encode_text(negative)
        score = (img_feat @ pos_feat.T - img_feat @ neg_feat.T).item()
    results.append({"path": path, "score": score})

pd.DataFrame(results).sort_values("score", ascending=False).to_csv("scores.csv", index=False)
```
Run it once over your folder (`python rank.py`) — this uses the M1's Metal GPU (`mps`)
and stays entirely offline. Re-run whenever you add new photos.

### 1.7 ffmpeg reel-assembly pipeline
```bash
mkdir -p ~/ai-tools/reel-builder
```
Create a `build_reel.sh` that takes the top N photos from `scores.csv`, a music track
(pulled via the Apple Music MCP), and stitches a Ken-Burns-style slideshow:
```bash
#!/bin/bash
# Usage: ./build_reel.sh <output.mp4> <audio.m4a> <photo1> <photo2> ...
ffmpeg -y \
  $(for img in "${@:3}"; do echo "-loop 1 -t 3 -i $img"; done) \
  -i "$2" \
  -filter_complex "$(python3 gen_filter.py "${@:3}")" \
  -shortest "$1"
```
(You'll iterate on `gen_filter.py` to generate zoom/pan and crossfade filter strings —
this is a good task to hand to Claude Code or your local qwen2.5-coder model once the
skeleton above is working.)

### 1.8 Keep the Mac reachable for scheduled jobs
Since photo ranking, reel building, and Apple Music/Photos automation are macOS-only,
they need the Mac awake when triggered:
- System Settings → Lock Screen → set "Turn display off" but **not** full sleep, or
- Use `caffeinate -s` in a login item to prevent sleep while plugged in, or
- Accept that these specific jobs run "next time the Mac is open" rather than
  instantly — reasonable for a batch task like reel-building.

**✅ Phase 1 checkpoint:** Ollama answers locally, Tailscale shows the Mac online,
Apple Music/Photos MCP servers start without error, `rank.py` produces a `scores.csv`.

---

## Phase 2 — Oracle Cloud setup (the always-on phone gateway)

### 2.1 Provision the free ARM VM
1. Log into https://cloud.oracle.com → Compute → Instances → Create Instance.
2. Region: pick **Mumbai (`ap-mumbai-1`) or Hyderabad (`ap-hyderabad-1`)** for
   lowest latency to you.
3. Image: Ubuntu 22.04 (or latest LTS) minimal.
4. Shape: click "Change shape" → Ampere → **VM.Standard.A1.Flex** → set OCPUs/RAM
   to whatever your tenancy currently allows (check the Always Free banner on the
   shape — it may show 2 OCPU/12GB or 4 OCPU/24GB depending on when your account
   was created; either is enough for this use case).
5. If you get a capacity/"out of host capacity" error, retry — this is common for
   the free ARM shape. Try a different availability domain, or retry every few
   hours; some people script a retry loop for this specifically.
6. Add your SSH public key under the SSH section.
7. Create. Note the public IP once it's running.

### 2.2 Basic hardening
```bash
ssh ubuntu@<public-ip>
sudo apt update && sudo apt upgrade -y
sudo ufw allow OpenSSH
sudo ufw enable
```
Also open the Oracle-side security list/NSG for port 22 only — everything else
(OpenClaw, Ollama) will be reached over Tailscale, not the public internet.

### 2.3 Install Tailscale on the VM
```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```
Authenticate via the link it prints, confirm the VM appears in the same tailnet as
your Mac. From now on, treat the VM's public IP as something you rarely touch
directly — everything routes over the tailnet.

### 2.4 Install Node.js and OpenClaw
```bash
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt install -y nodejs
node -v   # confirm v22+

# Install OpenClaw (check their current install docs — this is the general path)
curl -fsSL https://get.openclaw.ai | sh
openclaw --version
```

### 2.5 Run the onboarding wizard and pair WhatsApp
```bash
openclaw onboard
```
- Choose "Quickstart" mode.
- When asked for a channel, choose WhatsApp.
- A QR code prints in the terminal — scan it with the WhatsApp mobile app
  (Settings → Linked Devices → Link a Device) on the dedicated number you set aside
  in Phase 0.
- Confirm you get a "WhatsApp session established" message.

### 2.6 Point OpenClaw at a model backend
Edit `openclaw.json`:
```json
{
  "channels": {
    "whatsapp": { "enabled": true, "allowFrom": ["*"] }
  },
  "models": {
    "default": "local-ollama",
    "providers": {
      "local-ollama": {
        "type": "ollama",
        "baseUrl": "http://localhost:11434"
      },
      "claude": {
        "type": "anthropic",
        "apiKey": "${ANTHROPIC_API_KEY}"
      }
    }
  }
}
```

### 2.7 Install a lightweight local model on the VM itself
```bash
curl -fsSL https://ollama.com/install.sh | sh
ollama pull qwen2.5:7b
```
This gives OpenClaw an always-available "reflex" brain on the VM even if the Mac is
asleep — for quick questions, reminders, and anything that doesn't need your local
files.

### 2.8 Wire the VM to the Mac for heavier jobs
For tasks that need the Mac (photo ranking, reel building, Apple Music control),
configure an OpenClaw "skill" that SSHes into the Mac over Tailscale and runs the
relevant script:
```bash
# From the Oracle VM, confirm you can reach the Mac over Tailscale
ssh <your-mac-username>@<mac-tailscale-ip> "echo mac reachable"
```
Add an OpenClaw skill (their skills system, see `skills.sh` or your local
`skills/` folder) that wraps this SSH call — e.g. a `build-reel` skill that SSHes
in, runs `build_reel.sh`, and pulls the output `.mp4` back over `scp`.

**✅ Phase 2 checkpoint:** messaging your dedicated WhatsApp number gets a reply
from OpenClaw; a message like "ping the Mac" successfully triggers something on
the Mac over Tailscale.

---

## Phase 3 — Claude Pro setup (the cloud reasoning/coding layer)

### 3.1 Subscribe
- Go to claude.ai → Upgrade → Pro. Confirm INR pricing shows at checkout
  (~₹2,000–2,400/month with GST included).
- Use the international-capable card from Phase 0.

### 3.2 Install Claude Code and Claude Desktop on the Mac
```bash
npm install -g @anthropic-ai/claude-code
claude-code --version
```
Also install Claude Desktop from claude.ai/download for the MCP-connected chat app
and Claude in Chrome extension for agentic browsing.

### 3.3 Wire your MCP servers into Claude Desktop
Edit Claude Desktop's config (`~/Library/Application Support/Claude/claude_desktop_config.json`):
```json
{
  "mcpServers": {
    "apple-music": {
      "command": "applemusic-mcp",
      "args": ["serve"]
    },
    "apple-photos": {
      "command": "node",
      "args": ["/Users/<you>/ai-tools/apple-photos-mcp/dist/index.js"]
    }
  }
}
```
Restart Claude Desktop. In a new chat, try: "List my Apple Music playlists" and
"Show me my Photos albums" to confirm both servers respond.

### 3.4 Get an Anthropic API key for OpenClaw's Claude fallback
- console.anthropic.com → API Keys → Create Key.
- Add it as `ANTHROPIC_API_KEY` in the Oracle VM's environment (`~/.bashrc` or a
  systemd env file for the OpenClaw service) so the `claude` provider in
  `openclaw.json` (Phase 2.6) works.
- Set a small monthly budget alert in the console (Settings → Billing → budget
  alerts) so an unexpectedly heavy day doesn't blow your ₹2–3k ceiling — keep this
  as a rarely-used fallback, not your default.

**✅ Phase 3 checkpoint:** Claude Desktop can call both MCP servers; messaging
OpenClaw with "use claude for this" successfully routes to the Anthropic API.

---

## Phase 4 — Automations (put it all to work)

### 4.1 Music curation (weekly, on the Mac)
Cron job (`crontab -e`) that runs a script asking your local Ollama model, using
the Apple Music MCP tools, to review recent listens and refresh a "Discover" playlist:
```
0 9 * * 1 /Users/<you>/ai-tools/music-refresh.sh
```

### 4.2 Photo albums + reels (weekly or on-demand via WhatsApp)
- Cron re-runs `rank.py` on any new files.
- A WhatsApp message like "build me a reel from this month's best photos" reaches
  OpenClaw → SSHes to the Mac → filters `scores.csv` for this month's top-scored
  images → calls `build_reel.sh` with a track pulled via the Apple Music MCP →
  scp's the finished `.mp4` back → OpenClaw sends it to you on WhatsApp.

### 4.3 Coding
- Default to `claude-code` in your project directories for anything nontrivial.
- Use qwen2.5-coder locally (via Continue.dev or Cline in your editor) for quick
  edits, so you're not spending Claude Pro's higher-effort usage on boilerplate.

### 4.4 Day-to-day / misc via WhatsApp
- Anything conversational goes straight to OpenClaw → local qwen2.5:7b on the
  Oracle VM by default.
- Say "use claude" (or set a keyword rule in `openclaw.json`) when you want a
  harder question routed to Claude Pro instead.

**✅ Phase 4 checkpoint:** you can trigger a photo reel and a playlist refresh
entirely from a WhatsApp message, with no laptop interaction required.

---

## Troubleshooting notes

- **Oracle capacity errors on VM creation:** common for the free ARM shape,
  especially in busy regions — retry periodically rather than assuming it's broken.
- **Oracle free-tier ARM limits:** these were recently reduced for some accounts
  (2 OCPU/12GB vs the older 4 OCPU/24GB) — check what your specific tenancy shows
  before sizing your VM.
- **WhatsApp session drops:** OpenClaw's WhatsApp session typically needs
  re-pairing roughly every 30 days — it will notify you in advance.
- **Claude Pro payment:** no UPI support at launch — use an international-enabled
  card, and check with your bank if the first charge gets blocked.
- **Mac asleep:** anything routed to the Mac (photo/reel jobs, Apple Music/Photos
  control) will queue or fail if the Mac is asleep — either keep it plugged in and
  awake, or set expectations that these are "next time you're at your desk" tasks.

---

## Monthly cost recap

| Item | Cost |
|---|---|
| Claude Pro | ₹2,000–2,400 |
| Oracle Cloud Always Free VM | ₹0 |
| OpenClaw, Ollama, Tailscale, MCP servers | ₹0 (open source) |
| Extra electricity (Mac + normal use) | ~₹100–200 |
| **Total** | **~₹2,100–2,600/month** |
