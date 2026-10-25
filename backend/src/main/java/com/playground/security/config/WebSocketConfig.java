package com.playground.security.config;

import com.playground.security.alerts.AlertHandshakeInterceptor;
import com.playground.security.alerts.AlertWebSocketHandler;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.socket.config.annotation.EnableWebSocket;
import org.springframework.web.socket.config.annotation.WebSocketConfigurer;
import org.springframework.web.socket.config.annotation.WebSocketHandlerRegistry;

@Configuration
@EnableWebSocket
public class WebSocketConfig implements WebSocketConfigurer {
    private final AlertWebSocketHandler handler;
    private final AlertHandshakeInterceptor handshakeInterceptor;

    public WebSocketConfig(
            AlertWebSocketHandler handler,
            AlertHandshakeInterceptor handshakeInterceptor) {
        this.handler = handler;
        this.handshakeInterceptor = handshakeInterceptor;
    }

    @Override
    public void registerWebSocketHandlers(WebSocketHandlerRegistry registry) {
        // Same-origin nginx is the normal path, but operators may also open the
        // app through a LAN address. Handshakes are still authenticated by the
        // JWT query parameter in AlertHandshakeInterceptor, so the origin
        // pattern does not grant access on its own.
        registry.addHandler(handler, "/ws/alerts")
                .addInterceptors(handshakeInterceptor)
                .setAllowedOriginPatterns("*");
    }
}
