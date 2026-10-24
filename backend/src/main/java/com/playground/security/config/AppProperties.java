package com.playground.security.config;

import java.time.Duration;
import java.util.List;
import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "app")
public record AppProperties(Ingest ingest, Media media, Cors cors) {
    public record Ingest(String token, Duration deduplicationWindow) {}

    public record Media(String directory) {}

    public record Cors(List<String> allowedOrigins) {}
}
