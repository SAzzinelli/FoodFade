import Foundation
import SwiftData
import Combine

/// Protocol per provider di intelligenza (astrazione)
protocol IntelligenceProvider {
    var isAvailable: Bool { get }
    
    /// Genera un suggerimento per la home basato su tutti gli alimenti
    func generateHomeSuggestion(for items: [FoodItem]) async -> String?
    
    /// Genera un consiglio specifico per un alimento
    func generateItemAdvice(for item: FoodItem, allItems: [FoodItem]) async -> String?
    
    /// Genera insight per le statistiche
    func generateStatisticsInsights(for items: [FoodItem], statistics: StatisticsData) async -> [String]
}

/// Provider locale deterministico (fallback) - NON usa Fridgy, solo funzioni base
/// Questo provider è usato quando Fridgy è disattivato o non disponibile
@MainActor
class LocalIntelligenceProvider: IntelligenceProvider {
    static let shared = LocalIntelligenceProvider()
    
    var isAvailable: Bool { true } // Sempre disponibile
    
    // NOTA: Questo provider NON genera suggerimenti Fridgy
    // Viene usato solo per funzionalità base quando Fridgy è disattivato
    func generateHomeSuggestion(for items: [FoodItem]) async -> String? {
        let activeItems = items.filter { !$0.isConsumed }
        let expiringToday = activeItems.filter { $0.expirationStatus == .today || $0.expirationStatus == .expired }
        let expiringSoon = activeItems.filter { $0.expirationStatus == .soon }
        let openedItems = activeItems.filter { $0.isOpened }
        
        // Regole locali statiche
        if !expiringToday.isEmpty && activeItems.count >= 2 {
            let names = expiringToday.prefix(2).map { $0.name }.joined(separator: " e ")
            return "💡 Idea: potresti consumare \(names) oggi per evitare sprechi"
        } else if !expiringSoon.isEmpty && !openedItems.isEmpty && activeItems.count >= 2 {
            let soonName = expiringSoon.first?.name ?? ""
            return "💡 Suggerimento: \(soonName) sta per scadere — potresti abbinarlo a qualcosa che hai già aperto"
        } else if !expiringSoon.isEmpty && activeItems.count >= 2 {
            let names = expiringSoon.prefix(2).map { $0.name }.joined(separator: " e ")
            return "💡 Prossimi a scadere: \(names) — considera di pianificarli"
        }
        
        return nil
    }
    
    func generateItemAdvice(for item: FoodItem, allItems: [FoodItem]) async -> String? {
        // Questo provider NON genera suggerimenti Fridgy quando Fridgy è disattivato
        // Restituisce nil - l'app funziona senza suggerimenti
        return nil
    }
    
    func generateStatisticsInsights(for items: [FoodItem], statistics: StatisticsData) async -> [String] {
        // Questo provider NON genera insight Fridgy quando Fridgy è disattivato
        // Restituisce array vuoto - l'app funziona senza insight
        return []
    }
}

/// Provider Fridgy - Usa Apple Intelligence o fallback locale per generare suggerimenti Fridgy
/// Questo provider implementa le regole Fridgy e la validazione
@MainActor
class FridgyProvider: IntelligenceProvider {
    static let shared = FridgyProvider()
    
    private let appleIntelligenceProvider = AppleIntelligenceProvider.shared
    private let localFridgyProvider = LocalFridgyProvider.shared
    
    var isAvailable: Bool {
        // Fridgy è disponibile se Apple Intelligence è disponibile O se il fallback locale funziona
        return appleIntelligenceProvider.isAvailable || localFridgyProvider.isAvailable
    }
    
    func generateHomeSuggestion(for items: [FoodItem]) async -> String? {
        // Controlla condizioni minime: almeno 2 alimenti
        guard items.filter({ !$0.isConsumed }).count >= 2 else {
            return nil
        }
        
        // Prova prima con Apple Intelligence se disponibile
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *), appleIntelligenceProvider.isAvailable {
            if let suggestion = await generateWithAppleIntelligence(
                prompt: FridgyPromptBuilder.homePrompt(items: items),
                context: .home
            ) {
                return suggestion
            }
        }
        #endif
        
