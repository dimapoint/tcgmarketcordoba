-- Flag de administrador. Se otorga a mano:
--   UPDATE users SET is_admin = true WHERE email = '...';
ALTER TABLE users ADD COLUMN is_admin boolean NOT NULL DEFAULT false;
