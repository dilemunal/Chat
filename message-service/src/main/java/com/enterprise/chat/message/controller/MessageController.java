package com.enterprise.chat.message.controller;

import com.enterprise.chat.message.dto.MessageDTO;
import com.enterprise.chat.message.model.Message;
import com.enterprise.chat.message.repository.MessageRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/v1/messages")
@RequiredArgsConstructor
public class MessageController {

    private final MessageRepository messageRepository;
    private final KafkaTemplate<String, Object> kafkaTemplate;

    @PostMapping
    public ResponseEntity<MessageDTO> sendMessage(@RequestBody Message message) {
        if (message.getKey() == null) {
            return ResponseEntity.badRequest().build();
        }
        message.getKey().setMessageId(UUID.randomUUID());
        message.setTimestamp(Instant.now());
        message.setStatus("SENT");
        
        Message savedMessage = messageRepository.save(message);
        
        // Publish to Kafka for search indexing and other async processing
        kafkaTemplate.send("chat-messages", savedMessage.getKey().getChatId(), savedMessage);
        
        return ResponseEntity.ok(convertToDTO(savedMessage));
    }

    @GetMapping("/{chatId}")
    public ResponseEntity<List<MessageDTO>> getChatMessages(@PathVariable String chatId) {
        List<Message> messages = messageRepository.findByKeyChatId(chatId);
        List<MessageDTO> dtos = messages.stream()
                .map(this::convertToDTO)
                .collect(Collectors.toList());
        return ResponseEntity.ok(dtos);
    }

    @DeleteMapping("/{chatId}")
    public ResponseEntity<Void> deleteChatMessages(@PathVariable String chatId) {
        messageRepository.deleteByKeyChatId(chatId);
        return ResponseEntity.noContent().build();
    }

    private MessageDTO convertToDTO(Message message) {
        return MessageDTO.builder()
                .chatId(message.getKey().getChatId())
                .messageId(message.getKey().getMessageId())
                .senderId(message.getSenderId())
                .content(message.getContent())
                .timestamp(message.getTimestamp().toEpochMilli())
                .status(message.getStatus())
                .isEdited(message.isEdited())
                .isDeleted(message.isDeleted())
                .mediaUrl(message.getMediaUrl())
                .mediaType(message.getMediaType())
                .localId(message.getLocalId())
                .build();
    }
}
