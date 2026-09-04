--liquibase formatted sql

--changeset tipster:001-payment-schema
CREATE SCHEMA IF NOT EXISTS payment_mgmt;
--rollback DROP SCHEMA IF EXISTS payment_mgmt CASCADE;
