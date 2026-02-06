import Foundation
import SwiftData

/// Voce della lista della spesa (cosa comprare)
@Model
final class ShoppingItem: Identifiable {
    var id: UUID = UUID()
    var name: String = ""
    var quantity: Int = 1
    var notes: String?
    var addedAt: Date = Date()
    var isCompleted: Bool = false
    var completedAt: Date?
    
    var list: ShoppingList?
    
    init(
        id: UUID = UUID(),
        name: String,
        quantity: Int = 1,
        notes: String? = nil,
        addedAt: Date = Date(),
        isCompleted: Bool = false,
        completedAt: Date? = nil,
        list: ShoppingList? = nil
    ) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.notes = notes
        self.addedAt = addedAt
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.list = list
    }
}
