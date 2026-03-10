package com.enterprise.chat.message.controller;

import com.enterprise.chat.message.model.Message;
import com.enterprise.chat.message.repository.MessageRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.web.bind.annotation.*;

import java.util.Comparator;
import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/messages")
@RequiredArgsConstructor
@Slf4j
public class MessageActionController {

    private final MessageRepository messageRepository;
    private final KafkaTemplate<String, Object> kafkaTemplate;

    @PutMapping("/{chatId}/{messageId}/edit")
    public ResponseEntity<Message> editMessage(
            @PathVariable String chatId,
            @PathVariable UUID messageId,
            @RequestParam String newContent) {
            
        Message.MessageKey key = Message.MessageKey.builder()
                .chatId(chatId)
                .messageId(messageId)
                .build();
                
        return messageRepository.findById(key)
                .map(msg -> {
                    if (msg.isDeleted()) {
                        return ResponseEntity.badRequest().<Message>build();
                    }
                    msg.setContent(newContent);
                    msg.setEdited(true);
                    Message saved = messageRepository.save(msg);
                    kafkaTemplate.send("chat-messages", chatId, saved);
                    return ResponseEntity.ok(saved);
                })
                .orElse(ResponseEntity.notFound().build());
    }

    @DeleteMapping("/{chatId}/{messageId}/revoke")
    public ResponseEntity<Message> revokeMessage(
            @PathVariable String chatId,
            @PathVariable UUID messageId) {
            
        Message.MessageKey key = Message.MessageKey.builder()
                .chatId(chatId)
                .messageId(messageId)
                .build();
                
        return messageRepository.findById(key)
                .map(msg -> {
                    // Hard delete the message from the database
                    messageRepository.delete(msg);
                    
                    // Create a dummy deleted message to notify existing clients to remove it from UI
                    msg.setDeleted(true);
                    msg.setContent("This message was deleted");
                    kafkaTemplate.send("chat-messages", chatId, msg);
                    
                    // Publish the new last message so the Chat List updates the preview
                    List<Message> msgs = messageRepository.findByKeyChatId(chatId);
                    Message lastMsg = msgs.stream().max(Comparator.comparing(Message::getTimestamp)).orElse(null);
                    if (lastMsg != null) {
                        // Sleep briefly so the delete event hits the consumer first, followed by the new last message
                        try { Thread.sleep(50); } catch (Exception ignored) {}
                        kafkaTemplate.send("chat-messages", chatId, lastMsg);
                    }
                    
                    return ResponseEntity.ok(msg);
                })
                .orElse(ResponseEntity.notFound().build());
    }

    @PostMapping("/{chatId}/{messageId}/read")
    public ResponseEntity<Message> markAsRead(
            @PathVariable String chatId,
            @PathVariable UUID messageId) {
            
        Message.MessageKey key = Message.MessageKey.builder()
                .chatId(chatId)
                .messageId(messageId)
                .build();
                
        return messageRepository.findById(key)
                .map(msg -> {
                    msg.setStatus("READ");
                    return ResponseEntity.ok(messageRepository.save(msg));
                })
                .orElse(ResponseEntity.notFound().build());
    }
}
