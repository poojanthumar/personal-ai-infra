# 09 — Apple Music Automation

**Goal:** automatically build and refresh Apple Music playlists that match your
taste, and mark tracks for offline listening.

**Time:** 2 hours.

**Cost:** ₹0.

---

## Two things to understand first

### 1. Skip the Apple Developer Program

The official Apple Music API needs a paid Apple Developer membership —
⚠️ about ₹8,900 per year, which is roughly ₹740 per month. That is a quarter of
your entire budget.

**AppleScript does the same things for free.** It is built into macOS and can:

| Action | AppleScript can do it |
|---|---|
| Read your whole library with play counts and ratings | ✅ |
| Create and rename playlists | ✅ |
| Add and remove tracks | ✅ |
| Set star ratings and love/dislike | ✅ |
| Search the Apple Music catalogue | ✅ (through the app) |
| Trigger offline download of library tracks | ✅ |
| Read recently played | ✅ |

The only thing the paid API adds is doing this from a server without a Mac. You
have a Mac. Skip it.

### 2. You cannot download the actual audio files

Apple Music tracks are copy-protected. "Download" in Apple Music means "keep an
offline copy inside the app for playing". You can trigger that. You cannot get a
plain audio file out, and you should not try.

**What this means practically:**
- ✅ Building playlists — works perfectly
- ✅ Marking things for offline listening — works
- ❌ Using Apple Music tracks in your reels (file 08) — impossible. Use music
  you own instead

---

## Step 1 — Test AppleScript access

```bash
osascript -e 'tell application "Music" to get name of current track'
```

The first time, macOS will ask permission. Allow it.

If you get "Not authorized to send Apple events", go to
**System Settings → Privacy & Security → Automation** and allow Terminal to
control Music.

Count your library:

```bash
osascript -e 'tell application "Music" to get count of tracks of library playlist 1'
```

---

## Step 2 — Export your library to a database

Reading your library through AppleScript is slow (several minutes for a large
library). Do it once, store it, then query instantly.

Save as `~/Documents/Code/aihub/music_export.applescript`:

```applescript
-- Export the library as tab-separated lines.
-- Tab separation avoids problems with commas in song titles.
tell application "Music"
    set output to ""
    set allTracks to every track of library playlist 1
    repeat with t in allTracks
        try
            set line to (get database ID of t) & tab & ¬
                        (get name of t) & tab & ¬
                        (get artist of t) & tab & ¬
                        (get album of t) & tab & ¬
                        (get genre of t) & tab & ¬
                        (get played count of t) & tab & ¬
                        (get rating of t) & tab & ¬
                        (get duration of t) & tab & ¬
                        (get year of t)
            set output to output & line & linefeed
        end try
    end repeat
    return output
end tell
```

Save as `~/Documents/Code/aihub/music_db.py`:

```python
"""Import the Apple Music library into SQLite so we can query it quickly."""

import subprocess, sqlite3
from datetime import datetime, timezone
from pathlib import Path

DB = Path("~/Media/music.sqlite").expanduser()

SCHEMA = """
CREATE TABLE IF NOT EXISTS tracks (
  db_id       INTEGER PRIMARY KEY,
  name        TEXT, artist TEXT, album TEXT, genre TEXT,
  played      INTEGER DEFAULT 0,
  rating      INTEGER DEFAULT 0,       -- 0-100, 20 per star
  duration    REAL,
  year        INTEGER,
  updated_at  TEXT
);
CREATE INDEX IF NOT EXISTS idx_tracks_artist ON tracks(artist);
CREATE INDEX IF NOT EXISTS idx_tracks_played ON tracks(played DESC);

CREATE TABLE IF NOT EXISTS suggestions (
  artist      TEXT PRIMARY KEY,
  source      TEXT,                    -- lastfm | listenbrainz
  score       REAL,
  in_library  INTEGER DEFAULT 0,
  added_at    TEXT
);
"""


def connect():
    DB.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(DB)
    conn.row_factory = sqlite3.Row
    conn.executescript(SCHEMA)
    return conn


def export_library(script_path="~/Documents/Code/aihub/music_export.applescript"):
    """Run the AppleScript and load the results. Takes a few minutes."""
    script = Path(script_path).expanduser()
    print("reading Apple Music library (this can take a few minutes)...")

    out = subprocess.run(["osascript", str(script)],
                         capture_output=True, text=True, timeout=1800)
    if out.returncode != 0:
        raise RuntimeError(f"AppleScript failed: {out.stderr[:500]}")

    conn = connect()
    now = datetime.now(timezone.utc).isoformat()
    added = 0

    for line in out.stdout.splitlines():
        parts = line.split("\t")
        if len(parts) < 9:
            continue
        try:
            conn.execute("""
                INSERT OR REPLACE INTO tracks
                (db_id,name,artist,album,genre,played,rating,duration,year,updated_at)
                VALUES (?,?,?,?,?,?,?,?,?,?)
            """, (int(parts[0]), parts[1], parts[2], parts[3], parts[4],
                  int(parts[5] or 0), int(parts[6] or 0),
                  float(parts[7] or 0), int(parts[8] or 0), now))
            added += 1
        except (ValueError, sqlite3.Error):
            continue

    conn.commit()
    total = conn.execute("SELECT COUNT(*) FROM tracks").fetchone()[0]
    conn.close()
    print(f"imported {added} tracks, {total} total in database")
    return {"imported": added, "total": total}


if __name__ == "__main__":
    export_library()
```

