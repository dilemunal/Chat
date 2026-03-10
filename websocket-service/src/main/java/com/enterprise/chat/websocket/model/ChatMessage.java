package com.enterprise.chat.websocket.model;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import java.io.Serializable;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ChatMessage implements Serializable {
    private String chatId;
    private String senderId;
    private String content;
    private long timestamp;
    private String mediaUrl;
    private String mediaType;
    private String localId;
}
