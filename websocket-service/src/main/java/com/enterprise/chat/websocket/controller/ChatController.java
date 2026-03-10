package com.enterprise.chat.websocket.controller;

import com.enterprise.chat.websocket.model.ChatMessage;
import lombok.RequiredArgsConstructor;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.messaging.handler.annotation.MessageMapping;
import org.springframework.messaging.handler.annotation.Payload;
import org.springframework.stereotype.Controller;
import java.time.Instant;

@Controller
@RequiredArgsConstructor
@lombok.extern.slf4j.Slf4j
public class ChatController {
    private final KafkaTemplate<String, Object> kafkaTemplate;

    @MessageMapping("/chat.send")
    public void sendMessage(@Payload ChatMessage chatMessage) {
        log.info("Received WebSocket message: {}", chatMessage);
        
        if (chatMessage.getTimestamp() == 0) {
            chatMessage.setTimestamp(Instant.now().toEpochMilli());
        }
        
        log.info("Publishing to Kafka: chatId={}, content={}, mediaUrl={}", 
            chatMessage.getChatId(), chatMessage.getContent(), chatMessage.getMediaUrl());
        
        // Send to Kafka for MessageService to persist to Cassandra, and for our own Consumer to broadcast to Redis
        kafkaTemplate.send("chat-messages", chatMessage.getChatId(), chatMessage);
    }
}
