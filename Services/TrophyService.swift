import Foundation
import SwiftUI
import SwiftData
import Combine

extension Notification.Name {
    static let trophyUnlocked = Notification.Name("FoodFade.Trophy.Unlocked")
}

/// Progresso verso un trofeo (per barra, percentuale, "quanto manca")
struct TrophyProgress: Identifiable, Equatable {
    let trophy: Trophy
    let isUnlocked: Bool
    /// 0.0 ... 1.0
    let progress: Double
    let currentValue: Int
    let targetValue: Int
    /// Per waste score: 0...100, altrimenti stesso significato di target
    let progressPercent: Int
    /// Testo tipo "3/7 giorni senza sprechi" o "Mancano 2 giorni" o "Sbloccato il ..."
    let progressSubtitle: String
    let unlockDate: Date?
    
    var id: String { trophy.rawValue }
}

/// Servizio per trofei: persistenza sblocchi e logica di verifica condizioni
final class TrophyService: ObservableObject {
    static let shared = TrophyService()

    private let unlockedKey = "FoodFade.Trophy.Unlocked"
    private let unlockDatesKey = "FoodFade.Trophy.UnlockDates"
    private let lastSeenCountKey = "FoodFade.Trophy.LastSeenCount"

    /// ID trofei sbloccati
    @Published private(set) var unlockedIDs: Set<String> = []

    /// Numero di trofei sbloccati quando l'utente ha aperto l'ultima volta la vista Trofei (per badge)
    private var lastSeenUnlockCount: Int {
        get { UserDefaults.standard.integer(forKey: lastSeenCountKey) }
        set { UserDefaults.standard.set(newValue, forKey: lastSeenCountKey) }
    }

    /// True se ci sono nuovi trofei sbloccati da quando l'utente ha aperto la vista Trofei
    var hasUnseenTrophies: Bool {
        unseenTrophyCount > 0
    }

    /// Numero di trofei nuovi (non ancora "visti" aprendo la vista Trofei)
    var unseenTrophyCount: Int {
        max(0, unlockedIDs.count - lastSeenUnlockCount)
    }

