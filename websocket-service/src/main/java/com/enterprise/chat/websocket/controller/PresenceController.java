package com.enterprise.chat.websocket.controller;

import com.enterprise.chat.websocket.service.PresenceService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.event.EventListener;
import org.springframework.messaging.simp.SimpMessageHeaderAccessor;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Controller;
import org.springframework.web.socket.messaging.SessionConnectEvent;
import org.springframework.web.socket.messaging.SessionDisconnectEvent;

import java.util.Map;

@Controller
@Slf4j
@RequiredArgsConstructor
public class PresenceController {

    private final PresenceService presenceService;
    private final SimpMessagingTemplate messagingTemplate;

    @EventListener
    public void handleSessionConnect(SessionConnectEvent event) {
        SimpMessageHeaderAccessor headers = SimpMessageHeaderAccessor.wrap(event.getMessage());
        String username = getUsername(headers);
        if (username != null) {
            log.info("User connected: {}", username);
            presenceService.setOnline(username);
            broadcastPresence(username, true);
        }
    }

    @EventListener
    public void handleSessionDisconnect(SessionDisconnectEvent event) {
        SimpMessageHeaderAccessor headers = SimpMessageHeaderAccessor.wrap(event.getMessage());
        String username = getUsername(headers);
        if (username != null) {
            log.info("User disconnected: {}", username);
            presenceService.setOffline(username);
            broadcastPresence(username, false);
        }
    }

    private void broadcastPresence(String username, boolean isOnline) {
        java.util.Map<String, String> payload = new java.util.HashMap<>();
        payload.put("username", username);
        payload.put("status", isOnline ? "ONLINE" : "OFFLINE");
        messagingTemplate.convertAndSend("/topic/presence", payload);
    }

    private String getUsername(SimpMessageHeaderAccessor headers) {
        java.util.Map<String, Object> attributes = headers.getSessionAttributes();
        Object username = attributes != null ? attributes.get("username") : null;
        if (username == null) {
            username = headers.getFirstNativeHeader("username");
        }
        return (String) username;
    }
}
