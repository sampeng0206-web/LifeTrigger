CREATE TABLE IF NOT EXISTS cloud_triggers (
  id TEXT PRIMARY KEY,
  encrypted_payload TEXT NOT NULL,
  recipient_emails TEXT NOT NULL,
  deadline TEXT NOT NULL,
  is_active INTEGER NOT NULL DEFAULT 1,
  requires_cloud INTEGER NOT NULL DEFAULT 1,
  status TEXT NOT NULL DEFAULT 'waiting',
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_trigger_lookup ON cloud_triggers (is_active, requires_cloud, deadline);
