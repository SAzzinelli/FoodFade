import SwiftUI

/// Overlay "Bravo!" con Fridgy dopo aver segnato un prodotto come Consumato
struct FridgyBravoOverlay: View {
    var onDismiss: () -> Void
    private let dismissAfter: TimeInterval = 1.4
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
            VStack(spacing: 12) {
                Image("FridgyBravo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 100, height: 100)
                Text("Bravo!")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primary)
            }
            .padding(24)
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(20)
        }
        .onAppear {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            DispatchQueue.main.asyncAfter(deadline: .now() + dismissAfter) {
                onDismiss()
            }
        }
    }
}
