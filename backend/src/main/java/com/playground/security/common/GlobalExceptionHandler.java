package com.playground.security.common;

import java.util.stream.Collectors;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.context.request.async.AsyncRequestNotUsableException;
import org.springframework.web.servlet.resource.NoResourceFoundException;

@RestControllerAdvice
public class GlobalExceptionHandler {
    private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandler.class);

    @ExceptionHandler(ApiException.class)
    public ResponseEntity<ApiError> handleApiException(ApiException exception) {
        return ResponseEntity.status(exception.status())
                .body(new ApiError(exception.code(), exception.getMessage()));
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ApiError> handleValidation(MethodArgumentNotValidException exception) {
        String message = exception.getBindingResult().getFieldErrors().stream()
                .map(error -> error.getField() + ": " + error.getDefaultMessage())
                .collect(Collectors.joining("; "));
        return ResponseEntity.badRequest()
                .body(new ApiError("VALIDATION_ERROR", message));
    }

    @ExceptionHandler(HttpMessageNotReadableException.class)
    public ResponseEntity<ApiError> handleUnreadableBody() {
        return ResponseEntity.badRequest()
                .body(new ApiError("INVALID_REQUEST", "Request body is invalid."));
    }

    /** Missing /favicon.ico and similar — a regular 404, not a server incident. */
    @ExceptionHandler(NoResourceFoundException.class)
    public ResponseEntity<ApiError> handleNoResource(NoResourceFoundException exception) {
        return ResponseEntity.status(HttpStatus.NOT_FOUND)
                .body(new ApiError("NOT_FOUND", "No resource: " + exception.getResourcePath()));
    }

    /**
     * The SSE client hung up mid-write (e.g. closed the tab). Spring reports it
     * through the async dispatch; nothing to answer to a dead connection.
     */
    @ExceptionHandler(AsyncRequestNotUsableException.class)
    public ResponseEntity<ApiError> handleClientDisconnected(AsyncRequestNotUsableException exception) {
        log.debug("Client disconnected while writing a response: {}", exception.getMessage());
        return ResponseEntity.noContent().build();
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ApiError> handleUnexpected(Exception exception) {
        log.error("Unhandled API error", exception);
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(new ApiError("INTERNAL_ERROR", "An unexpected server error occurred."));
    }
}
