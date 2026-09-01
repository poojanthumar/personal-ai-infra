#!/usr/bin/env python3
"""Job queue API from docs/deprecated/personal-ai-stack/04-oracle-box.md."""

import os
from typing import Optional

import psycopg2
import psycopg2.extras
from fastapi import FastAPI, Header, HTTPException
from pydantic import BaseModel

DSN = os.environ["DATABASE_URL"]
TOKEN = os.environ["WORKER_TOKEN"]

app = FastAPI(title="aihub queue")


def db():
    return psycopg2.connect(DSN, cursor_factory=psycopg2.extras.RealDictCursor)


def check(token: Optional[str]):
    if token != TOKEN:
        raise HTTPException(status_code=401, detail="bad token")


class NewJob(BaseModel):
    type: str
    payload: dict = {}
    reply_to: Optional[str] = None


class JobResult(BaseModel):
    id: int
    status: str
    result: dict = {}


@app.get("/health")
def health():
    return {"ok": True}


@app.get("/jobs/next")
def next_job(x_worker_token: str = Header(None)):
    check(x_worker_token)
    with db() as c, c.cursor() as cur:
        cur.execute(
            """
            UPDATE jobs SET status='running', claimed_at=now()
            WHERE id = (
              SELECT id FROM jobs WHERE status='queued'
              ORDER BY id LIMIT 1 FOR UPDATE SKIP LOCKED
            )
            RETURNING id, type, payload, reply_to
            """
        )
        row = cur.fetchone()
    return {"job": row}


@app.post("/jobs/result")
def job_result(r: JobResult, x_worker_token: str = Header(None)):
    check(x_worker_token)
    with db() as c, c.cursor() as cur:
        cur.execute(
            """
            UPDATE jobs SET status=%s, result=%s, finished_at=now() WHERE id=%s
            """,
            (r.status, psycopg2.extras.Json(r.result), r.id),
        )
    return {"ok": True}


@app.post("/heartbeat")
def heartbeat(x_worker_token: str = Header(None)):
    check(x_worker_token)
    with db() as c, c.cursor() as cur:
        cur.execute(
            """
            INSERT INTO heartbeat (worker, last_seen) VALUES ('mac', now())
            ON CONFLICT (worker) DO UPDATE SET last_seen = now()
            """
        )
    return {"ok": True}


@app.post("/jobs")
def add_job(j: NewJob, x_worker_token: str = Header(None)):
    check(x_worker_token)
    with db() as c, c.cursor() as cur:
        cur.execute(
            """
            INSERT INTO jobs (type, payload, reply_to) VALUES (%s,%s,%s)
            RETURNING id
            """,
            (j.type, psycopg2.extras.Json(j.payload), j.reply_to),
        )
        jid = cur.fetchone()["id"]
    return {"id": jid}


@app.get("/jobs/{job_id}")
def get_job(job_id: int, x_worker_token: str = Header(None)):
    check(x_worker_token)
    with db() as c, c.cursor() as cur:
        cur.execute("SELECT * FROM jobs WHERE id=%s", (job_id,))
        row = cur.fetchone()
    if not row:
        raise HTTPException(404, "no such job")
    return row


@app.post("/jobs/reclaim")
def reclaim(x_worker_token: str = Header(None)):
    check(x_worker_token)
    with db() as c, c.cursor() as cur:
        cur.execute(
            """
            UPDATE jobs SET status='queued', claimed_at=NULL
            WHERE status='running' AND claimed_at < now() - interval '1 hour'
            RETURNING id
            """
        )
        ids = [r["id"] for r in cur.fetchall()]
    return {"reclaimed": ids}
