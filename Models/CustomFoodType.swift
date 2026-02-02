import Foundation
import SwiftData

/// Modello per memorizzare i tipi di alimento personalizzati
@Model
final class CustomFoodType {
    var id: UUID = UUID()
    var name: String = ""
    var icon: String = "tag.fill"
    var createdAt: Date = Date()
    
    init(name: String, icon: String = "tag.fill", id: UUID = UUID(), createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.icon = icon
        self.createdAt = createdAt
    }
    
    func toFoodType() -> FoodType {
        FoodType(rawValue: name, icon: icon)
    }
}

