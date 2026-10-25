package com.playground.security.service;

import com.playground.security.alerts.AlertBroadcaster;
import com.playground.security.dto.IncidentResponse;
import com.playground.security.dto.IngestRequest;
import org.springframework.stereotype.Service;

/**
 * Single entry point for incidents coming from CV, whether they arrive through
 * the REST ingest endpoint or through the longpoll consumer.
 */
@Service
public class IncidentIngestService {
    private final PlaygroundService playgroundService;
    private final AlertBroadcaster broadcaster;

    public IncidentIngestService(
            PlaygroundService playgroundService,
            AlertBroadcaster broadcaster) {
        this.playgroundService = playgroundService;
        this.broadcaster = broadcaster;
    }

    /**
     * The transaction in {@link PlaygroundService#ingest} has committed by the
     * time this method returns, so clients never receive an alert for a row that
     * was rolled back.
     */
    public PlaygroundService.IngestResult ingest(IngestRequest request) {
        PlaygroundService.IngestResult result = playgroundService.ingest(request);
        if (result.created()) {
            broadcaster.broadcast(IncidentResponse.from(result.incident()));
        }
        return result;
    }
}
