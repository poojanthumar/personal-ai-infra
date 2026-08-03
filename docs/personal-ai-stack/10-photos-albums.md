# 10 — Photos and Albums

**Goal:** group your photos into meaningful albums automatically — by trip, by
event, by who is in them — and give each album a sensible name.

**Time:** 2–3 hours.

**Cost:** ₹0 for grouping. About ₹0.10 for naming 50 albums.

**Requires:** file 07, so photos already have scores and captions.

---

## First, the bad news about Google Photos

⚠️ Around March 2025, Google restricted the Photos API. Outside applications can
generally only see media they created themselves. Broad read access to your
whole library was removed. User-chosen selection moved to a separate "Picker"
flow, which is for one-off choices, not for automated album building.

**So "point an AI at my Google Photos and build albums" is not buildable.**
That is the one requirement from your original list that cannot be met as
described.

⚠️ Check the current state at https://developers.google.com/photos before ruling
it out permanently — but plan for the alternatives.

### Three working alternatives

| Option | Best when | Cost |
|---|---|---|
| **Immich** — a photo server you run yourself | 🏆 You want a real photo app with AI search, face grouping, and phone apps | ₹0 |
| **osxphotos** — read your Apple Photos library | 🏆 You already keep everything in Apple Photos | ₹0 |
| **Google Takeout** — download a copy | One-time migration off Google | ₹0 |

Pick based on where your photos actually live today.

---

# OPTION A — Immich (recommended)

Immich is a self-hosted photo app. It looks and works like Google Photos, and
it already includes the AI you want: text search over your photos, and face
grouping.

## Step 1 — Install

```bash
mkdir -p ~/Documents/Code/immich && cd ~/Documents/Code/immich

# Get their official compose files
curl -o docker-compose.yml \
  https://github.com/immich-app/immich/releases/latest/download/docker-compose.yml
curl -o .env \
  https://github.com/immich-app/immich/releases/latest/download/example.env
```

Edit `.env`:

```bash
UPLOAD_LOCATION=/Users/poojanthumar/Media/immich-library
DB_DATA_LOCATION=/Users/poojanthumar/Media/immich-db
DB_PASSWORD=make-up-something-long
```

⚠️ Immich changes fast. Read their release notes before upgrading — they
occasionally require manual migration steps.

```bash
docker compose up -d
docker compose logs -f immich-server     # wait for "Immich Server is listening"
```

Open http://localhost:2283 and create your admin account.

## Step 2 — Memory warning

Immich runs several containers including a machine-learning one. On a 16 GB Mac
that is significant.

```bash
docker stats --no-stream
```

If it is using too much, disable the heavy ML features you do not need in
**Administration → Settings → Machine Learning**. Keep **CLIP search** and
**face detection**; you can turn off duplicate detection since file 07 already
does that better for your purposes.

**If it is too heavy for your Mac,** run Immich on the Oracle free VM instead
(24 GB RAM) and keep the originals on your Mac, syncing selectively.

## Step 3 — Import your photos

```bash
# One-off import of a folder
docker exec -it immich_server \
  /usr/src/app/bin/immich-admin upload /path/inside/container
```

Easier: use the Immich phone app to upload, or the **external library** feature
which reads a folder in place without copying — better for a 10 GB collection.

**Administration → External Libraries → Add** → point at `~/Media/Photos`.

## Step 4 — Query Immich from your scripts

Immich has a REST API. Create an API key in **Account Settings → API Keys**.

```python
# immich_client.py
import os, requests

BASE = os.environ.get("IMMICH_URL", "http://localhost:2283/api")
KEY  = os.environ["IMMICH_KEY"]
H    = {"x-api-key": KEY}


def search_by_text(query, limit=50):
    """Immich's built-in CLIP search. Ask in plain words."""
    r = requests.post(f"{BASE}/search/smart",
                      headers=H, json={"query": query, "size": limit},
                      timeout=60)
    r.raise_for_status()
    return r.json()


def list_people():
    """Faces Immich has grouped. Name them once in the web UI first."""
    r = requests.get(f"{BASE}/people", headers=H, timeout=60)
    r.raise_for_status()
    return r.json()


def create_album(name, asset_ids):
    """Make an album from a list of Immich asset IDs."""
    r = requests.post(f"{BASE}/albums", headers=H,
                      json={"albumName": name, "assetIds": asset_ids},
                      timeout=60)
    r.raise_for_status()
    return r.json()
```

