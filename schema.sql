-- Enable UUID extension if not already present (PostgreSQL specific)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

---
-- 1. USERS TABLE
---
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL, -- To store Argon2/BCrypt hashes
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Index on email for fast lookups during login/registration checks
CREATE INDEX idx_users_email ON users(email);


---
-- 2. REFRESH TOKENS TABLE
---
CREATE TABLE refresh_tokens (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL,
    token VARCHAR(512) NOT NULL UNIQUE, -- Holds the refresh token string/hash
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    is_revoked BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Foreign Key Constraint
    CONSTRAINT fk_refresh_tokens_user 
        FOREIGN KEY (user_id) 
        REFERENCES users(id) 
        ON DELETE CASCADE
);

-- Index for token lookup during verification and /auth/refresh rotation
CREATE INDEX idx_refresh_tokens_token ON refresh_tokens(token);


---
-- 3. AUDIT / AUTOMATION (OPTIONAL BUT RECOMMENDED)
---
-- Automatically update the updated_at timestamp on user change
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_users_updated_at
BEFORE UPDATE ON users
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();