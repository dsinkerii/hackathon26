package com.playground.security.dto;

import com.playground.security.entity.Incident;
import java.time.OffsetDateTime;

public record IncidentResponse(
        String id,
        String type,
        OffsetDateTime occurredAt,
        String description,
        String snapshotUrl) {
    public static IncidentResponse from(Incident incident) {
        return new IncidentResponse(
                incident.getId(),
                incident.getType(),
                incident.getOccurredAt(),
                incident.getDescription(),
                incident.getSnapshotUrl());
    }
}
