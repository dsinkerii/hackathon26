package com.playground.security.alerts;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.playground.security.dto.IncidentResponse;
import java.io.IOException;
import java.util.Set;
import java.util.concurrent.CopyOnWriteArraySet;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.CloseStatus;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;
import org.springframework.web.socket.handler.TextWebSocketHandler;

/**
 * Raw WebSocket endpoint for operator clients. Every saved incident is pushed
 * to every connected client; clients never need to poll for alerts.
 */
@Component
public class AlertWebSocketHandler extends TextWebSocketHandler {
    private static final Logger log = LoggerFactory.getLogger(AlertWebSocketHandler.class);

    private final ObjectMapper objectMapper;
    private final Set<WebSocketSession> sessions = new CopyOnWriteArraySet<>();

    public AlertWebSocketHandler(ObjectMapper objectMapper) {
        this.objectMapper = objectMapper;
    }

    @Override
    public void afterConnectionEstablished(WebSocketSession session) {
        sessions.add(session);
        log.info("Alert WebSocket connected: {} ({} clients)", session.getId(), sessions.size());
    }

    @Override
    public void afterConnectionClosed(WebSocketSession session, CloseStatus status) {
        sessions.remove(session);
        log.info("Alert WebSocket disconnected: {} ({} clients)", session.getId(), sessions.size());
    }

    @Override
    public void handleTransportError(WebSocketSession session, Throwable exception) {
        log.debug("Alert WebSocket transport error on {}", session.getId(), exception);
        sessions.remove(session);
    }

    public void broadcast(IncidentResponse incident) {
        if (sessions.isEmpty()) {
            return;
        }
        final String payload;
        try {
            payload = objectMapper.writeValueAsString(incident);
        } catch (JsonProcessingException exception) {
            log.error("Could not serialize incident alert {}", incident.id(), exception);
            return;
        }

        TextMessage message = new TextMessage(payload);
        for (WebSocketSession session : sessions) {
            // WebSocketSession is not safe for concurrent sends.
            synchronized (session) {
                if (!session.isOpen()) {
                    sessions.remove(session);
                    continue;
                }
                try {
                    session.sendMessage(message);
                } catch (IOException exception) {
                    log.debug("Dropping closed alert client {}", session.getId(), exception);
                    sessions.remove(session);
                }
            }
        }
    }

    public int connectedClients() {
        return sessions.size();
    }
}
