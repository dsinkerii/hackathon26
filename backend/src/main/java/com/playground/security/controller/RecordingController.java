package com.playground.security.controller;

import com.playground.security.common.ApiException;
import com.playground.security.dto.RecordingResponse;
import com.playground.security.entity.Camera;
import com.playground.security.entity.Recording;
import com.playground.security.repository.CameraRepository;
import com.playground.security.repository.RecordingRepository;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;
import java.net.URI;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;
import org.springframework.data.domain.Sort;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/recordings")
public class RecordingController {
    private final RecordingRepository recordings;
    private final CameraRepository cameras;

    public RecordingController(RecordingRepository recordings, CameraRepository cameras) {
        this.recordings = recordings;
        this.cameras = cameras;
    }

    @GetMapping
    public List<RecordingResponse> list(
            @AuthenticationPrincipal Jwt principal,
            @RequestParam(required = false) String cameraId,
            @RequestParam(required = false) Boolean withoutCamera,
            @RequestParam(required = false) OffsetDateTime from,
            @RequestParam(required = false) OffsetDateTime to) {
        boolean admin = "ADMIN".equals(principal.getClaimAsString("role"));
        if (Boolean.TRUE.equals(withoutCamera) && !admin) {
            throw new ApiException(HttpStatus.FORBIDDEN, "CATEGORY_HIDDEN",
                    "The no-camera category is available to administrators only.");
        }
        if (from != null && to != null && !from.isBefore(to)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_DATE_RANGE",
                    "'from' must be earlier than 'to'.");
        }
        return recordings.findAll(
                        RecordingRepository.byFilters(
                                cameraId, withoutCamera, admin, from, to),
                        Sort.by(Sort.Direction.DESC, "recordedAt"))
                .stream().map(RecordingResponse::from).toList();
    }

    @PostMapping
    @PreAuthorize("hasRole('ADMIN')")
    @Transactional
    public RecordingResponse create(@Valid @RequestBody RecordingRequest request) {
        return RecordingResponse.from(recordings.save(new Recording(
                UUID.randomUUID().toString(),
                resolveCamera(request.cameraId()),
                request.title().trim(),
                clean(request.eventType()),
                request.recordedAt(),
                request.durationSeconds(),
                validateUrl(request.videoUrl()))));
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    @Transactional
    public RecordingResponse update(
            @PathVariable String id, @Valid @RequestBody RecordingRequest request) {
        Recording recording = recordings.findById(id)
                .orElseThrow(() -> new ApiException(
                        HttpStatus.NOT_FOUND, "RECORDING_NOT_FOUND", "Recording was not found."));
        recording.update(resolveCamera(request.cameraId()), request.title().trim(),
                clean(request.eventType()), request.recordedAt(),
                request.durationSeconds(), validateUrl(request.videoUrl()));
        return RecordingResponse.from(recordings.save(recording));
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    public org.springframework.http.ResponseEntity<Void> delete(@PathVariable String id) {
        if (!recordings.existsById(id)) {
            throw new ApiException(HttpStatus.NOT_FOUND, "RECORDING_NOT_FOUND", "Recording was not found.");
        }
        recordings.deleteById(id);
        return org.springframework.http.ResponseEntity.noContent().build();
    }

    private Camera resolveCamera(String id) {
        if (id == null || id.isBlank()) {
            return null;
        }
        return cameras.findById(id)
                .orElseThrow(() -> new ApiException(
                        HttpStatus.NOT_FOUND, "CAMERA_NOT_FOUND", "Camera was not found."));
    }

    private String validateUrl(String value) {
        URI uri;
        try {
            uri = URI.create(value.trim());
        } catch (IllegalArgumentException exception) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_URL", "Video URL is invalid.");
        }
        if (!uri.isAbsolute() || uri.getHost() == null
                || !(uri.getScheme().equalsIgnoreCase("http") || uri.getScheme().equalsIgnoreCase("https"))) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_URL",
                    "Video URL must use HTTP or HTTPS.");
        }
        return uri.toString();
    }

    private String clean(String value) {
        return value == null || value.isBlank() ? null : value.trim();
    }

    public record RecordingRequest(
            @Size(max = 36) String cameraId,
            @NotBlank @Size(max = 200) String title,
            @Size(max = 64) String eventType,
            @NotNull OffsetDateTime recordedAt,
            @Positive Integer durationSeconds,
            @NotBlank @Size(max = 2048) String videoUrl) {}
}