        // Fallback a provider locale Fridgy
        return await localFridgyProvider.generateHomeSuggestion(for: items)
    }
    
    func generateItemAdvice(for item: FoodItem, allItems: [FoodItem]) async -> String? {
        // Trova alimenti compatibili (stessa categoria, non consumati, diversi da questo)
        let compatibleItems = allItems.filter {
            $0.category == item.category &&
            !$0.isConsumed &&
            $0.id != item.id &&
            ($0.expirationStatus == .soon || $0.expirationStatus == .today || $0.isOpened)
        }
        
        // Prova prima con Apple Intelligence se disponibile
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *), appleIntelligenceProvider.isAvailable {
            if let suggestion = await generateWithAppleIntelligence(
                prompt: FridgyPromptBuilder.itemPrompt(item: item, compatibleItems: Array(compatibleItems.prefix(3))),
                context: .item
            ) {
                return suggestion
            }
        }
        #endif
        
        // Fallback a provider locale Fridgy
        return await localFridgyProvider.generateItemAdvice(for: item, allItems: allItems)
    }
    
    func generateStatisticsInsights(for items: [FoodItem], statistics: StatisticsData) async -> [String] {
        // Prova prima con Apple Intelligence se disponibile
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *), appleIntelligenceProvider.isAvailable {
            if let insight = await generateWithAppleIntelligence(
                prompt: FridgyPromptBuilder.statisticsPrompt(items: items, statistics: statistics),
                context: .statistics
            ) {
                return [insight]
            }
        }
        #endif
        
        // Fallback a provider locale Fridgy
        return await localFridgyProvider.generateStatisticsInsights(for: items, statistics: statistics)
    }
    
    // MARK: - Apple Intelligence Integration
    
    private enum Context {
        case home
        case item
        case statistics
    }
    
    @available(iOS 26.0, macOS 26.0, *)
    private func generateWithAppleIntelligence(prompt: String, context: Context) async -> String? {
        #if canImport(FoundationModels)
        // TODO: Implementare con API reale quando iOS 26 sarà disponibile
        // Per ora usa il fallback locale
        return nil
        #else
        return nil
        #endif
    }
}

/// Provider Apple Intelligence (raw, senza Fridgy)
@MainActor
class AppleIntelligenceProvider {
    static let shared = AppleIntelligenceProvider()
    
    var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            return true
        }
        #endif
        return false
    }
}

/// Provider locale per Fridgy (fallback quando Apple Intelligence non disponibile)
/// Implementa regole Fridgy con logica deterministica e validazione
@MainActor
class LocalFridgyProvider: IntelligenceProvider {
    static let shared = LocalFridgyProvider()
    
    var isAvailable: Bool { true }
    
    func generateHomeSuggestion(for items: [FoodItem]) async -> String? {
        let activeItems = items.filter { !$0.isConsumed }
        
        // Condizioni minime: almeno 2 alimenti
        guard activeItems.count >= 2 else {
            return nil
        }
        
        let expiringToday = activeItems.filter { $0.expirationStatus == .today || $0.expirationStatus == .expired }
        let expiringSoon = activeItems.filter { $0.expirationStatus == .soon }
        let openedItems = activeItems.filter { $0.isOpened }
        
        // Genera suggerimento secondo regole Fridgy
        var suggestion: String?
        
        // Regola: almeno 2 condizioni di valore
        var conditionsMet = 0
        
        if !expiringToday.isEmpty {
            conditionsMet += 1
            let names = expiringToday.prefix(2).map { $0.name }.joined(separator: " e ")
            suggestion = "💡 Idea: potresti consumare \(names) oggi per evitare sprechi"
        } else if !expiringSoon.isEmpty && !openedItems.isEmpty {
            conditionsMet += 2
            let soonName = expiringSoon.first?.name ?? ""
            suggestion = "💡 Suggerimento: \(soonName) sta per scadere — potresti abbinarlo a qualcosa che hai già aperto"
        } else if !expiringSoon.isEmpty && activeItems.count >= 3 {
            conditionsMet += 1
            let names = expiringSoon.prefix(2).map { $0.name }.joined(separator: " e ")
            suggestion = "💡 Prossimi a scadere: \(names) — potresti pianificarli"
        }
        
        // Valida e restituisci solo se passa la validazione
        if let suggestion = suggestion, conditionsMet >= 1 {
            let sanitized = FridgyRules.sanitize(suggestion)
            let validation = FridgyRules.validate(sanitized)
            
            if case .accepted = validation {
                return sanitized
            }
        }
        
        return nil
    }
    
    func generateItemAdvice(for item: FoodItem, allItems: [FoodItem]) async -> String? {
        // Trova alimenti compatibili (max 2-3)
        let compatibleItems = allItems.filter {
            $0.category == item.category &&
            !$0.isConsumed &&
            $0.id != item.id &&
            ($0.expirationStatus == .soon || $0.expirationStatus == .today || $0.isOpened)
        }.prefix(3)
        
        var suggestion: String?
        
        // Suggerimento specifico per questo alimento
        if item.isOpened && !compatibleItems.isEmpty {
            let names = compatibleItems.map { $0.name }.joined(separator: " e ")
            suggestion = "💡 Puoi abbinarlo con \(names) che hai già"
        } else if item.expirationStatus == .today || item.expirationStatus == .expired {
            suggestion = "💡 Idea: potresti consumarlo oggi"
        } else if item.expirationStatus == .soon && !compatibleItems.isEmpty {
            let names = compatibleItems.map { $0.name }.joined(separator: " e ")
            suggestion = "💡 Puoi abbinarlo con \(names) che hai già"
        } else if item.expirationStatus == .soon {
            let days = item.daysRemaining
            suggestion = "💡 Scade tra \(days) \(days == 1 ? "giorno" : "giorni") — potresti pianificarlo"
        }
        
        // Valida e restituisci solo se passa
        if let suggestion = suggestion {
            let sanitized = FridgyRules.sanitize(suggestion)
            let validation = FridgyRules.validate(sanitized)
            
            if case .accepted = validation {
                return sanitized
            }
        }
        
        return nil
    }
    