Run it:

```bash
source ~/.venvs/aihub/bin/activate
cd ~/Documents/Code/aihub
python music_db.py
```

---

## Step 3 — Understand your own taste

Now you can query it instantly:

```bash
# Your most played artists
sqlite3 -header -column ~/Media/music.sqlite "
SELECT artist, SUM(played) plays, COUNT(*) tracks
FROM tracks GROUP BY artist
ORDER BY plays DESC LIMIT 20;"

# Highly rated but rarely played — good rediscovery candidates
sqlite3 -header -column ~/Media/music.sqlite "
SELECT name, artist, rating/20 stars, played
FROM tracks WHERE rating >= 80 AND played <= 2
ORDER BY rating DESC LIMIT 20;"

# Your genre spread
sqlite3 -header -column ~/Media/music.sqlite "
SELECT genre, COUNT(*) tracks, SUM(played) plays
FROM tracks WHERE genre != '' GROUP BY genre
ORDER BY plays DESC LIMIT 15;"
```

---

## Step 4 — Find new music with Last.fm

⚠️ Note: Spotify closed its recommendation API to new applications around
November 2024. Do not plan around it. **Last.fm** and **ListenBrainz** are both
free and open.

Get a free Last.fm API key at https://www.last.fm/api/account/create.

```bash
echo 'LASTFM_KEY=your_key_here' >> ~/.config/aihub/.env
```

Save as `~/Documents/Code/aihub/music_discover.py`:

```python
"""Find artists similar to the ones you play most, using Last.fm."""

import os, requests
from datetime import datetime, timezone
from music_db import connect

LASTFM = "https://ws.audioscrobbler.com/2.0/"
KEY = os.environ["LASTFM_KEY"]


def similar_artists(artist, limit=15):
    """Ask Last.fm which artists are similar to this one."""
    r = requests.get(LASTFM, params={
        "method": "artist.getsimilar", "artist": artist,
        "api_key": KEY, "format": "json", "limit": limit,
    }, timeout=30)
    r.raise_for_status()
    items = r.json().get("similarartists", {}).get("artist", [])
    return [(a["name"], float(a.get("match", 0))) for a in items]


def build_suggestions(top_n_artists=20):
    """
    For your top artists, gather similar artists you do NOT already have.
    Those are your discovery candidates.
    """
    conn = connect()
    have = {r["artist"].lower()
            for r in conn.execute("SELECT DISTINCT artist FROM tracks")}

    tops = conn.execute("""
        SELECT artist, SUM(played) p FROM tracks
        WHERE artist != '' GROUP BY artist
        ORDER BY p DESC LIMIT ?
    """, (top_n_artists,)).fetchall()

    now = datetime.now(timezone.utc).isoformat()
    found = 0

    for row in tops:
        try:
            for name, match in similar_artists(row["artist"]):
                already = 1 if name.lower() in have else 0
                conn.execute("""
                    INSERT INTO suggestions (artist, source, score, in_library, added_at)
                    VALUES (?,?,?,?,?)
                    ON CONFLICT(artist) DO UPDATE SET
                      score = MAX(score, excluded.score),
                      in_library = excluded.in_library
                """, (name, "lastfm", match, already, now))
                if not already:
                    found += 1
        except Exception as e:
            print(f"skip {row['artist']}: {e}")

    conn.commit()
    new = [dict(r) for r in conn.execute("""
        SELECT artist, round(score,3) score FROM suggestions
        WHERE in_library = 0 ORDER BY score DESC LIMIT 30
    """)]
    conn.close()

    print(f"{len(new)} new artists to try")
    return new


if __name__ == "__main__":
    import json
    print(json.dumps(build_suggestions(), indent=2))
```

---

## Step 5 — Create playlists

Save as `~/Documents/Code/aihub/music_playlist.applescript`:

