package com.playground.security.controller;

import com.playground.security.dto.IncidentResponse;
import com.playground.security.dto.IngestRequest;
import com.playground.security.dto.PersonResponse;
import com.playground.security.service.AlertBroadcaster;
import com.playground.security.service.PlaygroundService;
import jakarta.validation.Valid;
import java.security.MessageDigest;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;
import com.playground.security.common.ApiException;
import com.playground.security.config.AppProperties;

@RestController
@RequestMapping("/api/v1")
public class IncidentController {
    private final PlaygroundService service;
    private final AlertBroadcaster alertBroadcaster;
    private final AppProperties properties;

    public IncidentController(
            PlaygroundService service, AlertBroadcaster alertBroadcaster, AppProperties properties) {
        this.service = service;
        this.alertBroadcaster = alertBroadcaster;
        this.properties = properties;
    }

    /** Live alert feed for the operator console (Server-Sent Events). */
    @GetMapping(value = "/alerts/stream", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    public SseEmitter alertsStream() {
        return alertBroadcaster.register();
    }

    @GetMapping("/incidents")
    public List<IncidentResponse> incidents() {
        return service.incidents().stream().map(IncidentResponse::from).toList();
    }

    @GetMapping("/persons")
    public List<PersonResponse> persons() {
        return service.persons().stream().map(PersonResponse::from).toList();
    }

    @PostMapping("/persons/{id}/confirm")
    public ResponseEntity<Void> confirmPerson(@PathVariable String id) {
        service.confirmPerson(id);
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/incidents")
    public ResponseEntity<IncidentResponse> ingest(
            @RequestHeader(name = "X-Ingest-Token", required = false) String token,
            @Valid @RequestBody IngestRequest request) {
        String expectedToken = properties.ingest().token();
        if (expectedToken == null || expectedToken.isBlank()) {
            throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE,
                    "INGEST_NOT_CONFIGURED", "Incident ingestion is not configured.");
        }
        if (token == null || !MessageDigest.isEqual(
                expectedToken.getBytes(java.nio.charset.StandardCharsets.UTF_8),
                token.getBytes(java.nio.charset.StandardCharsets.UTF_8))) {
            throw new ApiException(HttpStatus.UNAUTHORIZED,
                    "UNAUTHORIZED", "A valid ingest token is required.");
        }
        PlaygroundService.IngestResult result = service.ingest(request);
        return ResponseEntity.status(result.created() ? HttpStatus.CREATED : HttpStatus.OK)
                .body(IncidentResponse.from(result.incident()));
    }
}
