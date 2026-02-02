import Foundation
import SwiftData

/// Contesto visivo per Fridgy (decide icona e colore)
enum FridgyContext {
    case tip        // Consiglio generico (verde, sparkles)
    case warning    // Attenzione (arancione, exclamationmark)
    case reminder   // Promemoria (blu, bell)
}

/// Payload per generare messaggio Fridgy
/// Contiene il contesto UI e il prompt per l'LLM
struct FridgyPayload {
    let context: FridgyContext
    let promptContext: String
    
    /// Genera il payload per un alimento specifico
    static func forFoodItem(_ item: FoodItem) -> FridgyPayload? {
        // Caso critico: aperto + pochi giorni
        let storageLine = "Luogo di conservazione attuale: \(item.category.rawValue). Non suggerire di cambiare luogo; suggerisci solo utilizzo o consumo."
        
        if item.isOpened && item.daysRemaining <= 2 {
            return FridgyPayload(
                context: .warning,
                promptContext: """
                Prodotto aperto.
                Nome: \(item.name)
                \(storageLine)
                Giorni rimanenti: \(item.daysRemaining)
                Suggerisci cosa fare per evitare sprechi (es. ricetta, consumare oggi).
                Massimo 20 parole, tono amichevole.
                """
            )
        }
        
        // Caso reminder: aperto ma ancora tempo
        if item.isOpened && item.daysRemaining > 2 {
            return FridgyPayload(
                context: .reminder,
                promptContext: """
                Prodotto aperto recentemente.
                Nome: \(item.name)
                \(storageLine)
                Giorni rimanenti: \(item.daysRemaining)
                Spiega in modo amichevole che la durata è ridotta dopo l'apertura. Suggerisci un utilizzo, non dove conservare.
                Massimo 20 parole.
                """
            )
        }
        
        // Caso tip: prodotto fresco
        if item.isFresh && !item.isOpened {
            return FridgyPayload(
                context: .tip,
                promptContext: """
                Prodotto fresco non aperto.
                Nome: \(item.name)
                \(storageLine)
                Suggerisci un consiglio di utilizzo (non di conservazione: è già nel luogo giusto).
                Massimo 20 parole.
                """
            )
        }
        
        // Caso tip: scade presto (allargato a <= 7 giorni)
        if item.expirationStatus == .soon && item.daysRemaining <= 7 {
            return FridgyPayload(
                context: .tip,
                promptContext: """
                Prodotto che scade presto.
                Nome: \(item.name)
                \(storageLine)
                Giorni rimanenti: \(item.daysRemaining)
                Suggerisci un'idea per consumarlo (ricetta o utilizzo).
                Massimo 20 parole.
                """
            )
        }
        
        // Caso generico: prodotto normale con scadenza tra 8-15 giorni
        if item.daysRemaining >= 8 && item.daysRemaining <= 15 && !item.isOpened {
            return FridgyPayload(
                context: .tip,
                promptContext: """
                Prodotto in buono stato.
                Nome: \(item.name)
                \(storageLine)
                Giorni rimanenti: \(item.daysRemaining)
                Suggerisci un consiglio di utilizzo o ricetta, non dove conservare.
                Massimo 20 parole, tono amichevole.
                """
            )
        }
        
        // Caso generico: prodotto con molti giorni rimanenti (solo se > 15 giorni)
        if item.daysRemaining > 15 && !item.isOpened {
            return FridgyPayload(
                context: .tip,
                promptContext: """
                Prodotto con molti giorni rimanenti.
                Nome: \(item.name)
                \(storageLine)
                Suggerisci un'idea di utilizzo o ricetta, non di conservazione.
                Massimo 20 parole.
                """
            )
        }
        
        return nil
    }
    
    /// Formatta lista prodotti con luogo di conservazione (per contesto home)
    private static func productListWithStorage(_ items: [FoodItem], limit: Int = 2) -> String {
        items.prefix(limit).map { "\($0.name) (\($0.category.rawValue))" }.joined(separator: ", ")
    }
    
