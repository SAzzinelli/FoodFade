import Foundation
import SwiftData
import SwiftUI
import Combine

/// ViewModel per ItemDetailView - minimo e pulito
@MainActor
final class ItemDetailViewModel: ObservableObject {
    @Published var fridgyMessage: String?
    @Published var fridgyContext: FridgyContext?
    @Published var isLoadingFridgy: Bool = false
    
    private let service: FridgyService
    
    init(service: FridgyService? = nil) {
        // Usa il servizio fornito o crea una nuova istanza
        if let service = service {
            self.service = service
        } else {
            // Accediamo a shared in modo sicuro perché siamo già @MainActor
            self.service = FridgyServiceImpl.shared
        }
    }
    
    /// Carica il messaggio Fridgy per un alimento
    func loadFridgy(for item: FoodItem) async {
        // La VIEW decide se mostrare Fridgy (controlla se è abilitato)
        guard IntelligenceManager.shared.isFridgyAvailable else {
            fridgyMessage = nil
            fridgyContext = nil
            isLoadingFridgy = false
            return
        }
        
        // La BUSINESS LOGIC decide il payload
        guard let payload = FridgyPayload.forFoodItem(item) else {
            fridgyMessage = nil
            fridgyContext = nil
            isLoadingFridgy = false
            return
        }
        
        // Mostra skeleton loader
        isLoadingFridgy = true
        
        // Il SERVIZIO genera il testo (solo con Apple Intelligence)
        do {
            let text = try await service.generateMessage(from: payload.promptContext)
            
            // Validazione Fridgy: sanitize + validate (lunghezza, parole proibite, abbinamenti assurdi)
            let sanitized = FridgyRules.sanitize(text)
            let validation = FridgyRules.validate(sanitized)
            switch validation {
            case .accepted:
                if !sanitized.isEmpty && sanitized.count <= 100 {
                    fridgyContext = payload.context
                    fridgyMessage = sanitized
                } else {
                    fridgyMessage = nil
                    fridgyContext = nil
                }
            case .rejected, .noSuggestion:
                fridgyMessage = nil
                fridgyContext = nil
            }
        } catch {
            // Se Apple Intelligence non è disponibile o c'è un errore, Fridgy non mostra nulla
            fridgyMessage = nil
            fridgyContext = nil
        }
        
        // Nascondi skeleton loader
        isLoadingFridgy = false
    }
}
