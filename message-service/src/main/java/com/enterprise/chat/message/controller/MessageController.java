package com.enterprise.chat.message.controller;

import com.enterprise.chat.message.model.Message;
import com.enterprise.chat.message.repository.MessageRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/messages")
@RequiredArgsConstructor
public class MessageController {

    private final MessageRepository messageRepository;
    private final KafkaTemplate<String, Object> kafkaTemplate;

    @PostMapping
    public ResponseEntity<Message> sendMessage(@RequestBody Message message) {
        if (message.getKey() == null) {
            return ResponseEntity.badRequest().build();
        }
        message.getKey().setMessageId(UUID.randomUUID());
        message.setTimestamp(Instant.now());
        message.setStatus("SENT");
        
        Message savedMessage = messageRepository.save(message);
        
        // Publish to Kafka for search indexing and other async processing
        kafkaTemplate.send("chat-messages", savedMessage.getKey().getChatId(), savedMessage);
        
        return ResponseEntity.ok(savedMessage);
    }

    @GetMapping("/{chatId}")
    public ResponseEntity<List<Message>> getChatMessages(@PathVariable String chatId) {
        return ResponseEntity.ok(messageRepository.findByKeyChatId(chatId));
    }
}
