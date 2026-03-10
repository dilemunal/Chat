import Foundation
import UIKit
import Combine

class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    private var cancellables = Set<AnyCancellable>()
    
    func connect(chatId: String, username: String) {
        // Fetch history
        APIClient.shared.fetchMessages(chatId: chatId) { msgs in
            DispatchQueue.main.async { self.messages = msgs }
        }
        
        // Connect WS if not connected
        if !WebSocketManager.shared.isConnected {
            WebSocketManager.shared.connect(username: username)
        }
        
        // Subscribe to topics
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let subFrame = "SUBSCRIBE\nid:sub-\(chatId)\ndestination:/topic/chat.\(chatId)\n\n\0"
            WebSocketManager.shared.sendRaw(subFrame) // Need to expose sendRaw or add subscribeChat
            WebSocketManager.shared.subscribeTyping(chatId: chatId)
        }
        
        // Listen for new messages
        WebSocketManager.shared.$receivedMessage
            .compactMap { $0 }
            .filter { $0.chatId == chatId }
            .receive(on: RunLoop.main)
            .sink { [weak self] newMsg in
                guard let self = self else { return }
                // Try to find if this message is a server-confirmation of a local one
                if let index = self.messages.firstIndex(where: {
                    ($0.messageId != nil && $0.messageId == newMsg.messageId) ||
                    ($0.localId != nil && $0.localId == newMsg.localId)
                }) {
                    if newMsg.isDeleted == true {
                        self.messages.remove(at: index)
                    } else {
                        self.messages[index] = newMsg
                    }
                } else {
                    if newMsg.isDeleted != true {
                        self.messages.append(newMsg)
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    func disconnect(chatId: String) {
        let unsubFrame = "UNSUBSCRIBE\nid:sub-\(chatId)\n\n\0"
        WebSocketManager.shared.sendRaw(unsubFrame)
        WebSocketManager.shared.unsubscribeTyping(chatId: chatId)
        cancellables.removeAll()
    }
    
    func sendMessage(chatId: String, senderId: String, replyToId: String? = nil) {
        let content = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        
        // Optimistic UI Update
        var localMsg = ChatMessage(chatId: chatId, senderId: senderId, content: content, replyToId: replyToId)
        localMsg.localId = localMsg.id
        localMsg.timestamp = Date().timeIntervalSince1970 * 1000
        self.messages.append(localMsg)
        
        // Clear input
        self.inputText = ""
        
        // Real Send
        var msg = ChatMessage(chatId: chatId, senderId: senderId, content: content, replyToId: replyToId)
        msg.localId = localMsg.id
        msg.timestamp = localMsg.timestamp
        WebSocketManager.shared.sendMessage(message: msg)
    }
    
    func editMessage(chatId: String, messageId: String, newContent: String) {
        // Optimistic UI for edit
        DispatchQueue.main.async {
            if let index = self.messages.firstIndex(where: { $0.messageId == messageId || $0.id == messageId }) {
                self.messages[index].content = newContent
                self.messages[index].isEdited = true
            }
        }
        
        APIClient.shared.editMessage(chatId: chatId, messageId: messageId, newContent: newContent) { [weak self] updatedMsg in
            if let msg = updatedMsg {
                DispatchQueue.main.async {
                    if let index = self?.messages.firstIndex(where: { $0.messageId == msg.messageId || $0.id == msg.id }) {
                        self?.messages[index] = msg
                    }
                }
            }
        }
    }
    
    func revokeMessage(chatId: String, messageId: String) {
        // Optimistic Hard Delete
        DispatchQueue.main.async {
            self.messages.removeAll(where: { $0.messageId == messageId || $0.id == messageId })
        }
        
        APIClient.shared.revokeMessage(chatId: chatId, messageId: messageId) { [weak self] updatedMsg in
            if let msg = updatedMsg {
                DispatchQueue.main.async {
                    self?.messages.removeAll(where: { $0.messageId == msg.messageId || $0.id == msg.id })
                }
            }
        }
    }
    
    func markAsRead(chatId: String, messageId: String) {
        APIClient.shared.markAsRead(chatId: chatId, messageId: messageId) { [weak self] updatedMsg in
            if let msg = updatedMsg {
                DispatchQueue.main.async {
                    if let index = self?.messages.firstIndex(where: { $0.id == msg.id }) {
                        self?.messages[index] = msg
                    }
                }
            }
        }
    }
    
    func uploadAndSendMedia(chatId: String, senderId: String, image: UIImage) {
        let tempId = UUID().uuidString
        // Optimistic UI: Adding a local message with a placeholder or just marking it as uploading
        var localMsg = ChatMessage(chatId: chatId, senderId: senderId, content: "[Uploading Image...]", mediaType: "IMAGE")
        localMsg.id = tempId
        localMsg.localId = tempId
        localMsg.timestamp = Date().timeIntervalSince1970 * 1000
        
        DispatchQueue.main.async {
            self.messages.append(localMsg)
        }
        
        guard let data = image.jpegData(compressionQuality: 0.7) else { return }
        APIClient.shared.uploadMedia(data: data, fileName: "\(tempId).jpg", contentType: "image/jpeg") { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let url):
                    // Optimistic update in place
                    if let index = self?.messages.firstIndex(where: { $0.id == tempId }) {
                        self?.messages[index].content = "[Image]"
                        self?.messages[index].mediaUrl = url
                    }
                    
                    var finalMsg = ChatMessage(chatId: chatId, senderId: senderId, content: "[Image]", mediaUrl: url, mediaType: "IMAGE")
                    finalMsg.localId = tempId
                    finalMsg.timestamp = Date().timeIntervalSince1970 * 1000
                    WebSocketManager.shared.sendMessage(message: finalMsg)
                case .failure(let error):
                    print("❌ Media upload failed: \(error.localizedDescription)")
                    self?.messages.removeAll(where: { $0.id == tempId })
                }
            }
        }
    }
    
    func uploadAndSendAudio(chatId: String, senderId: String, audioUrl: URL, replyToId: String? = nil) {
        let tempId = UUID().uuidString
        var localMsg = ChatMessage(chatId: chatId, senderId: senderId, content: "[Uploading Audio...]", replyToId: replyToId, mediaType: "AUDIO")
        localMsg.id = tempId
        localMsg.localId = tempId
        localMsg.timestamp = Date().timeIntervalSince1970 * 1000
        
        DispatchQueue.main.async {
            self.messages.append(localMsg)
        }
        
        guard let data = try? Data(contentsOf: audioUrl) else {
            DispatchQueue.main.async { self.messages.removeAll(where: { $0.id == tempId }) }
            return
        }
        
        APIClient.shared.uploadMedia(data: data, fileName: "\(tempId).m4a", contentType: "audio/m4a") { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let url):
                    // Optimistic update in place to avoid flickering and "stuck" states
                    if let index = self?.messages.firstIndex(where: { $0.id == tempId }) {
                        self?.messages[index].content = "Voice Note"
                        self?.messages[index].mediaUrl = url
                    }
                    
                    var finalMsg = ChatMessage(chatId: chatId, senderId: senderId, content: "Voice Note", replyToId: replyToId, mediaUrl: url, mediaType: "AUDIO")
                    finalMsg.localId = tempId
                    finalMsg.timestamp = Date().timeIntervalSince1970 * 1000
                    WebSocketManager.shared.sendMessage(message: finalMsg)
                case .failure(let error):
                    print("❌ Audio upload failed: \(error.localizedDescription)")
                    self?.messages.removeAll(where: { $0.id == tempId })
                }
            }
        }
    }
}
