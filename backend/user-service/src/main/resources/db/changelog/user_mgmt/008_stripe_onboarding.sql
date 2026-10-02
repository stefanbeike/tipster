--liquibase formatted sql
--changeset gratilo:008-stripe-onboarding
ALTER TABLE user_mgmt.users ADD COLUMN IF NOT EXISTS stripe_onboarding_completed BOOLEAN NOT NULL DEFAULT FALSE;
