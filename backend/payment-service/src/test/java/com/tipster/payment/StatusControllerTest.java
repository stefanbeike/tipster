package com.tipster.payment;

import io.micronaut.http.HttpRequest;
import io.micronaut.http.client.HttpClient;
import io.micronaut.http.client.annotation.Client;
import io.micronaut.test.extensions.junit5.annotation.MicronautTest;
import jakarta.inject.Inject;
import org.junit.jupiter.api.Test;

import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;

@MicronautTest
class StatusControllerTest {
    @Inject
    @Client("/")
    HttpClient client;

    @Test
    void exposesServiceStatus() {
        Map<?, ?> response = client.toBlocking().retrieve(HttpRequest.GET("/api/status"), Map.class);

        assertEquals("payment-service", response.get("service"));
        assertEquals("UP", response.get("status"));
    }
}
