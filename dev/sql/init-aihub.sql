CREATE TABLE IF NOT EXISTS jobs (
  id          bigserial PRIMARY KEY,
  type        text NOT NULL,
  payload     jsonb NOT NULL DEFAULT '{}',
  status      text NOT NULL DEFAULT 'queued',
  result      jsonb,
  reply_to    text,
  created_at  timestamptz NOT NULL DEFAULT now(),
  claimed_at  timestamptz,
  finished_at timestamptz
);
CREATE INDEX IF NOT EXISTS idx_jobs_queued ON jobs (status, id);

CREATE TABLE IF NOT EXISTS heartbeat (
  worker    text PRIMARY KEY,
  last_seen timestamptz NOT NULL
);

CREATE TABLE IF NOT EXISTS job_runs (
  id          bigserial PRIMARY KEY,
  job_type    text NOT NULL,
  status      text NOT NULL,
  items       int  DEFAULT 0,
  started_at  timestamptz NOT NULL,
  duration_ms int,
  llm_calls   int  DEFAULT 0,
  error       text
);
CREATE INDEX IF NOT EXISTS idx_job_runs_time ON job_runs (started_at DESC);
CREATE INDEX IF NOT EXISTS idx_job_runs_type ON job_runs (job_type, started_at DESC);

CREATE TABLE IF NOT EXISTS quota_usage (
  provider text NOT NULL,
  day date NOT NULL,
  requests int DEFAULT 0,
  tokens bigint DEFAULT 0,
  PRIMARY KEY (provider, day)
);

CREATE TABLE IF NOT EXISTS quota_limits (
  provider text PRIMARY KEY,
  daily_requests int,
  daily_tokens bigint,
  note text
);
