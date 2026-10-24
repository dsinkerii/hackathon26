package com.playground.security.service;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.playground.security.dto.IncidentResponse;
import jakarta.annotation.PreDestroy;
import java.io.IOException;
import java.util.List;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

/**
 * Keeps one SSE connection per operator console and pushes every newly
 * created incident as an "alert" event. A periodic heartbeat comment keeps
 * intermediaries from closing the stream and lets clients detect a dead
 * connection quickly.
 */
@Service
public class AlertBroadcaster {
    private static final Logger log = LoggerFactory.getLogger(AlertBroadcaster.class);
    private static final String ALERT_EVENT = "alert";
    private static final long HEARTBEAT_PERIOD_SECONDS = 15;

    private final List<SseEmitter> emitters = new CopyOnWriteArrayList<>();
    private final ObjectMapper objectMapper;
    private final ScheduledExecutorService heartbeat;

    public AlertBroadcaster(ObjectMapper objectMapper) {
        this.objectMapper = objectMapper;
        this.heartbeat = Executors.newSingleThreadScheduledExecutor(runnable -> {
            Thread thread = new Thread(runnable, "alerts-heartbeat");
            thread.setDaemon(true);
            return thread;
        });
        this.heartbeat.scheduleWithFixedDelay(
                this::beat, HEARTBEAT_PERIOD_SECONDS, HEARTBEAT_PERIOD_SECONDS, TimeUnit.SECONDS);
    }

    /**
     * Registers an operator console.
     *
     * @return an emitter the MVC layer returns to the client (no timeout:
     *         dead links are detected via the heartbeat and client reconnect).
     */
    public SseEmitter register() {
        SseEmitter emitter = new SseEmitter(0L);
        emitter.onCompletion(() -> emitters.remove(emitter));
        emitter.onTimeout(() -> emitters.remove(emitter));
        emitter.onError(ignored -> emitters.remove(emitter));
        try {
            emitter.send(SseEmitter.event().name("connected").data("ready"));
        } catch (IOException e) {
            log.debug("Could not greet a new operator console: {}", e.getMessage());
        }
        emitters.add(emitter);
        return emitter;
    }

    /** Pushes a newly created incident to every connected console. */
    public void broadcast(IncidentResponse alert) {
        String payload;
        try {
            payload = objectMapper.writeValueAsString(alert);
        } catch (JsonProcessingException e) {
            log.error("Failed to serialize alert payload", e);
            return;
        }
        for (SseEmitter emitter : emitters) {
            try {
                emitter.send(SseEmitter.event().name(ALERT_EVENT).data(payload));
            } catch (IOException | IllegalStateException e) {
                emitters.remove(emitter);
            }
        }
    }

    private void beat() {
        for (SseEmitter emitter : emitters) {
            try {
                emitter.send(SseEmitter.event().comment("heartbeat"));
            } catch (IOException | IllegalStateException e) {
                emitters.remove(emitter);
            }
        }
    }

    @PreDestroy
    void shutdown() {
        heartbeat.shutdownNow();
        for (SseEmitter emitter : emitters) {
            emitter.complete();
        }
        emitters.clear();
    }
}
