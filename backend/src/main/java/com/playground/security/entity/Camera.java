package com.playground.security.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;

@Entity
@Table(name = "cameras")
public class Camera {
    @Id
    @Column(length = 36)
    private String id;

    @Column(nullable = false, unique = true, length = 120)
    private String name;

    @Column(length = 300)
    private String location;

    @Column(name = "stream_url", length = 2048)
    private String streamUrl;

    @Column(nullable = false)
    private boolean enabled;

    @Column(name = "created_at", nullable = false)
    private OffsetDateTime createdAt;

    protected Camera() {}

    public Camera(String id, String name, String location, String streamUrl) {
        this.id = id;
        this.name = name;
        this.location = location;
        this.streamUrl = streamUrl;
        this.enabled = true;
        this.createdAt = OffsetDateTime.now(ZoneOffset.UTC);
    }

    public String getId() { return id; }
    public String getName() { return name; }
    public String getLocation() { return location; }
    public String getStreamUrl() { return streamUrl; }
    public boolean isEnabled() { return enabled; }
    public OffsetDateTime getCreatedAt() { return createdAt; }

    public void update(String name, String location, String streamUrl, boolean enabled) {
        this.name = name;
        this.location = location;
        this.streamUrl = streamUrl;
        this.enabled = enabled;
    }
}
