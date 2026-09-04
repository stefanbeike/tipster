package com.tipster.user.api;

import com.tipster.user.domain.UserEntity;
import io.micronaut.serde.annotation.Serdeable;

import java.time.OffsetDateTime;
import java.util.UUID;

public final class UserResponses {
    private UserResponses() {
    }

    @Serdeable
    public record Message(String message) {
    }

    @Serdeable
    public record Login(
            String tokenType,
            String accessToken,
            UUID userId,
            String email,
            boolean emailVerified
    ) {
    }

    @Serdeable
    public record Profile(
            UUID userId,
            String email,
            boolean emailVerified,
            String firstName,
            String lastName,
            String organisation,
            String street,
            String city,
            String phone,
            String country,
            boolean newsletter,
            String agbAcceptedFile,
            OffsetDateTime createdAt,
            OffsetDateTime updatedAt
    ) {
        public static Profile from(UserEntity user) {
            return new Profile(
                    user.getId(), user.getEmail(), user.isEmailVerified(), user.getFirstName(), user.getLastName(),
                    user.getOrganisation(), user.getStreet(), user.getCity(), user.getPhone(), user.getCountry(),
                    user.isNewsletter(), user.getAgbAcceptedFile(), user.getCreatedAt(), user.getUpdatedAt()
            );
        }
    }
}
