import SwiftUI

/// Placeholder per la tab Lista spesa (vista completa da implementare)
struct ShoppingListPlaceholderView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "cart")
                    .font(.system(size: 60))
                    .foregroundColor(.secondary)
                Text("Lista vuota")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                Text("Aggiungi cosa devi comprare.")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Lista spesa")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    ShoppingListPlaceholderView()
}
