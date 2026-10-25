package com.playground.security.config;

import java.time.Duration;
import java.util.List;
import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "app")
public record AppProperties(Ingest ingest, Media media, Cors cors, Security security, Cv cv) {
    public record Ingest(String token, Duration deduplicationWindow) {}

    public record Media(String directory) {}

    public record Cors(List<String> allowedOrigins) {}

    public record Security(String jwtSecret, String initialAdminUsername,
                           String initialAdminPassword) {}

    public record Cv(boolean enabled, String baseUrl, Duration longpollTimeout,
                     Duration errorBackoff) {}
}
