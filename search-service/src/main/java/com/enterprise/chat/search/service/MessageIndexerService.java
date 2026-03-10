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
        log.debug("Received raw message payload: {}", messagePayload);
        try {
            Map<String, Object> payload = objectMapper.readValue(messagePayload, Map.class);
            
            String msgId = payload.getOrDefault("messageId", "").toString();
            if (msgId.isEmpty()) {
                msgId = java.util.UUID.randomUUID().toString();
            }

            Object tsObj = payload.get("timestamp");
            long timestamp = 0;
            if (tsObj instanceof Number) {
                timestamp = ((Number) tsObj).longValue();
            } else if (tsObj != null) {
                timestamp = Long.parseLong(tsObj.toString());
            }

            IndexedMessage indexedMessage = IndexedMessage.builder()
                    .messageId(msgId)
                    .chatId(payload.getOrDefault("chatId", "").toString())
                    .senderId(payload.getOrDefault("senderId", "").toString())
                    .content(payload.getOrDefault("content", "").toString())
                    .timestamp(timestamp)
                    .mediaUrl(payload.getOrDefault("mediaUrl", "").toString())
                    .mediaType(payload.getOrDefault("mediaType", "").toString())
                    .localId(payload.getOrDefault("localId", "").toString())
                    .build();

            searchRepository.save(indexedMessage);
            log.info("Successfully indexed message {} from chat {}", indexedMessage.getMessageId(), indexedMessage.getChatId());
        } catch (Exception e) {
            log.error("Failed to index message. Payload: {}", messagePayload, e);
        }
    }
}
