package com.playground.security.cv;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.playground.security.config.AppProperties;
import com.playground.security.dto.IngestRequest;
import com.playground.security.entity.Incident;
import com.playground.security.service.IncidentIngestService;
import com.playground.security.service.PlaygroundService;
import java.io.IOException;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.Optional;
import org.junit.jupiter.api.Test;

class CvAlertPollerTest {
    private final IncidentIngestService ingestService = mock(IncidentIngestService.class);

    @Test
    void ingestsAnAlertReturnedByTheLongpoll() throws Exception {
        IngestRequest request = new IngestRequest(
                "VEHICLE_IN_ZONE",
                OffsetDateTime.of(2026, 10, 25, 10, 0, 0, 0, ZoneOffset.UTC),
                "vehicle-7",
                0.91,
                null,
                null,
                "/9j/4AAQ",
                null);
        Incident incident = new Incident(
                "incident-1",
                request.type(),
                request.occurredAt(),
                "Автомобиль на детской площадке",
                "/media/snapshots/incident-1.jpg",
                request.trackId(),
                request.confidence(),
                null);
        when(ingestService.ingest(request))
                .thenReturn(new PlaygroundService.IngestResult(incident, true));

        CvAlertsClient client = () -> Optional.of(request);
        CvAlertPoller poller = new CvAlertPoller(client, ingestService, properties());

        assertTrue(poller.pollOnce());
        verify(ingestService).ingest(request);
    }

    @Test
    void ignoresAnEmptyLongpollResponse() throws Exception {
        CvAlertsClient client = () -> Optional.empty();
        CvAlertPoller poller = new CvAlertPoller(client, ingestService, properties());

        assertTrue(poller.pollOnce());
        verify(ingestService, never()).ingest(org.mockito.ArgumentMatchers.<IngestRequest>any());
    }

    @Test
    void reportsFailureSoTheLoopCanBackOff() throws Exception {
        CvAlertsClient client = () -> {
            throw new IOException("CV is down");
        };
        CvAlertPoller poller = new CvAlertPoller(client, ingestService, properties());

        assertFalse(poller.pollOnce());
        verify(ingestService, never()).ingest(org.mockito.ArgumentMatchers.<IngestRequest>any());
    }

    private AppProperties properties() {
        return new AppProperties(
                null,
                null,
                null,
                null,
                new AppProperties.Cv(
                        false,
                        "http://127.0.0.1:6532",
                        java.time.Duration.ofSeconds(1),
                        java.time.Duration.ofSeconds(1)));
    }
}
