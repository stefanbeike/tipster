package com.tipster.user.controller;

import com.tipster.user.api.UserRequests;
import com.tipster.user.api.UserResponses;
import com.tipster.user.domain.UserEntity;
import com.tipster.user.repository.UserRepository;
import com.tipster.user.service.EmailVerificationService;
import com.tipster.user.service.PaymentUrlPoolService;
import io.micronaut.http.HttpResponse;
import io.micronaut.http.annotation.Body;
import io.micronaut.http.annotation.Controller;
import io.micronaut.http.annotation.Get;
import io.micronaut.http.annotation.Post;
import io.micronaut.http.annotation.Put;
import io.micronaut.security.annotation.Secured;
import io.micronaut.security.authentication.Authentication;
import io.micronaut.security.rules.SecurityRule;
import io.micronaut.transaction.annotation.Transactional;
import jakarta.validation.Valid;
import org.mindrot.jbcrypt.BCrypt;

import java.net.URI;
import java.util.UUID;

@Controller("/user-service/users")
public class UserController {
    private final UserRepository userRepository;
    private final EmailVerificationService emailVerificationService;
    private final PaymentUrlPoolService paymentUrlPoolService;

    public UserController(UserRepository userRepository, EmailVerificationService emailVerificationService, PaymentUrlPoolService paymentUrlPoolService) {
        this.userRepository = userRepository; this.emailVerificationService = emailVerificationService; this.paymentUrlPoolService = paymentUrlPoolService;
    }

    public UserController(UserRepository userRepository, EmailVerificationService emailVerificationService) { this(userRepository, emailVerificationService, null); }

    @Secured(SecurityRule.IS_ANONYMOUS)
    @Post("/register")
    @Transactional
    public HttpResponse<?> register(@Body @Valid UserRequests.Register request) {
        if (request.agbFileName() == null || request.agbFileName().isBlank()) {
            return HttpResponse.badRequest(new UserResponses.Message("AGB wurden nicht akzeptiert"));
        }
        if (!request.password().equals(request.confirmPassword())) {
            return HttpResponse.badRequest(new UserResponses.Message("Passwörter stimmen nicht überein"));
        }
        if (!com.tipster.user.service.ProfileImageValidator.isValid(request.profileImage())) {
            return HttpResponse.badRequest(new UserResponses.Message("Ungültiges Profilbild. Bitte wähle das Bild erneut aus."));
        }
        String email = request.email().toLowerCase();
        if (userRepository.existsByEmail(email)) {
            return HttpResponse.badRequest(new UserResponses.Message("E-Mail-Adresse ist bereits registriert"));
        }

        UserEntity user = new UserEntity();
        user.setEmail(email);
        user.setPasswordHash(BCrypt.hashpw(request.password(), BCrypt.gensalt()));
        user.setNewsletter(Boolean.TRUE.equals(request.newsletter()));
        user.setFirstName(request.firstName());
        user.setLastName(request.lastName());
        user.setOrganisation(request.organisation());
        user.setStreet(request.street());
        user.setCity(request.city());
        user.setCountry(request.country());
        user.setPhone(request.phone());
        user.setAgbAcceptedFile(request.agbFileName());
        user.setPrivacyPolicy(request.privacyPolicy());
        user.setProfileImage(request.profileImage());

        UserEntity saved = userRepository.save(user);
        if (paymentUrlPoolService != null) { saved.setPaymentUrlPath(paymentUrlPoolService.assign(saved)); saved = userRepository.update(saved); }
        emailVerificationService.createAndSend(saved);
        return HttpResponse.created(URI.create("/user-service/users/" + saved.getId()));
    }

    @Secured(SecurityRule.IS_ANONYMOUS)
    @Get("/public/payment/{path}")
    public HttpResponse<?> publicPaymentProfile(String path) {
        UserEntity user = paymentUrlPoolService.userForPath(path);
        return user == null ? HttpResponse.notFound() : HttpResponse.ok(UserResponses.PublicProfile.from(user));
    }

    @Secured(SecurityRule.IS_AUTHENTICATED)
    @Get("/me")
    @Transactional
    public HttpResponse<?> showProfile(Authentication authentication) {
        return authenticatedUser(authentication)
                .map(user -> HttpResponse.ok(UserResponses.Profile.from(user)))
                .orElseGet(HttpResponse::notFound);
    }

    @Secured(SecurityRule.IS_ANONYMOUS)
    @Get("/public/{id}")
    public HttpResponse<?> publicProfile(UUID id) {
        return userRepository.findById(id)
                .map(user -> HttpResponse.ok(UserResponses.PublicProfile.from(user)))
                .orElseGet(HttpResponse::notFound);
    }

    @Secured(SecurityRule.IS_AUTHENTICATED)
    @Put("/profile")
    @Transactional
    public HttpResponse<?> editProfile(
            @Body @Valid UserRequests.ProfileUpdate request,
            Authentication authentication
    ) {
        var maybeUser = authenticatedUser(authentication);
        if (maybeUser.isEmpty()) {
            return HttpResponse.notFound(new UserResponses.Message("Benutzer wurde nicht gefunden"));
        }
        UserEntity user = maybeUser.get();

        if (!com.tipster.user.service.ProfileImageValidator.isValid(request.profileImage())) {
            return HttpResponse.badRequest(new UserResponses.Message("Ungültiges Profilbild. Bitte wähle das Bild erneut aus."));
        }

        if (request.currentPassword() != null && !request.currentPassword().isBlank()) {
            if (!BCrypt.checkpw(request.currentPassword(), user.getPasswordHash())) {
                return HttpResponse.badRequest(new UserResponses.Message("Aktuelles Passwort ist falsch"));
            }
            if (request.newPassword() == null || !request.newPassword().equals(request.confirmPassword())) {
                return HttpResponse.badRequest(new UserResponses.Message("Neue Passwörter stimmen nicht überein"));
            }
            if (!request.newPassword().matches(UserRequests.PASSWORD_PATTERN)) {
                return HttpResponse.badRequest(new UserResponses.Message("Neues Passwort erfüllt die Richtlinie nicht"));
            }
            user.setPasswordHash(BCrypt.hashpw(request.newPassword(), BCrypt.gensalt()));
        }

        user.setFirstName(request.firstName());
        user.setLastName(request.lastName());
        user.setOrganisation(request.organisation());
        user.setStreet(request.street());
        user.setCity(request.city());
        user.setPhone(request.phone());
        user.setCountry(request.country());
        user.setNewsletter(Boolean.TRUE.equals(request.newsletter()));
        user.setProfileImage(request.profileImage());
        if (request.paymentEnabled() != null) user.setPaymentEnabled(request.paymentEnabled());
        return HttpResponse.ok(UserResponses.Profile.from(userRepository.update(user)));
    }

    private java.util.Optional<UserEntity> authenticatedUser(Authentication authentication) {
        try {
            return userRepository.findById(UUID.fromString(authentication.getName()));
        } catch (IllegalArgumentException exception) {
            return java.util.Optional.empty();
        }
    }
}
