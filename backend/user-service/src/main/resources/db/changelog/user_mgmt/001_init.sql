--liquibase formatted sql

--changeset tipster:001-users
CREATE TABLE IF NOT EXISTS user_mgmt.users (
    id UUID PRIMARY KEY,
    email VARCHAR(255) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(120),
    last_name VARCHAR(120),
    organisation VARCHAR(255),
    street VARCHAR(255),
    city VARCHAR(255),
    phone VARCHAR(50),
    country VARCHAR(100),
    newsletter BOOLEAN NOT NULL DEFAULT FALSE,
    email_verified BOOLEAN NOT NULL DEFAULT FALSE,
    agb_accepted_file VARCHAR(512),
    privacy_policy VARCHAR(512),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS users_email_unique_ci ON user_mgmt.users (LOWER(email));
--rollback DROP TABLE IF EXISTS user_mgmt.users CASCADE;

--changeset tipster:002-verification-tokens
CREATE TABLE IF NOT EXISTS user_mgmt.email_verification_tokens (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES user_mgmt.users(id) ON DELETE CASCADE,
    token VARCHAR(128) NOT NULL UNIQUE,
    expires_at TIMESTAMPTZ NOT NULL,
    used BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_verification_user ON user_mgmt.email_verification_tokens(user_id);
--rollback DROP TABLE IF EXISTS user_mgmt.email_verification_tokens;

--changeset tipster:003-password-reset-tokens
CREATE TABLE IF NOT EXISTS user_mgmt.password_reset_tokens (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES user_mgmt.users(id) ON DELETE CASCADE,
    token_hash VARCHAR(128) NOT NULL UNIQUE,
    expires_at TIMESTAMPTZ NOT NULL,
    used BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_password_reset_user ON user_mgmt.password_reset_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_password_reset_active ON user_mgmt.password_reset_tokens(expires_at, used);
--rollback DROP TABLE IF EXISTS user_mgmt.password_reset_tokens;
