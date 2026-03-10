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
    public ResponseEntity<List<IndexedMessage>> searchGlobal(@RequestParam String keyword) {
        List<IndexedMessage> results = searchRepository.findByContentContaining(keyword);
        return ResponseEntity.ok(results);
    }
}
