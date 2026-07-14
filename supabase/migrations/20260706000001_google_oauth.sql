-- Usuarios creados vía Google Sign-In no tienen contraseña: password_hash
-- pasa a ser nullable. El backend trata NULL como "sin contraseña" (el login
-- con contraseña siempre falla para esas cuentas).
ALTER TABLE users ALTER COLUMN password_hash DROP NOT NULL;