    /// Genera il payload per la home (suggerimento generico)
    static func forHome(items: [FoodItem]) -> FridgyPayload? {
        let activeItems = items.filter { !$0.isConsumed }
        guard activeItems.count >= 1 else { return nil }
        
        let expiringToday = activeItems.filter { $0.expirationStatus == .today || $0.expirationStatus == .expired }
        let expiringSoon = activeItems.filter { $0.expirationStatus == .soon }
        let opened = activeItems.filter { $0.isOpened }
        let storageNote = "Ogni prodotto è già nel suo luogo (Frigorifero/Dispensa/Congelatore). Suggerisci solo utilizzo o ricette, mai dove conservare."
        
        // Priorità 1: scadono oggi
        if !expiringToday.isEmpty {
            let list = productListWithStorage(expiringToday, limit: 2)
            return FridgyPayload(
                context: .warning,
                promptContext: """
                Prodotti che scadono oggi: \(list)
                \(storageNote)
                Suggerisci un'idea per consumarli oggi (ricetta o utilizzo).
                Massimo 20 parole, tono amichevole.
                """
            )
        }
        
        // Priorità 2: aperti + scadono presto
        if !opened.isEmpty && !expiringSoon.isEmpty {
            let list = productListWithStorage(expiringSoon, limit: 2)
            return FridgyPayload(
                context: .reminder,
                promptContext: """
                Hai prodotti aperti e altri che scadono presto: \(list)
                \(storageNote)
                Suggerisci un'idea per combinarli (ricetta).
                Massimo 20 parole.
                """
            )
        }
        
        // Priorità 3: scadono presto (allargato a >= 2 prodotti)
        if !expiringSoon.isEmpty && activeItems.count >= 2 {
            let list = productListWithStorage(expiringSoon, limit: 2)
            return FridgyPayload(
                context: .tip,
                promptContext: """
                Prodotti che scadono presto: \(list)
                \(storageNote)
                Suggerisci un'idea per pianificarli (utilizzo o ricetta).
                Massimo 20 parole.
                """
            )
        }
        
        // Priorità 4: prodotti aperti (solo se >= 2 prodotti)
        if !opened.isEmpty && activeItems.count >= 2 {
            let list = productListWithStorage(opened, limit: 2)
            return FridgyPayload(
                context: .reminder,
                promptContext: """
                Hai prodotti aperti: \(list)
                \(storageNote)
                Ricorda che la durata si riduce dopo l'apertura. Suggerisci un utilizzo.
                Massimo 20 parole.
                """
            )
        }
        
        // Priorità 5: suggerimento generico (se ci sono almeno 2 prodotti)
        if activeItems.count >= 2 {
            let list = productListWithStorage(activeItems, limit: 2)
            return FridgyPayload(
                context: .tip,
                promptContext: """
                Prodotti nel tuo inventario: \(list)
                \(storageNote)
                Suggerisci un consiglio di utilizzo o ricetta, non di conservazione.
                Massimo 20 parole, tono amichevole.
                """
            )
        }
        
        // Priorità 6: anche con un solo prodotto, se scade presto o è aperto
        if activeItems.count == 1 {
            let item = activeItems[0]
            if item.expirationStatus == .soon || item.isOpened {
                let storageLine = "Luogo: \(item.category.rawValue). Non suggerire dove conservare."
                return FridgyPayload(
                    context: .tip,
                    promptContext: """
                    Prodotto: \(item.name) (\(item.category.rawValue))
                    \(storageLine)
                    \(item.isOpened ? "È aperto" : "Scade presto")
                    Suggerisci un consiglio di utilizzo.
                    Massimo 20 parole.
                    """
                )
            }
        }
        
        return nil
    }
    
