package com.enterprise.chat.websocket.service;

import com.enterprise.chat.websocket.model.ChatMessage;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;

@Service
@Slf4j
@RequiredArgsConstructor
public class RedisSubscriber {

    private final ObjectMapper objectMapper;
    private final SimpMessagingTemplate messagingTemplate;

    public void onMessage(String message, String channel) {
        try {
            ChatMessage chatMessage = objectMapper.readValue(message, ChatMessage.class);
            // Broadcast to the target STOMP topic connected clients
            messagingTemplate.convertAndSend("/topic/chat." + chatMessage.getChatId(), chatMessage);
        } catch (Exception e) {
            log.error("Error deserializing message from Redis pub/sub", e);
        }
    }
}
