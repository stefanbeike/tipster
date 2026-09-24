--liquibase formatted sql
--changeset gratilo:004-remove-capacity-alert
ALTER TABLE user_mgmt.payment_url_pool DROP COLUMN IF EXISTS capacity_alert_sent;