    /// Data di sblocco per trofeo (per mostrare "Sbloccato il ...")
    private var unlockDates: [String: Date] {
        get {
            guard let data = UserDefaults.standard.data(forKey: unlockDatesKey),
                  let decoded = try? JSONDecoder().decode([String: Date].self, from: data) else { return [:] }
            return decoded
        }
        set {
            if let encoded = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(encoded, forKey: unlockDatesKey)
            }
        }
    }

    private init() {
        if let stored = UserDefaults.standard.stringArray(forKey: unlockedKey) {
            unlockedIDs = Set(stored)
        }
    }

    func isUnlocked(_ trophy: Trophy) -> Bool {
        unlockedIDs.contains(trophy.rawValue)
    }

    func unlockDate(for trophy: Trophy) -> Date? {
        unlockDates[trophy.rawValue]
    }
    
    /// Progresso di ogni trofeo (per card Statistiche e sheet dettaglio)
    func progressForAllTrophies(items: [FoodItem]) -> [TrophyProgress] {
        let active = items.filter { !$0.isConsumed }
        let consumed = items.filter { $0.isConsumed }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let streak = currentStreak(items: items)
        let consumedInTime = consumedInTimeThisMonth(items: consumed, calendar: calendar, today: today)
        let (wasteScoreValue, wasteTotal) = wasteScoreThisMonth(items: items, consumed: consumed, calendar: calendar, today: today)
        let requiredUnlocked = Trophy.requiredForMaster.filter { isUnlocked($0) }.count
        
        return Trophy.sortedAll.map { trophy in
            let unlocked = isUnlocked(trophy)
            let date = unlockDate(for: trophy)
            switch trophy {
            case .firstStep:
                let cur = min(1, items.count)
                let prog = items.count >= 1 ? 1.0 : 0.0
                let sub = unlocked ? (date.map { String(format: "trophy.unlocked_on".localized, formatDate($0)) } ?? "") : (items.isEmpty ? "trophy.progress.add_one".localized : "trophy.progress.done".localized)
                return TrophyProgress(trophy: trophy, isUnlocked: unlocked, progress: prog, currentValue: cur, targetValue: 1, progressPercent: Int(prog * 100), progressSubtitle: sub, unlockDate: date)
            case .fullFridge:
                let cur = active.count
                let target = 10
                let prog = min(1.0, Double(cur) / Double(target))
                let sub: String
                if unlocked { sub = date.map { String(format: "trophy.unlocked_on".localized, formatDate($0)) } ?? "" }
                else if cur >= target { sub = "trophy.progress.done".localized }
                else { sub = String(format: "trophy.progress.products".localized, cur, target) }
                return TrophyProgress(trophy: trophy, isUnlocked: unlocked, progress: prog, currentValue: cur, targetValue: target, progressPercent: Int(prog * 100), progressSubtitle: sub, unlockDate: date)
            case .fridgyFriend:
                let target = 3
                let prog = min(1.0, Double(streak) / Double(target))
                let sub: String
                if unlocked { sub = date.map { String(format: "trophy.unlocked_on".localized, formatDate($0)) } ?? "" }
                else if streak >= target { sub = "trophy.progress.done".localized }
                else { sub = String(format: "trophy.progress.days_streak".localized, streak, target) }
                return TrophyProgress(trophy: trophy, isUnlocked: unlocked, progress: prog, currentValue: streak, targetValue: target, progressPercent: Int(prog * 100), progressSubtitle: sub, unlockDate: date)
            case .weekClean:
                let target = 7
                let prog = min(1.0, Double(streak) / Double(target))
                let sub: String
                if unlocked { sub = date.map { String(format: "trophy.unlocked_on".localized, formatDate($0)) } ?? "" }
                else if streak >= target { sub = "trophy.progress.done".localized }
                else { sub = String(format: "trophy.progress.days_streak".localized, streak, target) }
                return TrophyProgress(trophy: trophy, isUnlocked: unlocked, progress: prog, currentValue: streak, targetValue: target, progressPercent: Int(prog * 100), progressSubtitle: sub, unlockDate: date)
            case .carefulConsumer:
                let target = 5
                let prog = min(1.0, Double(consumedInTime) / Double(target))
                let sub: String
                if unlocked { sub = date.map { String(format: "trophy.unlocked_on".localized, formatDate($0)) } ?? "" }
                else if consumedInTime >= target { sub = "trophy.progress.done".localized }
                else { sub = String(format: "trophy.progress.consumed_month".localized, consumedInTime, target) }
                return TrophyProgress(trophy: trophy, isUnlocked: unlocked, progress: prog, currentValue: consumedInTime, targetValue: target, progressPercent: Int(prog * 100), progressSubtitle: sub, unlockDate: date)
            case .wasteFighter:
                let targetPercent = 80
                let scorePercent = wasteTotal > 0 ? Int(wasteScoreValue * 100) : 0
                let prog = wasteTotal >= 3 ? min(1.0, Double(scorePercent) / Double(targetPercent)) : 0.0
                let sub: String
                if unlocked { sub = date.map { String(format: "trophy.unlocked_on".localized, formatDate($0)) } ?? "" }
                else if wasteTotal < 3 { sub = "trophy.progress.waste_need_more".localized }
                else { sub = String(format: "trophy.progress.waste_score".localized, scorePercent, targetPercent) }
                return TrophyProgress(trophy: trophy, isUnlocked: unlocked, progress: prog, currentValue: scorePercent, targetValue: targetPercent, progressPercent: scorePercent, progressSubtitle: sub, unlockDate: date)
            case .master:
                let target = 6
                let prog = Double(requiredUnlocked) / Double(target)
                let sub: String
                if unlocked { sub = date.map { String(format: "trophy.unlocked_on".localized, formatDate($0)) } ?? "" }
                else if requiredUnlocked >= target { sub = "trophy.progress.done".localized }
                else { sub = String(format: "trophy.progress.master".localized, requiredUnlocked, target) }
                return TrophyProgress(trophy: trophy, isUnlocked: unlocked, progress: prog, currentValue: requiredUnlocked, targetValue: target, progressPercent: Int(prog * 100), progressSubtitle: sub, unlockDate: date)
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: date)
    }
    
    private func consumedInTimeThisMonth(items: [FoodItem], calendar: Calendar, today: Date) -> Int {
        items.filter { item in
            guard let consumedDate = item.consumedDate else { return false }
            guard calendar.isDate(consumedDate, equalTo: today, toGranularity: .month) else { return false }
            return item.expirationDate >= calendar.startOfDay(for: consumedDate)
        }.count
    }
    
    private func wasteScoreThisMonth(items: [FoodItem], consumed: [FoodItem], calendar: Calendar, today: Date) -> (score: Double, total: Int) {
        let thisMonthConsumed = consumed.filter { item in
            guard let d = item.consumedDate else { return false }
            return calendar.isDate(d, equalTo: today, toGranularity: .month)
        }.count
        let thisMonthExpired = items.filter { item in
            !item.isConsumed && calendar.isDate(item.expirationDate, equalTo: today, toGranularity: .month) && item.expirationDate < today
        }.count
        let total = thisMonthConsumed + thisMonthExpired
        let score = total > 0 ? Double(thisMonthConsumed) / Double(total) : 0
        return (score, total)
    }

    /// Sblocca un trofeo, persiste e notifica (banner + haptic)
    func unlock(_ trophy: Trophy) {
        guard !unlockedIDs.contains(trophy.rawValue) else { return }
        unlockedIDs.insert(trophy.rawValue)
        var dates = unlockDates
        dates[trophy.rawValue] = Date()
        unlockDates = dates
        UserDefaults.standard.set(Array(unlockedIDs), forKey: unlockedKey)
        objectWillChange.send()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        NotificationCenter.default.post(
            name: .trophyUnlocked,
            object: nil,
            userInfo: ["trophyRawValue": trophy.rawValue]
        )
    }

    /// Chiamare quando l'utente apre la vista Trofei (azzera il badge)
    func markTrophiesAsSeen() {
        lastSeenUnlockCount = unlockedIDs.count
        objectWillChange.send()
    }

    /// Verifica tutte le condizioni e sblocca i trofei ottenuti. Chiamare con gli item correnti (es. da Home o Statistiche).
    func checkTrophies(items: [FoodItem]) {
        let active = items.filter { !$0.isConsumed }
        let consumed = items.filter { $0.isConsumed }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // firstStep: almeno un prodotto (mai o attuale)
        if items.count >= 1 {
            unlock(.firstStep)
        }

        // fullFridge: 10+ prodotti in inventario (non consumati)
        if active.count >= 10 {
            unlock(.fullFridge)
        }

        // Streak: giorni consecutivi senza sprechi (nessun prodotto con expirationDate in quel giorno lasciato non consumato)
        let streak = currentStreak(items: items)
        if streak >= 3 {
            unlock(.fridgyFriend)
        }
        if streak >= 7 {
            unlock(.weekClean)
        }

        // carefulConsumer: 5+ consumati "in tempo" nel mese corrente (consumati prima della scadenza)
        let consumedInTimeThisMonth = consumed.filter { item in
            guard let consumedDate = item.consumedDate else { return false }
            guard calendar.isDate(consumedDate, equalTo: today, toGranularity: .month) else { return false }
            return item.expirationDate >= calendar.startOfDay(for: consumedDate)
        }.count
        if consumedInTimeThisMonth >= 5 {
            unlock(.carefulConsumer)
        }

        // wasteFighter: waste score ≥ 80% nel mese corrente
        let thisMonthConsumed = consumed.filter { item in
            guard let d = item.consumedDate else { return false }
            return calendar.isDate(d, equalTo: today, toGranularity: .month)
        }.count
        let thisMonthExpired = items.filter { item in
            !item.isConsumed && calendar.isDate(item.expirationDate, equalTo: today, toGranularity: .month) && item.expirationDate < today
        }.count
        let total = thisMonthConsumed + thisMonthExpired
        let wasteScore = total > 0 ? Double(thisMonthConsumed) / Double(total) : 1.0
        if wasteScore >= 0.8 && total >= 3 {
            unlock(.wasteFighter)
        }

        // master: tutti gli altri sbloccati
        let allOthers = Trophy.requiredForMaster
        if allOthers.allSatisfy({ isUnlocked($0) }) {
            unlock(.master)
        }
    }

    /// Calcola la serie attuale: giorni consecutivi (fino a ieri) senza sprechi
    private func currentStreak(items: [FoodItem]) -> Int {
        let calendar = Calendar.current
        var streak = 0
        var dayToCheck = calendar.date(byAdding: .day, value: -1, to: Date())! // ieri
        let farPast = calendar.date(byAdding: .day, value: -365, to: Date())!

        while dayToCheck >= farPast {
            let startOfDay = calendar.startOfDay(for: dayToCheck)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            // Quel giorno c'è stato spreco se esiste un item con expirationDate in quel giorno e non consumato
            let hadWasteThatDay = items.contains { item in
                if item.isConsumed { return false }
                let exp = item.expirationDate
                return exp >= startOfDay && exp < endOfDay
            }
            if hadWasteThatDay { break }
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: dayToCheck) else { break }
            dayToCheck = prev
        }
        return streak
    }
}
