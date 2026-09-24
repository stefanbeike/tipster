--liquibase formatted sql
--changeset gratilo:005-payment-url-full-link
ALTER TABLE user_mgmt.payment_url_pool ADD COLUMN IF NOT EXISTS payment_url VARCHAR(512);
UPDATE user_mgmt.payment_url_pool SET payment_url = 'http://localhost:3000/pay/' || path WHERE payment_url IS NULL;
ALTER TABLE user_mgmt.users ALTER COLUMN payment_url_path TYPE VARCHAR(512);
UPDATE user_mgmt.users u SET payment_url_path = p.payment_url FROM user_mgmt.payment_url_pool p WHERE p.assigned_user_id = u.id AND p.payment_url IS NOT NULL;
