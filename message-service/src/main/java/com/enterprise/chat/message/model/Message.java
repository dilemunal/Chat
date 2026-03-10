package com.enterprise.chat.message.model;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.springframework.data.cassandra.core.cql.PrimaryKeyType;
import org.springframework.data.cassandra.core.mapping.Column;
import org.springframework.data.cassandra.core.mapping.PrimaryKeyColumn;
import org.springframework.data.cassandra.core.mapping.Table;

import java.io.Serializable;
import java.time.Instant;
import java.util.UUID;

@Table("messages")
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Message {

    @org.springframework.data.cassandra.core.mapping.PrimaryKey
    private MessageKey key;

    @Column("sender_id")
    private String senderId;

    @Column("content")
    private String content;

    @Column("timestamp")
    private Instant timestamp;

    @Column("status")
    private String status; // SENT, DELIVERED, READ

    @Column("is_edited")
    private boolean isEdited;

    @Column("is_deleted")
    private boolean isDeleted;

    @Column("reply_to_id")
    private UUID replyToId;

    @Column("media_url")
    private String mediaUrl;

    @Column("media_type")
    private String mediaType; // IMAGE, VIDEO, FILE, VOICE

    @Column("local_id")
    private String localId;

    @org.springframework.data.cassandra.core.mapping.PrimaryKeyClass
    @Data
    @AllArgsConstructor
    @NoArgsConstructor
    @Builder
    public static class MessageKey implements Serializable {
        @PrimaryKeyColumn(name = "chat_id", ordinal = 0, type = PrimaryKeyType.PARTITIONED)
        private String chatId;

        @PrimaryKeyColumn(name = "message_id", ordinal = 1, type = PrimaryKeyType.CLUSTERED)
        private UUID messageId;
    }
}
