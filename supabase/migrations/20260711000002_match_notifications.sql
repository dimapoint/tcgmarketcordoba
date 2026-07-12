-- Novedades de match: marca de la última vez que el usuario vio los listings
-- nuevos que matchean sus búsquedas activas. DEFAULT now() para que los
-- usuarios existentes arranquen sin un aluvión de novedades históricas.
ALTER TABLE profiles
  ADD COLUMN matches_seen_at timestamptz NOT NULL DEFAULT now();
