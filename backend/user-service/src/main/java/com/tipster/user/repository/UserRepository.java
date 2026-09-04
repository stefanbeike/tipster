package com.tipster.user.repository;

import com.tipster.user.domain.UserEntity;
import io.micronaut.data.annotation.Query;
import io.micronaut.data.annotation.Repository;
import io.micronaut.data.repository.CrudRepository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface UserRepository extends CrudRepository<UserEntity, UUID> {
    boolean existsByEmail(String email);

    Optional<UserEntity> findByEmail(String email);

    @Query(value = "UPDATE user_mgmt.users SET password_hash = :passwordHash WHERE id = :id", nativeQuery = true)
    void updatePassword(UUID id, String passwordHash);
}
