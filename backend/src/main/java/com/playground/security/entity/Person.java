package com.playground.security.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.OffsetDateTime;

@Entity
@Table(name = "persons")
public class Person {
    @Id
    @Column(length = 36)
    private String id;

    @Column(name = "display_name", length = 200)
    private String displayName;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 24)
    private PersonStatus status;

    @Column(name = "first_seen_at", nullable = false)
    private OffsetDateTime firstSeenAt;

    @Column(name = "last_seen_at", nullable = false)
    private OffsetDateTime lastSeenAt;

    @Column(name = "visit_count", nullable = false)
    private int visitCount;

    @Column(name = "photo_url", length = 1024)
    private String photoUrl;

    protected Person() {}

    public Person(String id, PersonStatus status, OffsetDateTime firstSeenAt, String photoUrl) {
        this.id = id;
        this.status = status;
        this.firstSeenAt = firstSeenAt;
        this.lastSeenAt = firstSeenAt;
        this.visitCount = 1;
        this.photoUrl = photoUrl;
    }

    public String getId() { return id; }
    public String getDisplayName() { return displayName; }
    public PersonStatus getStatus() { return status; }
    public OffsetDateTime getFirstSeenAt() { return firstSeenAt; }
    public OffsetDateTime getLastSeenAt() { return lastSeenAt; }
    public int getVisitCount() { return visitCount; }
    public String getPhotoUrl() { return photoUrl; }

    public void recordVisit(OffsetDateTime occurredAt) {
        visitCount++;
        if (occurredAt.isAfter(lastSeenAt)) {
            lastSeenAt = occurredAt;
        }
    }

    public void confirm() {
        status = PersonStatus.TRUSTED;
    }
}
