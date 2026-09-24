--liquibase formatted sql
--changeset gratilo:004-payment-method
ALTER TABLE payment_mgmt.transactions ADD COLUMN IF NOT EXISTS payment_method VARCHAR(40);
