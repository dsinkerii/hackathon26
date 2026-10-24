package com.playground.security.media;

import com.playground.security.common.ApiException;
import com.playground.security.config.AppProperties;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Base64;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

@Service
public class MediaStorageService {
    private static final Logger log = LoggerFactory.getLogger(MediaStorageService.class);
    private static final int MAX_IMAGE_BYTES = 5 * 1024 * 1024;
    private final Path root;

    public MediaStorageService(AppProperties properties) {
        root = Path.of(properties.media().directory()).toAbsolutePath().normalize();
    }

    public String saveJpeg(String encoded, String category) {
        if (encoded == null || encoded.isBlank()) {
            return null;
        }
        final byte[] bytes;
        try {
            bytes = Base64.getDecoder().decode(encoded);
        } catch (IllegalArgumentException exception) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_IMAGE", "Image is not valid base64.");
        }
        if (bytes.length < 4 || bytes.length > MAX_IMAGE_BYTES
                || (bytes[0] & 0xff) != 0xff || (bytes[1] & 0xff) != 0xd8
                || (bytes[2] & 0xff) != 0xff) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_IMAGE", "Image must be a JPEG up to 5 MB.");
        }

        String filename = UUID.randomUUID() + ".jpg";
        Path directory = root.resolve(category).normalize();
        if (!directory.startsWith(root)) {
            throw new IllegalStateException("Invalid media category.");
        }
        try {
            Files.createDirectories(directory);
            Files.write(directory.resolve(filename), bytes);
        } catch (IOException exception) {
            log.error("Could not write uploaded image to media storage", exception);
            throw new ApiException(HttpStatus.INTERNAL_SERVER_ERROR, "MEDIA_STORAGE_FAILED",
                    "Could not store the image.");
        }
        return "/media/" + category + "/" + filename;
    }
}
