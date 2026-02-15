import Foundation
import SwiftData

/// Chat con Fridgy: una conversazione con titolo/topic e cronologia messaggi persistita.
@Model
final class FridgyChat: Identifiable {
    @Attribute(.unique) var id: UUID
    /// Titolo/topic della chat (es. "Scadenze latte", "Ricette" o "Nuova chat").
    var title: String
    var createdAt: Date
    @Relationship(deleteRule: .cascade, inverse: \FridgyMessage.chat) var messages: [FridgyMessage]
    
    init(id: UUID = UUID(), title: String, createdAt: Date = Date(), messages: [FridgyMessage] = []) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.messages = messages
    }
}

/// Singolo messaggio in una chat Fridgy.
@Model
final class FridgyMessage: Identifiable {
    @Attribute(.unique) var id: UUID
    var text: String
    var isFromUser: Bool
    var createdAt: Date
    @Relationship var chat: FridgyChat?
    
    init(id: UUID = UUID(), text: String, isFromUser: Bool, createdAt: Date = Date(), chat: FridgyChat? = nil) {
        self.id = id
        self.text = text
        self.isFromUser = isFromUser
        self.createdAt = createdAt
        self.chat = chat
    }
}
