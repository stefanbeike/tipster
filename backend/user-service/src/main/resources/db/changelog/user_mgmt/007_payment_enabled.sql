--liquibase formatted sql
--changeset gratilo:007-payment-enabled
ALTER TABLE user_mgmt.users ADD COLUMN IF NOT EXISTS payment_enabled BOOLEAN NOT NULL DEFAULT TRUE;
