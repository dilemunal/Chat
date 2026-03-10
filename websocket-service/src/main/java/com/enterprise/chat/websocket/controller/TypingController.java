package com.enterprise.chat.websocket.controller;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.RequiredArgsConstructor;
import org.springframework.messaging.handler.annotation.MessageMapping;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Controller;

@Controller
@RequiredArgsConstructor
public class TypingController {

    private final SimpMessagingTemplate messagingTemplate;

    @MessageMapping("/typing")
    public void handleTyping(TypingEvent event) {
        // Broadcast to the chat room topic
        messagingTemplate.convertAndSend("/topic/chat." + event.getChatId() + ".typing", event);
    }

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    public static class TypingEvent {
        private String chatId;
        private String username;
        private boolean isTyping;
    }
}
