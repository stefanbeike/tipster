--liquibase formatted sql
--changeset gratilo:011-user-soft-delete
ALTER TABLE user_mgmt.users ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
