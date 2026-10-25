package com.playground.security.cv;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.playground.security.config.AppProperties;
import com.playground.security.dto.IngestRequest;
import com.playground.security.service.IncidentIngestService;
import jakarta.annotation.PreDestroy;
import java.time.Duration;
import java.util.Optional;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Component;

/**
 * Long-running consumer for {@code GET /alerts/longpoll} on the CV service.
 * It deliberately runs on its own daemon thread: the longpoll blocks for up to
 * 60 seconds, so it must never occupy a normal request thread.
 */
@Component
public class CvAlertPoller {
    private static final Logger log = LoggerFactory.getLogger(CvAlertPoller.class);
    private static final long MAX_BACKOFF_MILLIS = 30_000;

    private final CvAlertsClient client;
    private final IncidentIngestService ingestService;
    private final AppProperties properties;

    private volatile boolean running;
    private Thread worker;

    public CvAlertPoller(
            CvAlertsClient client,
            IncidentIngestService ingestService,
            AppProperties properties) {
        this.client = client;
        this.ingestService = ingestService;
        this.properties = properties;
    }

    @EventListener(ApplicationReadyEvent.class)
    public void start() {
        if (!properties.cv().enabled() || running) {
            return;
        }
        running = true;
        worker = new Thread(this::loop, "cv-alert-poller");
        worker.setDaemon(true);
        worker.start();
        log.info("CV alert poller started");
    }

    /**
     * One longpoll cycle. Kept package-private so tests can drive the consumer
     * deterministically without starting the background thread.
     */
    boolean pollOnce() {
        final Optional<IngestRequest> alert;
        try {
            alert = client.nextAlert();
        } catch (JsonProcessingException exception) {
            log.warn("CV sent an unreadable alert, skipping it: {}", exception.getMessage());
            return true;
        } catch (InterruptedException exception) {
            Thread.currentThread().interrupt();
            return false;
        } catch (Exception exception) {
            log.warn("CV longpoll failed: {}", exception.toString());
            return false;
        }

        if (alert.isEmpty()) {
            return true;
        }

        try {
            var result = ingestService.ingest(alert.get());
            log.info("CV alert ingested: type={} created={}",
                    result.incident().getType(), result.created());
        } catch (Exception exception) {
            // A single malformed or conflicting alert must not kill the poller.
            log.error("Could not ingest CV alert: {}", exception.getMessage(), exception);
        }
        return true;
    }

    private void loop() {
        Duration baseBackoff = properties.cv().errorBackoff();
        long backoffMillis = Math.max(500, baseBackoff.toMillis());

        while (running && !Thread.currentThread().isInterrupted()) {
            boolean ok;
            try {
                ok = pollOnce();
            } catch (Exception exception) {
                log.error("Unexpected CV poller failure", exception);
                ok = false;
            }
            if (ok) {
                backoffMillis = Math.max(500, baseBackoff.toMillis());
                continue;
            }
            try {
                Thread.sleep(backoffMillis);
            } catch (InterruptedException exception) {
                Thread.currentThread().interrupt();
                break;
            }
            backoffMillis = Math.min(MAX_BACKOFF_MILLIS, backoffMillis * 2);
        }
        log.info("CV alert poller stopped");
    }

    @PreDestroy
    public void stop() {
        running = false;
        if (worker != null) {
            worker.interrupt();
        }
    }
}
