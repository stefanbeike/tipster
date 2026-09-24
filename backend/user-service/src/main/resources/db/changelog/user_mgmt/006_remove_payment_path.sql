--liquibase formatted sql
--changeset gratilo:006-remove-payment-path
ALTER TABLE user_mgmt.payment_url_pool DROP COLUMN IF EXISTS path;
