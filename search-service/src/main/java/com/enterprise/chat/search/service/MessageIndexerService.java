package com.enterprise.chat.search.service;

import com.enterprise.chat.search.model.IndexedMessage;
import com.enterprise.chat.search.repository.SearchRepository;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.stereotype.Service;

import java.util.Map;

@Service
@Slf4j
@RequiredArgsConstructor
public class MessageIndexerService {

    private final SearchRepository searchRepository;
    private final ObjectMapper objectMapper;

    @KafkaListener(topics = "chat-messages", groupId = "search-indexer-group")
    public void consumeMessage(String messagePayload) {
        try {
            // In a real scenario, this matches the ChatMessage / Message DTO published by MessageService or WebSocketService.
            Map<String, Object> payload = objectMapper.readValue(messagePayload, Map.class);
            
            IndexedMessage indexedMessage = IndexedMessage.builder()
                    .messageId(payload.getOrDefault("messageId", "").toString())
                    .chatId(payload.getOrDefault("chatId", "").toString())
                    .senderId(payload.getOrDefault("senderId", "").toString())
                    .content(payload.getOrDefault("content", "").toString())
                    // Assuming timestamp is passed as long/epoch millis
                    .timestamp(Long.parseLong(payload.getOrDefault("timestamp", "0").toString()))
                    .build();

            searchRepository.save(indexedMessage);
            log.debug("Indexed message: {}", indexedMessage.getMessageId());
        } catch (Exception e) {
            log.error("Failed to index message", e);
        }
    }
}
