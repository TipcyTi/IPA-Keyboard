import Foundation

struct Provider: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var baseURL: String
    var model: String
    var createdAt = Date()
}

struct ChatMessage: Identifiable, Codable, Equatable {
    enum Role: String, Codable {
        case user
        case assistant
    }

    var id = UUID()
    var role: Role
    var text: String
    var date = Date()
    var isError = false
}

struct Conversation: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var providerID: UUID?
    var model: String
    var messages: [ChatMessage] = []
    var updatedAt = Date()
}

struct PersistedState: Codable {
    var providers: [Provider] = []
    var conversations: [Conversation] = []
    var activeProviderID: UUID?
}

struct StreamingState: Equatable {
    var conversationID: UUID
    var text: String
}

struct APIMessage: Codable {
    var role: String
    var content: String
}
