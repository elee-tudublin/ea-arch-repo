CREATE TABLE IF NOT EXISTS country (
  code TEXT PRIMARY KEY,
  name TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS thread (
  id SERIAL PRIMARY KEY,
  topic TEXT NOT NULL,
  country_code TEXT NOT NULL REFERENCES country(code)
);

CREATE TABLE IF NOT EXISTS post (
  id SERIAL PRIMARY KEY,
  thread_id INT NOT NULL REFERENCES thread(id) ON DELETE CASCADE,
  text TEXT NOT NULL,
  country_code TEXT NOT NULL REFERENCES country(code),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_post_thread_id ON post(thread_id);

CREATE TABLE IF NOT EXISTS processed_event (
  consumer_name TEXT NOT NULL,
  event_id UUID NOT NULL,
  processed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (consumer_name, event_id)
);

CREATE TABLE IF NOT EXISTS moderation (
  post_id INT PRIMARY KEY REFERENCES post(id) ON DELETE CASCADE,
  decision TEXT NOT NULL,
  reason_code TEXT NOT NULL,
  confidence REAL NOT NULL DEFAULT 0,
  moderated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO country(code, name) VALUES
  ('IE', 'Ireland'),
  ('GB', 'United Kingdom'),
  ('US', 'United States')
ON CONFLICT (code) DO NOTHING;
