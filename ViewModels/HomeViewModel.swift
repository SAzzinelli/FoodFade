import Foundation
import SwiftData
import SwiftUI
import Combine

/// Tipo di KPI card
enum KPICardType: String, CaseIterable, Codable, Hashable {
    case expiringToday = "expiringToday"
    case toConsume = "toConsume"
    case incoming = "incoming"
    case allOk = "allOk"
    
    var title: String {
        switch self {
        case .expiringToday: return "Scadono oggi"
        case .toConsume: return "Da consumare"
        case .incoming: return "Nei prossimi giorni"
        case .allOk: return "Tutto ok"
        }
    }
    
    var icon: String {
        switch self {
        case .expiringToday: return "exclamationmark.triangle.fill"
        case .toConsume: return "fork.knife"
        case .incoming: return "clock.fill"
        case .allOk: return "checkmark.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .expiringToday: return .red
        case .toConsume: return AppTheme.accentOrange
        case .incoming: return AppTheme.accentYellow
        case .allOk: return .green
        }
    }
}

/// Suggerimento "Oggi per te": una frase dinamica, prossima azione (la View risolve in stringa localizzata).
enum OggiPerTeSuggestion {
    case consumeTodayOne(name: String)
    case consumeTodayMany(count: Int)
    case consumeTomorrowOne(name: String)
    case consumeInDaysOne(name: String, days: Int)
    case consumeTomorrowMany(count: Int)
    case incomingSoon        // solo "nei prossimi giorni" → niente di urgente oggi, ma non "tutto sotto controllo"
    case fridgeUnderControl  // solo "tutto ok" → davvero tutto sotto controllo
    case noUrgency           // inventario vuoto o solo tutto ok (alias)
}

@MainActor
class HomeViewModel: ObservableObject {
    @Published var expiringToday: [FoodItem] = []
    @Published var toConsume: [FoodItem] = []
    @Published var incoming: [FoodItem] = []
    @Published var allOk: [FoodItem] = []
    @Published var expiredCount: Int = 0
    @Published var smartSuggestion: String? // Retrocompatibilità
    @Published var fridgySuggestion: String? // Retrocompatibilità
    @Published var fridgyMessage: String?
    @Published var fridgyContext: FridgyContext?
    @Published var isLoading = false
    @Published var kpiCardOrder: [KPICardType] = [.expiringToday, .toConsume, .incoming, .allOk]
    
    @AppStorage("kpiCardOrder") private var kpiCardOrderData: Data?
    
    private var modelContext: ModelContext?
    private let fridgyService: FridgyService = FridgyServiceImpl.shared
    private var progressRingMode: ProgressRingMode = .safeItems
    
    init() {
        loadKPICardOrder()
    }
    
    func setup(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadProgressRingMode()
        loadData()
    }
    
    private func loadProgressRingMode() {
        guard let modelContext = modelContext else { return }
        let descriptor = FetchDescriptor<AppSettings>()
        if let settings = try? modelContext.fetch(descriptor).first {
            progressRingMode = settings.progressRingMode
        }
    }
    
