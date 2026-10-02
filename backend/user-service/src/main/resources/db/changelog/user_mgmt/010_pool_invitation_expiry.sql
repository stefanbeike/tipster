--liquibase formatted sql
--changeset gratilo:010-pool-invitation-expiry
ALTER TABLE user_mgmt.pool_members ADD COLUMN IF NOT EXISTS invitation_expires_at TIMESTAMPTZ;