⚠️ Immich API paths change between versions. Check
`http://localhost:2283/api/api-docs` for the live list on your install.

---

# OPTION B — osxphotos (if you use Apple Photos)

Much lighter than Immich. No containers, no server.

```bash
source ~/.venvs/media/bin/activate
pip install osxphotos
```

macOS will ask for Photos permission the first time. Allow it.

```bash
# Basic info
osxphotos info

# Export everything the library knows, as JSON
osxphotos query --json > ~/Media/photos_library.json
```

What you get for free, already computed by Apple:

| Field | Useful for |
|---|---|
| `persons` | Who is in the photo — Apple already did face recognition |
| `place` | Reverse-geocoded location name, not just coordinates |
| `date` | When taken |
| `favorite` | Your own signal of what matters |
| `labels` | Apple's own scene classification |
| `score` | ⚠️ Apple's internal curation scores, if available |

**`persons` and `place` are the valuable ones.** Apple has already solved face
recognition and turning GPS coordinates into "Goa, India". Reusing that saves
you a lot of work.

```python
# apple_photos_import.py
import osxphotos, sqlite3
from pathlib import Path

DB = Path("~/Media/photos_meta.sqlite").expanduser()

conn = sqlite3.connect(DB)
conn.executescript("""
CREATE TABLE IF NOT EXISTS apple_photos (
  uuid       TEXT PRIMARY KEY,
  filename   TEXT,
  date       TEXT,
  place      TEXT,
  persons    TEXT,        -- comma separated
  labels     TEXT,
  favorite   INTEGER,
  lat        REAL,
  lon        REAL
);
""")

db = osxphotos.PhotosDB()
n = 0
for p in db.photos():
    conn.execute("""
        INSERT OR REPLACE INTO apple_photos
        VALUES (?,?,?,?,?,?,?,?,?)
    """, (p.uuid, p.original_filename,
          p.date.isoformat() if p.date else None,
          p.place.name if p.place else None,
          ",".join(p.persons or []),
          ",".join(p.labels or []),
          1 if p.favorite else 0,
          p.latitude, p.longitude))
    n += 1

conn.commit()
print(f"imported {n} photos")
```

---

## Step 5 — Group photos into events (works with either option)

This is the actual clever bit, and it needs no AI. Photos naturally cluster in
time and place.

Save as `~/Documents/Code/aihub/group_photos.py`:

