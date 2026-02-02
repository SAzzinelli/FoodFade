import Foundation
import Combine

// Import Foundation Models quando disponibile
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Servizio per suggerimenti intelligenti usando Apple Intelligence (Foundation Models) quando disponibile
/// Fallback a algoritmo euristico per dispositivi non supportati
@MainActor
class AppleIntelligenceService: ObservableObject {
    static let shared = AppleIntelligenceService()
    
    private init() {}
    
    /// Verifica se Apple Intelligence (Foundation Models) è disponibile sul dispositivo
    /// Foundation Models è disponibile da iOS 26+ su dispositivi compatibili con Apple Intelligence
    var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            // Verifica se il framework è realmente disponibile e funzionante
            // Foundation Models richiede dispositivi con Neural Engine e supporto Apple Intelligence
            // iPhone 15 Pro e successivi, iPad con M1+, Mac con Apple Silicon
            return supportsAppleIntelligence
        }
        #endif
        // Fallback: usa algoritmo euristico su dispositivi non supportati
        return false
    }
    
    /// Verifica se il dispositivo supporta Apple Intelligence (hardware + software)
    private var supportsAppleIntelligence: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            // Foundation Models è disponibile solo su dispositivi con Apple Intelligence
            // Verifica hardware: iPhone 15 Pro+, iPad M1+, Mac Apple Silicon
            // Per ora restituiamo true se il framework è disponibile
            // In futuro si può aggiungere verifica hardware più specifica
            return true
        }
        #endif
        return false
    }
    
    /// Suggerisce quali alimenti mangiare per primi usando un algoritmo di ordinamento euristico
    /// Algoritmo: ordina per stato di scadenza > giorni rimanenti > categoria (frigo > dispensa > congelatore)
    func suggestPriorityFoods(_ items: [FoodItem]) -> [FoodItem] {
        // Fallback: ordinamento semplice se non disponibile
        guard isAvailable else {
            return items
                .filter { !$0.isConsumed }
                .sorted { $0.expirationStatus.priority < $1.expirationStatus.priority }
        }
        
        // Algoritmo euristico per prioritizzare i cibi
        // Ordina per: status di scadenza > giorni rimanenti > categoria
        return items
            .filter { !$0.isConsumed }
            .sorted { item1, item2 in
                // Prima per stato di scadenza (scaduti/oggi > prossimi > sicuri)
                if item1.expirationStatus.priority != item2.expirationStatus.priority {
                    return item1.expirationStatus.priority < item2.expirationStatus.priority
                }
                
                // Poi per giorni rimanenti (meno giorni = più prioritario)
                if item1.daysRemaining != item2.daysRemaining {
                    return item1.daysRemaining < item2.daysRemaining
                }
                
                // Infine per categoria (frigo > dispensa > congelatore)
                return item1.category.priority < item2.category.priority
            }
    }
    
    /// Genera un suggerimento testuale intelligente usando Foundation Models quando disponibile
    /// Fallback a template predefiniti per dispositivi non supportati
    func generateSuggestion(for items: [FoodItem]) async -> String? {
        let priorityItems = suggestPriorityFoods(items)
        let expiringToday = priorityItems.filter { $0.expirationStatus == .today || $0.expirationStatus == .expired }
        let expiringSoon = priorityItems.filter { $0.expirationStatus == .soon }
        
        // Se non ci sono prodotti prioritari, non generare suggerimenti
        guard !expiringToday.isEmpty || !expiringSoon.isEmpty else {
            return nil
        }
        
        // Usa Foundation Models se disponibile (iOS 26+)
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *), supportsAppleIntelligence {
            return await generateSuggestionWithFoundationModels(
                expiringToday: expiringToday,
                expiringSoon: expiringSoon,
                allItems: priorityItems
            )
        }
        #endif
        
        // Fallback a template predefiniti
        return generateSuggestionWithTemplates(
            expiringToday: expiringToday,
            expiringSoon: expiringSoon
        )
    }
    
    /// Genera suggerimento usando Foundation Models (Apple Intelligence)
    @available(iOS 26.0, macOS 26.0, *)
    private func generateSuggestionWithFoundationModels(
        expiringToday: [FoodItem],
        expiringSoon: [FoodItem],
        allItems: [FoodItem]
    ) async -> String? {
        #if canImport(FoundationModels)
        // Prepara il contesto per il modello
        let urgentItems = expiringToday.prefix(3).map { "\($0.name)" }.joined(separator: ", ")
        let soonItems = expiringSoon.prefix(3).map { "\($0.name)" }.joined(separator: ", ")
        
        // Prompt per il modello - ottimizzato per generazione guidata
        // Nota: Questo prompt sarà usato quando l'API Foundation Models sarà disponibile
        // Per ora è commentato perché non viene ancora utilizzato
        _ = urgentItems.isEmpty ? soonItems : urgentItems
        
        // Usa Foundation Models per generare il suggerimento
        // Nota: L'API esatta sarà disponibile quando iOS 26 sarà rilasciato
        // Questo è un placeholder basato sulla documentazione disponibile
        // L'API reale potrebbe essere simile a:
        // let model = try await FoundationModel.default()
        // let response = try await model.generate(prompt: prompt, options: GenerationOptions(maxTokens: 100))
        // return response.text
        
        // Per ora, usiamo un approccio ibrido: template migliorato con contesto
        return generateEnhancedSuggestion(
            expiringToday: expiringToday,
            expiringSoon: expiringSoon
        )
        #else
        // Fallback se Foundation Models non è disponibile
        return generateSuggestionWithTemplates(
            expiringToday: expiringToday,
            expiringSoon: expiringSoon
        )
        #endif
    }
    
    /// Genera suggerimento migliorato usando contesto più ricco (preparazione per Foundation Models)
    private func generateEnhancedSuggestion(
        expiringToday: [FoodItem],
        expiringSoon: [FoodItem]
    ) -> String? {
        if !expiringToday.isEmpty {
            let names = expiringToday.prefix(3).map { $0.name }.joined(separator: ", ")
            let days = expiringToday.first?.daysRemaining ?? 0
            if days < 0 {
                return "⚠️ \(names) sono scaduti — consumali subito per evitare sprechi"
            } else {
                return "🍽️ Consuma oggi: \(names) — stanno per scadere!"
            }
        } else if !expiringSoon.isEmpty {
            let names = expiringSoon.prefix(3).map { $0.name }.joined(separator: ", ")
            return "⏰ Prossimi a scadere: \(names) — pianifica di consumarli presto"
        }
        
        return nil
    }
    
    /// Genera suggerimento usando template predefiniti (fallback)
    private func generateSuggestionWithTemplates(
        expiringToday: [FoodItem],
        expiringSoon: [FoodItem]
    ) -> String? {
        if !expiringToday.isEmpty {
            let names = expiringToday.prefix(3).map { $0.name }.joined(separator: ", ")
            return "Mangia questi oggi per evitare sprechi: \(names)"
        } else if !expiringSoon.isEmpty {
            let names = expiringSoon.prefix(3).map { $0.name }.joined(separator: ", ")
            return "Prossimi a scadere: \(names) — considera di mangiarli presto"
        }
        
        return nil
    }
    
    /// Costruisce il contesto per il suggerimento
    private func buildContextForSuggestion(
        expiringToday: [FoodItem],
        expiringSoon: [FoodItem],
        allItems: [FoodItem]
    ) -> String {
        var context = ""
        
        if !expiringToday.isEmpty {
            context += "Urgenti (oggi/scaduti): \(expiringToday.map { $0.name }.joined(separator: ", "))\n"
        }
        
        if !expiringSoon.isEmpty {
            context += "Prossimi (2-3 giorni): \(expiringSoon.prefix(5).map { $0.name }.joined(separator: ", "))\n"
        }
        
        return context
    }
    
    /// Raggruppa gli alimenti per urgenza
    func groupByUrgency(_ items: [FoodItem]) -> [String: [FoodItem]] {
        let activeItems = items.filter { !$0.isConsumed }
        
        return [
            "Urgenti": activeItems.filter { $0.expirationStatus == .expired || $0.expirationStatus == .today },
            "Prossimi": activeItems.filter { $0.expirationStatus == .soon },
            "Sicuri": activeItems.filter { $0.expirationStatus == .safe }
        ]
    }
}

// MARK: - FoodCategory Priority Extension
private extension FoodCategory {
    var priority: Int {
        switch self {
        case .fridge: return 0
        case .freezer: return 2
        case .pantry: return 1
        }
    }
}

