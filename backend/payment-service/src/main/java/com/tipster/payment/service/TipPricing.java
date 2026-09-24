package com.tipster.payment.service;
public final class TipPricing {
    private TipPricing() {}
    public static long serviceFeeMinor(long tipMinor) {
        if (tipMinor < 100) throw new IllegalArgumentException("Das Mindesttrinkgeld beträgt 1,00 EUR");
        return 0;
    }
    public static long totalMinor(long tipMinor) { return tipMinor; }
}
