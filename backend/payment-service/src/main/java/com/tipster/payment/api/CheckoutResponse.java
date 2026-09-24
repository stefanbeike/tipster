package com.tipster.payment.api;
import io.micronaut.serde.annotation.Serdeable;
@Serdeable public record CheckoutResponse(String checkoutUrl, String transactionId, boolean demo) {}
