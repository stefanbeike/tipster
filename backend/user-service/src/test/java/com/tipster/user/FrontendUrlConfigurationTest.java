package com.tipster.user;

import io.micronaut.context.ApplicationContext;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;

class FrontendUrlConfigurationTest {
    @Test
    void preservesProtocolHostAndPortInDefaultFrontendUrl() {
        try (ApplicationContext context = ApplicationContext.builder()
                .environmentPropertySource(false).build()) {
            context.getEnvironment().start();

            assertEquals("http://localhost:3000", context.getEnvironment()
                    .getRequiredProperty("frontend.base-url", String.class));
            assertEquals("http://localhost:3000", context.getEnvironment()
                    .getRequiredProperty("micronaut.server.cors.configurations.default.allowed-origins[0]", String.class));
        }
    }
}
