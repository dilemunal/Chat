package com.enterprise.chat.websocket.service;

import lombok.RequiredArgsConstructor;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.stereotype.Service;

import java.util.concurrent.TimeUnit;

@Service
@RequiredArgsConstructor
public class PresenceService {

    private final RedisTemplate<String, Object> redisTemplate;
    private static final String PRESENCE_KEY_PREFIX = "presence:";

    public void setOnline(String username) {
        // Set online with a TTL of 1 minute (heartbeat expected)
        redisTemplate.opsForValue().set(PRESENCE_KEY_PREFIX + username, "online", 60, TimeUnit.SECONDS);
    }

    public void setOffline(String username) {
        redisTemplate.delete(PRESENCE_KEY_PREFIX + username);
    }

    public boolean isOnline(String username) {
        return redisTemplate.hasKey(PRESENCE_KEY_PREFIX + username);
    }
}