    /// Genera il payload per statistiche (insight)
    static func forStatistics(items: [FoodItem], statistics: StatisticsData) -> FridgyPayload? {
        let consumed = items.filter { $0.isConsumed }
        let expired = items.filter { !$0.isConsumed && $0.expirationStatus == .expired }
        let active = items.filter { !$0.isConsumed && $0.expirationStatus != .expired }
        let total = consumed.count + expired.count
        
        // Se non ci sono prodotti, non mostrare Fridgy
        guard !items.isEmpty else { return nil }
        
        // Calcola percentuale sprechi
        let wastePercentage = total > 0 ? Double(expired.count) / Double(total) : 0.0
        
        // PRIORITÀ 1: Sprechi elevati (warning)
        if wastePercentage > 0.4 && expired.count >= 2 {
            return FridgyPayload(
                context: .warning,
                promptContext: """
                Analisi sprechi: hai \(expired.count) prodotti scaduti su \(total) totali (waste score: \(String(format: "%.0f", statistics.wasteScore * 100))%).
                Questo mese: \(statistics.monthlyStats.consumed) consumati, \(statistics.monthlyStats.expired) scaduti.
                Analizza il pattern di sprechi e suggerisci un'idea per ridurli.
                Massimo 20 parole, tono osservativo e non giudicante.
                """
            )
        }
        
        // PRIORITÀ 2: Trend positivo (tip)
        if statistics.wasteScore > 0.7 && consumed.count >= 2 {
            return FridgyPayload(
                context: .tip,
                promptContext: """
                Analisi consumi: hai consumato \(consumed.count) prodotti su \(total) totali (waste score: \(String(format: "%.0f", statistics.wasteScore * 100))%).
                Questo mese: \(statistics.monthlyStats.consumed) consumati, \(statistics.monthlyStats.expired) scaduti.
                Descrivi questo pattern positivo in modo neutro e descrittivo.
                Massimo 20 parole, tono osservativo.
                """
            )
        }
        
        // PRIORITÀ 3: Pattern consumo (tip)
        if consumed.count >= 3 && consumed.count > expired.count * 2 {
            return FridgyPayload(
                context: .tip,
                promptContext: """
                Analisi pattern: tendi a consumare i prodotti prima che scadano.
                Questo mese: \(statistics.monthlyStats.consumed) consumati, \(statistics.monthlyStats.expired) scaduti.
                Descrivi questo pattern in modo neutro e descrittivo.
                Massimo 20 parole, tono osservativo.
                """
            )
        }
        
        // PRIORITÀ 4: Sprechi moderati (reminder)
        if wastePercentage > 0.2 && wastePercentage <= 0.4 && expired.count >= 1 {
            return FridgyPayload(
                context: .reminder,
                promptContext: """
                Analisi sprechi: hai \(expired.count) prodotti scaduti su \(total) totali.
                Questo mese: \(statistics.monthlyStats.consumed) consumati, \(statistics.monthlyStats.expired) scaduti.
                Suggerisci un'idea per migliorare la gestione dei prodotti.
                Massimo 20 parole, tono amichevole.
                """
            )
        }
        
        // PRIORITÀ 5: Insight generico basato su statistiche (se ci sono dati)
        // Se ci sono prodotti attivi ma pochi consumati/scaduti
        if active.count >= 1 && total < 2 {
            return FridgyPayload(
                context: .tip,
                promptContext: """
                Hai \(active.count) prodotti attivi nel tuo inventario.
                Questo mese: \(statistics.monthlyStats.consumed) consumati, \(statistics.monthlyStats.expired) scaduti.
                Fornisci un insight descrittivo sulla gestione dei prodotti.
                Massimo 20 parole, tono neutro e osservativo.
                """
            )
        }
        
        // PRIORITÀ 6: Insight generico (se ci sono almeno 2 prodotti totali) - FALLBACK
        // Questo dovrebbe sempre essere raggiunto se items.count >= 2
        if items.count >= 2 {
            return FridgyPayload(
                context: .tip,
                promptContext: """
                Analisi generale: \(consumed.count) consumati, \(expired.count) scaduti, \(active.count) attivi su \(items.count) totali.
                Questo mese: \(statistics.monthlyStats.consumed) consumati, \(statistics.monthlyStats.expired) scaduti.
                Waste score: \(String(format: "%.0f", statistics.wasteScore * 100))%.
                Fornisci un insight descrittivo sulle tue abitudini di consumo.
                Massimo 20 parole, tono neutro e osservativo.
                """
            )
        }
        
        // PRIORITÀ 7: Fallback assoluto - anche con 1 solo prodotto
        if items.count >= 1 {
            return FridgyPayload(
                context: .tip,
                promptContext: """
                Hai \(items.count) prodotto/i nel tuo inventario.
                Questo mese: \(statistics.monthlyStats.consumed) consumati, \(statistics.monthlyStats.expired) scaduti.
                Fornisci un consiglio generico sulla gestione dei prodotti.
                Massimo 20 parole, tono neutro e osservativo.
                """
            )
        }
        
        return nil
    }
}
