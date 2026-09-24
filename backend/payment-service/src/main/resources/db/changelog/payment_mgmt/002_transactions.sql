--liquibase formatted sql

--changeset tipster:002-transactions
CREATE TABLE payment_mgmt.transactions (
    id UUID PRIMARY KEY,
    account_user_id UUID NOT NULL,
    counterparty_user_id UUID,
    amount_minor BIGINT NOT NULL CHECK (amount_minor <> 0),
    currency VARCHAR(3) NOT NULL DEFAULT 'EUR',
    type VARCHAR(24) NOT NULL,
    status VARCHAR(24) NOT NULL,
    reference VARCHAR(140),
    description VARCHAR(500),
    idempotency_key VARCHAR(100),
    provider VARCHAR(40) NOT NULL DEFAULT 'DEMO',
    provider_reference VARCHAR(255),
    failure_code VARCHAR(80),
    failure_message VARCHAR(500),
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    booked_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT transactions_currency_ck CHECK (currency = upper(currency))
);
CREATE UNIQUE INDEX transactions_idempotency_idx ON payment_mgmt.transactions(account_user_id, idempotency_key) WHERE idempotency_key IS NOT NULL;
CREATE INDEX transactions_account_created_idx ON payment_mgmt.transactions(account_user_id, created_at DESC);
CREATE INDEX transactions_status_idx ON payment_mgmt.transactions(status);
--rollback DROP TABLE IF EXISTS payment_mgmt.transactions;
