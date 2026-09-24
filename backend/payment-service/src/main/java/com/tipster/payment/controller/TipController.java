package com.tipster.payment.controller;
import com.tipster.payment.api.*;
import com.tipster.payment.service.TipPricing;
import com.tipster.payment.repository.ConnectedAccountRepository;
import com.tipster.payment.repository.TransactionRepository;
import io.micronaut.http.*;
import io.micronaut.http.annotation.*;
import jakarta.validation.Valid;
import java.util.UUID;
import java.time.OffsetDateTime;
import com.tipster.payment.service.StripeCheckoutService;
@Controller("/payment-service/tips")
public class TipController {
    private final StripeCheckoutService checkoutService;
    private final ConnectedAccountRepository accounts;
    private final TransactionRepository transactions;
    public TipController(StripeCheckoutService checkoutService, ConnectedAccountRepository accounts, TransactionRepository transactions) { this.checkoutService = checkoutService; this.accounts = accounts; this.transactions = transactions; }
    @Get("/{recipientUserId}/quote") public TipQuote quote(UUID recipientUserId, @QueryValue long amountMinor) {
        long fee = TipPricing.serviceFeeMinor(amountMinor); return new TipQuote(amountMinor, fee, amountMinor + fee, "EUR", 0, 0);
    }
    @Get("/checkout/confirm") public HttpResponse<?> confirm(@QueryValue String sessionId) {
        try { return HttpResponse.ok(java.util.Map.of("confirmed", checkoutService.confirmSession(sessionId))); }
        catch (Exception e) { return HttpResponse.status(HttpStatus.BAD_GATEWAY).body(java.util.Map.of("confirmed", false)); }
    }
    @Post("/{recipientUserId}/checkout") public HttpResponse<?> checkout(UUID recipientUserId, @QueryValue(value = "demo", defaultValue = "false") String demo, @Body @Valid TipPaymentRequest request) {
        if (request.tipAmountMinor() < 100) return HttpResponse.badRequest(new com.tipster.payment.api.TransactionResponse(null, recipientUserId, 0, "EUR", null, null, null, "Mindesttrinkgeld: 1,00 EUR", "DEMO", null, "card", null, null, null, null, null));
        if ("1".equals(demo) || "true".equalsIgnoreCase(demo)) {
            var tx = new com.tipster.payment.domain.TransactionEntity(); tx.setAccountUserId(recipientUserId); tx.setAmountMinor(request.tipAmountMinor()); tx.setCurrency("EUR"); tx.setType(com.tipster.payment.domain.TransactionType.TIP); tx.setStatus(com.tipster.payment.domain.TransactionStatus.BOOKED); tx.setDescription(request.message()); tx.setProvider("STRIPE_SANDBOX"); tx.setPaymentMethod("card"); tx.setIdempotencyKey(request.idempotencyKey()); tx.setBookedAt(OffsetDateTime.now()); tx.setCompletedAt(OffsetDateTime.now());
            tx = transactions.save(tx);
            return HttpResponse.ok(new CheckoutResponse("/pay/success?demo=1", tx.getId().toString(), true));
        }
        try {
            var checkout = checkoutService.create(recipientUserId, request);
            if (checkout.isPresent()) return HttpResponse.ok(checkout.get());
            var account = accounts.findByUserId(recipientUserId).orElse(null);
            String status = account == null ? "kein Connected Account" : "onboarding=" + account.getOnboardingStatus() + ", charges_enabled=" + account.isChargesEnabled() + ", payouts_enabled=" + account.isPayoutsEnabled() + ", stripe_account_id=" + account.getStripeAccountId() + ", stripe_secret_configured=" + checkoutService.isConfigured();
            return HttpResponse.status(HttpStatus.SERVICE_UNAVAILABLE).body(java.util.Map.of("message", "Stripe Checkout ist für diesen Empfänger noch nicht aktiviert. Bitte zuerst das Stripe-Onboarding abschließen und den Status synchronisieren.", "detail", status));
        } catch (Exception exception) { return HttpResponse.status(HttpStatus.BAD_GATEWAY).body(java.util.Map.of("message", "Stripe Checkout konnte nicht erstellt werden: " + (exception.getMessage() == null ? exception.getClass().getSimpleName() : exception.getMessage()))); }
    }
}
