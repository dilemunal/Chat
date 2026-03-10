import Foundation

struct ChatMessage: Codable, Identifiable, Hashable {
    var id: String { messageId ?? UUID().uuidString }
    var chatId: String
    var messageId: String?
    var senderId: String
    var content: String
    var timestamp: Double?
    
    // Phase 5: Message Lifecycle
    var status: String? // SENT, DELIVERED, READ
    var isEdited: Bool?
    var isDeleted: Bool?
    var replyToId: String?
    
    // Phase 6: Media Support
    var mediaUrl: String?
    var mediaType: String? // IMAGE, VIDEO, FILE, VOICE
}

struct User: Codable, Identifiable, Hashable {
    var id: String
    var username: String
    var email: String?
    var firstName: String?
    var lastName: String?
    var online: Bool?
}

struct ChatRoom: Codable, Identifiable, Hashable {
    let id: String
    let name: String?
    let group: Bool
    let members: Set<String>
    let createdAt: Double?
}
