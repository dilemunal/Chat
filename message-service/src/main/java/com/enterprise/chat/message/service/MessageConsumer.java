package com.enterprise.chat.message.service;

import com.enterprise.chat.message.model.Message;
import com.enterprise.chat.message.repository.MessageRepository;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.stereotype.Service;

import java.io.Serializable;
import java.time.Instant;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class MessageConsumer {

    private final MessageRepository messageRepository;

    @KafkaListener(topics = "chat-messages", groupId = "message-service-group")
    public void consume(ChatMessageDTO chatMessageDTO) {
        log.info("Received message from Kafka: {}", chatMessageDTO);
        log.info("Mapping mediaUrl={}, mediaType={}, localId={}", 
            chatMessageDTO.getMediaUrl(), chatMessageDTO.getMediaType(), chatMessageDTO.getLocalId());
        
        Message message = Message.builder()
                .key(Message.MessageKey.builder()
                        .chatId(chatMessageDTO.getChatId())
                        .messageId(UUID.randomUUID())
                        .build())
                .senderId(chatMessageDTO.getSenderId())
                .content(chatMessageDTO.getContent())
                .timestamp(Instant.ofEpochMilli(chatMessageDTO.getTimestamp()))
                .status("SENT")
                .mediaUrl(chatMessageDTO.getMediaUrl())
                .mediaType(chatMessageDTO.getMediaType())
                .localId(chatMessageDTO.getLocalId())
                .build();
        
        messageRepository.save(message);
        log.info("Message persisted to Cassandra: messageId={}, mediaUrl={}", 
            message.getKey().getMessageId(), message.getMediaUrl());
    }

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    @Builder
    public static class ChatMessageDTO implements Serializable {
        private String chatId;
        private String senderId;
        private String content;
        private long timestamp;
        private String mediaUrl;
        private String mediaType;
        private String localId;
    }
}
