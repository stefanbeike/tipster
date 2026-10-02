--liquibase formatted sql
--changeset gratilo:012-production-payment-urls context:@prd
-- Preserve payment paths and assignments while switching existing local URLs to production.
UPDATE user_mgmt.payment_url_pool
SET payment_url = 'https://gratilo.com' || substring(payment_url FROM length('http://localhost:3000') + 1)
WHERE payment_url LIKE 'http://localhost:3000/pay/%';

UPDATE user_mgmt.users
SET payment_url_path = 'https://gratilo.com' || substring(payment_url_path FROM length('http://localhost:3000') + 1)
WHERE payment_url_path LIKE 'http://localhost:3000/pay/%';
