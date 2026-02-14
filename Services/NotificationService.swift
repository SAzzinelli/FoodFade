import Foundation
import UserNotifications
import Combine

/// Servizio per la gestione delle notifiche locali
@MainActor
class NotificationService: ObservableObject {
    static let shared = NotificationService()
    
    private init() {}
    
    /// ID dell'item da aprire in dettaglio quando l'utente tap sulla notifica (in scadenza / scaduto).
    @Published var itemIdToOpenFromNotification: UUID?
    
    /// ID dell'item da segnare come consumato (azione "Segna come consumato" dalla notifica).
    @Published var itemIdToMarkAsConsumedFromNotification: UUID?
    
    /// Richiede l'autorizzazione per le notifiche
    func requestAuthorization() async throws {
        let center = UNUserNotificationCenter.current()
        let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        
        if !granted {
            throw NotificationError.authorizationDenied
        }
    }
    
    /// Identificatori notifiche per item (reminder = X giorni prima, today = giorno di scadenza)
    private func reminderIdentifier(for itemId: UUID) -> String { "\(itemId.uuidString).reminder" }
    private func todayIdentifier(for itemId: UUID) -> String { "\(itemId.uuidString).today" }

    /// Programma le notifiche per un FoodItem:
    /// 1) "X giorni prima" alle 9:00 (se quella data è nel futuro)
    /// 2) "Scade oggi" il giorno di scadenza alle 9:00 (così non perdi mai l'avviso)
    func scheduleNotifications(for item: FoodItem, daysBefore: Int) async {
        guard item.notify, !item.isConsumed else { return }

        let calendar = Calendar.current
        let expirationDate = item.effectiveExpirationDate
        let now = Date()

        var dateComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: expirationDate)
        dateComponents.hour = 9
        dateComponents.minute = 0
        guard let expirationAtNine = calendar.date(from: dateComponents) else { return }

        await cancelNotifications(for: item.id)
        await registerCategoryIfNeeded()

        let center = UNUserNotificationCenter.current()

        // 1) Notifica "X giorni prima" (solo se la data è nel futuro)
        let reminderDate = calendar.date(byAdding: .day, value: -daysBefore, to: expirationAtNine) ?? expirationAtNine
        if reminderDate > now {
            let content = UNMutableNotificationContent()
            content.title = "⏰ FoodFade"
            content.body = notificationBody(for: item, daysRemaining: daysBefore)
            content.sound = .default
            content.userInfo = ["foodItemId": item.id.uuidString]
            content.categoryIdentifier = "FOOD_EXPIRATION"
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate),
                repeats: false
            )
            let request = UNNotificationRequest(
                identifier: reminderIdentifier(for: item.id),
                content: content,
                trigger: trigger
            )
            do {
                try await center.add(request)
            } catch {
                #if DEBUG
                print("Errore programmazione notifica reminder: \(error)")
                #endif
            }
        }

        // 2) Notifica "Scade oggi" il giorno di scadenza alle 9:00 (sempre se nel futuro)
        if expirationAtNine > now {
            let content = UNMutableNotificationContent()
            content.title = "⏰ FoodFade"
            content.body = notificationBody(for: item, daysRemaining: 0)
            content.sound = .default
            content.userInfo = ["foodItemId": item.id.uuidString]
            content.categoryIdentifier = "FOOD_EXPIRATION"
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: expirationAtNine),
                repeats: false
            )
            let request = UNNotificationRequest(
                identifier: todayIdentifier(for: item.id),
                content: content,
                trigger: trigger
            )
            do {
                try await center.add(request)
            } catch {
                #if DEBUG
                print("Errore programmazione notifica scade oggi: \(error)")
                #endif
            }
        }
    }

    private func registerCategoryIfNeeded() async {
        let markAsEatenAction = UNNotificationAction(
            identifier: "MARK_AS_EATEN",
            title: NSLocalizedString("notification.action.mark_consumed", comment: ""),
            options: []
        )
        let openAppAction = UNNotificationAction(
            identifier: "OPEN_APP",
            title: NSLocalizedString("notification.action.open_app", comment: ""),
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
    
    /// Cancella tutte le notifiche per un item (reminder + scade oggi)
    func cancelNotifications(for itemId: UUID) async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [itemId.uuidString, reminderIdentifier(for: itemId), todayIdentifier(for: itemId)]
        )
    }
    
    /// Cancella tutte le notifiche
    func cancelAllNotifications() async {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    /// Rischedula le notifiche per tutti gli item passati (utile all'avvio app per non perdere "Scade oggi")
    func rescheduleNotificationsForItems(_ items: [FoodItem], daysBefore: Int) async {
        let toNotify = items.filter { $0.notify && !$0.isConsumed }
        for item in toNotify {
            await scheduleNotifications(for: item, daysBefore: daysBefore)
        }
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
            let word = daysRemaining == 1 ? "giorno" : "giorni"
            return "Ricorda: \(item.name) scade tra \(daysRemaining) \(word) \(getEmoji(for: item.name))"
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

