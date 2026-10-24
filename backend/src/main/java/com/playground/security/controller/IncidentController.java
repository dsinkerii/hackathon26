package com.playground.security.controller;

import com.playground.security.dto.IncidentResponse;
import com.playground.security.dto.IngestRequest;
import com.playground.security.dto.PersonResponse;
import com.playground.security.service.PlaygroundService;
import jakarta.validation.Valid;
import java.security.MessageDigest;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import com.playground.security.common.ApiException;
import com.playground.security.config.AppProperties;

@RestController
@RequestMapping("/api/v1")
public class IncidentController {
    private final PlaygroundService service;
    private final AppProperties properties;

    public IncidentController(PlaygroundService service, AppProperties properties) {
        this.service = service;
        this.properties = properties;
    }

    @GetMapping("/incidents")
    public List<IncidentResponse> incidents() {
        return service.incidents().stream().map(IncidentResponse::from).toList();
    }

    @GetMapping("/persons")
    public List<PersonResponse> persons(
            @RequestParam(name = "status", required = false) String status) {
        return service.persons(status).stream().map(PersonResponse::from).toList();
    }

    @PostMapping("/persons/{id}/confirm")
    public ResponseEntity<Void> confirmPerson(@PathVariable String id) {
        service.confirmPerson(id);
        return ResponseEntity.noContent().build();
    }

    /** Удаление посетителя (например, из белого списка) вместе с его инцидентами. */
    @DeleteMapping("/persons/{id}")
    public ResponseEntity<Void> deletePerson(@PathVariable String id) {
        service.deletePerson(id);
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
