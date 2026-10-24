package com.playground.security.dto;

import com.playground.security.entity.Camera;
import java.time.OffsetDateTime;

public record CameraResponse(
        String id, String name, String location, String streamUrl, boolean enabled, OffsetDateTime createdAt) {
    public static CameraResponse from(Camera camera) {
        return new CameraResponse(camera.getId(), camera.getName(), camera.getLocation(),
                camera.getStreamUrl(), camera.isEnabled(), camera.getCreatedAt());
    }
}