```applescript
-- Create or empty a playlist, then add tracks by their database ID.
-- Arguments: playlist name, then one or more database IDs.
on run argv
    set playlistName to item 1 of argv
    set trackIDs to rest of argv

    tell application "Music"
        -- Reuse the playlist if it already exists, so links keep working
        if not (exists user playlist playlistName) then
            make new user playlist with properties {name:playlistName}
        else
            try
                delete every track of user playlist playlistName
            end try
        end if

        set target to user playlist playlistName
        set added to 0

        repeat with idText in trackIDs
            try
                set t to (first track of library playlist 1 ¬
                          whose database ID is (idText as integer))
                duplicate t to target
                set added to added + 1
            end try
        end repeat

        return "added " & added & " tracks to " & playlistName
    end tell
end run
```

Save as `~/Documents/Code/aihub/music_sync.py`:

```python
#!/usr/bin/env python3
"""Build Apple Music playlists from rules or from a mood description."""

import os, subprocess, json, requests
from pathlib import Path
from music_db import connect

SCRIPT = Path("~/Documents/Code/aihub/music_playlist.applescript").expanduser()
LITELLM = os.environ.get("LITELLM_URL", "http://localhost:4000/v1")
KEY = os.environ.get("LITELLM_KEY", "")


def write_playlist(name, track_ids):
    """Hand the track IDs to AppleScript, which does the actual work."""
    if not track_ids:
        return "no tracks to add"
    args = ["osascript", str(SCRIPT), name] + [str(i) for i in track_ids]
    out = subprocess.run(args, capture_output=True, text=True, timeout=900)
    if out.returncode != 0:
        raise RuntimeError(f"AppleScript failed: {out.stderr[:400]}")
    return out.stdout.strip()


# ------------------------------------------------- rule-based playlists (free)

RULES = {
    "heavy rotation": """
        SELECT db_id FROM tracks
        WHERE played >= 5 ORDER BY played DESC LIMIT 60
    """,
    "forgotten favourites": """
        SELECT db_id FROM tracks
        WHERE rating >= 80 AND played <= 2 ORDER BY rating DESC LIMIT 50
    """,
    "never played": """
        SELECT db_id FROM tracks
        WHERE played = 0 ORDER BY RANDOM() LIMIT 50
    """,
    "long tracks for focus": """
        SELECT db_id FROM tracks
        WHERE duration > 300 AND rating >= 60
        ORDER BY duration DESC LIMIT 40
    """,
}


def build_rule_playlist(rule_name):
    """No AI involved. Pure SQL. Instant and free."""
    if rule_name not in RULES:
        raise ValueError(f"unknown rule: {rule_name}. "
                         f"Known: {', '.join(RULES)}")
    conn = connect()
    ids = [r["db_id"] for r in conn.execute(RULES[rule_name])]
    conn.close()
    msg = write_playlist(f"AI · {rule_name}", ids)
    return {"playlist": rule_name, "tracks": len(ids), "result": msg}


# -------------------------------------------------- mood playlists (tiny cost)

def build_mood_playlist(mood, candidate_limit=250, pick=40):
    """
    Ask an AI to pick tracks for a mood.
    Only track names and artists are sent — no audio, no personal data.
    """
    conn = connect()
    rows = conn.execute("""
        SELECT db_id, name, artist, genre, played, rating
        FROM tracks WHERE rating >= 40 OR played >= 2
        ORDER BY played DESC LIMIT ?
    """, (candidate_limit,)).fetchall()

    catalogue = [
        {"id": r["db_id"], "t": r["name"][:50], "a": r["artist"][:40],
         "g": (r["genre"] or "")[:20]}
        for r in rows
    ]

    prompt = (
        f'Pick exactly {pick} tracks from this list that fit the mood: "{mood}".\n'
        "Vary the artists — no more than 3 tracks from any one artist.\n"
        "Order them so the energy flows sensibly from start to finish.\n"
        'Return ONLY a JSON array of the id numbers, like [123,456,789]. '
        "No explanation, no markdown fences.\n\n"
        + json.dumps(catalogue)
    )

    r = requests.post(f"{LITELLM}/chat/completions",
        headers={"Authorization": f"Bearer {KEY}"},
        json={"model": "tier2-cheap",
              "messages": [{"role": "user", "content": prompt}],
              "metadata": {"tags": ["job:music_playlist"]}},
        timeout=180)
    r.raise_for_status()

    text = r.json()["choices"][0]["message"]["content"].strip()
    if text.startswith("```"):
        text = text.split("```")[1].removeprefix("json")

    picked = json.loads(text)

    # Only trust IDs we actually offered
    valid = {c["id"] for c in catalogue}
    ids = [int(i) for i in picked if int(i) in valid]
    conn.close()

    msg = write_playlist(f"AI · {mood}", ids)
    return {"playlist": mood, "requested": pick,
            "tracks": len(ids), "result": msg}


