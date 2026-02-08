import Foundation
import UserNotifications
import Combine

/// Servizio per la gestione delle notifiche locali
@MainActor
class NotificationService: ObservableObject {
    static let shared = NotificationService()
    
    private init() {}
    
    /// Richiede l'autorizzazione per le notifiche
    func requestAuthorization() async throws {
        let center = UNUserNotificationCenter.current()
        let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        
        if !granted {
            throw NotificationError.authorizationDenied
        }
    }
    
    /// Programma la notifica per un FoodItem: viene fissata per (scadenza - daysBefore) alle 9:00, se quella data è nel futuro.
    func scheduleNotifications(for item: FoodItem, daysBefore: Int) async {
        guard item.notify, !item.isConsumed else { return }
        
        let calendar = Calendar.current
        let expirationDate = item.effectiveExpirationDate
        let now = Date()
        
        // Data/ora in cui far partire la notifica: giorno di scadenza alle 9:00, meno N giorni
        var dateComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: expirationDate)
        dateComponents.hour = 9
        dateComponents.minute = 0
        guard let expirationAtNine = calendar.date(from: dateComponents) else { return }
        let triggerDate = calendar.date(byAdding: .day, value: -daysBefore, to: expirationAtNine) ?? expirationAtNine
        
        // Non programmare se la data è già passata (evita notifiche inutili)
        if triggerDate <= now { return }
        
        await cancelNotifications(for: item.id)
        
        let content = UNMutableNotificationContent()
        content.title = "⏰ FoodFade"
        // Messaggio in base a quanti giorni mancano al momento della notifica (daysBefore)
        content.body = notificationBody(for: item, daysRemaining: daysBefore)
        content.sound = .default
        content.userInfo = ["foodItemId": item.id.uuidString]
        content.categoryIdentifier = "FOOD_EXPIRATION"
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate),
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: item.id.uuidString,
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("Errore nella programmazione della notifica: \(error)")
        }
        
        // Aggiungi azioni alla notifica
        let markAsEatenAction = UNNotificationAction(
            identifier: "MARK_AS_EATEN",
            title: "Segna come consumato",
            options: []
        )
        
        let openAppAction = UNNotificationAction(
            identifier: "OPEN_APP",
            title: "Apri app",
            options: .foreground
        )
        
        let category = UNNotificationCategory(
            identifier: "FOOD_EXPIRATION",
            actions: [markAsEatenAction, openAppAction],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }
    
    /// Cancella le notifiche per un item
    func cancelNotifications(for itemId: UUID) async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [itemId.uuidString]
        )
    }
    
    /// Cancella tutte le notifiche
    func cancelAllNotifications() async {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    /// Testo della notifica
    private func notificationBody(for item: FoodItem, daysRemaining: Int) -> String {
        if daysRemaining < 0 {
            return "Il tuo \(item.name) è scaduto 📦"
        } else if daysRemaining == 0 {
            return "Ultima possibilità — il tuo \(item.name) scade oggi! \(getEmoji(for: item.name))"
        } else if daysRemaining == 1 {
            return "Il tuo \(item.name) scade domani \(getEmoji(for: item.name))"
        } else {
            return "Ricorda: \(item.name) scade tra \(daysRemaining) giorni \(getEmoji(for: item.name))"
        }
    }
    
    /// Emoji basata sul nome del cibo
    private func getEmoji(for name: String) -> String {
        let lowercased = name.lowercased()
        
        if lowercased.contains("latte") || lowercased.contains("yogurt") || lowercased.contains("formaggio") {
            return "🥛"
        } else if lowercased.contains("frutta") || lowercased.contains("mela") || lowercased.contains("banana") {
            return "🍎"
        } else if lowercased.contains("verdura") || lowercased.contains("insalata") {
            return "🥗"
        } else if lowercased.contains("pane") {
            return "🍞"
        } else if lowercased.contains("carne") {
            return "🥩"
        } else if lowercased.contains("pesce") {
            return "🐟"
        } else {
            return "🍽️"
        }
    }
    
    enum NotificationError: LocalizedError {
        case authorizationDenied
        
        var errorDescription: String? {
            switch self {
            case .authorizationDenied:
                return "Autorizzazione notifiche negata"
            }
        }
    }
}

