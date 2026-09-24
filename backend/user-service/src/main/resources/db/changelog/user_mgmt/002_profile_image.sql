--liquibase formatted sql

--changeset tipster:004-profile-image
ALTER TABLE user_mgmt.users ADD COLUMN profile_image TEXT;
--rollback ALTER TABLE user_mgmt.users DROP COLUMN profile_image;
