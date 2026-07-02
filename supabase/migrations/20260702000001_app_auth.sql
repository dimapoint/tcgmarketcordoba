-- auth propia: users reemplaza la dependencia de auth.users
CREATE TABLE users (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email         text NOT NULL UNIQUE,
  password_hash text NOT NULL,
  created_at    timestamptz NOT NULL DEFAULT now()
);

-- migrar usuarios existentes (los hashes bcrypt de Supabase son compatibles con Go bcrypt)
INSERT INTO users (id, email, password_hash)
SELECT id, email, coalesce(encrypted_password, '')
FROM auth.users;

-- profiles ahora referencia nuestra tabla
ALTER TABLE profiles DROP CONSTRAINT profiles_id_fkey;
ALTER TABLE profiles
  ADD CONSTRAINT profiles_id_fkey
  FOREIGN KEY (id) REFERENCES users(id) ON DELETE CASCADE;

-- la creación del profile pasa al handler de signup del backend
DROP TRIGGER on_auth_user_created ON auth.users;
DROP FUNCTION public.handle_new_user();

-- refresh tokens (rotados en cada uso, guardados hasheados)
CREATE TABLE refresh_tokens (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash text NOT NULL UNIQUE,
  expires_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_refresh_tokens_user ON refresh_tokens(user_id);
