package com.playground.security.cv;

import com.playground.security.dto.IngestRequest;
import java.io.IOException;
import java.util.Optional;

/** Pulls one queued alert from the CV service's longpoll endpoint. */
public interface CvAlertsClient {
    /**
     * Blocks until an alert arrives, the CV longpoll times out, or the request
     * fails.
     *
     * @return the alert, or empty when CV returned {@code 204 No Content}
     */
    Optional<IngestRequest> nextAlert() throws IOException, InterruptedException;
}