```python
#!/usr/bin/env python3
"""
Group photos into events using time and location gaps.

The idea: a trip is a run of photos taken close together in time. When there is
a gap of many hours, or you moved a long way, that is a different event.
"""

import math
from datetime import datetime
from media_db import connect

# Tuning: raise the hours for looser grouping, lower for tighter
TIME_GAP_HOURS = 8
DISTANCE_GAP_KM = 30
MIN_PHOTOS_PER_EVENT = 4


def km_between(lat1, lon1, lat2, lon2):
    """Great-circle distance in kilometres."""
    if None in (lat1, lon1, lat2, lon2):
        return 0.0
    R = 6371.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp = p2 - p1
    dl = math.radians(lon2 - lon1)
    a = math.sin(dp/2)**2 + math.cos(p1)*math.cos(p2)*math.sin(dl/2)**2
    return 2 * R * math.asin(math.sqrt(a))


def group_events(db_path="~/Media/index.sqlite"):
    """Walk photos in time order and split whenever there is a big gap."""
    conn = connect(db_path)
    conn.execute("""
        CREATE TABLE IF NOT EXISTS events (
          id          INTEGER PRIMARY KEY AUTOINCREMENT,
          name        TEXT,
          start_date  TEXT, end_date TEXT,
          place       TEXT,
          photo_count INTEGER,
          best_photo  TEXT,
          named_by    TEXT          -- 'ai' or 'me'
        );
        CREATE TABLE IF NOT EXISTS event_photos (
          event_id INTEGER, media_id INTEGER,
          PRIMARY KEY (event_id, media_id)
        );
    """)

    rows = conn.execute("""
        SELECT id, path, taken_at, gps_lat, gps_lon, final_score, caption
        FROM media
        WHERE kind='photo' AND taken_at IS NOT NULL AND is_best_of_group=1
        ORDER BY taken_at
    """).fetchall()

    if not rows:
        conn.close()
        return {"events": 0, "note": "no photos with dates — check EXIF"}

    def parse(t):
        """EXIF dates use colons in the date part: 2026:07:31 14:22:01"""
        try:
            return datetime.strptime(t[:19], "%Y:%m:%d %H:%M:%S")
        except ValueError:
            try:
                return datetime.fromisoformat(t[:19])
            except ValueError:
                return None

    clusters, current = [], [rows[0]]

    for prev, cur in zip(rows, rows[1:]):
        t_prev, t_cur = parse(prev["taken_at"]), parse(cur["taken_at"])
        split = False

        if t_prev and t_cur:
            hours = abs((t_cur - t_prev).total_seconds()) / 3600.0
            if hours > TIME_GAP_HOURS:
                split = True

        d = km_between(prev["gps_lat"], prev["gps_lon"],
                       cur["gps_lat"], cur["gps_lon"])
        if d > DISTANCE_GAP_KM:
            split = True

        if split:
            clusters.append(current)
            current = [cur]
        else:
            current.append(cur)

    clusters.append(current)
    clusters = [c for c in clusters if len(c) >= MIN_PHOTOS_PER_EVENT]

    conn.execute("DELETE FROM event_photos")
    conn.execute("DELETE FROM events")

    for c in clusters:
        dates = [parse(r["taken_at"]) for r in c]
        dates = [d for d in dates if d]
        best = max(c, key=lambda r: r["final_score"] or 0)

        cur = conn.execute("""
            INSERT INTO events
            (name, start_date, end_date, photo_count, best_photo, named_by)
            VALUES (NULL,?,?,?,?,NULL)
        """, (min(dates).isoformat() if dates else None,
              max(dates).isoformat() if dates else None,
              len(c), best["path"]))
        eid = cur.lastrowid

        for r in c:
            conn.execute(
                "INSERT OR IGNORE INTO event_photos VALUES (?,?)", (eid, r["id"]))

    conn.commit()
    total = conn.execute("SELECT COUNT(*) FROM events").fetchone()[0]
    conn.close()
    print(f"found {total} events from {len(rows)} photos")
    return {"events": total, "photos": len(rows)}


if __name__ == "__main__":
    import json
    print(json.dumps(group_events(), indent=2))
```

**Tuning tip:** run it, look at the results, then adjust `TIME_GAP_HOURS`. Use
4 hours for tight events (a dinner, a match), 12–24 for whole trips.

---

## Step 6 — Name the events with AI

Grouping is free. Naming needs a little intelligence — but only over text.

```python
# name_events.py
import os, json, requests
from media_db import connect

LITELLM = os.environ.get("LITELLM_URL", "http://localhost:4000/v1")
KEY = os.environ["LITELLM_KEY"]


def name_events(model="tier0-local"):
    """
    Name each event from its dates and its photo captions.
    Only text is sent. No images. Local model is good enough for this.
    """
    conn = connect()
    events = conn.execute("SELECT * FROM events WHERE name IS NULL").fetchall()

    for ev in events:
        caps = [r["caption"] for r in conn.execute("""
            SELECT m.caption FROM event_photos ep
            JOIN media m ON m.id = ep.media_id
            WHERE ep.event_id=? AND m.caption IS NOT NULL
            ORDER BY m.final_score DESC LIMIT 12
        """, (ev["id"],))]

        if not caps:
            continue

        prompt = (
            "Give this group of photos a short album name.\n"
            f"Dates: {(ev['start_date'] or '')[:10]} to "
            f"{(ev['end_date'] or '')[:10]}\n"
            f"Number of photos: {ev['photo_count']}\n"
            "What the photos show:\n"
            + "\n".join(f"- {c}" for c in caps)
            + "\n\nRules: at most 5 words. No quotes. No date unless it is the "
              "only useful information. Reply with the name and nothing else."
        )

        r = requests.post(f"{LITELLM}/chat/completions",
            headers={"Authorization": f"Bearer {KEY}"},
            json={"model": model,
                  "messages": [{"role": "user", "content": prompt}],
                  "metadata": {"tags": ["job:name_events"]}},
            timeout=120)

        if r.status_code != 200:
            print(f"event {ev['id']}: HTTP {r.status_code}")
            continue

        name = r.json()["choices"][0]["message"]["content"].strip().strip('"')[:60]
        conn.execute("UPDATE events SET name=?, named_by='ai' WHERE id=?",
                     (name, ev["id"]))
        print(f"event {ev['id']} ({ev['photo_count']} photos): {name}")

    conn.commit()
    conn.close()


if __name__ == "__main__":
    name_events()
```

