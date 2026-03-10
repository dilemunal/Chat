package com.enterprise.chat.message.controller;

import com.enterprise.chat.message.model.Message;
import com.enterprise.chat.message.repository.MessageRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/api/v1/messages")
@RequiredArgsConstructor
@Slf4j
public class MessageActionController {

    private final MessageRepository messageRepository;

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
                    return ResponseEntity.ok(messageRepository.save(msg));
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
                    msg.setContent("This message was deleted");
                    msg.setDeleted(true);
                    return ResponseEntity.ok(messageRepository.save(msg));
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
