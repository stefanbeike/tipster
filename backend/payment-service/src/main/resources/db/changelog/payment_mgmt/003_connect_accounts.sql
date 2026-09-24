--liquibase formatted sql

--changeset tipster:003-connect-accounts
CREATE TABLE payment_mgmt.connected_accounts (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL UNIQUE,
    stripe_account_id VARCHAR(255) UNIQUE,
    onboarding_status VARCHAR(32) NOT NULL DEFAULT 'NOT_STARTED',
    charges_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    payouts_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    details_submitted BOOLEAN NOT NULL DEFAULT FALSE,
    requirements_due JSONB NOT NULL DEFAULT '[]'::jsonb,
    payout_schedule_interval VARCHAR(24) NOT NULL DEFAULT 'weekly',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX connected_accounts_stripe_idx ON payment_mgmt.connected_accounts(stripe_account_id);
--rollback DROP TABLE IF EXISTS payment_mgmt.connected_accounts;