def build_playlist(mood=None, rule=None):
    """Entry point used by the Mac agent."""
    if rule:
        return build_rule_playlist(rule)
    if mood in RULES:
        return build_rule_playlist(mood)
    return build_mood_playlist(mood or "recent favourites")


if __name__ == "__main__":
    import sys
    arg = " ".join(sys.argv[1:]) or "heavy rotation"
    print(json.dumps(build_playlist(mood=arg), indent=2))
```

---

## Step 6 — Run it

```bash
source ~/.venvs/aihub/bin/activate
set -a; source ~/.config/aihub/.env; set +a
cd ~/Documents/Code/aihub

# Free, no AI
python music_sync.py "heavy rotation"
python music_sync.py "forgotten favourites"

# Uses AI, costs about ₹0.05
python music_sync.py "rainy evening, calm, instrumental"
```

Open Apple Music. You should see playlists starting with `AI ·`.

---

## Step 7 — Mark tracks for offline listening

```applescript
-- music_download.applescript
-- Trigger offline download for tracks in a playlist.
on run argv
    set playlistName to item 1 of argv
    tell application "Music"
        set p to user playlist playlistName
        set n to 0
        repeat with t in (every track of p)
            try
                download t
                set n to n + 1
            end try
        end repeat
        return "requested download for " & n & " tracks"
    end tell
end run
```

```bash
osascript ~/Documents/Code/aihub/music_download.applescript "AI · heavy rotation"
```

⚠️ `download` only works on tracks that are in your Apple Music library and
requires an active subscription. It queues them; the app downloads in the
background. You still cannot extract the files.

---

## Step 8 — Run it weekly

Add to the Worker's cron in file 03:

```toml
[triggers]
crons = ["0 3 * * *", "0 4 * * 1"]   # daily 3am UTC, plus Mondays 4am UTC
```

And in the Worker's `scheduled` function:

```js
const hour = new Date(event.scheduledTime).getUTCHours();
if (hour === 4) {
  await env.DB.prepare(
    "INSERT INTO jobs (type,payload,created_at) VALUES ('music_playlist',?,?)"
  ).bind(JSON.stringify({ rule: "heavy rotation" }),
         new Date().toISOString()).run();
}
```

Then every Monday your playlists refresh themselves.

---

## What this can and cannot do

| Want | Possible? | How |
|---|---|---|
| Build a playlist from my play history | ✅ | Step 5, rule-based, free |
| Build a playlist from a mood description | ✅ | Step 5, ~₹0.05 per playlist |
| Find artists similar to my favourites | ✅ | Step 4, Last.fm, free |
| Add discovered tracks to my library automatically | ⚠️ Partly | AppleScript can search the catalogue, but reliably matching a name to the right track is fiddly. Semi-manual is more dependable |
| Mark playlists for offline listening | ✅ | Step 7 |
| Get plain audio files out of Apple Music | ❌ | Copy-protected. Not possible, do not try |
| Use Apple Music tracks in my reels | ❌ | Same reason. Use music you own (file 08) |
| Run any of this without a Mac | ❌ | AppleScript is macOS only. That is the trade-off for avoiding the ₹8,900/year API |

---

## Troubleshooting

| Problem | Cause | Fix |
|---|---|---|
| "Not authorized to send Apple events" | Permission not granted | System Settings → Privacy & Security → Automation → allow Terminal for Music |
| Export takes over 10 minutes | Very large library | Normal. It only needs doing occasionally |
| Some tracks missing from export | Cloud-only tracks behave differently | Usually fine; the `try` block skips problems |
| Playlist created but empty | Database IDs stale after a library change | Re-run `music_db.py` |
| AI returns invalid IDs | Model made them up | The `valid` filter catches this. Reduce `candidate_limit` if it happens a lot |
| `download` does nothing | Track not in library, or no subscription | Add it to your library first |
| Playlist order looks random | AppleScript `duplicate` preserves order, but Music may re-sort the view | Set the playlist view to "Playlist Order" |

---

## Prompt for AI

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

## Check you are done

- [ ] `osascript` can read your current track
- [ ] Library exported and `music.sqlite` has your tracks
- [ ] Top-artists query returns something that looks like your taste
- [ ] A rule-based playlist appears in Apple Music
- [ ] A mood playlist works and cost under ₹0.10
- [ ] Last.fm returns similar artists you don't already have
- [ ] Weekly refresh scheduled

---

Next: [10 — Photos and albums](10-photos-albums.md)