**Cost:** each event is one small request — a few hundred tokens. Locally it is
₹0. On DeepSeek, naming 50 events costs about **₹0.10**.

---

## Step 7 — Push albums into Immich (optional)

```python
# push_albums.py
from media_db import connect
from immich_client import search_by_text, create_album

conn = connect()
for ev in conn.execute("SELECT * FROM events WHERE name IS NOT NULL"):
    # Match your database rows to Immich assets by filename.
    # Immich asset IDs differ from your paths, so a lookup step is needed.
    print(f"would create album: {ev['name']} ({ev['photo_count']} photos)")
```

⚠️ Matching your files to Immich's asset IDs takes a bit of work — Immich has a
`/search/metadata` endpoint you can query by original filename. Build this only
if you actually want the albums inside Immich; the SQLite events table is
already useful on its own for driving reels.

---

## Step 8 — Useful queries

```bash
# Your events, biggest first
sqlite3 -header -column ~/Media/index.sqlite "
SELECT id, name, substr(start_date,1,10) start, photo_count
FROM events ORDER BY photo_count DESC LIMIT 20;"

# The best photo from each event — a highlight reel of your year
sqlite3 -header -column ~/Media/index.sqlite "
SELECT e.name, e.best_photo, m.round_score FROM events e
JOIN (SELECT path, round(final_score,2) round_score FROM media) m
  ON m.path = e.best_photo
ORDER BY e.start_date DESC LIMIT 30;"

# Events with people in them
sqlite3 -header -column ~/Media/index.sqlite "
SELECT e.name, COUNT(*) photos_with_faces FROM events e
JOIN event_photos ep ON ep.event_id = e.id
JOIN media m ON m.id = ep.media_id
WHERE m.faces > 0 GROUP BY e.id
ORDER BY photos_with_faces DESC LIMIT 15;"
```

---

## How this feeds the reels pipeline

Once you have named events, `/reel goa trip` works properly: the manifest
builder in file 08 matches your words against **event names** as well as photo
captions, so it picks clips from the right trip instead of guessing from
captions alone.

Add this to `build_manifest` in file 08:

```python
# Try matching an event name first — much more accurate than caption matching
ev = conn.execute("""
    SELECT id, name FROM events
    WHERE LOWER(name) LIKE ? ORDER BY photo_count DESC LIMIT 1
""", (f"%{description.lower()}%",)).fetchone()

if ev:
    rows = conn.execute("""
        SELECT m.* FROM event_photos ep JOIN media m ON m.id=ep.media_id
        WHERE ep.event_id=? AND m.is_best_of_group=1
        ORDER BY m.final_score DESC LIMIT ?
    """, (ev["id"], max_clips)).fetchall()
```

---

## Troubleshooting

| Problem | Cause | Fix |
|---|---|---|
| "no photos with dates" | EXIF stripped, common with WhatsApp images | Use file modification time as a fallback |
| Everything in one giant event | Photos have no GPS and similar timestamps | Lower `TIME_GAP_HOURS` to 4 |
| Hundreds of tiny events | Gaps too small | Raise `TIME_GAP_HOURS`, raise `MIN_PHOTOS_PER_EVENT` |
| Immich eats all your memory | ML containers are heavy | Disable unneeded ML features, or move Immich to the Oracle VM |
| osxphotos permission denied | Photos access not granted | System Settings → Privacy & Security → Photos |
| Album names are generic | Captions are weak | Improve the captioning prompt in file 07, step 7 |
| Immich API returns 404 | Version changed the path | Check `/api/api-docs` on your install |

---

## Prompt for AI

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

## Check you are done

- [ ] Chosen Immich or osxphotos and it reads your photos
- [ ] `group_events` produces a sensible number of events
- [ ] Event boundaries roughly match real trips and occasions
- [ ] Event names are recognisable, not generic
- [ ] The highlight query returns photos you would actually pick
- [ ] `/reel <event name>` picks clips from the right event

---

Next: [11 — Dashboard](11-dashboard.md)
