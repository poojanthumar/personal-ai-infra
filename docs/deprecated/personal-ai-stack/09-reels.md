# 08 — Reels Pipeline


> ⚠️ **Anything marked ⚠️ in this file is unverified.** All of it is answered
> by the prompt in [⚠️ Verify with AI](#-verify-with-ai) at the bottom — paste it
> into Gemini or any web-enabled AI and update this file with the result.

**Goal:** turn a request like "30 second beach trip reel, upbeat" into a
finished vertical video, using your already-scored clips and your own music.

**Time:** 2–3 hours to build. About 1–3 minutes per reel to run.

**Cost:** about ₹0.05 per reel (one small AI call). Rendering is free.

**Requires:** file 03 done, so `index.sqlite` has scores for your clips.

---

## The architecture that makes this cheap

**The AI writes a plan. ffmpeg does the work. The AI never touches a pixel.**

```
"30s beach trip, upbeat"
        ↓
Query index.sqlite for the best matching clips  ← free, instant
        ↓
Build a small manifest (2-5 KB of text)
        ↓
Send manifest to a cheap AI model  ← ~₹0.05
        ↓
AI returns an Edit Decision List (JSON)
        ↓
ffmpeg renders it  ← free
        ↓
reel.mp4
```

An **Edit Decision List** (EDL) is just a list saying "show clip 41 from 12.4 to
15.1 seconds, then clip 57 from 3.0 to 5.2 seconds". Film editors have used the
idea for decades. It is the perfect thing for an AI to write, because it is
short, structured, and easy to check.

**Never let the AI generate video or run ffmpeg itself.** It writes a plan; your
code validates and executes it. That is what keeps it cheap and predictable.

---

## Step 1 — Music and beat detection

```bash
source ~/.venvs/media/bin/activate
pip install librosa soundfile
```

Save as `~/Documents/Code/aihub/beats.py`:

```python
"""Find the tempo and beat times in a music file."""

import librosa
import numpy as np


def analyse_track(path):
    """
    Returns tempo in beats-per-minute and a list of beat times in seconds.
    Cuts that land on beats feel intentional; cuts that don't feel sloppy.
    """
    y, sr = librosa.load(str(path), mono=True)
    tempo, beat_frames = librosa.beat.beat_track(y=y, sr=sr)
    beats = librosa.frames_to_time(beat_frames, sr=sr)
    return {
        "bpm": float(np.atleast_1d(tempo)[0]),
        "beats": [round(float(b), 3) for b in beats],
        "duration": float(librosa.get_duration(y=y, sr=sr)),
    }


if __name__ == "__main__":
    import sys, json
    print(json.dumps(analyse_track(sys.argv[1]), indent=2)[:1000])
```

Test it:

```bash
python beats.py ~/Media/Music/track.m4a
```

You should get a BPM around 90–130 for most modern music, and a long list of
beat times.

---

## ⚠️ Important legal note about music

You **cannot** use Apple Music or Spotify tracks in an exported video. Those
files are copy-protected, and even if you got around that, publishing the result
would infringe copyright.

Use one of these instead, in `~/Media/Music`:

| Source | Notes |
|---|---|
| Music you own outright | Purchased downloads, your own recordings |
| Royalty-free libraries | Free Music Archive, ccMixter, Pixabay Music |
| Platform audio libraries | Instagram and YouTube provide licensed tracks *inside their editors* — but you cannot export those into your own file |
| AI-generated music | Check the specific service's licence terms |

For personal videos you never share, the practical risk is low — but the export
still cannot read a protected Apple Music file, so it will simply fail.

---

## Step 2 — Build the manifest

The manifest is the small text summary the AI sees. Save as
`~/Documents/Code/aihub/manifest.py`:

```python
"""Build a small text summary of candidate clips for the AI to plan with."""

from pathlib import Path
from media_db import connect
from beats import analyse_track


def build_manifest(description, target_seconds=30, music_file=None,
                   max_clips=25, db_path="~/Media/index.sqlite"):
    """
    Pick candidate clips from the database and describe them compactly.
    Only text goes to the AI. No images, no video, no audio.
    """
    conn = connect(db_path)

    # Pull keywords out of the request to match against captions
    stop = {"a", "an", "the", "reel", "video", "second", "seconds", "make",
            "build", "of", "my", "for", "with", "and", "s"}
    words = [w.strip(",.").lower() for w in description.split()]
    keywords = [w for w in words if w not in stop and not w.isdigit()
                and len(w) > 2]

    # Prefer clips whose caption matches a keyword, then fall back to best score
    rows = []
    if keywords:
        like = " OR ".join(["caption LIKE ?"] * len(keywords))
        rows = conn.execute(f"""
            SELECT id, path, kind, scene_start, scene_end, caption,
                   round(final_score,2) AS score, round(aesthetic,2) AS aes,
                   round(sharpness,2) AS sharp, faces
            FROM media
            WHERE is_best_of_group=1 AND ({like})
            ORDER BY final_score DESC LIMIT ?
        """, [f"%{k}%" for k in keywords] + [max_clips]).fetchall()

    if len(rows) < 6:
        rows = conn.execute("""
            SELECT id, path, kind, scene_start, scene_end, caption,
                   round(final_score,2) AS score, round(aesthetic,2) AS aes,
                   round(sharpness,2) AS sharp, faces
            FROM media
            WHERE is_best_of_group=1
            ORDER BY final_score DESC LIMIT ?
        """, (max_clips,)).fetchall()

    clips = []
    for r in rows:
        clips.append({
            "id": r["id"],
            "file": r["path"],
            "kind": r["kind"],
            "in": round(r["scene_start"], 2) if r["scene_start"] is not None else 0,
            "out": round(r["scene_end"], 2) if r["scene_end"] is not None else 0,
            "score": r["score"],
            "faces": r["faces"],
            "caption": (r["caption"] or "")[:80],
        })

    manifest = {
        "request": description,
        "target_seconds": target_seconds,
        "clips": clips,
    }

    if music_file:
        m = analyse_track(Path(music_file).expanduser())
        # Only send the beats we might actually use
        cutoff = target_seconds + 5
        manifest["music"] = {
            "file": str(music_file),
            "bpm": round(m["bpm"], 1),
            "beats": [b for b in m["beats"] if b <= cutoff],
        }

    conn.close()
    return manifest
```

A manifest for 25 clips is about 2–4 KB. That is a few thousand tokens — around
**₹2 on Claude Opus 5, or ₹0.05 on DeepSeek.**

---

## Step 3 — Ask the AI for an edit plan

Save as `~/Documents/Code/aihub/plan_reel.py`:

```python
"""Send the manifest to an AI model and get back a validated edit plan."""

import json, os, requests

LITELLM = os.environ.get("LITELLM_URL", "http://localhost:4000/v1")
KEY     = os.environ["LITELLM_KEY"]

SYSTEM = """You are a video editor. You produce edit plans as JSON only.

You will receive a list of available clips with scores and captions, a target
length in seconds, and optionally music beat times.

Return ONLY valid JSON in exactly this shape, with no explanation and no
markdown fences:

{
  "title": "short title",
  "cuts": [
    {"clip_id": 41, "in": 12.4, "out": 15.1, "transition": "cut"}
  ],
  "music_start": 0.0,
  "notes": "one short sentence about the pacing choice"
}

Rules you must follow:
- Only use clip_id values that appear in the input. Never invent one.
- "in" and "out" must be inside that clip's own in/out range.
- Each cut must be between 0.8 and 4.0 seconds long.
- The total of all cuts must be within 2 seconds of target_seconds.
- transition is only ever "cut" or "fade".
- If music beats were provided, make each cut boundary land on or very near a
  beat time.
- Prefer higher-scoring clips, but vary the shots. Do not use the same clip
  twice in a row.
- Open with a strong wide shot and close on a memorable one.
"""


def plan_reel(manifest, model="tier2-cheap"):
    """Get an edit plan, then check it. Raises ValueError if the plan is bad."""
    r = requests.post(
        f"{LITELLM}/chat/completions",
        headers={"Authorization": f"Bearer {KEY}"},
        json={
            "model": model,
            "messages": [
                {"role": "system", "content": SYSTEM},
                {"role": "user", "content": json.dumps(manifest)},
            ],
            "metadata": {"tags": ["job:reel_edl"]},
        },
        timeout=180,
    )
    r.raise_for_status()
    text = r.json()["choices"][0]["message"]["content"].strip()

    # Models sometimes wrap JSON in markdown fences despite instructions
    if text.startswith("```"):
        text = text.split("```")[1]
        if text.startswith("json"):
            text = text[4:]

    plan = json.loads(text)
    validate_plan(plan, manifest)
    return plan


def validate_plan(plan, manifest):
    """
    Never trust the plan. Check it against reality before rendering.
    A wrong plan should fail here, not halfway through ffmpeg.
    """
    by_id = {c["id"]: c for c in manifest["clips"]}
    cuts = plan.get("cuts") or []

    if not cuts:
        raise ValueError("plan has no cuts")

    total = 0.0
    for i, cut in enumerate(cuts):
        cid = cut.get("clip_id")
        if cid not in by_id:
            raise ValueError(f"cut {i}: clip_id {cid} was not offered")

        src = by_id[cid]
        cin, cout = float(cut["in"]), float(cut["out"])
        length = cout - cin

        if length < 0.5 or length > 6.0:
            raise ValueError(f"cut {i}: length {length:.2f}s is out of range")

        if src["kind"] == "video_scene" and src["out"] > 0:
            if cin < src["in"] - 0.5 or cout > src["out"] + 0.5:
                raise ValueError(
                    f"cut {i}: {cin}-{cout} is outside the clip's "
                    f"{src['in']}-{src['out']}")

        if cut.get("transition") not in ("cut", "fade", None):
            raise ValueError(f"cut {i}: unknown transition {cut.get('transition')}")

        total += length

    target = manifest.get("target_seconds", 30)
    if abs(total - target) > 5:
        raise ValueError(f"total {total:.1f}s is too far from target {target}s")

    return True
```

**The validator matters more than the prompt.** Models occasionally invent a
clip ID or an out-of-range timestamp. Catching that here gives you a clear error
instead of a corrupt video.

---

## Step 4 — Render with ffmpeg

Save as `~/Documents/Code/aihub/build_reel.py`:

```python
#!/usr/bin/env python3
"""Turn a validated edit plan into an actual video file."""

import json, os, subprocess, tempfile, shutil
from datetime import datetime
from pathlib import Path

from media_db import connect
from manifest import build_manifest
from plan_reel import plan_reel

# Vertical video, the format short-form platforms want
W, H, FPS = 1080, 1920, 30


def extract_cut(src, start, end, out_path):
    """Cut one piece out, scale to vertical, normalise frame rate."""
    duration = end - start
    vf = (f"scale={W}:{H}:force_original_aspect_ratio=increase,"
          f"crop={W}:{H},fps={FPS},format=yuv420p")

    subprocess.run([
        "ffmpeg", "-y", "-loglevel", "error",
        "-ss", f"{start:.3f}", "-i", str(src), "-t", f"{duration:.3f}",
        "-vf", vf, "-an",                 # drop original audio, music comes later
        "-c:v", "libx264", "-preset", "veryfast", "-crf", "20",
        str(out_path),
    ], check=True, timeout=600)


def still_to_clip(src, seconds, out_path):
    """Turn a photo into a short clip with a slow zoom (Ken Burns effect)."""
    frames = int(seconds * FPS)
    vf = (f"scale={W*2}:{H*2}:force_original_aspect_ratio=increase,"
          f"crop={W*2}:{H*2},"
          f"zoompan=z='min(zoom+0.0012,1.25)':d={frames}:s={W}x{H}:fps={FPS},"
          f"format=yuv420p")

    subprocess.run([
        "ffmpeg", "-y", "-loglevel", "error",
        "-loop", "1", "-i", str(src), "-t", f"{seconds:.3f}",
        "-vf", vf, "-c:v", "libx264", "-preset", "veryfast", "-crf", "20",
        str(out_path),
    ], check=True, timeout=600)


def build_reel(description, media_root="~/Media", target_seconds=30,
               music_file=None, model="tier2-cheap"):
    """Full pipeline: pick clips, plan the edit, render the video."""
    root = Path(media_root).expanduser().resolve()
    out_dir = root / "Output"
    out_dir.mkdir(parents=True, exist_ok=True)

    # Pick music automatically if none was given
    if music_file is None:
        tracks = sorted((root / "Music").glob("*.*"))
        music_file = tracks[0] if tracks else None

    print("building manifest...")
    manifest = build_manifest(description, target_seconds, music_file)
    if len(manifest["clips"]) < 3:
        raise ValueError("fewer than 3 scored clips available — run the "
                         "ranker (file 03) first")

    print(f"asking {model} for an edit plan "
          f"({len(manifest['clips'])} candidate clips)...")
    plan = plan_reel(manifest, model=model)
    print(f"plan: {len(plan['cuts'])} cuts — {plan.get('notes','')}")

    by_id = {c["id"]: c for c in manifest["clips"]}
    tmp = Path(tempfile.mkdtemp(prefix="reel_"))

    try:
        pieces = []
        for i, cut in enumerate(plan["cuts"]):
            src_info = by_id[cut["clip_id"]]
            src = root / src_info["file"]
            piece = tmp / f"{i:03d}.mp4"

            if src_info["kind"] == "photo":
                still_to_clip(src, cut["out"] - cut["in"], piece)
            else:
                extract_cut(src, cut["in"], cut["out"], piece)

            pieces.append(piece)
            print(f"  cut {i+1}/{len(plan['cuts'])}: {src_info['file']}")

        # Join the pieces
        listfile = tmp / "list.txt"
        listfile.write_text("".join(f"file '{p}'\n" for p in pieces))
        silent = tmp / "silent.mp4"
        subprocess.run([
            "ffmpeg", "-y", "-loglevel", "error",
            "-f", "concat", "-safe", "0", "-i", str(listfile),
            "-c", "copy", str(silent),
        ], check=True, timeout=600)

        stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
        safe_title = "".join(c if c.isalnum() or c in "-_" else "-"
                             for c in plan.get("title", "reel"))[:40]
        final = out_dir / f"{stamp}-{safe_title}.mp4"

        if music_file and Path(music_file).exists():
            ms = float(plan.get("music_start", 0.0))
            subprocess.run([
                "ffmpeg", "-y", "-loglevel", "error",
                "-i", str(silent),
                "-ss", f"{ms:.3f}", "-i", str(music_file),
                "-filter_complex",
                # fade the music out over the last 1.5 seconds
                "[1:a]afade=t=out:st=%.2f:d=1.5[a]" % max(0, target_seconds - 1.5),
                "-map", "0:v", "-map", "[a]",
                "-c:v", "copy", "-c:a", "aac", "-b:a", "192k",
                "-shortest", str(final),
            ], check=True, timeout=600)
        else:
            shutil.copy(silent, final)

        print(f"done: {final}")
        return str(final)

    finally:
        shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    import sys
    desc = " ".join(sys.argv[1:]) or "best recent moments, upbeat"
    build_reel(desc)
```

---

## Step 5 — Run it

```bash
source ~/.venvs/media/bin/activate
set -a; source ~/.config/aihub/.env; set +a
export MEDIA_ROOTS="$HOME/Media:$HOME/Downloads"
cd ~/Documents/Code/aihub

python build_reel.py "30 second beach trip, upbeat"
open ~/Media/Output/
```

**Expected time:** 1–3 minutes for a 30 second reel, mostly ffmpeg encoding.

---

## Step 6 — Connect to Telegram

The handler already exists in file 05. Once this works:

```
/reel 30 second beach trip, upbeat
```

To get the finished file sent back to you, add this to the agent's
`h_reel_render` handler:

```python
def h_reel_render(payload):
    from build_reel import build_reel
    out = build_reel(
        description=payload.get("description", ""),
        media_root=MEDIA_ROOT,
        target_seconds=int(payload.get("seconds", 30)),
    )

    # Send the video back through Telegram, if it is small enough
    chat_id = payload.get("_reply_to")
    size_mb = Path(out).stat().st_size / 1_000_000
    if TG_TOKEN and chat_id and size_mb < 45:      # Telegram bot limit ~50 MB
        with open(out, "rb") as f:
            requests.post(
                f"https://api.telegram.org/bot{TG_TOKEN}/sendVideo",
                data={"chat_id": chat_id},
                files={"video": f},
                timeout=600,
            )

    return {"output": str(Path(out).relative_to(MEDIA_ROOT)),
            "size_mb": round(size_mb, 1)}
```

---

## Step 7 — Improvements worth adding later

| Improvement | How | Value |
|---|---|---|
| **Beat-locked cuts** | Snap every cut boundary to the nearest beat time in Python *after* the AI plans, instead of trusting it | High. Makes edits feel professional |
| Shaky-clip filter | Reject clips with high motion using ffmpeg's motion vectors | Medium |
| Text overlay | `drawtext` filter, with the caption from the database | Medium |
| Speed ramps | `setpts` filter on selected cuts | Nice for action shots |
| Multiple aspect ratios | Render 1080×1920 and 1080×1080 from the same plan | Handy |
| Try three plans, pick one | Call the AI three times, render all, choose | Costs 3× — still under ₹0.20 |

**Beat locking in code** is the highest-value one and does not need AI:

```python
def snap_to_beats(plan, beats, tolerance=0.25):
    """Move each cut boundary to the nearest beat, if one is close enough."""
    if not beats:
        return plan
    t = 0.0
    for cut in plan["cuts"]:
        length = cut["out"] - cut["in"]
        want = t + length
        nearest = min(beats, key=lambda b: abs(b - want))
        if abs(nearest - want) <= tolerance:
            cut["out"] = cut["in"] + (nearest - t)
        t += cut["out"] - cut["in"]
    return plan
```

---

## Troubleshooting

| Problem | Cause | Fix |
|---|---|---|
| "fewer than 3 scored clips" | Ranker not run yet | Do file 03 first |
| Plan validation fails repeatedly | Model too weak for structured output | Use `tier2-cheap` (DeepSeek), not a local 8B model |
| JSON parse error | Model wrapped the JSON in fences | The fence stripper handles it; if not, add "Return raw JSON, no markdown" to the prompt |
| ffmpeg "Invalid data" | Corrupt or unusual source file | Check that file plays; re-encode it first |
| Video and audio out of sync | Frame rates differ between clips | Already handled by `fps={FPS}` in the filter |
| Very slow rendering | `preset` too slow, or 4K sources | Use `-preset ultrafast` for drafts |
| Music silent in output | Protected file, or wrong path | Protected Apple Music files cannot be used. Use a file you own |
| Photos look stretched | Aspect ratio mismatch | The `crop` filter handles it; check the source is not already vertical |

---

## Prompt for AI

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

## Check you are done

- [ ] `beats.py` reports a sensible BPM for your music
- [ ] `build_manifest` returns at least 6 clips
- [ ] `plan_reel` returns valid JSON that passes validation
- [ ] A reel renders and plays correctly
- [ ] Music is present and fades out at the end
- [ ] Video is 1080×1920 vertical
- [ ] `/reel ...` from Telegram produces a file
- [ ] Cost per reel is under ₹0.10 (check the LiteLLM dashboard)

---

## ⚠️ Verify with AI

| # | Unverified | Why it matters |
|---|---|---|
| 1 | ffmpeg filter syntax for zoompan and afade | Flags shift between versions |
| 2 | librosa current beat-tracking API | `beat_track` return shape has changed before |
| 3 | Whether hardware encoding is available on M1 | Would speed renders up a lot |
| 4 | Correct settings for Instagram/YouTube Shorts | Wrong specs get re-encoded badly |

Paste this into Gemini or any web-enabled AI, then update this file with what comes back.

```
RULES — follow exactly:
- Use only the official ffmpeg documentation and wiki, the librosa documentation,
  and the platform's own creator/help documentation. No blogs, no tutorials.
- Give the source URL and version for each answer.
- If a filter or flag is deprecated, say so and give the replacement.

I am assembling short vertical videos on an M1 Pro Mac with ffmpeg, driven by a
JSON edit list. Photos become clips with a slow zoom; clips are cut, scaled,
concatenated, and one music track is laid over the top with a fade-out.

1. Verify this scale-and-crop-to-vertical filter chain is still correct and
   efficient, and suggest a better one if not:
   scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,fps=30,format=yuv420p
2. Verify the zoompan syntax for a slow zoom on a still image, and give the
   official example:
   zoompan=z='min(zoom+0.0012,1.25)':d=<frames>:s=1080x1920:fps=30
   Is there a better-maintained filter for a Ken Burns effect now?
3. Is the concat demuxer still the recommended way to join pre-encoded clips with
   identical parameters, or is there something better? Give the official example.
4. Verify the afade filter syntax for fading audio out over the last 1.5 seconds
   of a known-length video.
5. Does ffmpeg on Apple Silicon support hardware-accelerated H.264 encoding via
   VideoToolbox? If so, give the exact flags, and say what quality or
   compatibility trade-offs the documentation notes versus libx264.
6. librosa: current API for tempo and beat times. Paste the official example.
   What exactly does `beat_track` return in the current version — a scalar tempo
   or an array? Any alternative the docs now prefer?
7. Instagram Reels and YouTube Shorts: currently recommended resolution, frame
   rate, video codec, audio codec, bitrate and maximum duration, from each
   platform's own help documentation.

Output as: | # | Answer | Official example | Source URL | Version |
```

---

Next: [09 — Apple Music automation](A3-music-out-of-scope.md)
