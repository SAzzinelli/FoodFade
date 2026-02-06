import Foundation
import SwiftData

/// Lista della spesa (puoi averne più di una)
@Model
final class ShoppingList {
    var id: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date()
    
    @Relationship(deleteRule: .cascade, inverse: \ShoppingItem.list)
    var items: [ShoppingItem] = []
    
    init(id: UUID = UUID(), name: String, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }
    
    var pendingItems: [ShoppingItem] {
        items.filter { !$0.isCompleted }
    }
    
    var archivedItems: [ShoppingItem] {
        items.filter { $0.isCompleted }
    }
}
