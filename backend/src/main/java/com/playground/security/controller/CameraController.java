package com.playground.security.controller;

import com.playground.security.common.ApiException;
import com.playground.security.dto.CameraResponse;
import com.playground.security.entity.Camera;
import com.playground.security.repository.CameraRepository;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.net.URI;
import java.util.List;
import java.util.UUID;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/cameras")
public class CameraController {
    private final CameraRepository cameras;

    public CameraController(CameraRepository cameras) {
        this.cameras = cameras;
    }

    @GetMapping
    public List<CameraResponse> list() {
        return cameras.findAllByOrderByNameAsc().stream().map(CameraResponse::from).toList();
    }

    @PostMapping
    @PreAuthorize("hasRole('ADMIN')")
    public CameraResponse create(@Valid @RequestBody CameraRequest request) {
        String name = request.name().trim();
        if (cameras.existsByNameIgnoreCase(name)) {
            throw new ApiException(HttpStatus.CONFLICT, "CAMERA_NAME_TAKEN", "Camera name already exists.");
        }
        return CameraResponse.from(cameras.save(new Camera(
                UUID.randomUUID().toString(), name, clean(request.location()), validateUrl(request.streamUrl()))));
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    public CameraResponse update(@PathVariable String id, @Valid @RequestBody CameraRequest request) {
        Camera camera = cameras.findById(id)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "CAMERA_NOT_FOUND", "Camera was not found."));
        String name = request.name().trim();
        if (cameras.existsByNameIgnoreCaseAndIdNot(name, id)) {
            throw new ApiException(HttpStatus.CONFLICT, "CAMERA_NAME_TAKEN", "Camera name already exists.");
        }
        camera.update(name, clean(request.location()), validateUrl(request.streamUrl()), request.enabled());
        return CameraResponse.from(cameras.save(camera));
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    public org.springframework.http.ResponseEntity<Void> delete(@PathVariable String id) {
        if (!cameras.existsById(id)) {
            throw new ApiException(HttpStatus.NOT_FOUND, "CAMERA_NOT_FOUND", "Camera was not found.");
        }
        try {
            cameras.deleteById(id);
            cameras.flush();
        } catch (DataIntegrityViolationException exception) {
            throw new ApiException(HttpStatus.CONFLICT, "CAMERA_HAS_RECORDINGS",
                    "Camera cannot be deleted while it has recordings.");
        }
        return org.springframework.http.ResponseEntity.noContent().build();
    }

    private String validateUrl(String value) {
        String url = clean(value);
        if (url == null) {
            return null;
        }
        URI uri;
        try {
            uri = URI.create(url);
        } catch (IllegalArgumentException exception) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_URL", "URL is invalid.");
        }
        if (!uri.isAbsolute() || uri.getHost() == null
                || !(uri.getScheme().equalsIgnoreCase("http")
                        || uri.getScheme().equalsIgnoreCase("https")
                        || uri.getScheme().equalsIgnoreCase("rtsp")
                        || uri.getScheme().equalsIgnoreCase("rtsps"))) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_URL", "URL must use HTTP, HTTPS, or RTSP.");
        }
        return uri.toString();
    }

    private String clean(String value) {
        return value == null || value.isBlank() ? null : value.trim();
    }

    public record CameraRequest(
            @NotBlank @Size(max = 120) String name,
            @Size(max = 300) String location,
            @Size(max = 2048) String streamUrl,
            boolean enabled) {}
}
