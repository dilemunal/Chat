package com.enterprise.chat.user.model;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;
import java.util.List;
import java.util.Set;

@Entity
@Table(name = "chat_rooms")
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ChatRoom {
    @Id
    private String id; // UUID or custom (e.g., dm_u1_u2)

    private String name;
    
    @Column(name = "is_group")
    private boolean group;

    @Column(name = "created_at")
    private Instant createdAt;

    @ElementCollection
    @CollectionTable(name = "chat_members", joinColumns = @JoinColumn(name = "room_id"))
    @Column(name = "username")
    private Set<String> members;
}
