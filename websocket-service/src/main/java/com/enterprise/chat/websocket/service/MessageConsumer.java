package com.enterprise.chat.websocket.service;

import com.enterprise.chat.websocket.model.ChatMessage;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.stereotype.Service;

@Service
@Slf4j
@RequiredArgsConstructor
public class MessageConsumer {

    private final RedisPublisher redisPublisher;

    @KafkaListener(topics = "chat-messages", groupId = "websocket-service-group")
    public void consume(ChatMessage chatMessage) {
        log.info("Received message from Kafka to broadcast: {}", chatMessage.getChatId());
        redisPublisher.publish(chatMessage);
    }
}
