import Foundation
import SwiftData

@Model
final class UserProfile {
    var id: UUID = UUID()
    var firstName: String?
    var lastName: String?
    var hasCompletedOnboarding: Bool = false
    var termOfAddressRaw: String? // Memorizza NSTermOfAddress.rawValue per SwiftData
    
    init(
        id: UUID = UUID(),
        firstName: String? = nil,
        lastName: String? = nil,
        hasCompletedOnboarding: Bool = false,
        gender: GenderHelper.Gender? = nil
    ) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.termOfAddressRaw = gender?.rawValue
    }
    
    /// Genere dell'utente (compatibile con NSTermOfAddress quando disponibile)
    var gender: GenderHelper.Gender {
        get {
            if let raw = termOfAddressRaw,
               let gender = GenderHelper.Gender(rawValue: raw) {
                return gender
            }
            return .neutral
        }
        set {
            termOfAddressRaw = newValue.rawValue
        }
    }
    
    var displayName: String {
        if let firstName = firstName, !firstName.isEmpty {
            return firstName
        }
        return "Utente"
    }
    
    var fullName: String {
        var components: [String] = []
        if let firstName = firstName, !firstName.isEmpty {
            components.append(firstName)
        }
        if let lastName = lastName, !lastName.isEmpty {
            components.append(lastName)
        }
        return components.isEmpty ? "Utente" : components.joined(separator: " ")
    }
}

