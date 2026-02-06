import Foundation
import SwiftData

/// Lista della spesa (puoi averne più di una)
@Model
final class ShoppingList {
    var id: UUID = UUID()
    var name: String = ""
    /// Nome icona SF Symbol (es. "list.bullet", "cart.fill")
    var iconName: String = "list.bullet"
    var createdAt: Date = Date()
    
    @Relationship(deleteRule: .cascade, inverse: \ShoppingItem.list)
    var items: [ShoppingItem] = []
    
    init(id: UUID = UUID(), name: String, iconName: String = "list.bullet", createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.createdAt = createdAt
    }
    
    /// Icone di sistema disponibili per le liste
    static let availableIcons = [
        "list.bullet", "cart.fill", "cart", "basket.fill", "bag.fill", "bag",
        "list.bullet.rectangle", "square.and.pencil", "checklist", "tray.full.fill",
        "leaf.fill", "heart.fill", "star.fill", "house.fill", "tag.fill"
    ]
    
    var pendingItems: [ShoppingItem] {
        items.filter { !$0.isCompleted }
    }
    
    var archivedItems: [ShoppingItem] {
        items.filter { $0.isCompleted }
    }
}
