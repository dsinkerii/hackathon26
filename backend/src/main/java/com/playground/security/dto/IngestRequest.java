package com.playground.security.dto;

import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.time.OffsetDateTime;

public record IngestRequest(
        @NotBlank @Size(max = 64) String type,
        @NotNull OffsetDateTime occurredAt,
        @Size(max = 200) String trackId,
        @DecimalMin("0.0") @DecimalMax("1.0") Double confidence,
        @Size(max = 1000) String description,
        @Size(max = 36) String personId,
        @Size(max = 7_000_000) String snapshotBase64,
        @Size(max = 7_000_000) String faceSnapshotBase64) {}
