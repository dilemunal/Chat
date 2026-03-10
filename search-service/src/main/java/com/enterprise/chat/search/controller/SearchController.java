package com.enterprise.chat.search.controller;

import com.enterprise.chat.search.model.IndexedMessage;
import com.enterprise.chat.search.repository.SearchRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/search")
@RequiredArgsConstructor
public class SearchController {

    private final SearchRepository searchRepository;

    @GetMapping("/messages")
    public ResponseEntity<List<IndexedMessage>> searchMessages(
            @RequestParam String chatId,
            @RequestParam String keyword) {
        List<IndexedMessage> results = searchRepository.findByChatIdAndContentContaining(chatId, keyword);
        return ResponseEntity.ok(results);
    }

    @GetMapping("/global")
    public ResponseEntity<List<IndexedMessage>> searchGlobal(
            @RequestParam String keyword,
            @RequestParam(required = false) List<String> chatIds) {
        
        List<IndexedMessage> results;
        if (chatIds != null && !chatIds.isEmpty()) {
            results = searchRepository.findByContentContainingAndChatIdIn(keyword, chatIds);
        } else {
            // Fallback to global search if no chatIds provided (for backward compatibility if needed, 
            // but the client should be updated to always provide them for scoping)
            results = searchRepository.findByContentContaining(keyword);
        }
        return ResponseEntity.ok(results);
    }
}
