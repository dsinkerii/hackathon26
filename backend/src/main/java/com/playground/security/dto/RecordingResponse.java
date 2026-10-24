package com.playground.security.dto;

import com.playground.security.entity.Camera;
import com.playground.security.entity.Recording;
import java.time.OffsetDateTime;

public record RecordingResponse(
        String id,
        String cameraId,
        String cameraName,
        String title,
        String eventType,
        OffsetDateTime recordedAt,
        Integer durationSeconds,
        String videoUrl) {
    public static RecordingResponse from(Recording recording) {
        Camera camera = recording.getCamera();
        return new RecordingResponse(
                recording.getId(),
                camera == null ? null : camera.getId(),
                camera == null ? null : camera.getName(),
                recording.getTitle(),
                recording.getEventType(),
                recording.getRecordedAt(),
                recording.getDurationSeconds(),
                recording.getVideoUrl());
    }
}
