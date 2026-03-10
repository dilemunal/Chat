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
                if !(self?.messages.contains(where: { $0.id == newMsg.id }) ?? false) {
                    self?.messages.append(newMsg)
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
        guard !inputText.isEmpty else { return }
        // For now, WebSocketManager.sendMessage only supports basic content. 
        // We might need to extend it for replyToId or use REST for complex actions.
        WebSocketManager.shared.sendMessage(chatId: chatId, senderId: senderId, content: inputText)
        inputText = ""
    }
    
    func editMessage(chatId: String, messageId: String, newContent: String) {
        APIClient.shared.editMessage(chatId: chatId, messageId: messageId, newContent: newContent) { [weak self] updatedMsg in
            if let msg = updatedMsg {
                DispatchQueue.main.async {
                    if let index = self?.messages.firstIndex(where: { $0.id == msg.id }) {
                        self?.messages[index] = msg
                    }
                }
            }
        }
    }
    
    func revokeMessage(chatId: String, messageId: String) {
        APIClient.shared.revokeMessage(chatId: chatId, messageId: messageId) { [weak self] updatedMsg in
            if let msg = updatedMsg {
                DispatchQueue.main.async {
                    if let index = self?.messages.firstIndex(where: { $0.id == msg.id }) {
                        self?.messages[index] = msg
                    }
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
        guard let data = image.jpegData(compressionQuality: 0.7) else { return }
        APIClient.shared.uploadMedia(data: data, fileName: "image.jpg", contentType: "image/jpeg") { result in
            if case .success(let url) = result {
                let mediaMsg = ChatMessage(chatId: chatId, senderId: senderId, content: "[Image]", mediaUrl: url, mediaType: "IMAGE")
                APIClient.shared.sendMessage(message: mediaMsg) { _ in }
            }
        }
    }
}
