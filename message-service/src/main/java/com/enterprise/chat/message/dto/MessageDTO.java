package com.enterprise.chat.message.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.UUID;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class MessageDTO {
    private String chatId;
    private UUID messageId;
    private String senderId;
    private String content;
    private long timestamp;
    private String status;
    private boolean isEdited;
    private boolean isDeleted;
    private String mediaUrl;
    private String mediaType;
}
