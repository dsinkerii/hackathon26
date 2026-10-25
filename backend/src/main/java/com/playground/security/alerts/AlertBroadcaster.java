package com.playground.security.alerts;

import com.playground.security.dto.IncidentResponse;
import org.springframework.stereotype.Component;

/** Sends a saved incident to every connected operator app. */
@Component
public class AlertBroadcaster {
    private final AlertWebSocketHandler handler;

    public AlertBroadcaster(AlertWebSocketHandler handler) {
        this.handler = handler;
    }

    public void broadcast(IncidentResponse incident) {
        handler.broadcast(incident);
    }
}
