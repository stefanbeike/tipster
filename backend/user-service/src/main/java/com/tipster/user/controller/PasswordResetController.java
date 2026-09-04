package com.tipster.user.controller;

import com.tipster.user.api.UserRequests;
import com.tipster.user.api.UserResponses;
import com.tipster.user.service.PasswordResetService;
import io.micronaut.http.HttpResponse;
import io.micronaut.http.annotation.Body;
import io.micronaut.http.annotation.Controller;
import io.micronaut.http.annotation.Post;
import io.micronaut.security.annotation.Secured;
import io.micronaut.security.rules.SecurityRule;
import jakarta.validation.Valid;

@Secured(SecurityRule.IS_ANONYMOUS)
@Controller("/user-service/auth/password-reset")
public class PasswordResetController {
    private final PasswordResetService passwordResetService;

    public PasswordResetController(PasswordResetService passwordResetService) {
        this.passwordResetService = passwordResetService;
    }

    @Post("/request")
    public HttpResponse<UserResponses.Message> request(@Body @Valid UserRequests.PasswordResetRequest request) {
        passwordResetService.createPasswordResetToken(request.email());
        return HttpResponse.ok(new UserResponses.Message(
                "Falls die E-Mail-Adresse existiert, wurde ein Link zum Zurücksetzen versendet"));
    }

    @Post("/confirm")
    public HttpResponse<UserResponses.Message> confirm(@Body @Valid UserRequests.PasswordResetConfirm request) {
        passwordResetService.resetPassword(request.token(), request.newPassword());
        return HttpResponse.ok(new UserResponses.Message("Passwort wurde erfolgreich geändert"));
    }
}
