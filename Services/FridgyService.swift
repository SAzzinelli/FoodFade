import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Protocollo per il servizio Fridgy (LLM)
/// La view NON sa come funziona, solo che genera testo
protocol FridgyService {
    func generateMessage(from promptContext: String) async throws -> String
}

/// Implementazione con Apple Intelligence
/// Funziona SOLO se Apple Intelligence è disponibile, nessun fallback hardcoded
@MainActor
class FridgyServiceImpl: FridgyService {
    static let shared = FridgyServiceImpl()
    
    private let isAppleIntelligenceAvailable: Bool
    
    private init() {
        // Verifica disponibilità Apple Intelligence su iOS 26.2+
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            // Verifica se il dispositivo supporta Apple Intelligence (iPhone 15 Pro+, iPad M1+, Mac Apple Silicon)
            // iPhone 15 Pro e successivi supportano Apple Intelligence
            // Per ora assumiamo che se il framework è disponibile, l'hardware lo supporta
            isAppleIntelligenceAvailable = true
        } else {
            isAppleIntelligenceAvailable = false
        }
        #else
        isAppleIntelligenceAvailable = false
        #endif
    }
    
    func generateMessage(from promptContext: String) async throws -> String {
        // SOLO se Apple Intelligence è disponibile e abilitato
        guard isAppleIntelligenceAvailable && IntelligenceManager.shared.isFridgyAvailable else {
            throw FridgyError.appleIntelligenceNotAvailable
        }
        
        return try await generateWithAppleIntelligence(promptContext: promptContext)
    }
    
    // MARK: - Apple Intelligence (quando disponibile)
    
    @available(iOS 26.0, macOS 26.0, *)
    private func generateWithAppleIntelligence(promptContext: String) async throws -> String {
        #if canImport(FoundationModels)
        // Usa Foundation Models API per generare la risposta
        let model = SystemLanguageModel.default
        
        // Verifica disponibilità del modello
        switch model.availability {
        case .available:
            // Il modello è disponibile, procedi con la generazione
            do {
                // Crea una sessione con le istruzioni per Fridgy (incluso contesto conservazione)
                let session = LanguageModelSession(instructions: """
                    \(FridgyRules.basePrompt)
                    \(FridgyRules.storageContextPrompt)
                    Non usare parole come "sicuro", "rischioso", "fa bene", "dovresti", "meglio per la salute".
                    Se non c'è un buon suggerimento, rispondi solo con "nessun suggerimento".
                    """)
                
                // Genera la risposta
                let response = try await session.respond(to: promptContext)
                
                // Estrai il contenuto dalla risposta
                let text = response.content.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                
                // Validazione: se è "nessun suggerimento" o troppo lungo, lancia errore
                if text.lowercased().contains("nessun suggerimento") || text.isEmpty {
                    throw FridgyError.noSuggestion
                }
                
                // Conta le parole (approssimativo)
                let wordCount = text.split(separator: " ").count
                if wordCount > 20 {
                    throw FridgyError.tooLong
                }
                
                return text
            } catch {
                // Se c'è un errore nella generazione, rilancia
                throw error
            }
        default:
            // Il modello non è disponibile
            throw FridgyError.appleIntelligenceNotAvailable
        }
        #else
        throw FridgyError.appleIntelligenceNotAvailable
        #endif
    }
}

// MARK: - Errori Fridgy

enum FridgyError: LocalizedError {
    case appleIntelligenceNotAvailable
    case notImplemented
    case noSuggestion
    case tooLong
    
    var errorDescription: String? {
        switch self {
        case .appleIntelligenceNotAvailable:
            return "Apple Intelligence non disponibile"
        case .notImplemented:
            return "Funzionalità non ancora implementata"
        case .noSuggestion:
            return "Nessun suggerimento disponibile"
        case .tooLong:
            return "Suggerimento troppo lungo"
        }
    }
}
