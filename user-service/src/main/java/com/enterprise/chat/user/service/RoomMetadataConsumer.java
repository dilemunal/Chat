package com.enterprise.chat.user.service;

import com.enterprise.chat.user.repository.ChatRoomRepository;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.stereotype.Service;

import java.io.Serializable;
import java.time.Instant;

@Service
@RequiredArgsConstructor
@Slf4j
public class RoomMetadataConsumer {

    private final ChatRoomRepository chatRoomRepository;

    @KafkaListener(topics = "chat-messages", groupId = "user-service-group")
    public void consume(ChatMessageDTO chatMessageDTO) {
        log.info("Received message for metadata update: {}", chatMessageDTO.getChatId());
        
        chatRoomRepository.findById(chatMessageDTO.getChatId()).ifPresent(room -> {
            room.setLastMessage(chatMessageDTO.getContent());
            room.setLastMessageAt(Instant.ofEpochMilli(chatMessageDTO.getTimestamp()));
            chatRoomRepository.save(room);
            log.info("Updated metadata for room: {}", room.getId());
        });
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
    }
}
