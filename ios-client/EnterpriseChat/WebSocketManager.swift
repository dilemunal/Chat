import Foundation
import Combine

class WebSocketManager: ObservableObject {
    static let shared = WebSocketManager()
    private var webSocketTask: URLSessionWebSocketTask?
    
    @Published var isConnected = false
    @Published var receivedMessage: ChatMessage?
    @Published var onlineUsers: Set<String> = []
    @Published var typingUsers: [String: Set<String>] = [:] // chatId: Set of usernames

    func connect(username: String) {
        // Direct routing to websocket-service native WS endpoint to bypass SockJS formatting in Swift
        guard let url = URL(string: "ws://localhost:8083/ws-native?username=\(username)") else { return }
        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        
        // Native STOMP CONNECT Frame with JWT
        let token = APIClient.shared.accessToken ?? ""
        let connectFrame = "CONNECT\naccept-version:1.1,1.0\nheart-beat:10000,10000\npasscode:\(token)\n\n\0"
        sendRaw(connectFrame)
        receive()
    }
    
    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        isConnected = false
    }
    
    func subscribePresence() {
        let subFrame = "SUBSCRIBE\nid:sub-presence\ndestination:/topic/presence\n\n\0"
        sendRaw(subFrame)
    }
    
    func subscribeTyping(chatId: String) {
        let subFrame = "SUBSCRIBE\nid:sub-typing-\(chatId)\ndestination:/topic/chat.\(chatId).typing\n\n\0"
        sendRaw(subFrame)
    }
    
    func unsubscribeTyping(chatId: String) {
        let unsubFrame = "UNSUBSCRIBE\nid:sub-typing-\(chatId)\n\n\0"
        sendRaw(unsubFrame)
    }
    
    func sendTyping(chatId: String, username: String, isTyping: Bool) {
        let payload = ["chatId": chatId, "username": username, "isTyping": isTyping] as [String : Any]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload),
              let jsonString = String(data: jsonData, encoding: .utf8) else { return }
        
        let sendFrame = "SEND\ndestination:/app/typing\ncontent-type:application/json\n\n\(jsonString)\0"
        sendRaw(sendFrame)
    }
    
    func sendMessage(chatId: String, senderId: String, content: String) {
        let msg = ChatMessage(chatId: chatId, senderId: senderId, content: content)
        guard let jsonData = try? JSONEncoder().encode(msg),
              let jsonString = String(data: jsonData, encoding: .utf8) else { return }
        
        let sendFrame = "SEND\ndestination:/app/chat.send\ncontent-type:application/json\n\n\(jsonString)\0"
        sendRaw(sendFrame)
    }
    
    func sendRaw(_ text: String) {
        webSocketTask?.send(.string(text)) { error in
            if let e = error { print("WS Send Error: \(e)") }
        }
    }
    
    private func receive() {
        webSocketTask?.receive { [weak self] result in
            defer { self?.receive() }
            switch result {
            case .success(let msg):
                if case .string(let text) = msg { self?.handleStomp(text) }
            case .failure(let error):
                print("WS Recv Error: \(error)")
                DispatchQueue.main.async { self?.isConnected = false }
            }
        }
    }
    
    private func handleStomp(_ frame: String) {
        if frame.hasPrefix("CONNECTED") {
            DispatchQueue.main.async { self.isConnected = true }
        } else if frame.hasPrefix("MESSAGE") {
            let lines = frame.components(separatedBy: "\n")
            let destination = lines.first(where: { $0.hasPrefix("destination:") })?.replacingOccurrences(of: "destination:", with: "")
            
            let parts = frame.components(separatedBy: "\n\n")
            if parts.count >= 2 {
                let bodyWithNull = parts.dropFirst().joined(separator: "\n\n")
                let body = bodyWithNull.replacingOccurrences(of: "\0", with: "")
                guard let data = body.data(using: .utf8) else { return }
                
                DispatchQueue.main.async {
                    if let dest = destination {
                        if dest.contains("/topic/presence") {
                            if let event = try? JSONDecoder().decode(PresenceEvent.self, from: data) {
                                if event.status == "ONLINE" { self.onlineUsers.insert(event.username) }
                                else { self.onlineUsers.remove(event.username) }
                            }
                        } else if dest.contains(".typing") {
                            if let event = try? JSONDecoder().decode(TypingEvent.self, from: data) {
                                var current = self.typingUsers[event.chatId] ?? []
                                if event.isTyping { current.insert(event.username) }
                                else { current.remove(event.username) }
                                self.typingUsers[event.chatId] = current
                            }
                        } else {
                            if let chatMsg = try? JSONDecoder().decode(ChatMessage.self, from: data) {
                                self.receivedMessage = chatMsg
                                NotificationCenter.default.post(name: NSNotification.Name("NewMessageReceived"), object: chatMsg)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct PresenceEvent: Codable {
    let username: String
    let status: String
}

struct TypingEvent: Codable {
    let chatId: String
    let username: String
    let isTyping: Bool
}
