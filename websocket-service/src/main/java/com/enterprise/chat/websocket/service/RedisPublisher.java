package com.enterprise.chat.websocket.service;

import com.enterprise.chat.websocket.config.RedisConfig;
import com.enterprise.chat.websocket.model.ChatMessage;
import lombok.RequiredArgsConstructor;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
public class RedisPublisher {

    private final RedisTemplate<String, Object> redisTemplate;

    public void publish(ChatMessage message) {
        redisTemplate.convertAndSend(RedisConfig.CHAT_TOPIC, message);
    }
}
