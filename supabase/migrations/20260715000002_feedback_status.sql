-- Triage de feedback desde el panel admin.
ALTER TABLE feedback
  ADD COLUMN status text NOT NULL DEFAULT 'nuevo'
  CHECK (status IN ('nuevo', 'resuelto'));
