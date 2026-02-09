import UIKit
import UserNotifications

/// Delegate per gestire il tap sulle notifiche: apre i dettagli dell'oggetto in scadenza/scaduto.
final class NotificationDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        guard let idString = userInfo["foodItemId"] as? String,
              let itemId = UUID(uuidString: idString) else {
            completionHandler()
            return
        }
        
        Task { @MainActor in
            NotificationService.shared.itemIdToOpenFromNotification = itemId
            if response.actionIdentifier == "MARK_AS_EATEN" {
                NotificationService.shared.itemIdToMarkAsConsumedFromNotification = itemId
            }
            completionHandler()
        }
    }
    
    /// Mostra la notifica anche quando l'app è in primo piano (opzionale)
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
}
