package com.tipster.payment.repository;
import com.tipster.payment.domain.ConnectedAccountEntity;
import io.micronaut.data.annotation.Repository;
import io.micronaut.data.repository.CrudRepository;
import java.util.*;
@Repository public interface ConnectedAccountRepository extends CrudRepository<ConnectedAccountEntity, UUID> { Optional<ConnectedAccountEntity> findByUserId(UUID userId); }
