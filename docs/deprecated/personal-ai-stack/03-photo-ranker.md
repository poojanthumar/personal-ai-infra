# 07 — Photo and Video Ranker

> ⚠️ **Anything marked ⚠️ in this file is unverified.** All of it is answered
> by the prompt in [⚠️ Verify with AI](#-verify-with-ai) at the bottom — paste it
> into Gemini or any web-enabled AI and update this file with the result.

**Goal:** score every photo and video clip in a 10 GB+ folder by how good it
looks, so you can pick the best shots for reels and albums.

**Time:** 2–3 hours to build. About 15–25 minutes to run on 5,000 photos.

**Cost:** ₹0. Completely local. Nothing leaves your Mac.

**Build this first after file 02.** It gives you real value on day one and it
produces the data every other media feature needs.

---



## Why this is free

The obvious approach — send the photos to an AI model and ask "which look
best?" — is impossibly expensive. Here is the arithmetic for **one minute** of
1080p video at 1 frame per second (60 frames):


| Approach                                                        | Cost                       |
| --------------------------------------------------------------- | -------------------------- |
| Claude Opus 5, standard-resolution frames (~1,600 tokens each)  | ~96,000 tokens ≈ **₹85**   |
| Claude Opus 5, high-resolution frames (up to 4,784 tokens each) | ~287,000 tokens ≈ **₹250** |
| **CLIP on your Mac**                                            | **₹0**, about 1–2 seconds  |


Your 10 GB folder is roughly 3–5 hours of footage. Through a premium model that
is **₹15,000–25,000 for one pass** — five to ten times your entire monthly
budget, for a job your Mac does free in fifteen minutes.

So: **the model never touches your media.** Local tools score it and describe
it, and only a small text summary is ever sent anywhere.

---



## What "aesthetic score" actually means

You score on separate, independent axes and store all of them. That way you can
re-rank later without re-processing 10 GB.


| Axis           | How it is measured                                    | What it catches                                         |
| -------------- | ----------------------------------------------------- | ------------------------------------------------------- |
| **Aesthetics** | CLIP image features → a small trained scoring head    | "Does this look good?"                                  |
| **Sharpness**  | Variance of the Laplacian (an edge-detection measure) | Blurry and out-of-focus shots                           |
| **Exposure**   | Histogram clipping at both ends                       | Too dark, blown-out highlights                          |
| **Faces**      | Face detection, plus eyes-open where possible         | Portraits worth keeping                                 |
| **Novelty**    | Perceptual hash + CLIP similarity                     | Collapses 12 near-identical burst shots to the best one |
| **Semantics**  | Local vision model caption                            | Lets you ask for "the beach ones"                       |


**The dedup axis alone transforms a camera roll.** Most people's "10 GB" is
really 2 GB of distinct moments plus 8 GB of near-duplicates.

---



## The final score is *your* taste, not a stranger's

The aesthetic model was trained on other people's ratings. To make it match
yours, you rate about 100 photos once and fit the weights to your ratings. This
step is what makes the tool feel personal rather than generic. See step 6.

---



## Step 1 — Install

Already done in file 02, step 8. Confirm:

```bash
source ~/.venvs/media/bin/activate
python -c "import torch, open_clip, PIL, imagehash, cv2; \
print('torch MPS:', torch.backends.mps.is_available())"
ffmpeg -version | head -1
exiftool -ver
```

`torch MPS: True` is required. Without it you are running on CPU and everything
will be roughly 5× slower.

---



## Step 2 — Get the aesthetic scoring head

CLIP turns an image into a list of 768 numbers. The aesthetic head is a tiny
model that turns those numbers into a score out of 10.

✅ **Verified location (Aug 2026):** the official repository is

```
https://github.com/christophschuhmann/improved-aesthetic-predictor
```

The weight files it contains are:

```
ava+logos-l14-linearMSE.pth     ← use this one
ava+logos-l14-reluMSE.pth
```

The `l14` in the name means it expects **CLIP ViT-L/14** embeddings, which is
what the script below uses. Read the repository's README to confirm the exact
preprocessing before relying on the absolute score values.

```bash
mkdir -p ~/.cache/aesthetic
# place ava+logos-l14-linearMSE.pth in that folder
ls -la ~/.cache/aesthetic/
```

⚠️ No officially designated successor to this predictor exists from the same
maintainers. Other aesthetic scorers exist but none is clearly better maintained.

**If you cannot get the weights:** the script below falls back to a
CLIP-prompt-based score (comparing each image against text like "a beautiful
professional photograph" versus "a blurry amateur snapshot"). It is less
accurate but works with no extra download, and you can add the head later.
Because you tune the weights to your own ratings in step 6 anyway, the fallback
is more usable than it sounds.

---



## Step 3 — The database

One SQLite file holds every score. Scoring is slow; querying must be instant.

Save as `~/Documents/Code/aihub/media_db.py`:

```python
"""SQLite store for media scores. One row per file (or per video scene)."""

import sqlite3
from pathlib import Path

SCHEMA = """
CREATE TABLE IF NOT EXISTS media (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  path         TEXT NOT NULL,          -- relative to MEDIA_ROOT
  kind         TEXT NOT NULL,          -- photo | video_scene
  scene_start  REAL,                   -- seconds, videos only
  scene_end    REAL,
  width        INTEGER,
  height       INTEGER,
  taken_at     TEXT,                   -- from EXIF if available
  gps_lat      REAL,
  gps_lon      REAL,

  aesthetic    REAL,                   -- 0-10, higher is better
  sharpness    REAL,                   -- 0-1
  exposure     REAL,                   -- 0-1, 1 = well exposed
  faces        INTEGER DEFAULT 0,
  phash        TEXT,                   -- perceptual hash for dedup
  dup_group    INTEGER,                -- same number = near-duplicates
  is_best_of_group INTEGER DEFAULT 0,

  caption      TEXT,                   -- from the local vision model
  final_score  REAL,                   -- weighted combination

  scored_at    TEXT NOT NULL,
  UNIQUE(path, scene_start)
);

CREATE INDEX IF NOT EXISTS idx_media_score ON media(final_score DESC);
CREATE INDEX IF NOT EXISTS idx_media_path  ON media(path);
CREATE INDEX IF NOT EXISTS idx_media_dup   ON media(dup_group);

-- Your own ratings, used to learn your taste
CREATE TABLE IF NOT EXISTS my_ratings (
  path    TEXT PRIMARY KEY,
  rating  INTEGER NOT NULL,            -- 1 = bad, 5 = excellent
  rated_at TEXT NOT NULL
);
"""


def connect(db_path="~/Media/index.sqlite"):
    """Open the database, creating tables on first use."""
    p = Path(db_path).expanduser()
    p.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(p)
    conn.row_factory = sqlite3.Row
    conn.executescript(SCHEMA)
    return conn
```

---



## Step 4 — The scoring script

Save as `~/Documents/Code/aihub/rank_media.py`.

```python
#!/usr/bin/env python3
"""
Score photos and video scenes on how good they look. All local, all free.

Usage:
    python rank_media.py ~/Media/Photos
"""

import os, sys, math, subprocess, json
from datetime import datetime, timezone
from pathlib import Path

import torch, open_clip, numpy as np, cv2
from PIL import Image
import imagehash
from tqdm import tqdm

from media_db import connect

PHOTO_EXT = {".jpg", ".jpeg", ".png", ".heic", ".heif", ".webp", ".tif", ".tiff"}
VIDEO_EXT = {".mov", ".mp4", ".m4v", ".avi", ".mkv"}

DEVICE = "mps" if torch.backends.mps.is_available() else "cpu"
AES_WEIGHTS = Path("~/.cache/aesthetic/ava+logos-l14-linearMSE.pth").expanduser()


# ------------------------------------------------------------------ models

def load_clip():
    """Load CLIP once. This takes a few seconds; reuse it for every image."""
    model, _, preprocess = open_clip.create_model_and_transforms(
        "ViT-L-14", pretrained="openai"
    )
    model = model.to(DEVICE).eval()
    return model, preprocess


def load_aesthetic_head():
    """
    Load the small model that turns CLIP features into a 0-10 score.
    Returns None if the weights file is missing (we then use a fallback).
    """
    if not AES_WEIGHTS.exists():
        print("NOTE: aesthetic weights not found, using CLIP-prompt fallback")
        return None
    head = torch.nn.Linear(768, 1)
    state = torch.load(AES_WEIGHTS, map_location="cpu")
    # The published file stores the weights under different key names
    # depending on version; take the first 2D tensor we find.
    for k, v in state.items():
        if hasattr(v, "shape") and len(v.shape) == 2:
            head.weight.data = v
        elif hasattr(v, "shape") and len(v.shape) == 1:
            head.bias.data = v
    return head.to(DEVICE).eval()


# ----------------------------------------------------------------- scoring

def clip_features(img, model, preprocess):
    """Turn one image into 768 numbers, normalised to length 1."""
    t = preprocess(img).unsqueeze(0).to(DEVICE)
    with torch.no_grad():
        f = model.encode_image(t)
        f = f / f.norm(dim=-1, keepdim=True)
    return f


def aesthetic_score(feats, head, model, fallback_text_feats):
    """Score 0-10. Uses the trained head when available, prompts otherwise."""
    if head is not None:
        with torch.no_grad():
            return float(head(feats).item())
    # Fallback: how much more like "good photo" than "bad photo" is this?
    with torch.no_grad():
        sims = (feats @ fallback_text_feats.T).squeeze(0)
        good, bad = sims[0].item(), sims[1].item()
    return float(max(0.0, min(10.0, 5.0 + (good - bad) * 50)))


def sharpness_score(bgr):
    """Variance of the Laplacian. Blurry images have low edge variance."""
    gray = cv2.cvtColor(bgr, cv2.COLOR_BGR2GRAY)
    var = cv2.Laplacian(gray, cv2.CV_64F).var()
    # Squash to 0-1. 500 is roughly "clearly sharp" for phone photos.
    return float(min(1.0, var / 500.0))


def exposure_score(bgr):
    """1.0 = well exposed. Drops when many pixels are pure black or white."""
    gray = cv2.cvtColor(bgr, cv2.COLOR_BGR2GRAY)
    total = gray.size
    too_dark = float((gray < 8).sum()) / total
    too_bright = float((gray > 247).sum()) / total
    return float(max(0.0, 1.0 - (too_dark + too_bright) * 3.0))


def count_faces(bgr, cascade):
    """Rough face count using OpenCV's built-in detector. Fast and free."""
    gray = cv2.cvtColor(bgr, cv2.COLOR_BGR2GRAY)
    faces = cascade.detectMultiScale(gray, 1.1, 5, minSize=(40, 40))
    return int(len(faces))


# ------------------------------------------------------------------ EXIF

def read_exif(path):
    """Date and GPS, if the file has them. Used later for album grouping."""
    try:
        out = subprocess.run(
            ["exiftool", "-j", "-DateTimeOriginal",
             "-GPSLatitude#", "-GPSLongitude#", str(path)],
            capture_output=True, text=True, timeout=20,
        )
        d = json.loads(out.stdout)[0]
        return (d.get("DateTimeOriginal"),
                d.get("GPSLatitude"), d.get("GPSLongitude"))
    except Exception:
        return (None, None, None)


# ----------------------------------------------------------------- videos

def video_scenes(path, max_scenes=40):
    """
    Split a video into scenes and return one representative time per scene.
    We score one frame per scene instead of every frame — 60x cheaper and
    almost as good for choosing clips.
    """
    from scenedetect import open_video, SceneManager, ContentDetector
    try:
        video = open_video(str(path))
        sm = SceneManager()
        sm.add_detector(ContentDetector(threshold=27.0))
        sm.detect_scenes(video, show_progress=False)
        scenes = sm.get_scene_list()
    except Exception:
        scenes = []

    if not scenes:
        return [(0.0, 3.0, 1.0)]   # whole clip, sample at 1 second

    out = []
    for start, end in scenes[:max_scenes]:
        s, e = start.get_seconds(), end.get_seconds()
        out.append((s, e, s + (e - s) / 2))   # sample the middle
    return out


def grab_frame(path, seconds):
    """Pull one frame out of a video as a numpy image, using ffmpeg."""
    import tempfile
    with tempfile.NamedTemporaryFile(suffix=".jpg", delete=False) as tmp:
        subprocess.run(
            ["ffmpeg", "-y", "-loglevel", "error",
             "-ss", str(seconds), "-i", str(path),
             "-frames:v", "1", "-q:v", "3", tmp.name],
            check=True, timeout=120,
        )
        img = cv2.imread(tmp.name)
        os.unlink(tmp.name)
    return img


# -------------------------------------------------------------------- main

def rank_folder(folder, db_path="~/Media/index.sqlite", weights=None):
    """
    Score everything in a folder. Safe to run repeatedly — already-scored
    files are skipped.
    """
    folder = Path(folder).expanduser().resolve()
    media_root = Path(os.environ.get("MEDIA_ROOT", "~/Media")).expanduser().resolve()

    weights = weights or {
        "aesthetic": 0.50, "sharpness": 0.25,
        "exposure": 0.15, "faces": 0.10,
    }

    conn = connect(db_path)
    model, preprocess = load_clip()
    head = load_aesthetic_head()
    cascade = cv2.CascadeClassifier(
        cv2.data.haarcascades + "haarcascade_frontalface_default.xml"
    )

    # Text features for the fallback scorer
    tok = open_clip.get_tokenizer("ViT-L-14")
    with torch.no_grad():
        tf = model.encode_text(tok([
            "a beautiful, well composed, professional photograph",
            "a blurry, badly exposed, amateur snapshot",
        ]).to(DEVICE))
        tf = tf / tf.norm(dim=-1, keepdim=True)

    # Collect work
    items = []          # (path, kind, start, end, sample_seconds)
    for p in sorted(folder.rglob("*")):
        if not p.is_file():
            continue
        ext = p.suffix.lower()
        if ext in PHOTO_EXT:
            items.append((p, "photo", None, None, None))
        elif ext in VIDEO_EXT:
            for s, e, mid in video_scenes(p):
                items.append((p, "video_scene", s, e, mid))

    print(f"{len(items)} items to consider in {folder}")
    scored = 0

    for path, kind, start, end, sample in tqdm(items, unit="item"):
        rel = str(path.relative_to(media_root))

        # Skip if already done
        row = conn.execute(
            "SELECT 1 FROM media WHERE path=? AND IFNULL(scene_start,-1)=?",
            (rel, start if start is not None else -1),
        ).fetchone()
        if row:
            continue

        try:
            if kind == "photo":
                bgr = cv2.imread(str(path))
                if bgr is None:            # HEIC often needs PIL
                    bgr = cv2.cvtColor(
                        np.array(Image.open(path).convert("RGB")),
                        cv2.COLOR_RGB2BGR)
            else:
                bgr = grab_frame(path, sample)
            if bgr is None:
                continue

            pil = Image.fromarray(cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB))
            feats = clip_features(pil, model, preprocess)

            aes = aesthetic_score(feats, head, model, tf)
            shp = sharpness_score(bgr)
            exp = exposure_score(bgr)
            nfaces = count_faces(bgr, cascade)
            ph = str(imagehash.phash(pil))

            taken, lat, lon = read_exif(path) if kind == "photo" else (None, None, None)
            h, w = bgr.shape[:2]

            final = (weights["aesthetic"] * (aes / 10.0)
                     + weights["sharpness"] * shp
                     + weights["exposure"] * exp
                     + weights["faces"] * min(1.0, nfaces / 3.0)) * 10.0

            conn.execute("""
                INSERT OR REPLACE INTO media
                (path, kind, scene_start, scene_end, width, height,
                 taken_at, gps_lat, gps_lon, aesthetic, sharpness, exposure,
                 faces, phash, final_score, scored_at)
                VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
            """, (rel, kind, start, end, w, h, taken, lat, lon,
                  round(aes, 3), round(shp, 3), round(exp, 3), nfaces, ph,
                  round(final, 3), datetime.now(timezone.utc).isoformat()))
            scored += 1

            if scored % 200 == 0:
                conn.commit()

        except Exception as e:
            print(f"skip {rel}: {type(e).__name__}: {e}")

    conn.commit()
    mark_duplicates(conn)

    top = [dict(r) for r in conn.execute("""
        SELECT path, scene_start, round(final_score,2) AS score,
               round(aesthetic,2) AS aesthetic, faces
        FROM media WHERE is_best_of_group=1
        ORDER BY final_score DESC LIMIT 20
    """)]

    total = conn.execute("SELECT COUNT(*) FROM media").fetchone()[0]
    conn.close()
    return {"count": scored, "total_in_db": total, "top": top}


def mark_duplicates(conn, max_distance=6):
    """
    Group near-identical shots and mark only the best one in each group.
    This is what turns 12 burst photos into 1 keeper.
    """
    rows = conn.execute(
        "SELECT id, phash, final_score FROM media WHERE phash IS NOT NULL"
    ).fetchall()

    groups, assigned = [], {}
    for r in rows:
        h = imagehash.hex_to_hash(r["phash"])
        placed = False
        for gi, rep in enumerate(groups):
            if h - rep <= max_distance:
                assigned[r["id"]] = gi
                placed = True
                break
        if not placed:
            groups.append(h)
            assigned[r["id"]] = len(groups) - 1

    conn.execute("UPDATE media SET dup_group=NULL, is_best_of_group=0")
    for mid, gi in assigned.items():
        conn.execute("UPDATE media SET dup_group=? WHERE id=?", (gi, mid))

    conn.execute("""
        UPDATE media SET is_best_of_group=1
        WHERE id IN (
          SELECT id FROM media m1
          WHERE m1.final_score = (
            SELECT MAX(m2.final_score) FROM media m2
            WHERE m2.dup_group = m1.dup_group
          )
        )
    """)
    conn.commit()

    n_groups = len(groups)
    n_items = len(rows)
    print(f"dedup: {n_items} items collapse to {n_groups} distinct moments")


if __name__ == "__main__":
    folder = sys.argv[1] if len(sys.argv) > 1 else "~/Media/Photos"
    result = rank_folder(folder)
    print(json.dumps(result, indent=2)[:3000])
```



---



## Step 5 — Run it

```bash
source ~/.venvs/media/bin/activate
export MEDIA_ROOTS="$HOME/Media:$HOME/Downloads"

🚨 **`caffeinate -s` will not save a long run from a closed lid** — it only works
on AC power and clamshell sleep overrides it. Leave the lid open for big scans.
The good news: **the scan is resumable** — already-scored files are skipped, so
re-running picks up where it stopped. Details in
[05 — Mac agent](05-mac-agent.md) §7.
cd ~/Documents/Code/aihub

# Start small — try 20-30 files first
python rank_media.py ~/Media/Photos/Test

# Then the real folder
caffeinate -s python rank_media.py ~/Media/Photos
```

`caffeinate -s` stops your Mac sleeping mid-job.

**Expected speed on M1 Pro:** roughly 15–30 photos per second, so about
15–25 minutes for 5,000 photos. Videos are slower because each scene needs a
frame extracted with ffmpeg.

**Watch the dedup line at the end.** On a typical camera roll you should see
something like "5,000 items collapse to 1,800 distinct moments" — that number
is the single most useful thing this tool produces.

---



## Step 6 — Teach it your taste

The scores now reflect a general model's taste. Fifteen minutes of rating makes
them reflect yours.

**6a. Export 100 photos to rate**, spread across the score range so you cover
good and bad:

```bash
sqlite3 ~/Media/index.sqlite <<'SQL' > ~/Media/to_rate.csv
.mode csv
SELECT path, round(final_score,2) FROM media
WHERE is_best_of_group=1
ORDER BY RANDOM() LIMIT 100;
SQL
```

**6b. Rate them.** Open each and give it 1–5. Put your ratings in the database:

```bash
# One example. Do this for each photo you rate.
sqlite3 ~/Media/index.sqlite \
  "INSERT OR REPLACE INTO my_ratings VALUES ('Photos/IMG_4412.jpg', 5, datetime('now'));"
```

For 100 photos, use the AI prompt at the end of this file to generate a small
rating tool rather than typing 100 SQL statements.

**6c. Fit the weights to your ratings:**

```python
# fit_weights.py
import numpy as np
from media_db import connect

conn = connect()
rows = conn.execute("""
    SELECT m.aesthetic/10.0 AS a, m.sharpness AS s, m.exposure AS e,
           MIN(1.0, m.faces/3.0) AS f, r.rating AS y
    FROM media m JOIN my_ratings r ON r.path = m.path
""").fetchall()

if len(rows) < 30:
    raise SystemExit(f"Only {len(rows)} ratings. Rate at least 30 first.")

X = np.array([[r["a"], r["s"], r["e"], r["f"]] for r in rows])
y = np.array([r["y"] for r in rows], dtype=float)

# Least squares, then force weights to be positive and sum to 1
w, *_ = np.linalg.lstsq(X, y, rcond=None)
w = np.clip(w, 0, None)
w = w / w.sum()

print("Your weights:")
for name, val in zip(["aesthetic", "sharpness", "exposure", "faces"], w):
    print(f'  "{name}": {val:.3f},')
```

Paste the printed weights into `rank_folder`'s default `weights` dictionary,
then re-score. Re-scoring recalculates `final_score` from the stored axis values
— you do **not** need to re-run CLIP, so it takes seconds instead of minutes.

---



## Step 7 — Add captions so you can search by words

This is what lets you later say "make a reel about the beach trip".

```python
# caption_media.py — run after ranking
import base64, requests, sqlite3
from pathlib import Path
from media_db import connect

LITELLM = "http://localhost:4000/v1/chat/completions"
KEY = "sk-your-automation-key"
ROOT = Path("~/Media").expanduser()

conn = connect()
rows = conn.execute("""
    SELECT id, path FROM media
    WHERE caption IS NULL AND is_best_of_group=1
    ORDER BY final_score DESC LIMIT 500
""").fetchall()

for r in rows:
    img = ROOT / r["path"]
    b64 = base64.b64encode(img.read_bytes()).decode()

    resp = requests.post(LITELLM,
        headers={"Authorization": f"Bearer {KEY}"},
        json={
            # private-local has NO cloud fallback. Photos never leave the Mac.
            "model": "private-local",
            "messages": [{"role": "user", "content": [
                {"type": "text", "text":
                 "Describe this photo in under 15 words. "
                 "Mention the main subject, the setting, and the light. "
                 "No opinions, no preamble."},
                {"type": "image_url",
                 "image_url": {"url": f"data:image/jpeg;base64,{b64}"}},
            ]}],
            "metadata": {"tags": ["job:caption_batch"]},
        }, timeout=180)

    if resp.status_code != 200:
        print(f"skip {r['path']}: HTTP {resp.status_code}")
        continue

    cap = resp.json()["choices"][0]["message"]["content"].strip()
    conn.execute("UPDATE media SET caption=? WHERE id=?", (cap, r["id"]))
    print(f"{r['path']}: {cap}")

conn.commit()
```

**Note the model name:** `private-local`**.** That is the tier with no cloud
fallback. If your Mac is busy, this fails rather than sending your photos to
Google. That is deliberate.

⚠️ Base64 makes files about 33% larger. For a 4 MB photo that is a ~5.3 MB
request body. Resize to about 1024px on the long edge first to keep it fast:

```python
from PIL import Image
import io
im = Image.open(img).convert("RGB")
im.thumbnail((1024, 1024))
buf = io.BytesIO(); im.save(buf, "JPEG", quality=85)
b64 = base64.b64encode(buf.getvalue()).decode()
```

---



## Step 8 — Useful queries

```bash
# The 20 genuinely best distinct shots
sqlite3 -header -column ~/Media/index.sqlite "
SELECT path, round(final_score,2) score, faces
FROM media WHERE is_best_of_group=1
ORDER BY final_score DESC LIMIT 20;"

# Best portraits
sqlite3 -header -column ~/Media/index.sqlite "
SELECT path, round(final_score,2) score, faces
FROM media WHERE faces >= 1 AND is_best_of_group=1
ORDER BY final_score DESC LIMIT 20;"

# Wasted space — near duplicates you can delete
sqlite3 ~/Media/index.sqlite "
SELECT COUNT(*) AS deletable FROM media WHERE is_best_of_group=0;"

# Best video clips for a reel
sqlite3 -header -column ~/Media/index.sqlite "
SELECT path, scene_start, scene_end, round(final_score,2) score
FROM media WHERE kind='video_scene'
ORDER BY final_score DESC LIMIT 15;"

# Search by caption
sqlite3 -header -column ~/Media/index.sqlite "
SELECT path, caption, round(final_score,2) score
FROM media WHERE caption LIKE '%beach%'
ORDER BY final_score DESC LIMIT 10;"
```

---



## Step 9 — Connect it to Telegram

The handler in file 05 already calls `rank_folder`. Once this file works:

```
/rank Photos/Beach
```

The Mac scores the folder and messages you the top 10. Cost: ₹0.

---



## Troubleshooting


| Problem                           | Cause                                 | Fix                                                                                             |
| --------------------------------- | ------------------------------------- | ----------------------------------------------------------------------------------------------- |
| Very slow (under 5 images/sec)    | Running on CPU                        | Check `torch.backends.mps.is_available()`                                                       |
| `cv2.imread` returns None on HEIC | OpenCV can't read HEIC                | The PIL fallback in the code handles it; make sure `pillow-heif` is installed if it still fails |
| Aesthetic scores all near 5       | Weights file missing, using fallback  | Get the LAION weights (step 2)                                                                  |
| Memory error partway through      | CLIP plus a big model loaded together | Close Ollama during a big scoring run                                                           |
| Dedup groups everything together  | `max_distance` too high               | Lower it to 4                                                                                   |
| Dedup groups nothing              | Too low                               | Raise it to 8                                                                                   |
| Video scenes not detected         | Threshold wrong for your footage      | Try `ContentDetector(threshold=20)` for subtle cuts                                             |
| Job dies at exactly the same file | Corrupt file                          | The try/except skips it; check the printed name                                                 |


---



## Prompt for AI

A well-scoped, genuinely useful tool to hand off.

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



## Check you are done

- [ ] `torch MPS: True`
- [ ] A test folder of 20 photos scores without errors
- [ ] `index.sqlite` exists and has rows
- [ ] The dedup line shows a meaningful reduction
- [ ] The top-20 query returns photos you agree are your best
- [ ] You rated at least 30 photos and fitted your own weights
- [ ] Captions generated using `private-local`
- [ ] `/rank Photos/Test` from Telegram works end to end

---



## ✅ Verified 2 Aug 2026 — three upgrades worth taking



### 1. 🏆 Replace Haar cascades with MediaPipe

> *"OpenCV Haar Cascades: **SUPERSEDED.** Highly sensitive to lighting/rotation,
> produces severe false positives, and lacks modern hardware acceleration."*

MediaPipe Face Mesh gives you faces **plus eye-aspect-ratio** — so you get
eyes-open detection, which the axis table promised and Haar can't deliver.

```bash
pip install mediapipe        # v0.10.x, runs on Apple Silicon, no compilation
```

