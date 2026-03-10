package com.enterprise.chat.user.controller;

import com.enterprise.chat.user.model.ChatRoom;
import com.enterprise.chat.user.repository.ChatRoomRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/rooms")
@RequiredArgsConstructor
public class ChatRoomController {

    private final ChatRoomRepository chatRoomRepository;

    @PostMapping
    public ResponseEntity<ChatRoom> createRoom(@RequestBody ChatRoom room) {
        if (room.isGroup()) {
            if (room.getId() == null) {
                room.setId("group_" + UUID.randomUUID().toString());
            }
        } else {
            // For DMs, create a consistent ID based on participants
            if (room.getMembers() != null && room.getMembers().size() == 2) {
                List<String> sortedMembers = room.getMembers().stream().sorted().toList();
                room.setId("dm_" + String.join("_", sortedMembers));
            } else if (room.getId() == null) {
                room.setId("dm_" + UUID.randomUUID().toString());
            }
        }
        
        if (room.getCreatedAt() == null) {
            room.setCreatedAt(Instant.now());
        }
        
        return ResponseEntity.ok(chatRoomRepository.save(room));
    }

    @GetMapping("/user/{username}")
    public ResponseEntity<List<ChatRoom>> getUserRooms(@PathVariable String username) {
        return ResponseEntity.ok(chatRoomRepository.findByMembersContaining(username));
    }
}
