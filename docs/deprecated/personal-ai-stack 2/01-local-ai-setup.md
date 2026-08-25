# 01 — Local AI Setup (your Mac)

**Goal:** run AI models on your MacBook so most work costs ₹0.

**Time:** about 1 hour, mostly waiting for downloads.

**Cost:** ₹0.

Do this first. It gives you value immediately and everything else builds on it.

---

## Before you start

Check what you have:

```bash
# Should say arm64 (Apple Silicon)
uname -m

# How much free memory right now (look at "Pages free")
vm_stat | head -5

# Free disk space — you need about 25 GB
df -h ~
```

If `uname -m` says `x86_64`, you are running under Rosetta. Open a normal
Terminal instead.

---

## Step 1 — Install Homebrew (if you don't have it)

Homebrew is the package installer for macOS.

```bash
# Check if you already have it
brew --version
```

If not found, install from [https://brew.sh](https://brew.sh) — follow the one command on their
homepage, then close and reopen Terminal.

---



## Step 2 — Install Ollama

Ollama is the easiest way to run models locally. It gives you a web address
(`http://localhost:11434`) that other programs can talk to.

```bash
brew install ollama
```

Start it as a background service so it comes back after a restart:

```bash
brew services start ollama
```

Check it is running:

```bash
curl http://localhost:11434/api/tags
```

You should get back `{"models":[]}` — empty, because you have no models yet.

---



## Step 3 — Download your models

Download in this order. Start with the small ones so you get something working
fast.

```bash
# 1. The router / tagger — small and very fast (about 2.5 GB)
ollama pull qwen3:4b

# 2. Vision model for describing photos (about 2.6 GB)
ollama pull gemma3:4b

# 3. Your general workhorse (about 5 GB)
ollama pull qwen3:8b

# 4. Embeddings — for searching your own notes and files
ollama pull nomic-embed-text        # 0.274 GB, but only 2K context
```

✅ **Tags verified current (Aug 2026):** `qwen3:4b`, `qwen3:8b`, `qwen3:14b`,
`gemma3:4b`, `gemma3:12b`, `nomic-embed-text` (latest = v1.5). Confirm at
[https://ollama.com/library/qwen3/tags](https://ollama.com/library/qwen3/tags) if a pull fails.

🚨 `nomic-embed-text` **has only a 2,000 token context window.** That is fine for
short photo captions, but too small for document chunks. If you want to search
PDFs and notes, use this instead:

```bash
ollama pull qwen3-embedding:4b      # 2.5 GB, 40K context
```

**Optional, only if you want the best local vision (7.5 GB, and it will make
your Mac feel slower while loaded):**

```bash
ollama pull gemma3:12b
```

Check what you have:

```bash
ollama list
```

---



## Step 4 — Test that it works

```bash
ollama run qwen3:8b "In one sentence, what is memory bandwidth?"
```

Type `/bye` to exit.

Now test the web address, which is how every other app will reach it:

```bash
curl http://localhost:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen3:8b",
    "messages": [{"role":"user","content":"Say OK and nothing else."}]
  }'
```

You should get JSON back with "OK" inside it. That `/v1/chat/completions`
address is the OpenAI-compatible format — this is why LiteLLM, Open WebUI, and
everything else can talk to it without special code.

---



## Step 5 — Keep the model loaded in memory

By default Ollama unloads a model after 5 minutes. Reloading takes 10–30
seconds, which will make your router think the model is broken and switch to a
paid cloud model unnecessarily.

Fix it:

```bash
launchctl setenv OLLAMA_KEEP_ALIVE 24h
brew services restart ollama
```

To make it survive a reboot, add it to your shell profile too:

```bash
echo 'export OLLAMA_KEEP_ALIVE=24h' >> ~/.zshrc
```

**Trade-off:** the model now permanently occupies its memory (5 GB for
qwen3:8b). If your Mac feels short of memory, set this to `1h` instead.

---



## Step 6 — Measure your actual speed

Knowing your real speed tells you which jobs are worth doing locally.

```bash
ollama run qwen3:8b --verbose "Write a 100 word paragraph about the sea."
```

Look at `eval rate` in the output. Expect:


| Model      | Expected speed   |
| ---------- | ---------------- |
| qwen3:4b   | 35–50 tokens/sec |
| qwen3:8b   | 20–30 tokens/sec |
| gemma3:12b | 12–18 tokens/sec |


If you are far below this, something else is using your memory. Close Chrome
and heavy apps and try again.

---



## Step 7 — Optional: try MLX and measure it

MLX is Apple's own machine-learning framework, built specifically for Apple chips
and unified memory.

🚨 **Correction to something I said earlier: MLX is not proven faster.** I claimed
20–40%. Research found **no published controlled benchmark** comparing MLX and
llama.cpp/Ollama at the same model and quantisation. Apple documents that MLX is
*designed* for Apple Silicon, which is not the same as a measured win.

**So: measure it on your own Mac before switching anything.**

```bash
brew install python@3.12
python3.12 -m venv ~/.venvs/mlx
source ~/.venvs/mlx/bin/activate
pip install mlx-lm

# Time it, then compare against the Ollama number from step 6
time mlx_lm.generate --model mlx-community/Qwen3-8B-4bit \
  --prompt "Write exactly 100 words about the ocean." --max-tokens 150
```

⚠️ Exact MLX model names live at [https://huggingface.co/mlx-community](https://huggingface.co/mlx-community) — check
there if the name above fails. Not every Ollama model has an MLX conversion.

Keep Ollama as your main setup either way. Only move a batch job to MLX if your
own measurement shows a real gain.

**One place MLX clearly wins:** speech to text.
`mlx-community/whisper-large-v3-turbo-4bit` is only **0.464 GB** and there is no
equivalent Ollama tag.

---



## Step 8 — Install the photo-scoring tools

These are **not** language models. They are small vision models that score
images. This is what makes your photo ranker free. Full details in file 07.

```bash
brew install ffmpeg exiftool

python3.12 -m venv ~/.venvs/media
source ~/.venvs/media/bin/activate

pip install torch torchvision open_clip_torch pillow imagehash \
            scenedetect opencv-python numpy tqdm
```

⚠️ `torch` on Apple Silicon uses a backend called MPS for GPU acceleration.
Confirm it works:

```bash
python -c "import torch; print('MPS available:', torch.backends.mps.is_available())"
```

Must print `True`. If it prints `False`, your torch build is CPU-only —
reinstall with `pip install --force-reinstall torch torchvision`.

---



## Which model for which job


| Job                                                       | Model                       | Why                                              |
| --------------------------------------------------------- | --------------------------- | ------------------------------------------------ |
| Understanding a short command like "rank my beach photos" | qwen3:4b                    | Fast, and this is an easy task                   |
| Naming a group of photos                                  | qwen3:4b                    | Short input, short output                        |
| Describing a photo                                        | gemma3:4b                   | Can see images, fast enough for thousands        |
| Summarising a document                                    | qwen3:8b                    | Better at longer text                            |
| Writing a video edit plan                                 | ⚠️ Send to cloud (DeepSeek) | Needs better reasoning than 8B gives             |
| Writing code                                              | ❌ Never local               | 8B models are not good enough. Use GLM or Claude |
| Searching your own notes                                  | nomic-embed-text            | Built for this                                   |
| Scoring photo quality                                     | CLIP + aesthetic model      | Not a language model at all                      |


---



## Troubleshooting


| Problem                             | Cause                                           | Fix                                                      |
| ----------------------------------- | ----------------------------------------------- | -------------------------------------------------------- |
| `connection refused` on port 11434  | Ollama not running                              | `brew services restart ollama`                           |
| Very slow, Mac feels frozen         | Model bigger than free memory, swapping to disk | Use a smaller model. Check with `vm_stat`                |
| Model reloads on every request      | Keep-alive not set                              | Redo step 5                                              |
| `MPS available: False`              | CPU-only torch                                  | `pip install --force-reinstall torch torchvision`        |
| Runs fine on power, slow on battery | macOS throttles on battery                      | Plug in for batch jobs                                   |
| Fans loud during long jobs          | Normal                                          | Plug in, use `caffeinate -s` so it doesn't sleep mid-job |


---



## Prompt for AI

Use this to get a speed-testing script written for you. It is a good task for
a weaker model because the job is small and the output format is fully
specified.

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



## Check you are done

- [x] `ollama list` shows qwen3:4b, gemma3:4b, qwen3:8b, nomic-embed-text
- [x] The `curl` test in step 4 returns JSON
- [x] Speed matches the table in step 6
- [x] `MPS available: True`
- [x] `ffmpeg -version` works

---

Next: [02 — LiteLLM router](02-litellm-router.md)