package com.enterprise.chat.search.repository;

import com.enterprise.chat.search.model.IndexedMessage;
import org.springframework.data.elasticsearch.repository.ElasticsearchRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface SearchRepository extends ElasticsearchRepository<IndexedMessage, String> {
    List<IndexedMessage> findByChatIdAndContentContaining(String chatId, String content);
    List<IndexedMessage> findByContentContaining(String content);
    List<IndexedMessage> findByContentContainingAndChatIdIn(String content, List<String> chatIds);
}