    func generateStatisticsInsights(for items: [FoodItem], statistics: StatisticsData) async -> [String] {
        var insights: [String] = []
        
        let consumed = items.filter { $0.isConsumed }
        let expired = items.filter { !$0.isConsumed && $0.expirationStatus == .expired }
        
        // Insight 1: Pattern consumo (descrittivo, non giudicante)
        if consumed.count > expired.count * 2 && consumed.count >= 5 {
            let insight = "💡 Questa settimana Fridgy nota che consumi spesso prodotti già aperti"
            let sanitized = FridgyRules.sanitize(insight)
            if case .accepted = FridgyRules.validate(sanitized) {
                insights.append(sanitized)
            }
        }
        
        // Insight 2: Trend positivo (waste score alto = molti consumati in tempo)
        if statistics.wasteScore >= 0.7 && consumed.count >= 3 {
            let insight = "💡 Stai consumando bene i prodotti prima che scadano: continua così!"
            let sanitized = FridgyRules.sanitize(insight)
            if case .accepted = FridgyRules.validate(sanitized) {
                insights.append(sanitized)
            }
        }
        
        // Massimo 1 insight
        return Array(insights.prefix(1))
    }
}

/// Manager centrale per Fridgy
/// REGOLA: Fridgy appare SOLO se toggle ON E Apple Intelligence disponibile
/// Se toggle OFF → Fridgy non appare, app usa solo funzioni base locali
@MainActor
class IntelligenceManager: ObservableObject {
    static let shared = IntelligenceManager()
    
    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "fridgyEnabled")
        }
    }
    
    @Published var isAppleIntelligenceAvailable: Bool = false
    
    private let fridgyProvider = FridgyProvider.shared
    private let localProvider = LocalIntelligenceProvider.shared
    
    private init() {
        self.isEnabled = UserDefaults.standard.bool(forKey: "fridgyEnabled")
        
        // Verifica disponibilità Apple Intelligence all'avvio
        checkAppleIntelligenceAvailability()
    }
    
    /// Verifica se Apple Intelligence è disponibile sul dispositivo
    func checkAppleIntelligenceAvailability() {
        #if canImport(FoundationModels)
        if #available(iOS 18.0, macOS 15.0, *) {
            isAppleIntelligenceAvailable = AppleIntelligenceProvider.shared.isAvailable
        } else {
            isAppleIntelligenceAvailable = false
        }
        #else
        isAppleIntelligenceAvailable = false
        #endif
    }
    
    /// Verifica se Fridgy può essere usato
    /// Fridgy è disponibile SOLO se: toggle ON E Apple Intelligence disponibile
    var isFridgyAvailable: Bool {
        return isEnabled && isAppleIntelligenceAvailable
    }
    
    /// Genera suggerimento Fridgy per la home
    /// Restituisce nil se Fridgy non è disponibile
    func generateHomeSuggestion(for items: [FoodItem]) async -> String? {
        guard isFridgyAvailable else {
            return nil // Fridgy non disponibile → non mostrare nulla
        }
        
        let suggestion = await fridgyProvider.generateHomeSuggestion(for: items)
        
        // Validazione finale
        if let suggestion = suggestion {
            let sanitized = FridgyRules.sanitize(suggestion)
            let validation = FridgyRules.validate(sanitized)
            
            if case .accepted = validation {
                return sanitized
            }
        }
        
        return nil
    }
    
    /// Genera consiglio Fridgy per un alimento specifico
    /// Restituisce nil se Fridgy non è disponibile
    func generateItemAdvice(for item: FoodItem, allItems: [FoodItem]) async -> String? {
        guard isFridgyAvailable else {
            return nil // Fridgy non disponibile → non mostrare nulla
        }
        
        let advice = await fridgyProvider.generateItemAdvice(for: item, allItems: allItems)
        
        // Validazione finale
        if let advice = advice {
            let sanitized = FridgyRules.sanitize(advice)
            let validation = FridgyRules.validate(sanitized)
            
            if case .accepted = validation {
                return sanitized
            }
        }
        
        return nil
    }
    
    /// Genera insight Fridgy per le statistiche
    /// Restituisce array vuoto se Fridgy non è disponibile
    func generateStatisticsInsights(for items: [FoodItem], statistics: StatisticsData) async -> [String] {
        guard isFridgyAvailable else {
            return [] // Fridgy non disponibile → non mostrare nulla
        }
        
        let insights = await fridgyProvider.generateStatisticsInsights(for: items, statistics: statistics)
        
        // Validazione finale per ogni insight
        return insights.compactMap { insight in
            let sanitized = FridgyRules.sanitize(insight)
            let validation = FridgyRules.validate(sanitized)
            
            if case .accepted = validation {
                return sanitized
            }
            return nil
        }
    }
}
