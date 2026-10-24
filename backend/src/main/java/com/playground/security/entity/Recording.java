package com.playground.security.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;

@Entity
@Table(name = "recordings")
public class Recording {
    @Id
    @Column(length = 36)
    private String id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "camera_id")
    private Camera camera;

    @Column(nullable = false, length = 200)
    private String title;

    @Column(name = "event_type", length = 64)
    private String eventType;

    @Column(name = "recorded_at", nullable = false)
    private OffsetDateTime recordedAt;

    @Column(name = "duration_seconds")
    private Integer durationSeconds;

    @Column(name = "video_url", nullable = false, length = 2048)
    private String videoUrl;

    @Column(name = "created_at", nullable = false)
    private OffsetDateTime createdAt;

    protected Recording() {}

    public Recording(String id, Camera camera, String title, String eventType,
                     OffsetDateTime recordedAt, Integer durationSeconds, String videoUrl) {
        this.id = id;
        this.camera = camera;
        this.title = title;
        this.eventType = eventType;
        this.recordedAt = recordedAt;
        this.durationSeconds = durationSeconds;
        this.videoUrl = videoUrl;
        this.createdAt = OffsetDateTime.now(ZoneOffset.UTC);
    }

    public String getId() { return id; }
    public Camera getCamera() { return camera; }
    public String getTitle() { return title; }
    public String getEventType() { return eventType; }
    public OffsetDateTime getRecordedAt() { return recordedAt; }
    public Integer getDurationSeconds() { return durationSeconds; }
    public String getVideoUrl() { return videoUrl; }

    public void update(Camera camera, String title, String eventType,
                       OffsetDateTime recordedAt, Integer durationSeconds, String videoUrl) {
        this.camera = camera;
        this.title = title;
        this.eventType = eventType;
        this.recordedAt = recordedAt;
        this.durationSeconds = durationSeconds;
        this.videoUrl = videoUrl;
    }
}
