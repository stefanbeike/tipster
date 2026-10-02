--liquibase formatted sql
--changeset gratilo:009-pools
CREATE TABLE user_mgmt.pools (id UUID PRIMARY KEY, owner_id UUID NOT NULL REFERENCES user_mgmt.users(id), name VARCHAR(120) NOT NULL, created_at TIMESTAMPTZ NOT NULL DEFAULT now());
CREATE TABLE user_mgmt.pool_members (id UUID PRIMARY KEY, pool_id UUID NOT NULL REFERENCES user_mgmt.pools(id) ON DELETE CASCADE, user_id UUID NOT NULL REFERENCES user_mgmt.users(id), share_percent NUMERIC(5,2) NOT NULL, status VARCHAR(16) NOT NULL, active BOOLEAN NOT NULL DEFAULT TRUE, invitation_token VARCHAR(120) UNIQUE, created_at TIMESTAMPTZ NOT NULL DEFAULT now(), responded_at TIMESTAMPTZ);
CREATE UNIQUE INDEX pool_members_pool_user_idx ON user_mgmt.pool_members(pool_id, user_id);
