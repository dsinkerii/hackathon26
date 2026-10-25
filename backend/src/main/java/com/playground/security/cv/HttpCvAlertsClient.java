package com.playground.security.cv;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.playground.security.config.AppProperties;
import com.playground.security.dto.IngestRequest;
import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.Optional;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.springframework.util.StringUtils;

/**
 * Java HttpClient implementation of the CV longpoll. The read timeout is
 * deliberately longer than the CV-side wait, otherwise every idle longpoll
 * would look like a connection failure.
 */
@Component
public class HttpCvAlertsClient implements CvAlertsClient {
    private static final Logger log = LoggerFactory.getLogger(HttpCvAlertsClient.class);

    private final HttpClient httpClient;
    private final ObjectMapper objectMapper;
    private final URI longpollUri;
    private final Duration requestTimeout;

    public HttpCvAlertsClient(AppProperties properties, ObjectMapper objectMapper) {
        this.objectMapper = objectMapper;
        String baseUrl = properties.cv().baseUrl();
        if (!StringUtils.hasText(baseUrl)) {
            baseUrl = "http://127.0.0.1:6532";
        }
        baseUrl = baseUrl.replaceAll("/+$", "");
        long longpollSeconds = Math.max(1, properties.cv().longpollTimeout().toSeconds());
        this.longpollUri = URI.create(baseUrl + "/alerts/longpoll?timeout=" + longpollSeconds);
        this.requestTimeout = properties.cv().longpollTimeout().plusSeconds(5);
        this.httpClient = HttpClient.newBuilder()
                .connectTimeout(Duration.ofSeconds(3))
                .build();
        log.info("CV alert source: {} (longpoll timeout {})", longpollUri, requestTimeout);
    }

    @Override
    public Optional<IngestRequest> nextAlert() throws IOException, InterruptedException {
        HttpRequest request = HttpRequest.newBuilder(longpollUri)
                .timeout(requestTimeout)
                .header("Accept", "application/json")
                .GET()
                .build();
        HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
        if (response.statusCode() == 204) {
            return Optional.empty();
        }
        if (response.statusCode() != 200) {
            throw new IOException("CV longpoll returned HTTP " + response.statusCode());
        }
        String body = response.body();
        if (!StringUtils.hasText(body)) {
            return Optional.empty();
        }
        return Optional.of(objectMapper.readValue(body, IngestRequest.class));
    }
}
