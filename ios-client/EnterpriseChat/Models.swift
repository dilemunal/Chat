import Foundation

struct ChatMessage: Codable, Identifiable, Hashable {
    var id = UUID().uuidString
    var chatId: String
    var messageId: String? = nil
    var senderId: String
    var content: String
    var timestamp: Double? = nil
    
    // Phase 5: Message Lifecycle
    var status: String? = nil // SENT, DELIVERED, READ
    var isEdited: Bool? = nil
    var isDeleted: Bool? = nil
    var replyToId: String? = nil
    
    // Phase 6: Media Support
    var mediaUrl: String? = nil
    var mediaType: String? = nil // IMAGE, VIDEO, FILE, VOICE
    
    var localId: String? = nil
    
    enum CodingKeys: String, CodingKey {
        case chatId, messageId, senderId, content, timestamp
        case status, replyToId
        case isEdited = "edited"
        case isDeleted = "deleted"
        case mediaUrl, mediaType, localId
    }
}

struct User: Codable, Identifiable, Hashable {
    var id: String
    var username: String
    var email: String? = nil
    var firstName: String? = nil
    var lastName: String? = nil
    var online: Bool? = nil
    
    enum CodingKeys: String, CodingKey {
        case id, username, email, firstName, lastName, online
    }
}

struct ChatRoom: Codable, Identifiable, Hashable {
    let id: String
    let name: String?
    let group: Bool
    let members: Set<String>
    let lastMessage: String?
    let lastMessageAt: String?
    let createdAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name, group, members, lastMessage, lastMessageAt, createdAt
    }
}

extension ChatRoom {
    func displayName(currentUser: User) -> String {
        if group {
            return name ?? "Group Chat"
        } else {
            let currentLow = currentUser.username.lowercased()
            let otherMember = members.first(where: { $0.lowercased() != currentLow })
            return otherMember ?? name ?? "Chat"
        }
    }
}

