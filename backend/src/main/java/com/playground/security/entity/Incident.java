package com.playground.security.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import java.time.OffsetDateTime;

@Entity
@Table(name = "incidents")
public class Incident {
    @Id
    @Column(length = 36)
    private String id;

    @Column(nullable = false, length = 64)
    private String type;

    @Column(name = "occurred_at", nullable = false)
    private OffsetDateTime occurredAt;

    @Column(length = 1000)
    private String description;

    @Column(name = "snapshot_url", length = 1024)
    private String snapshotUrl;

    @Column(name = "track_id", length = 200)
    private String trackId;

    private Double confidence;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "person_id")
    private Person person;

    protected Incident() {}

    public Incident(String id, String type, OffsetDateTime occurredAt, String description,
                    String snapshotUrl, String trackId, Double confidence, Person person) {
        this.id = id;
        this.type = type;
        this.occurredAt = occurredAt;
        this.description = description;
        this.snapshotUrl = snapshotUrl;
        this.trackId = trackId;
        this.confidence = confidence;
        this.person = person;
    }

    public String getId() { return id; }
    public String getType() { return type; }
    public OffsetDateTime getOccurredAt() { return occurredAt; }
    public String getDescription() { return description; }
    public String getSnapshotUrl() { return snapshotUrl; }
    public String getTrackId() { return trackId; }
    public Double getConfidence() { return confidence; }
}
