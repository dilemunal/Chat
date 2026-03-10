package com.enterprise.chat.message.repository;

import com.enterprise.chat.message.model.Message;
import org.springframework.data.cassandra.repository.CassandraRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface MessageRepository extends CassandraRepository<Message, Message.MessageKey> {
    List<Message> findByKeyChatId(String chatId);
    void deleteByKeyChatId(String chatId);
}
