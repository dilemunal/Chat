package com.enterprise.chat.search.model;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.springframework.data.annotation.Id;
import org.springframework.data.elasticsearch.annotations.Document;
import org.springframework.data.elasticsearch.annotations.Field;
import org.springframework.data.elasticsearch.annotations.FieldType;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
@Document(indexName = "messages")
public class IndexedMessage {

    @Id
    private String messageId;

    @Field(type = FieldType.Keyword)
    private String chatId;

    @Field(type = FieldType.Keyword)
    private String senderId;

    @Field(type = FieldType.Text, analyzer = "standard")
    private String content;

    @Field(type = FieldType.Date)
    private long timestamp;

    @Field(type = FieldType.Keyword)
    private String mediaUrl;

    @Field(type = FieldType.Keyword)
    private String mediaType;

    @Field(type = FieldType.Keyword)
    private String localId;
}