    func loadData() {
        guard let modelContext = modelContext else { return }
        
        isLoading = true
        
        let descriptor = FetchDescriptor<FoodItem>(
            sortBy: [SortDescriptor(\.expirationDate, order: .forward)]
        )
        
        do {
            let allItems = try modelContext.fetch(descriptor)
            
            let activeItems = allItems.filter { !$0.isConsumed }
            
            let calendar = Calendar.current
            let now = Date()
            let endOfToday = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: now) ?? now)
            let endOfTomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 2, to: now) ?? now)
            let soonThreshold = calendar.date(byAdding: .day, value: 3, to: now) ?? now
            
            // Calcola KPI con priorità (ogni prodotto appare solo in un KPI)
            var remainingItems = activeItems
            
            // 1. Scadono oggi: expiryDate <= endOfToday
            expiringToday = remainingItems.filter { item in
                let expiry = item.effectiveExpirationDate
                return expiry < endOfToday || calendar.isDate(expiry, inSameDayAs: now)
            }
            remainingItems = remainingItems.filter { !expiringToday.contains($0) }
            
            // 2. Da consumare: expiryDate <= endOfTomorrow (esclusi quelli già in "Scadono oggi")
            toConsume = remainingItems.filter { item in
                let expiry = item.effectiveExpirationDate
                return expiry < endOfTomorrow
            }
            remainingItems = remainingItems.filter { !toConsume.contains($0) }
            
            // 3. Nei prossimi giorni: expiryDate > endOfTomorrow AND expiryDate <= now + 3 giorni
            incoming = remainingItems.filter { item in
                let expiry = item.effectiveExpirationDate
                return expiry > endOfTomorrow && expiry <= soonThreshold
            }
            remainingItems = remainingItems.filter { !incoming.contains($0) }
            
            // 4. Tutto ok: tutto il resto
            allOk = remainingItems
            
            expiredCount = allItems.filter { !$0.isConsumed && $0.expirationStatus == .expired }.count
            
            // Fridgy non è più mostrato in Home; suggerimenti solo nelle viste singole (Scadono oggi, Da consumare, ecc.)
            fridgyMessage = nil
            fridgyContext = nil
            fridgySuggestion = nil
            smartSuggestion = nil
            
            // Ricarica la modalità dell'anello (potrebbe essere cambiata nelle impostazioni)
            loadProgressRingMode()
            
            isLoading = false
        } catch {
            print("Errore nel caricamento dei dati: \(error)")
            isLoading = false
        }
    }
    
    func moveKPI(from source: IndexSet, to destination: Int) {
        kpiCardOrder.move(fromOffsets: source, toOffset: destination)
        saveKPICardOrder()
    }
    
    func count(for type: KPICardType) -> Int {
        switch type {
        case .expiringToday: return expiringToday.count
        case .toConsume: return toConsume.count
        case .incoming: return incoming.count
        case .allOk: return allOk.count
        }
    }
    
    private func loadKPICardOrder() {
        guard let data = kpiCardOrderData,
              let order = try? JSONDecoder().decode([KPICardType].self, from: data) else {
            kpiCardOrder = [.expiringToday, .toConsume, .incoming, .allOk]
            return
        }
        kpiCardOrder = order
    }
    
    private func saveKPICardOrder() {
        if let data = try? JSONEncoder().encode(kpiCardOrder) {
            kpiCardOrderData = data
        }
    }
    
    /// Percentuale per l'anello di progresso (calcolata in base alla modalità selezionata).
    /// - safeItems: prodotti "con margine" (tutto ok + nei prossimi giorni) / totale → anello pieno = inventario sotto controllo.
    /// - atRisk: prodotti a rischio (scadono oggi + da consumare + nei prossimi giorni) / totale.
    var progressRingPercentage: Double {
        let total = expiringToday.count + toConsume.count + incoming.count + allOk.count
        guard total > 0 else {
            return progressRingMode == .atRisk ? 0.0 : 1.0
        }
        
        switch progressRingMode {
        case .safeItems:
            let withMargin = allOk.count + incoming.count
            return Double(withMargin) / Double(total)
        case .atRisk:
            let atRiskCount = expiringToday.count + toConsume.count + incoming.count
            return Double(atRiskCount) / Double(total)
        }
    }
    
    /// Percentuale di items sicuri (tutto ok) - mantenuta per retrocompatibilità
    var safeItemsPercentage: Double {
        progressRingPercentage
    }
    
    /// Totale items attivi
    var totalActiveItems: Int {
        expiringToday.count + toConsume.count + incoming.count + allOk.count
    }
    
    /// Prodotti "in scadenza" (scadono oggi + da consumare + nei prossimi giorni), esclusi gli scaduti
    var inScadenzaCount: Int {
        totalActiveItems - allOk.count - expiredCount
    }
    
    /// Conteggi per i 3 anelli: OK, in scadenza, scaduti
    var activityRingCounts: (ok: Int, inScadenza: Int, expired: Int) {
        (allOk.count, inScadenzaCount, expiredCount)
    }
    
    /// Suggerimento "Oggi per te": una sola frase, prossima azione (no numeri, no grafici).
    /// Priorità: 1) scadono oggi 2) da consumare (domani) 3) nei prossimi giorni 4) solo tutto ok.
    /// "Tutto sotto controllo" solo quando ci sono solo prodotti tutto ok (o inventario vuoto). Se ci sono "nei prossimi giorni" → incomingSoon, non fridgeUnderControl.
    var oggiPerTeSuggestion: OggiPerTeSuggestion {
        if !expiringToday.isEmpty {
            let first = expiringToday.first!
            return (expiringToday.count == 1 && !first.name.isEmpty)
                ? .consumeTodayOne(name: first.name)
                : .consumeTodayMany(count: expiringToday.count)
        }
        if !toConsume.isEmpty {
            let first = toConsume.first!
            let days = first.daysRemaining
            if toConsume.count == 1 && !first.name.isEmpty {
                if days == 1 { return .consumeTomorrowOne(name: first.name) }
                return .consumeInDaysOne(name: first.name, days: days)
            }
            return .consumeTomorrowMany(count: toConsume.count)
        }
        if !incoming.isEmpty {
            return .incomingSoon
        }
        return .fridgeUnderControl
    }

    /// Sottotitolo opzionale per la card "Oggi per te" (es. "Frigorifero • 1 pz") quando il suggerimento riguarda un singolo prodotto.
    var oggiPerTeSubtitle: String? {
        let first: FoodItem?
        if !expiringToday.isEmpty, expiringToday.count == 1, !expiringToday.first!.name.isEmpty {
            first = expiringToday.first
        } else if !toConsume.isEmpty, toConsume.count == 1, !toConsume.first!.name.isEmpty {
            first = toConsume.first
        } else {
            first = nil
        }
        guard let item = first else { return nil }
        let cat = item.category.rawValue
        let qty = item.quantity
        return "\(cat) • \(qty) pz"
    }
    
    /// Carica il suggerimento Fridgy per la home usando la nuova architettura
    private func loadFridgySuggestion(for items: [FoodItem]) async {
        // La VIEW decide se mostrare Fridgy (controlla se è abilitato)
        guard IntelligenceManager.shared.isFridgyAvailable else {
            await MainActor.run {
                fridgyMessage = nil
                fridgyContext = nil
                fridgySuggestion = nil
                smartSuggestion = nil
            }
            return
        }
        
        // La BUSINESS LOGIC decide il payload
        guard let payload = FridgyPayload.forHome(items: items) else {
            await MainActor.run {
                fridgyMessage = nil
                fridgyContext = nil
                fridgySuggestion = nil
                smartSuggestion = nil
            }
            return
        }
        
        // Il SERVIZIO genera il testo
        do {
            let text = try await fridgyService.generateMessage(from: payload.promptContext)
            
            // Validazione: controlla che il testo sia valido
            let sanitized = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !sanitized.isEmpty && sanitized.count <= 100 {
                await MainActor.run {
                    fridgyContext = payload.context
                    fridgyMessage = sanitized
                    // Retrocompatibilità
                    fridgySuggestion = sanitized
                    smartSuggestion = sanitized
                }
            } else {
                await MainActor.run {
                    fridgyMessage = nil
                    fridgyContext = nil
                    fridgySuggestion = nil
                    smartSuggestion = nil
                }
            }
        } catch {
            // Se Apple Intelligence non è disponibile o c'è un errore, Fridgy non mostra nulla
            await MainActor.run {
                fridgyMessage = nil
                fridgyContext = nil
                fridgySuggestion = nil
                smartSuggestion = nil
            }
        }
    }
}

// MARK: - Color extension per Codable
extension Color {
    // Questo non è usato per Codable, solo per riferimento
}
