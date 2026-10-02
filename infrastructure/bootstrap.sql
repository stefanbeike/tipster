-- Executed only by an explicitly approved one-off ECS task, never by Terraform.
-- psql quotes passwords as literals; secret values are not command arguments.
\getenv user_password USER_DB_PASSWORD
\getenv payment_password PAYMENT_DB_PASSWORD
BEGIN;
SELECT 'CREATE ROLE tipster_user LOGIN'
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'tipster_user') \gexec
SELECT 'CREATE ROLE tipster_payment LOGIN'
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'tipster_payment') \gexec
SELECT format('ALTER ROLE tipster_user PASSWORD %L', :'user_password') \gexec
SELECT format('ALTER ROLE tipster_payment PASSWORD %L', :'payment_password') \gexec
-- Existing payment migration uses CREATE SCHEMA IF NOT EXISTS, which checks
-- database CREATE permission even when the schema already exists.
SELECT format('GRANT CREATE ON DATABASE %I TO tipster_payment', current_database()) \gexec
GRANT tipster_user, tipster_payment TO tipster_admin;
CREATE SCHEMA IF NOT EXISTS user_mgmt AUTHORIZATION tipster_user;
CREATE SCHEMA IF NOT EXISTS payment_mgmt AUTHORIZATION tipster_payment;
REVOKE tipster_user, tipster_payment FROM tipster_admin;
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
COMMIT;
